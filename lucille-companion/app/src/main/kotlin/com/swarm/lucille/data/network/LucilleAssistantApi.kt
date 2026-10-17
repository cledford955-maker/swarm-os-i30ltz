// LucilleAssistantApi.kt — OkHttp client for the separate Lucille Assistant service  v1.0.0  2026-10-10
// Lucille Assistant (project status briefings, PC telemetry/actions, device pairing)
// runs on the same PC as LucyServer but as its own process on its own port (8403),
// with its own device-pairing token — never the LucyServer authToken.
package com.swarm.lucille.data.network

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

class LucilleAssistantApi(
    private var baseUrl: String = "",
    private var token: String = ""
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    private val gson: Gson = GsonBuilder().setLenient().create()
    private val json = "application/json; charset=utf-8".toMediaType()

    /** Lucille Assistant lives on the same host as LucyServer, just a different port. */
    fun configureFromLucyServerUrl(lucyServerUrl: String, assistantToken: String) {
        token = assistantToken
        val host = lucyServerUrl.toHttpUrlOrNull()
        baseUrl = if (host != null) "${host.scheme}://${host.host}:8403" else ""
    }

    val isConfigured: Boolean get() = baseUrl.startsWith("http")
    val hasToken: Boolean get() = token.isNotBlank()

    private fun url(path: String, params: Map<String, String> = emptyMap()): HttpUrl? {
        val builder = "$baseUrl$path".toHttpUrlOrNull()?.newBuilder() ?: return null
        if (token.isNotBlank()) builder.addQueryParameter("token", token)
        params.forEach { (k, v) -> builder.addQueryParameter(k, v) }
        return builder.build()
    }

    private inline fun <reified T> get(path: String, params: Map<String, String> = emptyMap()): ApiResult<T> {
        val httpUrl = url(path, params) ?: return ApiResult.Error("Bad URL: $baseUrl$path")
        return execute(Request.Builder().url(httpUrl).get().build())
    }

    private inline fun <reified T> post(path: String, body: Any): ApiResult<T> {
        val httpUrl = url(path) ?: return ApiResult.Error("Bad URL: $baseUrl$path")
        val jsonBody = gson.toJson(body).toRequestBody(json)
        return execute(Request.Builder().url(httpUrl).post(jsonBody).build())
    }

    private inline fun <reified T> execute(req: Request): ApiResult<T> {
        return try {
            val resp = client.newCall(req).execute()
            val bodyStr = resp.body?.string() ?: ""
            if (!resp.isSuccessful) return ApiResult.Error("HTTP ${resp.code}: $bodyStr", resp.code)
            val type = object : TypeToken<T>() {}.type
            ApiResult.Success(gson.fromJson<T>(bodyStr, type))
        } catch (e: IOException) {
            ApiResult.Error("Network error: ${e.message}")
        } catch (e: Exception) {
            ApiResult.Error("Parse error: ${e.message}")
        }
    }

    // ── Briefings ────────────────────────────────────────────────────────────
    fun getBriefings(): ApiResult<BriefingsListResponse> = get("/api/briefings")

    // ── Pairing — no token needed yet, this call is what obtains one ────────
    /** Redeems a 6-digit one-time code (printed on the PC) for a device token. */
    fun redeemPairCode(lucyServerUrl: String, code: String, label: String): ApiResult<PairRedeemResponse> {
        val host = lucyServerUrl.toHttpUrlOrNull() ?: return ApiResult.Error("Bad URL: $lucyServerUrl")
        val assistantBase = "${host.scheme}://${host.host}:8403"
        val httpUrl = "$assistantBase/api/pair".toHttpUrlOrNull() ?: return ApiResult.Error("Bad URL: $assistantBase/api/pair")
        val payload = mapOf("code" to code, "label" to label)
        val jsonBody = gson.toJson(payload).toRequestBody(json)
        return execute(Request.Builder().url(httpUrl).post(jsonBody).build())
    }
}
