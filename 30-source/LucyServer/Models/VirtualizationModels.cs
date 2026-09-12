namespace LucyServer.Models;

public enum VmOsType
{
    Linux,
    Windows,
    MacOS,
    Container
}

public enum VmStatus
{
    Stopped,
    Starting,
    Running,
    Paused,
    Stopping,
    Error
}

public class VirtualMachine
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public VmOsType OsType { get; set; } = VmOsType.Linux;
    public VmStatus Status { get; set; } = VmStatus.Stopped;
    public int CpuCores { get; set; } = 4;
    public int RamMb { get; set; } = 8192;
    public int DiskSizeGb { get; set; } = 32;
    public string DiskPath { get; set; } = string.Empty;
    public string? IsoPath { get; set; }
    public int SshPort { get; set; } = 2222;
    public int HttpPort { get; set; } = 8080;
    public int VncPort { get; set; } = 5900;
    public int? ProcessId { get; set; }
    public string? TemplateId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastStartedAt { get; set; }
}

public class VmCreateRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public VmOsType OsType { get; set; } = VmOsType.Linux;
    public int CpuCores { get; set; } = 4;
    public int RamMb { get; set; } = 8192;
    public int DiskSizeGb { get; set; } = 32;
    public string? IsoPath { get; set; }
    public string? TemplateId { get; set; }
}

public class VmSnapshot
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid VmId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; }
}

public class VmSnapshotCreateRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
}

public class VmTelemetry
{
    public Guid VmId { get; set; }
    public double CpuUsagePercent { get; set; }
    public long MemoryUsedMb { get; set; }
    public long MemoryTotalMb { get; set; }
    public double DiskReadBytesPerSec { get; set; }
    public double DiskWriteBytesPerSec { get; set; }
    public double NetworkRxBytesPerSec { get; set; }
    public double NetworkTxBytesPerSec { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public class EnvironmentTemplate
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public VmOsType OsType { get; set; }
    public string Category { get; set; } = string.Empty;
    public int RecommendedCpus { get; set; } = 4;
    public int MinRamMb { get; set; } = 4096;
    public int MinDiskGb { get; set; } = 20;
    public string[] Tags { get; set; } = [];
    public Dictionary<string, int> DefaultPorts { get; set; } = new();
    public bool IsCloudInitReady { get; set; }
}

public class SandboxExecutionRequest
{
    public string Code { get; set; } = string.Empty;
    public string Language { get; set; } = "bash"; // bash, python, c, dart, rust
    public int TimeoutSeconds { get; set; } = 30;
    public bool NetworkEnabled { get; set; } = false;
    public bool EphemeralOverlay { get; set; } = true;
    public int MemoryLimitMb { get; set; } = 512;
    public string? WorkingDirectory { get; set; }
}

public class SandboxExecutionResult
{
    public int ExitCode { get; set; }
    public string Stdout { get; set; } = string.Empty;
    public string Stderr { get; set; } = string.Empty;
    public long ExecutionTimeMs { get; set; }
    public long MemoryPeakMb { get; set; }
    public bool IsSandboxed { get; set; } = true;
    public bool TimedOut { get; set; } = false;
}
