using System;
using System.Collections.Generic;

namespace LucyServer.Models.Marketplace
{
    /// <summary>
    /// Represents a publishable item in the marketplace (extension, template, tool, etc.)
    /// </summary>
    public class MarketplaceItem
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        
        // Basic Info
        public string Name { get; set; }
        public string Description { get; set; }
        public string Category { get; set; } // LanguageServer, Debugger, Template, EmulatorPlugin, etc.
        public string Type { get; set; } // "extension", "template", "tool"
        
        // Metadata
        public string Version { get; set; } = "1.0.0";
        public string Author { get; set; }
        public Guid AuthorId { get; set; } // FK to Developer
        public string IconUrl { get; set; }
        public string RepositoryUrl { get; set; } // GitHub or self-hosted Git
        public string DocumentationUrl { get; set; }
        public string LicenseType { get; set; } // MIT, Apache-2.0, proprietary, GPL-3.0
        
        // Ratings & Engagement
        public decimal AverageRating { get; set; } = 0m; // 0.0 - 5.0
        public int RatingCount { get; set; } = 0;
        public int InstallCount { get; set; } = 0;
        public int DownloadCount { get; set; } = 0;
        
        // Marketplace Status
        public MarketplaceStatus Status { get; set; } = MarketplaceStatus.Draft;
        public DateTime PublishedAt { get; set; }
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        
        // Compatibility
        public string[] SupportedLanguages { get; set; } = Array.Empty<string>(); // Kotlin, Java, Dart, Python, TypeScript
        public string[] SupportedPlatforms { get; set; } = Array.Empty<string>(); // Android, iOS, Web, Linux
        public string[] Tags { get; set; } = Array.Empty<string>(); // linter, formatter, debugger, ai-assistant
        public string MinCoderVersion { get; set; } = "1.0.0";
        
        // Monetization
        public bool IsFree { get; set; } = true;
        public decimal? PriceUsd { get; set; }
        public int? FreeDownloadLimit { get; set; } // null = unlimited free downloads
        
        // Content & Assets
        public string DownloadUrl { get; set; } // Direct download link or S3 presigned URL
        public string ManifestUrl { get; set; } // manifest.json location
        public long FileSizeBytes { get; set; }
        
        // Verification & Moderation
        public bool IsVerified { get; set; } = false;
        public bool IsFeatured { get; set; } = false;
        public string ModerationNotes { get; set; }
        
