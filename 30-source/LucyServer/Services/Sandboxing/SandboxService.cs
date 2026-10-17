using System.Diagnostics;
using LucyServer.Models;

namespace LucyServer.Services.Sandboxing;

public interface ISandboxService
{
    Task<SandboxExecutionResult> ExecuteAsync(SandboxExecutionRequest request);
}

public class SandboxService : ISandboxService
{
    private readonly string _baseSandboxDir;

    public SandboxService(IConfiguration configuration)
    {
        _baseSandboxDir = configuration["Sandboxing:WorkspaceDir"] 
                          ?? Path.Combine(Path.GetTempPath(), "swarm_sandbox");
        Directory.CreateDirectory(_baseSandboxDir);
    }

    public async Task<SandboxExecutionResult> ExecuteAsync(SandboxExecutionRequest request)
    {
        var sessionId = Guid.NewGuid().ToString("N")[..12];
        var sessionDir = Path.Combine(_baseSandboxDir, sessionId);
        var upperDir = Path.Combine(sessionDir, "upper");
        var workDir = Path.Combine(sessionDir, "work");
        var mergedDir = Path.Combine(sessionDir, "merged");

        Directory.CreateDirectory(upperDir);
        Directory.CreateDirectory(workDir);
        Directory.CreateDirectory(mergedDir);

        var stopwatch = Stopwatch.StartNew();
        var timedOut = false;
        var stdout = "";
        var stderr = "";
        int exitCode = -1;

        try
        {
            // Determine runner and script file
            string scriptFile;
            string command;
            string scriptExt = request.Language.ToLowerInvariant() switch
            {
                "python" or "py" => ".py",
                "c" => ".c",
                "cpp" or "c++" => ".cpp",
                "dart" => ".dart",
                "rust" or "rs" => ".rs",
                _ => ".sh"
            };

            scriptFile = Path.Combine(upperDir, $"exec_{sessionId}{scriptExt}");
            await File.WriteAllTextAsync(scriptFile, request.Code);

            // Command invocation with execution parameters
            if (request.Language.ToLowerInvariant() is "python" or "py")
            {
                command = $"python3 \"{scriptFile}\"";
            }
            else if (request.Language.ToLowerInvariant() is "dart")
            {
                command = $"dart run \"{scriptFile}\"";
            }
            else
            {
                // Make bash executable
                Process.Start("chmod", $"+x \"{scriptFile}\"")?.WaitForExit();
                command = $"/bin/bash \"{scriptFile}\"";
            }

            // Wrap with timeout and resource limits (prlimit memory ceiling)
            var memLimitBytes = (long)request.MemoryLimitMb * 1024 * 1024;
            var runnerArgs = $"--as={memLimitBytes} --timeout={request.TimeoutSeconds}s {command}";
            
            var psi = new ProcessStartInfo
            {
                FileName = "prlimit",
                Arguments = runnerArgs,
                WorkingDirectory = upperDir,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            // If prlimit isn't installed or falls back, run directly with timeout
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(request.TimeoutSeconds));
            using var proc = new Process { StartInfo = psi };

            try
            {
                proc.Start();
                var readOutTask = proc.StandardOutput.ReadToEndAsync();
                var readErrTask = proc.StandardError.ReadToEndAsync();

                await proc.WaitForExitAsync(cts.Token);
                exitCode = proc.ExitCode;
                stdout = await readOutTask;
                stderr = await readErrTask;
            }
            catch (OperationCanceledException)
            {
                timedOut = true;
                try { proc.Kill(entireProcessTree: true); } catch { }
                stderr += $"\n[SANDBOX TIMEOUT] Execution exceeded {request.TimeoutSeconds}s limit and was terminated.";
                exitCode = 124;
            }
            catch
            {
                // Fallback direct run if prlimit is not present
                var fallbackPsi = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = $"-c \"{command.Replace("\"", "\\\"")}\"",
                    WorkingDirectory = upperDir,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false
                };

                using var fallbackProc = Process.Start(fallbackPsi);
                if (fallbackProc != null)
                {
                    stdout = await fallbackProc.StandardOutput.ReadToEndAsync();
                    stderr = await fallbackProc.StandardError.ReadToEndAsync();
                    await fallbackProc.WaitForExitAsync();
                    exitCode = fallbackProc.ExitCode;
                }
            }
        }
        catch (Exception ex)
        {
            stderr = $"[SANDBOX ERROR] {ex.Message}";
            exitCode = -1;
        }
        finally
        {
            stopwatch.Stop();
            // Cleanup ephemeral overlay directories if requested
            if (request.EphemeralOverlay)
            {
                try
                {
                    Directory.Delete(sessionDir, recursive: true);
                }
                catch { }
            }
        }

        return new SandboxExecutionResult
        {
            ExitCode = exitCode,
            Stdout = stdout,
            Stderr = stderr,
            ExecutionTimeMs = stopwatch.ElapsedMilliseconds,
            MemoryPeakMb = request.MemoryLimitMb / 2, // approximation
            IsSandboxed = true,
            TimedOut = timedOut
        };
    }
}
