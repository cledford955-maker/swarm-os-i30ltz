using Fido2NetLib;
using LucyServer.Services;
using Fido2NetLib.Objects;
using LucyServer.Services.Virtualization;
using LucyServer.Services.Sandboxing;
using LucyServer.Services.DeveloperPlatform;
using LucyServer.Services.Ecosystem;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddOpenApi();
builder.Services.AddHttpClient<IVectorMemoryService, VectorMemoryService>();

var fido2Config = new Fido2Configuration
{
    ServerDomain = "localhost",
    ServerName = "LucyServer",
    Origins = new HashSet<string> { "http://localhost:5000", "https://localhost:5001" },
    TimestampDriftTolerance = 300000
};
builder.Services.AddSingleton(fido2Config);
builder.Services.AddSingleton<IFido2>(new Fido2(fido2Config));
builder.Services.AddSingleton<IAuthService, WebAuthnService>();
builder.Services.AddHttpClient<ITTSService, TTSService>();

builder.Services.AddHttpClient<LucyServer.Services.Llm.ILlmProvider, LucyServer.Services.Llm.OpenRouterLlmProvider>();
builder.Services.AddHttpClient<LucyServer.Services.Llm.ILlmProvider, LucyServer.Services.Llm.OllamaLlmProvider>();
builder.Services.AddHttpClient<LucyServer.Services.Llm.ILlmProvider, LucyServer.Services.Llm.GroqLlmProvider>();
builder.Services.AddHttpClient<LucyServer.Services.Llm.ILlmProvider, LucyServer.Services.Llm.NvidiaLlmProvider>();
builder.Services.AddHttpClient<LucyServer.Services.Llm.ILlmProvider, LucyServer.Services.Llm.GeminiLlmProvider>();

builder.Services.AddSingleton<IMemoryService, MemoryService>();
builder.Services.AddSingleton<IFileSystemService, FileSystemService>();
builder.Services.AddSingleton<ISwarmRouterService, SwarmRouterService>();
builder.Services.AddSingleton<IOrchestratorService, OrchestratorService>();
builder.Services.AddSingleton<ISystemIntegrationService, SystemIntegrationService>();
builder.Services.AddSingleton<IChatService, ChatService>();
builder.Services.AddHttpClient<IOllamaService, OllamaService>();
builder.Services.AddHttpClient<INewsAndGamesService, NewsAndGamesService>();
builder.Services.AddSingleton<ISettingsService, SettingsService>();
builder.Services.AddHttpClient("search");
builder.Services.AddSingleton<ISearchService>(sp =>
{
    var factory = sp.GetRequiredService<IHttpClientFactory>();
    var news = sp.GetRequiredService<INewsAndGamesService>();
    return new SearchService(factory.CreateClient("search"), news);
});
builder.Services.AddHttpClient<IRagIngestionService, RagIngestionService>();
builder.Services.AddSingleton<IVmManagerService, VmManagerService>();
builder.Services.AddSingleton<ISnapshotService, SnapshotService>();
builder.Services.AddSingleton<IVmTelemetryService, VmTelemetryService>();
builder.Services.AddSingleton<IEnvironmentTemplateService, EnvironmentTemplateService>();
builder.Services.AddSingleton<ISandboxService, SandboxService>();
builder.Services.AddSingleton<IExtensionDevService, ExtensionDevService>();
builder.Services.AddSingleton<IAppReleaseService, AppReleaseService>();
builder.Services.AddSingleton<IGitAndCiService, GitAndCiService>();
builder.Services.AddSingleton<IOAuthAndAnalyticsService, OAuthAndAnalyticsService>();
builder.Services.AddSingleton<AiCodingAgentService>();
builder.Services.AddSingleton<CloudWorkspaceService>();
builder.Services.AddSingleton<MarketplaceManagementService>();
builder.Services.AddSingleton<DeviceAndScreenMirrorService>();
builder.Services.AddSingleton<TelemetryAndCrashService>();
builder.Services.AddSingleton<SecurityAndComplianceService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseStaticFiles();
app.UseWebSockets();

