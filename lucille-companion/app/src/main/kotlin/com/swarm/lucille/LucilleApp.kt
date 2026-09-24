// LucilleApp.kt — Application class for Lucille Companion  v1.0.0  2026-09-24
// Manual DI: single instances of API, Repository, and Prefs wired here
package com.swarm.lucille

import android.app.Application
import com.swarm.lucille.data.network.LucilleApi
import com.swarm.lucille.data.prefs.AppPrefs
import com.swarm.lucille.data.repository.LucilleRepository

class LucilleApp : Application() {

    // Singletons — accessible anywhere via (application as LucilleApp).*
    lateinit var prefs: AppPrefs
    lateinit var api: LucilleApi
    lateinit var repository: LucilleRepository

    override fun onCreate() {
        super.onCreate()
        prefs      = AppPrefs(this)
        api        = LucilleApi()
        repository = LucilleRepository(api, prefs)
    }
}
