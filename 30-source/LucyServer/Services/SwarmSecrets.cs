using Microsoft.Extensions.Configuration;

namespace LucyServer.Services;

/// <summary>
/// The ONE place SWARM secrets live, and the only code that decides where
/// that is.
///
/// Added 2026-10-05. Before this, SettingsService wrote the env file to
/// `Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ".env")` — the
/// directory the binary happened to be running from. That meant:
///
///   dotnet run        -> bin/Debug/net10.0/.env
///   dotnet publish    -> publish/.env
///   deployed copy     -> /mnt/Lucy/LucyServer/.env
///
/// Every one of those is inside the source tree, so saved keys were picked
/// up by git, Syncthing, tarballs and ISO builds. The location also changed
/// with the launch method, which is why keys kept reappearing somewhere new.
///
/// The path is now absolute and outside the source tree. `.stignore`
/// already excludes `.env` from Syncthing, so secrets stay on LUCILLE.
/// </summary>
public static class SwarmSecrets
{
    /// <summary>Override for tests or an unusual layout.</summary>
    private const string PathOverrideVariable = "SWARM_ENV_FILE";

    private const string DefaultPath = "/mnt/Lucy/20-runtime/.env";

    /// <summary>
    /// Absolute path to the single env file. Never relative to the binary.
    /// </summary>
    public static string EnvFilePath
    {
        get
        {
            var overridden = Environment.GetEnvironmentVariable(PathOverrideVariable);
            return string.IsNullOrWhiteSpace(overridden) ? DefaultPath : overridden;
        }
    }

    /// <summary>
    /// Secret names this server will read or write, in the SCREAMING_SNAKE
    /// spelling an env file uses. The Go Lucille Assistant reads the same
    /// file with the same spellings, so one file serves both services.
    /// </summary>
    public static readonly string[] KnownKeys =
    {
        "OPENROUTER_API_KEY", "NVIDIA_API_KEY", "GEMINI_API_KEY",
        "CLAUDE_API_KEY", "ANTHROPIC_API_KEY", "GROQ_API_KEY",
        "STEAM_API_KEY", "STEAM_ID64", "FISH_AUDIO_KEY",
        "SWARM_AUTH_TOKEN",
    };

