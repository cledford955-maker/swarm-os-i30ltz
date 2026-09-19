package com.example.data.memory

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.ArrayDeque

/**
 * LAN fallback discovery (spec §3.2): every phone advertises
 * `_swarmcompanion._tcp` and browses for the others. 13E457-THUNDERI30LT
 * advertises the same type through avahi (/etc/avahi/services/swarm-memory.service), so a
 * phone finds it on home Wi-Fi even with Tailscale down.
 */
class MemoryPeerDiscovery(context: Context, private val serviceName: () -> String) {
    private val nsd = context.applicationContext.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private var multicastLock: WifiManager.MulticastLock? = null

    private val _peers = MutableStateFlow<Map<String, String>>(emptyMap()) // service name -> base URL
    val peers: StateFlow<Map<String, String>> = _peers.asStateFlow()

    private var registration: NsdManager.RegistrationListener? = null
    private var discovery: NsdManager.DiscoveryListener? = null

    // NsdManager.resolveService handles one request at a time on older APIs.
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false

    fun start() {
        if (discovery != null) return
        multicastLock = wifi.createMulticastLock("swarm-memory").apply {
            setReferenceCounted(false)
            runCatching { acquire() }
        }
        register()
        browse()
    }

    fun stop() {
        registration?.let { runCatching { nsd.unregisterService(it) } }
        discovery?.let { runCatching { nsd.stopServiceDiscovery(it) } }
        registration = null
        discovery = null
        runCatching { multicastLock?.release() }
        _peers.value = emptyMap()
    }

    private fun register() {
        val info = NsdServiceInfo().apply {
            serviceName = this@MemoryPeerDiscovery.serviceName()
            serviceType = SERVICE_TYPE
            port = MemorySyncServer.PORT
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) {}
            override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) { Log.w(TAG, "register failed: $code") }
            override fun onServiceUnregistered(info: NsdServiceInfo) {}
            override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) {}
        }
        registration = listener
        runCatching { nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener) }
    }

    private fun browse() {
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(type: String) {}
            override fun onDiscoveryStopped(type: String) {}
            override fun onStartDiscoveryFailed(type: String, code: Int) { Log.w(TAG, "discovery failed: $code") }
            override fun onStopDiscoveryFailed(type: String, code: Int) {}
            override fun onServiceFound(info: NsdServiceInfo) {
                if (info.serviceName == serviceName()) return // ourselves
                enqueueResolve(info)
            }
            override fun onServiceLost(info: NsdServiceInfo) {
                _peers.value = _peers.value - info.serviceName
            }
        }
        discovery = listener
        runCatching { nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener) }
    }

    @Synchronized
    private fun enqueueResolve(info: NsdServiceInfo) {
        resolveQueue.add(info)
        if (!resolving) resolveNext()
    }

    @Synchronized
    private fun resolveNext() {
        val next = resolveQueue.poll()
        if (next == null) {
            resolving = false
            return
        }
        resolving = true
        @Suppress("DEPRECATION")
        nsd.resolveService(next, object : NsdManager.ResolveListener {
            override fun onResolveFailed(info: NsdServiceInfo, code: Int) { resolveNext() }
            override fun onServiceResolved(info: NsdServiceInfo) {
                @Suppress("DEPRECATION")
                val host = info.host?.hostAddress
                if (host != null) {
                    val h = if (host.contains(':')) "[${host.substringBefore('%')}]" else host
                    _peers.value = _peers.value + (info.serviceName to "http://$h:${info.port}")
                }
                resolveNext()
            }
        })
    }

    companion object {
        const val SERVICE_TYPE = "_swarmcompanion._tcp."
        private const val TAG = "MemoryPeerDiscovery"
    }
}
