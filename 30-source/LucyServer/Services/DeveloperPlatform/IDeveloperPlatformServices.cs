using LucyServer.Models;

namespace LucyServer.Services.DeveloperPlatform;

public interface IExtensionDevService
{
    Task<LocalExtensionLink> LinkLocalExtensionAsync(string sourcePath);
    Task<List<LocalExtensionLink>> ListLocalExtensionsAsync();
    Task<bool> UnlinkLocalExtensionAsync(string extensionId);
    Task<DependencyResolutionResult> ResolveDependenciesAsync(Dictionary<string, string> requestedDependencies);
    Task<List<ExtensionManifest>> CheckUpdatesAsync();
}

public interface IAppReleaseService
{
    Task<AppRelease> PublishReleaseAsync(AppRelease release);
    Task<List<AppRelease>> GetReleasesAsync(string appId, ReleaseChannel? channel = null);
    Task<bool> PromoteReleaseAsync(Guid releaseId, ReleaseChannel targetChannel);
}

public interface IGitAndCiService
{
    Task<List<GitRepository>> ListRepositoriesAsync();
    Task<GitRepository> CreateRepositoryAsync(string repoName);
    Task<CiPipeline> TriggerPipelineAsync(string repoName, string commitSha);
    Task<CiPipeline?> GetPipelineAsync(Guid pipelineId);
    Task<ReleaseArtifact> StoreArtifactAsync(string name, string version, Stream content, string contentType);
    Task<ReleaseArtifact?> GetArtifactAsync(Guid artifactId);
    Task<List<ReleaseArtifact>> ListArtifactsAsync();
}

public interface IOAuthAndAnalyticsService
{
    Task<string> GetOAuthLoginUrlAsync(string provider);
    Task<bool> HandleOAuthCallbackAsync(string provider, string code);
    Task<DeveloperAnalytics> GetDeveloperAnalyticsAsync();
}
