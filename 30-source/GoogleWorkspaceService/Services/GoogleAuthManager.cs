using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Flows;
using Google.Apis.Auth.OAuth2.Requests;
using Google.Apis.Auth.OAuth2.Responses;
using Google.Apis.Util.Store;

namespace GoogleWorkspaceService.Services;

public class GoogleAuthManager
{
    private static readonly string[] Scopes =
    {
        Google.Apis.Gmail.v1.GmailService.Scope.GmailModify,
        Google.Apis.Gmail.v1.GmailService.Scope.GmailSend,
        Google.Apis.Calendar.v3.CalendarService.Scope.Calendar,
        Google.Apis.Drive.v3.DriveService.Scope.Drive,
        Google.Apis.Tasks.v1.TasksService.Scope.Tasks,
        Google.Apis.PeopleService.v1.PeopleServiceService.Scope.Contacts,
        Google.Apis.PeopleService.v1.PeopleServiceService.Scope.ContactsReadonly,
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    };

    private readonly string _dataDir;
    private readonly string _credentialsPath;
    private readonly string _redirectUri;

    private GoogleAuthorizationCodeFlow? _flow;
    private UserCredential? _credential;

    public bool Authenticated => _credential != null;
    public string? UserEmail { get; private set; }
    public string? UserName { get; private set; }

    public GoogleAuthManager()
    {
        _dataDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "google_tokens");
        _credentialsPath = Path.Combine(_dataDir, "credentials.json");
        _redirectUri = "http://localhost:8399/auth/callback";
        Directory.CreateDirectory(_dataDir);

        _ = TryRestoreSessionAsync();
    }

    // ── Credentials upload ───────────────────────────────────────────────

    public async Task SaveCredentialsAsync(Stream stream)
    {
        Directory.CreateDirectory(_dataDir);
        using var file = File.Create(_credentialsPath);
        await stream.CopyToAsync(file);
        _flow = null;
    }

    public bool HasCredentials => File.Exists(_credentialsPath);

    // ── OAuth URL generation ─────────────────────────────────────────────

    public string GetAuthUrl()
    {
        EnsureFlow();
        var req = (GoogleAuthorizationCodeRequestUrl)_flow!.CreateAuthorizationCodeRequest(_redirectUri);
        req.ResponseType = "code";
        req.AccessType = "offline";
        return req.Build().ToString();
    }

    // ── Code exchange ────────────────────────────────────────────────────

    public async Task<bool> ExchangeCodeAsync(string code)
    {
        EnsureFlow();
        try
        {
            var token = await _flow!.ExchangeCodeForTokenAsync("user", code, _redirectUri, CancellationToken.None);
            _credential = new UserCredential(_flow, "user", token);
            await FetchUserInfoAsync();
            return true;
        }
        catch
        {
            return false;
        }
    }

    // ── Logout ───────────────────────────────────────────────────────────

    public async Task LogoutAsync()
    {
        if (_credential != null)
            await _credential.RevokeTokenAsync(CancellationToken.None);
        _credential = null;
        UserEmail = null;
        UserName = null;
        if (Directory.Exists(_dataDir))
            foreach (var f in Directory.GetFiles(_dataDir, "Google.Apis.Auth*"))
                File.Delete(f);
    }

    // ── Status ───────────────────────────────────────────────────────────

    public object GetStatus() => new
    {
        authenticated = Authenticated,
        email = UserEmail,
        name = UserName,
        has_credentials = HasCredentials
    };

    // ── Get usable credential ────────────────────────────────────────────

    public UserCredential GetCredential()
    {
        if (_credential == null) throw new InvalidOperationException("Not authenticated. Complete OAuth first.");
        return _credential;
    }

    // ── Internal ─────────────────────────────────────────────────────────

    private void EnsureFlow()
    {
        if (_flow != null) return;
        if (!HasCredentials) throw new InvalidOperationException("credentials.json not uploaded yet.");

        var secrets = GoogleClientSecrets.FromFile(_credentialsPath).Secrets;
        _flow = new GoogleAuthorizationCodeFlow(new GoogleAuthorizationCodeFlow.Initializer
        {
            ClientSecrets = secrets,
            Scopes = Scopes,
            DataStore = new FileDataStore(_dataDir, fullPath: true)
        });
    }

    private async Task TryRestoreSessionAsync()
    {
        if (!HasCredentials) return;
        try
        {
            EnsureFlow();
            var token = await _flow!.LoadTokenAsync("user", CancellationToken.None);
            if (token == null) return;

            _credential = new UserCredential(_flow, "user", token);
            if (_credential.Token.IsStale)
                await _credential.RefreshTokenAsync(CancellationToken.None);

            await FetchUserInfoAsync();
        }
        catch { }
    }

    private async Task FetchUserInfoAsync()
    {
        if (_credential == null) return;
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _credential.Token.AccessToken);
            var json = await http.GetStringAsync("https://www.googleapis.com/oauth2/v2/userinfo");
            using var doc = System.Text.Json.JsonDocument.Parse(json);
            UserEmail = doc.RootElement.TryGetProperty("email", out var e) ? e.GetString() : null;
            UserName  = doc.RootElement.TryGetProperty("name",  out var n) ? n.GetString() : null;
        }
        catch { }
    }
}
