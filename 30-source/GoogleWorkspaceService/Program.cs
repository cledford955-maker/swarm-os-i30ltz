using GoogleWorkspaceService.Models;
using GoogleWorkspaceService.Services;

var builder = WebApplication.CreateBuilder(args);

// Clients enter through authenticated LucyServer; keep the token-bearing
// backend on loopback instead of exposing its Google API surface to the LAN.
builder.WebHost.UseUrls("http://127.0.0.1:8399");

builder.Services.AddOpenApi();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

// Auth manager is a singleton so credential & token state persist for the lifetime of the process
builder.Services.AddSingleton<GoogleAuthManager>();
builder.Services.AddSingleton<KeepNotesService>();

var app = builder.Build();

if (app.Environment.IsDevelopment()) app.MapOpenApi();
app.UseCors();

// Resolve once — these are cheap wrappers constructed on first authenticated request
GoogleAuthManager Auth(IServiceProvider sp) => sp.GetRequiredService<GoogleAuthManager>();

T Agent<T>(HttpContext ctx, Func<GoogleAuthManager, T> factory)
{
    try { return factory(ctx.RequestServices.GetRequiredService<GoogleAuthManager>()); }
    catch (InvalidOperationException ex) { throw new BadHttpRequestException(ex.Message, 401); }
}

// ══════════ ROOT / HEALTH ══════════

app.MapGet("/", async (GoogleAuthManager auth) => new
{
    service = "Swarm OS Google Workspace Service",
    version = "1.0.0",
    session = await auth.GetStatusAsync(),
    agents = new[] { "gmail", "calendar", "drive", "tasks", "contacts", "keep" }
});

app.MapGet("/health", async (GoogleAuthManager auth) => new
{
    status = "ok",
    session = await auth.GetStatusAsync()
});

// ══════════ AUTH ══════════

app.MapPost("/auth/upload_credentials", async (HttpContext ctx, GoogleAuthManager auth) =>
{
    if (!ctx.Request.HasFormContentType || ctx.Request.Form.Files.Count == 0)
        return Results.BadRequest(new { error = "Send credentials.json as multipart form-data file 'file'" });

    var file = ctx.Request.Form.Files[0];
    await auth.SaveCredentialsAsync(file.OpenReadStream());
    return Results.Ok(new { ok = true, message = "credentials.json saved. Call GET /auth/url to begin OAuth." });
});

app.MapGet("/auth/url", (GoogleAuthManager auth) =>
{
    if (!auth.HasCredentials)
        return Results.BadRequest(new { error = "Upload credentials.json first via POST /auth/upload_credentials" });
    return Results.Ok(new { ok = true, url = auth.GetAuthUrl() });
});

// Browser redirect lands here after user approves
app.MapGet("/auth/callback", async (string? code, string? error, GoogleAuthManager auth) =>
{
    if (!string.IsNullOrEmpty(error))
        return Results.Ok($"<html><body><h2>Auth failed: {error}</h2></body></html>");

    if (string.IsNullOrEmpty(code))
        return Results.BadRequest(new { error = "No code returned" });

    var ok = await auth.ExchangeCodeAsync(code);
    if (!ok) return Results.UnprocessableEntity(new { error = "Token exchange failed" });

    return Results.Content(
        $"<html><body><h2>Authenticated as {auth.UserEmail}</h2><p>You may close this tab.</p></body></html>",
        "text/html");
});

// Also allow posting code manually (companion app flow)
app.MapPost("/auth/exchange", async (ExchangeCodeRequest req, GoogleAuthManager auth) =>
{
    var ok = await auth.ExchangeCodeAsync(req.Code);
    return ok
        ? Results.Ok(new { ok = true, email = auth.UserEmail })
        : Results.UnprocessableEntity(new { error = "Token exchange failed" });
});

app.MapGet("/auth/status", async (GoogleAuthManager auth) => Results.Ok(await auth.GetStatusAsync()));

app.MapPost("/auth/logout", async (GoogleAuthManager auth) =>
{
    await auth.LogoutAsync();
    return Results.Ok(new { ok = true });
});

