using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using LucyServer.Models;
using LucyServer.Services.Llm;
using Microsoft.Extensions.DependencyInjection;

namespace LucyServer.Services;

public class SwarmRouterService : ISwarmRouterService
{
    private readonly IServiceProvider _serviceProvider;
    private const string RouterModelId = "nvidia/nemotron-4-340b-instruct";

    public SwarmRouterService(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public async Task<SwarmRoute> RoutePromptAsync(string userPrompt, CancellationToken cancellationToken = default)
    {
        var systemPrompt = @"You are a routing agent. Your task is to classify the user's prompt into one of the following three categories. Respond ONLY with the category name (CHAT, DEV, or SYS) and nothing else.

Categories:
- DEV: The user is asking for code, programming help, architectural advice, or code audits.
- SYS: The user is asking to execute a system command, change system settings, or manipulate files directly.
- CHAT: General conversational inquiries, knowledge questions, or companion chat.";

        var messages = new List<ChatMessage>
        {
            new ChatMessage { Role = "system", Content = systemPrompt },
            new ChatMessage { Role = "user", Content = userPrompt }
        };

        // We resolve ILlmProvider dynamically to avoid circular dependencies if we use IEnumerable<ILlmProvider> 
        // and one of them requires something else. But here we can just get the registered ones.
        var providers = _serviceProvider.GetServices<ILlmProvider>();
        ILlmProvider? routerProvider = null;
        foreach (var provider in providers)
        {
            if (provider.CanHandle(RouterModelId))
            {
                routerProvider = provider;
                break;
            }
        }

        if (routerProvider == null)
        {
            // Fallback to CHAT if no provider can handle Nemotron
            return SwarmRoute.CHAT;
        }

        var responseBuilder = new StringBuilder();
        try
        {
            await foreach (var chunk in routerProvider.StreamChatAsync(RouterModelId, messages, cancellationToken))
            {
                responseBuilder.Append(chunk);
            }
        }
        catch
        {
            return SwarmRoute.CHAT;
        }

        var responseText = responseBuilder.ToString().Trim().ToUpperInvariant();
        if (responseText.Contains("DEV")) return SwarmRoute.DEV;
        if (responseText.Contains("SYS")) return SwarmRoute.SYS;

        return SwarmRoute.CHAT;
    }
}
