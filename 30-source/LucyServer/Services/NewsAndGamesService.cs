using System.Net.Http.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace LucyServer.Services;

public interface INewsAndGamesService
{
    Task<List<NewsItem>> GetNewsAsync();
    Task<List<DealItem>> GetDealsAsync();
    Task<List<NewsItem>> GetNewsFeedAsync();
    Task<List<NewsItem>> GetDevNewsAsync();
    Task<object> GetSteamLibraryAsync();
    Task<object> GetGamePricesAsync(string gameId);
    Task<object> GetGameInfoAsync(string gameId);
    Task<List<string>> GetGfnGamesAsync();
    object OptimizeGfn(string game);
}

public class NewsAndGamesService : INewsAndGamesService
{
    private readonly HttpClient _http;

    private static (List<NewsItem> Data, DateTime UpdatedAt) _newsCache = (new(), DateTime.MinValue);
    private static (List<DealItem> Data, DateTime UpdatedAt) _dealsCache = (new(), DateTime.MinValue);
    private static (List<NewsItem> Data, DateTime UpdatedAt) _feedCache = (new(), DateTime.MinValue);
    private static (List<NewsItem> Data, DateTime UpdatedAt) _devNewsCache = (new(), DateTime.MinValue);
    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(3);
    private static readonly TimeSpan DevCacheTtl = TimeSpan.FromMinutes(15);

    public NewsAndGamesService(HttpClient http)
    {
        _http = http;
        _http.Timeout = TimeSpan.FromSeconds(12);
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("LucyServer/1.0");
    }

    public async Task<List<NewsItem>> GetNewsAsync()
    {
        if (DateTime.UtcNow - _newsCache.UpdatedAt < CacheTtl && _newsCache.Data.Count > 0)
            return _newsCache.Data;

        var feeds = new Dictionary<string, string>
        {
            ["GameSpot"] = "https://www.gamespot.com/feeds/news/",
            ["Boiling Steam"] = "https://boilingsteam.com/feed/"
        };

        var items = await FetchRssFeeds(feeds, "gaming");
        _newsCache = (items, DateTime.UtcNow);
        return items;
    }

    public async Task<List<DealItem>> GetDealsAsync()
    {
        if (DateTime.UtcNow - _dealsCache.UpdatedAt < CacheTtl && _dealsCache.Data.Count > 0)
            return _dealsCache.Data;

        try
        {
            var deals = await _http.GetFromJsonAsync<List<CheapSharkDeal>>(
                "https://www.cheapshark.com/api/1.0/deals?storeID=1&upperPrice=15");

            var result = (deals ?? new()).Take(15).Select(d => new DealItem
            {
                Title = d.Title,
                SalePrice = d.SalePrice,
                NormalPrice = d.NormalPrice,
                Savings = d.Savings,
                StoreId = d.StoreID,
                DealId = d.DealID
            }).ToList();

            _dealsCache = (result, DateTime.UtcNow);
            return result;
        }
        catch
        {
            return new List<DealItem>();
        }
    }

    public async Task<List<NewsItem>> GetNewsFeedAsync()
    {
        if (DateTime.UtcNow - _feedCache.UpdatedAt < CacheTtl && _feedCache.Data.Count > 0)
            return _feedCache.Data;

        var feeds = new Dictionary<string, string>
        {
            ["GameSpot"] = "https://www.gamespot.com/feeds/news/",
            ["Boiling Steam"] = "https://boilingsteam.com/feed/",
            ["Linux Gaming News"] = "https://linuxgaming.life/feed/"
        };

        var items = await FetchRssFeeds(feeds, "gaming");
        _feedCache = (items, DateTime.UtcNow);
        return items;
    }

    public async Task<List<NewsItem>> GetDevNewsAsync()
    {
        if (DateTime.UtcNow - _devNewsCache.UpdatedAt < DevCacheTtl && _devNewsCache.Data.Count > 0)
            return _devNewsCache.Data;

        var feeds = new Dictionary<string, string>
        {
            ["Google Dev Blog"] = "https://developers.googleblog.com/feeds/posts/default",
            ["Android Developers"] = "https://android-developers.googleblog.com/feeds/posts/default",
            ["NVIDIA Developer News"] = "https://developer.nvidia.com/blog/feed/"
        };

        var items = await FetchRssFeeds(feeds, "dev");
        _devNewsCache = (items, DateTime.UtcNow);
        return items;
    }

