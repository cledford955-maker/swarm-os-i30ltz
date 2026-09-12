package com.example.data.config

import android.content.Context
import android.content.SharedPreferences

/**
 * Single source of truth for how the companion app reaches LucyServer:
 * host, port and the X-Swarm-Auth token. Used by RemotePcScreen,
 * InteractiveTerminalScreen and AppRepository's phone-to-PC bridge call —
 * previously each of those hardcoded its own copy of the IP and token.
 */
class SwarmConnection(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var host: String
        get() = prefs.getString(KEY_HOST, DEFAULT_HOST) ?: DEFAULT_HOST
        set(value) = prefs.edit().putString(KEY_HOST, value.trim()).apply()

    var port: Int
        get() = prefs.getInt(KEY_PORT, DEFAULT_PORT)
        set(value) = prefs.edit().putInt(KEY_PORT, value).apply()

    var authToken: String
        get() = prefs.getString(KEY_TOKEN, DEFAULT_TOKEN) ?: DEFAULT_TOKEN
        set(value) = prefs.edit().putString(KEY_TOKEN, value.trim()).apply()

    fun httpBase(): String = "http://$host:$port"
    fun wsBase(): String = "ws://$host:$port"

    val isUsable: Boolean
        get() = host.isNotBlank() && authToken.isNotBlank()

    companion object {
        private const val PREFS_NAME = "swarm_connection"
        private const val KEY_HOST = "host"
        private const val KEY_PORT = "port"
        private const val KEY_TOKEN = "auth_token"

        // Matches LucyServer-go's swarmAuthMiddleware fallback (main.go),
        // used whenever SWARM_AUTH_TOKEN isn't set in the environment —
        // which is the case on this drive's /20-runtime/.env today.
        const val DEFAULT_HOST = "100.105.12.16"
        const val DEFAULT_PORT = 5000
        const val DEFAULT_TOKEN = "swarm-token-2026"
    }
}
