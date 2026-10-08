package com.swarm.lucille.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val description: String,
    val category: String, // "System", "PC Sync", "Work", "Security", "General"
    val priority: String, // "HIGH", "MEDIUM", "LOW"
    val dueDate: Long,
    val isCompleted: Boolean = false,
    val syncedWithPc: Boolean = false,
    val createdAt: Long = System.currentTimeMillis()
)
