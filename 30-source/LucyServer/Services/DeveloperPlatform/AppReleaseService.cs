using LucyServer.Models;

namespace LucyServer.Services.DeveloperPlatform;

public class AppReleaseService : IAppReleaseService
{
    private readonly List<AppRelease> _releases = new();
    private readonly object _lock = new();

    public Task<AppRelease> PublishReleaseAsync(AppRelease release)
    {
        lock (_lock)
        {
            release.PublishedAt = DateTime.UtcNow;
            _releases.Add(release);
            return Task.FromResult(release);
        }
    }

    public Task<List<AppRelease>> GetReleasesAsync(string appId, ReleaseChannel? channel = null)
    {
        lock (_lock)
        {
            var query = _releases.Where(r => r.AppId.Equals(appId, StringComparison.OrdinalIgnoreCase));
            if (channel.HasValue)
            {
                query = query.Where(r => r.Channel == channel.Value);
            }
            return Task.FromResult(query.OrderByDescending(r => r.PublishedAt).ToList());
        }
    }

    public Task<bool> PromoteReleaseAsync(Guid releaseId, ReleaseChannel targetChannel)
    {
        lock (_lock)
        {
            var release = _releases.FirstOrDefault(r => r.Id == releaseId);
            if (release == null) return Task.FromResult(false);

            release.Channel = targetChannel;
            release.PublishedAt = DateTime.UtcNow;
            return Task.FromResult(true);
        }
    }
}
