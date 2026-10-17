package com.swarm.lucille.data.db

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface AIChatDao {
    @Query("SELECT * FROM ai_chat ORDER BY timestamp ASC")
    fun getAllMessages(): Flow<List<AIChatEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMessage(message: AIChatEntity): Long

    @Query("DELETE FROM ai_chat")
    suspend fun clearHistory()
}
