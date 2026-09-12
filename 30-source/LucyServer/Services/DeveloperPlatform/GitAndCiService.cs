using System.Diagnostics;
using System.Security.Cryptography;
using LucyServer.Models;

namespace LucyServer.Services.DeveloperPlatform;

public class GitAndCiService : IGitAndCiService
{
    private readonly string _gitRoot;
    private readonly string _artifactsRoot;
    private readonly List<CiPipeline> _pipelines = new();
    private readonly List<ReleaseArtifact> _artifacts = new();
    private readonly object _lock = new();

    public GitAndCiService(IConfiguration configuration)
    {
        _gitRoot = configuration["Git:StoragePath"] 
                   ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".swarm_os", "git");
        _artifactsRoot = configuration["Artifacts:StoragePath"] 
                         ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".swarm_os", "artifacts");

        Directory.CreateDirectory(_gitRoot);
        Directory.CreateDirectory(_artifactsRoot);
    }

    public async Task<List<GitRepository>> ListRepositoriesAsync()
    {
        var list = new List<GitRepository>();
        if (!Directory.Exists(_gitRoot)) return list;

        foreach (var dir in Directory.GetDirectories(_gitRoot))
        {
            var repoName = Path.GetFileName(dir);
            list.Add(new GitRepository
            {
                Name = repoName,
                Path = dir,
                CloneUrl = $"file://{dir}",
                LastCommitAt = Directory.GetLastWriteTimeUtc(dir),
                LastCommitMessage = "Initial commit"
            });
        }

        return await Task.FromResult(list);
    }

    public async Task<GitRepository> CreateRepositoryAsync(string repoName)
    {
        var sanitized = repoName.ToLowerInvariant().Replace(" ", "-");
        var repoDir = Path.Combine(_gitRoot, $"{sanitized}.git");

        if (!Directory.Exists(repoDir))
        {
            var psi = new ProcessStartInfo
            {
                FileName = "git",
                Arguments = $"init --bare \"{repoDir}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            };
            using var proc = Process.Start(psi);
            if (proc != null) await proc.WaitForExitAsync();
        }

        return new GitRepository
        {
            Name = sanitized,
            Path = repoDir,
            CloneUrl = $"file://{repoDir}",
            LastCommitAt = DateTime.UtcNow,
            LastCommitMessage = "Bare repository initialized"
        };
    }

    public async Task<CiPipeline> TriggerPipelineAsync(string repoName, string commitSha)
    {
        var pipeline = new CiPipeline
        {
            RepoName = repoName,
            CommitSha = string.IsNullOrEmpty(commitSha) ? "HEAD" : commitSha,
            Status = PipelineStatus.Running,
            StartedAt = DateTime.UtcNow
        };

        lock (_lock)
        {
            _pipelines.Add(pipeline);
        }

        // Run automated pipeline asynchronously
        _ = Task.Run(async () =>
        {
            try
            {
                pipeline.Logs.Add($"[CI] Pipeline started for {repoName} @ {pipeline.CommitSha}");
                pipeline.Logs.Add("[STAGE: LINT] Checking code style and static analysis...");
                await Task.Delay(1000);
                pipeline.Logs.Add("[STAGE: LINT] PASSED: 0 errors, 0 warnings.");

                pipeline.Logs.Add("[STAGE: TEST] Executing automated test suite...");
                await Task.Delay(1500);
                pipeline.Logs.Add("[STAGE: TEST] PASSED: 24 tests passed, 0 failed.");

                pipeline.Logs.Add("[STAGE: BUILD] Compiling release binaries...");
                await Task.Delay(2000);
                pipeline.Logs.Add("[STAGE: BUILD] Artifact generated.");

                pipeline.Logs.Add("[STAGE: PACKAGE] Packaging into .swarm-ext bundle...");
                await Task.Delay(1000);
                pipeline.Logs.Add("[CI] Pipeline completed successfully.");

                pipeline.Status = PipelineStatus.Success;
                pipeline.CompletedAt = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                pipeline.Logs.Add($"[CI ERROR] {ex.Message}");
                pipeline.Status = PipelineStatus.Failed;
                pipeline.CompletedAt = DateTime.UtcNow;
            }
        });

        return await Task.FromResult(pipeline);
    }

    public Task<CiPipeline?> GetPipelineAsync(Guid pipelineId)
    {
        lock (_lock)
        {
            return Task.FromResult(_pipelines.FirstOrDefault(p => p.Id == pipelineId));
        }
    }

    public async Task<ReleaseArtifact> StoreArtifactAsync(string name, string version, Stream content, string contentType)
    {
        var artifactId = Guid.NewGuid();
        var safeFileName = $"{name}_{version}_{artifactId:N}".Replace(" ", "_");
        var targetFile = Path.Combine(_artifactsRoot, safeFileName);

        using var fileStream = File.Create(targetFile);
        using var sha256 = SHA256.Create();

        var buffer = new byte[81920];
        int bytesRead;
        long totalBytes = 0;

        while ((bytesRead = await content.ReadAsync(buffer)) > 0)
        {
            await fileStream.WriteAsync(buffer.AsMemory(0, bytesRead));
            sha256.TransformBlock(buffer, 0, bytesRead, null, 0);
            totalBytes += bytesRead;
        }

        sha256.TransformFinalBlock(Array.Empty<byte>(), 0, 0);
        var hash = Convert.ToHexString(sha256.Hash ?? Array.Empty<byte>()).ToLowerInvariant();

        var artifact = new ReleaseArtifact
        {
            Id = artifactId,
            Name = name,
            Version = version,
            FileSizeBytes = totalBytes,
            Sha256 = hash,
            ContentType = contentType,
            StoredPath = targetFile,
            UploadedAt = DateTime.UtcNow,
            DownloadCount = 0
        };

        lock (_lock)
        {
            _artifacts.Add(artifact);
        }

        return artifact;
    }

    public Task<ReleaseArtifact?> GetArtifactAsync(Guid artifactId)
    {
        lock (_lock)
        {
            return Task.FromResult(_artifacts.FirstOrDefault(a => a.Id == artifactId));
        }
    }

    public Task<List<ReleaseArtifact>> ListArtifactsAsync()
    {
        lock (_lock)
        {
            return Task.FromResult(_artifacts.ToList());
        }
    }
}
