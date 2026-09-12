using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using EdgeTTS;

namespace LucyServer.Services;

public class TTSService : ITTSService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;

    public TTSService(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _configuration = configuration;
    }

    public async Task<string> GenerateVoiceBase64Async(string text, string voiceName = "en-GB-SoniaNeural")
    {
        var cleanText = text.Replace("*", "");

        if (IsFishAudioVoice(voiceName))
        {
            var apiKey = _configuration["FISH_AUDIO_KEY"] ?? Environment.GetEnvironmentVariable("FISH_AUDIO_KEY");
            if (!string.IsNullOrEmpty(apiKey))
            {
                try
                {
                    return await GenerateFishAudioAsync(cleanText, voiceName, apiKey);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Fish Audio generation failed: {ex.Message}. Falling back to Edge TTS.");
                }
            }
        }

        // Fallback to Edge TTS (FOSS)
        return await GenerateEdgeTTSAsync(cleanText, voiceName);
    }

    private bool IsFishAudioVoice(string voiceName)
    {
        // Simple logic to detect if we should route to Fish Audio API
        // For now, if it doesn't look like an Edge TTS voice (e.g. en-GB-SoniaNeural), route to Fish Audio
        return !voiceName.Contains("Neural") && voiceName.Length == 32; // basic heuristic for Fish Audio Voice IDs
    }

    private async Task<string> GenerateFishAudioAsync(string text, string voiceName, string apiKey)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "https://api.fish.audio/v1/tts");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        
        var payload = new
        {
            text = text,
            reference_id = voiceName,
            format = "mp3"
        };
        
        request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
        
        var response = await _httpClient.SendAsync(request);
        response.EnsureSuccessStatusCode();
        
        var audioBytes = await response.Content.ReadAsByteArrayAsync();
        return Convert.ToBase64String(audioBytes);
    }

    private async Task<string> GenerateEdgeTTSAsync(string text, string voiceName)
    {
        // Default Edge TTS voice if an invalid one was passed and it fell through to here
        if (!voiceName.Contains("Neural"))
        {
            voiceName = "en-GB-SoniaNeural";
        }

        var communicate = new Communicate(text, voiceName, "+5%", "+0%", "+0Hz", null);
        
        using var ms = new MemoryStream();
        await communicate.Stream((data) => 
        {
            if (data.Type == "audio" && data.Data != null)
            {
                data.Data.CopyTo(ms);
            }
        }, default);

        return Convert.ToBase64String(ms.ToArray());
    }
}
