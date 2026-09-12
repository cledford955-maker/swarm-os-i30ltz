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

    private static readonly string BaseDir = Path.GetDirectoryName(AppDomain.CurrentDomain.BaseDirectory)
        ?? Directory.GetCurrentDirectory();

    private string LoginPassFile => Path.Combine(BaseDir, "AI", "login_password.txt");
    private string SudoPassFile => Path.Combine(BaseDir, "AI", "sudo_password.txt");
    private string EnvFile => Path.Combine(BaseDir, ".env");

    private static readonly string[] AllowedKeys =
    {
        "OPENROUTER_API_KEY", "NVIDIA_API_KEY", "GEMINI_API_KEY",
        "CLAUDE_API_KEY", "ANTHROPIC_API_KEY", "GROQ_API_KEY",
        "STEAM_API_KEY", "STEAM_ID64"
    };

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

    public async Task<(bool Success, string Message)> SetSudoPasswordAsync(string? newPassword)
    {
        if (string.IsNullOrEmpty(newPassword))
        {
            try
            {
                if (File.Exists(SudoPassFile)) File.Delete(SudoPassFile);
                return (true, "Sudo password cleared successfully");
            }
            catch (Exception ex)
            {
                return (false, $"Failed to clear sudo password: {ex.Message}");
            }
        }

        // Validate the password actually works
        try
        {
            var psi = new ProcessStartInfo("sudo")
            {
                ArgumentList = { "-S", "-k", "true" },
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            };

            using var proc = new Process { StartInfo = psi };
            proc.Start();
            await proc.StandardInput.WriteLineAsync(newPassword);
            proc.StandardInput.Close();
            await proc.WaitForExitAsync();

            if (proc.ExitCode != 0)
                return (false, "Invalid sudo password: authentication failed");

            Directory.CreateDirectory(Path.GetDirectoryName(SudoPassFile)!);
            await File.WriteAllTextAsync(SudoPassFile, newPassword);
            return (true, "Sudo password updated successfully");
        }
        catch (Exception ex)
        {
            return (false, $"Failed to save sudo password: {ex.Message}");
        }
    }

    public async Task<(bool Success, string Message)> SaveApiKeysAsync(Dictionary<string, string> keys)
    {
        try
        {
            // Load existing .env entries
            var envLines = File.Exists(EnvFile)
                ? (await File.ReadAllLinesAsync(EnvFile)).ToList()
                : new List<string>();

            foreach (var kvp in keys)
            {
                if (!AllowedKeys.Contains(kvp.Key)) continue;

                // Update env var in process
                Environment.SetEnvironmentVariable(kvp.Key, kvp.Value);

                // Update or add in file
                var idx = envLines.FindIndex(l => l.StartsWith(kvp.Key + "="));
                var line = $"{kvp.Key}={kvp.Value}";
                if (idx >= 0)
                    envLines[idx] = line;
                else
                    envLines.Add(line);
            }

            await File.WriteAllLinesAsync(EnvFile, envLines);
            return (true, "API keys saved and loaded successfully.");
        }
        catch (Exception ex)
        {
            return (false, ex.Message);
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
