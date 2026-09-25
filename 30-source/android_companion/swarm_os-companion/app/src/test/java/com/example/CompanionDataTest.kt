package com.example

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.example.data.db.AppDatabase
import com.example.data.memory.MemoryEntryEntity
import com.example.data.repository.RemoteTelemetry
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class CompanionDataTest {
    @Test fun telemetryUsesServerContractAndDoesNotInventStorage() {
        val result = RemoteTelemetry.parse(JSONObject("""{"cpuUsagePercentage":12.5,"totalMemoryMb":8000,"usedMemoryMb":2000}"""))
        assertEquals(13, result.cpu); assertEquals(25, result.ram); assertEquals(-1, result.storage)
        assertTrue(runCatching { RemoteTelemetry.parse(JSONObject("{}")) }.isFailure)
        assertTrue(runCatching { RemoteTelemetry.parse(JSONObject("""{"cpuUsagePercentage":0,"totalMemoryMb":0,"usedMemoryMb":0}""")) }.isFailure)
    }
    @Test fun currentMemorySuppressesSupersededValuesAndTombstones() = runBlocking {
        val db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext<Context>(), AppDatabase::class.java).build()
        try {
            val old = MemoryEntryEntity.create("test", "chatgpt_memory", "preference", "old").copy(ts="2026-09-20T00:00:00Z")
            val fresh = old.copy(id="new-entry-123", ts="2026-09-21T00:00:00Z", content="current")
            db.memoryDao().insertAll(listOf(old,fresh))
            assertEquals(listOf("current"), db.memoryDao().observe("", "", 300).first().map { it.content })
            db.memoryDao().insertAll(listOf(fresh.copy(id="deleted-entry-123", ts="2026-09-22T00:00:00Z", deleted=true)))
            assertTrue(db.memoryDao().observe("", "", 300).first().isEmpty())
        } finally { db.close() }
    }
}
