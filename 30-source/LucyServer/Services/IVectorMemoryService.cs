namespace LucyServer.Services;

public interface IVectorMemoryService
{
    Task<string> GetVectorContextAsync(string prompt, string baseOllamaUrl = "http://127.0.0.1:11434", string model = "nomic-embed-text");
}
