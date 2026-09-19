package com.example.data.memory

import android.annotation.SuppressLint
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.example.data.config.SwarmConnection
import com.example.data.db.AppDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.time.Instant
import java.util.concurrent.TimeUnit

/** Sync status for one peer, shown on the Memory screen. */
data class PeerStatus(
    val name: String,
    val url: String,
    val lastOk: String? = null,
    val lastError: String? = null,
    val pulled: Int = 0,
    val pushed: Int = 0
)

/** Who is "main" for live editing (spec §3.5). */
data class LeaseState(val holder: String = "", val expires: String = "", val known: Boolean = false) {
    val isFree get() = holder.isEmpty()
}

/**
 * Keeps this phone's copy of the shared memory in step with 13E457-THUNDERI30LT
 * and the other phones. Spec: 90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md.
 *
 *  - Writes land in Room first (the offline queue) and push on the next sync.
 *  - Sync runs on network reconnect (callback, not a timer), every 15 min via
 *    JobScheduler under Doze, and on demand.
 *  - Peers: 13E457-THUNDERI30LT over Tailscale, plus anything advertising
 *    _swarmcompanion._tcp on the LAN — 13E457-THUNDERI30LT via avahi, and other phones.
 *    Entries from third devices are forwarded too, so the mesh converges by gossip.
 *  - The write lease and the live SSE stream come from 13E457-THUNDERI30LT.
 */
object MemorySyncEngine {
    private const val TAG = "MemorySyncEngine"
    private const val PREFS = "swarm_memory"
    private const val JOB_ID = 84020

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val syncMutex = Mutex()
    private val json = "application/json".toMediaType()

    private lateinit var app: Context
    private lateinit var dao: MemoryDao
    private lateinit var connection: SwarmConnection
    private lateinit var server: MemorySyncServer
    private lateinit var discovery: MemoryPeerDiscovery
    private var started = false

    private val http = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    private val streamHttp = http.newBuilder().readTimeout(0, TimeUnit.SECONDS).build()

    private val _status = MutableStateFlow("Not synced yet")
    val status: StateFlow<String> = _status.asStateFlow()
    private val _syncing = MutableStateFlow(false)
    val syncing: StateFlow<Boolean> = _syncing.asStateFlow()
    private val _peers = MutableStateFlow<List<PeerStatus>>(emptyList())
    val peers: StateFlow<List<PeerStatus>> = _peers.asStateFlow()
    private val _lease = MutableStateFlow(LeaseState())
    val lease: StateFlow<LeaseState> = _lease.asStateFlow()
    private val _live = MutableStateFlow(false)
    val live: StateFlow<Boolean> = _live.asStateFlow()

    private var heartbeatJob: Job? = null
    private var streamJob: Job? = null

    val deviceId: String
        get() = prefs().getString("device_id", null) ?: run {
            @SuppressLint("HardwareIds")
            val androidId = Settings.Secure.getString(app.contentResolver, Settings.Secure.ANDROID_ID).orEmpty()
            val model = Build.MODEL.lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-').take(20)
            val id = "phone-$model-${androidId.take(6)}".replace("--", "-")
            prefs().edit().putString("device_id", id).apply()
            id
        }

    val isMain: Boolean get() = _lease.value.holder == deviceId

    /** Idempotent; call from MainActivity and the sync job. */
    @Synchronized
    fun start(context: Context) {
        if (started) return
        started = true
        app = context.applicationContext
        dao = AppDatabase.getInstance(app).memoryDao()
        connection = SwarmConnection(app)
        server = MemorySyncServer(scope, dao, { deviceId }, { connection.authToken }) { n ->
            _status.value = "Received $n entr${if (n == 1) "y" else "ies"} from a peer"
        }
        discovery = MemoryPeerDiscovery(app) { "swarm-$deviceId" }
        startMeshIfSecure()
        watchNetwork()
        schedulePeriodicJob()
        scope.launch { discovery.peers.collect { if (it.isNotEmpty()) requestSync() } }
        requestSync()
    }

    private val _meshEnabled = MutableStateFlow(false)
    /** Phone-to-phone sync (embedded server + mDNS) is on only with a real token. */
    val meshEnabled: StateFlow<Boolean> = _meshEnabled.asStateFlow()

    /**
     * The default token is public, so a phone serving its memory on the LAN
     * behind it would expose everything to anyone on the Wi-Fi. Syncing out to
     * 13E457-THUNDERI30LT still works; serving and discovery wait for a real token.
     */
    fun startMeshIfSecure() {
        if (!started) return
        val secure = connection.authToken != SwarmConnection.DEFAULT_TOKEN
        if (secure && !server.isRunning) {
            server.start()
            discovery.start()
        } else if (!secure && server.isRunning) {
            server.stop()
            discovery.stop()
        }
        _meshEnabled.value = server.isRunning
    }

