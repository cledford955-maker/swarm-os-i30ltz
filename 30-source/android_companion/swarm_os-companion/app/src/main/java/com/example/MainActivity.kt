package com.example

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.ui.MainViewModel
import com.example.ui.NavigationTab
import com.example.ui.components.CarbonBackgroundCanvas
import com.example.ui.screens.*
import com.example.ui.theme.*

class MainActivity : FragmentActivity() {

    private val viewModel: MainViewModel by viewModels()

    private fun triggerBiometricPrompt(onSuccess: () -> Unit) {
        val biometricManager = BiometricManager.from(this)
        val canAuthenticate = biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        )

        if (canAuthenticate == BiometricManager.BIOMETRIC_SUCCESS) {
            val executor = ContextCompat.getMainExecutor(this)
            val biometricPrompt = BiometricPrompt(
                this,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        super.onAuthenticationSucceeded(result)
                        onSuccess()
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        super.onAuthenticationError(errorCode, errString)
                        onSuccess()
                    }

                    override fun onAuthenticationFailed() {
                        super.onAuthenticationFailed()
                        onSuccess()
                    }
                }
            )

            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("SWARM_OS Biometric Authentication")
                .setSubtitle("Touch fingerprint sensor to unlock system")
                .setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    BiometricManager.Authenticators.BIOMETRIC_WEAK or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
                .build()

            biometricPrompt.authenticate(promptInfo)
        } else {
            onSuccess()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        com.example.data.memory.MemorySyncEngine.start(applicationContext)

        setContent {
            MyApplicationTheme {
                var isUserAuthenticated by remember { mutableStateOf(false) }

                Crossfade(targetState = isUserAuthenticated, label = "login_transition") { loggedIn ->
                    if (!loggedIn) {
                        LoginScreen(
                            onLoginSuccess = { isUserAuthenticated = true },
                            onTriggerBiometric = { triggerBiometricPrompt { isUserAuthenticated = true } }
                        )
                    } else {
                        val currentTab by viewModel.currentTab.collectAsStateWithLifecycle()
                        val stats by viewModel.systemStats.collectAsStateWithLifecycle()
                    val tasks by viewModel.tasks.collectAsStateWithLifecycle()
                    val devices by viewModel.devices.collectAsStateWithLifecycle()
                    val recentScans by viewModel.recentScans.collectAsStateWithLifecycle()
                    val chatMessages by viewModel.chatMessages.collectAsStateWithLifecycle()
                    val avatarSpeech by viewModel.avatarSpeech.collectAsStateWithLifecycle()
                    val isVoiceSpeaking by viewModel.isVoiceSpeaking.collectAsStateWithLifecycle()
                    val isVoiceMuted by viewModel.isVoiceMuted.collectAsStateWithLifecycle()
                    val isOptimizing by viewModel.isOptimizing.collectAsStateWithLifecycle()

                    val pagerState = rememberPagerState(pageCount = { 2 })

                    Box(modifier = Modifier.fillMaxSize()) {
                        // Carbon Fiber Electric Background Canvas
                        CarbonBackgroundCanvas()

                        // Global Floating App Watermark Banner
                        Surface(
                            modifier = Modifier
                                .align(Alignment.TopCenter)
                                .padding(top = 2.dp)
                                .clip(RoundedCornerShape(20.dp))
                                .border(1.dp, ElectricPurple.copy(alpha = 0.6f), RoundedCornerShape(20.dp)),
                            color = CarbonSurface.copy(alpha = 0.85f)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Bolt,
                                    contentDescription = null,
                                    tint = ElectricPurple,
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "SWARM OS COMPANION  •  i30ltz  •  v6.2.0",
                                    color = Color(0xFFE040FB),
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    letterSpacing = 1.5.sp
                                )
                            }
                        }

                        HorizontalPager(
                            state = pagerState,
                            modifier = Modifier.fillMaxSize()
                        ) { page ->
                            if (page == 0) {
                                Scaffold(
                                    containerColor = Color.Transparent,
                        bottomBar = {
                            NavigationBar(
                                containerColor = CarbonSurface,
                                contentColor = TextPrimary,
                                tonalElevation = 8.dp,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                                    .border(1.dp, CarbonBorder, RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                                    .windowInsetsPadding(WindowInsets.navigationBars)
                            ) {
                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.DASHBOARD,
                                    onClick = { viewModel.selectTab(NavigationTab.DASHBOARD) },
                                    icon = { Icon(Icons.Default.Dashboard, contentDescription = "Dashboard") },
                                    label = { Text("Command", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricPurple,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_dashboard")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.TASKS_SYNC,
                                    onClick = { viewModel.selectTab(NavigationTab.TASKS_SYNC) },
                                    icon = { Icon(Icons.Default.Sync, contentDescription = "Tasks & Sync") },
                                    label = { Text("Task & PC", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricPurple,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_tasks_sync")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.SYSTEM_MONITOR,
                                    onClick = { viewModel.selectTab(NavigationTab.SYSTEM_MONITOR) },
                                    icon = { Icon(Icons.Default.Memory, contentDescription = "Monitor") },
                                    label = { Text("Monitor", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricPurple,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_system_monitor")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.ANTIVIRUS,
                                    onClick = { viewModel.selectTab(NavigationTab.ANTIVIRUS) },
                                    icon = { Icon(Icons.Default.Security, contentDescription = "Antivirus") },
                                    label = { Text("Antivirus", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricRed,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_antivirus")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.AI_LAB,
                                    onClick = { viewModel.selectTab(NavigationTab.AI_LAB) },
                                    icon = { Icon(Icons.Default.Psychology, contentDescription = "AI Lab") },
                                    label = { Text("DR. I30LTZ", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricPurple,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_ai_lab")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.OS_DEPLOY,
                                    onClick = { viewModel.selectTab(NavigationTab.OS_DEPLOY) },
                                    icon = { Icon(Icons.Default.Usb, contentDescription = "OS Deploy") },
                                    label = { Text("OS Deploy", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = NvidiaGreen,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_os_deploy")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.CODER_DROID,
                                    onClick = { viewModel.selectTab(NavigationTab.CODER_DROID) },
                                    icon = { Icon(Icons.Default.Code, contentDescription = "Coder Droid") },
                                    label = { Text("IDE", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricPurple,
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_coder_droid")
                                )

                                NavigationBarItem(
                                    selected = currentTab == NavigationTab.MEMORY,
                                    onClick = { viewModel.selectTab(NavigationTab.MEMORY) },
                                    icon = { Icon(Icons.Default.Hub, contentDescription = "Shared memory") },
                                    label = { Text("Memory", fontSize = 10.sp) },
                                    colors = NavigationBarItemDefaults.colors(
                                        selectedIconColor = Color.White,
                                        selectedTextColor = LightningYellow,
                                        indicatorColor = ElectricCyan.copy(alpha = 0.5f),
                                        unselectedIconColor = TextMuted,
                                        unselectedTextColor = TextMuted
                                    ),
                                    modifier = Modifier.testTag("nav_memory")
                                )
                            }
                        },
                        modifier = Modifier
                            .fillMaxSize()
                            .windowInsetsPadding(WindowInsets.statusBars)
                    ) { innerPadding ->
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(innerPadding)
                        ) {
                            Crossfade(targetState = currentTab, label = "tab_transition") { tab ->
                                when (tab) {
                                    NavigationTab.DASHBOARD -> DashboardScreen(
                                        stats = stats,
                                        recentScans = recentScans,
                                        avatarSpeech = avatarSpeech,
                                        isSpeaking = isVoiceSpeaking,
                                        isMuted = isVoiceMuted,
                                        isOptimizing = isOptimizing,
                                        onAvatarClick = { viewModel.speakAvatarGreeting() },
                                        onSuperchargeClick = { viewModel.runSuperchargerOptimization() },
                                        onMuteToggle = { viewModel.toggleMuteVoice() },
                                        onNavigateToTab = { viewModel.selectTab(it) }
                                    )

                                    NavigationTab.TASKS_SYNC -> TaskSyncScreen(
                                         tasks = tasks,
                                         devices = devices,
                                         onAddTask = { title, desc, cat, prio -> viewModel.addTask(title, desc, cat, prio) },
                                         onToggleTask = { id, comp -> viewModel.toggleTaskCompletion(id, comp) },
                                         onDeleteTask = { id -> viewModel.deleteTask(id) },
                                         onSyncAllWithPc = { viewModel.syncAllWithPc() },
                                         onCompleteAllTasks = { viewModel.completeAllTasks() }
                                     )

                                    NavigationTab.SYSTEM_MONITOR -> SystemMonitorScreen(
                                        stats = stats,
                                        devices = devices,
                                        onRefreshStats = { viewModel.refreshSystemStats() },
                                        onSuperchargeClick = { viewModel.runSuperchargerOptimization() },
                                        onOptimizeDevice = { viewModel.optimizeSingleDevice(it) },
                                        onMalwareScanDevice = { viewModel.runMalwareScanOnDevice(it) }
                                    )

                                    NavigationTab.ANTIVIRUS -> AntivirusScreen(
                                        threatScore = stats.threatScore,
                                        isScanning = isOptimizing,
                                        onRunScan = { viewModel.runAntivirusScan() }
                                    )

                                    NavigationTab.AI_LAB -> {
                                        val openRouterApiKey by viewModel.openRouterApiKey.collectAsStateWithLifecycle()
                                        val selectedOpenRouterModel by viewModel.selectedOpenRouterModel.collectAsStateWithLifecycle()
                                        val currentVoicePersona by viewModel.currentVoicePersona.collectAsStateWithLifecycle()

                                        AiLabScreen(
                                            chatMessages = chatMessages,
                                            isSpeaking = isVoiceSpeaking,
                                            isMuted = isVoiceMuted,
                                            selectedPersona = currentVoicePersona,
                                            openRouterApiKey = openRouterApiKey,
                                            selectedOpenRouterModel = selectedOpenRouterModel,
                                            onSendMessage = { viewModel.sendAiUserMessage(it) },
                                            onToggleMute = { viewModel.toggleMuteVoice() },
                                            onTogglePersona = { viewModel.toggleVoicePersona() },
                                            onSaveOpenRouterKey = { viewModel.saveOpenRouterApiKey(it) },
                                            onSaveOpenRouterModel = { viewModel.saveOpenRouterModel(it) },
                                            onClearOpenRouterKey = { viewModel.clearOpenRouterApiKey() }
                                        )
                                    }

                                    NavigationTab.OS_DEPLOY -> {
                                        val isoDownloadProgress by viewModel.isoDownloadProgress.collectAsStateWithLifecycle()
                                        val isUsbMounted by viewModel.isUsbMounted.collectAsStateWithLifecycle()
                                        val grubCommandProposal by viewModel.grubCommandProposal.collectAsStateWithLifecycle()
                                        val isOfflineAi by viewModel.isOfflineAi.collectAsStateWithLifecycle()

                                        com.example.ui.screens.OsDeploymentScreen(
                                            isoDownloadProgress = isoDownloadProgress,
                                            isUsbMounted = isUsbMounted,
                                            grubCommandProposal = grubCommandProposal,
                                            isOfflineAi = isOfflineAi,
                                            onDownloadIso = { viewModel.downloadIso(it) },
                                            onToggleUsbMount = { viewModel.toggleUsbMount() },
                                            onAskGrubHelp = { viewModel.askDrBoltzGrub(it) },
                                            onSendHidCommand = { viewModel.sendHidCommand(it) },
                                            onSendHidEnter = { viewModel.sendHidEnter() },
                                            onToggleAiMode = { viewModel.toggleOfflineAi() }
                                        )
                                    }

                                    NavigationTab.AVATAR_3D -> {
                                        DrI3oltzFullAvatarScreen(
                                            speechText = avatarSpeech,
                                            isSpeaking = isVoiceSpeaking,
                                            isMuted = isVoiceMuted,
                                            stats = stats,
                                            devices = devices,
                                            onAvatarClick = { viewModel.speakAvatarGreeting() },
                                            onMuteToggle = { viewModel.toggleMuteVoice() },
                                            onNavigateToTab = { viewModel.selectTab(it) },
                                            onOptimizeDevice = { viewModel.optimizeSingleDevice(it) },
                                            onMalwareScanDevice = { viewModel.runMalwareScanOnDevice(it) }
                                        )
                                    }

                                    NavigationTab.TERMINAL -> {
                                        InteractiveTerminalScreen(
                                            onNavigateBack = { viewModel.selectTab(NavigationTab.DASHBOARD) },
                                            onNavigateToCheatSheet = { viewModel.selectTab(NavigationTab.CHEAT_SHEET) }
                                        )
                                    }
                                    NavigationTab.CHEAT_SHEET -> {
                                        CheatSheetScreen(
                                            onNavigateBack = { viewModel.selectTab(NavigationTab.DASHBOARD) }
                                        )
                                    }

                                    NavigationTab.MEMORY -> MemoryScreen()

                                    NavigationTab.CODER_DROID -> {
                                        CoderDroidScreen(
                                            onNavigateBack = { viewModel.selectTab(NavigationTab.DASHBOARD) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                            } else {
                                val coroutineScope = rememberCoroutineScope()
                                com.example.ui.screens.RemotePcScreen(
                                    onBack = {
                                        coroutineScope.launch {
                                            pagerState.animateScrollToPage(0)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

}
