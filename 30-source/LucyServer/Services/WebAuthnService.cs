using Fido2NetLib;
using Fido2NetLib.Objects;
using System.Text.Json;

namespace LucyServer.Services;

public class WebAuthnService : IAuthService
{
    private readonly IFido2 _fido2;
    private readonly string _credentialStorePath;
    
    // In-memory challenge storage for simplicity (should use a distributed cache in prod)
    private static readonly Dictionary<string, string> _challenges = new();
    private static readonly List<StoredCredential> _credentials = new();

    public WebAuthnService(IFido2 fido2)
    {
        _fido2 = fido2;
        _credentialStorePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "webauthn_credentials.json");
        LoadCredentials();
    }

    private void LoadCredentials()
    {
        if (File.Exists(_credentialStorePath))
        {
            try
            {
                var json = File.ReadAllText(_credentialStorePath);
                var loaded = JsonSerializer.Deserialize<List<StoredCredential>>(json);
                if (loaded != null)
                {
                    _credentials.Clear();
                    _credentials.AddRange(loaded);
                }
            }
            catch { }
        }
    }

    private void SaveCredentials()
    {
        var json = JsonSerializer.Serialize(_credentials);
        File.WriteAllText(_credentialStorePath, json);
    }

    public CredentialCreateOptions GetRegisterOptions()
    {
        var user = new Fido2User
        {
            Name = "admin",
            DisplayName = "Administrator",
            Id = "user1"u8.ToArray()
        };

        var options = _fido2.RequestNewCredential(
            user,
            _credentials.Select(c => new PublicKeyCredentialDescriptor(c.Descriptor.Id)).ToList(),
            AuthenticatorSelection.Default,
            AttestationConveyancePreference.None
        );

        _challenges["register"] = Convert.ToBase64String(options.Challenge);
        return options;
    }

    public async Task<Fido2.CredentialMakeResult> VerifyRegisterAsync(AuthenticatorAttestationRawResponse clientResponse)
    {
        if (!_challenges.TryGetValue("register", out var challengeBase64))
            throw new Exception("No challenge found");

        var challenge = Convert.FromBase64String(challengeBase64);
        
        var result = await _fido2.MakeNewCredentialAsync(
            clientResponse,
            new CredentialCreateOptions { Challenge = challenge },
            async (args, cancellationToken) => 
            {
                var isUnique = !_credentials.Any(c => c.Descriptor.Id.SequenceEqual(args.CredentialId));
                return await Task.FromResult(isUnique);
            }
        );

        if (result.Status == "ok")
        {
            _credentials.Add(new StoredCredential 
            {
                Descriptor = new PublicKeyCredentialDescriptor(result.Result.CredentialId),
                PublicKey = result.Result.PublicKey,
                UserHandle = result.Result.User.Id,
                SignCount = result.Result.Counter,
                RegDate = DateTime.UtcNow
            });
            SaveCredentials();
        }

        return result;
    }

    public AssertionOptions GetLoginOptions()
    {
        var existingCredentials = _credentials.Select(c => c.Descriptor).ToList();
        var options = _fido2.GetAssertionOptions(
            existingCredentials,
            UserVerificationRequirement.Preferred
        );
        _challenges["login"] = Convert.ToBase64String(options.Challenge);
        return options;
    }

    public async Task<AssertionVerificationResult> VerifyLoginAsync(AuthenticatorAssertionRawResponse clientResponse)
    {
        if (!_challenges.TryGetValue("login", out var challengeBase64))
            throw new Exception("No challenge found");

        var challenge = Convert.FromBase64String(challengeBase64);
        var options = AssertionOptions.FromJson(JsonSerializer.Serialize(new { challenge = challenge }));

        var storedCred = _credentials.FirstOrDefault(c => c.Descriptor.Id.SequenceEqual(clientResponse.Id));
        if (storedCred == null)
            throw new Exception("Unknown credential");

        var result = await _fido2.MakeAssertionAsync(
            clientResponse,
            options,
            storedCred.PublicKey,
            storedCred.SignCount,
            async (args, cancellationToken) => 
            {
                return await Task.FromResult(true);
            }
        );

        if (result.Status == "ok")
        {
            storedCred.SignCount = result.Counter;
            SaveCredentials();
        }

        return result;
    }

    public List<object> ListCredentials()
    {
        return _credentials.Select(c => (object)new
        {
            label = c.RegDate.ToString("yyyy-MM-dd"),
            id = Convert.ToBase64String(c.Descriptor.Id)[..Math.Min(10, Convert.ToBase64String(c.Descriptor.Id).Length)] + "..."
        }).ToList();
    }

    public void ClearCredentials()
    {
        _credentials.Clear();
        SaveCredentials();
    }
}

public class StoredCredential
{
    public required PublicKeyCredentialDescriptor Descriptor { get; set; }
    public required byte[] PublicKey { get; set; }
    public required byte[] UserHandle { get; set; }
    public uint SignCount { get; set; }
    public DateTime RegDate { get; set; }
}