    fun entries(kind: String, query: String): Flow<List<MemoryEntryEntity>> = dao.observe(kind, query, 300)
    fun count(): Flow<Int> = dao.count()
    private val _pending = MutableStateFlow(0)
    /** Entries 13E457-THUNDERI30LT has not received from this phone yet. */
    val pending: StateFlow<Int> = _pending.asStateFlow()

    private suspend fun updatePending() {
        _pending.value = dao.since(pushCursor(pcUrl()), 10_000).size
    }

    private fun prefs() = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    // Over Tailscale 13E457-THUNDERI30LT is reached on the main API port (token-guarded, 5000).
    // The sync-only port 8402 is the LAN fallback, found through mDNS.
    private fun pcUrl() = "http://${connection.host}:${connection.port}"
    private fun pullCursor(peer: String) = prefs().getString("pull:$peer", "") ?: ""
    private fun pushCursor(peer: String) = prefs().getLong("push:$peer", 0L)

    // ── Writing ───────────────────────────────────────────────────────────────

    sealed class WriteResult {
        data object Saved : WriteResult()
        data class Blocked(val holder: String) : WriteResult()
    }

    /**
     * Saves a memory. While another device is main (and we can see 13E457-THUNDERI30LT),
     * live writes are refused so the lease means something; offline, the entry
     * is queued and merges on the next sync, as the spec allows.
     */
    suspend fun add(kind: String, key: String, content: String): WriteResult = withContext(Dispatchers.IO) {
        val lease = _lease.value
        if (lease.known && !lease.isFree && lease.holder != deviceId) return@withContext WriteResult.Blocked(lease.holder)
        dao.insertAll(listOf(MemoryEntryEntity.create(deviceId, kind, key.trim(), content.trim())))
        updatePending()
        requestSync()
        WriteResult.Saved
    }

    // ── Sync ──────────────────────────────────────────────────────────────────

    fun requestSync() {
        scope.launch { syncAll() }
    }

    suspend fun syncAll() {
        if (!started) return
        if (!syncMutex.tryLock()) return // one pass at a time; a pass already covers this request
        try {
            _syncing.value = true
            val targets = linkedMapOf("13E457-THUNDERI30LT (Tailscale)" to pcUrl())
            discovery.peers.value.forEach { (name, url) -> if (url !in targets.values) targets[name] = url }
            val results = targets.map { (name, url) -> syncWithPeer(name, url) }
            _peers.value = results
            val ok = results.count { it.lastError == null }
            val pulled = results.sumOf { it.pulled }
            val pushed = results.sumOf { it.pushed }
            _status.value = if (ok == 0) "Offline — changes are saved on this phone and will sync later"
            else "Synced with $ok of ${results.size} peer${if (results.size == 1) "" else "s"} · pulled $pulled, pushed $pushed"
            if (ok > 0) refreshLease()
            updatePending()
        } finally {
            _syncing.value = false
            syncMutex.unlock()
        }
    }

    private suspend fun syncWithPeer(name: String, base: String): PeerStatus = withContext(Dispatchers.IO) {
        var pulled = 0
        var pushed = 0
        try {
            // Pull until the peer says there is no more.
            var cursor = pullCursor(base)
            while (true) {
                val url = "$base${MemorySyncServer.SYNC_PATH}?cursor=${URLEncoder.encode(cursor, "UTF-8")}"
                val body = call(Request.Builder().url(url).get())
                val arr = body.optJSONArray("entries") ?: JSONArray()
                val entries = (0 until arr.length()).mapNotNull { MemoryEntryEntity.fromJson(arr.getJSONObject(it)) }
                pulled += dao.insertAll(entries).count { it != -1L }
                cursor = body.optString("cursor", cursor)
                prefs().edit().putString("pull:$base", cursor).apply()
                if (!body.optBoolean("more", false)) break
            }

            // Push everything the peer hasn't had from us, including gossip.
            var after = pushCursor(base)
            while (true) {
                val batch = dao.since(after, 200)
                if (batch.isEmpty()) break
                val payload = JSONObject().put("entries", JSONArray().apply { batch.forEach { put(it.toJson()) } })
                call(Request.Builder().url("$base${MemorySyncServer.SYNC_PATH}").post(payload.toString().toRequestBody(json)))
                pushed += batch.size
                after = batch.last().seq
                prefs().edit().putLong("push:$base", after).apply()
            }
            PeerStatus(name, base, lastOk = Instant.now().toString(), pulled = pulled, pushed = pushed)
        } catch (e: Exception) {
            PeerStatus(name, base, lastError = e.message ?: e.javaClass.simpleName, pulled = pulled, pushed = pushed)
        }
    }

