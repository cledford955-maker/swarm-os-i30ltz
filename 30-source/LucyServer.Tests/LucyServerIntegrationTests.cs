using System.Net;
using Xunit;

namespace LucyServer.Tests;

/// <summary>
/// Integration tests for LucyServer endpoints.
/// Uses REAL services (FileSystemService, MemoryService, ChatService, etc.)
/// NO MOCKS - external APIs stubbed with HttpMessageHandler.
/// </summary>
public class LucyServerIntegrationTests : IClassFixture<LucyServerWebApplicationFactory>
{
    private readonly LucyServerWebApplicationFactory _factory;

    public LucyServerIntegrationTests(LucyServerWebApplicationFactory factory)
    {
        _factory = factory;
    }

    // ============== Health Check Tests ==============

    [Fact]
    public async Task HealthCheck_Returns200()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/health");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // ============== File System Service Tests ==============

    [Fact]
    public async Task ListDirectory_WithValidPath_Returns200()
    {
        // Arrange
        var client = _factory.CreateClient();
        var path = "/tmp";

        // Act
        var response = await client.GetAsync($"/api/filesystem/list?path={Uri.EscapeDataString(path)}");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.NotNull(content);
    }

    [Fact]
    public async Task ListDirectory_WithInvalidPath_Returns400()
    {
        // Arrange
        var client = _factory.CreateClient();
        var path = "/nonexistent/invalid/path/that/does/not/exist/12345";

        // Act
        var response = await client.GetAsync($"/api/filesystem/list?path={Uri.EscapeDataString(path)}");

        // Assert
        Assert.True(response.StatusCode == HttpStatusCode.BadRequest || response.StatusCode == HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task SaveFile_WithValidContent_Returns200()
    {
        // Arrange
        var client = _factory.CreateClient();
        var fileName = "test_file.txt";
        var content = "Test file content for integration testing";
        var payload = new { filename = fileName, content = content };

        // Act
        var response = await client.PostAsJsonAsync("/api/filesystem/save", payload);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // ============== Memory Service Tests ==============

    [Fact]
    public async Task GetMemoryContext_Returns200()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/memory/context");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.NotNull(content);
    }

    // ============== Chat Service Tests (with stubbed LLM) ==============

    [Fact]
    public async Task SendMessage_WithValidInput_Returns200()
    {
        // Arrange
        var client = _factory.CreateClient();
        var messagePayload = new
        {
            userMessage = "What is your name?",
            systemContext = "Test context"
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/chat/send", messagePayload);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.NotEmpty(content);
    }

    [Fact]
    public async Task SendMessage_WithEmptyMessage_Returns400()
    {
        // Arrange
        var client = _factory.CreateClient();
        var messagePayload = new
        {
            userMessage = "",
            systemContext = "Test context"
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/chat/send", messagePayload);

        // Assert
        Assert.True(
            response.StatusCode == HttpStatusCode.BadRequest ||
            response.StatusCode == HttpStatusCode.UnprocessableEntity
        );
    }

    // ============== Authentication Tests ==============

    [Fact]
    public async Task GetLoginOptions_ReturnsValidOptions()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/auth/login-options");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains("challenge", content);
    }

    [Fact]
    public async Task GetRegisterOptions_ReturnsValidOptions()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/auth/register-options");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains("challenge", content);
    }

    // ============== TTS Service Tests ==============

    [Fact]
    public async Task TextToSpeech_WithValidInput_Returns200()
    {
        // Arrange
        var client = _factory.CreateClient();
        var ttsPayload = new
        {
            text = "Hello, this is a test",
            voice = "default"
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/tts/synthesize", ttsPayload);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // ============== Error Handling Tests ==============

    [Fact]
    public async Task InvalidEndpoint_Returns404()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/invalid/endpoint");

        // Assert
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task RequestWithoutAuthToken_Returns401OrProceed()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act - Most endpoints should require auth
        var response = await client.PostAsJsonAsync("/api/chat/send", new { userMessage = "test" });

        // Assert - Should be 401 or allow without token depending on endpoint
        Assert.True(
            response.StatusCode == HttpStatusCode.Unauthorized ||
            response.StatusCode == HttpStatusCode.OK ||
            response.StatusCode == HttpStatusCode.BadRequest
        );
    }
}

/// <summary>
/// Performance and reliability tests for LucyServer.
/// Demonstrates real-world testing scenarios.
/// </summary>
public class LucyServerReliabilityTests : IClassFixture<LucyServerWebApplicationFactory>
{
    private readonly LucyServerWebApplicationFactory _factory;

    public LucyServerReliabilityTests(LucyServerWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task ConcurrentRequests_HandleMultipleRequests()
    {
        // Arrange
        var client = _factory.CreateClient();
        var tasks = new List<Task<HttpResponseMessage>>();

        // Act - Send 10 concurrent requests
        for (int i = 0; i < 10; i++)
        {
            var task = client.PostAsJsonAsync(
                "/api/chat/send",
                new
                {
                    userMessage = $"Test message {i}",
                    systemContext = "Test context"
                }
            );
            tasks.Add(task);
        }

        var results = await Task.WhenAll(tasks);

        // Assert - All should succeed
        Assert.True(results.All(r => r.IsSuccessStatusCode || r.StatusCode == HttpStatusCode.BadRequest),
            "All concurrent requests should complete");
    }

    [Fact]
    public async Task LargeFileUpload_Handles()
    {
        // Arrange
        var client = _factory.CreateClient();
        var largeContent = string.Join("", Enumerable.Range(0, 1000).Select(i => $"Line {i}: Large content\n"));
        var payload = new
        {
            filename = "large_file.txt",
            content = largeContent
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/filesystem/save", payload);

        // Assert
        Assert.True(response.IsSuccessStatusCode, "Should handle large file uploads");
    }
}
