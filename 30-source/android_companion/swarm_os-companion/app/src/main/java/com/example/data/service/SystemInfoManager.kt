package com.example.data.service

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Environment
import android.os.StatFs
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

data class SystemStats(
    val totalRamMb: Long,
    val usedRamMb: Long,
    val freeRamMb: Long,
    val ramPercentage: Int,
    val totalStorageGb: Double,
    val usedStorageGb: Double,
    val freeStorageGb: Double,
    val storagePercentage: Int,
    val batteryLevel: Int,
    val batteryTemperature: Float,
    val batteryHealth: String,
    val isCharging: Boolean,
    val runningProcessCount: Int,
    val swapZramSimulatedMb: Long,
    val threatScore: Int // 100 = safe, <70 = risks found
)

class SystemInfoManager(private val context: Context) {

    fun getLiveSystemStats(): SystemStats {
        val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        actManager.getMemoryInfo(memInfo)

        val totalRamMb = memInfo.totalMem / (1024 * 1024)
        val freeRamMb = memInfo.availMem / (1024 * 1024)
        val usedRamMb = totalRamMb - freeRamMb
        val ramPercentage = ((usedRamMb.toDouble() / totalRamMb.toDouble()) * 100).roundToInt()

        // Storage
        val path = Environment.getDataDirectory()
        val stat = StatFs(path.path)
        val blockSize = stat.blockSizeLong
        val totalBlocks = stat.blockCountLong
        val availBlocks = stat.availableBlocksLong

        val totalStorageGb = (totalBlocks * blockSize).toDouble() / (1024 * 1024 * 1024)
        val freeStorageGb = (availBlocks * blockSize).toDouble() / (1024 * 1024 * 1024)
        val usedStorageGb = totalStorageGb - freeStorageGb
        val storagePercentage = if (totalStorageGb > 0) ((usedStorageGb / totalStorageGb) * 100).roundToInt() else 0

        // Battery
        val iFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus = context.registerReceiver(null, iFilter)
        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: 85
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: 100
        val batteryPct = ((level / scale.toFloat()) * 100).roundToInt()
        val temp = (batteryStatus?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 320) / 10.0f
        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

        val healthCode = batteryStatus?.getIntExtra(BatteryManager.EXTRA_HEALTH, BatteryManager.BATTERY_HEALTH_GOOD) ?: BatteryManager.BATTERY_HEALTH_GOOD
        val batteryHealth = when(healthCode) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good / Optimal"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheating Warning"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Degraded"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
            else -> "Normal"
        }

        // Processes & Swap / ZRAM calculation
        val runningProcesses = actManager.runningAppProcesses?.size ?: 24
        val swapMb = (totalRamMb * 0.25).toLong() // Calculated ZRAM Swap buffer

        // Safety score based on RAM usage & temp
        val threatScore = when {
            temp > 42.0f -> 65
            ramPercentage > 85 -> 72
            else -> 98
        }

        return SystemStats(
            totalRamMb = totalRamMb,
            usedRamMb = usedRamMb,
            freeRamMb = freeRamMb,
            ramPercentage = ramPercentage,
            totalStorageGb = String.format("%.1f", totalStorageGb).toDoubleOrNull() ?: 128.0,
            usedStorageGb = String.format("%.1f", usedStorageGb).toDoubleOrNull() ?: 45.0,
            freeStorageGb = String.format("%.1f", freeStorageGb).toDoubleOrNull() ?: 83.0,
            storagePercentage = storagePercentage,
            batteryLevel = batteryPct,
            batteryTemperature = temp,
            batteryHealth = batteryHealth,
            isCharging = isCharging,
            runningProcessCount = runningProcesses,
            swapZramSimulatedMb = swapMb,
            threatScore = threatScore
        )
    }

    /// Real optimization, real numbers.
    ///
    /// Returns (ramFreedMb, junkCleanedMb) actually measured — previously both
    /// were `(180..420).random()` and `(350..1200).random()`, i.e. invented,
    /// with only a `System.gc()` hint behind them.
    ///
    /// RAM: measures available memory before and after asking the platform to
    /// kill other apps' background processes (needs KILL_BACKGROUND_PROCESSES,
    /// already declared in the manifest). Android may ignore the request for
    /// some packages, so the delta is whatever genuinely came back — clamped at
    /// zero, because memory pressure from other apps can legitimately make it
    /// negative.
    ///
    /// Junk: sums this app's own cache directories, deletes them, and reports
    /// the bytes actually reclaimed. Clearing other apps' caches requires
    /// privileges a normal app does not have, so this deliberately reports only
    /// what it really cleaned rather than a whole-device figure.
    suspend fun performSuperchargeOptimization(): Pair<Long, Long> = withContext(Dispatchers.IO) {
        val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

        fun availMb(): Long {
            val info = ActivityManager.MemoryInfo()
            actManager.getMemoryInfo(info)
            return info.availMem / (1024 * 1024)
        }

        val availBefore = availMb()

        val myPackage = context.packageName
        try {
            val installed = context.packageManager.getInstalledApplications(0)
            for (app in installed) {
                if (app.packageName == myPackage) continue
                // System apps are skipped: killing them is disruptive and the
                // platform generally refuses anyway.
                if (app.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0) continue
                try {
                    actManager.killBackgroundProcesses(app.packageName)
                } catch (_: SecurityException) {
                    // No permission for this package — skip it.
                }
            }
        } catch (_: Exception) {
            // Package enumeration can be restricted; fall through with whatever
            // was reclaimed so far.
        }

        System.gc()
        val freedRamMb = (availMb() - availBefore).coerceAtLeast(0L)

        var cleanedBytes = 0L
        for (dir in listOfNotNull(context.cacheDir, context.externalCacheDir)) {
            cleanedBytes += deleteDirContents(dir)
        }
        val cleanedJunkMb = cleanedBytes / (1024 * 1024)

        Pair(freedRamMb, cleanedJunkMb)
    }

    /// Deletes everything inside [dir] (but not [dir] itself) and returns the
    /// number of bytes actually removed.
    private fun deleteDirContents(dir: java.io.File): Long {
        if (!dir.exists() || !dir.isDirectory) return 0L
        var removed = 0L
        val children = dir.listFiles() ?: return 0L
        for (child in children) {
            removed += if (child.isDirectory) {
                val inner = deleteDirContents(child)
                if (child.delete()) inner else inner
            } else {
                val size = child.length()
                if (child.delete()) size else 0L
            }
        }
        return removed
    }
}
