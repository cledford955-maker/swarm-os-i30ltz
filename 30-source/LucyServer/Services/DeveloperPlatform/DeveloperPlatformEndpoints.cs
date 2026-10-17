using LucyServer.Models;

namespace LucyServer.Services.DeveloperPlatform;

public static class DeveloperPlatformEndpoints
{
    public static IEndpointRouteBuilder MapDeveloperPlatformEndpoints(this IEndpointRouteBuilder app)
    {
        // 1. Extensions SDK & Local Development
        var extGroup = app.MapGroup("/api/extensions");

        extGroup.MapPost("/local/link", async (string path, IExtensionDevService extService) =>
        {
            try
            {
                var link = await extService.LinkLocalExtensionAsync(path);
                return Results.Ok(link);
            }
            catch (Exception ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        });

        extGroup.MapGet("/local/list", async (IExtensionDevService extService) =>
        {
            var list = await extService.ListLocalExtensionsAsync();
            return Results.Ok(list);
        });

        extGroup.MapDelete("/local/{extensionId}", async (string extensionId, IExtensionDevService extService) =>
        {
            var unlinked = await extService.UnlinkLocalExtensionAsync(extensionId);
            return unlinked ? Results.Ok(new { success = true }) : Results.NotFound();
        });

        extGroup.MapPost("/dependencies/resolve", async (Dictionary<string, string> requested, IExtensionDevService extService) =>
        {
            var res = await extService.ResolveDependenciesAsync(requested);
            return Results.Ok(res);
        });

        extGroup.MapGet("/updates/check", async (IExtensionDevService extService) =>
        {
            var updates = await extService.CheckUpdatesAsync();
            return Results.Ok(updates);
        });

        // 2. App Releases & Channels
        var relGroup = app.MapGroup("/api/releases");

        relGroup.MapPost("/publish", async (AppRelease release, IAppReleaseService relService) =>
        {
            var created = await relService.PublishReleaseAsync(release);
            return Results.Created($"/api/releases/{created.Id}", created);
        });

        relGroup.MapGet("/{appId}", async (string appId, ReleaseChannel? channel, IAppReleaseService relService) =>
        {
            var releases = await relService.GetReleasesAsync(appId, channel);
            return Results.Ok(releases);
        });

        relGroup.MapPost("/{id:guid}/promote", async (Guid id, ReleaseChannel targetChannel, IAppReleaseService relService) =>
        {
            var success = await relService.PromoteReleaseAsync(id, targetChannel);
            return success ? Results.Ok(new { success = true, channel = targetChannel.ToString() }) : Results.NotFound();
        });

        // 3. Self-Hosted Git Repositories
        var gitGroup = app.MapGroup("/api/git");

        gitGroup.MapGet("/repos", async (IGitAndCiService gitService) =>
        {
            var repos = await gitService.ListRepositoriesAsync();
            return Results.Ok(repos);
        });

        gitGroup.MapPost("/repos/create", async (string name, IGitAndCiService gitService) =>
        {
            var repo = await gitService.CreateRepositoryAsync(name);
            return Results.Created($"/api/git/repos/{repo.Name}", repo);
        });

        // 4. CI/CD Pipelines & Build Servers
        var ciGroup = app.MapGroup("/api/ci");

        ciGroup.MapPost("/pipelines/trigger", async (string repoName, string? commitSha, IGitAndCiService gitService) =>
        {
            var pipeline = await gitService.TriggerPipelineAsync(repoName, commitSha ?? "HEAD");
            return Results.Ok(pipeline);
        });

        ciGroup.MapGet("/pipelines/{id:guid}", async (Guid id, IGitAndCiService gitService) =>
        {
            var pipeline = await gitService.GetPipelineAsync(id);
            return pipeline != null ? Results.Ok(pipeline) : Results.NotFound();
        });

        // 5. Release Artifacts Storage
        var artGroup = app.MapGroup("/api/artifacts");

        artGroup.MapGet("/", async (IGitAndCiService gitService) =>
        {
            var artifacts = await gitService.ListArtifactsAsync();
            return Results.Ok(artifacts);
        });

        artGroup.MapGet("/{id:guid}/download", async (Guid id, IGitAndCiService gitService) =>
        {
            var artifact = await gitService.GetArtifactAsync(id);
            if (artifact == null || !File.Exists(artifact.StoredPath)) return Results.NotFound();

            artifact.DownloadCount++;
            var stream = File.OpenRead(artifact.StoredPath);
            return Results.File(stream, artifact.ContentType, artifact.Name);
        });

        // 6. OAuth & Analytics
        var oauthGroup = app.MapGroup("/api/oauth");

        oauthGroup.MapGet("/{provider}/login", async (string provider, IOAuthAndAnalyticsService oauthService) =>
        {
            var url = await oauthService.GetOAuthLoginUrlAsync(provider);
            return Results.Ok(new { url });
        });

        oauthGroup.MapGet("/{provider}/callback", async (string provider, string code, IOAuthAndAnalyticsService oauthService) =>
        {
            var success = await oauthService.HandleOAuthCallbackAsync(provider, code);
            return Results.Ok(new { success });
        });

        app.MapGet("/api/analytics/dashboard", async (IOAuthAndAnalyticsService analyticsService) =>
        {
            var stats = await analyticsService.GetDeveloperAnalyticsAsync();
            return Results.Ok(stats);
        });

        return app;
    }
}
