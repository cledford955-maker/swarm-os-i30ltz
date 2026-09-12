using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using LucyServer.Models;
using Microsoft.Extensions.Configuration;

namespace LucyServer.Services.Llm;

public class OllamaLlmProvider : ILlmProvider
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;

    public OllamaLlmProvider(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _baseUrl = configuration["OllamaBaseUrl"] ?? "http://127.0.0.1:11434";
        _httpClient.BaseAddress = new Uri(_baseUrl);
    }

    public bool CanHandle(string modelId)
    {
        // Default models that don't have a specific provider prefix usually fall to Ollama
        // Specifically handled if it doesn't contain a slash, or is explicitly local
        return !modelId.Contains("/");
    }

    public async IAsyncEnumerable<string> StreamChatAsync(string modelId, List<ChatMessage> messages, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var requestBody = new
        {
            model = modelId,
            messages = messages,
            stream = true
        };

        var request = new HttpRequestMessage(HttpMethod.Post, "/api/chat")
        {
            Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json")
        };

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

            JsonDocument json;
            try
            {
                json = JsonDocument.Parse(line);
            }
            catch (JsonException)
            {
                continue;
            }

            if (json.RootElement.TryGetProperty("message", out var message) && message.TryGetProperty("content", out var content))
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
