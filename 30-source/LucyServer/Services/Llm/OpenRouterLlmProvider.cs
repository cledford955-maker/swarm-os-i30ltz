using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using LucyServer.Models;

namespace LucyServer.Services.Llm;

public class OpenRouterLlmProvider : ILlmProvider
{
    private readonly HttpClient _httpClient;
    private readonly string? _apiKey;

    public OpenRouterLlmProvider(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        // Accepts both spellings. The settings panel writes "OPENROUTER_API_KEY";
        // this provider previously read only "OpenRouterApiKey", and .NET does not
        // map one to the other (only "__" is special in env var names), so a
        // key saved through the UI was invisible here. Missing is no longer
        // fatal at construction either: throwing here took down provider
        // enumeration for every model because ONE key was absent.
        _apiKey = SwarmSecrets.Lookup(configuration, "OpenRouterApiKey", "OPENROUTER_API_KEY");
        _httpClient.BaseAddress = new Uri("https://openrouter.ai/api/v1/");
    }

    public bool CanHandle(string modelId)
    {
        // OpenRouter models typically have a slash, e.g., "openai/gpt-4o", "anthropic/claude-3.5-sonnet", or "or/..."
        return modelId.Contains("/") || modelId.StartsWith("or/");
    }

    public async IAsyncEnumerable<string> StreamChatAsync(string modelId, List<ChatMessage> messages, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var requestBody = new
        {
            model = modelId,
            messages = messages,
            stream = true
        };

        var request = new HttpRequestMessage(HttpMethod.Post, "chat/completions")
        {
            Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json")
        };
        RequireKey();
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);

        // Optionally add headers for OpenRouter rankings
        request.Headers.Add("HTTP-Referer", "https://lucy.local");
        request.Headers.Add("X-Title", "Lucy");

        using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var reader = new StreamReader(stream);

        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var line = await reader.ReadLineAsync();
            if (line == null) break;

            if (string.IsNullOrWhiteSpace(line)) continue;
            
            if (line.StartsWith("data: "))
            {
                var data = line.Substring(6).Trim();
                if (data == "[DONE]") break;

                JsonDocument json;
                try
                {
                    json = JsonDocument.Parse(data);
                }
                catch (JsonException)
                {
                    continue;
                }

                if (json.RootElement.TryGetProperty("choices", out var choices) && choices.GetArrayLength() > 0)
                {
                    var choice = choices[0];
                    if (choice.TryGetProperty("delta", out var delta) && delta.TryGetProperty("content", out var content))
                    {
                        var contentString = content.GetString();
                        if (!string.IsNullOrEmpty(contentString))
                        {
                            yield return contentString;
                        }
                    }
                }
            }
        }
    }

    /// <summary>Fail with a clear, actionable message at call time
    /// rather than at construction.</summary>
    private void RequireKey()
    {
        if (string.IsNullOrWhiteSpace(_apiKey))
        {
            throw new InvalidOperationException(
                "No OpenRouter API key. Add OPENROUTER_API_KEY=<key> to "
                + SwarmSecrets.EnvFilePath
                + " (or save it in Settings), then restart LucyServer.");
        }
    }
}
