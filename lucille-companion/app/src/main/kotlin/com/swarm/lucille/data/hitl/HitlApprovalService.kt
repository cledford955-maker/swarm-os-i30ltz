package com.swarm.lucille.data.hitl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.swarm.lucille.R
import com.swarm.lucille.data.config.SwarmConnection
import com.swarm.lucille.ui.hitl.HitlApprovalActivity
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Keeps an authenticated WebSocket open to lucille-core's companion socket
 * (:9091 over Tailscale) and turns HITL approval requests into notifications.
 *
 * Foreground service instead of FCM (user decision 2026-09-25): nothing leaves
 * the tailnet and no Google account is needed, at the cost of a permanent
 * low-priority status notification.
 *
 * Liveness both ways: the server pings every 5 s and drops us after 3 missed
 * pongs (OkHttp answers pings automatically); OkHttp also pings the server
 * every 15 s and fails the socket if the PC stops answering, which triggers
 * a reconnect with backoff.
 */
class HitlApprovalService : Service() {

    companion object {
        private const val ACTION_CONNECT = "com.swarm.lucille.hitl.CONNECT"
        private const val ACTION_STOP = "com.swarm.lucille.hitl.STOP"
        private const val ACTION_RESPOND = "com.swarm.lucille.hitl.RESPOND"
        const val EXTRA_CHALLENGE_ID = "challenge_id"
        const val EXTRA_COMMAND = "command"
        const val EXTRA_RISK = "risk_level"
        const val EXTRA_EXPIRES_AT = "expires_at"
        private const val EXTRA_APPROVED = "approved"

        private const val CHANNEL_STATUS = "hitl_status"
        private const val CHANNEL_ALERTS = "hitl_alerts"
        private const val NOTIF_STATUS = 4100

        private const val BACKOFF_START_MS = 2_000L
        private const val BACKOFF_MAX_MS = 60_000L
        private const val AUTH_RETRY_MS = 5 * 60_000L

        /** Last status line, for the settings screen. */
        @Volatile var statusText: String = "Off"
            private set

        /** Start or stop the service to match the saved setting. */
        fun sync(context: Context) {
            val ctx = context.applicationContext
            if (SwarmConnection(ctx).hitlAlertsEnabled) {
                ContextCompat.startForegroundService(ctx, Intent(ctx, HitlApprovalService::class.java).setAction(ACTION_CONNECT))
            } else {
                ctx.stopService(Intent(ctx, HitlApprovalService::class.java))
                statusText = "Off"
            }
        }

        /** Reconnect with freshly saved host/port/token. */
        fun restart(context: Context) {
            val ctx = context.applicationContext
            ctx.stopService(Intent(ctx, HitlApprovalService::class.java))
            sync(ctx)
        }

        /** Send an approve/deny answer for a challenge over the open socket. */
        fun respond(context: Context, challengeId: String, approved: Boolean) {
            val ctx = context.applicationContext
            ContextCompat.startForegroundService(
                ctx,
                Intent(ctx, HitlApprovalService::class.java)
                    .setAction(ACTION_RESPOND)
                    .putExtra(EXTRA_CHALLENGE_ID, challengeId)
                    .putExtra(EXTRA_APPROVED, approved)
            )
        }

        fun alertNotificationId(challengeId: String) = 4200 + (challengeId.hashCode() and 0xFFFF)
    }

