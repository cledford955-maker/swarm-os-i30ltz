using System.Threading;
using System.Threading.Tasks;

namespace LucyServer.Services;

public enum SwarmRoute
{
    CHAT,
    DEV,
    SYS
}

public interface ISwarmRouterService
{
    Task<SwarmRoute> RoutePromptAsync(string userPrompt, CancellationToken cancellationToken = default);
}
