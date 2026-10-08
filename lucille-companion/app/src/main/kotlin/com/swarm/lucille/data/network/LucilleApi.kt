// LucilleApi.kt — OkHttp API client for Lucille Assistant  v1.0.0  2026-09-24
// No Retrofit, no Hilt — plain OkHttp + Gson, token as ?token= query param
package com.swarm.lucille.data.network

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Sealed result type — success or a human-readable error message. */
sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val message: String, val code: Int = 0) : ApiResult<Nothing>()
    object Loading : ApiResult<Nothing>()
}

class LucilleApi(
    private var baseUrl: String = "",
    private var token: String = ""
) {
    // ── OkHttp client ────────────────────────────────────────────────────────
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    private val gson: Gson = GsonBuilder().setLenient().create()
    private val json = "application/json; charset=utf-8".toMediaType()

    // ── Config ───────────────────────────────────────────────────────────────
    fun configure(url: String, tok: String) {
        baseUrl = url.trimEnd('/')
        token   = tok
    }

    val isConfigured: Boolean get() = baseUrl.startsWith("http") && token.isNotBlank()

    // ── HTTP helpers ─────────────────────────────────────────────────────────

    /** Build a URL appending ?token= and any extra params. */
    private fun url(path: String, params: Map<String, String> = emptyMap()): HttpUrl? {
        val raw = "$baseUrl$path"
        val builder = raw.toHttpUrlOrNull()?.newBuilder() ?: return null
        builder.addQueryParameter("token", token)
        params.forEach { (k, v) -> builder.addQueryParameter(k, v) }
        return builder.build()
    }

    private inline fun <reified T> get(path: String, params: Map<String, String> = emptyMap()): ApiResult<T> {
        val httpUrl = url(path, params) ?: return ApiResult.Error("Bad URL: $baseUrl$path")
        val req = Request.Builder().url(httpUrl).get().build()
        return execute(req)
    }

    private inline fun <reified T> post(path: String, body: Any): ApiResult<T> {
        val httpUrl = url(path) ?: return ApiResult.Error("Bad URL: $baseUrl$path")
        val jsonBody = gson.toJson(body).toRequestBody(json)
        val req = Request.Builder().url(httpUrl).post(jsonBody).build()
        return execute(req)
    }

    private inline fun <reified T> execute(req: Request): ApiResult<T> {
        return try {
            val resp = client.newCall(req).execute()
            val bodyStr = resp.body?.string() ?: ""
            if (!resp.isSuccessful) {
                return ApiResult.Error("HTTP ${resp.code}: $bodyStr", resp.code)
            }
            val type = object : TypeToken<T>() {}.type
            val parsed = gson.fromJson<T>(bodyStr, type)
            ApiResult.Success(parsed)
        } catch (e: IOException) {
            ApiResult.Error("Network error: ${e.message}")
        } catch (e: Exception) {
            ApiResult.Error("Parse error: ${e.message}")
        }
    }

    // ── Ping ─────────────────────────────────────────────────────────────────
    fun ping(): ApiResult<BaseResponse> = get("/api/health")

    // ── Brief ────────────────────────────────────────────────────────────────
    fun getDailyBrief(): ApiResult<DailyBriefResponse> = get("/api/brief/daily")
    fun getProjectBrief(): ApiResult<ProjectBriefResponse> = get("/api/brief/project")

    // ── Mail ─────────────────────────────────────────────────────────────────
    fun getMail(label: String = "INBOX", maxResults: Int = 20): ApiResult<MailResponse> =
        get("/api/mail", mapOf("label" to label, "max" to maxResults.toString()))

    // ── Voice ────────────────────────────────────────────────────────────────
    fun getVoiceSMS(): ApiResult<VoiceResponse>      = get("/api/voice", mapOf("kind" to "sms"))
    fun getVoiceCalls(): ApiResult<VoiceResponse>    = get("/api/voice", mapOf("kind" to "calls"))
    fun getVoiceVoicemail(): ApiResult<VoiceResponse> = get("/api/voice", mapOf("kind" to "voicemail"))
    fun getVoiceThread(threadId: String): ApiResult<VoiceResponse> =
        get("/api/voice", mapOf("thread" to threadId))

    fun sendVoiceSMS(threadId: String, body: String): ApiResult<BaseResponse> {
        val payload = mapOf("thread_id" to threadId, "body" to body)
        return post("/api/voice/send", payload)
    }

    // ── Contacts ─────────────────────────────────────────────────────────────
    fun getContacts(): ApiResult<ContactsResponse>  = get("/api/contacts")
    fun searchContacts(q: String): ApiResult<ContactsResponse> =
        get("/api/contacts", mapOf("q" to q))

    // ── Drive ────────────────────────────────────────────────────────────────
    fun getDriveRecent(): ApiResult<DriveFilesResponse> =
        get("/api/drive/files", mapOf("mode" to "recent"))
    fun searchDrive(q: String): ApiResult<DriveFilesResponse> =
        get("/api/drive/files", mapOf("q" to q))
    fun listDriveFolder(parentId: String): ApiResult<DriveFilesResponse> =
        get("/api/drive/files", mapOf("parent" to parentId))

    // ── Calendar ─────────────────────────────────────────────────────────────
    fun getCalendar(days: Int = 7): ApiResult<CalendarResponse> =
        get("/api/calendar", mapOf("days" to days.toString()))

    // ── Telemetry ────────────────────────────────────────────────────────────
    fun getTelemetry(): ApiResult<TelemetryResponse> = get("/api/telemetry")

    // ── AI Coach ─────────────────────────────────────────────────────────────
    fun getCoachTips(game: String = ""): ApiResult<CoachResponse> =
        if (game.isBlank()) get("/api/coach")
        else get("/api/coach", mapOf("game" to game))

    // ── Ideas ────────────────────────────────────────────────────────────────
    fun getIdeas(): ApiResult<BaseResponse> = get("/api/ideas")

    // ── Git / Sessions (for SWARM status) ────────────────────────────────────
    fun getSessions(): ApiResult<BaseResponse> = get("/api/sessions")
}
