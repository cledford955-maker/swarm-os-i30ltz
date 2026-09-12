using LucyServer.Models;

namespace LucyServer.Services.Virtualization;

public interface IVmManagerService
{
    Task<List<VirtualMachine>> ListVmsAsync();
    Task<VirtualMachine?> GetVmAsync(Guid id);
    Task<VirtualMachine> CreateVmAsync(VmCreateRequest request);
    Task<bool> StartVmAsync(Guid id);
    Task<bool> StopVmAsync(Guid id, bool force = false);
    Task<bool> PauseVmAsync(Guid id);
    Task<bool> ResumeVmAsync(Guid id);
    Task<bool> DeleteVmAsync(Guid id);
}

public interface ISnapshotService
{
    Task<List<VmSnapshot>> ListSnapshotsAsync(Guid vmId);
    Task<VmSnapshot> CreateSnapshotAsync(Guid vmId, VmSnapshotCreateRequest request);
    Task<bool> RestoreSnapshotAsync(Guid vmId, string snapshotName);
    Task<bool> DeleteSnapshotAsync(Guid vmId, string snapshotName);
}

public interface IVmTelemetryService
{
    Task<VmTelemetry?> GetTelemetryAsync(Guid vmId);
    Task<List<VmTelemetry>> GetHistoryAsync(Guid vmId, TimeSpan duration);
}

public interface IEnvironmentTemplateService
{
    Task<List<EnvironmentTemplate>> ListTemplatesAsync();
    Task<EnvironmentTemplate?> GetTemplateAsync(string templateId);
    Task<VirtualMachine> InstantiateTemplateAsync(string templateId, string vmName);
}
