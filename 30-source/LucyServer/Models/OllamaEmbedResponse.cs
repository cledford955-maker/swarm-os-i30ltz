using System.Text.Json.Serialization;

namespace LucyServer.Models;

public class OllamaEmbedResponse
{
    [JsonPropertyName("embeddings")]
    public float[][] Embeddings { get; set; } = Array.Empty<float[]>();
}
