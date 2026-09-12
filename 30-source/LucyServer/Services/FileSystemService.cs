using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services;

public class FileSystemService : IFileSystemService
{
    private readonly ISystemIntegrationService _systemService;

    public FileSystemService(ISystemIntegrationService systemService)
    {
        _systemService = systemService;
    }

    public Task<IEnumerable<FileItemInfo>> ListDirectoryAsync(string path)
    {
        var result = new List<FileItemInfo>();
        
        if (!Directory.Exists(path))
        {
            throw new DirectoryNotFoundException($"Directory not found: {path}");
        }

        var dirInfo = new DirectoryInfo(path);
        
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

        return Task.FromResult<IEnumerable<FileItemInfo>>(result.OrderBy(x => !x.IsDirectory).ThenBy(x => x.Name));
    }

    public async Task<object> AnalyzeDirectoryAsync(string path)
    {
        if (!Directory.Exists(path))
        {
            throw new DirectoryNotFoundException($"Directory not found: {path}");
        }

        // Just run `du -sh` on linux for a quick analyze
        var result = await _systemService.RunCommandAsync($"du -sh \"{path}\"");
        return new { sizeInfo = result.StandardOutput.Trim() };
    }

    public Task<IEnumerable<string>> ListCodeFilesAsync(string path)
    {
        if (!Directory.Exists(path))
        {
            throw new DirectoryNotFoundException($"Directory not found: {path}");
        }

        var allowedExtensions = new[] { ".cs", ".js", ".ts", ".html", ".css", ".py", ".json", ".md", ".sh" };
        var files = Directory.GetFiles(path, "*.*", SearchOption.AllDirectories)
            .Where(f => allowedExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()));

        return Task.FromResult(files);
    }

    public async Task<string> ReadFileAsync(string filename)
    {
        if (!File.Exists(filename))
        {
            throw new FileNotFoundException($"File not found: {filename}");
        }
        
        return await File.ReadAllTextAsync(filename);
    }

    public async Task<bool> SaveFileAsync(string filename, string content)
    {
        var dir = Path.GetDirectoryName(filename);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }

        await File.WriteAllTextAsync(filename, content);
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
