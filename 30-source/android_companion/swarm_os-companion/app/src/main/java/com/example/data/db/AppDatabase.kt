package com.example.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.Room.databaseBuilder
import androidx.room.RoomDatabase

@Database(
    entities = [
        TaskEntity::class,
        DeviceSyncEntity::class,
        SystemScanEntity::class,
        AIChatEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun deviceSyncDao(): DeviceSyncDao
    abstract fun systemScanDao(): SystemScanDao
    abstract fun aiChatDao(): AIChatDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = databaseBuilder(context.applicationContext, AppDatabase::class.java, "dr_boltz_db")
                .fallbackToDestructiveMigration(dropAllTables = true)
                .build()
                INSTANCE = instance
                instance 
            }
        }
    }
}
