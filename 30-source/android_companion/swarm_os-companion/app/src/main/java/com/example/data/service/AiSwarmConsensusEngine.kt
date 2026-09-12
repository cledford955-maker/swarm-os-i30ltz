package com.example.data.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * AiSwarmConsensusEngine coordinates real parallel inference across the AI Swarm:
 * - Kimi Specialist (Moonshot AI - moonshotai/kimi-k2)
 * - Qwen Coder (Alibaba - qwen/qwen-2.5-coder-32b-instruct)
 * - GLM-4 Tactical (THUDM - thudm/glm-4)
 * - DeepSeek R1 (DeepSeek - deepseek/deepseek-r1)
 * - Local Offline GGUF Swarm (On-device fallback)
 */
class AiSwarmConsensusEngine(
    private val openRouterManager: OpenRouterManager,
    private val localLlamaEngine: LocalLlamaEngine
) {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(20, TimeUnit.SECONDS)
        .build()

    data class SwarmAgentResult(
        val agentName: String,
        val modelId: String,
        val output: String,
        val isLocal: Boolean = false
    )

    suspend fun executeSwarmConsensus(
        prompt: String,
        systemContext: String,
        isOfflineMode: Boolean = false
    ): String = coroutineScope {
        val apiKey = openRouterManager.getApiKey()
        if (isOfflineMode || apiKey.isBlank()) {
            val localResult = localLlamaEngine.generateLocalResponse(prompt, systemContext)
            return@coroutineScope "⚡ [SWARM LOCAL OFFLINE AGENT - ${localLlamaEngine.getModelName()}]:\n$localResult"
        }

        val models = listOf(
            "Kimi Specialist" to "moonshotai/kimi-k2",
            "Qwen Coder" to "qwen/qwen-2.5-coder-32b-instruct",
            "GLM-4 Tactical" to "thudm/glm-4",
            "DeepSeek R1" to "deepseek/deepseek-r1"
        )

        val swarmTasks = models.map { (name, modelId) ->
            async(Dispatchers.IO) {
                val response = callOpenRouterModel(prompt, systemContext, apiKey, modelId)
                    ?: "Agent inference timeout / fallback."
                SwarmAgentResult(name, modelId, response)
            }
        }

        val results = swarmTasks.awaitAll()

        val synthesis = StringBuilder().apply {
            append("⚡ [LUCILLE CORE • REAL-TIME AI SWARM CONSENSUS]\n")
            append("========================================================================\n")
            results.forEach { res ->
                append("🔹 ${res.agentName.uppercase()} [${res.modelId}]:\n")
                append("${res.output.trim()}\n\n")
            }
            append("========================================================================\n")
            append("👑 [LUCILLE MASTER SYNTHESIS]: Parallel multi-agent inference completed across ${results.size} swarm models under telemetry context: $systemContext.")
        }.toString()

        return@coroutineScope synthesis
    }

    private fun callOpenRouterModel(
        prompt: String,
        systemContext: String,
        apiKey: String,
        modelId: String
    ): String? {
        return try {
            val jsonBody = JSONObject().apply {
                put("model", modelId)
                val messagesArray = JSONArray().apply {
                    val sysMsg = JSONObject().apply {
                        put("role", "system")
                        put("content", "You are an autonomous AI swarm agent operating within SWARM_OS. Provide concise, expert, actionable insights.\n[System Telemetry: $systemContext]")
                    }
                    val userMsg = JSONObject().apply {
                        put("role", "user")
                        put("content", prompt)
                    }
                    put(sysMsg)
                    put(userMsg)
                }
                put("messages", messagesArray)
                put("temperature", 0.6)
                put("max_tokens", 500)
            }

            val requestBody = jsonBody.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("https://openrouter.ai/api/v1/chat/completions")
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("HTTP-Referer", "https://github.com/i30ltz/swarm-os")
                .addHeader("X-Title", "SWARM_OS Companion")
                .addHeader("Content-Type", "application/json")
                .post(requestBody)
                .build()

            val response = httpClient.newCall(request).execute()
            if (response.isSuccessful) {
                val responseStr = response.body?.string() ?: ""
                val jsonObj = JSONObject(responseStr)
                val choices = jsonObj.optJSONArray("choices")
                if (choices != null && choices.length() > 0) {
                    val firstChoice = choices.getJSONObject(0)
                    val messageObj = firstChoice.optJSONObject("message")
                    return messageObj?.optString("content", "")?.trim()
                }
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
