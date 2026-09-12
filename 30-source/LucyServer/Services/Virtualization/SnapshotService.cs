using System.Diagnostics;
using LucyServer.Models;

namespace LucyServer.Services.Virtualization;

public class SnapshotService : ISnapshotService
{
    private readonly IVmManagerService _vmManager;

    public SnapshotService(IVmManagerService vmManager)
    {
        _vmManager = vmManager;
    }

    public async Task<List<VmSnapshot>> ListSnapshotsAsync(Guid vmId)
    {
        var vm = await _vmManager.GetVmAsync(vmId);
        if (vm == null || !File.Exists(vm.DiskPath)) return new List<VmSnapshot>();

        var snapshots = new List<VmSnapshot>();

        var psi = new ProcessStartInfo
        {
            FileName = "qemu-img",
            Arguments = $"snapshot -l \"{vm.DiskPath}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using var process = Process.Start(psi);
        if (process != null)
        {
            var output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();

            var lines = output.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            // qemu-img snapshot table format:
            // ID        TAG               VM SIZE                DATE       VM CLOCK     ICOUNT
            bool inTable = false;
            foreach (var line in lines)
            {
                if (line.StartsWith("ID") && line.Contains("TAG"))
                {
                    inTable = true;
                    continue;
                }
                if (inTable && !string.IsNullOrWhiteSpace(line))
                {
                    var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 2)
                    {
                        var tag = parts[1];
                        snapshots.Add(new VmSnapshot
                        {
                            VmId = vmId,
                            Name = tag,
                            Description = $"Snapshot {tag}",
                            CreatedAt = DateTime.UtcNow,
                            IsActive = false
                        });
                    }
                }
            }
        }

        return snapshots;
    }

    public async Task<VmSnapshot> CreateSnapshotAsync(Guid vmId, VmSnapshotCreateRequest request)
    {
        var vm = await _vmManager.GetVmAsync(vmId);
        if (vm == null || !File.Exists(vm.DiskPath))
        {
            throw new InvalidOperationException($"VM {vmId} not found or disk missing.");
        }

        var snapName = string.IsNullOrWhiteSpace(request.Name) 
            ? $"snap_{DateTime.UtcNow:yyyyMMdd_HHmmss}" 
            : request.Name.Replace(" ", "_");

        var psi = new ProcessStartInfo
        {
            FileName = "qemu-img",
            Arguments = $"snapshot -c \"{snapName}\" \"{vm.DiskPath}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using var process = Process.Start(psi);
        if (process != null)
        {
            await process.WaitForExitAsync();
            if (process.ExitCode != 0)
            {
                var err = await process.StandardError.ReadToEndAsync();
                throw new InvalidOperationException($"Failed to create snapshot: {err}");
            }
        }

        return new VmSnapshot
        {
            VmId = vmId,
            Name = snapName,
            Description = request.Description ?? $"Snapshot {snapName}",
            CreatedAt = DateTime.UtcNow,
            IsActive = true
        };
    }

    public async Task<bool> RestoreSnapshotAsync(Guid vmId, string snapshotName)
    {
        var vm = await _vmManager.GetVmAsync(vmId);
        if (vm == null || !File.Exists(vm.DiskPath)) return false;

        // VM must be stopped to safely revert disk state
        if (vm.Status == VmStatus.Running)
        {
            await _vmManager.StopVmAsync(vmId, force: true);
        }

        var psi = new ProcessStartInfo
        {
            FileName = "qemu-img",
            Arguments = $"snapshot -a \"{snapshotName}\" \"{vm.DiskPath}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using var process = Process.Start(psi);
        if (process != null)
        {
            await process.WaitForExitAsync();
            return process.ExitCode == 0;
        }

        return false;
    }

    public async Task<bool> DeleteSnapshotAsync(Guid vmId, string snapshotName)
    {
        var vm = await _vmManager.GetVmAsync(vmId);
        if (vm == null || !File.Exists(vm.DiskPath)) return false;

        var psi = new ProcessStartInfo
        {
            FileName = "qemu-img",
            Arguments = $"snapshot -d \"{snapshotName}\" \"{vm.DiskPath}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using var process = Process.Start(psi);
        if (process != null)
        {
            await process.WaitForExitAsync();
            return process.ExitCode == 0;
        }

        return false;
    }
}
