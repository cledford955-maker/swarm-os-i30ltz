using LucyServer.Models;

namespace LucyServer.Services.Virtualization;

public class EnvironmentTemplateService : IEnvironmentTemplateService
{
    private readonly IVmManagerService _vmManager;
    private readonly List<EnvironmentTemplate> _templates = new();

    public EnvironmentTemplateService(IVmManagerService vmManager)
    {
        _vmManager = vmManager;
        InitializeCatalog();
    }

    private void InitializeCatalog()
    {
        _templates.Add(new EnvironmentTemplate
        {
            Id = "swarm-arch-dev",
            Name = "SWARM Arch Linux Dev Workstation",
            Description = "Arch Linux base with Flutter, .NET 10, Clang C++20, and Android CLI tools pre-staged.",
            OsType = VmOsType.Linux,
            Category = "Development",
            RecommendedCpus = 4,
            MinRamMb = 8192,
            MinDiskGb = 32,
            Tags = ["Arch", "Flutter", ".NET", "C++", "Android"],
            DefaultPorts = new Dictionary<string, int> { { "SSH", 22 }, { "HTTP", 8080 }, { "FlutterDev", 50000 } },
            IsCloudInitReady = true
        });

        _templates.Add(new EnvironmentTemplate
        {
            Id = "swarm-ubuntu-lts",
            Name = "Ubuntu 24.04 LTS AI Stack",
            Description = "Ubuntu Noble with Python 3.12, PyTorch, Ollama, Docker, and NVIDIA container toolkit.",
            OsType = VmOsType.Linux,
            Category = "AI & Data Science",
            RecommendedCpus = 6,
            MinRamMb = 16384,
            MinDiskGb = 64,
            Tags = ["Ubuntu", "Python", "PyTorch", "Docker", "Ollama"],
            DefaultPorts = new Dictionary<string, int> { { "SSH", 22 }, { "Jupyter", 8888 }, { "Ollama", 11434 } },
            IsCloudInitReady = true
        });

        _templates.Add(new EnvironmentTemplate
        {
            Id = "swarm-alpine-edge",
            Name = "Alpine Micro-Sandbox",
            Description = "Lightweight 50MB Alpine Linux container/VM for high-speed isolated test execution.",
            OsType = VmOsType.Container,
            Category = "Testing",
            RecommendedCpus = 2,
            MinRamMb = 1024,
            MinDiskGb = 8,
            Tags = ["Alpine", "Lightweight", "Sandbox", "Testing"],
            DefaultPorts = new Dictionary<string, int> { { "SSH", 22 } },
            IsCloudInitReady = true
        });

        _templates.Add(new EnvironmentTemplate
        {
            Id = "swarm-android-emu",
            Name = "Android Virtual Device (AVD)",
            Description = "Headless Android 14 x86_64 emulator image with pre-authorized ADB bridge and companion tools.",
            OsType = VmOsType.Linux,
            Category = "Mobile Testing",
            RecommendedCpus = 4,
            MinRamMb = 6144,
            MinDiskGb = 24,
            Tags = ["Android", "AVD", "ADB", "Mobile"],
            DefaultPorts = new Dictionary<string, int> { { "ADB", 5555 }, { "VNC", 5900 } },
            IsCloudInitReady = false
        });

        _templates.Add(new EnvironmentTemplate
        {
            Id = "swarm-win11-dev",
            Name = "Windows 11 Enterprise Dev Guest",
            Description = "Windows 11 Pro/Enterprise evaluation with TPM 2.0, VirtIO storage/network, and VS Build Tools.",
            OsType = VmOsType.Windows,
            Category = "Cross-Platform",
            RecommendedCpus = 6,
            MinRamMb = 16384,
            MinDiskGb = 80,
            Tags = ["Windows", "Win11", "VirtIO", "TPM2", "MSVC"],
            DefaultPorts = new Dictionary<string, int> { { "RDP", 3389 }, { "WinRM", 5985 } },
            IsCloudInitReady = false
        });

        _templates.Add(new EnvironmentTemplate
        {
            Id = "swarm-macos-dev",
            Name = "macOS Sonoma / Sequoia KVM",
            Description = "macOS OpenCore KVM environment with Apple-SMC emulation for cross-compiling and iOS testing.",
            OsType = VmOsType.MacOS,
            Category = "Cross-Platform",
            RecommendedCpus = 6,
            MinRamMb = 16384,
            MinDiskGb = 80,
            Tags = ["macOS", "OpenCore", "KVM", "Xcode", "iOS"],
            DefaultPorts = new Dictionary<string, int> { { "SSH", 22 }, { "VNC", 5900 } },
            IsCloudInitReady = false
        });
    }

    public Task<List<EnvironmentTemplate>> ListTemplatesAsync()
    {
        return Task.FromResult(_templates.ToList());
    }

    public Task<EnvironmentTemplate?> GetTemplateAsync(string templateId)
    {
        var tmpl = _templates.FirstOrDefault(t => t.Id.Equals(templateId, StringComparison.OrdinalIgnoreCase));
        return Task.FromResult(tmpl);
    }

    public async Task<VirtualMachine> InstantiateTemplateAsync(string templateId, string vmName)
    {
        var template = await GetTemplateAsync(templateId)
            ?? throw new ArgumentException($"Template '{templateId}' not found.");

        var createReq = new VmCreateRequest
        {
            Name = string.IsNullOrWhiteSpace(vmName) ? $"{template.Name} ({DateTime.UtcNow:MMdd})" : vmName,
            Description = $"Instantiated from template: {template.Name}",
            OsType = template.OsType,
            CpuCores = template.RecommendedCpus,
            RamMb = template.MinRamMb,
            DiskSizeGb = template.MinDiskGb,
            TemplateId = template.Id
        };

        return await _vmManager.CreateVmAsync(createReq);
    }
}
