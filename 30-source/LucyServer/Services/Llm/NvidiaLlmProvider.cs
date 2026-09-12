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
using LucyServer.Models;
using Microsoft.Extensions.Configuration;

namespace LucyServer.Services.Llm;

public class NvidiaLlmProvider : ILlmProvider
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;

    public NvidiaLlmProvider(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _apiKey = configuration["NvidiaApiKey"] ?? throw new ArgumentNullException("NvidiaApiKey is missing from configuration.");
        _httpClient.BaseAddress = new Uri("https://integrate.api.nvidia.com/v1/");
    }

    public bool CanHandle(string modelId)
    {
        return modelId.StartsWith("nvidia/");
    }

    public async IAsyncEnumerable<string> StreamChatAsync(string modelId, List<ChatMessage> messages, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        // For Nvidia API, if the modelId starts with "nvidia/", we might need to keep it or replace it depending on the exact API specification.
        // Usually OpenRouter uses "nvidia/nemotron...", but Nvidia's native API might just expect the model name, e.g., "meta/llama3-70b-instruct" or "nvidia/nemotron-4-340b-instruct". 
        // We'll pass the full string, since Nvidia APIs usually include the namespace like "meta/llama3-8b-instruct"
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
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);

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
}
