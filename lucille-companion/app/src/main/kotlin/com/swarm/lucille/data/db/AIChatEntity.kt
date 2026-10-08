package com.swarm.lucille.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "ai_chat")
data class AIChatEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val sender: String, // "USER" or "DR_i3OLTZ"
    val message: String,
    val category: String = "General" // "Optimization", "Security", "Sync", "Task"
)
