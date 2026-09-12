package com.example.data.db

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
    val cpuLoadPercent: Int = 0,
    val ramLoadPercent: Int = 0,
    val storageAvailableGb: Int = 0,
    val pingMs: Int = 0,
    val threatScore: Int = 0,
    val isOptimizing: Boolean = false
)

