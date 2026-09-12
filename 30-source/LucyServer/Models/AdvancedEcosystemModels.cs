using System;
using System.Collections.Generic;

namespace LucyServer.Models
{
    // =========================================================================
    // 1 & 2. AI Coding Agents & Suggested Code Assistance
    // =========================================================================
    public enum CodingAgentRole
    {
        Architect,
        LeadCoder,
        SecurityAuditor,
        TestEngineer,
        RefactorSpecialist
    }

    public class AiCodingAgentTask
    {
        public string TaskId { get; set; } = Guid.NewGuid().ToString("N");
        public string Title { get; set; } = string.Empty;
        public string Prompt { get; set; } = string.Empty;
        public string ActiveFilePath { get; set; } = string.Empty;
        public string Language { get; set; } = "dart";
        public CodingAgentRole AssignedRole { get; set; } = CodingAgentRole.LeadCoder;
        public string Status { get; set; } = "Pending"; // Pending, InProgress, Completed, Failed
        public List<string> ExecutionSteps { get; set; } = new();
        public string GeneratedCode { get; set; } = string.Empty;
        public string DiffPreview { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class SuggestedCodeFix
    {
        public string FixId { get; set; } = Guid.NewGuid().ToString("N");
        public string DiagnosticCode { get; set; } = string.Empty; // e.g., unused_import, CS8618
        public string Message { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public int LineNumber { get; set; }
        public string OriginalCode { get; set; } = string.Empty;
        public string ReplacementCode { get; set; } = string.Empty;
        public string Explanation { get; set; } = string.Empty;
        public double ConfidenceScore { get; set; } = 0.95;
    }

    // =========================================================================
    // 3. Cloud Remote Workspaces
    // =========================================================================
    public class CloudWorkspace
    {
        public string WorkspaceId { get; set; } = Guid.NewGuid().ToString("N");
        public string Name { get; set; } = string.Empty;
        public string RemoteHost { get; set; } = string.Empty;
        public int SshPort { get; set; } = 22;
        public string Username { get; set; } = "swarm";
        public string AuthType { get; set; } = "SSH_KEY"; // SSH_KEY, PASSWORD, MTLS
        public string RemotePath { get; set; } = "/home/swarm/workspace";
        public string Status { get; set; } = "Disconnected"; // Connected, Disconnected, Syncing, Error
        public int LatencyMs { get; set; } = 0;
        public long MemoryUsedMb { get; set; }
        public long MemoryTotalMb { get; set; }
        public double CpuUsagePercent { get; set; }
        public DateTime LastSyncedAt { get; set; } = DateTime.UtcNow;
    }

    // =========================================================================
    // 4, 5, 6 & 7. App Store, Social Discovery, Monetization & Community Templates
    // =========================================================================
    public class CommunityTemplate
    {
        public string TemplateId { get; set; } = Guid.NewGuid().ToString("N");
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Category { get; set; } = "Mobile"; // Mobile, Desktop, Systems, AI, Web
        public string Author { get; set; } = string.Empty;
        public string RepoUrl { get; set; } = string.Empty;
        public List<string> Tags { get; set; } = new();
        public double Rating { get; set; } = 5.0;
        public int Downloads { get; set; } = 0;
        public bool IsVerified { get; set; } = true;
        public bool IsPaid { get; set; } = false;
        public decimal PriceUsd { get; set; } = 0.00m;
        public DateTime PublishedAt { get; set; } = DateTime.UtcNow;
    }

    public class SocialExtensionReview
    {
        public string ReviewId { get; set; } = Guid.NewGuid().ToString("N");
        public string ExtensionId { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public double Rating { get; set; } = 5.0;
        public string Comment { get; set; } = string.Empty;
        public int Upvotes { get; set; } = 0;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class MarketplaceBillingRecord
    {
        public string TransactionId { get; set; } = Guid.NewGuid().ToString("N");
        public string ItemId { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public string BuyerId { get; set; } = string.Empty;
        public string DeveloperId { get; set; } = string.Empty;
        public decimal GrossAmountUsd { get; set; }
        public decimal PlatformFeeUsd { get; set; } // 15%
        public decimal DeveloperPayoutUsd { get; set; } // 85%
        public string LicenseKey { get; set; } = string.Empty;
        public string PaymentStatus { get; set; } = "Completed";
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    public class MarketplaceAnalyticsSummary
    {
        public decimal TotalGrossRevenue { get; set; }
        public decimal TotalDeveloperPayouts { get; set; }
        public int TotalTransactions { get; set; }
        public int ActivePaidSubscriptions { get; set; }
        public List<MarketplaceBillingRecord> RecentTransactions { get; set; } = new();
    }

    // =========================================================================
    // 8 & 9. Screen Mirroring & Device Performance Stats
    // =========================================================================
    public class ScreenMirrorSession
    {
        public string SessionId { get; set; } = Guid.NewGuid().ToString("N");
        public string DeviceSerial { get; set; } = string.Empty;
        public string DeviceModel { get; set; } = string.Empty;
        public bool IsWireless { get; set; } = false;
        public string IpAddress { get; set; } = string.Empty;
        public int Port { get; set; } = 5555;
        public int MaxFps { get; set; } = 60;
        public int BitrateMbps { get; set; } = 8;
        public bool ForwardAudio { get; set; } = true;
        public bool StayAwake { get; set; } = true;
        public string Status { get; set; } = "Active"; // Active, Paused, Terminated
        public int Pid { get; set; }
        public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    }

    public class DeviceHardwareStats
    {
        public string DeviceName { get; set; } = "SWARM OS Host";
        public double CpuFrequencyGhz { get; set; } = 3.8;
        public double CpuTemperatureCelsius { get; set; } = 48.5;
        public bool IsThermalThrottling { get; set; } = false;
        public double GpuCoreUsagePercent { get; set; } = 22.0;
        public double GpuMemoryUsedGb { get; set; } = 4.2;
        public double GpuMemoryTotalGb { get; set; } = 16.0;
        public double TensorCoreUtilization { get; set; } = 15.0;
        public int BatteryPercentage { get; set; } = 100;
        public bool IsCharging { get; set; } = true;
        public long SystemUpTimeSeconds { get; set; }
        public DateTime SampleTime { get; set; } = DateTime.UtcNow;
    }

    // =========================================================================
    // 10 & 11. Telemetry, Crash Reports & App Analytics
    // =========================================================================
    public class CrashReport
    {
        public string CrashId { get; set; } = Guid.NewGuid().ToString("N");
        public string AppName { get; set; } = "SWARM OS Desktop";
        public string Version { get; set; } = "6.2.2";
        public string ExceptionType { get; set; } = string.Empty;
        public string ExceptionMessage { get; set; } = string.Empty;
        public string RawStackTrace { get; set; } = string.Empty;
        public List<string> SymbolicatedFrames { get; set; } = new();
        public Dictionary<string, string> EnvironmentMetadata { get; set; } = new();
        public string Severity { get; set; } = "Error"; // Critical, Error, Warning
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    public class AppAnalyticsReport
    {
        public string AppId { get; set; } = string.Empty;
        public int DailyActiveUsers { get; set; } = 1420;
        public int MonthlyActiveUsers { get; set; } = 8900;
        public double AverageSessionMinutes { get; set; } = 42.5;
        public double CrashFreeUserRatePercent { get; set; } = 99.8;
        public Dictionary<string, int> PlatformBreakdown { get; set; } = new()
        {
            { "Linux x86_64", 65 },
            { "Android Arm64", 25 },
            { "Windows / macOS VMs", 10 }
        };
    }

    // =========================================================================
    // 12, 13, 14 & 15. RBAC, Audit Logs, Malware Scanning & Signed Dev Identities
    // =========================================================================
    public class AuditLogEntry
    {
        public string LogId { get; set; } = Guid.NewGuid().ToString("N");
        public string Principal { get; set; } = "i30ltz";
        public string Action { get; set; } = string.Empty;
        public string Resource { get; set; } = string.Empty;
        public string Details { get; set; } = string.Empty;
        public string IpAddress { get; set; } = "127.0.0.1";
        public bool Succeeded { get; set; } = true;
        public string PreviousBlockHash { get; set; } = string.Empty;
        public string EntryHash { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    public class MalwareScanReport
    {
        public string ScanId { get; set; } = Guid.NewGuid().ToString("N");
        public string PackagePath { get; set; } = string.Empty;
        public string PackageName { get; set; } = string.Empty;
        public long FileSizeBytes { get; set; }
        public string Sha256Hash { get; set; } = string.Empty;
        public int ThreatScore { get; set; } = 0; // 0 (Clean) to 100 (Malicious)
        public string Verdict { get; set; } = "CLEAN"; // CLEAN, SUSPICIOUS, MALICIOUS
        public List<string> DangerousPermissionsDetected { get; set; } = new();
        public List<string> SuspiciousStringsOrUrls { get; set; } = new();
        public List<string> SecurityRecommendations { get; set; } = new();
        public DateTime ScannedAt { get; set; } = DateTime.UtcNow;
    }

    public class DeveloperIdentity
    {
        public string DeveloperId { get; set; } = Guid.NewGuid().ToString("N");
        public string CommonName { get; set; } = string.Empty;
        public string Organization { get; set; } = "SWARM OS Ecosystem";
        public string FingerprintSha256 { get; set; } = string.Empty;
        public bool IsVerified { get; set; } = true;
        public string VerificationTier { get; set; } = "Enterprise Gold";
        public DateTime CertificateExpiry { get; set; } = DateTime.UtcNow.AddYears(2);
        public string PublicKeyPem { get; set; } = string.Empty;
    }
}
