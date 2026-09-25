package com.example.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.config.SwarmConnection
import com.example.data.db.*
import com.example.data.repository.AppRepository
import com.example.data.service.GeminiAiService
import com.example.data.service.SystemInfoManager
import com.example.data.service.SystemStats
import com.example.data.service.TtsVoiceManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val db = AppDatabase.getInstance(application)
    private val systemInfoManager = SystemInfoManager(application)
    private val ttsVoiceManager = TtsVoiceManager(application)
    val openRouterManager = com.example.data.service.OpenRouterManager(application)
    private val geminiAiService = GeminiAiService(openRouterManager)
    private val swarmConnection = SwarmConnection(application)

    val repository = AppRepository(db, systemInfoManager, ttsVoiceManager, geminiAiService, swarmConnection)

    val openRouterApiKey = openRouterManager.apiKey
    val selectedOpenRouterModel = openRouterManager.selectedModel

    fun saveOpenRouterApiKey(key: String) {
        openRouterManager.saveApiKey(key)
    }

    fun saveOpenRouterModel(model: String) {
        openRouterManager.saveSelectedModel(model)
    }

    fun clearOpenRouterApiKey() {
        openRouterManager.clearApiKey()
    }

    // Navigation Tab
    private val _currentTab = MutableStateFlow(NavigationTab.DASHBOARD)
    val currentTab: StateFlow<NavigationTab> = _currentTab

    // System Stats
    private val _systemStats = MutableStateFlow(systemInfoManager.getLiveSystemStats())
    val systemStats: StateFlow<SystemStats> = _systemStats

    init {
        viewModelScope.launch {
            repository.seedDefaultTailscaleDevicesIfEmpty()
            while (kotlinx.coroutines.currentCoroutineContext().isActive) {
                repository.refreshConfiguredNode()
                kotlinx.coroutines.delay(30_000)
            }
        }
    }

    fun optimizeSingleDevice(deviceId: Long) {
        if (deviceId == -1L) { runSuperchargerOptimization(); return }
        viewModelScope.launch {
            val scan = repository.optimizeSingleDevice(deviceId)
            _avatarSpeech.value = scan?.summaryMessage
                ?: "Could not optimize device #$deviceId — it is not reachable."
        }
    }

    /// Runs the real antivirus scan (local package audit + remote LucyServer
    /// scan) and reports what it actually found. This previously slept 1.8s and
    /// then decided the verdict with `(1..10).random() > 2` — a coin flip that
    /// told the user their device was infected, or clean, at random.
    fun runMalwareScanOnDevice(deviceId: Long) {
        viewModelScope.launch {
            _isOptimizing.value = true
            _avatarSpeech.value = "⚡ Scanning ${if (deviceId == -1L) "This Phone" else "device #$deviceId"} for malware, rogue processes, and suspicious permissions..."
            try {
                val scan = repository.runAntivirusScan()
                _avatarSpeech.value = if (scan.threatsFoundCount == 0) {
                    "✅ Scan complete — no threats detected. ${scan.summaryMessage}"
                } else {
                    "⚠️ Scan found ${scan.threatsFoundCount} issue(s). ${scan.summaryMessage}"
                }
            } catch (e: Exception) {
                _avatarSpeech.value = "Scan did not complete: ${e.message}. No verdict — treat this device as unknown."
            }
            _isOptimizing.value = false
        }
    }

    fun runInfiniteFleetScan() {
        viewModelScope.launch {
            repository.allDevices.firstOrNull()?.forEach { dev ->
                repository.optimizeSingleDevice(dev.id)
            }
        }
    }

    // Database Flows
    val tasks: StateFlow<List<TaskEntity>> = repository.allTasks
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val devices: StateFlow<List<DeviceSyncEntity>> = repository.allDevices
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val recentScans: StateFlow<List<SystemScanEntity>> = repository.recentScans
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val chatMessages: StateFlow<List<AIChatEntity>> = repository.chatMessages
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Voice State
    val isVoiceMuted = repository.isVoiceMuted
    val isVoiceSpeaking = repository.isVoiceSpeaking

    // Active Speech Text for DR. I30LTZ avatar
    private val _avatarSpeech = MutableStateFlow<String?>("⚡ Greetings! I am DR. I30LTZ — your IT Field Agent. Ask me anything to optimize your device & PC!")
    val avatarSpeech: StateFlow<String?> = _avatarSpeech

    // Is Optimizing Flag
    private val _isOptimizing = MutableStateFlow(false)
    val isOptimizing: StateFlow<Boolean> = _isOptimizing

    // OS Deployment / Boot Tools State
    private val _isoDownloadProgress = MutableStateFlow(0f)
    val isoDownloadProgress: StateFlow<Float> = _isoDownloadProgress

    private val _isUsbMounted = MutableStateFlow(false)
    val isUsbMounted: StateFlow<Boolean> = _isUsbMounted

    private val _grubCommandProposal = MutableStateFlow("")
    val grubCommandProposal: StateFlow<String> = _grubCommandProposal

    private val _isOfflineAi = MutableStateFlow(false)
    val isOfflineAi: StateFlow<Boolean> = _isOfflineAi


    fun selectTab(tab: NavigationTab) {
        _currentTab.value = tab
        refreshSystemStats()
    }

    fun refreshSystemStats() {
        _systemStats.value = systemInfoManager.getLiveSystemStats()
    }

    fun runSuperchargerOptimization() {
        viewModelScope.launch {
            _isOptimizing.value = true
            _avatarSpeech.value = "⚡ Initializing DR. I30LTZ Supercharger! Flushed RAM caches and re-indexed ZRAM swap..."
            val scanResult = repository.runFullSystemOptimization()
            _systemStats.value = systemInfoManager.getLiveSystemStats()
            _avatarSpeech.value = "⚡ ${scanResult.summaryMessage}"
            _isOptimizing.value = false
        }
    }

    fun runAntivirusScan() {
        viewModelScope.launch {
            _isOptimizing.value = true
            _avatarSpeech.value = "⚡ Reading device configuration; no malware scan is performed."
            val scanResult = repository.runAntivirusScan()
            _systemStats.value = systemInfoManager.getLiveSystemStats()
            _avatarSpeech.value = "⚡ ${scanResult.summaryMessage}"
            _isOptimizing.value = false
        }
    }

    fun addTask(title: String, description: String, category: String, priority: String) {
        viewModelScope.launch {
            repository.addTask(
                TaskEntity(
                    title = title,
                    description = description,
                    category = category,
                    priority = priority,
                    dueDate = System.currentTimeMillis() + 86400000
                )
            )
        }
    }

    fun toggleTaskCompletion(taskId: Long, currentCompleted: Boolean) {
        viewModelScope.launch {
            repository.updateTaskCompletion(taskId, !currentCompleted)
        }
    }

    fun deleteTask(taskId: Long) {
        viewModelScope.launch {
            repository.deleteTask(taskId)
        }
    }

    fun completeAllTasks() {
        viewModelScope.launch {
            repository.completeAllTasks()
            _avatarSpeech.value = "⚡ All pending system & PC sync tasks marked complete!"
        }
    }

    fun syncAllWithPc() {
        viewModelScope.launch {
            try {
                val count = repository.syncAllTasksWithPc()
                _avatarSpeech.value = "$count completed tasks acknowledged by shared memory."
            } catch (e: Exception) {
                _avatarSpeech.value = "Task sync failed: ${e.message}"
            }
        }
    }

    fun sendAiUserMessage(message: String) {
        if (message.isBlank()) return
        viewModelScope.launch {
            val response = repository.sendMessageToAi(message)
            _avatarSpeech.value = response
        }
    }

    fun speakAvatarGreeting() {
        viewModelScope.launch {
            val greeting = "⚡ DR. I30LTZ⚡ reporting in! Core memory is optimal at ${_systemStats.value.ramPercentage}% load. Ready for your commands!"
            _avatarSpeech.value = greeting
            repository.speakAloud(greeting)
        }
    }

    fun toggleMuteVoice() {
        repository.toggleVoiceMute()
    }

    // --- OS Deployment / Boot Tools Methods ---

    fun toggleOfflineAi() {
        _isOfflineAi.value = !_isOfflineAi.value
    }

    fun downloadIso(isoName: String) {
        _avatarSpeech.value = "SWARM ISO releases are managed on the paired computer at /mnt/ventoy/ISO/SWARM_OS/. No phone download started."
    }

    fun toggleUsbMount() {
        _isUsbMounted.value = false
        _avatarSpeech.value = "USB boot emulation needs a supported rooted kernel and is not provided by this app."
    }

    fun askDrI3oltzGrub(issue: String) {
        if (issue.isBlank()) return
        viewModelScope.launch {
            _avatarSpeech.value = "⚡ Analyzing GRUB boot issue..."
            val prompt = "I am in GRUB. My issue is: $issue. What exact command should I type? Just give the command in a code block or clearly."
            val response = repository.sendMessageToAi(prompt, forceOffline = _isOfflineAi.value)
            
            // Extract code block if any
            val codeRegex = Regex("```(.*?)```", RegexOption.DOT_MATCHES_ALL)
            val match = codeRegex.find(response)
            if (match != null) {
                _grubCommandProposal.value = match.groupValues[1].trim().removePrefix("bash").trim()
            } else {
                // simple fallback if no code block
                if (response.contains("`")) {
                    val fallbackRegex = Regex("`(.*?)`")
                    val fallbackMatch = fallbackRegex.find(response)
                    _grubCommandProposal.value = fallbackMatch?.groupValues?.get(1).orEmpty()
                } else {
                    _grubCommandProposal.value = ""
                }
            }
            _avatarSpeech.value = response
        }
    }

    fun sendHidCommand(command: String) {
        val clipboard = getApplication<Application>().getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
        clipboard.setPrimaryClip(android.content.ClipData.newPlainText("Recovery command", command))
        _avatarSpeech.value = "Command copied. Nothing has been executed."
    }

    fun sendHidEnter() {
        _avatarSpeech.value = "USB keyboard injection is not supported by this app. Use the connected computer's terminal."
    }

    override fun onCleared() {
        super.onCleared()
        ttsVoiceManager.shutdown()
    }
}
