package com.swarm.lucille.data.config

import android.content.Context
import android.content.SharedPreferences
import okhttp3.OkHttpClient
import java.net.ConnectException
import java.net.NoRouteToHostException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit

/**
 * Single source of truth for how the companion app reaches LucyServer:
 * host, port and the X-Swarm-Auth token. Used by RemotePcScreen,
 * InteractiveTerminalScreen and AppRepository's phone-to-PC bridge call —
 * previously each of those hardcoded its own copy of the IP and token.
 */
class SwarmConnection(context: Context) {
    private val prefs: SharedPreferences =
        securePreferences(context.applicationContext, PREFS_NAME)

    var host: String
        get() = prefs.getString(KEY_HOST, DEFAULT_HOST) ?: DEFAULT_HOST
        set(value) = prefs.edit().putString(KEY_HOST, value.trim()).apply()

    var port: Int
        get() = prefs.getInt(KEY_PORT, DEFAULT_PORT)
        set(value) = prefs.edit().putInt(KEY_PORT, value).apply()

    var authToken: String
        get() = prefs.getString(KEY_TOKEN, DEFAULT_TOKEN) ?: DEFAULT_TOKEN
        set(value) = prefs.edit().putString(KEY_TOKEN, value.trim()).apply()

    /** lucille-core companion socket (HITL approvals); same host and token. */
    var hitlPort: Int
        get() = prefs.getInt(KEY_HITL_PORT, DEFAULT_HITL_PORT)
        set(value) = prefs.edit().putInt(KEY_HITL_PORT, value).apply()

    /** Keep the approval link open in the background (foreground service). */
    var hitlAlertsEnabled: Boolean
        get() = prefs.getBoolean(KEY_HITL_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_HITL_ENABLED, value).apply()

    fun httpBase(): String = "http://$host:$port"
    fun wsBase(): String = "ws://$host:$port"

    val isUsable: Boolean
        get() = host.isNotBlank() && authToken.isNotBlank()

    /** OkHttp client for the terminal WebSocket: pings keep an idle shell alive through Tailscale/NAT. */
    fun terminalClient(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS)
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    /**
     * Turns a failed call into something actionable. Every terminal failure on
     * 2026-09-16 looked like a bare "Failed to connect", with three different
     * causes: server bound to loopback, phone off the tailnet, wrong token.
     */
    fun explain(t: Throwable?, httpCode: Int? = null): String {
        val target = "$host:$port"
        return when {
            httpCode == 401 || httpCode == 403 ->
                "LucyServer at $target rejected the auth token. Save CachyOS’s configured access token under Remote PC → CHANGE NODE."
            t is ConnectException && t.message.orEmpty().contains("ECONNREFUSED") ->
                "Reached $host, but nothing is listening on port $port. Start LucyServer on CachyOS, and make sure it listens on its Tailscale address, not only 127.0.0.1."
            t is SocketTimeoutException || t is NoRouteToHostException || t?.message.orEmpty().contains("timeout", ignoreCase = true) ->
                "No route to $target. Turn on Tailscale on this phone, and check that CachyOS is online (tailscale status)."
            t is UnknownHostException -> "Can't resolve \"$host\". Use CachyOS's Tailscale IP, e.g. $DEFAULT_HOST."
            httpCode != null -> "LucyServer at $target answered HTTP $httpCode."
            else -> "Connection to $target failed: ${t?.message ?: "unknown error"}"
        }
    }

    companion object {
        private const val PREFS_NAME = "swarm_connection"
        private const val KEY_HOST = "host"
        private const val KEY_PORT = "port"
        private const val KEY_TOKEN = "auth_token"
        private const val KEY_HITL_PORT = "hitl_port"
        private const val KEY_HITL_ENABLED = "hitl_enabled"
        const val DEFAULT_HITL_PORT = 9091

        // Matches LucyServer-go's swarmAuthMiddleware fallback (main.go),
        // used whenever SWARM_AUTH_TOKEN isn't set in the environment —
        // which is the case on this drive's /20-runtime/.env today.
        // CachyOS (CachyOS daily driver, renamed from LUCILLE
        // 2026-09-19) as of 2026-09-16 (`tailscale status`). SWARM OS on
        // the same machine is 100.82.1.20 — switch under Remote PC → CHANGE NODE.
        const val DEFAULT_HOST = "100.82.1.19"
        const val DEFAULT_PORT = 5000
        const val DEFAULT_TOKEN = "swarm-token-2026"
    }
}
