namespace GoogleWorkspaceService.Models;

public record SendEmailRequest(string To, string Subject, string Body,
    string? Cc = null, string? Bcc = null, bool Html = false);

public record ReplyEmailRequest(string Body, bool Html = false, bool ReplyAll = false);

public record ForwardEmailRequest(string To, string AdditionalBody = "");

public record DraftRequest(string To, string Subject, string Body, bool Html = false);

public record CreateEventRequest(string Summary, string Start, string End,
    string Description = "", string Location = "",
    List<string>? Attendees = null, bool AllDay = false,
    List<int>? ReminderMinutes = null, string? ColorId = null,
    List<string>? Recurrence = null, string CalendarId = "primary");

public record QuickAddEventRequest(string Text, string CalendarId = "primary");

public record UpdateEventRequest(string EventId, string? Summary = null, string? Description = null,
    string? Location = null, string? Start = null, string? End = null, string CalendarId = "primary");

public record CreateFolderRequest(string Name, string? ParentId = null);

public record DriveShareRequest(string FileId, string Email, string Role = "reader");

public record CreateTaskListRequest(string Title);

public record CreateTaskRequest(string Title, string Notes = "", string? Due = null, string TaskListId = "@default");

public record UpdateTaskRequest(string TaskId, string? Title = null, string? Notes = null,
    string? Due = null, string TaskListId = "@default");

public record CreateContactRequest(string FirstName, string LastName = "",
    string Email = "", string Phone = "", string Organization = "");

public record WriteNoteRequest(string Content, string? Title = null, List<string>? Tags = null,
    bool Pinned = false, string Category = "general", string? Color = null);

public record UpdateNoteRequest(string NoteId, string? Content = null, string? Title = null,
    List<string>? Tags = null, bool? Pinned = null, string? Category = null, string? Color = null);

public record ChecklistRequest(string Title, List<GoogleWorkspaceService.Services.ChecklistItem> Items, bool Pinned = false);

public record ExchangeCodeRequest(string Code);
