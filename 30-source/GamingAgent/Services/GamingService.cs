using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using GamingAgent.Models;
using Microsoft.Data.Sqlite;

namespace GamingAgent.Services;

public class GamingService
{
    private readonly HttpClient _http;
    private readonly string _dbPath;

    private static (List<GfnGame> Data, DateTime UpdatedAt) _gfnCache = (new(), DateTime.MinValue);
    private static readonly TimeSpan GfnCacheTtl = TimeSpan.FromHours(12);

    private const string GfnCatalogUrl =
        "https://static.nvidiagrid.net/supported-public-game-content/Games.json";

    public GamingService(HttpClient http, IConfiguration config)
    {
        _http = http;
        _http.Timeout = TimeSpan.FromSeconds(30);
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("SwarmOS-GamingAgent/1.0");

        _dbPath = config["GAMING_DB_PATH"] ?? "/etc/swarm_os/gaming.db";
        Directory.CreateDirectory(Path.GetDirectoryName(_dbPath)!);
        InitDb();
    }

    private void InitDb()
    {
        using var conn = OpenDb();
        conn.Execute(@"
            CREATE TABLE IF NOT EXISTS favorites (
                app_id INTEGER PRIMARY KEY,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                is_pinned   INTEGER NOT NULL DEFAULT 0,
                pin_order   INTEGER NOT NULL DEFAULT 0,
                updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
            )");
        conn.Execute(@"
            CREATE TABLE IF NOT EXISTS chat_history (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT    NOT NULL DEFAULT 'default',
                role       TEXT    NOT NULL,
                content    TEXT    NOT NULL,
                created_at TEXT    NOT NULL DEFAULT (datetime('now'))
            )");
        conn.Execute("CREATE INDEX IF NOT EXISTS idx_chat_session ON chat_history(session_id, id)");
    }

    private SqliteConnection OpenDb()
    {
        var conn = new SqliteConnection($"Data Source={_dbPath}");
        conn.Open();
        return conn;
    }

    public async Task<List<GfnGame>> GetGfnCatalogAsync()
    {
        if (DateTime.UtcNow - _gfnCache.UpdatedAt < GfnCacheTtl && _gfnCache.Data.Count > 0)
            return _gfnCache.Data;

        try
        {
            var games = await _http.GetFromJsonAsync<List<GfnGame>>(GfnCatalogUrl,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
            var available = games.Where(g => g.Status != "MAINTENANCE").ToList();
            _gfnCache = (available, DateTime.UtcNow);
            return available;
        }
        catch
        {
            return _gfnCache.Data;
        }
    }

    public async Task<List<SteamGame>> GetSteamLibraryAsync()
    {
        var key = Environment.GetEnvironmentVariable("STEAM_API_KEY");
        var id = Environment.GetEnvironmentVariable("STEAM_ID64");
        if (string.IsNullOrEmpty(key) || string.IsNullOrEmpty(id)) return new();

        try
        {
            var url = $"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/" +
                      $"?key={key}&steamid={id}&include_appinfo=true&include_played_free_games=true&format=json";
            var resp = await _http.GetFromJsonAsync<SteamResponse>(url);
            return resp?.Response?.Games ?? new();
        }
        catch
        {
            return new();
        }
    }

    public async Task<object> GetIntersectionAsync(string? genre, string? search, bool favoritesOnly)
    {
        var steamTask = GetSteamLibraryAsync();
        var gfnTask   = GetGfnCatalogAsync();
        await Task.WhenAll(steamTask, gfnTask);
        var steamGames = steamTask.Result;
        var gfnGames   = gfnTask.Result;

        // Build GFN lookup by steam app id and normalized title
        var gfnBySteamId = gfnGames
            .Where(g => g.SteamAppId.HasValue)
            .ToDictionary(g => g.SteamAppId!.Value, g => g);

        var gfnByTitle = gfnGames.ToDictionary(
            g => NormalizeTitle(g.Title), g => g, StringComparer.OrdinalIgnoreCase);

        var favorites = GetAllFavorites();

        var enriched = steamGames.Select(sg =>
        {
            GfnGame? gfn = null;
            gfnBySteamId.TryGetValue(sg.AppId, out gfn);
            if (gfn == null) gfnByTitle.TryGetValue(NormalizeTitle(sg.Name), out gfn);

            var fav = favorites.GetValueOrDefault(sg.AppId);
            return new EnrichedGame(
                AppId: sg.AppId,
                Name: sg.Name,
                OnGfn: gfn != null,
                GfnId: gfn?.Id,
                Genres: gfn?.Genres ?? new(),
                Description: gfn?.Description,
                Publisher: gfn?.Publisher,
                PlaytimeMinutes: sg.PlaytimeMinutes,
                HeaderImage: $"https://cdn.akamai.steamstatic.com/steam/apps/{sg.AppId}/header.jpg",
                CapsuleImage: $"https://cdn.akamai.steamstatic.com/steam/apps/{sg.AppId}/capsule_616x353.jpg",
                SteamUrl: $"https://store.steampowered.com/app/{sg.AppId}/",
                GfnUrl: gfn != null ? $"https://play.geforcenow.com/games?game-id={gfn.Id}" : null,
                IsFavorite: fav?.IsFavorite ?? false,
                IsPinned: fav?.IsPinned ?? false
            );
        }).ToList();

        var gfnOnly = enriched.Where(g => g.OnGfn).ToList();
        var all = enriched;

        IEnumerable<EnrichedGame> result = gfnOnly;

        if (favoritesOnly)
            result = result.Where(g => g.IsFavorite);

        if (!string.IsNullOrEmpty(genre))
            result = result.Where(g => g.Genres.Any(x =>
                x.Contains(genre, StringComparison.OrdinalIgnoreCase)));

        if (!string.IsNullOrEmpty(search))
            result = result.Where(g =>
                g.Name.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (g.Description?.Contains(search, StringComparison.OrdinalIgnoreCase) ?? false));

        var sorted = result
            .OrderByDescending(g => g.IsPinned)
            .ThenByDescending(g => g.IsFavorite)
            .ThenByDescending(g => g.PlaytimeMinutes)
            .ToList();

        var genres = gfnOnly
            .SelectMany(g => g.Genres)
            .Where(g => !string.IsNullOrEmpty(g))
            .GroupBy(g => g)
            .OrderByDescending(x => x.Count())
            .Select(x => new { name = x.Key, count = x.Count() })
            .ToList();

        return new
        {
            games = sorted,
            total = sorted.Count,
            totalSteam = steamGames.Count,
            totalGfn = gfnGames.Count,
            totalIntersection = gfnOnly.Count,
            genres
        };
    }

    public async Task<List<string>> GetAllGenresAsync()
    {
        var gfn = await GetGfnCatalogAsync();
        return gfn.SelectMany(g => g.Genres ?? new())
            .Where(g => !string.IsNullOrEmpty(g))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(g => g)
            .ToList();
    }

    public FavoriteEntry SetFavorite(int appId, bool isFavorite, bool isPinned)
    {
        using var conn = OpenDb();
        conn.Execute(@"
            INSERT INTO favorites (app_id, is_favorite, is_pinned, updated_at)
            VALUES (@id, @fav, @pin, datetime('now'))
            ON CONFLICT(app_id) DO UPDATE SET
                is_favorite = @fav,
                is_pinned   = @pin,
                updated_at  = datetime('now')",
            new { id = appId, fav = isFavorite ? 1 : 0, pin = isPinned ? 1 : 0 });

        return new FavoriteEntry(appId, isFavorite, isPinned);
    }

    private Dictionary<int, FavoriteEntry> GetAllFavorites()
    {
        using var conn = OpenDb();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT app_id, is_favorite, is_pinned FROM favorites";
        using var reader = cmd.ExecuteReader();
        var result = new Dictionary<int, FavoriteEntry>();
        while (reader.Read())
        {
            var id = reader.GetInt32(0);
            result[id] = new FavoriteEntry(id, reader.GetInt32(1) == 1, reader.GetInt32(2) == 1);
        }
        return result;
    }

    public async Task<object> GetPricesAsync(int appId)
    {
        try
        {
            var searchUrl = $"https://www.cheapshark.com/api/1.0/games?steamAppID={appId}";
            var list = await _http.GetFromJsonAsync<List<JsonElement>>(searchUrl);
            if (list == null || list.Count == 0) return new { error = "not found" };

            var csId = list[0].GetProperty("gameID").GetString();
            var detailUrl = $"https://www.cheapshark.com/api/1.0/games?id={csId}";
            var detail = await _http.GetFromJsonAsync<CheapSharkGameDetail>(detailUrl);
            if (detail?.Deals == null) return new { error = "no deals" };

            var sorted = detail.Deals
                .OrderBy(d => double.TryParse(d.Price, out var p) ? p : double.MaxValue)
                .ToList();

            return new
            {
                cheapest = sorted.FirstOrDefault(),
                deals = sorted.Take(5),
                info = detail.Info
            };
        }
        catch (Exception ex)
        {
            return new { error = ex.Message };
        }
    }

    public async Task<LucilleEvalResult> GetLucilleEvalAsync()
    {
        var nvidiaKey = Environment.GetEnvironmentVariable("NVIDIA_API_KEY");
        if (string.IsNullOrEmpty(nvidiaKey))
            return new LucilleEvalResult { Error = "NVIDIA_API_KEY not set in environment" };

        var steamGames = await GetSteamLibraryAsync();
        var gfnGames   = await GetGfnCatalogAsync();
        var favorites  = GetAllFavorites();

        var gfnIds = gfnGames.Where(g => g.SteamAppId.HasValue)
                             .Select(g => g.SteamAppId!.Value)
                             .ToHashSet();
        var gfnByTitle = gfnGames.ToDictionary(g => NormalizeTitle(g.Title), g => g, StringComparer.OrdinalIgnoreCase);

        // Top 20 by playtime, flag which are on GFN
        var top = steamGames
            .OrderByDescending(g => g.PlaytimeMinutes)
            .Take(20)
            .Select(g =>
            {
                bool onGfn = gfnIds.Contains(g.AppId) ||
                             gfnByTitle.ContainsKey(NormalizeTitle(g.Name));
                return new
                {
                    name     = g.Name,
                    hours    = Math.Round(g.PlaytimeMinutes / 60.0, 1),
                    onGfn,
                    pinned   = favorites.GetValueOrDefault(g.AppId)?.IsPinned ?? false,
                    favorite = favorites.GetValueOrDefault(g.AppId)?.IsFavorite ?? false
                };
            }).ToList();

        var allGenres = gfnGames.SelectMany(g => g.Genres ?? new())
                                .Where(g => !string.IsNullOrEmpty(g))
                                .Distinct(StringComparer.OrdinalIgnoreCase)
                                .OrderBy(g => g)
                                .ToList();

        var systemPrompt =
            "You are Lucille, the AI for SWARM OS — a custom Arch Linux gaming platform. " +
            "Analyze this user's real Steam playtime data and NVIDIA GeForce NOW availability. " +
            "Respond ONLY with a valid JSON object — no markdown fences, no explanation outside the JSON. " +
            "The JSON must have exactly these keys:\n" +
            "  genre_filters: string[] — 1-3 genres from the available list that best match play history\n" +
            "  pin_games: string[] — 2-4 game names from their library to pin to the top (exact names)\n" +
            "  sort_by: \"playtime\" | \"discount\" | \"name\"\n" +
            "  favorite_games: string[] — 2-3 underrated picks they own but haven't played much\n" +
            "  summary: string — 2-3 sentences: what you observed, what you set, one specific recommendation\n" +
            "  system_suggestions: string[] — 3-5 real SWARM OS / GamingAgent improvements based on what this user actually plays. Be specific and technical. No generic advice.";

        var userMsg =
            $"Steam library: {steamGames.Count} games total, {gfnIds.Count} on GFN.\n" +
            $"Top played (hours | on GFN):\n" +
            string.Join("\n", top.Select(g => $"  {g.name} — {g.hours}h {(g.onGfn ? "[GFN]" : "")}")) +
            $"\n\nAvailable genres in GFN catalog: {string.Join(", ", allGenres)}";

        try
        {
            var request = new
            {
                model = "nvidia/llama-3.3-nemotron-super-49b-v1",
                messages = new[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user",   content = userMsg }
                },
                max_tokens = 1024,
                temperature = 0.7
            };

            using var req = new HttpRequestMessage(HttpMethod.Post,
                "https://integrate.api.nvidia.com/v1/chat/completions");
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", nvidiaKey);
            req.Content = JsonContent.Create(request);

            using var resp = await _http.SendAsync(req);
            resp.EnsureSuccessStatusCode();

            var raw = await resp.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(raw);
            var content = doc.RootElement
                             .GetProperty("choices")[0]
                             .GetProperty("message")
                             .GetProperty("content")
                             .GetString() ?? "";

            // Strip markdown fences if Nemotron wrapped anyway
            content = Regex.Replace(content.Trim(), @"^```[a-z]*\n?|\n?```$", "", RegexOptions.Multiline).Trim();

            using var parsed = JsonDocument.Parse(content);
            var r = parsed.RootElement;

            return new LucilleEvalResult
            {
                GenreFilters     = r.TryGetProperty("genre_filters",     out var gf)  ? gf.EnumerateArray().Select(x=>x.GetString()??string.Empty).ToList() : new(),
                PinGames         = r.TryGetProperty("pin_games",         out var pg)  ? pg.EnumerateArray().Select(x=>x.GetString()??string.Empty).ToList() : new(),
                SortBy           = r.TryGetProperty("sort_by",           out var sb)  ? sb.GetString() ?? "playtime" : "playtime",
                FavoriteGames    = r.TryGetProperty("favorite_games",    out var fg)  ? fg.EnumerateArray().Select(x=>x.GetString()??string.Empty).ToList() : new(),
                Summary          = r.TryGetProperty("summary",           out var sm)  ? sm.GetString() ?? "" : "",
                SystemSuggestions= r.TryGetProperty("system_suggestions",out var ss)  ? ss.EnumerateArray().Select(x=>x.GetString()??string.Empty).ToList() : new(),
                TopGames         = top.Select(g => new TopGame { Name = g.name, Hours = g.hours, OnGfn = g.onGfn }).ToList()
            };
        }
        catch (Exception ex)
        {
            return new LucilleEvalResult { Error = $"Nemotron error: {ex.Message}" };
        }
    }

    // ── Lucille Chat ─────────────────────────────────────────────────────────

    private string BuildChatSystemPrompt(List<SteamGame> steamGames, HashSet<int> gfnIds)
    {
        var top = steamGames
            .OrderByDescending(g => g.PlaytimeMinutes)
            .Take(12)
            .Select(g => $"{g.Name} ({Math.Round(g.PlaytimeMinutes / 60.0, 1)}h{(gfnIds.Contains(g.AppId) ? " [GFN]" : "")})")
            .ToList();

        return
            "You are Lucille, the AI assistant for SWARM OS — a custom Arch Linux gaming kiosk built for one user. " +
            "You have access to their Steam library and know which games are on GeForce NOW (GFN). " +
            "Be direct, knowledgeable, and a bit edgy. Keep answers concise (2-4 sentences unless detail is asked for). " +
            $"Library context: {steamGames.Count} Steam games, {gfnIds.Count} on GFN. " +
            $"Top played: {string.Join("; ", top)}.";
    }

    public async Task<LucilleChatResponse> LucilleChatAsync(LucilleChatRequest request)
    {
        var nvidiaKey = Environment.GetEnvironmentVariable("NVIDIA_API_KEY");
        if (string.IsNullOrEmpty(nvidiaKey))
            return new LucilleChatResponse("", "default", Error: "NVIDIA_API_KEY not set");

        var sessionId = request.SessionId ?? "default";
        var steamGames = await GetSteamLibraryAsync();
        var gfnGames   = await GetGfnCatalogAsync();
        var gfnIds     = gfnGames.Where(g => g.SteamAppId.HasValue).Select(g => g.SteamAppId!.Value).ToHashSet();

        var systemPrompt = BuildChatSystemPrompt(steamGames, gfnIds);

        var messages = new List<object> { new { role = "system", content = systemPrompt } };
        messages.AddRange(request.Messages.Select(m => (object)new { role = m.Role, content = m.Content }));

        try
        {
            var payload = new
            {
                model = "nvidia/llama-3.3-nemotron-super-49b-v1",
                messages,
                max_tokens = 512,
                temperature = 0.85
            };

            using var req = new HttpRequestMessage(HttpMethod.Post,
                "https://integrate.api.nvidia.com/v1/chat/completions");
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", nvidiaKey);
            req.Content = JsonContent.Create(payload);

            using var resp = await _http.SendAsync(req);
            resp.EnsureSuccessStatusCode();

            var raw = await resp.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(raw);
            var reply = doc.RootElement
                           .GetProperty("choices")[0]
                           .GetProperty("message")
                           .GetProperty("content")
                           .GetString()?.Trim() ?? "";

            // Persist both the user turn and Lucille's reply
            var lastUser = request.Messages.LastOrDefault(m => m.Role == "user");
            if (lastUser != null)
                SaveChatMessage(sessionId, "user", lastUser.Content);
            SaveChatMessage(sessionId, "assistant", reply);

            return new LucilleChatResponse(reply, sessionId);
        }
        catch (Exception ex)
        {
            return new LucilleChatResponse("", sessionId, Error: $"Nemotron error: {ex.Message}");
        }
    }

    public async IAsyncEnumerable<string> LucilleChatStreamAsync(LucilleChatRequest request)
    {
        var nvidiaKey = Environment.GetEnvironmentVariable("NVIDIA_API_KEY");
        if (string.IsNullOrEmpty(nvidiaKey))
        {
            yield return "[ERROR] NVIDIA_API_KEY not set";
            yield break;
        }

        var sessionId  = request.SessionId ?? "default";
        var steamGames = await GetSteamLibraryAsync();
        var gfnGames   = await GetGfnCatalogAsync();
        var gfnIds     = gfnGames.Where(g => g.SteamAppId.HasValue).Select(g => g.SteamAppId!.Value).ToHashSet();

        var systemPrompt = BuildChatSystemPrompt(steamGames, gfnIds);
        var messages = new List<object> { new { role = "system", content = systemPrompt } };
        messages.AddRange(request.Messages.Select(m => (object)new { role = m.Role, content = m.Content }));

        var payload = new
        {
            model = "nvidia/llama-3.3-nemotron-super-49b-v1",
            messages,
            max_tokens = 512,
            temperature = 0.85,
            stream = true
        };

        HttpResponseMessage? resp = null;
        Exception? initError = null;
        var httpReq = new HttpRequestMessage(HttpMethod.Post,
            "https://integrate.api.nvidia.com/v1/chat/completions");
        httpReq.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", nvidiaKey);
        httpReq.Content = JsonContent.Create(payload);
        try
        {
            resp = await _http.SendAsync(httpReq, HttpCompletionOption.ResponseHeadersRead);
            resp.EnsureSuccessStatusCode();
        }
        catch (Exception ex) { initError = ex; }

        if (initError != null || resp == null)
        {
            yield return $"[ERROR] {initError?.Message ?? "no response"}";
            yield break;
        }

        var fullReply = new System.Text.StringBuilder();
        using (resp)
        using (var stream = await resp.Content.ReadAsStreamAsync())
        using (var reader = new System.IO.StreamReader(stream))
        {
            string? line;
            while ((line = await reader.ReadLineAsync()) != null)
            {
                if (string.IsNullOrEmpty(line)) continue;
                if (!line.StartsWith("data: ")) continue;

                var data = line[6..];
                if (data == "[DONE]") break;

                string? chunk = null;
                try
                {
                    using var doc = JsonDocument.Parse(data);
                    var delta = doc.RootElement.GetProperty("choices")[0].GetProperty("delta");
                    if (!delta.TryGetProperty("content", out var cp)) continue;
                    chunk = cp.GetString();
                }
                catch { continue; }

                if (string.IsNullOrEmpty(chunk)) continue;
                fullReply.Append(chunk);
                yield return chunk;
            }
        }

        // Persist after stream completes
        var lastUser = request.Messages.LastOrDefault(m => m.Role == "user");
        if (lastUser != null)
            SaveChatMessage(sessionId, "user", lastUser.Content);
        if (fullReply.Length > 0)
            SaveChatMessage(sessionId, "assistant", fullReply.ToString());
    }

    public List<ChatHistoryEntry> GetChatHistory(string sessionId = "default", int limit = 50)
    {
        using var conn = OpenDb();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT id, role, content, created_at
            FROM chat_history
            WHERE session_id = @sid
            ORDER BY id DESC
            LIMIT @lim";
        cmd.Parameters.AddWithValue("@sid", sessionId);
        cmd.Parameters.AddWithValue("@lim", limit);

        using var reader = cmd.ExecuteReader();
        var result = new List<ChatHistoryEntry>();
        while (reader.Read())
            result.Add(new ChatHistoryEntry(
                reader.GetInt64(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3)));

        result.Reverse(); // chronological order
        return result;
    }

    private void SaveChatMessage(string sessionId, string role, string content)
    {
        using var conn = OpenDb();
        conn.Execute(
            "INSERT INTO chat_history (session_id, role, content) VALUES (@sid, @role, @content)",
            new { sid = sessionId, role, content });
    }

    private static string NormalizeTitle(string title) =>
        Regex.Replace(title.ToLowerInvariant(), @"[^a-z0-9]", "");
}

public static class SqliteExtensions
{
    public static void Execute(this SqliteConnection conn, string sql, object? param = null)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        if (param != null)
        {
            foreach (var prop in param.GetType().GetProperties())
                cmd.Parameters.AddWithValue($"@{prop.Name}", prop.GetValue(param) ?? DBNull.Value);
        }
        cmd.ExecuteNonQuery();
    }
}
