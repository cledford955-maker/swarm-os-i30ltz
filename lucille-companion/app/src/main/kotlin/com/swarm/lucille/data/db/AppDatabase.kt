package com.swarm.lucille.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.Room.databaseBuilder
import androidx.room.RoomDatabase
import com.swarm.lucille.data.memory.MemoryDao
import com.swarm.lucille.data.memory.MemoryEntryEntity

@Database(
    entities = [
        TaskEntity::class,
        DeviceSyncEntity::class,
        SystemScanEntity::class,
        AIChatEntity::class,
        MemoryEntryEntity::class
    ],
    version = 2,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun deviceSyncDao(): DeviceSyncDao
    abstract fun systemScanDao(): SystemScanDao
    abstract fun aiChatDao(): AIChatDao
    abstract fun memoryDao(): MemoryDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = databaseBuilder(context.applicationContext, AppDatabase::class.java, "dr_boltz_db")
                // Explicit migration first: shared memory must never be wiped by a schema bump.
                .addMigrations(MemoryEntryEntity.MIGRATION_1_2)
                .fallbackToDestructiveMigration()
                .build()
                INSTANCE = instance
                instance 
            }
        }
    }
}
