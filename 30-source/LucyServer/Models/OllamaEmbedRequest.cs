using System.Text.Json.Serialization;

namespace LucyServer.Models;

public class OllamaEmbedRequest
{
    [JsonPropertyName("model")]
    public string Model { get; set; } = "nomic-embed-text";

    [JsonPropertyName("input")]
    public string Input { get; set; } = string.Empty;
}
