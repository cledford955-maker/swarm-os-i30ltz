namespace LucyServer.Services;

public class GenerateVoiceRequest
{
    public required string Text { get; set; }
    public string VoiceName { get; set; } = "en-GB-SoniaNeural";
}

public interface ITTSService
{
    Task<string> GenerateVoiceBase64Async(string text, string voiceName = "en-GB-SoniaNeural");
}
