using Google.Apis.Gmail.v1;
using Google.Apis.Gmail.v1.Data;
using Google.Apis.Services;
using MimeKit;
using System.Text;
using GMailMessagePart = Google.Apis.Gmail.v1.Data.MessagePart;

namespace GoogleWorkspaceService.Services;

public class GmailAgent
{
    private readonly GmailService _svc;

    public GmailAgent(GoogleAuthManager auth)
    {
        _svc = new GmailService(new BaseClientService.Initializer
        {
            HttpClientInitializer = auth.GetCredential(),
            ApplicationName = "SwarmOS"
        });
    }

    public async Task<List<object>> GetInboxAsync(int maxResults = 20, string? query = null,
        string label = "INBOX", bool unreadOnly = false)
    {
        var q = query ?? "";
        if (unreadOnly) q = ("is:unread " + q).Trim();

        var req = _svc.Users.Messages.List("me");
        req.MaxResults = maxResults;
        req.LabelIds = label;
        req.Q = q;

        var listResp = await req.ExecuteAsync();
        var messages = listResp.Messages ?? new List<Message>();
        var result = new List<object>();

        foreach (var msg in messages)
        {
            var full = await _svc.Users.Messages.Get("me", msg.Id).ExecuteAsync();
            result.Add(FormatMessage(full));
        }

        return result;
    }

    public async Task<object?> GetMessageAsync(string messageId)
    {
        var msg = await _svc.Users.Messages.Get("me", messageId).ExecuteAsync();
        return msg == null ? null : FormatMessage(msg);
    }

    public async Task<List<object>> SearchAsync(string q, int maxResults = 20)
    {
        var req = _svc.Users.Messages.List("me");
        req.Q = q;
        req.MaxResults = maxResults;
        var listResp = await req.ExecuteAsync();
        var result = new List<object>();
        foreach (var msg in listResp.Messages ?? new List<Message>())
        {
            var full = await _svc.Users.Messages.Get("me", msg.Id).ExecuteAsync();
            result.Add(FormatMessage(full));
        }
        return result;
    }

    public async Task<int> GetUnreadCountAsync()
    {
        var req = _svc.Users.Messages.List("me");
        req.Q = "is:unread";
        req.MaxResults = 1;
        var resp = await req.ExecuteAsync();
        return (int)(resp.ResultSizeEstimate ?? 0);
    }

    public async Task<object> SendAsync(string to, string subject, string body, string? cc = null,
        string? bcc = null, bool html = false)
    {
        var mime = new MimeMessage();
        mime.To.Add(MailboxAddress.Parse(to));
        mime.Subject = subject;
        if (!string.IsNullOrEmpty(cc)) mime.Cc.Add(MailboxAddress.Parse(cc));
        if (!string.IsNullOrEmpty(bcc)) mime.Bcc.Add(MailboxAddress.Parse(bcc));
        mime.Body = new TextPart(html ? MimeKit.Text.TextFormat.Html : MimeKit.Text.TextFormat.Plain) { Text = body };

        using var ms = new MemoryStream();
        await mime.WriteToAsync(ms);
        var raw = Convert.ToBase64String(ms.ToArray()).Replace('+', '-').Replace('/', '_').TrimEnd('=');

        var sent = await _svc.Users.Messages.Send(new Message { Raw = raw }, "me").ExecuteAsync();
        return new { id = sent.Id, thread_id = sent.ThreadId };
    }

    public async Task<object> ReplyAsync(string messageId, string body, bool html = false, bool replyAll = false)
    {
        var orig = await _svc.Users.Messages.Get("me", messageId).ExecuteAsync();
        var headers = orig.Payload?.Headers?.ToDictionary(h => h.Name, h => h.Value) ?? new();

        var to = replyAll ? headers.GetValueOrDefault("From", "") : headers.GetValueOrDefault("From", "");
        var subject = "Re: " + headers.GetValueOrDefault("Subject", "");
        var threadId = orig.ThreadId;

        var mime = new MimeMessage();
        mime.To.Add(MailboxAddress.Parse(to));
        mime.Subject = subject;
        mime.Headers.Add("In-Reply-To", headers.GetValueOrDefault("Message-ID", ""));
        mime.Body = new TextPart(html ? MimeKit.Text.TextFormat.Html : MimeKit.Text.TextFormat.Plain) { Text = body };

        using var ms = new MemoryStream();
        await mime.WriteToAsync(ms);
        var raw = Convert.ToBase64String(ms.ToArray()).Replace('+', '-').Replace('/', '_').TrimEnd('=');

        var sent = await _svc.Users.Messages.Send(new Message { Raw = raw, ThreadId = threadId }, "me").ExecuteAsync();
        return new { id = sent.Id, thread_id = sent.ThreadId };
    }

