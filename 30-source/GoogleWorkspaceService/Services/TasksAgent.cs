using Google.Apis.Services;
using Google.Apis.Tasks.v1;
using GTask = Google.Apis.Tasks.v1.Data.Task;
using GTaskList = Google.Apis.Tasks.v1.Data.TaskList;

namespace GoogleWorkspaceService.Services;

public class TasksAgent
{
    private readonly TasksService _svc;

    public TasksAgent(GoogleAuthManager auth)
    {
        _svc = new TasksService(new BaseClientService.Initializer
        {
            HttpClientInitializer = auth.GetCredential(),
            ApplicationName = "SwarmOS"
        });
    }

    public async Task<List<object>> GetTaskListsAsync()
    {
        var resp = await _svc.Tasklists.List().ExecuteAsync();
        return (resp.Items ?? new List<GTaskList>())
            .Select(l => (object)new { id = l.Id, title = l.Title, updated = l.Updated }).ToList();
    }

    public async Task<object> CreateTaskListAsync(string title)
    {
        var list = await _svc.Tasklists.Insert(new GTaskList { Title = title }).ExecuteAsync();
        return new { id = list.Id, title = list.Title };
    }

    public async Task<List<object>> GetTasksAsync(string taskListId = "@default", bool showCompleted = false, int maxResults = 50)
    {
        var req = _svc.Tasks.List(taskListId);
        req.MaxResults = maxResults;
        req.ShowCompleted = showCompleted;
        var resp = await req.ExecuteAsync();
        return (resp.Items ?? new List<GTask>()).Select(FormatTask).ToList();
    }

    public async Task<object> CreateTaskAsync(string title, string notes = "", string? due = null, string taskListId = "@default")
    {
        var task = new GTask { Title = title, Notes = notes };
        if (!string.IsNullOrEmpty(due)) task.Due = DateTimeOffset.Parse(due).ToString("yyyy-MM-ddTHH:mm:ssZ");

        var created = await _svc.Tasks.Insert(task, taskListId).ExecuteAsync();
        return FormatTask(created);
    }

    public async Task<bool> CompleteTaskAsync(string taskId, string taskListId = "@default")
    {
        var task = await _svc.Tasks.Get(taskListId, taskId).ExecuteAsync();
        task.Status = "completed";
        task.Completed = DateTime.UtcNow.ToString("O");
        await _svc.Tasks.Update(task, taskListId, taskId).ExecuteAsync();
        return true;
    }

    public async Task<object> UpdateTaskAsync(string taskId, string? title = null, string? notes = null,
        string? due = null, string taskListId = "@default")
    {
        var task = await _svc.Tasks.Get(taskListId, taskId).ExecuteAsync();
        if (title != null) task.Title = title;
        if (notes != null) task.Notes = notes;
        if (due != null) task.Due = DateTimeOffset.Parse(due).ToString("yyyy-MM-ddTHH:mm:ssZ");

        var updated = await _svc.Tasks.Update(task, taskListId, taskId).ExecuteAsync();
        return FormatTask(updated);
    }

    public async Task<bool> DeleteTaskAsync(string taskId, string taskListId = "@default")
    {
        await _svc.Tasks.Delete(taskListId, taskId).ExecuteAsync();
        return true;
    }

    public async Task<object> GetStatsAsync(string taskListId = "@default")
    {
        var tasks = await GetTasksAsync(taskListId, showCompleted: true, maxResults: 100);
        return new { total = tasks.Count, task_list_id = taskListId };
    }

    private static object FormatTask(GTask t) => new
    {
        id = t.Id,
        title = t.Title,
        notes = t.Notes,
        status = t.Status,
        due = t.Due,
        completed = t.Completed,
        updated = t.Updated
    };
}
