namespace LucyServer.Models;

public class RunCommandRequest
{
    public string Command { get; set; } = string.Empty;
    public string? Cwd { get; set; }
}

public class KillProcessRequest
{
    public int Pid { get; set; }
}

public class UninstallPackageRequest
{
    public string PackageName { get; set; } = string.Empty;
}

public class SetClipboardRequest
{
    public string Text { get; set; } = string.Empty;
}

public class VoiceSettingRequest
{
    public string? Voice { get; set; }
}

public class PasswordRequest
{
    public string? Password { get; set; }
}

public class GfnOptimizeRequest
{
    public string? Game { get; set; }
}

public class RagIngestRequest
{
    public string? Text { get; set; }
    public string? Source { get; set; }
}

public class RagFileRequest
{
    public string? FilePath { get; set; }
}