    public async Task<object> CreateDraftAsync(string to, string subject, string body, bool html = false)
    {
        var mime = new MimeMessage();
        mime.To.Add(MailboxAddress.Parse(to));
        mime.Subject = subject;
        mime.Body = new TextPart(html ? MimeKit.Text.TextFormat.Html : MimeKit.Text.TextFormat.Plain) { Text = body };

        using var ms = new MemoryStream();
        await mime.WriteToAsync(ms);
        var raw = Convert.ToBase64String(ms.ToArray()).Replace('+', '-').Replace('/', '_').TrimEnd('=');

        var draft = await _svc.Users.Drafts.Create(new Draft { Message = new Message { Raw = raw } }, "me").ExecuteAsync();
        return new { id = draft.Id };
    }

    public async Task<List<object>> GetDraftsAsync(int maxResults = 10)
    {
        var resp = await _svc.Users.Drafts.List("me").ExecuteAsync();
        return (resp.Drafts ?? new List<Draft>()).Take(maxResults)
            .Select(d => (object)new { id = d.Id }).ToList();
    }

    public async Task<List<object>> GetLabelsAsync()
    {
        var resp = await _svc.Users.Labels.List("me").ExecuteAsync();
        return (resp.Labels ?? new List<Label>())
            .Select(l => (object)new { id = l.Id, name = l.Name, type = l.Type }).ToList();
    }

    public async Task<bool> MarkReadAsync(string id)   => await ModifyLabels(id, remove: "UNREAD");
    public async Task<bool> MarkUnreadAsync(string id) => await ModifyLabels(id, add: "UNREAD");
    public async Task<bool> StarAsync(string id)       => await ModifyLabels(id, add: "STARRED");
    public async Task<bool> TrashAsync(string id)      { await _svc.Users.Messages.Trash("me", id).ExecuteAsync(); return true; }
    public async Task<bool> ArchiveAsync(string id)    => await ModifyLabels(id, remove: "INBOX");

    public async Task<object> GetThreadAsync(string threadId)
    {
        var thread = await _svc.Users.Threads.Get("me", threadId).ExecuteAsync();
        return new { id = thread.Id, messages = thread.Messages?.Select(FormatMessage).ToList() };
    }

    public async Task<object> GetStatsAsync()
    {
        var profile = await _svc.Users.GetProfile("me").ExecuteAsync();
        return new { email = profile.EmailAddress, total = profile.MessagesTotal, threads = profile.ThreadsTotal };
    }

    private async Task<bool> ModifyLabels(string id, string? add = null, string? remove = null)
    {
        var req = new ModifyMessageRequest();
        if (add != null) req.AddLabelIds = new[] { add };
        if (remove != null) req.RemoveLabelIds = new[] { remove };
        await _svc.Users.Messages.Modify(req, "me", id).ExecuteAsync();
        return true;
    }

    private static object FormatMessage(Message msg)
    {
        var headers = msg.Payload?.Headers?.ToDictionary(h => h.Name, h => h.Value) ?? new();
        var body = ExtractBody(msg.Payload);
        return new
        {
            id = msg.Id,
            thread_id = msg.ThreadId,
            from = headers.GetValueOrDefault("From", ""),
            to = headers.GetValueOrDefault("To", ""),
            subject = headers.GetValueOrDefault("Subject", ""),
            date = headers.GetValueOrDefault("Date", ""),
            snippet = msg.Snippet,
            body,
            labels = msg.LabelIds
        };
    }

    private static string ExtractBody(GMailMessagePart? part)
    {
        if (part == null) return "";
        if (part.Body?.Data != null)
        {
            var padded = part.Body.Data.Replace('-', '+').Replace('_', '/');
            while (padded.Length % 4 != 0) padded += '=';
            return Encoding.UTF8.GetString(Convert.FromBase64String(padded));
        }
        foreach (var p in part.Parts ?? new List<GMailMessagePart>())
        {
            var text = ExtractBody(p);
            if (!string.IsNullOrEmpty(text)) return text;
        }
        return "";
    }
}
