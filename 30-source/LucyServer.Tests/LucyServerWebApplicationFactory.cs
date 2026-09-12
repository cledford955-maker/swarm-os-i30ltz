using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using LucyServer.Services;
using Fido2NetLib;
using Fido2NetLib.Objects;

namespace LucyServer.Tests;

/// <summary>
/// WebApplicationFactory for integration testing LucyServer.
/// Provides real services with in-memory storage for zero-mock testing.
/// </summary>
public class LucyServerWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove production services if needed
            var fileSystemDescriptor = services.FirstOrDefault(
                d => d.ServiceType == typeof(IFileSystemService));
            if (fileSystemDescriptor != null)
                services.Remove(fileSystemDescriptor);

            var memoryDescriptor = services.FirstOrDefault(
                d => d.ServiceType == typeof(IMemoryService));
            if (memoryDescriptor != null)
                services.Remove(memoryDescriptor);

            // Add test implementations with real file I/O using temp directories
            services.AddScoped<IFileSystemService>(sp =>
            {
                var tempDir = Path.Combine(Path.GetTempPath(), "lucy_server_tests");
                Directory.CreateDirectory(tempDir);
                return new TestFileSystemService(tempDir);
            });

            services.AddScoped<IMemoryService, TestMemoryService>();

            // Auth service can use real FIDO2 with test credentials
            services.AddSingleton<IAuthService, WebAuthnService>();
        });

        builder.UseEnvironment("Testing");
    }
}

/// <summary>
/// Test implementation of IFileSystemService that uses a temp directory.
/// No mocks - uses real file I/O in isolated temp directory.
/// </summary>
public class TestFileSystemService : FileSystemService
{
    private readonly string _testDirectory;

    public TestFileSystemService(string testDirectory) : base(new TestSystemIntegrationService())
    {
        _testDirectory = testDirectory;
        Directory.CreateDirectory(testDirectory);
    }

    public override Task<IEnumerable<FileItemInfo>> ListDirectoryAsync(string path)
    {
        // Sandbox to test directory
        var safePath = Path.Combine(_testDirectory, Path.GetFileName(path) ?? "");
        return base.ListDirectoryAsync(safePath);
    }

    public override Task<string> ReadFileAsync(string filename)
    {
        var safePath = Path.Combine(_testDirectory, Path.GetFileName(filename) ?? "");
        return base.ReadFileAsync(safePath);
    }

    public override Task<bool> SaveFileAsync(string filename, string content)
    {
        var safePath = Path.Combine(_testDirectory, Path.GetFileName(filename) ?? "");
        return base.SaveFileAsync(safePath, content);
    }
}

/// <summary>
/// Test implementation of IMemoryService using in-memory storage.
/// </summary>
public class TestMemoryService : IMemoryService
{
    private string _memoryContent = string.Empty;

    public Task<string> GetMemoryContextAsync()
    {
        return Task.FromResult(_memoryContent);
    }

    public Task SetMemoryContextAsync(string content)
    {
        _memoryContent = content;
        return Task.CompletedTask;
    }
}

/// <summary>
/// Test implementation of ISystemIntegrationService that doesn't actually execute shell commands.
/// </summary>
public class TestSystemIntegrationService : ISystemIntegrationService
{
    public Task<(string StandardOutput, string StandardError, int ExitCode)> RunCommandAsync(string command)
    {
        // Return mock output for testing
        var output = $"[TEST] Command: {command}\n[TEST] Execution simulated - no actual system commands run";
        return Task.FromResult((output, string.Empty, 0));
    }
}
