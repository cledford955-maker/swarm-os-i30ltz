using System.Collections.Generic;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services;

public interface IFileSystemService
{
    Task<IEnumerable<FileItemInfo>> ListDirectoryAsync(string path);
    Task<object> AnalyzeDirectoryAsync(string path);
    Task<IEnumerable<string>> ListCodeFilesAsync(string path);
    Task<string> ReadFileAsync(string filename);
    Task<bool> SaveFileAsync(string filename, string content);
    Task<bool> ApplyUpgradeAsync(string filename, string content);
    Task<bool> MountRecoveryAsync();
}
