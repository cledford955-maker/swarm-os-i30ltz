// Prefs.kt — multi-host profile store  v1.0.0 · 2026-09-26
package os.swarm.lucille.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class HostProfile(
    val id:    String,   // "swarm" | "debian" | custom slug
    val label: String,   // "SWARM OS" / "I30LTZ Recovery"
    val host:  String,   // "http://100.82.1.19:8403"
    val token: String,
    val color: Long      // tint: Plasma=0xFF1A7FFF, amber for Debian=0xFFFFB300
)

val DEFAULT_PROFILES = listOf(
    HostProfile(
        id    = "swarm",
        label = "SWARM OS",
        host  = "http://100.82.1.19:8403",
        token = "",
        color = 0xFF1A7FFF   // electric blue
    ),
    HostProfile(
        id    = "cachyos",
        label = "CachyOS",
        host  = "http://100.82.1.18:8403",   // update with CachyOS Tailscale IP
        token = "",
        color = 0xFF00D4FF   // arc cyan
    ),
    HostProfile(
        id    = "debian",
        label = "I30LTZ Recovery",
        host  = "http://100.82.1.20:8403",   // update when Debian Lucille is deployed
        token = "",
        color = 0xFFFFB300   // amber — Dr. I30LTZ / MAD IT
    )
)

class Prefs(ctx: Context) {
    private val sp: SharedPreferences =
        ctx.getSharedPreferences("lucille_prefs", Context.MODE_PRIVATE)

    private val serializer = Json { ignoreUnknownKeys = true }

    // ─── Active profile ───────────────────────────────────────────────────────
    var activeId: String
        get() = sp.getString("active_id", "swarm") ?: "swarm"
        set(v) { sp.edit().putString("active_id", v).apply() }

    // ─── Profile list ─────────────────────────────────────────────────────────
    var profiles: List<HostProfile>
        get() {
            val raw = sp.getString("profiles", null) ?: return DEFAULT_PROFILES
            return try { serializer.decodeFromString(raw) } catch (_: Exception) { DEFAULT_PROFILES }
        }
        set(v) { sp.edit().putString("profiles", serializer.encodeToString(v)).apply() }

    val activeProfile: HostProfile?
        get() = profiles.firstOrNull { it.id == activeId }

    val isConfigured: Boolean
        get() = activeProfile?.let { it.host.isNotBlank() && it.token.isNotBlank() } ?: false

    // ─── Update a single profile ──────────────────────────────────────────────
    fun upsertProfile(profile: HostProfile) {
        val list = profiles.toMutableList()
        val idx  = list.indexOfFirst { it.id == profile.id }
        if (idx >= 0) list[idx] = profile else list.add(profile)
        profiles = list
    }

    // ─── Misc ─────────────────────────────────────────────────────────────────
    var lastTab: String
        get() = sp.getString("last_tab", "brief") ?: "brief"
        set(v) { sp.edit().putString("last_tab", v).apply() }

    fun clearAll() = sp.edit().clear().apply()
}
