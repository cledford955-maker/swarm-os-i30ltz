// LucilleRepository.kt — single source of truth for all Lucille data  v1.0.0  2026-09-24
// Wraps LucilleApi with coroutine dispatchers + in-memory TTL cache
package com.swarm.lucille.data.repository

import com.swarm.lucille.data.network.*
import com.swarm.lucille.data.prefs.AppPrefs
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.firstOrNull

/** Lightweight time-bounded cache entry. */
private data class CacheEntry<T>(val value: T, val at: Long = System.currentTimeMillis())
private fun <T> CacheEntry<T>?.valid(ttlMs: Long) = this != null && System.currentTimeMillis() - at < ttlMs

class LucilleRepository(
    private val api: LucilleApi,
    private val assistantApi: LucilleAssistantApi,
    private val prefs: AppPrefs
) {
    private val io = Dispatchers.IO

    // ── Per-endpoint TTL caches ────────────────────────────────────────────
    private var cacheDailyBrief:   CacheEntry<DailyBriefResponse>?  = null
    private var cacheProjectBrief: CacheEntry<ProjectBriefResponse>? = null
    private var cacheTelemetry:    CacheEntry<TelemetryResponse>?    = null
    private var cacheContacts:     CacheEntry<ContactsResponse>?     = null
    private var cacheDriveRecent:  CacheEntry<DriveFilesResponse>?   = null
    private var cacheCalendar:     CacheEntry<CalendarResponse>?     = null
    private var cacheSMS:          CacheEntry<VoiceResponse>?        = null
    private var cacheCalls:        CacheEntry<VoiceResponse>?        = null
    private var cacheVoicemail:    CacheEntry<VoiceResponse>?        = null
    private var cacheBriefings:    CacheEntry<BriefingsListResponse>? = null

    companion object {
        const val TTL_BRIEF    = 5 * 60_000L   // 5 min
        const val TTL_CONTACTS = 5 * 60_000L   // 5 min
        const val TTL_DRIVE    = 2 * 60_000L   // 2 min
        const val TTL_CALENDAR = 2 * 60_000L   // 2 min
        const val TTL_VOICE    = 90 * 1_000L   // 90 s
        const val TTL_TELEMETRY= 3 * 1_000L    // 3 s (live data)
        const val TTL_BRIEFINGS= 2 * 60_000L   // 2 min
    }

    // ── Config sync ───────────────────────────────────────────────────────
    /** Pull latest credentials from DataStore and configure the API clients. */
    suspend fun syncConfig() {
        val url = prefs.serverUrl.firstOrNull() ?: ""
        val tok = prefs.authToken.firstOrNull() ?: ""
        api.configure(url, tok)
        val assistantTok = prefs.assistantToken.firstOrNull() ?: ""
        assistantApi.configureFromLucyServerUrl(url, assistantTok)
    }

    /** Reconfigure immediately with new credentials. */
    fun configure(url: String, token: String) {
        api.configure(url, token)
        clearCache()
    }

    /** Lucille Assistant has its own device-pairing token, separate from LucyServer's. */
    suspend fun configureAssistantToken(token: String) {
        prefs.setAssistantToken(token)
        val url = prefs.serverUrl.firstOrNull() ?: ""
        assistantApi.configureFromLucyServerUrl(url, token)
        cacheBriefings = null
    }

    fun clearCache() {
        cacheDailyBrief   = null
        cacheProjectBrief = null
        cacheTelemetry    = null
        cacheContacts     = null
        cacheDriveRecent  = null
        cacheCalendar     = null
        cacheSMS          = null
        cacheCalls        = null
        cacheVoicemail    = null
        cacheBriefings    = null
    }

    // ── Connectivity check ────────────────────────────────────────────────
    suspend fun ping(): ApiResult<BaseResponse> = withContext(io) { api.ping() }

    // ── Brief ─────────────────────────────────────────────────────────────
    suspend fun getDailyBrief(forceRefresh: Boolean = false): ApiResult<DailyBriefResponse> =
        withContext(io) {
            if (!forceRefresh && cacheDailyBrief.valid(TTL_BRIEF)) {
                return@withContext ApiResult.Success(cacheDailyBrief!!.value)
            }
            val res = api.getDailyBrief()
            if (res is ApiResult.Success) cacheDailyBrief = CacheEntry(res.data)
            res
        }

    suspend fun getProjectBrief(forceRefresh: Boolean = false): ApiResult<ProjectBriefResponse> =
        withContext(io) {
            if (!forceRefresh && cacheProjectBrief.valid(TTL_BRIEF)) {
                return@withContext ApiResult.Success(cacheProjectBrief!!.value)
            }
            val res = api.getProjectBrief()
            if (res is ApiResult.Success) cacheProjectBrief = CacheEntry(res.data)
            res
        }

    // ── Mail ──────────────────────────────────────────────────────────────
    suspend fun getMail(label: String = "INBOX"): ApiResult<MailResponse> =
        withContext(io) { api.getMail(label) }

    // ── Voice ─────────────────────────────────────────────────────────────
    suspend fun getVoiceSMS(forceRefresh: Boolean = false): ApiResult<VoiceResponse> =
        withContext(io) {
            if (!forceRefresh && cacheSMS.valid(TTL_VOICE)) {
                return@withContext ApiResult.Success(cacheSMS!!.value)
            }
            val res = api.getVoiceSMS()
            if (res is ApiResult.Success) cacheSMS = CacheEntry(res.data)
            res
        }

    suspend fun getVoiceCalls(forceRefresh: Boolean = false): ApiResult<VoiceResponse> =
        withContext(io) {
            if (!forceRefresh && cacheCalls.valid(TTL_VOICE)) {
                return@withContext ApiResult.Success(cacheCalls!!.value)
            }
            val res = api.getVoiceCalls()
            if (res is ApiResult.Success) cacheCalls = CacheEntry(res.data)
            res
        }

    suspend fun getVoiceVoicemail(forceRefresh: Boolean = false): ApiResult<VoiceResponse> =
        withContext(io) {
            if (!forceRefresh && cacheVoicemail.valid(TTL_VOICE)) {
                return@withContext ApiResult.Success(cacheVoicemail!!.value)
            }
            val res = api.getVoiceVoicemail()
            if (res is ApiResult.Success) cacheVoicemail = CacheEntry(res.data)
            res
        }

    suspend fun sendVoiceSMS(threadId: String, body: String): ApiResult<BaseResponse> =
        withContext(io) {
            val res = api.sendVoiceSMS(threadId, body)
            if (res is ApiResult.Success) cacheSMS = null // invalidate
            res
        }

    // ── Contacts ──────────────────────────────────────────────────────────
    suspend fun getContacts(forceRefresh: Boolean = false): ApiResult<ContactsResponse> =
        withContext(io) {
            if (!forceRefresh && cacheContacts.valid(TTL_CONTACTS)) {
                return@withContext ApiResult.Success(cacheContacts!!.value)
            }
            val res = api.getContacts()
            if (res is ApiResult.Success) cacheContacts = CacheEntry(res.data)
            res
        }

    suspend fun searchContacts(q: String): ApiResult<ContactsResponse> =
        withContext(io) { api.searchContacts(q) }

    // ── Drive ─────────────────────────────────────────────────────────────
    suspend fun getDriveRecent(forceRefresh: Boolean = false): ApiResult<DriveFilesResponse> =
        withContext(io) {
            if (!forceRefresh && cacheDriveRecent.valid(TTL_DRIVE)) {
                return@withContext ApiResult.Success(cacheDriveRecent!!.value)
            }
            val res = api.getDriveRecent()
            if (res is ApiResult.Success) cacheDriveRecent = CacheEntry(res.data)
            res
        }

    suspend fun searchDrive(q: String): ApiResult<DriveFilesResponse> =
        withContext(io) { api.searchDrive(q) }

    // ── Calendar ──────────────────────────────────────────────────────────
    suspend fun getCalendar(forceRefresh: Boolean = false): ApiResult<CalendarResponse> =
        withContext(io) {
            if (!forceRefresh && cacheCalendar.valid(TTL_CALENDAR)) {
                return@withContext ApiResult.Success(cacheCalendar!!.value)
            }
            val res = api.getCalendar()
            if (res is ApiResult.Success) cacheCalendar = CacheEntry(res.data)
            res
        }

    // ── Telemetry (always fresh — 3 s TTL) ───────────────────────────────
    suspend fun getTelemetry(): ApiResult<TelemetryResponse> =
        withContext(io) {
            if (cacheTelemetry.valid(TTL_TELEMETRY)) {
                return@withContext ApiResult.Success(cacheTelemetry!!.value)
            }
            val res = api.getTelemetry()
            if (res is ApiResult.Success) cacheTelemetry = CacheEntry(res.data)
            res
        }

    // ── Coach ─────────────────────────────────────────────────────────────
    suspend fun getCoachTips(game: String = ""): ApiResult<CoachResponse> =
        withContext(io) { api.getCoachTips(game) }

    // ── Lucille Assistant: project briefings ─────────────────────────────
    val assistantConfigured: Boolean get() = assistantApi.isConfigured && assistantApi.hasToken

    suspend fun getBriefings(forceRefresh: Boolean = false): ApiResult<BriefingsListResponse> =
        withContext(io) {
            if (!assistantApi.hasToken) return@withContext ApiResult.Error("Not paired with Lucille Assistant yet.")
            if (!forceRefresh && cacheBriefings.valid(TTL_BRIEFINGS)) {
                return@withContext ApiResult.Success(cacheBriefings!!.value)
            }
            val res = assistantApi.getBriefings()
            if (res is ApiResult.Success) cacheBriefings = CacheEntry(res.data)
            res
        }

    /** Redeems a 6-digit one-time code (printed on the PC) and saves the resulting token. */
    suspend fun redeemAssistantPairCode(code: String, label: String): ApiResult<PairRedeemResponse> =
        withContext(io) {
            val url = prefs.serverUrl.firstOrNull() ?: ""
            val res = assistantApi.redeemPairCode(url, code, label)
            if (res is ApiResult.Success && res.data.ok && !res.data.token.isNullOrBlank()) {
                configureAssistantToken(res.data.token)
            }
            res
        }
}
