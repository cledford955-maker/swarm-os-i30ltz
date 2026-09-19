package com.example.data.memory

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder

/**
 * The phone's embedded sync endpoint, so phones can gossip with each other
 * when 13E457-THUNDERI30LT is unreachable. Serves only GET/POST /api/memory/sync and
 * /health on [PORT], always behind the SWARM token — the same contract as
 * LucyServer's LAN listener, so the Go CLI can sync with a phone too.
 *
 * A deliberately tiny HTTP/1.1 implementation (one request per connection)
 * instead of a server library: three routes don't justify a dependency.
 */
class MemorySyncServer(
    private val scope: CoroutineScope,
    private val dao: MemoryDao,
    private val deviceId: () -> String,
    private val token: () -> String,
    private val onIngested: (Int) -> Unit
) {
    private var socket: ServerSocket? = null
    private var job: Job? = null

    val isRunning: Boolean get() = socket?.isClosed == false

    fun start() {
        if (isRunning) return
        val server = try {
            ServerSocket(PORT)
        } catch (e: Exception) {
            Log.w(TAG, "sync server could not bind :$PORT", e)
            return
        }
        socket = server
        job = scope.launch(Dispatchers.IO) {
            while (isActive && !server.isClosed) {
                val client = try { server.accept() } catch (e: Exception) { break }
                launch { handle(client) }
            }
        }
    }

    fun stop() {
        runCatching { socket?.close() }
        job?.cancel()
        socket = null
    }

    private suspend fun handle(client: Socket) {
        client.use { s ->
            s.soTimeout = 15_000
            val input = BufferedInputStream(s.getInputStream())
            val (status, body) = try {
                route(input)
            } catch (e: Exception) {
                400 to JSONObject().put("error", e.message ?: "bad request")
            }
            val bytes = body.toString().toByteArray()
            val out = s.getOutputStream()
            out.write(
                ("HTTP/1.1 $status ${reason(status)}\r\nContent-Type: application/json\r\n" +
                    "Content-Length: ${bytes.size}\r\nConnection: close\r\n\r\n").toByteArray()
            )
            out.write(bytes)
            out.flush()
        }
    }

    private suspend fun route(input: InputStream): Pair<Int, JSONObject> {
        val requestLine = readLine(input) ?: return 400 to err("empty request")
        val parts = requestLine.split(" ")
        if (parts.size < 2) return 400 to err("bad request line")
        val method = parts[0]
        val target = parts[1]
        val headers = mutableMapOf<String, String>()
        while (true) {
            val line = readLine(input) ?: break
            if (line.isEmpty()) break
            val i = line.indexOf(':')
            if (i > 0) headers[line.substring(0, i).trim().lowercase()] = line.substring(i + 1).trim()
        }
        if (headers.containsKey("origin")) return 403 to err("browser access is not allowed on the sync port")
        val given = headers["x-swarm-auth"] ?: headers["authorization"]?.removePrefix("Bearer ")
        if (given != token()) return 401 to err("missing or invalid X-Swarm-Auth token")

        val path = target.substringBefore('?')
        val query = target.substringAfter('?', "").split('&').filter { it.contains('=') }
            .associate { URLDecoder.decode(it.substringBefore('='), "UTF-8") to URLDecoder.decode(it.substringAfter('='), "UTF-8") }

        return when {
            path == "/health" -> 200 to JSONObject().put("status", "ok").put("device", deviceId())
            path == SYNC_PATH && method == "GET" -> pull(query["cursor"].orEmpty())
            path == SYNC_PATH && method == "POST" -> {
                val len = headers["content-length"]?.toIntOrNull() ?: return 411 to err("Content-Length required")
                if (len > MAX_BODY) return 413 to err("push too large; send smaller batches")
                push(String(readExactly(input, len)))
            }
            else -> 404 to err("not found")
        }
    }

    /** Cursor is this phone's seq as a decimal string (opaque to peers). */
    private suspend fun pull(cursor: String): Pair<Int, JSONObject> {
        val after = if (cursor.isEmpty()) 0L else cursor.toLongOrNull() ?: return 400 to err("cursor is not one this phone issued; pull again with an empty cursor")
        val rows = dao.since(after, PAGE)
        val next = rows.lastOrNull()?.seq ?: maxOf(after, 0L)
        val arr = JSONArray()
        rows.sortedBy { it.ts }.forEach { arr.put(it.toJson()) }
        // A full page means more remains; the peer pulls again with the new cursor.
        return 200 to JSONObject().put("device", deviceId()).put("entries", arr).put("cursor", next.toString())
            .put("more", rows.size == PAGE)
    }

    private suspend fun push(body: String): Pair<Int, JSONObject> {
        val arr = JSONObject(body).optJSONArray("entries") ?: return 400 to err("body must be {\"entries\": [...]}")
        val entries = (0 until arr.length()).map {
            MemoryEntryEntity.fromJson(arr.getJSONObject(it)) ?: return 400 to err("entry $it is invalid")
        }
        val accepted = dao.insertAll(entries).count { it != -1L }
        if (accepted > 0) onIngested(accepted)
        return 200 to JSONObject().put("accepted", accepted)
    }

    private fun readLine(input: InputStream): String? {
        val buf = ByteArrayOutputStream()
        while (true) {
            val b = input.read()
            if (b == -1) return if (buf.size() == 0) null else buf.toString("UTF-8")
            if (b == '\n'.code) return buf.toString("UTF-8").trimEnd('\r')
            if (buf.size() > 8192) throw IllegalArgumentException("header line too long")
            buf.write(b)
        }
    }

    private fun readExactly(input: InputStream, len: Int): ByteArray {
        val data = ByteArray(len)
        var read = 0
        while (read < len) {
            val n = input.read(data, read, len - read)
            if (n < 0) throw IllegalArgumentException("body shorter than Content-Length")
            read += n
        }
        return data
    }

    private fun err(msg: String) = JSONObject().put("error", msg)

    private fun reason(code: Int) = when (code) {
        200 -> "OK"; 400 -> "Bad Request"; 401 -> "Unauthorized"; 403 -> "Forbidden"
        404 -> "Not Found"; 411 -> "Length Required"; 413 -> "Payload Too Large"; else -> "Error"
    }

    companion object {
        const val PORT = 8402
        const val SYNC_PATH = "/api/memory/sync"
        private const val PAGE = 500
        private const val MAX_BODY = 64 * 1024 * 1024
        private const val TAG = "MemorySyncServer"
    }
}
