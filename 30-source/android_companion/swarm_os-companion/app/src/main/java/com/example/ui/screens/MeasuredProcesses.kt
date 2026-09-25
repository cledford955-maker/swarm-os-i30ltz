package com.example.ui.screens

import android.app.ActivityManager
import android.content.Context
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import com.example.data.config.SwarmConnection
import com.example.data.db.DeviceSyncEntity
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

internal data class MeasuredProcesses(val entries: List<ProcessEntryAvatar> = emptyList(), val status: String = "Loading processes…")
private val processClient = OkHttpClient.Builder().callTimeout(10, TimeUnit.SECONDS).build()

@Composable
internal fun rememberDeviceProcesses(device: DeviceSyncEntity?): MeasuredProcesses {
    val context = LocalContext.current
    val connection = remember { SwarmConnection(context) }
    val state by produceState(MeasuredProcesses(), device?.id, device?.ipAddress, connection.port) {
        value = MeasuredProcesses()
        while (isActive) {
            value = withContext(Dispatchers.IO) {
                try {
                    val entries = if (device == null) {
                        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        manager.runningAppProcesses.orEmpty().map { process ->
                            val mem = runCatching { manager.getProcessMemoryInfo(intArrayOf(process.pid))[0].totalPss / 1024 }.getOrDefault(-1)
                            ProcessEntryAvatar(process.pid.toString(), process.processName, if (mem > 0) mem else -1, true)
                        }
                    } else {
                        val request = Request.Builder().url("http://${device.ipAddress}:${connection.port}/api/system/processes")
                            .header("X-Swarm-Auth", connection.authToken).build()
                        processClient.newCall(request).execute().use { response ->
                            check(response.isSuccessful) { "HTTP ${response.code}" }
                            val rows = JSONArray(response.body?.string().orEmpty())
                            (0 until rows.length()).map { index ->
                                val row = rows.getJSONObject(index)
                                ProcessEntryAvatar(row.getInt("pid").toString(), row.getString("name"), row.getDouble("memoryUsageMb").toInt(), row.getInt("pid") <= 1)
                            }
                        }
                    }
                    MeasuredProcesses(entries, "${entries.size} measured processes" + if (device == null) " · Android limits visibility and process control" else " · ${device.deviceName}")
                } catch (e: Exception) {
                    if (e is CancellationException) throw e
                    MeasuredProcesses(status = "Processes unavailable: ${e.message}")
                }
            }
            delay(5000)
        }
    }
    return state
}

internal suspend fun terminateMeasuredProcess(context: Context, device: DeviceSyncEntity?, process: ProcessEntryAvatar): String = withContext(Dispatchers.IO) {
    if (device == null) return@withContext "Android does not grant this app control of other processes."
    try {
        val connection = SwarmConnection(context)
        val payload = JSONObject().put("pid", process.pkg.toInt()).toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url("http://${device.ipAddress}:${connection.port}/api/system/process/kill")
            .header("X-Swarm-Auth", connection.authToken).post(payload).build()
        processClient.newCall(request).execute().use { response ->
            check(response.isSuccessful && JSONObject(response.body?.string().orEmpty()).getBoolean("success")) { "Node refused termination" }
        }
        "Node acknowledged termination of ${process.label}; refreshing process list."
    } catch (e: Exception) {
        if (e is CancellationException) throw e
        "Termination failed: ${e.message}"
    }
}
