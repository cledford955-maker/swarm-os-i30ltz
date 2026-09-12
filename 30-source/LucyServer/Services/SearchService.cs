using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace LucyServer.Services;

public interface ISearchService
{
    Task<List<SearchResult>> SearchWebAsync(string query, int maxResults = 8);
    Task<object> GetDailyBriefAsync();
}

public class SearchService : ISearchService
{
    private readonly HttpClient _http;
    private readonly INewsAndGamesService _news;

    // GoogleWorkspaceService runs on 8399 — optional, graceful degradation if not up
    private const string GoogleSvcBase = "http://127.0.0.1:8399";

    public SearchService(HttpClient http, INewsAndGamesService news)
    {
        _http = http;
        _http.Timeout = TimeSpan.FromSeconds(10);
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 LucyServer/1.0");
        _news = news;
    }

    // ── Web Search (DuckDuckGo lite HTML scrape) ──────────────────────────

    public async Task<List<SearchResult>> SearchWebAsync(string query, int maxResults = 8)
    {
        var results = new List<SearchResult>();

        // 1. Try DDG Instant Answer API for a quick abstract
        try
        {
            var encoded = Uri.EscapeDataString(query);
            var ddgJson = await _http.GetStringAsync(
                $"https://api.duckduckgo.com/?q={encoded}&format=json&no_html=1&skip_disambig=1");
            var doc = JsonDocument.Parse(ddgJson);
            var abstract_ = doc.RootElement.TryGetProperty("Abstract", out var ab) ? ab.GetString() : null;
            var url = doc.RootElement.TryGetProperty("AbstractURL", out var au) ? au.GetString() : null;
            var source = doc.RootElement.TryGetProperty("AbstractSource", out var src) ? src.GetString() : null;

            if (!string.IsNullOrEmpty(abstract_))
                results.Add(new SearchResult { Title = source ?? query, Url = url ?? "", Snippet = abstract_, Source = "DDG Instant" });

            // Related topics as additional results
            if (doc.RootElement.TryGetProperty("RelatedTopics", out var topics))
            {
                foreach (var topic in topics.EnumerateArray().Take(maxResults - 1))
                {
                    var text = topic.TryGetProperty("Text", out var t) ? t.GetString() : null;
                    var href = topic.TryGetProperty("FirstURL", out var f) ? f.GetString() : null;
                    if (!string.IsNullOrEmpty(text) && !string.IsNullOrEmpty(href))
                        results.Add(new SearchResult { Title = text[..Math.Min(80, text.Length)], Url = href, Snippet = text, Source = "DDG" });
                }
            }
        }
        catch { }

        // 2. Scrape DDG lite for real organic results if instant answer was empty
        if (results.Count < 3)
        {
            try
            {
                var encoded = Uri.EscapeDataString(query);
                var html = await _http.GetStringAsync($"https://lite.duckduckgo.com/lite/?q={encoded}");

                // Extract result links and snippets from DDG lite HTML
                var linkPattern = new Regex(@"<a[^>]+href=""(https?://[^""]+)""[^>]*>([^<]+)</a>", RegexOptions.IgnoreCase);
                var snippetPattern = new Regex(@"<td[^>]+class=""result-snippet""[^>]*>(.*?)</td>", RegexOptions.Singleline | RegexOptions.IgnoreCase);

                var links = linkPattern.Matches(html);
                var snippets = snippetPattern.Matches(html);

                for (int i = 0; i < Math.Min(links.Count, maxResults); i++)
                {
                    var url = links[i].Groups[1].Value;
                    var title = HtmlDecode(links[i].Groups[2].Value.Trim());
                    var snippet = i < snippets.Count
                        ? Regex.Replace(snippets[i].Groups[1].Value, "<[^>]+>", "").Trim()
                        : "";

                    if (!results.Any(r => r.Url == url))
                        results.Add(new SearchResult { Title = title, Url = url, Snippet = snippet, Source = "DDG" });
                }
            }
            catch { }
        }

        return results.Take(maxResults).ToList();
    }

    // ── Daily Brief ───────────────────────────────────────────────────────

