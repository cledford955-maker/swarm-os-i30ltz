namespace LucyServer.Models;

public enum ReleaseChannel
{
    Alpha,
    Beta,
    RC,
    Stable
}

public class AppRelease
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string AppId { get; set; } = string.Empty;
    public string Version { get; set; } = "1.0.0";
    public ReleaseChannel Channel { get; set; } = ReleaseChannel.Stable;
    public string Changelog { get; set; } = string.Empty;
    public string ArtifactUrl { get; set; } = string.Empty;
    public string Sha256Checksum { get; set; } = string.Empty;
    public string MinOsVersion { get; set; } = "6.2.0";
    public int RolloutPercentage { get; set; } = 100;
    public DateTime PublishedAt { get; set; } = DateTime.UtcNow;
}

public class ExtensionManifest
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Version { get; set; } = "1.0.0";
    public string DisplayName { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Author { get; set; } = string.Empty;
    public string EntryPoint { get; set; } = "main.dart";
    public List<string> Permissions { get; set; } = new();
    public Dictionary<string, string> Dependencies { get; set; } = new();
    public Dictionary<string, object> Contributes { get; set; } = new();
}

public class LocalExtensionLink
{
    public string ExtensionId { get; set; } = string.Empty;
    public string SourcePath { get; set; } = string.Empty;
    public ExtensionManifest Manifest { get; set; } = new();
    public DateTime LinkedAt { get; set; } = DateTime.UtcNow;
    public bool IsWatching { get; set; } = true;
}

public class DependencyResolutionResult
{
    public bool Success { get; set; }
    public Dictionary<string, string> ResolvedPackages { get; set; } = new();
    public List<string> MissingDependencies { get; set; } = new();
    public List<string> VersionConflicts { get; set; } = new();
}

public class GitRepository
{
    public string Name { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public string DefaultBranch { get; set; } = "main";
    public int CommitCount { get; set; }
    public string LastCommitMessage { get; set; } = string.Empty;
    public DateTime LastCommitAt { get; set; } = DateTime.UtcNow;
    public string CloneUrl { get; set; } = string.Empty;
}

public enum PipelineStatus
{
    Queued,
    Running,
    Success,
    Failed,
    Cancelled
}

public class CiPipeline
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string RepoName { get; set; } = string.Empty;
    public string CommitSha { get; set; } = string.Empty;
    public PipelineStatus Status { get; set; } = PipelineStatus.Queued;
    public List<string> Stages { get; set; } = ["lint", "test", "build", "package"];
    public List<string> Logs { get; set; } = new();
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
}

public class ReleaseArtifact
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public string Sha256 { get; set; } = string.Empty;
    public string ContentType { get; set; } = "application/octet-stream";
    public int DownloadCount { get; set; }
    public string StoredPath { get; set; } = string.Empty;
    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
}

public class DeveloperAnalytics
{
    public int TotalInstalls { get; set; }
    public int ActiveUsers { get; set; }
    public int DailyDownloads { get; set; }
    public double CrashRate { get; set; }
    public decimal RevenueUsd { get; set; }
    public Dictionary<string, int> InstallsPerChannel { get; set; } = new();
    public List<string> TopExtensions { get; set; } = new();
}