    public async Task<object> GetSteamLibraryAsync()
    {
        var steamKey = Environment.GetEnvironmentVariable("STEAM_API_KEY");
        var steamId = Environment.GetEnvironmentVariable("STEAM_ID64");

        if (string.IsNullOrEmpty(steamKey) || string.IsNullOrEmpty(steamId))
            return new { error = "Steam API key or Steam ID not configured", games = new List<object>() };

        try
        {
            var url = $"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={steamKey}&steamid={steamId}&include_appinfo=true&include_played_free_games=true&format=json";
            var response = await _http.GetFromJsonAsync<SteamLibraryResponse>(url);
            var games = response?.Response?.Games ?? new();

            var enriched = games.Select(g => new
            {
                appid = g.Appid,
                name = g.Name,
                playtime_forever = g.PlaytimeForever,
                header_image = $"https://cdn.akamai.steamstatic.com/steam/apps/{g.Appid}/header.jpg",
                capsule_image = $"https://cdn.akamai.steamstatic.com/steam/apps/{g.Appid}/capsule_616x353.jpg",
                steam_url = $"steam://rungameid/{g.Appid}",
                store_url = $"https://store.steampowered.com/app/{g.Appid}/"
            }).ToList();

            return new { games = enriched, total = enriched.Count, source = "steam" };
        }
        catch (Exception ex)
        {
            return new { error = ex.Message, games = new List<object>() };
        }
    }

    public async Task<object> GetGamePricesAsync(string gameId)
    {
        try
        {
            var url = $"https://www.cheapshark.com/api/1.0/games?id={gameId}";
            var data = await _http.GetFromJsonAsync<CheapSharkGameDetail>(url);
            if (data?.Deals == null) return new { error = "No deals found" };

            var sorted = data.Deals.OrderBy(d => double.TryParse(d.Price, out var p) ? p : double.MaxValue).ToList();
            return new
            {
                cheapest = sorted.FirstOrDefault(),
                deals = sorted.Take(5),
                info = data.Info
            };
        }
        catch (Exception ex)
        {
            return new { error = ex.Message };
        }
    }

    public async Task<object> GetGameInfoAsync(string gameId)
    {
        try
        {
            var url = $"https://store.steampowered.com/api/appdetails?appids={gameId}";
            var raw = await _http.GetStringAsync(url);
            return new { raw };
        }
        catch (Exception ex)
        {
            return new { error = ex.Message };
        }
    }

    public async Task<List<string>> GetGfnGamesAsync()
    {
        // GeForce Now doesn't have a public API — return commonly known supported titles
        await Task.CompletedTask;
        return new List<string>
        {
            "Cyberpunk 2077", "Fortnite", "Minecraft", "Apex Legends",
            "The Witcher 3", "Control", "Dying Light 2", "Red Dead Redemption 2",
            "Assassin's Creed Valhalla", "Watch Dogs: Legion"
        };
    }

    public object OptimizeGfn(string game)
    {
        return new
        {
            status = "ok",
            game,
            recommendations = new[]
            {
                "Enable RTX On for ray tracing if supported",
                "Set resolution to 1080p for best streaming performance",
                "Use wired Ethernet for lowest latency",
                "Enable DLSS Quality mode for performance/quality balance",
                "Close background applications to free bandwidth"
            }
        };
    }

    private async Task<List<NewsItem>> FetchRssFeeds(Dictionary<string, string> feeds, string category)
    {
        var results = new List<NewsItem>();
        var tasks = feeds.Select(async kvp =>
        {
            try
            {
                var content = await _http.GetStringAsync(kvp.Value);
                var items = ParseRss(content, kvp.Key, category);
                lock (results) { results.AddRange(items); }
            }
            catch { }
        });

        await Task.WhenAll(tasks);
        return results.OrderByDescending(i => i.PubDate).ToList();
    }