        // Navigation
        public virtual Developer Developer { get; set; }
        public virtual ICollection<ItemRating> Ratings { get; set; } = new List<ItemRating>();
        public virtual ICollection<Installation> Installations { get; set; } = new List<Installation>();
        public virtual ICollection<ItemVersion> VersionHistory { get; set; } = new List<ItemVersion>();
    }

    public enum MarketplaceStatus
    {
        Draft,           // Not yet published
        PendingReview,   // Awaiting moderation
        Published,       // Available in marketplace
        Featured,        // Promoted to featured section
        Deprecated,      // Old version, hidden but available
        Removed          // Taken down (history kept)
    }

    public enum ItemCategory
    {
        LanguageServer,
        Debugger,
        Formatter,
        Linter,
        Theme,
        CodeSnippet,
        Template,
        EmulatorPlugin,
        ADBTool,
        APKBuilder,
        PlayConsoleIntegration,
        AnalyticsTool,
        AIAssistant,
        DeviceEmulator,
        Tool
    }

    /// <summary>
    /// Developer/Publisher account
    /// </summary>
    public class Developer
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        
        // Profile
        public string Username { get; set; }
        public string DisplayName { get; set; }
        public string Bio { get; set; }
        public string ProfilePictureUrl { get; set; }
        public string Email { get; set; }
        
        // OAuth
        public string GitHubUsername { get; set; }
        public string GitHubUserId { get; set; }
        public string GitHubAccessToken { get; set; } // Encrypted
        
        // Play Console Auth (encrypted in DB)
        public string PlayConsoleRefreshToken { get; set; }
        public DateTime? PlayConsoleTokenExpiresAt { get; set; }
        
        // Stats
        public decimal TotalEarnings { get; set; } = 0m;
        public int TotalInstalls { get; set; } = 0;
        public int TotalDownloads { get; set; } = 0;
        public decimal AverageRating { get; set; } = 0m;
        
        // Verification
        public bool EmailVerified { get; set; } = false;
        public bool GitHubVerified { get; set; } = false;
        public DeveloperTier Tier { get; set; } = DeveloperTier.Community;
        
        // Settings & Privacy
        public bool AllowAnalytics { get; set; } = true;
        public bool AllowContactingAboutUpdates { get; set; } = true;
        public bool AllowPublicProfile { get; set; } = true;
        
        // Metadata
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime LastActivityAt { get; set; } = DateTime.UtcNow;
        
        // Navigation
        public virtual ICollection<MarketplaceItem> PublishedItems { get; set; } = new List<MarketplaceItem>();
        public virtual ICollection<ItemRating> Ratings { get; set; } = new List<ItemRating>();
        public virtual ICollection<Installation> Installations { get; set; } = new List<Installation>();
    }

    public enum DeveloperTier
    {
        Community,    // Default
        Verified,     // Email + GitHub verified
        Featured,     // High ratings + install count (>1000)
        Partner       // Direct collaboration with Luccile team
    }

    /// <summary>
    /// Track installations per device/developer
    /// </summary>
    public class Installation
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        
        public Guid MarketplaceItemId { get; set; }
        public Guid DeveloperId { get; set; }
        
        public string InstalledVersion { get; set; }
        public DateTime InstalledAt { get; set; } = DateTime.UtcNow;
        public DateTime? UninstalledAt { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        // Navigation
        public virtual MarketplaceItem MarketplaceItem { get; set; }
        public virtual Developer Developer { get; set; }
    }

    /// <summary>
    /// User ratings and reviews
    /// </summary>
    public class ItemRating
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        
        public Guid MarketplaceItemId { get; set; }
        public Guid DeveloperId { get; set; }
        
        public int Rating { get; set; } // 1-5 stars
        public string ReviewTitle { get; set; }
        public string ReviewText { get; set; }
        public int HelpfulCount { get; set; } = 0;
        
        public DateTime RatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation
        public virtual MarketplaceItem MarketplaceItem { get; set; }
        public virtual Developer Developer { get; set; }
    }

    /// <summary>
    /// Version history for marketplace items
    /// </summary>
    public class ItemVersion
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        
        public Guid MarketplaceItemId { get; set; }
        
        public string VersionNumber { get; set; }
        public string ChangeLog { get; set; }
        public string DownloadUrl { get; set; }
        public long FileSizeBytes { get; set; }
        
        public DateTime ReleasedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation
        public virtual MarketplaceItem MarketplaceItem { get; set; }
    }

    /// <summary>
    /// Project templates for scaffolding
    /// </summary>
    public class Template
    {
        public Guid Id { get; set; } = Guid.NewGuid();
        
        public string Name { get; set; }
        public string Description { get; set; }
        public string Category { get; set; } // Android, Flutter, Web, Python, CLI
        public string Language { get; set; } // Kotlin, Dart, TypeScript, Python
        
        public string GitRepositoryUrl { get; set; }
        public string GitBranch { get; set; } = "main";
        public string IconUrl { get; set; }
        
        // Template variables to replace
        public Dictionary<string, TemplateVariable> PlaceholderVariables { get; set; } = new();
        
        public string[] RequiredTools { get; set; } = Array.Empty<string>(); // kotlin, gradle, git, dart
        public bool IsCommunityTemplate { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }

    public class TemplateVariable
    {
        public string Name { get; set; }
        public string DefaultValue { get; set; }
        public string Description { get; set; }
        public string Placeholder { get; set; } // {{APP_NAME}}
        public string[] PredefinedOptions { get; set; } // null or array of choices
        public string ValidationRegex { get; set; } // Regex pattern validation
    }
}
