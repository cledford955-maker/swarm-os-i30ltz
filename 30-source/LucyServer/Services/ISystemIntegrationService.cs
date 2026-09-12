using System.Collections.Generic;
using System.Threading.Tasks;

namespace LucyServer.Services;

public class CommandResult
{
    public int ExitCode { get; set; }
    public string StandardOutput { get; set; } = string.Empty;
    public string StandardError { get; set; } = string.Empty;
}

public class ProcessInfo
{
    public int Pid { get; set; }
    public string Name { get; set; } = string.Empty;
    public double MemoryUsageMb { get; set; }
}

public class SystemStats
{
    public double CpuUsagePercentage { get; set; }
    public double TotalMemoryMb { get; set; }
    public double UsedMemoryMb { get; set; }
    public double FreeMemoryMb { get; set; }
}

public interface ISystemIntegrationService
{
    Task<CommandResult> RunCommandAsync(string command, string? cwd = null);
    Task<SystemStats> GetSystemStatsAsync();
    Task<IEnumerable<ProcessInfo>> GetProcessesAsync();
    Task<bool> KillProcessAsync(int pid);
    Task<IEnumerable<string>> ListPackagesAsync();
    Task<CommandResult> UninstallPackageAsync(string packageName);
    Task<CommandResult> SetClipboardTextAsync(string text);
    Task HandleTerminalWebSocketAsync(System.Net.WebSockets.WebSocket webSocket);
}