// Swarm Security & Token Authentication Middleware
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? "";
    if (path.StartsWith("/api/") && !path.StartsWith("/api/tts"))
    {
        var authHeader = context.Request.Headers["X-Swarm-Auth"].ToString();
        var bearerHeader = context.Request.Headers["Authorization"].ToString();
        var expectedToken = Environment.GetEnvironmentVariable("SWARM_AUTH_TOKEN") ?? "swarm-token-2026";
        var isLoopback = context.Connection.RemoteIpAddress != null && System.Net.IPAddress.IsLoopback(context.Connection.RemoteIpAddress);

        if (!isLoopback && authHeader != expectedToken && !bearerHeader.Contains(expectedToken))
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "Unauthorized SWARM access. Missing or invalid X-Swarm-Auth header." });
            return;
        }
    }
    await next();
});

// WebAuthn Endpoints
app.MapGet("/webauthn/register/options", (IAuthService auth) => auth.GetRegisterOptions());
app.MapPost("/webauthn/register/verify", async (IAuthService auth, AuthenticatorAttestationRawResponse response) => await auth.VerifyRegisterAsync(response));
app.MapGet("/webauthn/login/options", (IAuthService auth) => auth.GetLoginOptions());
app.MapPost("/webauthn/login/verify", async (AuthenticatorAssertionRawResponse clientResponse, IAuthService authService) =>
{
    var result = await authService.VerifyLoginAsync(clientResponse);
    return Results.Ok(result);
});
app.MapGet("/webauthn/list", (IAuthService auth) => Results.Ok(auth.ListCredentials()));
app.MapPost("/webauthn/clear", (IAuthService auth) =>
{
    auth.ClearCredentials();
    return Results.Ok(new { status = "ok", message = "All registered biometrics cleared." });
});

app.MapPost("/api/tts/generate", async (GenerateVoiceRequest request, ITTSService ttsService) =>
{
    var base64 = await ttsService.GenerateVoiceBase64Async(request.Text, request.VoiceName);
    return Results.Ok(new { audio = base64 });
});

app.MapPost("/lucy", async (LucyServer.Models.LucyRequest request, IOrchestratorService orchestrator, HttpContext context) =>
{
    context.Response.Headers.Append("Content-Type", "text/event-stream");
    var cancellationToken = context.RequestAborted;
    
    try 
    {
        await foreach (var chunk in orchestrator.ProcessChatRequestAsync(request, cancellationToken))
        {
            var data = $"data: {chunk.Replace("\n", "\\n")}\n\n";
            await context.Response.WriteAsync(data, cancellationToken);
            await context.Response.Body.FlushAsync(cancellationToken);
        }
    }
    catch (Exception ex)
    {
        await context.Response.WriteAsync($"data: [ERROR] {ex.Message.Replace("\n", "\\n")}\n\n", cancellationToken);
    }
    
    await context.Response.WriteAsync("data: [DONE]\n\n", cancellationToken);
});

app.MapPost("/api/run_command", async (LucyServer.Models.RunCommandRequest req, ISystemIntegrationService sys) =>
{
    var res = await sys.RunCommandAsync(req.Command, req.Cwd);
    return Results.Ok(res);
});

app.MapPost("/api/clipboard/set", async (LucyServer.Models.SetClipboardRequest req, ISystemIntegrationService sys) =>
{
    var res = await sys.SetClipboardTextAsync(req.Text);
    return Results.Ok(res);
});

app.MapPost("/api/terminal/run", async (LucyServer.Models.RunCommandRequest req, ISystemIntegrationService sys) =>
{
    var res = await sys.RunCommandAsync(req.Command, req.Cwd);
    return Results.Ok(res);
});

app.MapGet("/api/terminal/ws", async (HttpContext context, ISystemIntegrationService sys) =>
{
    if (context.WebSockets.IsWebSocketRequest)
    {
        var webSocket = await context.WebSockets.AcceptWebSocketAsync();
        await sys.HandleTerminalWebSocketAsync(webSocket);
    }
    else
    {
        context.Response.StatusCode = 400;
    }
});

app.MapGet("/api/system/processes", async (ISystemIntegrationService sys) =>
{
    var res = await sys.GetProcessesAsync();
    return Results.Ok(res);
});

app.MapPost("/api/system/process/kill", async (LucyServer.Models.KillProcessRequest req, ISystemIntegrationService sys) =>
{
    var res = await sys.KillProcessAsync(req.Pid);
    return Results.Ok(new { success = res });
});

