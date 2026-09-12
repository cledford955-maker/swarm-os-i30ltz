using System.Text.Json.Serialization;

namespace LucyServer.Models;

public class RagDocument
{
    [JsonPropertyName("text")]
    public string Text { get; set; } = string.Empty;

    [JsonPropertyName("embedding")]
    public float[] Embedding { get; set; } = Array.Empty<float>();

    [JsonPropertyName("source")]
    public string? Source { get; set; }
}
