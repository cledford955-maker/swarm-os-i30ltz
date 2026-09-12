namespace LucyServer.Tests;

/// <summary>
/// Test HTTP message handler for stubbing external API responses.
/// Allows testing LLM API calls (OpenRouter, Gemini, etc.) without mocks.
/// </summary>
public class TestHttpMessageHandler : HttpMessageHandler
{
    private readonly Dictionary<string, Func<HttpRequestMessage, HttpResponseMessage>> _responseMap;

    public TestHttpMessageHandler()
    {
        _responseMap = new Dictionary<string, Func<HttpRequestMessage, HttpResponseMessage>>();
    }

    /// <summary>
    /// Register a stub response for a specific URL pattern.
    /// </summary>
    public void RegisterResponse(string urlPattern, Func<HttpRequestMessage, HttpResponseMessage> responseFactory)
    {
        _responseMap[urlPattern] = responseFactory;
    }

    /// <summary>
    /// Register a simple JSON response for a URL pattern.
    /// </summary>
    public void RegisterJsonResponse(string urlPattern, string jsonContent, int statusCode = 200)
    {
        RegisterResponse(urlPattern, request =>
        {
            var response = new HttpResponseMessage(System.Net.HttpStatusCode.OK);
            response.Content = new StringContent(jsonContent, System.Text.Encoding.UTF8, "application/json");
            return response;
        });
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var requestUrl = request.RequestUri?.ToString() ?? "";

        // Find matching pattern
        foreach (var pattern in _responseMap.Keys)
        {
            if (requestUrl.Contains(pattern))
            {
                var response = _responseMap[pattern](request);
                return Task.FromResult(response);
            }
        }

        // Default: return 404 if no pattern matched
        return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.NotFound));
    }
}

/// <summary>
/// Test responses for common LLM APIs.
/// </summary>
public static class TestLlmResponses
{
    /// <summary>
    /// OpenRouter API response for testing.
    /// </summary>
    public static string GetOpenRouterResponse(string userMessage)
    {
        return $@"{{
            ""id"": ""chatcmpl-test-123"",
            ""object"": ""chat.completion"",
            ""created"": {DateTimeOffset.UtcNow.ToUnixTimeSeconds()},
            ""model"": ""deepseek/deepseek-r1"",
            ""choices"": [
                {{
                    ""index"": 0,
                    ""message"": {{
                        ""role"": ""assistant"",
                        ""content"": ""[TEST] Response to: {userMessage}. This is a test response from OpenRouter stub.""
                    }},
                    ""finish_reason"": ""stop""
                }}
            ],
            ""usage"": {{
                ""prompt_tokens"": 50,
                ""completion_tokens"": 30,
                ""total_tokens"": 80
            }}
        }}";
    }

    /// <summary>
    /// Gemini API response for testing.
    /// </summary>
    public static string GetGeminiResponse(string userMessage)
    {
        return $@"{{
            ""candidates"": [
                {{
                    ""content"": {{
                        ""parts"": [
                            {{
                                ""text"": ""[TEST] Gemini response to: {userMessage}. This is a test response from Gemini stub.""
                            }}
                        ],
                        ""role"": ""model""
                    }},
                    ""finishReason"": ""STOP"",
                    ""safetyRatings"": []
                }}
            ],
            ""usageMetadata"": {{
                ""promptTokenCount"": 100,
                ""candidatesTokenCount"": 50,
                ""totalTokenCount"": 150
            }}
        }}";
    }

    /// <summary>
    /// Edge TTS API response for testing.
    /// </summary>
    public static string GetEdgeTtsResponse()
    {
        return @"{
            ""success"": true,
            ""audio_url"": ""https://test-cdn.example.com/audio/test-123.wav""
        }";
    }
}

/// <summary>
/// Builder for creating test HTTP clients with stubbed responses.
/// </summary>
public class TestHttpClientBuilder
{
    private readonly TestHttpMessageHandler _handler;
    private readonly Dictionary<string, string> _headers;

    public TestHttpClientBuilder()
    {
        _handler = new TestHttpMessageHandler();
        _headers = new Dictionary<string, string>();
    }

    /// <summary>
    /// Add an OpenRouter stub response.
    /// </summary>
    public TestHttpClientBuilder WithOpenRouterStub(string userMessage = "test")
    {
        var response = TestLlmResponses.GetOpenRouterResponse(userMessage);
        _handler.RegisterJsonResponse("openrouter.ai", response);
        return this;
    }

    /// <summary>
    /// Add a Gemini stub response.
    /// </summary>
    public TestHttpClientBuilder WithGeminiStub(string userMessage = "test")
    {
        var response = TestLlmResponses.GetGeminiResponse(userMessage);
        _handler.RegisterJsonResponse("generativelanguage.googleapis.com", response);
        return this;
    }

    /// <summary>
    /// Add a custom response pattern.
    /// </summary>
    public TestHttpClientBuilder WithCustomResponse(string urlPattern, string jsonContent)
    {
        _handler.RegisterJsonResponse(urlPattern, jsonContent);
        return this;
    }

    /// <summary>
    /// Build the HttpClient with stubbed responses.
    /// </summary>
    public HttpClient Build()
    {
        var client = new HttpClient(_handler)
        {
            Timeout = TimeSpan.FromSeconds(5)
        };

        foreach (var header in _headers)
        {
            client.DefaultRequestHeaders.Add(header.Key, header.Value);
        }

        return client;
    }
}