    public async Task<object> GetDailyBriefAsync()
    {
        var briefTasks = new
        {
            emails    = TryGetEmailsAsync(),
            calendar  = TryGetCalendarAsync(),
            devNews   = _news.GetDevNewsAsync(),
            weather   = GetWeatherAsync()
        };

        await Task.WhenAll(briefTasks.emails, briefTasks.calendar, briefTasks.devNews, briefTasks.weather);

        return new
        {
            emails        = briefTasks.emails.Result,
            calendar      = briefTasks.calendar.Result,
            dev_news      = briefTasks.devNews.Result.Take(5),
            weather       = briefTasks.weather.Result,
            generated_at  = DateTime.UtcNow.ToString("O")
        };
    }

    // Call GoogleWorkspaceService for Gmail — gracefully returns empty if not authenticated
    private async Task<object> TryGetEmailsAsync()
    {
        try
        {
            var status = await _http.GetFromJsonAsync<JsonElement>($"{GoogleSvcBase}/auth/status");
            if (!status.TryGetProperty("authenticated", out var auth) || !auth.GetBoolean())
                return new { authenticated = false, messages = Array.Empty<object>() };

            var inbox = await _http.GetFromJsonAsync<JsonElement>($"{GoogleSvcBase}/gmail/inbox?maxResults=5&unreadOnly=true");
            return new { authenticated = true, messages = inbox.TryGetProperty("messages", out var msgs) ? msgs : default };
        }
        catch
        {
            return new { authenticated = false, messages = Array.Empty<object>() };
        }
    }

    private async Task<object> TryGetCalendarAsync()
    {
        try
        {
            var status = await _http.GetFromJsonAsync<JsonElement>($"{GoogleSvcBase}/auth/status");
            if (!status.TryGetProperty("authenticated", out var auth) || !auth.GetBoolean())
                return new { authenticated = false, events = Array.Empty<object>() };

            var events = await _http.GetFromJsonAsync<JsonElement>($"{GoogleSvcBase}/cal/events?maxResults=5&daysAhead=1&calendarId=primary");
            return new { authenticated = true, events = events.TryGetProperty("events", out var ev) ? ev : default };
        }
        catch
        {
            return new { authenticated = false, events = Array.Empty<object>() };
        }
    }

    // Open-Meteo — free, no API key
    private async Task<object> GetWeatherAsync()
    {
        try
        {
            // Default coords — user can override via WEATHER_LAT/WEATHER_LON env vars
            var lat = Environment.GetEnvironmentVariable("WEATHER_LAT") ?? "41.8781";
            var lon = Environment.GetEnvironmentVariable("WEATHER_LON") ?? "-87.6298";

            var url = $"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}" +
                      "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m" +
                      "&temperature_unit=fahrenheit&wind_speed_unit=mph&forecast_days=1";

            var data = await _http.GetFromJsonAsync<JsonElement>(url);
            var current = data.TryGetProperty("current", out var c) ? c : default;

            return new
            {
                temperature_f  = current.TryGetProperty("temperature_2m", out var t) ? t.GetDouble() : 0,
                feels_like_f   = current.TryGetProperty("apparent_temperature", out var fl) ? fl.GetDouble() : 0,
                wind_mph       = current.TryGetProperty("wind_speed_10m", out var w) ? w.GetDouble() : 0,
                condition      = WmoCodeToDescription(current.TryGetProperty("weather_code", out var wc) ? wc.GetInt32() : 0)
            };
        }
        catch
        {
            return new { error = "Weather unavailable" };
        }
    }

    private static string WmoCodeToDescription(int code) => code switch
    {
        0 => "Clear sky",
        1 or 2 or 3 => "Partly cloudy",
        45 or 48 => "Foggy",
        51 or 53 or 55 => "Drizzle",
        61 or 63 or 65 => "Rain",
        71 or 73 or 75 => "Snow",
        80 or 81 or 82 => "Rain showers",
        95 => "Thunderstorm",
        _ => "Mixed conditions"
    };

    private static string HtmlDecode(string s) =>
        s.Replace("&amp;", "&").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&quot;", "\"").Replace("&#39;", "'");
}

public class SearchResult
{
    public string Title { get; set; } = "";
    public string Url { get; set; } = "";
    public string Snippet { get; set; } = "";
    public string Source { get; set; } = "";
}
