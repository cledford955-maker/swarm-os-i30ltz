// ApiModels.kt — JSON data models for Lucille API responses  v1.0.0  2026-09-24
// All fields are nullable — the Go server may omit any key if its source
// service is unavailable, and we degrade gracefully rather than crash.
package com.swarm.lucille.data.network

import com.google.gson.JsonElement
import com.google.gson.annotations.SerializedName

// ─── Base response envelope ────────────────────────────────────────────────
data class BaseResponse(
    val ok: Boolean = false,
    val error: String? = null,
    val version: String? = null,
    @SerializedName("generated_at") val generatedAt: String? = null,
    val date: String? = null
)

// ─── Daily personal brief ─────────────────────────────────────────────────
data class DailyBriefResponse(
    val ok: Boolean = false,
    val headline: String? = null,
    val nudges: List<Nudge>? = null,
    val care: CareSection? = null,
    val calendar: JsonElement? = null,
    val mail: JsonElement? = null,
    val drives: List<DriveUsage>? = null,
    val sessions: SessionSummary? = null,
    @SerializedName("generated_at") val generatedAt: String? = null,
    val errors: Map<String, String>? = null
)

// ─── Project brief ─────────────────────────────────────────────────────────
data class ProjectBriefResponse(
    val ok: Boolean = false,
    @SerializedName("project_headline") val projectHeadline: String? = null,
    val git: List<RepoStatus>? = null,
    val sessions: SessionSummary? = null,
    val drives: List<DriveUsage>? = null,
    val suggestions: List<ProjectSuggestion>? = null,
    @SerializedName("recent_files") val recentFiles: JsonElement? = null,
    @SerializedName("generated_at") val generatedAt: String? = null
)

data class ProjectSuggestion(
    val priority: String = "medium",   // critical | high | medium | idea
    val title: String = "",
    val detail: String = "",
    val tag: String = "code"           // code | build | hardware | companion | recovery
)

// ─── Nudges ────────────────────────────────────────────────────────────────
data class Nudge(
    val kind: String = "",             // meds | water | food | sleep | break
    val severity: String = "info",    // critical | warn | info
    val text: String = ""
)

// ─── Care ──────────────────────────────────────────────────────────────────
data class CareSection(
    val day: CareDay? = null,
    val schedule: List<MedDose>? = null,
    @SerializedName("water_goal_ml") val waterGoalML: Int = 2500,
    @SerializedName("sleep_goal_h") val sleepGoalH: Double = 7.5,
    @SerializedName("wake_at") val wakeAt: String? = null,
    @SerializedName("bed_at") val bedAt: String? = null
)

data class CareDay(
    val date: String = "",
    val meds: List<MedTaken>? = null,
    @SerializedName("water_ml") val waterML: Int = 0,
    val meals: List<Meal>? = null,
    val sleep: Sleep? = null
)

data class MedDose(val name: String = "", val at: String = "")
data class MedTaken(val name: String = "", @SerializedName("taken_at") val takenAt: String? = null)
data class Meal(val label: String = "", val at: String? = null)
data class Sleep(val bed: String? = null, val wake: String? = null, val hours: Double = 0.0)

// ─── Sessions ──────────────────────────────────────────────────────────────
data class SessionSummary(
    val active: List<Session>? = null,
    @SerializedName("today_minutes") val todayMin: Map<String, Double>? = null,
    @SerializedName("week_minutes") val weekMin: Map<String, Double>? = null,
    @SerializedName("gaming_week_minutes") val gamingWeekMin: Double? = null,
    val recent: List<Session>? = null
)

data class Session(
    val id: String = "",
    val project: String = "",
    val kind: String = "project",
    val start: String? = null,
    val end: String? = null
)

// ─── Git ───────────────────────────────────────────────────────────────────
data class RepoStatus(
    val path: String = "",
    val branch: String = "",
    val ahead: Int = 0,
    val behind: Int = 0,
    val dirty: Int = 0,
    val untracked: Int = 0,
    @SerializedName("last_commit") val lastCommit: String? = null,
    @SerializedName("last_when") val lastWhen: String? = null,
    val changed: List<String>? = null,
    val error: String? = null
)

