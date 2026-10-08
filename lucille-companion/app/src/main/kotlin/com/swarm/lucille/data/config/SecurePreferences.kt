package com.swarm.lucille.data.config

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/** One-time migration preserves existing connection and provider settings. */
fun securePreferences(context: Context, legacyName: String): SharedPreferences {
    val key = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
    val encrypted = EncryptedSharedPreferences.create(context, legacyName + "_secure", key,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)
    val old = context.getSharedPreferences(legacyName, Context.MODE_PRIVATE)
    if(old.all.isNotEmpty()) {
        val editor=encrypted.edit()
        old.all.forEach { (name,value) -> if(!encrypted.contains(name)) when(value) {
            is String -> editor.putString(name,value)
            is Int -> editor.putInt(name,value)
            is Boolean -> editor.putBoolean(name,value)
            is Long -> editor.putLong(name,value)
            is Float -> editor.putFloat(name,value)
        } }
        check(editor.commit()) { "Could not save encrypted settings" }
        old.edit().clear().commit()
    }
    return encrypted
}
