package com.example.ui.coderdroid

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Storage for the GitHub personal access token CoderDroid's Git panel uses to
 * push/pull. Unlike [com.example.data.config.SwarmConnection]'s LAN-only swarm
 * token, this is a real external credential, so it goes through
 * EncryptedSharedPreferences (Android Keystore-backed) instead of plain prefs.
 */
class CdrGitCredentials(context: Context) {
    private val prefs: SharedPreferences = run {
        val masterKey = MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context.applicationContext,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    var username: String
        get() = prefs.getString(KEY_USERNAME, "") ?: ""
        set(value) = prefs.edit().putString(KEY_USERNAME, value.trim()).apply()

    var token: String
        get() = prefs.getString(KEY_TOKEN, "") ?: ""
        set(value) = prefs.edit().putString(KEY_TOKEN, value.trim()).apply()

    var authorName: String
        get() = prefs.getString("author_name", "") ?: ""
        set(value) = prefs.edit().putString("author_name", value.trim()).apply()
    var authorEmail: String
        get() = prefs.getString("author_email", "") ?: ""
        set(value) = prefs.edit().putString("author_email", value.trim()).apply()

    val hasCredentials: Boolean
        get() = token.isNotBlank()

    fun clear() = prefs.edit().remove(KEY_USERNAME).remove(KEY_TOKEN).apply()

    companion object {
        private const val PREFS_NAME = "cdr_git_credentials"
        private const val KEY_USERNAME = "username"
        private const val KEY_TOKEN = "token"
    }
}