// ─── Drives ────────────────────────────────────────────────────────────────
data class DriveUsage(
    val mount: String = "",
    val mounted: Boolean = false,
    val device: String? = null,
    @SerializedName("total_gb") val totalGB: Double = 0.0,
    @SerializedName("used_gb") val usedGB: Double = 0.0,
    @SerializedName("free_gb") val freeGB: Double = 0.0,
    @SerializedName("used_pct") val usedPct: Double = 0.0
)

// ─── Mail (Gmail) ──────────────────────────────────────────────────────────
data class MailResponse(
    val ok: Boolean = false,
    val connected: Boolean = false,
    val inbox: MailList? = null,
    val unread: UnreadCount? = null,
    val error: String? = null
)

data class MailList(val messages: List<MailMessage>? = null, @SerializedName("result_size_estimate") val total: Int = 0)
data class UnreadCount(val count: Int = 0, @SerializedName("unread_count") val unreadCount: Int = 0)

data class MailMessage(
    val id: String = "",
    @SerializedName("thread_id") val threadId: String = "",
    val snippet: String? = null,
    val subject: String? = null,
    val from: String? = null,
    val date: String? = null,
    @SerializedName("is_unread") val isUnread: Boolean = false,
    val labels: List<String>? = null
)

// ─── Voice (Google Voice via Gmail) ────────────────────────────────────────
data class VoiceResponse(
    val ok: Boolean = false,
    val connected: Boolean = false,
    val messages: List<MailMessage>? = null,  // reuse MailMessage shape
    val error: String? = null
)

// ─── Contacts ──────────────────────────────────────────────────────────────
data class ContactsResponse(
    val ok: Boolean = false,
    val contacts: List<Contact>? = null,
    val connections: List<Contact>? = null,  // Google People API uses "connections"
    val error: String? = null
)

data class Contact(
    val name: String? = null,
    @SerializedName("display_name") val displayName: String? = null,
    val email: String? = null,
    val phone: String? = null,
    val photo: String? = null,
    @SerializedName("resource_name") val resourceName: String? = null
) {
    val displayOrName: String get() = displayName ?: name ?: "Unknown"
    val initials: String get() {
        val n = displayOrName.split(" ")
        return when {
            n.size >= 2 -> "${n[0].first()}${n[1].first()}".uppercase()
            n.isNotEmpty() -> n[0].take(2).uppercase()
            else -> "?"
        }
    }
}

// ─── Drive files ───────────────────────────────────────────────────────────
data class DriveFilesResponse(
    val ok: Boolean = false,
    val files: List<DriveFile>? = null,
    val error: String? = null
)

data class DriveFile(
    val id: String = "",
    val name: String = "",
    @SerializedName("mime_type") val mimeType: String? = null,
    @SerializedName("modified_time") val modifiedTime: String? = null,
    @SerializedName("web_view_link") val webViewLink: String? = null,
    val size: Long? = null,
    val starred: Boolean = false,
    @SerializedName("icon_link") val iconLink: String? = null
) {
    val icon: String get() = when {
        mimeType?.contains("spreadsheet") == true -> "📊"
        mimeType?.contains("document") == true    -> "📝"
        mimeType?.contains("presentation") == true-> "📑"
        mimeType?.contains("folder") == true      -> "📁"
        mimeType?.contains("image") == true       -> "🖼️"
        mimeType?.contains("pdf") == true         -> "📄"
        mimeType?.contains("video") == true       -> "🎬"
        mimeType?.contains("audio") == true       -> "🎵"
        mimeType?.contains("zip") == true         -> "📦"
        else -> "📄"
    }
}

// ─── Calendar ──────────────────────────────────────────────────────────────
data class CalendarResponse(
    val ok: Boolean = false,
    val events: EventList? = null,
    val error: String? = null
)

data class EventList(val items: List<CalEvent>? = null, val summary: String? = null)

