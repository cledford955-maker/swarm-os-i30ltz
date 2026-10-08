package com.swarm.lucille.data.service

/** No native inference runtime or GGUF weights ship in this APK. Never invent model output. */
class LocalLlamaEngine {
    suspend fun initializeModel(modelName: String = "", nCtx: Int = 2048): Boolean = false
    suspend fun generateLocalResponse(prompt: String, systemContext: String): String =
        "Offline AI is unavailable: this app has no installed inference runtime or model. No command has been run. Connect a configured AI provider, or use the saved recovery reference."
    fun isLoaded() = false
    fun getModelName() = "Not installed"
    fun getContextTokens() = 0
}
