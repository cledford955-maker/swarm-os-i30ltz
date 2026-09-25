package com.example.data.db

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface SystemScanDao {
    @Query("SELECT * FROM system_scans ORDER BY timestamp DESC LIMIT 20")
    fun getRecentScans(): Flow<List<SystemScanEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertScan(scan: SystemScanEntity): Long
}
