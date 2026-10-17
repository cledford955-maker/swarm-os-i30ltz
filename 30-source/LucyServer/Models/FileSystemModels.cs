namespace LucyServer.Models;

public class FileReadRequest
{
    public string Filename { get; set; } = string.Empty;
}

public class FileSaveRequest
{
    public string Filename { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
}

public class FsAnalyzeRequest
{
    public string Path { get; set; } = string.Empty;
}

public class FileItemInfo
{
    public string Name { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public bool IsDirectory { get; set; }
    public long Size { get; set; }
}
