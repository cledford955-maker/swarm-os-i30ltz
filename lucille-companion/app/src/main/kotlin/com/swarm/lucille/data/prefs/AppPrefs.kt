// AppPrefs.kt — DataStore preferences for Lucille Companion  v1.0.0  2026-09-24
// Stores: server URL, auth token, last-used tab, coach game name
package com.swarm.lucille.data.prefs

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "lucille_prefs")

class AppPrefs(private val ctx: Context) {

    companion object {
        val SERVER_URL  = stringPreferencesKey("server_url")
        val AUTH_TOKEN  = stringPreferencesKey("auth_token")
        val COACH_GAME  = stringPreferencesKey("coach_game")
        val LAST_TAB    = stringPreferencesKey("last_tab")
        // Lucille Assistant is a separate service on the same PC (its own port, its own
        // device-pairing token) — see data/network/LucilleAssistantApi.kt.
        val ASSISTANT_TOKEN = stringPreferencesKey("lucille_assistant_token")
    }

    val serverUrl: Flow<String>  = ctx.dataStore.data.map { it[SERVER_URL] ?: "" }
    val authToken: Flow<String>  = ctx.dataStore.data.map { it[AUTH_TOKEN] ?: "" }
    val coachGame: Flow<String>  = ctx.dataStore.data.map { it[COACH_GAME] ?: "" }
    val lastTab: Flow<String>    = ctx.dataStore.data.map { it[LAST_TAB]   ?: "brief" }
    val assistantToken: Flow<String> = ctx.dataStore.data.map { it[ASSISTANT_TOKEN] ?: "" }

    suspend fun setServerUrl(url: String)  { ctx.dataStore.edit { it[SERVER_URL] = url.trimEnd('/') } }
    suspend fun setAuthToken(tok: String)  { ctx.dataStore.edit { it[AUTH_TOKEN] = tok } }
    suspend fun setCoachGame(game: String) { ctx.dataStore.edit { it[COACH_GAME] = game } }
    suspend fun setLastTab(tab: String)    { ctx.dataStore.edit { it[LAST_TAB]   = tab } }
    suspend fun setAssistantToken(tok: String) { ctx.dataStore.edit { it[ASSISTANT_TOKEN] = tok } }

    /** True when both server URL and token are configured. */
    val isConfigured: Flow<Boolean> = ctx.dataStore.data.map { prefs ->
        val url = prefs[SERVER_URL] ?: ""
        val tok = prefs[AUTH_TOKEN] ?: ""
        url.startsWith("http") && tok.isNotBlank()
    }
}
