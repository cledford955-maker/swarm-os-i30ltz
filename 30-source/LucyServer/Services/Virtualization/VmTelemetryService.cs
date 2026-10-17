using System.Collections.Concurrent;
using System.Diagnostics;
using LucyServer.Models;

namespace LucyServer.Services.Virtualization;

public class VmTelemetryService : IVmTelemetryService
{
    private readonly IVmManagerService _vmManager;
    private readonly ConcurrentDictionary<Guid, List<VmTelemetry>> _history = new();
    private readonly ConcurrentDictionary<int, (DateTime Time, TimeSpan CpuTime)> _cpuPrev = new();

    public VmTelemetryService(IVmManagerService vmManager)
    {
        _vmManager = vmManager;
    }

    public async Task<VmTelemetry?> GetTelemetryAsync(Guid vmId)
    {
        var vm = await _vmManager.GetVmAsync(vmId);
        if (vm == null || vm.Status != VmStatus.Running || !vm.ProcessId.HasValue)
        {
            return null;
        }

        try
        {
            var proc = Process.GetProcessById(vm.ProcessId.Value);
            if (proc.HasExited) return null;

            proc.Refresh();

            // CPU Calculation
            double cpuPercent = 0.0;
            var now = DateTime.UtcNow;
            var currentCpuTime = proc.TotalProcessorTime;

            if (_cpuPrev.TryGetValue(proc.Id, out var prev))
            {
                var timeDelta = (now - prev.Time).TotalMilliseconds;
                var cpuDelta = (currentCpuTime - prev.CpuTime).TotalMilliseconds;
                if (timeDelta > 0)
                {
                    cpuPercent = Math.Round((cpuDelta / (timeDelta * Environment.ProcessorCount)) * 100.0, 2);
                    if (cpuPercent > 100.0) cpuPercent = 100.0;
                    if (cpuPercent < 0.0) cpuPercent = 0.0;
                }
            }
            _cpuPrev[proc.Id] = (now, currentCpuTime);

            // Memory
            long memoryUsedMb = proc.WorkingSet64 / (1024 * 1024);

            // Read /proc/<pid>/io for Disk I/O on Linux
            double readBytesSec = 0;
            double writeBytesSec = 0;
            var ioPath = $"/proc/{proc.Id}/io";
            if (File.Exists(ioPath))
            {
                try
                {
                    var lines = await File.ReadAllLinesAsync(ioPath);
                    foreach (var line in lines)
                    {
                        if (line.StartsWith("read_bytes:"))
                        {
                            long.TryParse(line.Split(':')[1].Trim(), out var rb);
                            readBytesSec = rb;
                        }
                        else if (line.StartsWith("write_bytes:"))
                        {
                            long.TryParse(line.Split(':')[1].Trim(), out var wb);
                            writeBytesSec = wb;
                        }
                    }
                }
                catch { }
            }

            var telemetry = new VmTelemetry
            {
                VmId = vmId,
                CpuUsagePercent = cpuPercent,
                MemoryUsedMb = memoryUsedMb,
                MemoryTotalMb = vm.RamMb,
                DiskReadBytesPerSec = readBytesSec,
                DiskWriteBytesPerSec = writeBytesSec,
                NetworkRxBytesPerSec = 0,
                NetworkTxBytesPerSec = 0,
                Timestamp = now
            };

            // Store in rolling history (max 60 points)
            var list = _history.GetOrAdd(vmId, _ => new List<VmTelemetry>());
            lock (list)
            {
                list.Add(telemetry);
                if (list.Count > 60)
                {
                    list.RemoveAt(0);
                }
            }

            return telemetry;
        }
        catch
        {
            return null;
        }
    }

    public Task<List<VmTelemetry>> GetHistoryAsync(Guid vmId, TimeSpan duration)
    {
        if (_history.TryGetValue(vmId, out var list))
        {
            lock (list)
            {
                var cutoff = DateTime.UtcNow - duration;
                return Task.FromResult(list.Where(t => t.Timestamp >= cutoff).ToList());
            }
        }
        return Task.FromResult(new List<VmTelemetry>());
    }
}
