using System.Text.Json.Serialization;

namespace GamingAgent.Models;

public record SteamGame(
    [property: JsonPropertyName("appid")] int AppId,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("playtime_forever")] int PlaytimeMinutes,
    [property: JsonPropertyName("img_icon_url")] string? IconUrl
);

public record SteamResponse(
    [property: JsonPropertyName("response")] SteamResponseInner? Response
);

public record SteamResponseInner(
    [property: JsonPropertyName("games")] List<SteamGame>? Games,
    [property: JsonPropertyName("game_count")] int GameCount
);

public record GfnGame(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("steamUrl")] string? SteamUrl,
    [property: JsonPropertyName("steamAppId")] int? SteamAppId,
    [property: JsonPropertyName("status")] string? Status,
    [property: JsonPropertyName("genres")] List<string>? Genres,
    [property: JsonPropertyName("description")] string? Description,
    [property: JsonPropertyName("publisher")] string? Publisher,
    [property: JsonPropertyName("releaseYear")] int? ReleaseYear
);

public record EnrichedGame(
    int AppId,
    string Name,
    bool OnGfn,
    string? GfnId,
    List<string> Genres,
    string? Description,
    string? Publisher,
    int PlaytimeMinutes,
    string HeaderImage,
    string CapsuleImage,
    string SteamUrl,
    string? GfnUrl,
    bool IsFavorite,
    bool IsPinned
);

public record FavoriteEntry(int AppId, bool IsFavorite, bool IsPinned);

public record CheapSharkDeal(
    [property: JsonPropertyName("storeID")] string StoreId,
    [property: JsonPropertyName("price")] string Price,
    [property: JsonPropertyName("retailPrice")] string RetailPrice,
    [property: JsonPropertyName("savings")] string Savings
);

public record CheapSharkInfo(
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("thumb")] string Thumb,
    [property: JsonPropertyName("cheapestPriceEver")] CheapSharkCheapest? CheapestEver
);

public record CheapSharkCheapest(
    [property: JsonPropertyName("price")] string Price,
    [property: JsonPropertyName("date")] long Date
);

public record CheapSharkGameDetail(
    [property: JsonPropertyName("info")] CheapSharkInfo? Info,
    [property: JsonPropertyName("deals")] List<CheapSharkDeal>? Deals
);

public class LucilleEvalResult
{
    public List<string> GenreFilters      { get; init; } = new();
    public List<string> PinGames          { get; init; } = new();
    public string       SortBy            { get; init; } = "playtime";
    public List<string> FavoriteGames     { get; init; } = new();
    public string       Summary           { get; init; } = "";
    public List<string> SystemSuggestions { get; init; } = new();
    public List<TopGame> TopGames         { get; init; } = new();
    public string?      Error             { get; init; }
}

public record TopGame(string Name, double Hours, bool OnGfn)
{
    public TopGame() : this("", 0, false) {}
    public string Name { get; init; } = Name;
    public double Hours { get; init; } = Hours;
    public bool OnGfn { get; init; } = OnGfn;
}

// ── Lucille Chat ─────────────────────────────────────────────────────────────

public record ChatMessage(
    [property: JsonPropertyName("role")] string Role,
    [property: JsonPropertyName("content")] string Content
);

public record LucilleChatRequest(
    [property: JsonPropertyName("messages")] List<ChatMessage> Messages,
    [property: JsonPropertyName("sessionId")] string? SessionId = null
);

public record LucilleChatResponse(
    [property: JsonPropertyName("reply")] string Reply,
    [property: JsonPropertyName("sessionId")] string SessionId,
    [property: JsonPropertyName("error")] string? Error = null
);

public record ChatHistoryEntry(
    [property: JsonPropertyName("id")] long Id,
    [property: JsonPropertyName("role")] string Role,
    [property: JsonPropertyName("content")] string Content,
    [property: JsonPropertyName("createdAt")] string CreatedAt
);