// ══════════ GMAIL ══════════

app.MapGet("/gmail/inbox", async (HttpContext ctx,
    int maxResults = 20, string? query = null, string label = "INBOX", bool unreadOnly = false) =>
{
    var msgs = await Agent(ctx, a => new GmailAgent(a)).GetInboxAsync(maxResults, query, label, unreadOnly);
    return Results.Ok(new { ok = true, messages = msgs });
});

app.MapGet("/gmail/message/{messageId}", async (string messageId, HttpContext ctx) =>
{
    var msg = await Agent(ctx, a => new GmailAgent(a)).GetMessageAsync(messageId);
    return msg == null ? Results.NotFound() : Results.Ok(new { ok = true, message = msg });
});

app.MapGet("/gmail/search", async (string q, int maxResults, HttpContext ctx) =>
{
    var msgs = await Agent(ctx, a => new GmailAgent(a)).SearchAsync(q, maxResults);
    return Results.Ok(new { ok = true, messages = msgs });
});

app.MapGet("/gmail/unread", async (HttpContext ctx) =>
{
    var count = await Agent(ctx, a => new GmailAgent(a)).GetUnreadCountAsync();
    return Results.Ok(new { ok = true, count });
});

app.MapPost("/gmail/send", async (SendEmailRequest req, HttpContext ctx) =>
{
    var result = await Agent(ctx, a => new GmailAgent(a)).SendAsync(req.To, req.Subject, req.Body, req.Cc, req.Bcc, req.Html);
    return Results.Ok(new { ok = true, result });
});

app.MapPost("/gmail/reply/{messageId}", async (string messageId, ReplyEmailRequest req, HttpContext ctx) =>
{
    var result = await Agent(ctx, a => new GmailAgent(a)).ReplyAsync(messageId, req.Body, req.Html, req.ReplyAll);
    return Results.Ok(new { ok = true, result });
});

app.MapPost("/gmail/draft", async (DraftRequest req, HttpContext ctx) =>
{
    var draft = await Agent(ctx, a => new GmailAgent(a)).CreateDraftAsync(req.To, req.Subject, req.Body, req.Html);
    return Results.Ok(new { ok = true, draft });
});

app.MapGet("/gmail/drafts", async (int maxResults, HttpContext ctx) =>
{
    var drafts = await Agent(ctx, a => new GmailAgent(a)).GetDraftsAsync(maxResults);
    return Results.Ok(new { ok = true, drafts });
});

app.MapGet("/gmail/labels", async (HttpContext ctx) =>
{
    var labels = await Agent(ctx, a => new GmailAgent(a)).GetLabelsAsync();
    return Results.Ok(new { ok = true, labels });
});

app.MapPost("/gmail/mark_read/{messageId}",   async (string messageId, HttpContext ctx) => Results.Ok(new { ok = await Agent(ctx, a => new GmailAgent(a)).MarkReadAsync(messageId) }));
app.MapPost("/gmail/mark_unread/{messageId}", async (string messageId, HttpContext ctx) => Results.Ok(new { ok = await Agent(ctx, a => new GmailAgent(a)).MarkUnreadAsync(messageId) }));
app.MapPost("/gmail/star/{messageId}",        async (string messageId, HttpContext ctx) => Results.Ok(new { ok = await Agent(ctx, a => new GmailAgent(a)).StarAsync(messageId) }));
app.MapPost("/gmail/trash/{messageId}",       async (string messageId, HttpContext ctx) => Results.Ok(new { ok = await Agent(ctx, a => new GmailAgent(a)).TrashAsync(messageId) }));
app.MapPost("/gmail/archive/{messageId}",     async (string messageId, HttpContext ctx) => Results.Ok(new { ok = await Agent(ctx, a => new GmailAgent(a)).ArchiveAsync(messageId) }));

app.MapGet("/gmail/thread/{threadId}", async (string threadId, HttpContext ctx) =>
    Results.Ok(new { ok = true, thread = await Agent(ctx, a => new GmailAgent(a)).GetThreadAsync(threadId) }));

