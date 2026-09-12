using System.Threading.Tasks;

namespace LucyServer.Services;

public interface IMemoryService
{
    Task<string> GetMemoryContextAsync();
}
