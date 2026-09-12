using System;
using System.Collections.Generic;

namespace LucyServer.Models;

public class ChatData
{
    public string ActiveChatId { get; set; } = "default";
    public Dictionary<string, ChatInfo> Chats { get; set; } = new();
}

public class ChatInfo
{
    public string Title { get; set; } = string.Empty;
    public List<ChatMessage> History { get; set; } = new();
    public bool Pinned { get; set; } = false;
    public string Privacy { get; set; } = "shared";
}

public class ChatNewRequest
{
    public string Title { get; set; } = string.Empty;
    public string Privacy { get; set; } = "shared";
}

public class ChatIdRequest
{
    public string ChatId { get; set; } = string.Empty;
}

public class ChatRenameRequest
{
    public string ChatId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
}

public class PullModelRequest
{
    public string Model { get; set; } = string.Empty;
}
