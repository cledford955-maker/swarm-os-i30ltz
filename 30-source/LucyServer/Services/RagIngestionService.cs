using System.Net.Http.Json;
using System.Text.Json;
using LucyServer.Models;

namespace LucyServer.Services;

public interface IRagIngestionService
{
    Task<object> IngestTextAsync(string text, string source);
    Task<object> IngestFileAsync(string filePath);
    Task<object> ListDocumentsAsync();
    Task<object> DeleteDocumentAsync(string source);
    Task<object> ClearStoreAsync();
}

public class RagIngestionService : IRagIngestionService
{
    private readonly HttpClient _http;
    private readonly string _storePath;
    private readonly string _ollamaBase;
    private readonly SemaphoreSlim _lock = new(1, 1);

    private const string EmbedModel = "nomic-embed-text";
    private const int ChunkSize = 512;          // chars per chunk
    private const int ChunkOverlap = 64;

    public RagIngestionService(HttpClient http)
    {
        _http = http;
        _ollamaBase = Environment.GetEnvironmentVariable("OLLAMA_BASE_URL") ?? "http://127.0.0.1:11434";
        _storePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bolt", "memory", "rag_store.json");
        Directory.CreateDirectory(Path.GetDirectoryName(_storePath)!);
    }

    public async Task<object> IngestTextAsync(string text, string source)
    {
        if (string.IsNullOrWhiteSpace(text))
            return new { success = false, error = "No text provided" };

        var chunks = ChunkText(text, source);
        var embedded = await EmbedChunksAsync(chunks);
        var added = await AppendToStoreAsync(embedded, source);

        return new { success = true, source, chunks_added = added };
    }

    public async Task<object> IngestFileAsync(string filePath)
    {
        if (!File.Exists(filePath))
            return new { success = false, error = $"File not found: {filePath}" };

        var ext = Path.GetExtension(filePath).ToLower();
        string text;
        try
        {
            text = await File.ReadAllTextAsync(filePath);
        }
        catch (Exception ex)
        {
            return new { success = false, error = ex.Message };
        }

        return await IngestTextAsync(text, Path.GetFileName(filePath));
    }

    public async Task<object> ListDocumentsAsync()
    {
        var store = await LoadStoreAsync();
        var sources = store
            .GroupBy(d => d.Source ?? "unknown")
            .Select(g => new { source = g.Key, chunk_count = g.Count() })
            .ToList();
        return new { total_chunks = store.Count, documents = sources };
    }

    public async Task<object> DeleteDocumentAsync(string source)
    {
        await _lock.WaitAsync();
        try
        {
            var store = await LoadStoreAsync();
            var before = store.Count;
            store.RemoveAll(d => d.Source == source);
            await SaveStoreAsync(store);
            return new { success = true, removed = before - store.Count };
        }
        finally { _lock.Release(); }
    }

    public async Task<object> ClearStoreAsync()
    {
        await _lock.WaitAsync();
        try
        {
            await SaveStoreAsync(new List<RagDocument>());
            return new { success = true, message = "RAG store cleared" };
        }
        finally { _lock.Release(); }
    }

    // ── Chunking ──────────────────────────────────────────────────────────

    private static List<RagDocument> ChunkText(string text, string source)
    {
        var chunks = new List<RagDocument>();
        int start = 0;

        // Split on paragraph boundaries first, then hard-chunk by size
        var paragraphs = text.Split(new[] { "\n\n", "\r\n\r\n" }, StringSplitOptions.RemoveEmptyEntries);
        var buffer = "";

        foreach (var para in paragraphs)
        {
            if ((buffer + para).Length > ChunkSize && buffer.Length > 0)
            {
                chunks.Add(new RagDocument { Text = buffer.Trim(), Source = source });
                buffer = buffer.Length > ChunkOverlap ? buffer[^ChunkOverlap..] : "";
            }
            buffer += para + "\n\n";
        }

        if (!string.IsNullOrWhiteSpace(buffer))
            chunks.Add(new RagDocument { Text = buffer.Trim(), Source = source });

        return chunks;
    }

    // ── Embedding via Ollama ──────────────────────────────────────────────

    private async Task<List<RagDocument>> EmbedChunksAsync(List<RagDocument> chunks)
    {
        foreach (var chunk in chunks)
        {
            try
            {
                var req = new OllamaEmbedRequest { Model = EmbedModel, Input = chunk.Text };
                var resp = await _http.PostAsJsonAsync($"{_ollamaBase}/api/embed", req);
                if (!resp.IsSuccessStatusCode) continue;

                var embedResp = await resp.Content.ReadFromJsonAsync<OllamaEmbedResponse>();
                if (embedResp?.Embeddings?.Length > 0)
                    chunk.Embedding = embedResp.Embeddings[0];
            }
            catch { }
        }

        return chunks.Where(c => c.Embedding?.Length > 0).ToList();
    }

    // ── Store I/O ─────────────────────────────────────────────────────────

    private async Task<int> AppendToStoreAsync(List<RagDocument> newDocs, string source)
    {
        if (newDocs.Count == 0) return 0;

        await _lock.WaitAsync();
        try
        {
            var store = await LoadStoreAsync();
            // Remove old chunks from same source so re-ingest is idempotent
            store.RemoveAll(d => d.Source == source);
            store.AddRange(newDocs);
            await SaveStoreAsync(store);
            return newDocs.Count;
        }
        finally { _lock.Release(); }
    }

    private async Task<List<RagDocument>> LoadStoreAsync()
    {
        if (!File.Exists(_storePath)) return new();
        try
        {
            var json = await File.ReadAllTextAsync(_storePath);
            return JsonSerializer.Deserialize<List<RagDocument>>(json) ?? new();
        }
        catch { return new(); }
    }

    private async Task SaveStoreAsync(List<RagDocument> store)
    {
        var json = JsonSerializer.Serialize(store, new JsonSerializerOptions { WriteIndented = false });
        await File.WriteAllTextAsync(_storePath, json);
    }
}