    private val handler = Handler(Looper.getMainLooper())
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS)
        .pingInterval(15, TimeUnit.SECONDS)
        .build()

    @Volatile private var socket: WebSocket? = null
    private var backoffMs = BACKOFF_START_MS
    private var stopping = false
    private val reconnect = Runnable { connect() }

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            // Network came back (e.g. Tailscale reconnected) — retry now, not after backoff
            handler.post {
                if (socket == null && !stopping) {
                    handler.removeCallbacks(reconnect)
                    backoffMs = BACKOFF_START_MS
                    connect()
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
        ServiceCompat.startForeground(
            this, NOTIF_STATUS, statusNotification("Connecting…"),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        )
        getSystemService(ConnectivityManager::class.java)?.registerDefaultNetworkCallback(networkCallback)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
            ACTION_RESPOND -> {
                val id = intent.getStringExtra(EXTRA_CHALLENGE_ID)
                if (id != null) send(id, intent.getBooleanExtra(EXTRA_APPROVED, false))
            }
        }
        if (!SwarmConnection(this).hitlAlertsEnabled) { stopSelf(); return START_NOT_STICKY }
        if (socket == null) handler.post { if (socket == null) connect() }
        return START_STICKY
    }

    override fun onDestroy() {
        stopping = true
        handler.removeCallbacksAndMessages(null)
        runCatching { getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(networkCallback) }
        socket?.close(1000, "companion alerts turned off")
        socket = null
        statusText = "Off"
        super.onDestroy()
    }

    // ---- Connection --------------------------------------------------------

    private fun connect() {
        if (stopping || socket != null) return
        val conn = SwarmConnection(this)
        if (!conn.isUsable) {
            setStatus("Set the SWARM host and token under Remote PC")
            return
        }
        val request = Request.Builder()
            .url("ws://${conn.host}:${conn.hitlPort}/")
            .header("X-Swarm-Auth", conn.authToken)
            .build()
        setStatus("Connecting to ${conn.host}:${conn.hitlPort}…")
        socket = client.newWebSocket(request, Listener(conn.host))
    }

    private fun scheduleReconnect(delayMs: Long) {
        if (stopping) return
        handler.removeCallbacks(reconnect)
        handler.postDelayed(reconnect, delayMs)
    }

    private inner class Listener(private val host: String) : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            handler.post { backoffMs = BACKOFF_START_MS }
            setStatus("Watching for approvals from $host")
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            val msg = runCatching { JSONObject(text) }.getOrNull() ?: return
            when (msg.optString("event")) {
                "hitl_challenge" -> showChallenge(msg)
                // Answered (by us or elsewhere) or expired — the alert is stale either way
                "hitl_resolved" -> cancelAlert(msg.optString("challenge_id"))
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) = lost(webSocket, null, null)

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) =
            lost(webSocket, t, response?.code)

        private fun lost(webSocket: WebSocket, t: Throwable?, httpCode: Int?) {
            handler.post {
                if (socket === webSocket) socket = null
                if (stopping) return@post
                if (httpCode == 401 || httpCode == 403) {
                    setStatus("SWARM rejected the token — update it under Remote PC")
                    scheduleReconnect(AUTH_RETRY_MS)
                } else {
                    setStatus("Reconnecting to $host in ${backoffMs / 1000}s" +
                              (t?.message?.let { " ($it)" } ?: ""))
                    scheduleReconnect(backoffMs)
                    backoffMs = (backoffMs * 2).coerceAtMost(BACKOFF_MAX_MS)
                }
            }
        }
    }

    private fun send(challengeId: String, approved: Boolean) {
        val body = JSONObject()
            .put("action", "hitl_response")
            .put("challenge_id", challengeId)
            .put("approved", approved)
            .toString()
        if (socket?.send(body) == true) {
            cancelAlert(challengeId)
        } else {
            // Keep the alert so the user can retry once the link is back
            notifyText("Not connected to SWARM — answer not sent. Try again when reconnected.")
        }
    }

    // ---- Notifications -----------------------------------------------------

    private fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_STATUS, "Approval link status", NotificationManager.IMPORTANCE_MIN)
                .apply { description = "Shows that the phone is listening for SWARM approval requests" }
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ALERTS, "Approval requests", NotificationManager.IMPORTANCE_HIGH)
                .apply {
                    description = "SWARM OS asking you to approve a risky action"
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                }
        )
    }

    private fun statusNotification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_STATUS)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("SWARM approvals")
            .setContentText(text)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()

    private fun setStatus(text: String) {
        statusText = text
        postIfAllowed(NOTIF_STATUS, statusNotification(text))
    }

    private fun showChallenge(msg: JSONObject) {
        val id = msg.optString("challenge_id").ifEmpty { return }
        val command = msg.optString("command")
        val risk = msg.optString("risk_level", "HIGH")
        val expiresAt = msg.optLong("expires_at", 0L)

        val review = Intent(this, HitlApprovalActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(EXTRA_CHALLENGE_ID, id)
            .putExtra(EXTRA_COMMAND, command)
            .putExtra(EXTRA_RISK, risk)
            .putExtra(EXTRA_EXPIRES_AT, expiresAt)
        val nid = alertNotificationId(id)
        val reviewPi = PendingIntent.getActivity(
            this, nid, review, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val denyPi = PendingIntent.getBroadcast(
            this, nid,
            Intent(this, HitlActionReceiver::class.java)
                .setAction(HitlActionReceiver.ACTION_DENY)
                .putExtra(EXTRA_CHALLENGE_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        // Lock screen shows only that a request exists, not the command
        val publicVersion = NotificationCompat.Builder(this, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("SWARM needs your approval")
            .setContentText("Unlock to review")
            .build()

        val builder = NotificationCompat.Builder(this, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("$risk: SWARM wants approval")
            .setContentText(command)
            .setStyle(NotificationCompat.BigTextStyle().bigText(command))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setContentIntent(reviewPi)
            .setAutoCancel(false)
            // Deny is one tap; approving always goes through the review screen + screen lock
            .addAction(0, "Deny", denyPi)
            .addAction(0, "Review", reviewPi)

        val msLeft = expiresAt * 1000 - System.currentTimeMillis()
        if (expiresAt > 0 && msLeft > 0) builder.setTimeoutAfter(msLeft)
        postIfAllowed(nid, builder.build())
    }

    private fun cancelAlert(challengeId: String) {
        if (challengeId.isNotEmpty()) NotificationManagerCompat.from(this).cancel(alertNotificationId(challengeId))
    }

    private fun notifyText(text: String) {
        postIfAllowed(
            4199,
            NotificationCompat.Builder(this, CHANNEL_ALERTS)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("SWARM approvals")
                .setContentText(text)
                .setAutoCancel(true)
                .build()
        )
    }

    private fun postIfAllowed(id: Int, n: Notification) {
        val nm = NotificationManagerCompat.from(this)
        if (nm.areNotificationsEnabled()) {
            try { nm.notify(id, n) } catch (_: SecurityException) { /* POST_NOTIFICATIONS revoked */ }
        }
    }
}
