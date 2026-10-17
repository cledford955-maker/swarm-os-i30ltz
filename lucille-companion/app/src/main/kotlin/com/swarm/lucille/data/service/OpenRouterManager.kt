package com.swarm.lucille.data.service

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class OpenRouterManager(context: Context) {
    private val prefs: SharedPreferences = com.swarm.lucille.data.config.securePreferences(context, "openrouter_config")

    private val _apiKey = MutableStateFlow(getApiKey())
    val apiKey: StateFlow<String> = _apiKey

    private val _selectedModel = MutableStateFlow(getSelectedModel())
    val selectedModel: StateFlow<String> = _selectedModel

    fun getApiKey(): String = prefs.getString("openrouter_api_key", "") ?: ""

    fun saveApiKey(key: String) {
        val trimmed = key.trim()
        prefs.edit().putString("openrouter_api_key", trimmed).apply()
        _apiKey.value = trimmed
    }

    fun getSelectedModel(): String = prefs.getString("openrouter_model", "deepseek/deepseek-r1") ?: "deepseek/deepseek-r1"

    fun saveSelectedModel(model: String) {
        val trimmed = model.trim()
        prefs.edit().putString("openrouter_model", trimmed).apply()
        _selectedModel.value = trimmed
    }

    fun clearApiKey() {
        prefs.edit().remove("openrouter_api_key").apply()
        _apiKey.value = ""
    }

    companion object {
        val AVAILABLE_MODELS = listOf(
            "deepseek/deepseek-r1" to "DeepSeek R1 (Reasoning Swarm)",
            "deepseek/deepseek-chat" to "DeepSeek V3 (Fast Chat)",
            "moonshotai/kimi-k2" to "Kimi K2 (Moonshot Swarm)",
            "thudm/glm-4" to "GLM 4 (Zhipu AI)",
            "anthropic/claude-3.5-sonnet" to "Claude 3.5 Sonnet",
            "qwen/qwen-2.5-coder-32b-instruct" to "Qwen 2.5 Coder 32B",
            "meta-llama/llama-3.3-70b-instruct" to "Meta Llama 3.3 70B",
            "google/gemini-2.5-flash" to "Google Gemini 2.5 Flash"
        )
    }
}
