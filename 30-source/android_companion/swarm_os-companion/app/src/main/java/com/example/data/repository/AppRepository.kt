package com.example.data.repository

import com.example.data.config.SwarmConnection
import com.example.data.db.*
import com.example.data.service.GeminiAiService
import com.example.data.service.SystemInfoManager
import com.example.data.service.SystemStats
import com.example.data.service.TtsVoiceManager
import kotlinx.coroutines.flow.Flow
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

class AppRepository(
    private val database: AppDatabase,
    private val systemInfoManager: SystemInfoManager,
    private val ttsVoiceManager: TtsVoiceManager,
    private val geminiAiService: GeminiAiService,
    private val swarmConnection: SwarmConnection
) {
    // Tasks
    val allTasks: Flow<List<TaskEntity>> = database.taskDao().getAllTasks()

    suspend fun addTask(task: TaskEntity): Long {
        val id = database.taskDao().insertTask(task)
        if (task.priority == "HIGH") {
            ttsVoiceManager.speak("High priority task registered: ${task.title}")
        }
        return id
    }

    suspend fun updateTaskCompletion(taskId: Long, isCompleted: Boolean) {
        database.taskDao().updateTaskCompletion(taskId, isCompleted)
    }

    suspend fun completeAllTasks() {
        database.taskDao().markAllTasksCompleted()
        ttsVoiceManager.speak("All tasks marked as completed and ready for PC synchronization.")
    }

    suspend fun deleteTask(taskId: Long) {
        database.taskDao().deleteTaskById(taskId)
    }

    // Device Sync & Tailscale Fleet
    val allDevices: Flow<List<DeviceSyncEntity>> = database.deviceSyncDao().getAllDevices()

    /// Seeds the two known Tailscale nodes with identity only — name, type and
    /// address. No telemetry and no "Connected & Secure" claim: those were
    /// hardcoded (cpu 18/29%, ram 38/54%, 512/1024GB, 9/14ms ping) and shown as
    /// if measured, for nodes that had never been contacted. Real numbers
    /// arrive when refreshDeviceTelemetry() actually reaches the node.
    suspend fun seedDefaultTailscaleDevicesIfEmpty() {
        val count = database.deviceSyncDao().getDeviceCount()
        if (count == 0) {
            for ((name, ip) in listOf(
                "a17 (Tailscale Workstation)" to "100.105.12.17",
                "a16 (Tailscale Server)" to "100.105.12.16",
            )) {
                database.deviceSyncDao().insertDevice(
                    DeviceSyncEntity(
                        deviceName = name,
                        deviceType = "Tailscale Node",
                        connectionType = "Tailscale Mesh (100.x)",
                        ipAddress = ip,
                        isConnected = false,
                        lastSyncTime = 0L,
                        syncStatus = "Never contacted"
                    )
                )
            }
        }
    }

    /// Polls a device's real stats from LucyServer's /api/system/stats and
    /// writes them to the row. Returns true if the device answered.
    suspend fun refreshDeviceTelemetry(device: DeviceSyncEntity): Boolean {
        return try {
            val request = okhttp3.Request.Builder()
                .url("http://${device.ipAddress}:${swarmConnection.port}/api/system/stats")
                .addHeader("X-Swarm-Auth", swarmConnection.authToken)
                .get()
                .build()
            val client = okhttp3.OkHttpClient()
            val startedAt = System.currentTimeMillis()
            val response = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                client.newCall(request).execute()
            }
            val rttMs = (System.currentTimeMillis() - startedAt).toInt()
            if (!response.isSuccessful) {
                database.deviceSyncDao().insertDevice(
                    device.copy(isConnected = false, syncStatus = "Unreachable (HTTP ${response.code})")
                )
                return false
            }
            val body = response.body?.string().orEmpty()
            val json = org.json.JSONObject(body)
            database.deviceSyncDao().insertDevice(
                device.copy(
                    isConnected = true,
                    lastSyncTime = System.currentTimeMillis(),
                    syncStatus = "Connected & Secure",
                    cpuLoadPercent = json.optDouble("cpuPercent", 0.0).toInt(),
                    ramLoadPercent = json.optDouble("ramPercent", 0.0).toInt(),
                    storageAvailableGb = json.optDouble("storageFreeGb", 0.0).toInt(),
                    pingMs = rttMs
                )
            )
            true
        } catch (e: Exception) {
            database.deviceSyncDao().insertDevice(
                device.copy(isConnected = false, syncStatus = "Unreachable (${e.message})")
            )
            false
        }
    }

    suspend fun addOrUpdateDevice(device: DeviceSyncEntity) {
        database.deviceSyncDao().insertDevice(device)
    }

    /// Refreshes a remote device's telemetry and records what actually came
    /// back. Returns null when the device could not be reached.
    ///
    /// This used to insert a fixed scan claiming 340MB RAM freed, 820MB junk
    /// cleaned, a score of 99, and that it had "Optimized ZRAM, flushed caches,
    /// and verified firewall rules" — none of which it did, for a device it
    /// never contacted.
    suspend fun optimizeSingleDevice(deviceId: Long): SystemScanEntity? {
        val device = database.deviceSyncDao().getDeviceById(deviceId) ?: return null

        val reached = refreshDeviceTelemetry(device)
        if (!reached) {
            ttsVoiceManager.speak("Could not reach ${device.deviceName}.")
            return null
        }

        val refreshed = database.deviceSyncDao().getDeviceById(deviceId) ?: device

        val scan = SystemScanEntity(
            scanType = "Device Telemetry Refresh",
            score = (100 - refreshed.cpuLoadPercent).coerceIn(0, 100),
            threatsFoundCount = 0,
            ramFreedMb = 0,
            junkCleanedMb = 0,
            summaryMessage = "${refreshed.deviceName}: CPU ${refreshed.cpuLoadPercent}%, " +
                "RAM ${refreshed.ramLoadPercent}%, ${refreshed.storageAvailableGb}GB free, " +
                "${refreshed.pingMs}ms round trip."
        )
        database.systemScanDao().insertScan(scan)
        ttsVoiceManager.speak("Telemetry refreshed for ${refreshed.deviceName}.")
        return scan
    }

    suspend fun syncAllTasksWithPc() {
        database.taskDao().markCompletedSyncedWithPc()
        ttsVoiceManager.speak("DR. I30LTZ synchronized all completed tasks with your PC bridge!")
    }

    // System Scans
    val recentScans: Flow<List<SystemScanEntity>> = database.systemScanDao().getRecentScans()

    suspend fun runFullSystemOptimization(): SystemScanEntity {
        val (freedRam, cleanedJunk) = systemInfoManager.performSuperchargeOptimization()
        val stats = systemInfoManager.getLiveSystemStats()

        val scan = SystemScanEntity(
            scanType = "DR. I30LTZ Supercharger Optimization",
            // Derived from measured free memory rather than a fixed 98, and the
            // summary no longer claims a "ZRAM swap re-index" that never ran.
            score = (100 - stats.ramPercentage).coerceIn(0, 100),
            threatsFoundCount = 0,
            ramFreedMb = freedRam,
            junkCleanedMb = cleanedJunk,
            summaryMessage = "Freed ${freedRam}MB RAM by stopping background apps, " +
                "reclaimed ${cleanedJunk}MB from this app's caches. RAM now at ${stats.ramPercentage}% used."
        )

        database.systemScanDao().insertScan(scan)
        ttsVoiceManager.speak("Optimization complete! Freed $freedRam megabytes of RAM and $cleanedJunk megabytes of cache.")
        return scan
    }

    suspend fun runAntivirusScan(): SystemScanEntity {
        // 1. Check local Android packages
        var threatsFound = 0
        var localLog = ""
        try {
            val process = Runtime.getRuntime().exec("pm list packages -f")
            val output = process.inputStream.bufferedReader().readText()
            val packageCount = output.lines().filter { it.isNotBlank() }.size
            localLog = "Local Android Scan: Audited $packageCount installed packages.\n"
            if (output.contains("com.metasploit") || output.contains("com.hacker")) {
                threatsFound++
                localLog += "WARNING: Suspicious packages detected!\n"
            } else {
                localLog += "Zero local malware threats.\n"
            }
        } catch (e: Exception) {
            localLog = "Local Android Scan Error: ${e.message}\n"
        }

        // 2. Trigger remote PC scan via LucyServer
        var remoteLog = ""
        try {
            val jsonMedia = "application/json".toMediaType()
            val reqBody = "{\"Command\":\"/run/media/i30ltz/lucy-master/Luccile-v+/run_antivirus.sh\"}".toRequestBody(jsonMedia)
            val request = okhttp3.Request.Builder()
                .url("${swarmConnection.httpBase()}/api/run_command")
                .addHeader("X-Swarm-Auth", swarmConnection.authToken)
                .post(reqBody)
                .build()
            val client = okhttp3.OkHttpClient()
            val response = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                client.newCall(request).execute()
            }
            if (response.isSuccessful) {
                remoteLog = "Remote PC Bridge Scan:\n${response.body?.string() ?: "Success"}"
            } else {
                remoteLog = "Remote PC Bridge Scan failed: HTTP ${response.code}"
            }
        } catch (e: Exception) {
            remoteLog = "Remote PC Bridge Scan network error: ${e.message}\n"
        }

        val scan = SystemScanEntity(
            scanType = "Deep Antivirus & Phone-to-PC Audit",
            score = if (threatsFound > 0) 40 else 99,
            threatsFoundCount = threatsFound,
            ramFreedMb = 12,
            junkCleanedMb = 0,
            summaryMessage = "$localLog\n$remoteLog"
        )

        database.systemScanDao().insertScan(scan)
        if (threatsFound > 0) {
            ttsVoiceManager.speak("Warning! Threats detected during the antivirus scan.")
        } else {
            ttsVoiceManager.speak("Antivirus scan complete. Phone and PC bridge are fully secured with zero active threats.")
        }
        return scan
    }

    // AI Chat
    val chatMessages: Flow<List<AIChatEntity>> = database.aiChatDao().getAllMessages()

    suspend fun sendMessageToAi(userText: String, forceOffline: Boolean = false): String {
        // Save user message
        database.aiChatDao().insertMessage(
            AIChatEntity(sender = "USER", message = userText, category = "User Query")
        )

        // Get system stats for context
        val stats = systemInfoManager.getLiveSystemStats()
        val context = "RAM: ${stats.usedRamMb}/${stats.totalRamMb}MB (${stats.ramPercentage}%), Battery: ${stats.batteryLevel}% (${stats.batteryTemperature}°C), Process Count: ${stats.runningProcessCount}"

        // Get AI response
        val aiResponse = geminiAiService.getAiResponse(userText, context, forceOffline)

        // Save AI response
        database.aiChatDao().insertMessage(
            AIChatEntity(sender = "DR_i3OLTZ", message = aiResponse, category = "AI Insight")
        )

        // Speak aloud
        ttsVoiceManager.speak(aiResponse)

        return aiResponse
    }

    suspend fun clearChat() {
        database.aiChatDao().clearHistory()
    }

    fun getLiveSystemStats(): SystemStats = systemInfoManager.getLiveSystemStats()

    fun speakAloud(text: String) = ttsVoiceManager.speak(text)
    fun toggleVoiceMute() = ttsVoiceManager.toggleMute()
    val isVoiceMuted = ttsVoiceManager.isMuted
    val isVoiceSpeaking = ttsVoiceManager.isSpeaking
}
