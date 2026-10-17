using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace LucyServer.Services;

public class SystemIntegrationService : ISystemIntegrationService
{
    public async Task<CommandResult> RunCommandAsync(string command, string? cwd = null)
    {
        var result = new CommandResult();

        var processStartInfo = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = $"-c \"{command.Replace("\"", "\\\"")}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = cwd ?? Directory.GetCurrentDirectory()
        };

        using var process = new Process { StartInfo = processStartInfo };
        
        process.Start();

        var stdOutTask = process.StandardOutput.ReadToEndAsync();
        var stdErrTask = process.StandardError.ReadToEndAsync();

        await process.WaitForExitAsync();

        result.StandardOutput = await stdOutTask;
        result.StandardError = await stdErrTask;
        result.ExitCode = process.ExitCode;

        return result;
    }

    public async Task<SystemStats> GetSystemStatsAsync()
    {
        var stats = new SystemStats();
        
        try
        {
            // Simple approach for Linux: parsing free -m
            var memResult = await RunCommandAsync("free -m | grep Mem");
            var memParts = memResult.StandardOutput.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (memParts.Length >= 4)
            {
                if (double.TryParse(memParts[1], out var total)) stats.TotalMemoryMb = total;
                if (double.TryParse(memParts[2], out var used)) stats.UsedMemoryMb = used;
                if (double.TryParse(memParts[3], out var free)) stats.FreeMemoryMb = free;
            }

            // Simple approach for Linux CPU: parsing top
            var cpuResult = await RunCommandAsync("top -bn1 | grep 'Cpu(s)'");
            var cpuParts = cpuResult.StandardOutput.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (cpuParts.Length >= 2)
            {
                var userCpuStr = cpuParts[1].Replace("%us,", "").Replace("%us", "");
                if (double.TryParse(userCpuStr, out var userCpu)) stats.CpuUsagePercentage = userCpu;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting system stats: {ex.Message}");
        }

        return stats;
    }

    public async Task<IEnumerable<ProcessInfo>> GetProcessesAsync()
    {
        var processes = new List<ProcessInfo>();
        
        try
        {
            var pList = Process.GetProcesses();
            foreach (var p in pList)
            {
                try
                {
                    processes.Add(new ProcessInfo
                    {
                        Pid = p.Id,
                        Name = p.ProcessName,
                        MemoryUsageMb = p.WorkingSet64 / 1024.0 / 1024.0
                    });
                }
                catch
                {
                    // Ignore processes we can't access
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error listing processes: {ex.Message}");
        }

        return processes.OrderByDescending(p => p.MemoryUsageMb).ToList();
    }

    public async Task<bool> KillProcessAsync(int pid)
    {
        try
        {
            var process = Process.GetProcessById(pid);
            process.Kill();
            await process.WaitForExitAsync();
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<IEnumerable<string>> ListPackagesAsync()
    {
        try
        {
            // Fallback to checking apt or pacman based on available binaries
            var aptCheck = await RunCommandAsync("which apt");
            if (aptCheck.ExitCode == 0)
            {
                var result = await RunCommandAsync("dpkg-query -f '${binary:Package}\\n' -W");
                return result.StandardOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            }

            var pacmanCheck = await RunCommandAsync("which pacman");
            if (pacmanCheck.ExitCode == 0)
            {
                var result = await RunCommandAsync("pacman -Qqe");
                return result.StandardOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            }
        }
        catch
        {
        }

        return new List<string>();
    }

    public async Task<CommandResult> UninstallPackageAsync(string packageName)
    {
        var aptCheck = await RunCommandAsync("which apt");
        if (aptCheck.ExitCode == 0)
        {
            return await RunCommandAsync($"sudo apt remove -y {packageName}");
        }

        var pacmanCheck = await RunCommandAsync("which pacman");
        if (pacmanCheck.ExitCode == 0)
        {
            return await RunCommandAsync($"sudo pacman -Rns --noconfirm {packageName}");
        }

        return new CommandResult { ExitCode = -1, StandardError = "No supported package manager found." };
    }

    public async Task<CommandResult> SetClipboardTextAsync(string text)
    {
        var escapedText = text.Replace("\"", "\\\"").Replace("$", "\\$").Replace("`", "\\`");
        
        // Try wl-copy (Wayland) first, fallback to xclip (X11)
        var wlCopyCheck = await RunCommandAsync("which wl-copy");
        if (wlCopyCheck.ExitCode == 0)
        {
            return await RunCommandAsync($"echo \"{escapedText}\" | wl-copy");
        }
        
        return await RunCommandAsync($"echo \"{escapedText}\" | xclip -selection clipboard");
    }

    public async Task HandleTerminalWebSocketAsync(System.Net.WebSockets.WebSocket webSocket)
    {
        var processStartInfo = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = "-l",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = Environment.GetEnvironmentVariable("HOME") ?? "/"
        };
        processStartInfo.EnvironmentVariables["TERM"] = "xterm-256color";

        using var process = new Process { StartInfo = processStartInfo };
        try
        {
            process.Start();

            var receiveTask = ReceiveFromWebSocketAsync(webSocket, process.StandardInput.BaseStream);
            var sendOutTask = SendToWebSocketAsync(process.StandardOutput.BaseStream, webSocket);
            var sendErrTask = SendToWebSocketAsync(process.StandardError.BaseStream, webSocket);

            await Task.WhenAny(receiveTask, sendOutTask, sendErrTask, process.WaitForExitAsync());

            if (!process.HasExited)
            {
                process.Kill();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in terminal session: {ex.Message}");
        }
        finally
        {
            if (webSocket.State == System.Net.WebSockets.WebSocketState.Open)
            {
                await webSocket.CloseAsync(System.Net.WebSockets.WebSocketCloseStatus.NormalClosure, "Terminal closed", System.Threading.CancellationToken.None);
            }
        }
    }

    private async Task ReceiveFromWebSocketAsync(System.Net.WebSockets.WebSocket webSocket, Stream stdIn)
    {
        var buffer = new byte[4096];
        try
        {
            while (webSocket.State == System.Net.WebSockets.WebSocketState.Open)
            {
                var result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), System.Threading.CancellationToken.None);
                if (result.MessageType == System.Net.WebSockets.WebSocketMessageType.Close)
                    break;

                await stdIn.WriteAsync(buffer, 0, result.Count);
                await stdIn.FlushAsync();
            }
        }
        catch { }
    }

    private async Task SendToWebSocketAsync(Stream stream, System.Net.WebSockets.WebSocket webSocket)
    {
        var buffer = new byte[4096];
        try
        {
            int bytesRead;
            while ((bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                if (webSocket.State != System.Net.WebSockets.WebSocketState.Open)
                    break;

                await webSocket.SendAsync(new ArraySegment<byte>(buffer, 0, bytesRead), System.Net.WebSockets.WebSocketMessageType.Text, true, System.Threading.CancellationToken.None);
            }
        }
        catch { }
    }
}
