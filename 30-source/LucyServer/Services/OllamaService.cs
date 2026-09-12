using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LucyServer.Services;

public interface IOllamaService
{
    Task<List<string>> ListLocalModelsAsync();
    Task<object> StartPullAsync(string modelName);
    object GetPullStatus();
}

public class OllamaService : IOllamaService
{
    private readonly HttpClient _http;

    private static readonly object _lock = new();
    private static PullStatus _status = new() { Status = "idle", Model = "", Message = "", Percentage = 0 };

    public OllamaService(HttpClient http)
    {
        _http = http;
        _http.BaseAddress = new Uri("http://127.0.0.1:11434");
        _http.Timeout = TimeSpan.FromSeconds(10);
    }

    public async Task<List<string>> ListLocalModelsAsync()
    {
        try
        {
            var response = await _http.GetFromJsonAsync<OllamaTagsResponse>("/api/tags");
            return response?.Models?.Select(m => m.Name).ToList() ?? new List<string>();
        }
        catch
        {
            return new List<string>();
        }
    }

    public Task<object> StartPullAsync(string modelName)
    {
        lock (_lock)
        {
            if (_status.Status == "pulling")
                return Task.FromResult<object>(new { error = "Another model is currently being pulled" });

            _status = new PullStatus { Status = "pulling", Model = modelName, Message = "Initializing pull...", Percentage = 0 };
        }

        _ = Task.Run(() => DoPullAsync(modelName));
        return Task.FromResult<object>(new { status = "ok", message = $"Started pulling {modelName}" });
    }

    public object GetPullStatus()
    {
        lock (_lock)
        {
            return new { status = _status.Status, model = _status.Model, message = _status.Message, percentage = _status.Percentage };
        }
    }

    private async Task DoPullAsync(string modelName)
    {
        try
        {
            var pullClient = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:11434"), Timeout = TimeSpan.FromMinutes(60) };
            var request = new HttpRequestMessage(HttpMethod.Post, "/api/pull")
            {
                Content = JsonContent.Create(new { name = modelName, stream = true })
            };

            using var response = await pullClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
            if (!response.IsSuccessStatusCode)
            {
                lock (_lock) { _status = new PullStatus { Status = "error", Model = modelName, Message = $"HTTP {(int)response.StatusCode}", Percentage = 0 }; }
                return;
            }

            using var stream = await response.Content.ReadAsStreamAsync();
            using var reader = new StreamReader(stream);

            while (!reader.EndOfStream)
            {
                var line = await reader.ReadLineAsync();
                if (string.IsNullOrWhiteSpace(line)) continue;

                var chunk = JsonSerializer.Deserialize<OllaPullChunk>(line, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (chunk == null) continue;

                var pct = chunk.Total > 0 ? (int)((double)chunk.Completed / chunk.Total * 100) : 0;
                lock (_lock)
                {
                    _status.Message = pct > 0 ? $"{chunk.Status} ({pct}%)" : chunk.Status ?? "";
                    _status.Percentage = pct;
                }
            }

            lock (_lock) { _status = new PullStatus { Status = "success", Model = modelName, Message = "Model pulled successfully!", Percentage = 100 }; }
        }
        catch (Exception ex)
        {
            lock (_lock) { _status = new PullStatus { Status = "error", Model = modelName, Message = $"Error: {ex.Message}", Percentage = 0 }; }
        }
    }

    private class PullStatus
    {
        public string Status { get; set; } = "idle";
        public string Model { get; set; } = "";
        public string Message { get; set; } = "";
        public int Percentage { get; set; }
    }

    private class OllamaTagsResponse
    {
        [JsonPropertyName("models")]
        public List<OllamaModel>? Models { get; set; }
    }

    private class OllamaModel
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "";
    }

    private class OllaPullChunk
    {
        public string? Status { get; set; }
        public long Completed { get; set; }
        public long Total { get; set; }
    }
}
