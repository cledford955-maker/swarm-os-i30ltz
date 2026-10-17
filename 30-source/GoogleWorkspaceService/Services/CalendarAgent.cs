using Google.Apis.Calendar.v3;
using Google.Apis.Calendar.v3.Data;
using Google.Apis.Services;

namespace GoogleWorkspaceService.Services;

public class CalendarAgent
{
    private readonly CalendarService _svc;

    public CalendarAgent(GoogleAuthManager auth)
    {
        _svc = new CalendarService(new BaseClientService.Initializer
        {
            HttpClientInitializer = auth.GetCredential(),
            ApplicationName = "SwarmOS"
        });
    }

    public async Task<List<object>> GetCalendarsAsync()
    {
        var list = await _svc.CalendarList.List().ExecuteAsync();
        return (list.Items ?? new List<CalendarListEntry>())
            .Select(c => (object)new { id = c.Id, summary = c.Summary, primary = c.Primary }).ToList();
    }

    public async Task<List<object>> GetEventsAsync(int maxResults = 10, int daysAhead = 7, string calendarId = "primary")
    {
        var req = _svc.Events.List(calendarId);
        req.MaxResults = maxResults;
        req.TimeMinDateTimeOffset = DateTimeOffset.UtcNow;
        req.TimeMaxDateTimeOffset = DateTimeOffset.UtcNow.AddDays(daysAhead);
        req.SingleEvents = true;
        req.OrderBy = EventsResource.ListRequest.OrderByEnum.StartTime;

        var resp = await req.ExecuteAsync();
        return (resp.Items ?? new List<Event>()).Select(FormatEvent).ToList();
    }

    public async Task<List<object>> GetEventsByDateAsync(string date, string calendarId = "primary")
    {
        if (!DateTimeOffset.TryParse(date, out var day))
            return new List<object>();

        var req = _svc.Events.List(calendarId);
        req.TimeMinDateTimeOffset = day.Date;
        req.TimeMaxDateTimeOffset = day.Date.AddDays(1);
        req.SingleEvents = true;
        req.OrderBy = EventsResource.ListRequest.OrderByEnum.StartTime;

        var resp = await req.ExecuteAsync();
        return (resp.Items ?? new List<Event>()).Select(FormatEvent).ToList();
    }

    public async Task<object> CreateEventAsync(string summary, string start, string end,
        string description = "", string location = "", List<string>? attendees = null,
        bool allDay = false, List<int>? reminderMinutes = null, string? colorId = null,
        List<string>? recurrence = null, string calendarId = "primary")
    {
        var ev = new Event
        {
            Summary = summary,
            Description = description,
            Location = location,
            ColorId = colorId,
            Recurrence = recurrence
        };

        if (allDay)
        {
            ev.Start = new EventDateTime { Date = start };
            ev.End = new EventDateTime { Date = end };
        }
        else
        {
            ev.Start = new EventDateTime { DateTimeDateTimeOffset = DateTimeOffset.Parse(start) };
            ev.End = new EventDateTime { DateTimeDateTimeOffset = DateTimeOffset.Parse(end) };
        }

        if (attendees != null)
            ev.Attendees = attendees.Select(a => new EventAttendee { Email = a }).ToList();

        if (reminderMinutes != null)
            ev.Reminders = new Event.RemindersData
            {
                UseDefault = false,
                Overrides = reminderMinutes.Select(m => new EventReminder { Method = "popup", Minutes = m }).ToList()
            };

        var created = await _svc.Events.Insert(ev, calendarId).ExecuteAsync();
        return FormatEvent(created);
    }

    public async Task<object> QuickAddAsync(string text, string calendarId = "primary")
    {
        var ev = await _svc.Events.QuickAdd(calendarId, text).ExecuteAsync();
        return FormatEvent(ev);
    }

    public async Task<object> UpdateEventAsync(string eventId, string? summary = null,
        string? description = null, string? location = null, string? start = null,
        string? end = null, string calendarId = "primary")
    {
        var ev = await _svc.Events.Get(calendarId, eventId).ExecuteAsync();
        if (summary != null) ev.Summary = summary;
        if (description != null) ev.Description = description;
        if (location != null) ev.Location = location;
        if (start != null) ev.Start = new EventDateTime { DateTimeDateTimeOffset = DateTimeOffset.Parse(start) };
        if (end != null) ev.End = new EventDateTime { DateTimeDateTimeOffset = DateTimeOffset.Parse(end) };

        var updated = await _svc.Events.Update(ev, calendarId, eventId).ExecuteAsync();
        return FormatEvent(updated);
    }

    public async Task<bool> DeleteEventAsync(string eventId, string calendarId = "primary")
    {
        await _svc.Events.Delete(calendarId, eventId).ExecuteAsync();
        return true;
    }

    public async Task<object> GetStatsAsync(string calendarId = "primary")
    {
        var events = await GetEventsAsync(100, 30, calendarId);
        return new { upcoming_count = events.Count, calendar_id = calendarId };
    }

    private static object FormatEvent(Event ev) => new
    {
        id = ev.Id,
        summary = ev.Summary,
        description = ev.Description,
        location = ev.Location,
        start = ev.Start?.DateTimeRaw ?? ev.Start?.Date,
        end = ev.End?.DateTimeRaw ?? ev.End?.Date,
        attendees = ev.Attendees?.Select(a => a.Email),
        html_link = ev.HtmlLink,
        status = ev.Status,
        color_id = ev.ColorId,
        recurrence = ev.Recurrence
    };
}