app.MapGet("/gmail/stats", async (HttpContext ctx) =>
    Results.Ok(new { ok = true, stats = await Agent(ctx, a => new GmailAgent(a)).GetStatsAsync() }));

// ══════════ CALENDAR ══════════

app.MapGet("/cal/list", async (HttpContext ctx) =>
    Results.Ok(new { ok = true, calendars = await Agent(ctx, a => new CalendarAgent(a)).GetCalendarsAsync() }));

app.MapGet("/cal/events", async (int maxResults, int daysAhead, string calendarId, HttpContext ctx) =>
    Results.Ok(new { ok = true, events = await Agent(ctx, a => new CalendarAgent(a)).GetEventsAsync(maxResults, daysAhead, calendarId) }));

app.MapGet("/cal/events/date", async (string date, string calendarId, HttpContext ctx) =>
    Results.Ok(new { ok = true, events = await Agent(ctx, a => new CalendarAgent(a)).GetEventsByDateAsync(date, calendarId) }));

app.MapPost("/cal/create", async (CreateEventRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, @event = await Agent(ctx, a => new CalendarAgent(a))
        .CreateEventAsync(req.Summary, req.Start, req.End, req.Description, req.Location,
            req.Attendees, req.AllDay, req.ReminderMinutes, req.ColorId, req.Recurrence, req.CalendarId) }));

app.MapPost("/cal/quick", async (QuickAddEventRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, @event = await Agent(ctx, a => new CalendarAgent(a)).QuickAddAsync(req.Text, req.CalendarId) }));

app.MapPut("/cal/update/{eventId}", async (string eventId, UpdateEventRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, @event = await Agent(ctx, a => new CalendarAgent(a))
        .UpdateEventAsync(eventId, req.Summary, req.Description, req.Location, req.Start, req.End, req.CalendarId) }));

app.MapDelete("/cal/delete/{eventId}", async (string eventId, string calendarId, HttpContext ctx) =>
    Results.Ok(new { ok = await Agent(ctx, a => new CalendarAgent(a)).DeleteEventAsync(eventId, calendarId) }));

// ══════════ DRIVE ══════════

app.MapGet("/drive/list", async (string? query, string? folderId, int maxResults, HttpContext ctx) =>
    Results.Ok(new { ok = true, files = await Agent(ctx, a => new DriveAgent(a)).ListFilesAsync(query, folderId, maxResults) }));

app.MapGet("/drive/search", async (string q, int maxResults, HttpContext ctx) =>
    Results.Ok(new { ok = true, files = await Agent(ctx, a => new DriveAgent(a)).SearchAsync(q, maxResults) }));

app.MapPost("/drive/folder", async (CreateFolderRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, folder = await Agent(ctx, a => new DriveAgent(a)).CreateFolderAsync(req.Name, req.ParentId) }));

app.MapPost("/drive/share", async (DriveShareRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = await Agent(ctx, a => new DriveAgent(a)).ShareFileAsync(req.FileId, req.Email, req.Role) }));

app.MapDelete("/drive/delete/{fileId}", async (string fileId, HttpContext ctx) =>
    Results.Ok(new { ok = await Agent(ctx, a => new DriveAgent(a)).DeleteFileAsync(fileId) }));

app.MapGet("/drive/quota", async (HttpContext ctx) =>
    Results.Ok(new { ok = true, quota = await Agent(ctx, a => new DriveAgent(a)).GetStorageQuotaAsync() }));

// ══════════ TASKS ══════════

app.MapGet("/tasks/lists", async (HttpContext ctx) =>
    Results.Ok(new { ok = true, lists = await Agent(ctx, a => new TasksAgent(a)).GetTaskListsAsync() }));

app.MapPost("/tasks/lists/create", async (CreateTaskListRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, list = await Agent(ctx, a => new TasksAgent(a)).CreateTaskListAsync(req.Title) }));

