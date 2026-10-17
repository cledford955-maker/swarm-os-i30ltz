using Google.Apis.Drive.v3;
using Google.Apis.Drive.v3.Data;
using Google.Apis.Services;
using DriveFile = Google.Apis.Drive.v3.Data.File;

namespace GoogleWorkspaceService.Services;

public class DriveAgent
{
    private readonly DriveService _svc;

    public DriveAgent(GoogleAuthManager auth)
    {
        _svc = new DriveService(new BaseClientService.Initializer
        {
            HttpClientInitializer = auth.GetCredential(),
            ApplicationName = "SwarmOS"
        });
    }

    public async Task<List<object>> ListFilesAsync(string? query = null, string? folderId = null, int maxResults = 20)
    {
        var req = _svc.Files.List();
        req.PageSize = maxResults;
        req.Fields = "files(id,name,mimeType,size,modifiedTime,webViewLink,parents)";

        var q = "trashed = false";
        if (!string.IsNullOrEmpty(query)) q += $" and name contains '{query}'";
        if (!string.IsNullOrEmpty(folderId)) q += $" and '{folderId}' in parents";
        req.Q = q;

        var resp = await req.ExecuteAsync();
        return (resp.Files ?? new List<DriveFile>()).Select(FormatFile).ToList();
    }

    public async Task<List<object>> SearchAsync(string q, int maxResults = 20)
    {
        var req = _svc.Files.List();
        req.PageSize = maxResults;
        req.Fields = "files(id,name,mimeType,size,modifiedTime,webViewLink)";
        req.Q = $"fullText contains '{q}' and trashed = false";

        var resp = await req.ExecuteAsync();
        return (resp.Files ?? new List<DriveFile>()).Select(FormatFile).ToList();
    }

    public async Task<object> CreateFolderAsync(string name, string? parentId = null)
    {
        var folder = new DriveFile
        {
            Name = name,
            MimeType = "application/vnd.google-apps.folder",
            Parents = parentId != null ? new[] { parentId } : null
        };
        var created = await _svc.Files.Create(folder).ExecuteAsync();
        return FormatFile(created);
    }

    public async Task<bool> ShareFileAsync(string fileId, string email, string role = "reader")
    {
        var permission = new Permission { EmailAddress = email, Role = role, Type = "user" };
        await _svc.Permissions.Create(permission, fileId).ExecuteAsync();
        return true;
    }

    public async Task<bool> DeleteFileAsync(string fileId)
    {
        await _svc.Files.Delete(fileId).ExecuteAsync();
        return true;
    }

    public async Task<object> GetStorageQuotaAsync()
    {
        var req = _svc.About.Get();
        req.Fields = "storageQuota";
        var about = await req.ExecuteAsync();
        var q = about.StorageQuota;
        return new
        {
            limit = q?.Limit,
            usage = q?.Usage,
            usage_in_drive = q?.UsageInDrive,
            usage_in_trash = q?.UsageInDriveTrash
        };
    }

    public async Task<object> GetStatsAsync()
    {
        var files = await ListFilesAsync(maxResults: 1);
        var quota = await GetStorageQuotaAsync();
        return new { quota };
    }

    private static object FormatFile(DriveFile f) => new
    {
        id = f.Id,
        name = f.Name,
        mime_type = f.MimeType,
        size = f.Size,
        modified = f.ModifiedTimeDateTimeOffset,
        web_view_link = f.WebViewLink,
        parents = f.Parents
    };
}
