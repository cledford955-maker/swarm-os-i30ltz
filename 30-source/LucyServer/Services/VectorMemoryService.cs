using System.Text.Json;
using LucyServer.Models;
using Microsoft.Extensions.Logging;

namespace LucyServer.Services;

public class VectorMemoryService : IVectorMemoryService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<VectorMemoryService> _logger;
    private readonly string _ragStorePath;

    public VectorMemoryService(HttpClient httpClient, ILogger<VectorMemoryService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        // In a real app, this should probably come from configuration
        _ragStorePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bolt", "memory", "rag_store.json");
    }

    public async Task<string> GetVectorContextAsync(string prompt, string baseOllamaUrl = "http://127.0.0.1:11434", string model = "nomic-embed-text")
    {
        try
        {
            // 1. Fetch query embedding
            var requestBody = new OllamaEmbedRequest { Model = model, Input = prompt };
            var response = await _httpClient.PostAsJsonAsync($"{baseOllamaUrl.TrimEnd('/')}/api/embed", requestBody);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Ollama API returned status code {StatusCode}", response.StatusCode);
                return string.Empty;
            }

            var embedResponse = await response.Content.ReadFromJsonAsync<OllamaEmbedResponse>();
            if (embedResponse?.Embeddings == null || embedResponse.Embeddings.Length == 0)
            {
                _logger.LogWarning("No embeddings returned from Ollama.");
                return string.Empty;
            }

            var queryVector = embedResponse.Embeddings[0];

            // 2. Load RAG store
            if (!File.Exists(_ragStorePath))
            {
                _logger.LogWarning("RAG store not found at {Path}", _ragStorePath);
                return string.Empty;
            }

            var storeJson = await File.ReadAllTextAsync(_ragStorePath);
            var store = JsonSerializer.Deserialize<List<RagDocument>>(storeJson);

            if (store == null || store.Count == 0)
            {
                return string.Empty;
            }

            // 3. Compute cosine similarity
            var scoredDocs = new List<(double Score, string Text)>();

            foreach (var doc in store)
            {
                if (doc.Embedding == null || doc.Embedding.Length == 0)
                    continue;

                double dotProduct = 0;
                double mag1 = 0;
                double mag2 = 0;

                for (int i = 0; i < queryVector.Length && i < doc.Embedding.Length; i++)
                {
                    dotProduct += queryVector[i] * doc.Embedding[i];
                    mag1 += queryVector[i] * queryVector[i];
                    mag2 += doc.Embedding[i] * doc.Embedding[i];
                }

                mag1 = Math.Sqrt(mag1);
                mag2 = Math.Sqrt(mag2);

                double score = (mag1 > 0 && mag2 > 0) ? dotProduct / (mag1 * mag2) : 0;

                if (score >= 0.35) // Threshold
                {
                    scoredDocs.Add((score, doc.Text));
                }
            }

            // 4. Sort and return top 3
            var topDocs = scoredDocs
                .OrderByDescending(x => x.Score)
                .Take(3)
                .Select(x => x.Text)
                .ToList();

            if (topDocs.Count > 0)
            {
                return "\n\n[RETRIEVED CONVERSATION MEMORY]:\n" + string.Join("\n---\n", topDocs);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[RAG AUTO] Error processing vector context");
        }

        return string.Empty;
    }
}
