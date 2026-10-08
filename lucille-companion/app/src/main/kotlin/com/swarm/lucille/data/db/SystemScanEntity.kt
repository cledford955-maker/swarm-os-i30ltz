package com.swarm.lucille.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "system_scans")
data class SystemScanEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val scanType: String, // "Full Security & Virus Scan", "RAM & Process Optimizer", "USB/Wi-Fi Tunnel Audit"
    val score: Int, // 0 - 100
    val threatsFoundCount: Int,
    val ramFreedMb: Long,
    val junkCleanedMb: Long,
    val summaryMessage: String
)
