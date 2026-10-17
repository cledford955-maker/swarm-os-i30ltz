using System.Collections.Generic;
using System.Threading;
using LucyServer.Models;

namespace LucyServer.Services.Llm;

public interface ILlmProvider
{
    bool CanHandle(string modelId);
    IAsyncEnumerable<string> StreamChatAsync(string modelId, List<ChatMessage> messages, CancellationToken cancellationToken = default);
}
