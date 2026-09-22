package com.example.data.repository

import org.json.JSONObject
import kotlin.math.roundToInt

internal data class RemoteTelemetry(val cpu: Int, val ram: Int, val storage: Int) {
    companion object {
        fun parse(json: JSONObject): RemoteTelemetry {
            val cpu = json.getDouble("cpuUsagePercentage")
            val total = json.getDouble("totalMemoryMb")
            val used = json.getDouble("usedMemoryMb")
            require(cpu.isFinite() && cpu in 0.0..100.0 && total.isFinite() && total > 0 && used.isFinite() && used in 0.0..total) { "Invalid telemetry response" }
            val storage = json.optDouble("storageFreeGb", Double.NaN)
            return RemoteTelemetry(cpu.roundToInt(), (used / total * 100).roundToInt(),
                if (storage.isFinite() && storage >= 0) storage.toInt() else -1)
        }
    }
}
