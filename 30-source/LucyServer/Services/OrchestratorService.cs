using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using LucyServer.Models;
using LucyServer.Services.Llm;
using Microsoft.Extensions.DependencyInjection;

namespace LucyServer.Services;

public class OrchestratorService : IOrchestratorService
{
    private readonly IVectorMemoryService _vectorMemoryService;
    private readonly IMemoryService _memoryService;
    private readonly ISwarmRouterService _swarmRouterService;
    private readonly ITTSService _ttsService;
    private readonly IServiceProvider _serviceProvider;

    public OrchestratorService(
        IVectorMemoryService vectorMemoryService,
        IMemoryService memoryService,
        ISwarmRouterService swarmRouterService,
        ITTSService ttsService,
        IServiceProvider serviceProvider)
    {
        _vectorMemoryService = vectorMemoryService;
        _memoryService = memoryService;
        _swarmRouterService = swarmRouterService;
        _ttsService = ttsService;
        _serviceProvider = serviceProvider;
    }

    public async IAsyncEnumerable<string> ProcessChatRequestAsync(LucyRequest request, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var providers = _serviceProvider.GetServices<ILlmProvider>();
        ILlmProvider? provider = providers.FirstOrDefault(p => p.CanHandle(request.ModelId));
        
        if (provider == null)
        {
            throw new Exception($"No LLM Provider found capable of handling model: {request.ModelId}");
        }

        string lastUserMessage = request.Messages.LastOrDefault(m => m.Role == "user")?.Content ?? "";
        
        // 2. Fetch RAG Context
        var ragContext = await _vectorMemoryService.GetVectorContextAsync(lastUserMessage);

        // 3. Load permanent memory
        var permanentMemory = await _memoryService.GetMemoryContextAsync();

        // 4. Use SwarmRouterService if auto-routing is requested
        string systemPromptAddition = "";
        if (request.AutoRoute)
        {
            var route = await _swarmRouterService.RoutePromptAsync(lastUserMessage, cancellationToken);
            systemPromptAddition = $"\\n[Swarm Routing Classification: {route}]";
        }

        // Construct the final system prompt
        var systemMessage = request.Messages.FirstOrDefault(m => m.Role == "system");
        if (systemMessage == null)
        {
            systemMessage = new ChatMessage { Role = "system", Content = "You are Lucy, an advanced AI assistant." };
            request.Messages.Insert(0, systemMessage);
        }

        systemMessage.Content = $"{systemMessage.Content}\\n\\n# Memory Context\\n{permanentMemory}\\n\\n# RAG Context\\n{ragContext}{systemPromptAddition}";

        // 5 & 6. Stream the response
        var responseBuilder = new StringBuilder();
        await foreach (var chunk in provider.StreamChatAsync(request.ModelId, request.Messages, cancellationToken))
        {
            responseBuilder.Append(chunk);
            yield return chunk;
        }

        // 7. Optional: Call ITTSService to generate voice (we could yield an event or just do it in the background)
        // Here we could yield a special event to the client if we wanted, 
        // e.g. a base64 encoded audio chunk, but for SSE typically the client calls TTS, 
        // or we append it at the end. We will yield a special "[AUDIO: ...]" tag at the end.
        
        string? audioBase64 = null;
        string? audioError = null;

        try
        {
            audioBase64 = await _ttsService.GenerateVoiceBase64Async(responseBuilder.ToString());
        }
        catch (Exception ex)
        {
            audioError = ex.Message;
        }

        if (audioError != null)
        {
            yield return $"\\n[AUDIO_ERROR:{audioError}]";
        }
        else if (!string.IsNullOrEmpty(audioBase64))
        {
            yield return $"\\n[AUDIO:{audioBase64}]";
        }
    }
}
