using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services;

/// <summary>
/// Filesystem access for the /api/fs and /api/code endpoints.
///
/// Hardened 2026-10-05. Two problems were fixed here:
///
///  1. Command injection. AnalyzeDirectoryAsync interpolated the caller's
///     path into a shell string (`du -sh "{path}"`), so a path containing a
///     quote followed by $(...) or ; ran arbitrary commands as the server
///     user. The walk is now done in-process and no shell is involved.
///
///  2. No root clamp. Every method accepted any absolute path, and the
///     /api/fs and /api/code/files endpoints defaulted to "/", so an
///     authenticated caller could list, read or OVERWRITE any file the
///     server user could reach. Every path now passes through
///     ResolveWithinRoots.
///
/// Roots are configurable and never "/":
///     SWARM_PROJECT_ROOTS   colon-separated list (preferred)
///     SWARM_PROJECT_ROOT    single root (the originally planned name)
///     default               /mnt/Lucy and the server user's home
/// Several roots are allowed deliberately: clamping to one guessed root is
/// what would silently break a client that legitimately browses the other.
/// </summary>
public class FileSystemService : IFileSystemService
{
    private readonly ISystemIntegrationService _systemService;
    private readonly string[] _roots;

    public FileSystemService(ISystemIntegrationService systemService)
    {
        _systemService = systemService;
        _roots = ComputeRoots();
        Console.WriteLine(
            "[FileSystemService] file API clamped to: " + string.Join(", ", _roots));
    }

    // ── root configuration ──────────────────────────────────────────────

    private static string HomeDirectory()
    {
        var home = Environment.GetEnvironmentVariable("HOME");
        if (string.IsNullOrWhiteSpace(home))
        {
            home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        }
        return string.IsNullOrWhiteSpace(home) ? "/tmp" : home;
    }

    private static string[] ComputeRoots()
    {
        var raw = Environment.GetEnvironmentVariable("SWARM_PROJECT_ROOTS");
        if (string.IsNullOrWhiteSpace(raw))
        {
            raw = Environment.GetEnvironmentVariable("SWARM_PROJECT_ROOT");
        }

        IEnumerable<string> candidates = !string.IsNullOrWhiteSpace(raw)
            ? raw.Split(':', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            : new[] { "/mnt/Lucy", HomeDirectory() };

        var roots = candidates
            .Select(candidate =>
            {
                try { return RealPath(candidate); }
                catch (Exception) { return null; }
            })
            .Where(candidate => !string.IsNullOrEmpty(candidate))
            .Select(candidate => candidate!.TrimEnd(Path.DirectorySeparatorChar))
            // A root that trims to empty was "/" — never allowed, because it
            // would make the clamp a no-op.
            .Where(candidate => candidate.Length > 0)
            .Where(Directory.Exists)
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        if (roots.Length == 0)
        {
            var home = HomeDirectory().TrimEnd(Path.DirectorySeparatorChar);
            if (home.Length == 0 || !Directory.Exists(home))
            {
                throw new InvalidOperationException(
                    "FileSystemService has no usable root. Set SWARM_PROJECT_ROOTS "
                    + "to one or more existing directories, separated by ':'.");
            }
            roots = new[] { home };
        }

        return roots;
    }

    // ── path resolution ─────────────────────────────────────────────────

    /// <summary>
    /// Resolve symlinks along the WHOLE path chain, not just the final
    /// component: a symlinked parent directory would otherwise step outside
    /// the roots while the normalized string still looked contained.
    /// </summary>
    private static string RealPath(string path)
    {
        var full = Path.GetFullPath(path);
        for (var hops = 0; hops < 40; hops++)
        {
            var next = ResolveFirstLink(full);
            if (next == null) return full;
            full = next;
        }
        throw new IOException("Too many symbolic links while resolving: " + path);
    }

    /// <summary>
    /// Find the first symlink in the chain, replace it with its target, and
    /// re-append the remainder. Returns null when the chain holds no link.
    /// </summary>
    private static string? ResolveFirstLink(string full)
    {
        var separator = Path.DirectorySeparatorChar;
        var parts = full.Split(separator, StringSplitOptions.RemoveEmptyEntries);
        var walked = separator.ToString();

        for (var i = 0; i < parts.Length; i++)
        {
            var candidate = Path.Combine(walked, parts[i]);

            FileSystemInfo info = Directory.Exists(candidate)
                ? new DirectoryInfo(candidate)
                : new FileInfo(candidate);

            string? target;
            try { target = info.LinkTarget; }
            catch (Exception) { target = null; }

            if (!string.IsNullOrEmpty(target))
            {
                var resolved = Path.IsPathRooted(target)
                    ? target
                    : Path.Combine(Path.GetDirectoryName(candidate) ?? walked, target);

                var remainder = parts.Skip(i + 1).ToArray();
                return Path.GetFullPath(remainder.Length > 0
                    ? Path.Combine(resolved, Path.Combine(remainder))
                    : resolved);
            }

            walked = candidate;
        }

        return null;
    }

    /// <summary>
    /// Canonicalize a caller-supplied path and require it to sit inside one
    /// of the configured roots. An empty path means "the first root", which
    /// is what the /api/fs and /api/code/files endpoints send when the
    /// caller omits one — they used to send "/".
    /// </summary>
    private string ResolveWithinRoots(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || path == "/")
        {
            return _roots[0];
        }

        var expanded = path.StartsWith("~/", StringComparison.Ordinal)
            ? Path.Combine(HomeDirectory(), path.Substring(2))
            : path;

        string real;
        try
        {
            real = RealPath(expanded);
        }
        catch (Exception ex) when (ex is IOException or ArgumentException or NotSupportedException)
        {
            throw new UnauthorizedAccessException("Path could not be resolved: " + path);
        }

        foreach (var root in _roots)
        {
            if (real == root ||
                real.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
            {
                return real;
            }
        }

        // Name the resolved path and the roots: a legitimate client that falls
        // outside should fail loudly and say how to fix it, not mysteriously.
        throw new UnauthorizedAccessException(
            "Path is outside the allowed roots: " + real
            + ". Allowed roots: " + string.Join(", ", _roots)
            + ". Set SWARM_PROJECT_ROOTS (colon-separated) to change this.");
    }

    // ── API ─────────────────────────────────────────────────────────────

    public Task<IEnumerable<FileItemInfo>> ListDirectoryAsync(string path)
    {
        var safe = ResolveWithinRoots(path);
        var result = new List<FileItemInfo>();

        if (!Directory.Exists(safe))
        {
            throw new DirectoryNotFoundException($"Directory not found: {safe}");
        }

        var dirInfo = new DirectoryInfo(safe);

        foreach (var dir in dirInfo.GetDirectories())
        {
            result.Add(new FileItemInfo
            {
                Name = dir.Name,
                Path = dir.FullName,
                IsDirectory = true,
                Size = 0
            });
        }

        foreach (var file in dirInfo.GetFiles())
        {
            result.Add(new FileItemInfo
            {
                Name = file.Name,
                Path = file.FullName,
                IsDirectory = false,
                Size = file.Length
            });
        }

        return Task.FromResult<IEnumerable<FileItemInfo>>(
            result.OrderBy(x => !x.IsDirectory).ThenBy(x => x.Name));
    }

    // Was: await _systemService.RunCommandAsync($"du -sh \"{path}\"")
    // The caller's path was interpolated into a shell command string, so a
    // path containing a quote followed by $(...) or ; executed arbitrary
    // commands as the server user. The walk is now in-process — no shell.
    // `sizeInfo` is kept in the response so existing callers do not break.
    public Task<object> AnalyzeDirectoryAsync(string path)
    {
        var safe = ResolveWithinRoots(path);

        if (!Directory.Exists(safe))
        {
            throw new DirectoryNotFoundException($"Directory not found: {safe}");
        }

        long totalBytes = 0;
        var fileCount = 0;
        var directoryCount = 0;

        var pending = new Stack<string>();
        pending.Push(safe);

        while (pending.Count > 0)
        {
            var current = pending.Pop();

            IEnumerable<string> subdirectories;
            IEnumerable<string> files;
            try
            {
                subdirectories = Directory.EnumerateDirectories(current);
                files = Directory.EnumerateFiles(current);
            }
            catch (UnauthorizedAccessException)
            {
                continue;
            }
            catch (DirectoryNotFoundException)
            {
                continue;
            }

            foreach (var subdirectory in subdirectories)
            {
                // Symlinked directories are counted but not followed: a link
                // can point outside the tree, or form a cycle.
                if (new DirectoryInfo(subdirectory).LinkTarget != null)
                {
                    directoryCount++;
                    continue;
                }

                directoryCount++;
                pending.Push(subdirectory);
            }

            foreach (var file in files)
            {
                try
                {
                    var info = new FileInfo(file);
                    if (info.LinkTarget != null)
                    {
                        fileCount++;
                        continue;
                    }

                    totalBytes += info.Length;
                    fileCount++;
                }
                catch (IOException)
                {
                    // File vanished or is unreadable mid-walk; skip it.
                }
                catch (UnauthorizedAccessException)
                {
                }
            }
        }

        return Task.FromResult<object>(new
        {
            sizeInfo = $"{FormatBytes(totalBytes)}\t{safe}",
            totalBytes,
            fileCount,
            directoryCount
        });
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = { "B", "K", "M", "G", "T" };
        double value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }
        return unit == 0 ? $"{bytes}B" : $"{value:0.#}{units[unit]}";
    }

