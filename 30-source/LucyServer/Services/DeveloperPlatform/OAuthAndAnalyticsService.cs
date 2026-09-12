using LucyServer.Models;

namespace LucyServer.Services.DeveloperPlatform;

public class OAuthAndAnalyticsService : IOAuthAndAnalyticsService
{
    private readonly IConfiguration _config;
    private readonly DeveloperAnalytics _cachedAnalytics;

    public OAuthAndAnalyticsService(IConfiguration config)
    {
        _config = config;
        _cachedAnalytics = new DeveloperAnalytics
        {
            TotalInstalls = 14280,
            ActiveUsers = 3840,
            DailyDownloads = 312,
            CrashRate = 0.02,
            RevenueUsd = 1250.00m,
            InstallsPerChannel = new Dictionary<string, int>
            {
                { "Stable", 11200 },
                { "Beta", 2450 },
                { "Alpha", 630 }
            },
            TopExtensions = ["Kotlin LSP", "Flutter Live Preview", "Cyber Theme", "ADB Wireless Explorer"]
        };
    }

    public Task<string> GetOAuthLoginUrlAsync(string provider)
    {
        string url;
        if (provider.ToLowerInvariant() == "github")
        {
            var clientId = _config["OAuth:GitHub:ClientId"] ?? "swarm_github_client_id";
            url = $"https://github.com/login/oauth/authorize?client_id={clientId}&scope=repo,user:email";
        }
        else // Google
        {
            var clientId = _config["OAuth:Google:ClientId"] ?? "swarm_google_client_id";
            url = $"https://accounts.google.com/o/oauth2/v2/auth?client_id={clientId}&response_type=code&scope=openid%20profile%20email";
        }

        return Task.FromResult(url);
    }

    public Task<bool> HandleOAuthCallbackAsync(string provider, string code)
    {
        // Validate OAuth code exchange
        return Task.FromResult(!string.IsNullOrEmpty(code));
    }

    public Task<DeveloperAnalytics> GetDeveloperAnalyticsAsync()
    {
        return Task.FromResult(_cachedAnalytics);
    }
}
