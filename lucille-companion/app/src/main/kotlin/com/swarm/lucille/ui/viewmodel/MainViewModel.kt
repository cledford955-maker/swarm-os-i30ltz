// MainViewModel.kt — Shared ViewModel for all screens  v1.0.0  2026-09-24
// StateFlow-based; single ViewModel shared across the bottom nav
package com.swarm.lucille.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.swarm.lucille.data.network.*
import com.swarm.lucille.data.prefs.AppPrefs
import com.swarm.lucille.data.repository.LucilleRepository
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

// ─── Screen-level UI state wrappers ──────────────────────────────────────────

data class UiState<T>(
    val data: T? = null,
    val loading: Boolean = false,
    val error: String? = null
) {
    val isReady get() = !loading && error == null && data != null
}

fun <T> loadingState() = UiState<T>(loading = true)
fun <T> ApiResult<T>.toUiState() = when (this) {
    is ApiResult.Success -> UiState(data = data)
    is ApiResult.Error   -> UiState(error = message)
    is ApiResult.Loading -> UiState(loading = true)
}

// ─── Telemetry auto-refresh job ─────────────────────────────────────────────

class MainViewModel(
    val prefs: AppPrefs,
    val repo: LucilleRepository
) : ViewModel() {

    // Connection state
    private val _connected = MutableStateFlow<Boolean?>(null)
    val connected: StateFlow<Boolean?> = _connected.asStateFlow()

    // ── Brief
    private val _dailyBrief   = MutableStateFlow<UiState<DailyBriefResponse>>(UiState())
    val dailyBrief = _dailyBrief.asStateFlow()

    private val _projectBrief = MutableStateFlow<UiState<ProjectBriefResponse>>(UiState())
    val projectBrief = _projectBrief.asStateFlow()

    // ── Mail
    private val _mail = MutableStateFlow<UiState<MailResponse>>(UiState())
    val mail = _mail.asStateFlow()

    // ── Voice
    private val _voiceSMS      = MutableStateFlow<UiState<VoiceResponse>>(UiState())
    val voiceSMS = _voiceSMS.asStateFlow()

    private val _voiceCalls    = MutableStateFlow<UiState<VoiceResponse>>(UiState())
    val voiceCalls = _voiceCalls.asStateFlow()

    private val _voiceVoicemail= MutableStateFlow<UiState<VoiceResponse>>(UiState())
    val voiceVoicemail = _voiceVoicemail.asStateFlow()

    // ── Workspace
    private val _driveRecent  = MutableStateFlow<UiState<DriveFilesResponse>>(UiState())
    val driveRecent = _driveRecent.asStateFlow()

    private val _calendar     = MutableStateFlow<UiState<CalendarResponse>>(UiState())
    val calendar = _calendar.asStateFlow()

    private val _contacts     = MutableStateFlow<UiState<ContactsResponse>>(UiState())
    val contacts = _contacts.asStateFlow()

    // ── Telemetry (polling)
    private val _telemetry    = MutableStateFlow<UiState<TelemetryResponse>>(UiState())
    val telemetry = _telemetry.asStateFlow()

    // ── Coach
    private val _coach        = MutableStateFlow<UiState<CoachResponse>>(UiState())
    val coach = _coach.asStateFlow()

    // ── Prefs flows
    val serverUrl  = prefs.serverUrl
    val coachGame  = prefs.coachGame

    // Auto-refresh job for telemetry
    private var telemetryJob: Job? = null
    private var telemetryPolling = false

    init {
        // Sync config once on start then try connecting
        viewModelScope.launch {
            repo.syncConfig()
            ping()
        }
    }

    // ── Connectivity ─────────────────────────────────────────────────────────

    fun ping() {
        viewModelScope.launch {
            val res = repo.ping()
            _connected.value = res is ApiResult.Success
        }
    }

    fun configure(url: String, token: String) {
        repo.configure(url, token)
        viewModelScope.launch {
            prefs.setServerUrl(url)
            prefs.setAuthToken(token)
            ping()
        }
    }

    // ── Brief ─────────────────────────────────────────────────────────────────

    fun loadDailyBrief(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _dailyBrief.value = loadingState()
            _dailyBrief.value = repo.getDailyBrief(forceRefresh).toUiState()
        }
    }

    fun loadProjectBrief(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _projectBrief.value = loadingState()
            _projectBrief.value = repo.getProjectBrief(forceRefresh).toUiState()
        }
    }

    // ── Mail ──────────────────────────────────────────────────────────────────

    fun loadMail(label: String = "INBOX") {
        viewModelScope.launch {
            _mail.value = loadingState()
            _mail.value = repo.getMail(label).toUiState()
        }
    }

    // ── Voice ─────────────────────────────────────────────────────────────────

    fun loadVoiceSMS(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _voiceSMS.value = loadingState()
            _voiceSMS.value = repo.getVoiceSMS(forceRefresh).toUiState()
        }
    }

    fun loadVoiceCalls(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _voiceCalls.value = loadingState()
            _voiceCalls.value = repo.getVoiceCalls(forceRefresh).toUiState()
        }
    }

    fun loadVoiceVoicemail(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _voiceVoicemail.value = loadingState()
            _voiceVoicemail.value = repo.getVoiceVoicemail(forceRefresh).toUiState()
        }
    }

    fun sendVoiceSMS(threadId: String, body: String, onDone: (Boolean) -> Unit) {
        viewModelScope.launch {
            val res = repo.sendVoiceSMS(threadId, body)
            onDone(res is ApiResult.Success)
            if (res is ApiResult.Success) loadVoiceSMS(forceRefresh = true)
        }
    }

    // ── Workspace ─────────────────────────────────────────────────────────────

    fun loadDriveRecent(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _driveRecent.value = loadingState()
            _driveRecent.value = repo.getDriveRecent(forceRefresh).toUiState()
        }
    }

    fun searchDrive(q: String) {
        viewModelScope.launch {
            _driveRecent.value = loadingState()
            _driveRecent.value = repo.searchDrive(q).toUiState()
        }
    }

    fun loadCalendar(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _calendar.value = loadingState()
            _calendar.value = repo.getCalendar(forceRefresh).toUiState()
        }
    }

    fun loadContacts(forceRefresh: Boolean = false) {
        viewModelScope.launch {
            _contacts.value = loadingState()
            _contacts.value = repo.getContacts(forceRefresh).toUiState()
        }
    }

    fun searchContacts(q: String) {
        viewModelScope.launch {
            _contacts.value = loadingState()
            _contacts.value = repo.searchContacts(q).toUiState()
        }
    }

    // ── Telemetry polling ─────────────────────────────────────────────────────

    fun startTelemetryPolling(intervalMs: Long = 3_000L) {
        if (telemetryPolling) return
        telemetryPolling = true
        telemetryJob = viewModelScope.launch {
            while (isActive) {
                val res = repo.getTelemetry()
                _telemetry.value = res.toUiState()
                delay(intervalMs)
            }
        }
    }

    fun stopTelemetryPolling() {
        telemetryPolling = false
        telemetryJob?.cancel()
        telemetryJob = null
    }

    fun loadTelemetryOnce() {
        viewModelScope.launch {
            _telemetry.value = loadingState()
            _telemetry.value = repo.getTelemetry().toUiState()
        }
    }

    // ── Coach ─────────────────────────────────────────────────────────────────

    fun loadCoachTips(game: String = "") {
        viewModelScope.launch {
            _coach.value = loadingState()
            _coach.value = repo.getCoachTips(game).toUiState()
        }
    }

    fun setCoachGame(game: String) {
        viewModelScope.launch {
            prefs.setCoachGame(game)
            loadCoachTips(game)
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopTelemetryPolling()
    }

    // ── Factory ───────────────────────────────────────────────────────────────
    class Factory(
        private val prefs: AppPrefs,
        private val repo: LucilleRepository
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(MainViewModel::class.java)) {
                return MainViewModel(prefs, repo) as T
            }
            throw IllegalArgumentException("Unknown ViewModel: ${modelClass.name}")
        }
    }
}
