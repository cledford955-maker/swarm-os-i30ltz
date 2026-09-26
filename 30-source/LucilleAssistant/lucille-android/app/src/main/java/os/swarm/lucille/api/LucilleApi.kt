// LucilleApi.kt — OkHttp client for :8403  v1.0.0 · 2026-09-26
package os.swarm.lucille.api

import kotlinx.serialization.json.Json
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

val json = Json { ignoreUnknownKeys = true; isLenient = true }

class LucilleApi(private val host: String, private val token: String) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private fun get(path: String): String {
        val req = Request.Builder()
            .url("$host$path")
            .header("X-Swarm-Auth", token)
            .build()
        val resp = client.newCall(req).execute()
        if (!resp.isSuccessful) throw IOException("HTTP ${resp.code}")
        return resp.body?.string() ?: ""
    }

    private fun post(path: String, body: String = "{}"): String {
        val rb = body.toRequestBody("application/json".toMediaType())
        val req = Request.Builder()
            .url("$host$path")
            .header("X-Swarm-Auth", token)
            .post(rb)
            .build()
        val resp = client.newCall(req).execute()
        if (!resp.isSuccessful) throw IOException("HTTP ${resp.code}")
        return resp.body?.string() ?: ""
    }

    // — Brief —
    fun brief(): String    = get("/api/brief")
    fun nudges(): String   = get("/api/nudges")

    // — Care —
    fun care(): String              = get("/api/care")
    fun logMed(name: String) : String = post("/api/care/med",   """{"name":"$name"}""")
    fun logWater(ml: Int)    : String = post("/api/care/water", """{"ml":$ml}""")
    fun logMeal(name: String): String = post("/api/care/meal",  """{"name":"$name"}""")
    fun logSleep()           : String = post("/api/care/sleep")

    // — Work —
    fun git(): String      = get("/api/git")
    fun drives(): String   = get("/api/drives")
    fun sessions(): String = get("/api/sessions")
    fun sessionStart(project: String): String = post("/api/sessions/start", """{"project":"$project"}""")
    fun sessionStop():  String = post("/api/sessions/stop")
    fun memory(): String   = get("/api/memory")
    fun memoryAdd(note: String): String = post("/api/memory", """{"note":"$note"}""")

    // — Games —
    fun gaming(): String   = get("/api/gaming")
    fun deals(): String    = get("/api/deals")
    fun news(tag: String = ""): String = get(if (tag.isEmpty()) "/api/news" else "/api/news?tag=$tag")

    // — Ideas —
    fun ideas(): String    = get("/api/ideas")

    // — Health check —
    fun health(): String   = get("/health")
}
