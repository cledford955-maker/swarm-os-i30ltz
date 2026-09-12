using System.Collections.Generic;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using LucyServer.Models;

namespace LucyServer.Services.Ecosystem
{
    public static class AdvancedEcosystemEndpoints
    {
        public static void MapAdvancedEcosystemEndpoints(this IEndpointRouteBuilder app)
        {
            // --- 1 & 2. AI Coding Agents & Suggested Fixes ---
            app.MapPost("/api/ai-coder/task", async (
                AiCodingAgentService svc,
                AgentTaskRequest req) =>
            {
                var result = await svc.DispatchAgentTaskAsync(req.Title, req.Prompt, req.ActiveFilePath, req.Language, req.Role);
                return Results.Ok(result);
            });

            app.MapPost("/api/ai-coder/suggest-fixes", async (
                AiCodingAgentService svc,
                AnalyzeFixRequest req) =>
            {
                var result = await svc.AnalyzeAndSuggestFixesAsync(req.FilePath, req.FileContent, req.CompilerOutput);
                return Results.Ok(result);
            });

            app.MapGet("/api/ai-coder/history", async (AiCodingAgentService svc) =>
            {
                var history = await svc.GetRecentAgentTasksAsync();
                return Results.Ok(history);
            });

            // --- 3. Cloud Remote Workspaces ---
            app.MapGet("/api/workspaces/cloud", async (CloudWorkspaceService svc) =>
            {
                var workspaces = await svc.GetAllWorkspacesAsync();
                return Results.Ok(workspaces);
            });

            app.MapPost("/api/workspaces/cloud/create", async (
                CloudWorkspaceService svc,
                CreateWorkspaceRequest req) =>
            {
                var ws = await svc.CreateWorkspaceAsync(req.Name, req.Host, req.Port, req.Username, req.RemotePath);
                return Results.Ok(ws);
            });

            app.MapPost("/api/workspaces/cloud/{id}/sync", async (
                string id,
                CloudWorkspaceService svc) =>
            {
                var ok = await svc.SyncWorkspaceFilesAsync(id);
                return Results.Ok(new { success = ok });
            });

            // --- 4, 5, 6 & 7. Marketplace, Social Discovery, Monetization & Community Templates ---
            app.MapGet("/api/templates/community", async (MarketplaceManagementService svc) =>
            {
                var templates = await svc.GetCommunityTemplatesAsync();
                return Results.Ok(templates);
            });

            app.MapPost("/api/templates/community/submit", async (
                MarketplaceManagementService svc,
                CommunityTemplate template) =>
            {
                var created = await svc.SubmitCommunityTemplateAsync(template);
                return Results.Ok(created);
            });

            app.MapGet("/api/marketplace/reviews/{extensionId}", async (
                string extensionId,
                MarketplaceManagementService svc) =>
            {
                var reviews = await svc.GetReviewsForExtensionAsync(extensionId);
                return Results.Ok(reviews);
            });

            app.MapPost("/api/marketplace/reviews/post", async (
                MarketplaceManagementService svc,
                PostReviewRequest req) =>
            {
                var rev = await svc.PostReviewAsync(req.ExtensionId, req.Username, req.Rating, req.Comment);
                return Results.Ok(rev);
            });

            app.MapPost("/api/marketplace/purchase", async (
                MarketplaceManagementService svc,
                PurchaseItemRequest req) =>
            {
                var record = await svc.ProcessItemPurchaseAsync(req.ItemId, req.ItemName, req.BuyerId, req.PriceUsd);
                return Results.Ok(record);
            });

            app.MapGet("/api/marketplace/analytics", async (MarketplaceManagementService svc) =>
            {
                var analytics = await svc.GetMarketplaceAnalyticsAsync();
                return Results.Ok(analytics);
            });

            // --- 8 & 9. Screen Mirroring & Hardware Performance Stats ---
            app.MapPost("/api/device/mirror/start", async (
                DeviceAndScreenMirrorService svc,
                StartMirrorRequest req) =>
            {
                var session = await svc.StartScreenMirrorAsync(
                    req.DeviceSerial, req.DeviceModel, req.IsWireless, req.IpAddress, req.Port, req.MaxFps, req.BitrateMbps, req.ForwardAudio);
                return Results.Ok(session);
            });

            app.MapPost("/api/device/mirror/{sessionId}/stop", async (
                string sessionId,
                DeviceAndScreenMirrorService svc) =>
            {
                var ok = await svc.StopScreenMirrorAsync(sessionId);
                return Results.Ok(new { success = ok });
            });

            app.MapGet("/api/device/mirror/sessions", async (DeviceAndScreenMirrorService svc) =>
            {
                var list = await svc.GetActiveSessionsAsync();
                return Results.Ok(list);
            });

            app.MapGet("/api/device/stats", async (DeviceAndScreenMirrorService svc) =>
            {
                var stats = await svc.GetHardwarePerformanceStatsAsync();
                return Results.Ok(stats);
            });

            // --- 10 & 11. Telemetry, Crash Reports & App Analytics ---
            app.MapGet("/api/telemetry/crash-reports", async (TelemetryAndCrashService svc) =>
            {
                var reports = await svc.GetRecentCrashReportsAsync();
                return Results.Ok(reports);
            });

            app.MapPost("/api/telemetry/crash-reports/submit", async (
                TelemetryAndCrashService svc,
                SubmitCrashRequest req) =>
            {
                var report = await svc.SubmitCrashReportAsync(req.AppName, req.Version, req.ExceptionType, req.Message, req.RawStackTrace, req.Metadata);
                return Results.Ok(report);
            });

            app.MapGet("/api/telemetry/app-analytics", async (
                TelemetryAndCrashService svc,
                string? appId) =>
            {
                var analytics = await svc.GetAppAnalyticsAsync(appId ?? "com.swarm.os.shell");
                return Results.Ok(analytics);
            });

            // --- 12, 13, 14 & 15. RBAC, Audit Logs, Malware Scanning & PKI ---
            app.MapGet("/api/security/audit-logs", async (SecurityAndComplianceService svc) =>
            {
                var logs = await svc.GetAuditLogsAsync();
                return Results.Ok(logs);
            });

            app.MapPost("/api/security/scan-package", async (
                SecurityAndComplianceService svc,
                ScanPackageRequest req) =>
            {
                var report = await svc.ScanPackageAsync(req.PackagePath);
                return Results.Ok(report);
            });

            app.MapGet("/api/security/verified-developers", async (SecurityAndComplianceService svc) =>
            {
                var devs = await svc.GetVerifiedDevelopersAsync();
                return Results.Ok(devs);
            });
        }
    }

    public record AgentTaskRequest(string Title, string Prompt, string ActiveFilePath, string Language, CodingAgentRole Role);
    public record AnalyzeFixRequest(string FilePath, string FileContent, string CompilerOutput);
    public record CreateWorkspaceRequest(string Name, string Host, int Port, string Username, string RemotePath);
    public record PostReviewRequest(string ExtensionId, string Username, double Rating, string Comment);
    public record PurchaseItemRequest(string ItemId, string ItemName, string BuyerId, decimal PriceUsd);
    public record StartMirrorRequest(string DeviceSerial, string DeviceModel, bool IsWireless, string IpAddress, int Port, int MaxFps, int BitrateMbps, bool ForwardAudio);
    public record SubmitCrashRequest(string AppName, string Version, string ExceptionType, string Message, string RawStackTrace, Dictionary<string, string>? Metadata);
    public record ScanPackageRequest(string PackagePath);
}