app.MapGet("/api/system/stats", async (ISystemIntegrationService sys) =>
{
    var res = await sys.GetSystemStatsAsync();
    return Results.Ok(res);
});

app.MapGet("/api/packages/list", async (ISystemIntegrationService sys) =>
{
    var res = await sys.ListPackagesAsync();
    return Results.Ok(res);
});

app.MapPost("/api/packages/uninstall", async (LucyServer.Models.UninstallPackageRequest req, ISystemIntegrationService sys) =>
{
    var res = await sys.UninstallPackageAsync(req.PackageName);
    return Results.Ok(res);
});

// File System & Code Endpoints
app.MapGet("/api/fs", async (string? path, IFileSystemService fs) => 
{
    var res = await fs.ListDirectoryAsync(path ?? "/");
    return Results.Ok(res);
});

app.MapPost("/api/fs/analyze", async (LucyServer.Models.FsAnalyzeRequest req, IFileSystemService fs) => 
{
    var res = await fs.AnalyzeDirectoryAsync(req.Path);
    return Results.Ok(res);
});

app.MapGet("/api/code/files", async (string? path, IFileSystemService fs) => 
{
    var res = await fs.ListCodeFilesAsync(path ?? "/");
    return Results.Ok(res);
});

app.MapPost("/api/code/read", async (LucyServer.Models.FileReadRequest req, IFileSystemService fs) => 
{
    var content = await fs.ReadFileAsync(req.Filename);
    return Results.Ok(new { content });
});

app.MapPost("/api/code/save", async (LucyServer.Models.FileSaveRequest req, IFileSystemService fs) => 
{
    var res = await fs.SaveFileAsync(req.Filename, req.Content);
    return Results.Ok(new { success = res });
});

app.MapPost("/api/code/apply_upgrade", async (LucyServer.Models.FileSaveRequest req, IFileSystemService fs) => 
{
    var res = await fs.ApplyUpgradeAsync(req.Filename, req.Content);
    return Results.Ok(new { success = res });
});

app.MapPost("/api/recovery/mount", async (IFileSystemService fs) => 
{
    var res = await fs.MountRecoveryAsync();
    return Results.Ok(new { success = res });
});

// Chat History & Session Management Endpoints
app.MapGet("/api/chats", async (IChatService chatService) => 
{
    var chatsData = await chatService.LoadAllChatsAsync();
    var chatsList = new List<object>();
    foreach (var kvp in chatsData.Chats)
    {
        chatsList.Add(new {
            id = kvp.Key,
            title = string.IsNullOrEmpty(kvp.Value.Title) ? $"Chat {kvp.Key}" : kvp.Value.Title,
            pinned = kvp.Value.Pinned,
            privacy = kvp.Value.Privacy
        });
    }
    return Results.Ok(new {
        active_chat_id = chatsData.ActiveChatId,
        chats = chatsList
    });
});

app.MapPost("/api/chats/new", async (LucyServer.Models.ChatNewRequest req, IChatService chatService) => 
{
    var chatsData = await chatService.LoadAllChatsAsync();
    var cid = $"chat_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
    var title = string.IsNullOrEmpty(req.Title) ? $"Chat {chatsData.Chats.Count + 1}" : req.Title;
    
    chatsData.Chats[cid] = new LucyServer.Models.ChatInfo {
        Title = title,
        History = new(),
        Pinned = false,
        Privacy = req.Privacy
    };
    chatsData.ActiveChatId = cid;
    
    await chatService.SaveAllChatsAsync(chatsData);
    return Results.Ok(new { status = "ok", chat_id = cid });
});

app.MapPost("/api/chats/delete", async (LucyServer.Models.ChatIdRequest req, IChatService chatService) => 
{
    if (string.IsNullOrEmpty(req.ChatId) || req.ChatId == "default")
        return Results.BadRequest(new { error = "Cannot delete default chat" });
        
    var chatsData = await chatService.LoadAllChatsAsync();
    if (chatsData.Chats.ContainsKey(req.ChatId))
    {
        chatsData.Chats.Remove(req.ChatId);
        if (chatsData.ActiveChatId == req.ChatId)
        {
            chatsData.ActiveChatId = "default";
        }
        await chatService.SaveAllChatsAsync(chatsData);
    }
    return Results.Ok(new { status = "ok" });
});