    private static List<NewsItem> ParseRss(string xml, string source, string category)
    {
        var items = new List<NewsItem>();
        try
        {
            var doc = XDocument.Parse(xml);
            XNamespace atom = "http://www.w3.org/2005/Atom";

            // Try RSS format
            var channel = doc.Descendants("channel").FirstOrDefault();
            if (channel != null)
            {
                foreach (var item in channel.Elements("item").Take(5))
                {
                    var title = item.Element("title")?.Value ?? "";
                    var link = item.Element("link")?.Value ?? "";
                    var pubDate = item.Element("pubDate")?.Value ?? "";
                    var description = item.Element("description")?.Value ?? "";
                    var snippet = Regex.Replace(description, "<[^>]+>", "");
                    if (snippet.Length > 150) snippet = snippet[..150] + "...";

                    items.Add(new NewsItem { Source = source, Title = title, Link = link, PubDate = pubDate, Snippet = snippet, Category = category });
                }
                return items;
            }

            // Try Atom format
            foreach (var entry in doc.Descendants(atom + "entry").Take(5))
            {
                var title = entry.Element(atom + "title")?.Value ?? "";
                var link = entry.Elements(atom + "link").FirstOrDefault(l => l.Attribute("rel")?.Value != "edit")?.Attribute("href")?.Value ?? "";
                var published = entry.Element(atom + "published")?.Value ?? entry.Element(atom + "updated")?.Value ?? "";
                var summary = entry.Element(atom + "summary")?.Value ?? "";
                var snippet = Regex.Replace(summary, "<[^>]+>", "");
                if (snippet.Length > 150) snippet = snippet[..150] + "...";

                items.Add(new NewsItem { Source = source, Title = title, Link = link, PubDate = published, Snippet = snippet, Category = category });
            }
        }
        catch { }
        return items;
    }

    // DTOs
    private class CheapSharkDeal
    {
        [JsonPropertyName("title")] public string Title { get; set; } = "";
        [JsonPropertyName("salePrice")] public string SalePrice { get; set; } = "";
        [JsonPropertyName("normalPrice")] public string NormalPrice { get; set; } = "";
        [JsonPropertyName("savings")] public string Savings { get; set; } = "";
        [JsonPropertyName("storeID")] public string StoreID { get; set; } = "";
        [JsonPropertyName("dealID")] public string DealID { get; set; } = "";
    }

    private class CheapSharkGameDetail
    {
        [JsonPropertyName("info")] public object? Info { get; set; }
        [JsonPropertyName("deals")] public List<CheapSharkDealEntry>? Deals { get; set; }
    }

    private class CheapSharkDealEntry
    {
        [JsonPropertyName("price")] public string Price { get; set; } = "";
        [JsonPropertyName("retailPrice")] public string RetailPrice { get; set; } = "";
        [JsonPropertyName("storeID")] public string StoreId { get; set; } = "";
    }

    private class SteamLibraryResponse
    {
        [JsonPropertyName("response")] public SteamResponseInner? Response { get; set; }
    }

    private class SteamResponseInner
    {
        [JsonPropertyName("games")] public List<SteamGame>? Games { get; set; }
    }

    private class SteamGame
    {
        [JsonPropertyName("appid")] public int Appid { get; set; }
        [JsonPropertyName("name")] public string Name { get; set; } = "";
        [JsonPropertyName("playtime_forever")] public int PlaytimeForever { get; set; }
    }
}

public class NewsItem
{
    public string Source { get; set; } = "";
    public string Title { get; set; } = "";
    public string Link { get; set; } = "";
    public string PubDate { get; set; } = "";
    public string Snippet { get; set; } = "";
    public string Category { get; set; } = "";
}

public class DealItem
{
    public string Title { get; set; } = "";
    public string SalePrice { get; set; } = "";
    public string NormalPrice { get; set; } = "";
    public string Savings { get; set; } = "";
    public string StoreId { get; set; } = "";
    public string DealId { get; set; } = "";
}
