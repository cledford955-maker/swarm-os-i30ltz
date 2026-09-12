using System.IO;
using System.Threading.Tasks;

namespace LucyServer.Services;

public class MemoryService : IMemoryService
{
    private const string MemoryFilePath = "llcy_memory.md";

    public async Task<string> GetMemoryContextAsync()
    {
        if (!File.Exists(MemoryFilePath))
        {
            return string.Empty;
        }

        return await File.ReadAllTextAsync(MemoryFilePath);
    }
}