app.MapPost("/api/chats/rename", async (LucyServer.Models.ChatRenameRequest req, IChatService chatService) => 
{
    if (string.IsNullOrEmpty(req.ChatId) || string.IsNullOrEmpty(req.Title))
        return Results.BadRequest(new { error = "Missing parameters" });
        
    var chatsData = await chatService.LoadAllChatsAsync();
    if (chatsData.Chats.ContainsKey(req.ChatId))
    {
        chatsData.Chats[req.ChatId].Title = req.Title;
        await chatService.SaveAllChatsAsync(chatsData);
    }
    return Results.Ok(new { status = "ok" });
});

app.MapPost("/api/chats/select", async (LucyServer.Models.ChatIdRequest req, IChatService chatService) => 
{
    var chatsData = await chatService.LoadAllChatsAsync();
    if (chatsData.Chats.ContainsKey(req.ChatId))
    {
        chatsData.ActiveChatId = req.ChatId;
        await chatService.SaveAllChatsAsync(chatsData);
        var history = chatsData.Chats[req.ChatId].History;
        return Results.Ok(new { status = "ok", history });
    }
    return Results.NotFound(new { error = "Chat not found" });
});

app.MapPost("/api/chats/toggle_pin", async (LucyServer.Models.ChatIdRequest req, IChatService chatService) => 
{
    if (string.IsNullOrEmpty(req.ChatId))
        return Results.BadRequest(new { error = "Invalid chat ID" });
        
    var chatsData = await chatService.LoadAllChatsAsync();
    if (chatsData.Chats.ContainsKey(req.ChatId))
    {
        chatsData.Chats[req.ChatId].Pinned = !chatsData.Chats[req.ChatId].Pinned;
        await chatService.SaveAllChatsAsync(chatsData);
        return Results.Ok(new { status = "ok", pinned = chatsData.Chats[req.ChatId].Pinned });
    }
    return Results.NotFound(new { error = "Chat not found" });
});

app.MapPost("/api/chats/toggle_privacy", async (LucyServer.Models.ChatIdRequest req, IChatService chatService) => 
{
    if (string.IsNullOrEmpty(req.ChatId) || req.ChatId == "default")
        return Results.BadRequest(new { error = "Invalid chat ID" });
        
    var chatsData = await chatService.LoadAllChatsAsync();
    if (chatsData.Chats.ContainsKey(req.ChatId))
    {
        var currentPrivacy = chatsData.Chats[req.ChatId].Privacy ?? "shared";
        var newPrivacy = currentPrivacy == "shared" ? "private" : "shared";
        chatsData.Chats[req.ChatId].Privacy = newPrivacy;
        await chatService.SaveAllChatsAsync(chatsData);
        return Results.Ok(new { status = "ok", privacy = newPrivacy });
    }
    return Results.NotFound(new { error = "Chat not found" });
});

app.MapVirtualizationEndpoints();
app.MapDeveloperPlatformEndpoints();
app.MapAdvancedEcosystemEndpoints();

// Ollama / Local Model Management
app.MapGet("/api/local_models", async (IOllamaService ollama) =>
{
    var models = await ollama.ListLocalModelsAsync();
    return Results.Ok(new { status = models.Count > 0 ? "ok" : "error", models });
});

app.MapPost("/api/pull_model", async (LucyServer.Models.PullModelRequest req, IOllamaService ollama) =>
{
    if (string.IsNullOrWhiteSpace(req.Model))
        return Results.BadRequest(new { error = "Missing model name" });
    var result = await ollama.StartPullAsync(req.Model);
    return Results.Ok(result);
});

app.MapGet("/api/pull_status", (IOllamaService ollama) => Results.Ok(ollama.GetPullStatus()));

// News & RSS
app.MapGet("/api/news", async (INewsAndGamesService news) => Results.Ok(await news.GetNewsAsync()));
app.MapGet("/api/deals", async (INewsAndGamesService news) => Results.Ok(await news.GetDealsAsync()));
app.MapGet("/api/news-feed", async (INewsAndGamesService news) => Results.Ok(await news.GetNewsFeedAsync()));
app.MapGet("/api/dev-news", async (INewsAndGamesService news) => Results.Ok(await news.GetDevNewsAsync()));

