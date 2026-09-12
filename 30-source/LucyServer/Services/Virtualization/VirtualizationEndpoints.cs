using LucyServer.Models;
using LucyServer.Services.Sandboxing;

namespace LucyServer.Services.Virtualization;

public static class VirtualizationEndpoints
{
    public static IEndpointRouteBuilder MapVirtualizationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/vms");

        // VM Lifecycles
        group.MapGet("/", async (IVmManagerService vmService) =>
        {
            var list = await vmService.ListVmsAsync();
            return Results.Ok(list);
        });

        group.MapGet("/{id:guid}", async (Guid id, IVmManagerService vmService) =>
        {
            var vm = await vmService.GetVmAsync(id);
            return vm != null ? Results.Ok(vm) : Results.NotFound();
        });

        group.MapPost("/create", async (VmCreateRequest request, IVmManagerService vmService) =>
        {
            var vm = await vmService.CreateVmAsync(request);
            return Results.Created($"/api/vms/{vm.Id}", vm);
        });

        group.MapPost("/{id:guid}/start", async (Guid id, IVmManagerService vmService) =>
        {
            var success = await vmService.StartVmAsync(id);
            return success ? Results.Ok(new { success = true, message = "VM started" }) : Results.BadRequest(new { error = "Failed to start VM" });
        });

        group.MapPost("/{id:guid}/stop", async (Guid id, bool? force, IVmManagerService vmService) =>
        {
            var success = await vmService.StopVmAsync(id, force ?? false);
            return success ? Results.Ok(new { success = true, message = "VM stopped" }) : Results.BadRequest(new { error = "Failed to stop VM" });
        });

        group.MapPost("/{id:guid}/pause", async (Guid id, IVmManagerService vmService) =>
        {
            var success = await vmService.PauseVmAsync(id);
            return success ? Results.Ok(new { success = true, message = "VM paused" }) : Results.BadRequest(new { error = "Failed to pause VM" });
        });

        group.MapPost("/{id:guid}/resume", async (Guid id, IVmManagerService vmService) =>
        {
            var success = await vmService.ResumeVmAsync(id);
            return success ? Results.Ok(new { success = true, message = "VM resumed" }) : Results.BadRequest(new { error = "Failed to resume VM" });
        });

        group.MapDelete("/{id:guid}", async (Guid id, IVmManagerService vmService) =>
        {
            var success = await vmService.DeleteVmAsync(id);
            return success ? Results.Ok(new { success = true, message = "VM deleted" }) : Results.NotFound();
        });

        // Telemetry
        group.MapGet("/{id:guid}/telemetry", async (Guid id, IVmTelemetryService telemetryService) =>
        {
            var stats = await telemetryService.GetTelemetryAsync(id);
            return stats != null ? Results.Ok(stats) : Results.NotFound(new { error = "VM not running or telemetry unavailable" });
        });

        group.MapGet("/{id:guid}/telemetry/history", async (Guid id, int? minutes, IVmTelemetryService telemetryService) =>
        {
            var duration = TimeSpan.FromMinutes(minutes ?? 15);
            var history = await telemetryService.GetHistoryAsync(id, duration);
            return Results.Ok(history);
        });

        // Snapshots
        group.MapGet("/{id:guid}/snapshots", async (Guid id, ISnapshotService snapshotService) =>
        {
            var list = await snapshotService.ListSnapshotsAsync(id);
            return Results.Ok(list);
        });

        group.MapPost("/{id:guid}/snapshots", async (Guid id, VmSnapshotCreateRequest request, ISnapshotService snapshotService) =>
        {
            try
            {
                var snap = await snapshotService.CreateSnapshotAsync(id, request);
                return Results.Created($"/api/vms/{id}/snapshots/{snap.Name}", snap);
            }
            catch (Exception ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        });

        group.MapPost("/{id:guid}/snapshots/{name}/restore", async (Guid id, string name, ISnapshotService snapshotService) =>
        {
            var success = await snapshotService.RestoreSnapshotAsync(id, name);
            return success ? Results.Ok(new { success = true, message = $"Snapshot '{name}' restored" }) : Results.BadRequest(new { error = "Failed to restore snapshot" });
        });

        group.MapDelete("/{id:guid}/snapshots/{name}", async (Guid id, string name, ISnapshotService snapshotService) =>
        {
            var success = await snapshotService.DeleteSnapshotAsync(id, name);
            return success ? Results.Ok(new { success = true, message = $"Snapshot '{name}' deleted" }) : Results.BadRequest(new { error = "Failed to delete snapshot" });
        });

        // Environment Templates
        var tmplGroup = app.MapGroup("/api/templates/environments");
        tmplGroup.MapGet("/", async (IEnvironmentTemplateService templateService) =>
        {
            var list = await templateService.ListTemplatesAsync();
            return Results.Ok(list);
        });

        tmplGroup.MapGet("/{id}", async (string id, IEnvironmentTemplateService templateService) =>
        {
            var template = await templateService.GetTemplateAsync(id);
            return template != null ? Results.Ok(template) : Results.NotFound();
        });

        tmplGroup.MapPost("/{id}/instantiate", async (string id, string? name, IEnvironmentTemplateService templateService) =>
        {
            try
            {
                var vm = await templateService.InstantiateTemplateAsync(id, name ?? "");
                return Results.Created($"/api/vms/{vm.Id}", vm);
            }
            catch (Exception ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        });

        // Sandboxing
        app.MapPost("/api/sandbox/execute", async (SandboxExecutionRequest request, ISandboxService sandboxService) =>
        {
            var result = await sandboxService.ExecuteAsync(request);
            return Results.Ok(result);
        });

        return app;
    }
}
