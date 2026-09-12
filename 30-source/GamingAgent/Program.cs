using GamingAgent.Models;
using GamingAgent.Services;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient<GamingService>();
builder.Services.AddSingleton<GamingService>();
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

var app = builder.Build();
app.UseCors();

// Warm GFN cache on startup
_ = app.Services.GetRequiredService<GamingService>().GetGfnCatalogAsync();

// ── Routes ──────────────────────────────────────────────────────────────────

// Full GFN catalog
app.MapGet("/api/gfn/catalog", async (GamingService svc) =>
    Results.Ok(await svc.GetGfnCatalogAsync()));

// Steam library
app.MapGet("/api/steam/library", async (GamingService svc) =>
    Results.Ok(await svc.GetSteamLibraryAsync()));

// Intersection: Steam library ∩ GFN catalog
// Query params: genre, search, favoritesOnly
app.MapGet("/api/games/intersection", async (
    GamingService svc,
    string? genre,
    string? search,
    bool favoritesOnly = false) =>
    Results.Ok(await svc.GetIntersectionAsync(genre, search, favoritesOnly)));

// All genres from GFN catalog
app.MapGet("/api/games/genres", async (GamingService svc) =>
    Results.Ok(await svc.GetAllGenresAsync()));

// Prices for a Steam app
app.MapGet("/api/games/prices/{appId:int}", async (int appId, GamingService svc) =>
    Results.Ok(await svc.GetPricesAsync(appId)));

// Set favorite / pin state
app.MapPost("/api/games/favorite", (FavoriteRequest req, GamingService svc) =>
    Results.Ok(svc.SetFavorite(req.AppId, req.IsFavorite, req.IsPinned)));

// Lucille Nemotron eval — real AI analysis of play patterns
app.MapGet("/api/lucille/eval", async (GamingService svc) =>
    Results.Ok(await svc.GetLucilleEvalAsync()));

// Lucille multi-turn chat (non-streaming)
app.MapPost("/api/lucille/chat", async (LucilleChatRequest req, GamingService svc) =>
    Results.Ok(await svc.LucilleChatAsync(req)));

// Lucille multi-turn chat (SSE streaming)
app.MapPost("/api/lucille/chat/stream", async (HttpContext ctx, GamingService svc) =>
{
    LucilleChatRequest? req;
    try { req = await ctx.Request.ReadFromJsonAsync<LucilleChatRequest>(); }
    catch { ctx.Response.StatusCode = 400; return; }
    if (req == null) { ctx.Response.StatusCode = 400; return; }

    ctx.Response.ContentType = "text/event-stream; charset=utf-8";
    ctx.Response.Headers.Append("Cache-Control", "no-cache");
    ctx.Response.Headers.Append("X-Accel-Buffering", "no");
    ctx.Response.Headers.Append("Access-Control-Allow-Origin", "*");

    await foreach (var chunk in svc.LucilleChatStreamAsync(req))
    {
        await ctx.Response.WriteAsync($"data: {JsonSerializer.Serialize(chunk)}\n\n");
        await ctx.Response.Body.FlushAsync(ctx.RequestAborted);
    }

    await ctx.Response.WriteAsync("data: [DONE]\n\n");
    await ctx.Response.Body.FlushAsync();
});

// Lucille chat history
app.MapGet("/api/lucille/history", (GamingService svc, string? sessionId, int limit = 50) =>
    Results.Ok(svc.GetChatHistory(sessionId ?? "default", Math.Clamp(limit, 1, 200))));

// Health
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "GamingAgent" }));

app.Run();

record FavoriteRequest(int AppId, bool IsFavorite, bool IsPinned);