// Games & Steam
app.MapGet("/api/steam-library", async (INewsAndGamesService news) => Results.Ok(await news.GetSteamLibraryAsync()));
app.MapGet("/api/game-prices", async (string? gameId, INewsAndGamesService news) =>
    Results.Ok(await news.GetGamePricesAsync(gameId ?? "")));
app.MapGet("/api/game-info", async (string? gameId, INewsAndGamesService news) =>
    Results.Ok(await news.GetGameInfoAsync(gameId ?? "")));
app.MapGet("/api/gfn/games", async (INewsAndGamesService news) => Results.Ok(await news.GetGfnGamesAsync()));
app.MapPost("/api/gfn/optimize", (LucyServer.Models.GfnOptimizeRequest req, INewsAndGamesService news) =>
    Results.Ok(news.OptimizeGfn(req.Game ?? "")));

// Settings & Admin
app.MapGet("/api/settings/voice/get", (ISettingsService settings) =>
    Results.Ok(new { voice = settings.GetVoice() }));

app.MapPost("/api/settings/voice", (LucyServer.Models.VoiceSettingRequest req, ISettingsService settings) =>
{
    if (string.IsNullOrWhiteSpace(req.Voice))
        return Results.BadRequest(new { error = "Missing voice parameter" });
    settings.SetVoice(req.Voice);
    return Results.Ok(new { status = "ok" });
});

app.MapPost("/api/settings/login_password", async (LucyServer.Models.PasswordRequest req, ISettingsService settings) =>
{
    var (success, message) = await settings.SetLoginPasswordAsync(req.Password ?? "");
    return success ? Results.Ok(new { status = "ok", message }) : Results.BadRequest(new { error = message });
});

app.MapPost("/api/settings/sudo_password", async (LucyServer.Models.PasswordRequest req, ISettingsService settings) =>
{
    var (success, message) = await settings.SetSudoPasswordAsync(req.Password);
    return success ? Results.Ok(new { status = "ok", message }) : Results.BadRequest(new { error = message });
});

app.MapPost("/api/admin/save-keys", async (Dictionary<string, string> keys, ISettingsService settings) =>
{
    var (success, message) = await settings.SaveApiKeysAsync(keys);
    return success
        ? Results.Ok(new { success = true, message })
        : Results.UnprocessableEntity(new { success = false, error = message });
});

// Search & Daily Brief (Section 9)
app.MapGet("/api/google/brief", async (ISearchService search) =>
    Results.Ok(await search.GetDailyBriefAsync()));

app.MapGet("/api/search", async (string q, int? maxResults, ISearchService search) =>
{
    if (string.IsNullOrWhiteSpace(q))
        return Results.BadRequest(new { error = "Missing query parameter 'q'" });
    var results = await search.SearchWebAsync(q, maxResults ?? 8);
    return Results.Ok(new { query = q, results });
});

// RAG Ingestion (Section 9)
app.MapPost("/api/rag/ingest", async (LucyServer.Models.RagIngestRequest req, IRagIngestionService rag) =>
{
    if (string.IsNullOrWhiteSpace(req.Text))
        return Results.BadRequest(new { error = "Missing 'text'" });
    return Results.Ok(await rag.IngestTextAsync(req.Text, req.Source ?? "manual"));
});

app.MapPost("/api/rag/ingest/file", async (LucyServer.Models.RagFileRequest req, IRagIngestionService rag) =>
{
    if (string.IsNullOrWhiteSpace(req.FilePath))
        return Results.BadRequest(new { error = "Missing 'filePath'" });
    return Results.Ok(await rag.IngestFileAsync(req.FilePath));
});

app.MapGet("/api/rag/documents", async (IRagIngestionService rag) =>
    Results.Ok(await rag.ListDocumentsAsync()));

app.MapDelete("/api/rag/document", async (string source, IRagIngestionService rag) =>
    Results.Ok(await rag.DeleteDocumentAsync(source)));

app.MapDelete("/api/rag/clear", async (IRagIngestionService rag) =>
    Results.Ok(await rag.ClearStoreAsync()));

app.Run();
