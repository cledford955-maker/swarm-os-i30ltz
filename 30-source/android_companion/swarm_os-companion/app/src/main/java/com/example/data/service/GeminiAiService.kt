package com.example.data.service

import com.example.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class GeminiAiService(private val openRouterManager: OpenRouterManager? = null) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(25, TimeUnit.SECONDS)
        .readTimeout(25, TimeUnit.SECONDS)
        .writeTimeout(25, TimeUnit.SECONDS)
        .build()

    private val systemInstructionText = """
        You are I30LTZ, the repair and recovery assistant inside I30LTZ Companion, paired with I30LTZ Recovery OS.
        Exact spelling is I30LTZ (capital I, digit 3, digit 0, LTZ). Lucille Assistant is a separate SWARM gaming/assistant phone app.
        Help with OS installation, repairs, data recovery and Android development. You give advice, not execution results.
        Never claim to have run commands, scanned malware, established a connection or recovered data without tool evidence.
        Only the supplied telemetry is measured. Ask for actual disk layout, filesystem, mountpoint and boot mode before proposing disk writes.
        Never assume disk letters, NVMe partition numbers, passwords, successful mounts or root access. Prefer read-only diagnosis first.
        SWARM working source is /mnt/Lucy (capital L). lucy-master mirrors are read-only; never instruct writing to them.
        The SWARM desktop uses labwc with Flutter and a Rust panel; LucyServer is being migrated to Go. Check live versions rather than guessing.
        SWARM release ISOs belong only in /mnt/ventoy/ISO/SWARM_OS/: ten rolling builds plus explicitly user-labelled Stable builds.
        For damaged-drive recovery, preserve the source and work from an image on a separate healthy disk; do not format or repair the only copy.
        Keep replies concise and distinguish verified facts from suggestions. No automatic command execution is available through chat.
    """.trimIndent()

    suspend fun getAiResponse(userPrompt: String, systemContext: String, forceOffline: Boolean = false): String = withContext(Dispatchers.IO) {
        if (forceOffline) {
            return@withContext getOfflineFallbackResponse(userPrompt, systemContext)
        }

        // 1. Try OpenRouter if API Key is configured in app
        val openRouterKey = openRouterManager?.getApiKey() ?: ""
        if (openRouterKey.isNotBlank()) {
            val selectedModel = openRouterManager?.getSelectedModel() ?: "deepseek/deepseek-r1"
            val openRouterResponse = callOpenRouterApi(userPrompt, systemContext, openRouterKey, selectedModel)
            if (openRouterResponse != null && openRouterResponse.isNotBlank()) {
                return@withContext openRouterResponse
            }
        }

        // 3. Offline AI Fallback
        return@withContext getOfflineFallbackResponse(userPrompt, systemContext)
    }

    private fun callOpenRouterApi(userPrompt: String, systemContext: String, apiKey: String, model: String): String? {
        return try {
            val jsonBody = JSONObject().apply {
                put("model", model)
                val messagesArray = JSONArray().apply {
                    val sysMsg = JSONObject().apply {
                        put("role", "system")
                        put("content", "$systemInstructionText\n\n[Telemetry Context: $systemContext]")
                    }
                    val userMsg = JSONObject().apply {
                        put("role", "user")
                        put("content", userPrompt)
                    }
                    put(sysMsg)
                    put(userMsg)
                }
                put("messages", messagesArray)
                put("temperature", 0.7)
            }

            val requestBody = jsonBody.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("https://openrouter.ai/api/v1/chat/completions")
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("HTTP-Referer", "https://github.com/aistudio-app")
                .addHeader("X-Title", "I30LTZ Companion")
                .addHeader("Content-Type", "application/json")
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val responseStr = response.body?.string() ?: ""
                val jsonObj = JSONObject(responseStr)
                val choices = jsonObj.optJSONArray("choices")
                if (choices != null && choices.length() > 0) {
                    val firstChoice = choices.getJSONObject(0)
                    val messageObj = firstChoice.optJSONObject("message")
                    val content = messageObj?.optString("content", "")
                    if (!content.isNullOrBlank()) {
                        return content
                    }
                }
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun callGeminiApi(userPrompt: String, systemContext: String, apiKey: String): String? {
        return try {
            val jsonBody = JSONObject().apply {
                val contentsArray = JSONArray().apply {
                    val contentObj = JSONObject().apply {
                        val partsArray = JSONArray().apply {
                            val promptWithContext = "Context: $systemContext\n\nUser Question: $userPrompt"
                            put(JSONObject().put("text", promptWithContext))
                        }
                        put("parts", partsArray)
                    }
                    put(contentObj)
                }
                put("contents", contentsArray)

                val sysInstructionObj = JSONObject().apply {
                    val partsArray = JSONArray().apply {
                        put(JSONObject().put("text", systemInstructionText))
                    }
                    put("parts", partsArray)
                }
                put("systemInstruction", sysInstructionObj)
            }

            val requestBody = jsonBody.toString().toRequestBody("application/json".toMediaType())
            val url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey"

            val request = Request.Builder()
                .url(url)
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val responseStr = response.body?.string() ?: ""
                val jsonObj = JSONObject(responseStr)
                val candidates = jsonObj.optJSONArray("candidates")
                if (candidates != null && candidates.length() > 0) {
                    val firstCandidate = candidates.getJSONObject(0)
                    val content = firstCandidate.optJSONObject("content")
                    val parts = content?.optJSONArray("parts")
                    if (parts != null && parts.length() > 0) {
                        return parts.getJSONObject(0).optString("text", "")
                    }
                }
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun getOfflineFallbackResponse(userPrompt: String, systemContext: String): String =
        "AI service unavailable. Check the provider and connection in AI settings. No diagnostic, repair, or security operation has been performed."
}
