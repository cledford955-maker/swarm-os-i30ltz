package com.example.data.db

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface DeviceSyncDao {
    @Query("SELECT * FROM device_sync ORDER BY isConnected DESC, lastSyncTime DESC")
    fun getAllDevices(): Flow<List<DeviceSyncEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDevice(device: DeviceSyncEntity): Long

    @Update
    suspend fun updateDevice(device: DeviceSyncEntity)

    @Query("SELECT * FROM device_sync WHERE id = :id LIMIT 1")
    suspend fun getDeviceById(id: Long): DeviceSyncEntity?

    @Query("SELECT COUNT(*) FROM device_sync")
    suspend fun getDeviceCount(): Int

    @Query("UPDATE device_sync SET isConnected = :connected, lastSyncTime = :timestamp, syncStatus = :status WHERE id = :id")
    suspend fun updateConnectionStatus(id: Long, connected: Boolean, timestamp: Long, status: String)
}