app.MapGet("/tasks", async (string taskListId, bool showCompleted, int maxResults, HttpContext ctx) =>
    Results.Ok(new { ok = true, tasks = await Agent(ctx, a => new TasksAgent(a)).GetTasksAsync(taskListId, showCompleted, maxResults) }));

app.MapPost("/tasks/create", async (CreateTaskRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, task = await Agent(ctx, a => new TasksAgent(a)).CreateTaskAsync(req.Title, req.Notes, req.Due, req.TaskListId) }));

app.MapPost("/tasks/complete/{taskId}", async (string taskId, string taskListId, HttpContext ctx) =>
    Results.Ok(new { ok = await Agent(ctx, a => new TasksAgent(a)).CompleteTaskAsync(taskId, taskListId) }));

app.MapPut("/tasks/update/{taskId}", async (string taskId, UpdateTaskRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, task = await Agent(ctx, a => new TasksAgent(a)).UpdateTaskAsync(taskId, req.Title, req.Notes, req.Due, req.TaskListId) }));

app.MapDelete("/tasks/delete/{taskId}", async (string taskId, string taskListId, HttpContext ctx) =>
    Results.Ok(new { ok = await Agent(ctx, a => new TasksAgent(a)).DeleteTaskAsync(taskId, taskListId) }));

// ══════════ CONTACTS ══════════

app.MapGet("/contacts", async (int maxResults, HttpContext ctx) =>
    Results.Ok(new { ok = true, contacts = await Agent(ctx, a => new ContactsAgent(a)).ListContactsAsync(maxResults) }));

app.MapGet("/contacts/search", async (string q, int maxResults, HttpContext ctx) =>
    Results.Ok(new { ok = true, contacts = await Agent(ctx, a => new ContactsAgent(a)).SearchContactsAsync(q, maxResults) }));

app.MapPost("/contacts/create", async (CreateContactRequest req, HttpContext ctx) =>
    Results.Ok(new { ok = true, contact = await Agent(ctx, a => new ContactsAgent(a))
        .CreateContactAsync(req.FirstName, req.LastName, req.Email, req.Phone, req.Organization) }));

// ══════════ KEEP NOTES (local SQLite) ══════════

app.MapPost("/keep/notes", (WriteNoteRequest req, KeepNotesService keep) =>
    Results.Ok(new { ok = true, result = keep.WriteNote(req.Content, req.Title, req.Tags, req.Pinned, req.Category, req.Color) }));

app.MapGet("/keep/notes", (KeepNotesService keep, string? tag, string? category, bool pinnedOnly, int maxResults) =>
    Results.Ok(new { ok = true, notes = keep.ReadNotes(tag, category, pinnedOnly, maxResults) }));

app.MapGet("/keep/notes/{id}", (string id, KeepNotesService keep) =>
{
    var note = keep.GetNote(id);
    return note == null ? Results.NotFound() : Results.Ok(new { ok = true, note });
});

app.MapPut("/keep/notes/{id}", (string id, UpdateNoteRequest req, KeepNotesService keep) =>
    Results.Ok(new { ok = keep.UpdateNote(id, req.Content, req.Title, req.Tags, req.Pinned, req.Category, req.Color) }));

app.MapDelete("/keep/notes/{id}", (string id, bool hard, KeepNotesService keep) =>
    Results.Ok(new { ok = keep.EraseNote(id, hard) }));

app.MapPost("/keep/notes/{id}/restore", (string id, KeepNotesService keep) =>
    Results.Ok(new { ok = keep.RestoreNote(id) }));

app.MapPost("/keep/checklist", (ChecklistRequest req, KeepNotesService keep) =>
    Results.Ok(new { ok = true, result = keep.CreateChecklist(req.Title, req.Items, req.Pinned) }));

app.MapGet("/keep/labels", (KeepNotesService keep) =>
    Results.Ok(new { ok = true, labels = keep.GetLabels() }));

app.MapGet("/keep/stats", (KeepNotesService keep) =>
    Results.Ok(new { ok = true, stats = keep.GetMemoryStats() }));

app.Run();
