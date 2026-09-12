using System.Collections.Generic;

namespace LucyServer.Models;

public class LucyRequest
{
    public string ModelId { get; set; } = string.Empty;
    public List<ChatMessage> Messages { get; set; } = new();
    public bool AutoRoute { get; set; } = false;
}
