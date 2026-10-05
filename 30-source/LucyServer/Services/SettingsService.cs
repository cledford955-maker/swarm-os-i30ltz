using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;

namespace LucyServer.Services;

public interface ISettingsService
{
    string GetVoice();
    void SetVoice(string voice);
    Task<(bool Success, string Message)> SetLoginPasswordAsync(string newPassword);
    Task<(bool Success, string Message)> SetSudoPasswordAsync(string? newPassword);
    Task<(bool Success, string Message)> SaveApiKeysAsync(Dictionary<string, string> keys);
}

public class SettingsService : ISettingsService
{
    private static string _currentVoice = "en-GB-SoniaNeural";

    // Hardened 2026-10-05. These three paths were all
    //     Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ...)
    // which is the directory the BINARY runs from — bin/Debug/net10.0 under
    // `dotnet run`, publish/ after a publish, /mnt/Lucy/LucyServer for the
    // deployed copy. Secrets therefore landed inside the source tree, where
    // git, Syncthing, tarballs and ISO builds all picked them up, and the
    // location changed with the launch method, so they kept reappearing
    // somewhere new. All three now resolve to one fixed place outside the
    // source tree.
    private static string SecretsDir
    {
        get
        {
            var dir = Path.GetDirectoryName(SwarmSecrets.EnvFilePath);
            return string.IsNullOrEmpty(dir) ? "/mnt/Lucy/20-runtime" : dir;
        }
    }

    private string LoginPassFile => Path.Combine(SecretsDir, "secrets", "login_password.txt");
    private string SudoPassFile  => Path.Combine(SecretsDir, "secrets", "sudo_password.txt");

    private static readonly string[] AllowedKeys = SwarmSecrets.KnownKeys;

    public string GetVoice() => _currentVoice;

    public void SetVoice(string voice) => _currentVoice = voice;

    public async Task<(bool Success, string Message)> SetLoginPasswordAsync(string newPassword)
    {
        if (string.IsNullOrWhiteSpace(newPassword))
            return (false, "Password cannot be empty");

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(LoginPassFile)!);
            var hashed = HashPassword(newPassword);
            await File.WriteAllTextAsync(LoginPassFile, hashed);
            return (true, "Login password updated successfully");
        }
        catch (Exception ex)
        {
            return (false, $"Failed to save login password: {ex.Message}");
        }
    }

    /// <summary>
    /// The sudo password is NO LONGER STORED. Changed 2026-10-05.
    ///
    /// It used to be written in plaintext to
    /// bin/Debug/net10.0/AI/sudo_password.txt — inside the build output,
    /// inside the synced source tree. Checking the codebase showed nothing
    /// ever read it back: it was written once and never used, so storing it
    /// bought nothing and risked root on the machine.
    ///
    /// It cannot usefully be encrypted either. `sudo -S` needs the literal
    /// password, so a hash cannot be replayed, and encryption needs a key
    /// the server can read unattended — which then sits on the same disk as
    /// the ciphertext. That is obfuscation, not protection.
    ///
    /// The endpoint is kept so the existing API and UI do not break. It now
    /// deletes any stored copy and reports that nothing is kept. If a future
    /// feature genuinely needs root, give the service account a sudoers rule
    /// scoped to those exact commands instead of storing a password.
    /// </summary>
    public Task<(bool Success, string Message)> SetSudoPasswordAsync(string? newPassword)
    {
        var removed = false;
        try
        {
            if (File.Exists(SudoPassFile))
            {
                File.Delete(SudoPassFile);
                removed = true;
            }
        }
        catch (Exception ex)
        {
            return Task.FromResult((false,
                $"Could not remove the old stored sudo password: {ex.Message}"));
        }

        return Task.FromResult((true,
            removed
                ? "Your sudo password is no longer stored, and the old saved copy has been deleted."
                : "Nothing to do — your sudo password is not stored anywhere."));
    }

    public Task<(bool Success, string Message)> SaveApiKeysAsync(Dictionary<string, string> keys)
    {
        try
        {
            var accepted = new Dictionary<string, string>();

            foreach (var kvp in keys)
            {
                if (!AllowedKeys.Contains(kvp.Key)) continue;

                // Make it live for this process immediately, so the key works
                // without a restart.
                Environment.SetEnvironmentVariable(kvp.Key, kvp.Value);
                accepted[kvp.Key] = kvp.Value;
            }

            if (accepted.Count == 0)
            {
                return Task.FromResult((false,
                    "No recognised key names. Allowed: " + string.Join(", ", AllowedKeys)));
            }

            SwarmSecrets.Save(accepted);

            return Task.FromResult((true,
                $"Saved {accepted.Count} key(s) to {SwarmSecrets.EnvFilePath}"));
        }
        catch (Exception ex)
        {
            return Task.FromResult((false, ex.Message));
        }
    }

    private static string HashPassword(string password)
    {
        // PBKDF2 hash — compatible with our simple verify logic
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(password), salt, 100_000, HashAlgorithmName.SHA256, 32);
        return $"pbkdf2:sha256:100000:{Convert.ToBase64String(salt)}:{Convert.ToBase64String(hash)}";
    }
}