data class CalEvent(
    val id: String = "",
    val summary: String? = null,
    val description: String? = null,
    val location: String? = null,
    val start: EventTime? = null,
    val end: EventTime? = null,
    val status: String? = null
)

data class EventTime(
    @SerializedName("date_time") val dateTime: String? = null,
    val date: String? = null
) {
    val display: String get() = dateTime?.take(16)?.replace("T", " ") ?: date ?: ""
}

// ─── Telemetry ─────────────────────────────────────────────────────────────
data class TelemetryResponse(
    val ok: Boolean = false,
    val telemetry: SystemTelemetry? = null,
    val error: String? = null
)

data class SystemTelemetry(
    val timestamp: String? = null,
    val cpu: CpuInfo? = null,
    val memory: MemInfo? = null,
    val gpu: GpuInfo? = null,
    val network: List<NetIface>? = null,
    @SerializedName("top_processes") val topProcs: List<ProcInfo>? = null,
    val uptime: String? = null,
    @SerializedName("load_avg") val loadAvg: List<Double>? = null
)

data class CpuInfo(
    val model: String? = null,
    val cores: Int = 0,
    @SerializedName("usage_pct") val usagePct: Double = 0.0,
    @SerializedName("freq_mhz") val freqMHz: Double = 0.0,
    @SerializedName("temp_c") val tempC: Double = 0.0
)

data class MemInfo(
    @SerializedName("total_mb") val totalMB: Long = 0,
    @SerializedName("used_mb") val usedMB: Long = 0,
    @SerializedName("avail_mb") val availMB: Long = 0,
    @SerializedName("usage_pct") val usagePct: Double = 0.0,
    @SerializedName("swap_total_mb") val swapTotalMB: Long = 0,
    @SerializedName("swap_used_mb") val swapUsedMB: Long = 0
)

data class GpuInfo(
    val vendor: String? = null,
    val name: String? = null,
    @SerializedName("usage_pct") val usagePct: Double = 0.0,
    @SerializedName("mem_used_mb") val memUsedMB: Double = 0.0,
    @SerializedName("mem_total_mb") val memTotalMB: Double = 0.0,
    @SerializedName("temp_c") val tempC: Double = 0.0,
    @SerializedName("power_w") val powerW: Double = 0.0,
    @SerializedName("fan_pct") val fanPct: Double = 0.0
)

data class NetIface(
    val name: String = "",
    @SerializedName("rx_mbps") val rxMbps: Double = 0.0,
    @SerializedName("tx_mbps") val txMbps: Double = 0.0
)

data class ProcInfo(
    val pid: Int = 0,
    val name: String = "",
    @SerializedName("cpu_pct") val cpuPct: Double = 0.0,
    @SerializedName("mem_mb") val memMB: Double = 0.0
)

// ─── AI Coach ──────────────────────────────────────────────────────────────
data class CoachResponse(
    val ok: Boolean = false,
    val game: String? = null,
    val tips: List<CoachTip>? = null,
    val at: String? = null,
    val error: String? = null
)

data class CoachTip(
    val category: String = "swarm",  // gaming | performance | swarm | shortcut | health
    val tip: String = "",
    val source: String? = null       // "live" | "static"
)

// ─── Lucille Assistant: project briefings ──────────────────────────────────
// Served by the separate Lucille Assistant service (own port, own pairing) —
// see data/network/LucilleAssistantApi.kt. Shape mirrors briefings.go's Briefing struct.
data class Briefing(
    val id: String = "",
    val title: String = "",
    val project: String = "",
    val summary: String = "",
    val body: String = "",
    @SerializedName("read_first") val readFirst: List<String>? = null,
    val order: Int = 0,
    val created: String? = null,
    val updated: String? = null
)

data class BriefingsListResponse(
    val ok: Boolean = false,
    val briefings: List<Briefing>? = null,
    val error: String? = null
)

data class PairRedeemResponse(
    val ok: Boolean = false,
    val id: String? = null,
    val token: String? = null,
    val error: String? = null
)