    private fun call(builder: Request.Builder, client: OkHttpClient = http): JSONObject {
        client.newCall(builder.header("X-Swarm-Auth", connection.authToken).build()).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            val obj = runCatching { JSONObject(text) }.getOrElse { JSONObject() }
            if (!resp.isSuccessful) throw HttpError(resp.code, obj.optString("error", "HTTP ${resp.code}"), obj)
            return obj
        }
    }

    class HttpError(val code: Int, message: String, val body: JSONObject) : Exception(message)

    // ── Write lease ───────────────────────────────────────────────────────────

    private fun leaseFrom(o: JSONObject) = LeaseState(o.optString("holder"), o.optString("expires"), known = true)

    suspend fun refreshLease() = withContext(Dispatchers.IO) {
        runCatching { _lease.value = leaseFrom(call(Request.Builder().url("${pcUrl()}/api/memory/lease").get())) }
    }

    /** Make this phone main. [force] is the explicit "take over" from another device. */
    suspend fun acquireLease(force: Boolean): Result<LeaseState> = withContext(Dispatchers.IO) {
        runCatching {
            val body = JSONObject().put("device", deviceId).put("force", force).toString().toRequestBody(json)
            val state = leaseFrom(call(Request.Builder().url("${pcUrl()}/api/memory/lease/acquire").post(body)))
            _lease.value = state
            startHeartbeat()
            state
        }.onFailure { e ->
            if (e is HttpError && e.code == 409) e.body.optJSONObject("lease")?.let { _lease.value = leaseFrom(it) }
        }
    }

    suspend fun releaseLease() = withContext(Dispatchers.IO) {
        heartbeatJob?.cancel()
        runCatching {
            val body = JSONObject().put("device", deviceId).toString().toRequestBody(json)
            call(Request.Builder().url("${pcUrl()}/api/memory/lease/release").post(body))
            _lease.value = LeaseState(known = true)
        }
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive && isMain) {
                delay(10_000)
                try {
                    val body = JSONObject().put("device", deviceId).toString().toRequestBody(json)
                    _lease.value = leaseFrom(call(Request.Builder().url("${pcUrl()}/api/memory/lease/heartbeat").post(body)))
                } catch (e: HttpError) {
                    if (e.code == 409) { // someone took over, or we lapsed
                        e.body.optJSONObject("lease")?.let { _lease.value = leaseFrom(it) } ?: refreshLease()
                        break
                    }
                } catch (_: Exception) {
                    // Unreachable for a beat; the lease expires by itself after 30 s if this lasts.
                }
            }
        }
    }

    // ── Live stream (while the Memory screen is open) ─────────────────────────

    fun startLive() {
        if (!started || streamJob?.isActive == true) return
        streamJob = scope.launch {
            while (isActive) {
                try {
                    val req = Request.Builder().url("http://${connection.host}:${connection.port}/api/memory/stream")
                        .header("X-Swarm-Auth", connection.authToken).build()
                    streamHttp.newCall(req).execute().use { resp ->
                        if (!resp.isSuccessful) throw HttpError(resp.code, "stream HTTP ${resp.code}", JSONObject())
                        _live.value = true
                        val source = resp.body!!.source()
                        var event = ""
                        while (isActive) {
                            val line = source.readUtf8Line() ?: break
                            when {
                                line.startsWith("event:") -> event = line.removePrefix("event:").trim()
                                line.startsWith("data:") -> handleEvent(event, line.removePrefix("data:").trim())
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "live stream dropped: ${e.message}")
                }
                _live.value = false
                delay(5_000)
            }
        }
    }

    fun stopLive() {
        streamJob?.cancel()
        _live.value = false
    }

    private suspend fun handleEvent(event: String, data: String) {
        val obj = runCatching { JSONObject(data) }.getOrNull() ?: return
        when (event) {
            "entry" -> MemoryEntryEntity.fromJson(obj)?.let { dao.insertAll(listOf(it)) }
            "lease" -> {
                _lease.value = leaseFrom(obj)
                if (!isMain) heartbeatJob?.cancel()
            }
        }
    }

    // ── Triggers ──────────────────────────────────────────────────────────────

    private fun watchNetwork() {
        val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                scope.launch {
                    delay(2_000) // let routes (and Tailscale) settle
                    syncAll()
                }
            }
        })
    }

    private fun schedulePeriodicJob() {
        val scheduler = app.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        if (scheduler.getPendingJob(JOB_ID) != null) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(app, MemorySyncJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPeriodic(TimeUnit.MINUTES.toMillis(15))
            .setPersisted(true)
            .build()
        runCatching { scheduler.schedule(job) }.onFailure { Log.w(TAG, "could not schedule sync job", it) }
    }
}