    /// <summary>
    /// Read the env file and set each entry as a process environment
    /// variable, WITHOUT overwriting one already set by systemd or the
    /// shell — an explicitly exported value should always win.
    ///
    /// Call this before WebApplication.CreateBuilder, so the values are in
    /// place when AddEnvironmentVariables() builds IConfiguration.
    /// </summary>
    public static void LoadIntoProcess()
    {
        var path = EnvFilePath;
        if (!File.Exists(path))
        {
            Console.WriteLine($"[SwarmSecrets] no env file at {path} (that is fine; nothing loaded)");
            return;
        }

        var loaded = 0;
        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;

            var split = line.IndexOf('=');
            if (split <= 0) continue;

            var name = line.Substring(0, split).Trim();
            var value = line.Substring(split + 1).Trim();

            // Tolerate quoted values, which hand-edited env files often have.
            if (value.Length >= 2 &&
                ((value[0] == '"' && value[^1] == '"') ||
                 (value[0] == '\'' && value[^1] == '\'')))
            {
                value = value.Substring(1, value.Length - 2);
            }

            if (name.Length == 0) continue;
            if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name))) continue;

            Environment.SetEnvironmentVariable(name, value);
            loaded++;
        }

        // Count only — never log a name/value pair.
        Console.WriteLine($"[SwarmSecrets] loaded {loaded} value(s) from {path}");
    }

    /// <summary>
    /// Delete secret files left behind in the old build-output locations,
    /// and any stored sudo password.
    ///
    /// Runs at every startup so the cleanup needs no action from the user.
    /// Contents are overwritten with zeros before the unlink, so a casual
    /// undelete does not bring the plaintext back. Failures are ignored:
    /// this is tidying, never something that should stop the server.
    /// </summary>
    public static void PurgeLegacySecretFiles()
    {
        var binDir = AppDomain.CurrentDomain.BaseDirectory;
        var secretsDir = Path.GetDirectoryName(EnvFilePath) ?? "/mnt/Lucy/20-runtime";

        var stale = new List<string>
        {
            // Written by the old BaseDirectory-relative paths.
            Path.Combine(binDir, ".env"),
            Path.Combine(binDir, "AI", "sudo_password.txt"),
            Path.Combine(binDir, "AI", "login_password.txt"),

            // The sudo password is no longer stored at all: nothing ever read
            // it back, so keeping it was risk without function.
            Path.Combine(secretsDir, "secrets", "sudo_password.txt"),
        };

        var removed = 0;
        foreach (var path in stale)
        {
            try
            {
                if (!File.Exists(path)) continue;
                Shred(path);
                removed++;
                Console.WriteLine($"[SwarmSecrets] removed stale secret file: {path}");
            }
            catch (Exception)
            {
                // A file we cannot remove is not a reason to fail startup.
            }
        }

        if (removed == 0)
        {
            Console.WriteLine("[SwarmSecrets] no stale secret files found");
        }
    }

    /// <summary>Zero the bytes, then unlink.</summary>
    private static void Shred(string path)
    {
        try
        {
            var length = new FileInfo(path).Length;
            if (length > 0 && length < 1_000_000)
            {
                using var stream = new FileStream(path, FileMode.Open, FileAccess.Write);
                stream.Write(new byte[length]);
                stream.Flush(true);
            }
        }
        catch (Exception)
        {
            // Overwriting is best effort; the unlink below is what matters.
        }
        File.Delete(path);
    }

    /// <summary>
    /// Look a secret up under every spelling it might carry.
    ///
    /// This exists because the two halves of the app disagreed. The settings
    /// panel wrote `OPENROUTER_API_KEY`; the providers read
    /// `configuration["OpenRouterApiKey"]`. .NET only treats `__` as special
    /// when mapping env vars to config keys — a single `_` stays literal —
    /// so those two names never matched and a key saved through the UI was
    /// invisible to the provider that needed it. That is what made the key
    /// seem to need retyping in a new place every time.
    /// </summary>
    public static string? Lookup(IConfiguration configuration, params string[] names)
    {
        foreach (var name in names)
        {
            var fromConfig = configuration[name];
            if (!string.IsNullOrWhiteSpace(fromConfig)) return fromConfig.Trim();

            var fromEnv = Environment.GetEnvironmentVariable(name);
            if (!string.IsNullOrWhiteSpace(fromEnv)) return fromEnv.Trim();
        }
        return null;
    }

    /// <summary>
    /// Merge values into the env file, creating it 0600 and leaving every
    /// other line untouched. Written through a temp file in the same
    /// directory and moved into place, so an interrupted write cannot leave
    /// a half-truncated secrets file.
    /// </summary>
    public static void Save(IDictionary<string, string> values)
    {
        var path = EnvFilePath;
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var lines = File.Exists(path)
            ? File.ReadAllLines(path).ToList()
            : new List<string>();

        foreach (var pair in values)
        {
            var index = lines.FindIndex(l =>
                l.TrimStart().StartsWith(pair.Key + "=", StringComparison.Ordinal));
            var line = $"{pair.Key}={pair.Value}";

            if (index >= 0) lines[index] = line;
            else lines.Add(line);
        }

        var temp = path + ".tmp";
        File.WriteAllLines(temp, lines);
        Chmod600(temp);
        File.Move(temp, path, overwrite: true);
        Chmod600(path);
    }

    private static void Chmod600(string path)
    {
        if (OperatingSystem.IsWindows()) return;
        try
        {
            File.SetUnixFileMode(path,
                UnixFileMode.UserRead | UnixFileMode.UserWrite);
        }
        catch (Exception)
        {
            // Mode is defence in depth, not the control itself; a filesystem
            // that refuses it must not fail the save.
        }
    }
}
