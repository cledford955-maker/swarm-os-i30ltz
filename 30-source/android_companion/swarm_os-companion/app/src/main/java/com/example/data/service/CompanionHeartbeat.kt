package com.example.data.service

import android.os.Build
import com.example.data.config.SwarmConnection
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Maintains a WebSocket connection to LucyServer's /api/companion/ws endpoint
 * so the desktop knows the phone is alive. The server pings every 5 s; OkHttp
 * responds to Pong automatically. If the connection drops, this reconnects
 * with exponential backoff (2 s → 60 s). Exposes connection state as a
 * StateFlow for the UI.
 */
class CompanionHeartbeat(private val conn: SwarmConnection) {

    enum class State { DISCONNECTED, CONNECTING, CONNECTED }

    private val _state = MutableStateFlow(State.DISCONNECTED)
    val state: StateFlow<State> = _state

    private val _serverCompanions = MutableStateFlow(0)
    val serverCompanions: StateFlow<Int> = _serverCompanions

    /**
     * Latest OTA update notice pushed from LucyServer, or null if none in this
     * session. Populated when the desktop's /api/updates/check sees a newer
     * SWARM ISO than the running system. UI consumers show a banner and
     * (optionally) trigger a system notification.
     */
    data class UpdateNotice(
        val currentVersion: String,
        val latestVersion: String,
        val filename: String,
        val sizeBytes: Long,
        val sha256: String,
        val at: String,
    )
    private val _pendingUpdate = MutableStateFlow<UpdateNotice?>(null)
    val pendingUpdate: StateFlow<UpdateNotice?> = _pendingUpdate

    /** Call after the user has acknowledged/dismissed the update banner. */
    fun clearPendingUpdate() { _pendingUpdate.value = null }

    private val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS)
        .pingInterval(15, TimeUnit.SECONDS)
        .build()

    @Volatile private var socket: WebSocket? = null
    @Volatile private var stopped = false
    private var backoffMs = BACKOFF_START_MS
    private var scope: CoroutineScope? = null

    fun start(scope: CoroutineScope) {
        this.scope = scope
        stopped = false
        connect()
    }

    fun stop() {
        stopped = true
        socket?.close(1000, "companion stopping")
        socket = null
        _state.value = State.DISCONNECTED
    }

    private fun connect() {
        if (stopped || socket != null) return
        if (!conn.isUsable) {
            _state.value = State.DISCONNECTED
            return
        }
        _state.value = State.CONNECTING
        val url = "${conn.wsBase()}/api/companion/ws"
        val request = Request.Builder()
            .url(url)
            .header("X-Swarm-Auth", conn.authToken)
            .build()
        socket = client.newWebSocket(request, Listener())
    }

    private fun scheduleReconnect() {
        if (stopped) return
        val delay = backoffMs
        backoffMs = (backoffMs * 2).coerceAtMost(BACKOFF_MAX_MS)
        scope?.launch {
            delay(delay)
            if (!stopped && socket == null) connect()
        }
    }

    private inner class Listener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            backoffMs = BACKOFF_START_MS
            val hello = JSONObject().apply {
                put("device_id", deviceId())
                put("device_name", deviceName())
            }
            webSocket.send(hello.toString())
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            val msg = runCatching { JSONObject(text) }.getOrNull() ?: return
            when (msg.optString("type")) {
                "welcome" -> {
                    _state.value = State.CONNECTED
                    _serverCompanions.value = msg.optInt("companions", 0)
                }
                "ack" -> {} // status acknowledgement, no action needed
                "swarm_os_update_available" -> {
                    // Desktop OTA push — a newer SWARM ISO is on Ventoy. UI
                    // consumers show this on the Remote PC screen; install
                    // is still a deliberate Ventoy-reboot action on the PC,
                    // never triggered from the phone.
                    _pendingUpdate.value = UpdateNotice(
                        currentVersion = msg.optString("current_version"),
                        latestVersion  = msg.optString("latest_version"),
                        filename       = msg.optString("filename"),
                        sizeBytes      = msg.optLong("size_bytes"),
                        sha256         = msg.optString("sha256"),
                        at             = msg.optString("at"),
                    )
                }
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) = lost(webSocket)
        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) = lost(webSocket)

        private fun lost(webSocket: WebSocket) {
            if (socket === webSocket) socket = null
            _state.value = State.DISCONNECTED
            _serverCompanions.value = 0
            scheduleReconnect()
        }
    }

    companion object {
        private const val BACKOFF_START_MS = 2_000L
        private const val BACKOFF_MAX_MS = 60_000L

        private fun deviceId(): String = "${Build.BRAND}-${Build.SERIAL}".take(64)
        private fun deviceName(): String = "${Build.MANUFACTURER} ${Build.MODEL}"
    }
}