    public Task<IEnumerable<string>> ListCodeFilesAsync(string path)
    {
        var safe = ResolveWithinRoots(path);

        if (!Directory.Exists(safe))
        {
            throw new DirectoryNotFoundException($"Directory not found: {safe}");
        }

        var allowedExtensions = new[] { ".cs", ".js", ".ts", ".html", ".css", ".py", ".json", ".md", ".sh" };
        var files = Directory
            .GetFiles(safe, "*.*", SearchOption.AllDirectories)
            .Where(f => allowedExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()));

        return Task.FromResult(files);
    }

    public async Task<string> ReadFileAsync(string filename)
    {
        var safe = ResolveWithinRoots(filename);

        if (!File.Exists(safe))
        {
            throw new FileNotFoundException($"File not found: {safe}");
        }

        return await File.ReadAllTextAsync(safe);
    }

    public async Task<bool> SaveFileAsync(string filename, string content)
    {
        var safe = ResolveWithinRoots(filename);

        var dir = Path.GetDirectoryName(safe);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            // Re-check the directory itself: ResolveWithinRoots validated the
            // file path, and the parent of a contained path is contained too,
            // but creating it is a write and is worth stating explicitly.
            ResolveWithinRoots(dir);
            Directory.CreateDirectory(dir);
        }

        await File.WriteAllTextAsync(safe, content);
        return true;
    }

    public async Task<bool> ApplyUpgradeAsync(string filename, string content)
    {
        // For now, this is equivalent to SaveFileAsync. We can add patch support later.
        return await SaveFileAsync(filename, content);
    }

    public async Task<bool> MountRecoveryAsync()
    {
        // Equivalent to the /tmp/host_system mount check/action in python
        var hostMount = "/tmp/host_system";
        if (!Directory.Exists(hostMount))
        {
            Directory.CreateDirectory(hostMount);
        }
        // In python it might have run mount /dev/... here we just simulate success
        return await Task.FromResult(true);
    }
}
