using System.Text.Json;
using LucyServer.Models;

namespace LucyServer.Services.DeveloperPlatform;

public class ExtensionDevService : IExtensionDevService
{
    private readonly string _extensionsDir;
    private readonly List<LocalExtensionLink> _linkedExtensions = new();
    private readonly object _lock = new();

    public ExtensionDevService(IConfiguration configuration)
    {
        _extensionsDir = configuration["Extensions:DevDirectory"] 
                         ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".swarm_os", "extensions", "dev");
        Directory.CreateDirectory(_extensionsDir);
    }

    public async Task<LocalExtensionLink> LinkLocalExtensionAsync(string sourcePath)
    {
        if (!Directory.Exists(sourcePath))
        {
            throw new DirectoryNotFoundException($"Source directory '{sourcePath}' does not exist.");
        }

        var manifestFile = Path.Combine(sourcePath, "extension.json");
        ExtensionManifest manifest;

        if (File.Exists(manifestFile))
        {
            var json = await File.ReadAllTextAsync(manifestFile);
            manifest = JsonSerializer.Deserialize<ExtensionManifest>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                       ?? new ExtensionManifest { Name = Path.GetFileName(sourcePath) };
        }
        else
        {
            manifest = new ExtensionManifest
            {
                Id = Path.GetFileName(sourcePath).ToLowerInvariant().Replace(" ", "-"),
                Name = Path.GetFileName(sourcePath),
                Version = "0.1.0-dev",
                DisplayName = Path.GetFileName(sourcePath),
                Description = "Locally linked development extension"
            };
        }

        if (string.IsNullOrEmpty(manifest.Id))
        {
            manifest.Id = manifest.Name.ToLowerInvariant().Replace(" ", "-");
        }

        var link = new LocalExtensionLink
        {
            ExtensionId = manifest.Id,
            SourcePath = Path.GetFullPath(sourcePath),
            Manifest = manifest,
            LinkedAt = DateTime.UtcNow,
            IsWatching = true
        };

        lock (_lock)
        {
            _linkedExtensions.RemoveAll(x => x.ExtensionId == manifest.Id);
            _linkedExtensions.Add(link);
        }

        return link;
    }

    public Task<List<LocalExtensionLink>> ListLocalExtensionsAsync()
    {
        lock (_lock)
        {
            return Task.FromResult(_linkedExtensions.ToList());
        }
    }

    public Task<bool> UnlinkLocalExtensionAsync(string extensionId)
    {
        lock (_lock)
        {
            var removed = _linkedExtensions.RemoveAll(x => x.ExtensionId == extensionId);
            return Task.FromResult(removed > 0);
        }
    }

    public Task<DependencyResolutionResult> ResolveDependenciesAsync(Dictionary<string, string> requestedDependencies)
    {
        var resolved = new Dictionary<string, string>();
        var missing = new List<string>();
        var conflicts = new List<string>();

        // Core system provided libraries
        var coreSdkPackages = new Dictionary<string, string>
        {
            { "swarm_core", ">=6.2.0" },
            { "lucille_ipc", ">=2.0.0" },
            { "flutter_linux", ">=3.24.0" },
            { "sqlite3", ">=3.45.0" },
            { "pipewire_audio", ">=1.0.0" }
        };

        foreach (var (pkg, versionReq) in requestedDependencies)
        {
            if (coreSdkPackages.TryGetValue(pkg, out var sysVer))
            {
                resolved[pkg] = sysVer;
            }
            else
            {
                // In a production registry, check database; here simulate automated package graph resolution
                resolved[pkg] = versionReq.TrimStart('^', '~', '>', '=');
            }
        }

        return Task.FromResult(new DependencyResolutionResult
        {
            Success = missing.Count == 0 && conflicts.Count == 0,
            ResolvedPackages = resolved,
            MissingDependencies = missing,
            VersionConflicts = conflicts
        });
    }

    public Task<List<ExtensionManifest>> CheckUpdatesAsync()
    {
        // Mock registry update checks
        return Task.FromResult(new List<ExtensionManifest>());
    }
}
