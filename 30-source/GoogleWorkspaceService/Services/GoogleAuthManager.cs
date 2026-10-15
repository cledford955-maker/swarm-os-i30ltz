using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Flows;
using Google.Apis.Auth.OAuth2.Requests;
using Google.Apis.Auth.OAuth2.Responses;
using Google.Apis.Util.Store;
using System.Security.Cryptography;

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
    private readonly string _legacyDataDir;
    private readonly string _redirectUri;
    private readonly Task _restoreSession;

    private GoogleAuthorizationCodeFlow? _flow;
    private UserCredential? _credential;

    public bool Authenticated => _credential != null;
    public string? UserEmail { get; private set; }
    public string? UserName { get; private set; }

    public GoogleAuthManager()
    {
        // Keep user OAuth state out of the replaceable application directory.
        // SWARM sets this to /var/lib/swarm/google-workspace; local development
        // uses the current user's private state directory.
        var configuredDataDir = Environment.GetEnvironmentVariable("SWARM_GOOGLE_DATA_DIR");
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (string.IsNullOrWhiteSpace(configuredDataDir) && string.IsNullOrWhiteSpace(home))
            throw new InvalidOperationException("Set SWARM_GOOGLE_DATA_DIR or provide a user home directory.");

        _dataDir = string.IsNullOrWhiteSpace(configuredDataDir)
            ? Path.Combine(home, ".local", "state", "swarm", "google-workspace")
            : configuredDataDir;
        _legacyDataDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "google_tokens");
        _credentialsPath = Path.Combine(_dataDir, "credentials.json");
        _redirectUri = "http://localhost:8399/auth/callback";
        EnsurePrivateDataDirectory();
        MigrateLegacyState();

        _restoreSession = TryRestoreSessionAsync();
    }

    // ── Credentials upload ───────────────────────────────────────────────

    public async Task SaveCredentialsAsync(Stream stream)
    {
        await _restoreSession;
        EnsurePrivateDataDirectory();
        using (var file = new FileStream(_credentialsPath, FileMode.Create, FileAccess.Write, FileShare.None))
            await stream.CopyToAsync(file);
        RestrictFile(_credentialsPath);
        DeleteStoredTokens();
        _credential = null;
        UserEmail = null;
        UserName = null;
        _flow = null;
    }

    public bool HasCredentials => File.Exists(_credentialsPath);

    // ── OAuth URL generation ─────────────────────────────────────────────

    public string GetAuthUrl()
    {
        _restoreSession.GetAwaiter().GetResult();
        EnsureFlow();
        var req = (GoogleAuthorizationCodeRequestUrl)_flow!.CreateAuthorizationCodeRequest(_redirectUri);
        req.ResponseType = "code";
        req.AccessType = "offline";
        req.Prompt = "consent";
        return req.Build().ToString();
    }

    // ── Code exchange ────────────────────────────────────────────────────

    public async Task<bool> ExchangeCodeAsync(string code)
    {
        await _restoreSession;
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
        await _restoreSession;
        if (_credential != null)
            await _credential.RevokeTokenAsync(CancellationToken.None);
        _credential = null;
        UserEmail = null;
        UserName = null;
        DeleteStoredTokens();
    }

    // ── Status ───────────────────────────────────────────────────────────

    public async Task<object> GetStatusAsync()
    {
        await _restoreSession;
        return new
        {
            authenticated = Authenticated,
            email = UserEmail,
            name = UserName,
            has_credentials = HasCredentials
        };
    }

    // ── Get usable credential ────────────────────────────────────────────

    public UserCredential GetCredential()
    {
        // Google API clients ask for credentials synchronously. Wait for the
        // one-time disk restore so the first request after service startup does
        // not incorrectly behave like a signed-out session.
        _restoreSession.GetAwaiter().GetResult();
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

    private void EnsurePrivateDataDirectory()
    {
        Directory.CreateDirectory(_dataDir);
        if (OperatingSystem.IsLinux())
            File.SetUnixFileMode(_dataDir, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
    }

    private void MigrateLegacyState()
    {
        if (!Directory.Exists(_legacyDataDir) || Path.GetFullPath(_legacyDataDir) == Path.GetFullPath(_dataDir))
            return;

        foreach (var source in Directory.EnumerateFiles(_legacyDataDir))
        {
            var name = Path.GetFileName(source);
            if (name != "credentials.json" && !name.StartsWith("Google.Apis.Auth", StringComparison.Ordinal))
                continue;

            var destination = Path.Combine(_dataDir, name);
            if (!File.Exists(destination))
            {
                File.Copy(source, destination);
                RestrictFile(destination);
            }

            // Keep the legacy copy if the durable file conflicts or cannot be
            // verified. Delete only the matched credentials/token file after
            // its new copy is confirmed, making retries safe and idempotent.
            if (File.Exists(destination) && FilesMatch(source, destination))
                File.Delete(source);
        }
    }

    private static bool FilesMatch(string first, string second)
    {
        using var firstStream = File.OpenRead(first);
        using var secondStream = File.OpenRead(second);
        var firstHash = SHA256.HashData(firstStream);
        var secondHash = SHA256.HashData(secondStream);
        return CryptographicOperations.FixedTimeEquals(firstHash, secondHash);
    }

    private void DeleteStoredTokens()
    {
        if (!Directory.Exists(_dataDir)) return;
        foreach (var file in Directory.EnumerateFiles(_dataDir, "Google.Apis.Auth*"))
            File.Delete(file);
    }

    private static void RestrictFile(string path)
    {
        if (OperatingSystem.IsLinux())
            File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
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
