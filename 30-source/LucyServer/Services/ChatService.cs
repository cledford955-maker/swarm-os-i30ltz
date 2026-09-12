using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using LucyServer.Models;

namespace LucyServer.Services;

public interface IChatService
{
    Task<ChatData> LoadAllChatsAsync(string? username = null);
    Task SaveAllChatsAsync(ChatData data, string? username = null);
}

public class ChatService : IChatService
{
    private readonly string _baseMemoryDb = "/mnt/i30ltz-brains/AI/memory.json";
    
    // Using a simple lock for file operations since Minimal APIs can be concurrent
    private static readonly SemaphoreSlim _fileLock = new SemaphoreSlim(1, 1);

    private string GetSharedMemoryDb(string? username)
    {
        // Currently matching the logic where role == family uses a per-user DB
        // For simplicity, we just suffix if username is provided.
        if (!string.IsNullOrEmpty(username))
        {
            var dir = Path.GetDirectoryName(_baseMemoryDb);
            var name = Path.GetFileNameWithoutExtension(_baseMemoryDb);
            var ext = Path.GetExtension(_baseMemoryDb);
            return Path.Combine(dir ?? "", $"{name}_{username}{ext}");
        }
        return _baseMemoryDb;
    }

    public async Task<ChatData> LoadAllChatsAsync(string? username = null)
    {
        var defaultData = new ChatData
        {
            ActiveChatId = "default",
            Chats = new Dictionary<string, ChatInfo>
            {
                { "default", new ChatInfo { Title = "Main Chat", History = new(), Pinned = false, Privacy = "shared" } }
            }
        };

        var filePath = GetSharedMemoryDb(username);

        await _fileLock.WaitAsync();
        try
        {
            if (File.Exists(filePath))
            {
                try
                {
                    var json = await File.ReadAllTextAsync(filePath);
                    var data = JsonSerializer.Deserialize<ChatData>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    if (data != null && data.Chats != null)
                    {
                        defaultData = data;
                    }
                    else
                    {
                        // Handle case where it might be a List<ChatMessage> legacy array
                        var legacyList = JsonSerializer.Deserialize<List<ChatMessage>>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                        if (legacyList != null)
                        {
                            defaultData.Chats["default"].History = legacyList;
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error loading shared chats: {ex.Message}");
                }
            }
        }
        finally
        {
            _fileLock.Release();
        }

        // Normalize
        foreach (var chat in defaultData.Chats.Values)
        {
            if (string.IsNullOrEmpty(chat.Privacy)) chat.Privacy = "shared";
        }

        return defaultData;
    }

    public async Task SaveAllChatsAsync(ChatData data, string? username = null)
    {
        var filePath = GetSharedMemoryDb(username);
        var dir = Path.GetDirectoryName(filePath);

        await _fileLock.WaitAsync();
        try
        {
            if (dir != null && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(filePath, json);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error saving shared chats: {ex.Message}");
        }
        finally
        {
            _fileLock.Release();
        }
    }
}
