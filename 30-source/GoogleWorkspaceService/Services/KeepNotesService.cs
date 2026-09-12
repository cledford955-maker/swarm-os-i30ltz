using Microsoft.Data.Sqlite;

namespace GoogleWorkspaceService.Services;

// Google Keep has no official API — this replaces it with a local SQLite notes store
// with the same interface, so the companion app and Lucille still work seamlessly.
public class KeepNotesService : IDisposable
{
    private readonly SqliteConnection _db;

    public KeepNotesService()
    {
        var dbPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "keep_notes.db");
        _db = new SqliteConnection($"Data Source={dbPath}");
        _db.Open();
        InitSchema();
    }

    private void InitSchema()
    {
        _db.Execute(@"
            CREATE TABLE IF NOT EXISTS notes (
                id          TEXT PRIMARY KEY,
                title       TEXT,
                content     TEXT NOT NULL,
                tags        TEXT DEFAULT '[]',
                pinned      INTEGER DEFAULT 0,
                category    TEXT DEFAULT 'general',
                color       TEXT,
                trashed     INTEGER DEFAULT 0,
                created_at  TEXT DEFAULT (datetime('now')),
                updated_at  TEXT DEFAULT (datetime('now'))
            )");
    }

    public object WriteNote(string content, string? title = null, List<string>? tags = null,
        bool pinned = false, string category = "general", string? color = null)
    {
        var id = Guid.NewGuid().ToString("N");
        var tagsJson = System.Text.Json.JsonSerializer.Serialize(tags ?? new List<string>());

        _db.Execute(@"INSERT INTO notes (id,title,content,tags,pinned,category,color)
                      VALUES ($id,$title,$content,$tags,$pinned,$category,$color)",
            new { id, title, content, tags = tagsJson, pinned = pinned ? 1 : 0, category, color });

        return new { ok = true, id };
    }

    public List<object> ReadNotes(string? tag = null, string? category = null,
        bool pinnedOnly = false, int maxResults = 50)
    {
        var sql = "SELECT * FROM notes WHERE trashed=0";
        if (pinnedOnly) sql += " AND pinned=1";
        if (!string.IsNullOrEmpty(category)) sql += $" AND category='{category}'";
        if (!string.IsNullOrEmpty(tag)) sql += $" AND tags LIKE '%\"{tag}\"%'";
        sql += $" ORDER BY pinned DESC, updated_at DESC LIMIT {maxResults}";

        return _db.Query(sql).Select(FormatRow).ToList();
    }

    public object? GetNote(string id)
    {
        var row = _db.QuerySingle("SELECT * FROM notes WHERE id=$id AND trashed=0", new { id });
        return row == null ? null : FormatRow(row);
    }

    public bool UpdateNote(string id, string? content = null, string? title = null,
        List<string>? tags = null, bool? pinned = null, string? category = null, string? color = null)
    {
        var sets = new List<string> { "updated_at=datetime('now')" };
        if (content != null) sets.Add("content=$content");
        if (title != null) sets.Add("title=$title");
        if (tags != null) sets.Add("tags=$tags");
        if (pinned.HasValue) sets.Add("pinned=$pinned");
        if (category != null) sets.Add("category=$category");
        if (color != null) sets.Add("color=$color");

        var tagsJson = tags != null ? System.Text.Json.JsonSerializer.Serialize(tags) : null;
        _db.Execute($"UPDATE notes SET {string.Join(",", sets)} WHERE id=$id",
            new { id, content, title, tags = tagsJson, pinned = pinned.HasValue ? (pinned.Value ? 1 : 0) : (object?)null, category, color });

        return true;
    }

    public bool EraseNote(string id, bool hard = false)
    {
        if (hard)
            _db.Execute("DELETE FROM notes WHERE id=$id", new { id });
        else
            _db.Execute("UPDATE notes SET trashed=1, updated_at=datetime('now') WHERE id=$id", new { id });
        return true;
    }

    public bool RestoreNote(string id)
    {
        _db.Execute("UPDATE notes SET trashed=0, updated_at=datetime('now') WHERE id=$id", new { id });
        return true;
    }

    public object CreateChecklist(string title, List<ChecklistItem> items, bool pinned = false)
    {
        var content = System.Text.Json.JsonSerializer.Serialize(items);
        return WriteNote(content, title, new[] { "checklist" }.ToList(), pinned, "checklist");
    }

    public List<string> GetLabels()
    {
        var rows = _db.Query("SELECT DISTINCT tags FROM notes WHERE trashed=0");
        var labels = new HashSet<string>();
        foreach (var row in rows)
        {
            try
            {
                var tags = System.Text.Json.JsonSerializer.Deserialize<List<string>>(row["tags"]?.ToString() ?? "[]");
                foreach (var t in tags ?? new()) labels.Add(t);
            }
            catch { }
        }
        return labels.OrderBy(l => l).ToList();
    }

    public object GetMemoryStats()
    {
        var total = _db.QueryScalar<long>("SELECT COUNT(*) FROM notes WHERE trashed=0");
        var pinned = _db.QueryScalar<long>("SELECT COUNT(*) FROM notes WHERE trashed=0 AND pinned=1");
        return new { total_notes = total, pinned_notes = pinned };
    }

    private static object FormatRow(Dictionary<string, object?> row) => new
    {
        id = row["id"],
        title = row["title"],
        content = row["content"],
        tags = TryDeserializeTags(row["tags"]?.ToString()),
        pinned = Convert.ToInt32(row["pinned"]) == 1,
        category = row["category"],
        color = row["color"],
        created_at = row["created_at"],
        updated_at = row["updated_at"]
    };

    private static List<string> TryDeserializeTags(string? json)
    {
        try { return System.Text.Json.JsonSerializer.Deserialize<List<string>>(json ?? "[]") ?? new(); }
        catch { return new(); }
    }

    public void Dispose() => _db.Dispose();
}

public class ChecklistItem
{
    public string Text { get; set; } = "";
    public bool Checked { get; set; }
}

// Minimal SQLite helpers to avoid pulling in Dapper
file static class SqliteExtensions
{
    public static void Execute(this SqliteConnection conn, string sql, object? parms = null)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        BindParams(cmd, parms);
        cmd.ExecuteNonQuery();
    }

    public static List<Dictionary<string, object?>> Query(this SqliteConnection conn, string sql, object? parms = null)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        BindParams(cmd, parms);
        using var reader = cmd.ExecuteReader();
        var results = new List<Dictionary<string, object?>>();
        while (reader.Read())
        {
            var row = new Dictionary<string, object?>();
            for (int i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            results.Add(row);
        }
        return results;
    }

    public static Dictionary<string, object?>? QuerySingle(this SqliteConnection conn, string sql, object? parms = null)
        => conn.Query(sql, parms).FirstOrDefault();

    public static T? QueryScalar<T>(this SqliteConnection conn, string sql, object? parms = null)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        BindParams(cmd, parms);
        var val = cmd.ExecuteScalar();
        return val == null || val == DBNull.Value ? default : (T)Convert.ChangeType(val, typeof(T));
    }

    private static void BindParams(SqliteCommand cmd, object? parms)
    {
        if (parms == null) return;
        foreach (var prop in parms.GetType().GetProperties())
        {
            var val = prop.GetValue(parms);
            cmd.Parameters.AddWithValue("$" + prop.Name, val ?? DBNull.Value);
        }
    }
}
