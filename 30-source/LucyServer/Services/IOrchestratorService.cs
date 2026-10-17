using System.Collections.Generic;
using System.Threading;

namespace LucyServer.Services;

public interface IOrchestratorService
{
    IAsyncEnumerable<string> ProcessChatRequestAsync(Models.LucyRequest request, CancellationToken cancellationToken = default);
}
