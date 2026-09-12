using System.Diagnostics;
using System.Text.Json;
using LucyServer.Models;

namespace LucyServer.Services.Virtualization;

public class VmManagerService : IVmManagerService
{
    private readonly string _storageDir;
    private readonly string _vmsMetadataFile;
    private readonly List<VirtualMachine> _vms = new();
    private readonly object _lock = new();

    public VmManagerService(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _storageDir = configuration["Virtualization:StoragePath"] 
                      ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".swarm_os", "vms");
        
        Directory.CreateDirectory(_storageDir);
        _vmsMetadataFile = Path.Combine(_storageDir, "vms.json");
        LoadMetadata();
    }

    private void LoadMetadata()
    {
        lock (_lock)
        {
            if (File.Exists(_vmsMetadataFile))
            {
                try
                {
                    var json = File.ReadAllText(_vmsMetadataFile);
                    var list = JsonSerializer.Deserialize<List<VirtualMachine>>(json);
                    if (list != null)
                    {
                        _vms.Clear();
                        _vms.AddRange(list);
                    }
                }
                catch
                {
                    // Ignore or log corrupt metadata
                }
            }
        }
    }

    private void SaveMetadata()
    {
        lock (_lock)
        {
            var json = JsonSerializer.Serialize(_vms, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(_vmsMetadataFile, json);
        }
    }

    public Task<List<VirtualMachine>> ListVmsAsync()
    {
        lock (_lock)
        {
            // Verify active PIDs
            foreach (var vm in _vms)
            {
                if (vm.ProcessId.HasValue)
                {
                    try
                    {
                        var proc = Process.GetProcessById(vm.ProcessId.Value);
                        if (proc.HasExited)
                        {
                            vm.Status = VmStatus.Stopped;
                            vm.ProcessId = null;
                        }
                    }
                    catch
                    {
                        vm.Status = VmStatus.Stopped;
                        vm.ProcessId = null;
                    }
                }
            }
            SaveMetadata();
            return Task.FromResult(_vms.ToList());
        }
    }

    public Task<VirtualMachine?> GetVmAsync(Guid id)
    {
        lock (_lock)
        {
            var vm = _vms.FirstOrDefault(v => v.Id == id);
            return Task.FromResult(vm);
        }
    }

    public async Task<VirtualMachine> CreateVmAsync(VmCreateRequest request)
    {
        var vmId = Guid.NewGuid();
        var vmDir = Path.Combine(_storageDir, vmId.ToString());
        Directory.CreateDirectory(vmDir);

        var diskPath = Path.Combine(vmDir, "disk.qcow2");
        
        // Allocate unique ports
        int sshPort, httpPort, vncPort;
        lock (_lock)
        {
            int basePort = 2222 + _vms.Count * 10;
            sshPort = basePort;
            httpPort = 8080 + _vms.Count * 10;
            vncPort = 5900 + _vms.Count;
        }

        // Create QCOW2 sparse disk
        var psi = new ProcessStartInfo
        {
            FileName = "qemu-img",
            Arguments = $"create -f qcow2 \"{diskPath}\" {request.DiskSizeGb}G",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using (var process = Process.Start(psi))
        {
            if (process != null)
            {
                await process.WaitForExitAsync();
            }
        }

        var vm = new VirtualMachine
        {
            Id = vmId,
            Name = string.IsNullOrWhiteSpace(request.Name) ? $"VM-{vmId.ToString()[..8]}" : request.Name,
            Description = request.Description ?? string.Empty,
            OsType = request.OsType,
            CpuCores = request.CpuCores,
            RamMb = request.RamMb,
            DiskSizeGb = request.DiskSizeGb,
            DiskPath = diskPath,
            IsoPath = request.IsoPath,
            TemplateId = request.TemplateId,
            SshPort = sshPort,
            HttpPort = httpPort,
            VncPort = vncPort,
            Status = VmStatus.Stopped,
            CreatedAt = DateTime.UtcNow
        };

        lock (_lock)
        {
            _vms.Add(vm);
            SaveMetadata();
        }

        return vm;
    }

    public async Task<bool> StartVmAsync(Guid id)
    {
        VirtualMachine? vm;
        lock (_lock)
        {
            vm = _vms.FirstOrDefault(v => v.Id == id);
        }

        if (vm == null || vm.Status == VmStatus.Running) return false;

        var qemuBinary = "qemu-system-x86_64";
        var hasKvm = File.Exists("/dev/kvm");
        var accelFlags = hasKvm ? "-enable-kvm -cpu host" : "-cpu max";

        var ovmfCode = "/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd";
        var ovmfVars = "/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd";
        var vmDir = Path.GetDirectoryName(vm.DiskPath)!;
        var localVars = Path.Combine(vmDir, "ovmf_vars.fd");

        var uefiFlags = "";
        if (File.Exists(ovmfCode) && File.Exists(ovmfVars))
        {
            if (!File.Exists(localVars))
            {
                File.Copy(ovmfVars, localVars);
            }
            uefiFlags = $"-drive if=pflash,format=raw,readonly=on,file=\"{ovmfCode}\" -drive if=pflash,format=raw,file=\"{localVars}\"";
        }

        var cdromFlag = !string.IsNullOrEmpty(vm.IsoPath) && File.Exists(vm.IsoPath) 
            ? $"-cdrom \"{vm.IsoPath}\" -boot order=d,menu=on" 
            : "-boot order=c";

        var vncDisplayIndex = vm.VncPort - 5900;
        var vncFlag = $"-vnc :{vncDisplayIndex}";

        var netFlag = $"-netdev user,id=net0,hostfwd=tcp::{vm.SshPort}-:22,hostfwd=tcp::{vm.HttpPort}-:80 -device virtio-net-pci,netdev=net0";

        var qmpSocket = Path.Combine(vmDir, "qmp.sock");
        var qmpFlag = $"-qmp unix:\"{qmpSocket}\",server,nowait";

        var args = $"{accelFlags} -m {vm.RamMb} -smp {vm.CpuCores} {uefiFlags} -vga virtio -display none {vncFlag} {netFlag} -drive file=\"{vm.DiskPath}\",if=virtio,format=qcow2,cache=writeback {cdromFlag} {qmpFlag}";

        var psi = new ProcessStartInfo
        {
            FileName = qemuBinary,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            var proc = Process.Start(psi);
            if (proc != null)
            {
                vm.ProcessId = proc.Id;
                vm.Status = VmStatus.Running;
                vm.LastStartedAt = DateTime.UtcNow;
                SaveMetadata();
                return true;
            }
        }
        catch
        {
            vm.Status = VmStatus.Error;
            SaveMetadata();
        }

        return false;
    }

    public async Task<bool> StopVmAsync(Guid id, bool force = false)
    {
        VirtualMachine? vm;
        lock (_lock)
        {
            vm = _vms.FirstOrDefault(v => v.Id == id);
        }

        if (vm == null || !vm.ProcessId.HasValue) return false;

        try
        {
            var proc = Process.GetProcessById(vm.ProcessId.Value);
            if (!proc.HasExited)
            {
                if (force)
                {
                    proc.Kill();
                }
                else
                {
                    // Graceful shutdown attempt via SIGTERM (kill -15)
                    try
                    {
                        Process.Start("kill", $"-15 {proc.Id}")?.WaitForExit(3000);
                        if (!proc.HasExited)
                        {
                            proc.Kill();
                        }
                    }
                    catch
                    {
                        proc.Kill();
                    }
                }
            }
        }
        catch
        {
            // Already exited
        }

        vm.Status = VmStatus.Stopped;
        vm.ProcessId = null;
        SaveMetadata();
        return true;
    }

    public async Task<bool> PauseVmAsync(Guid id)
    {
        VirtualMachine? vm;
        lock (_lock)
        {
            vm = _vms.FirstOrDefault(v => v.Id == id);
        }

        if (vm == null || !vm.ProcessId.HasValue) return false;

        try
        {
            Process.Start("kill", $"-STOP {vm.ProcessId.Value}")?.WaitForExit(2000);
            vm.Status = VmStatus.Paused;
            SaveMetadata();
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> ResumeVmAsync(Guid id)
    {
        VirtualMachine? vm;
        lock (_lock)
        {
            vm = _vms.FirstOrDefault(v => v.Id == id);
        }

        if (vm == null || !vm.ProcessId.HasValue) return false;

        try
        {
            Process.Start("kill", $"-CONT {vm.ProcessId.Value}")?.WaitForExit(2000);
            vm.Status = VmStatus.Running;
            SaveMetadata();
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> DeleteVmAsync(Guid id)
    {
        await StopVmAsync(id, force: true);

        lock (_lock)
        {
            var vm = _vms.FirstOrDefault(v => v.Id == id);
            if (vm != null)
            {
                _vms.Remove(vm);
                SaveMetadata();

                var vmDir = Path.GetDirectoryName(vm.DiskPath);
                if (!string.IsNullOrEmpty(vmDir) && Directory.Exists(vmDir))
                {
                    try { Directory.Delete(vmDir, recursive: true); } catch { }
                }
                return true;
            }
        }

        return false;
    }
}
