package com.swarm.lucille.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "device_sync")
data class DeviceSyncEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val deviceName: String,
    val deviceType: String, // "Tailscale Node", "PC (Linux/Windows)", "Android Phone"
    val connectionType: String, // "Tailscale Mesh (100.x)", "USB Bridge", "Wi-Fi SSE"
    val ipAddress: String,
    val isConnected: Boolean,
    val lastSyncTime: Long,
    val syncStatus: String, // "Connected & Secure", "Sync Pending", "Disconnected"
    // Telemetry defaults are 0 = "not measured yet", not plausible-looking
    // sample values. Showing 24%/42%/128GB/12ms by default made unpolled
    // devices indistinguishable from devices reporting real data.
    val cpuLoadPercent: Int = -1,
    val ramLoadPercent: Int = -1,
    val storageAvailableGb: Int = -1,
    val pingMs: Int = -1,
    val threatScore: Int = -1,
    val isOptimizing: Boolean = false
)

