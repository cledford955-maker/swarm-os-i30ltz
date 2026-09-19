package com.example.data.memory

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.flow.Flow
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

/**
 * One immutable shared-memory entry — the phone-side copy of the log at
 * /mnt/brains/swarm-memory on 13E457-THUNDERI30LT. Schema v1, 2026-09-16.
 *
 * [seq] is local insertion order and doubles as this phone's sync cursor:
 * a peer that has pulled up to seq N only needs rows with seq > N.
 */
@Entity(tableName = "memory_entries", indices = [Index(value = ["id"], unique = true)])
data class MemoryEntryEntity(
    @PrimaryKey(autoGenerate = true) val seq: Long = 0,
    val id: String,
    val device: String,
    val ts: String,
    val kind: String,
    @ColumnInfo(name = "entry_key") val key: String,
    val content: String,
    @ColumnInfo(name = "tags_json") val tagsJson: String,
    @ColumnInfo(name = "meta_json") val metaJson: String,
    val deleted: Boolean
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("v", SCHEMA_VERSION)
        put("id", id)
        put("device", device)
        put("ts", ts)
        put("kind", kind)
        if (key.isNotEmpty()) put("key", key)
        put("content", content)
        val tags = JSONArray(tagsJson)
        if (tags.length() > 0) put("tags", tags)
        val meta = JSONObject(metaJson)
        if (meta.length() > 0) put("meta", meta)
        if (deleted) put("deleted", true)
    }

    companion object {
        const val SCHEMA_VERSION = 1
        private val DEVICE_RE = Regex("^[A-Za-z0-9._@-]{1,64}$")
        private val KIND_RE = Regex("^[a-z][a-z0-9_]{0,31}$")
        private val ID_RE = Regex("^[A-Za-z0-9-]{8,64}$")

        fun create(device: String, kind: String, key: String, content: String): MemoryEntryEntity =
            MemoryEntryEntity(
                id = UUID.randomUUID().toString(),
                device = device,
                ts = Instant.now().toString(),
                kind = kind,
                key = key,
                content = content,
                tagsJson = "[]",
                metaJson = "{}",
                deleted = false
            )

        /** Parses and validates with the same rules as the Go server; null if invalid. */
        fun fromJson(o: JSONObject): MemoryEntryEntity? {
            if (o.optInt("v") != SCHEMA_VERSION) return null
            val id = o.optString("id")
            val device = o.optString("device")
            val kind = o.optString("kind")
            val ts = o.optString("ts")
            val content = o.optString("content")
            val key = o.optString("key", "")
            if (!ID_RE.matches(id) || !DEVICE_RE.matches(device) || !KIND_RE.matches(kind)) return null
            if (key.length > 200 || content.length > 2 * 1024 * 1024) return null
            if (runCatching { Instant.parse(ts) }.isFailure) return null
            return MemoryEntryEntity(
                id = id, device = device, ts = ts, kind = kind, key = key, content = content,
                tagsJson = (o.optJSONArray("tags") ?: JSONArray()).toString(),
                metaJson = (o.optJSONObject("meta") ?: JSONObject()).toString(),
                deleted = o.optBoolean("deleted", false)
            )
        }

        /** Room v1 -> v2 adds this table without touching tasks, chats or scans. */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `memory_entries` (" +
                        "`seq` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `id` TEXT NOT NULL, " +
                        "`device` TEXT NOT NULL, `ts` TEXT NOT NULL, `kind` TEXT NOT NULL, " +
                        "`entry_key` TEXT NOT NULL, `content` TEXT NOT NULL, `tags_json` TEXT NOT NULL, " +
                        "`meta_json` TEXT NOT NULL, `deleted` INTEGER NOT NULL)"
                )
                db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_memory_entries_id` ON `memory_entries` (`id`)")
            }
        }
    }
}

@Dao
interface MemoryDao {
    /** Returns -1 for each entry whose id is already stored. */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(entries: List<MemoryEntryEntity>): List<Long>

    @Query("SELECT * FROM memory_entries WHERE seq > :afterSeq ORDER BY seq LIMIT :limit")
    suspend fun since(afterSeq: Long, limit: Int): List<MemoryEntryEntity>

    @Query("SELECT COALESCE(MAX(seq), 0) FROM memory_entries")
    suspend fun maxSeq(): Long

    @Query("SELECT COUNT(*) FROM memory_entries WHERE seq > :afterSeq")
    fun countAfter(afterSeq: Long): Flow<Int>

    @Query("SELECT COUNT(*) FROM memory_entries")
    fun count(): Flow<Int>

    @Query(
        "SELECT * FROM memory_entries WHERE (:kind = '' OR kind = :kind) " +
            "AND (:query = '' OR content LIKE '%' || :query || '%' OR entry_key LIKE '%' || :query || '%') " +
            "ORDER BY ts DESC LIMIT :limit"
    )
    fun observe(kind: String, query: String, limit: Int): Flow<List<MemoryEntryEntity>>
}
