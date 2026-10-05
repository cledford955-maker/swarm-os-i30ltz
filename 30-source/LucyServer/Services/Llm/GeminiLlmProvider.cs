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

public class GeminiLlmProvider : ILlmProvider
{
    private readonly HttpClient _httpClient;
    private readonly string? _apiKey;

    public GeminiLlmProvider(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        // Accepts both spellings. The settings panel writes "GEMINI_API_KEY";
        // this provider previously read only "GeminiApiKey", and .NET does not
        // map one to the other (only "__" is special in env var names), so a
        // key saved through the UI was invisible here. Missing is no longer
        // fatal at construction either: throwing here took down provider
        // enumeration for every model because ONE key was absent.
        _apiKey = SwarmSecrets.Lookup(configuration, "GeminiApiKey", "GEMINI_API_KEY");
        _httpClient.BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/models/");
    }

    public bool CanHandle(string modelId)
    {
        return modelId.StartsWith("gemini/");
    }

    public async IAsyncEnumerable<string> StreamChatAsync(string modelId, List<ChatMessage> messages, [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        var actualModelId = modelId.StartsWith("gemini/") ? modelId.Substring(7) : modelId;
        
        // Map messages to Gemini format
        var geminiContents = new List<object>();
        foreach (var msg in messages)
        {
            var role = msg.Role.ToLowerInvariant() == "user" ? "user" : "model";
            // Gemini doesn't use "system" role in the messages array in the same way, but it can be passed as system_instruction.
            // For simplicity here, we'll map system to user/model or just prepend it if needed.
            // Assuming standard chat completion structure here for simplicity, though real Gemini API is slightly different.
            geminiContents.Add(new
            {
                role = role,
                parts = new[] { new { text = msg.Content } }
            });
        }

        var requestBody = new
        {
            contents = geminiContents
        };

        RequireKey();
        var requestUri = $"{actualModelId}:streamGenerateContent?key={_apiKey}";
        var request = new HttpRequestMessage(HttpMethod.Post, requestUri)
        {
            Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json")
        };

        using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var reader = new StreamReader(stream);

        // Gemini streaming API returns a JSON array of chunk objects where each object has candidates -> content -> parts
        // or it's a stream of JSON objects. The exact format for streamGenerateContent with SSE is specific.
        // streamGenerateContent usually returns an array of chunks if not SSE, or with SSE it can be parsed.
        // Assuming chunked JSON array parsing:
        
        var jsonText = await reader.ReadToEndAsync();
        
        // We'll yield the whole thing for now or parse it simply since Gemini's stream is a JSON array.
        // This is a simplified parser for Gemini.
        var json = JsonDocument.Parse(jsonText);
        
        if (json.RootElement.ValueKind == JsonValueKind.Array)
        {
            foreach (var chunk in json.RootElement.EnumerateArray())
            {
                if (chunk.TryGetProperty("candidates", out var candidates) && candidates.GetArrayLength() > 0)
                {
                    var candidate = candidates[0];
                    if (candidate.TryGetProperty("content", out var content) && content.TryGetProperty("parts", out var parts) && parts.GetArrayLength() > 0)
                    {
                        var text = parts[0].GetProperty("text").GetString();
                        if (!string.IsNullOrEmpty(text))
                        {
                            yield return text;
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
                "No Gemini API key. Add GEMINI_API_KEY=<key> to "
                + SwarmSecrets.EnvFilePath
                + " (or save it in Settings), then restart LucyServer.");
        }
    }
}
