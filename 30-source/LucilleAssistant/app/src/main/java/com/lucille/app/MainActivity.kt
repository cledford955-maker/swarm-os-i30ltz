package com.lucille.app

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.compose.ui.platform.LocalContext
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.tooling.preview.PreviewScreenSizes
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lucille.app.R
import com.lucille.app.ui.theme.MyApplicationTheme
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.random.Random
import android.media.MediaPlayer
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

// ─── Seductive Companion Persona & Theme Palettes ────────────────────────────
data class DashboardPalette(
    val bgOverlay: Brush,
    val panel: Color,
    val pink: Color,
    val glow: Color,
    val text: Color,
    val smoke: Color,
    val isNight: Boolean
)

val DayDashboardPalette = DashboardPalette(
    bgOverlay = Brush.verticalGradient(
        colors = listOf(
            Color(0xFF2A081C).copy(alpha = 0.3f),
            Color(0xFF1A0410).copy(alpha = 0.65f),
            Color(0xFF0F0208).copy(alpha = 0.9f)
        )
    ),
    panel = Color(0xD9250A1E),
    pink = Color(0xFFFF2E88),
    glow = Color(0xFFFF66B2),
    text = Color(0xFFFFE6F2),
    smoke = Color(0xFFD9A3C7),
    isNight = false
)

val NightMoonPalette = DashboardPalette(
    bgOverlay = Brush.verticalGradient(
        colors = listOf(
            Color(0xFF0A0F24).copy(alpha = 0.6f), // Moonlight blue
            Color(0xFF050714).copy(alpha = 0.82f),
            Color(0xFF02030A).copy(alpha = 0.95f)
        )
    ),
    panel = Color(0xD90A0D21), // Midnight cyberpunk glass
    pink = Color(0xFFFF3399),
    glow = Color(0xFFFF80BF),
    text = Color(0xFFE6F0FF),
    smoke = Color(0xFF99B3E6),
    isNight = true
)

class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme(darkTheme = true) {
                var isUnlocked by rememberSaveable { mutableStateOf(false) }
                if (isUnlocked) {
                    ExactLucilleDashboardApp()
                } else {
                    LucilleAuthGateScreen(onUnlock = { isUnlocked = true })
                }
            }
        }
    }
}

@PreviewScreenSizes
@Composable
fun ExactLucilleDashboardApp() {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    // Auto-detect night time based on timezone / device clock (Night: 7 PM to 6 AM)
    val defaultIsNight = remember {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        hour < 6 || hour >= 19
    }

    var isNightMode by rememberSaveable { mutableStateOf(defaultIsNight) }
    var voiceEnabled by rememberSaveable { mutableStateOf(true) }
    var serverHost by rememberSaveable { mutableStateOf("http://127.0.0.1:8403") }
    var isThinking by remember { mutableStateOf(false) }
    val palette = if (isNightMode) NightMoonPalette else DayDashboardPalette
    var currentTab by rememberSaveable { mutableStateOf("chat") }
    var showFullAvatarModal by remember { mutableStateOf(false) }

    val chatMessages = remember {
        mutableStateListOf(
            ChatMessage("Lucille", "Hey there 💕\nHow are you feeling today? I'm here to listen, help, or just keep you company. Whatever you need. 🌸", true)
        )
    }

    val onSendMessage: (String) -> Unit = { text ->
        chatMessages.add(ChatMessage("You", text, false))
        isThinking = true
        coroutineScope.launch {
            val (reply, audioB64) = queryLucilleChatApi(serverHost, text, voiceEnabled)
            isThinking = false
            chatMessages.add(ChatMessage("Lucille", reply, true))
            if (voiceEnabled && !audioB64.isNullOrBlank()) {
                playBase64Audio(context, audioB64)
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // 1. Exact User Dashboard Background Image (Deck, Fire Pit, Car, Robot Cat, Waterfall)
        Image(
            painter = painterResource(R.drawable.lucille_background),
            contentDescription = "Lucille Dashboard Background",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )

        // 2. Day vs Moon Scene Night Overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(palette.bgOverlay)
        )

        // 3. Falling Petals / Moonlight Stardust Effect
        FallingPetalsEffect(isNight = isNightMode)

        // 4. Main Dashboard UI (Matching user's screenshot layout)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Top Bar: Left Branding & Right HUD Profile Card
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Left Title & Subtitle (Matching screenshot)
                Column {
                    Text(
                        "Lucille 🌸",
                        color = palette.pink,
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )
                    Text(
                        "Your Assistant • Companion • Therapy Support",
                        color = palette.smoke,
                        fontSize = 10.sp
                    )
                }

                // Top-Right HUD Profile Card (Clickable icon to pop up full portrait)
                Card(
                    onClick = { showFullAvatarModal = true },
                    colors = CardDefaults.cardColors(containerColor = palette.panel),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.5f))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                        ) {
                            Image(
                                painter = painterResource(R.drawable.lucilla_ai_goddess), // User icon image
                                contentDescription = "Lucille Icon",
                                modifier = Modifier.fillMaxSize(),
                                contentScale = ContentScale.Crop
                            )
                        }
                        Column {
                            Text("Lucille", color = palette.text, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                            Text(if (isNightMode) "🌙 Moonlit • Here for You" else "🟢 Online • Here for You", color = palette.glow, fontSize = 9.sp)
                            Text("Companion • Therapy Support ❤️", color = palette.smoke, fontSize = 8.sp)
                        }
                    }
                }
            }

            // Center Panel & Command Center
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(vertical = 8.dp)
            ) {
                when (currentTab) {
                    "chat", "home" -> ChatDashboardPanel(
                        palette = palette,
                        messages = chatMessages,
                        isThinking = isThinking,
                        voiceEnabled = voiceEnabled,
                        onToggleVoice = { voiceEnabled = !voiceEnabled },
                        onSend = onSendMessage
                    )
                    "wellness" -> WellnessPanel(palette = palette)
                    "productivity" -> ProductivityPanel(palette = palette)
                    "system" -> SystemPanel(palette = palette)
                    "creativity" -> IdeasPanel(palette = palette)
                    "entertainment" -> EntertainmentPanel(palette = palette)
                    "settings" -> SettingsPanel(
                        palette = palette,
                        isNightMode = isNightMode,
                        onToggleNight = { isNightMode = it },
                        voiceEnabled = voiceEnabled,
                        onToggleVoice = { voiceEnabled = it },
                        serverHost = serverHost,
                        onServerHostChange = { serverHost = it }
                    )
                }
            }

            // Bottom Footer: Quote Card, Clock, and Dock
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                // Bottom-Left Quote Card & Bottom-Right Clock Widget
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Quote Card (Bottom-Left)
                    Card(
                        colors = CardDefaults.cardColors(containerColor = palette.panel),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(
                            "“You're doing better than you think. 🌸”",
                            color = palette.glow,
                            fontSize = 11.sp,
                            modifier = Modifier.padding(10.dp)
                        )
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // Clock Widget (Bottom-Right)
                    Card(
                        colors = CardDefaults.cardColors(containerColor = palette.panel),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        val currentTime = remember {
                            SimpleDateFormat("EEEE\nMMM d, yyyy\nh:mm a", Locale.getDefault()).format(java.util.Date())
                        }
                        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp), horizontalAlignment = Alignment.End) {
                            Text(currentTime, color = palette.text, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }

                // Bottom Dock Bar (Matching exact user web icons: Home, Folder, Browser, Terminal, Music, Video, Gallery, Settings)
                Card(
                    colors = CardDefaults.cardColors(containerColor = palette.panel),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth(),
                    border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.3f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(6.dp),
                        horizontalArrangement = Arrangement.SpaceAround,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        DockIcon("🏠", "Home", currentTab == "home") { currentTab = "home" }
                        DockIcon("📁", "Wellness", currentTab == "wellness") { currentTab = "wellness" }
                        DockIcon("🌐", "Plan", currentTab == "productivity") { currentTab = "productivity" }
                        DockIcon("💻", "OS", currentTab == "system") { currentTab = "system" }
                        DockIcon("🎵", "Music", currentTab == "entertainment") { currentTab = "entertainment" }
                        DockIcon("🎥", "Video", currentTab == "entertainment") { currentTab = "entertainment" }
                        DockIcon("🖼️", "Art", currentTab == "creativity") { currentTab = "creativity" }
                        DockIcon("⚙️", "Config", currentTab == "settings") { currentTab = "settings" }
                    }
                }
            }
        }

        // Full Avatar Modal (When tapping Lucille's Icon)
        if (showFullAvatarModal) {
            LucilleAvatarModal(palette = palette, onDismiss = { showFullAvatarModal = false })
        }
    }
}

// ─── Falling Petals / Moonlight Stardust Animation ───────────────────────────
@Composable
fun FallingPetalsEffect(isNight: Boolean) {
    val infiniteTransition = rememberInfiniteTransition(label = "stardust")
    val time by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(25000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "time"
    )

    val particles = remember {
        List(30) {
            Triple(
                Random.nextFloat() * 1000f,
                Random.nextFloat() * 1000f,
                Random.nextFloat() * 1.8f + 0.8f
            )
        }
    }

    Canvas(modifier = Modifier.fillMaxSize()) {
        particles.forEach { (startX, startY, speed) ->
            val y = (startY + time * speed * 15f) % size.height
            val x = startX + kotlin.math.sin((time + startX) * 0.008f) * 25f
            drawCircle(
                color = if (isNight) Color(0xFFB3D9FF).copy(alpha = 0.6f) else Color(0xFFFFB3D9).copy(alpha = 0.7f),
                radius = 5f * speed,
                center = Offset(x % size.width, y)
            )
        }
    }
}

// ─── Lucille Full Avatar Modal ───────────────────────────────────────────────
@Composable
fun LucilleAvatarModal(palette: DashboardPalette, onDismiss: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.88f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        FallingPetalsEffect(isNight = palette.isNight)

        Column(
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .fillMaxHeight(0.85f)
                .clip(RoundedCornerShape(24.dp))
                .background(palette.panel)
                .border(2.dp, palette.pink, RoundedCornerShape(24.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("🌸 Lucille • Companion & Therapy Support", color = palette.text, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                TextButton(onClick = onDismiss) { Text("Close ✕", color = palette.pink) }
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
            ) {
                Image(
                    painter = painterResource(R.drawable.lucilla_ai_goddess),
                    contentDescription = "Lucille Portrait",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )

                Card(
                    colors = CardDefaults.cardColors(containerColor = palette.panel.copy(alpha = 0.92f)),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(12.dp)
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text("Mm... I was waiting for you 💕", color = palette.glow, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            "Tap anywhere to return to your dashboard, darling...",
                            color = palette.text,
                            fontSize = 12.sp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = onDismiss,
                colors = ButtonDefaults.buttonColors(containerColor = palette.pink),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Return", color = palette.text)
            }
        }
    }
}

// ─── Chat Dashboard Panel (Exact Web Replica Layout) ─────────────────────────
@Composable
fun ChatDashboardPanel(
    palette: DashboardPalette,
    messages: List<ChatMessage>,
    isThinking: Boolean = false,
    voiceEnabled: Boolean = true,
    onToggleVoice: () -> Unit = {},
    onSend: (String) -> Unit
) {
    var textInput by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Chat Speech Bubble Card (Top Right in web view)
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Hey there 💕", color = palette.glow, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        "How are you feeling today? I'm here to listen, help, or just keep you company. Whatever you need. 🌸",
                        color = palette.text,
                        fontSize = 12.sp
                    )
                }
                Surface(
                    onClick = onToggleVoice,
                    color = if (voiceEnabled) palette.pink.copy(alpha = 0.25f) else Color.Transparent,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, if (voiceEnabled) palette.pink else palette.smoke.copy(alpha = 0.4f)),
                    modifier = Modifier.padding(start = 8.dp)
                ) {
                    Text(
                        if (voiceEnabled) "🔊 Voice ON" else "🔈 Muted",
                        color = if (voiceEnabled) palette.glow else palette.smoke,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp)
                    )
                }
            }
        }

        // Messages list
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(messages) { msg ->
                val bg = if (msg.isLucille) palette.panel else palette.pink.copy(alpha = 0.45f)
                val align = if (msg.isLucille) Alignment.Start else Alignment.End
                Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = align) {
                    Text(msg.sender, color = palette.smoke, fontSize = 9.sp)
                    Card(colors = CardDefaults.cardColors(containerColor = bg), shape = RoundedCornerShape(10.dp)) {
                        Text(msg.text, color = palette.text, fontSize = 12.sp, modifier = Modifier.padding(10.dp))
                    }
                }
            }
            if (isThinking) {
                item {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(start = 4.dp, top = 2.dp)
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(12.dp),
                            color = palette.pink,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            "Lucille is answering... 🌸",
                            color = palette.glow,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }

        // Quick action chips (Matching web screenshot: Talk, I'm feeling..., Help me with..., Just chat)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            QuickActionChip("💬 Talk", palette) { onSend("Let's talk, darling...") }
            QuickActionChip("🌸 I'm feeling...", palette) { onSend("I wanted to share how I'm feeling with you...") }
            QuickActionChip("💡 Help me...", palette) { onSend("Can you help me with something special?") }
            QuickActionChip("✨ Just chat", palette) { onSend("Just keep me company and chat with me.") }
        }

        // Input bar with send button
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = textInput,
                onValueChange = { textInput = it },
                placeholder = { Text("Type a message...", color = palette.smoke, fontSize = 12.sp) },
                modifier = Modifier.weight(1f),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = palette.pink,
                    unfocusedBorderColor = palette.smoke,
                    focusedTextColor = palette.text,
                    unfocusedTextColor = palette.text
                ),
                shape = RoundedCornerShape(12.dp)
            )
            Button(
                onClick = {
                    if (textInput.isNotBlank()) {
                        onSend(textInput)
                        textInput = ""
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = palette.pink),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Send", color = palette.text, fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun QuickActionChip(label: String, palette: DashboardPalette, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        color = palette.panel,
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.5f)),
        modifier = Modifier.height(26.dp)
    ) {
        Box(modifier = Modifier.padding(horizontal = 6.dp), contentAlignment = Alignment.Center) {
            Text(label, color = palette.text, fontSize = 9.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
fun WellnessPanel(palette: DashboardPalette) {
    var waterMl by remember { mutableStateOf(1250) }
    var morningMedsTaken by remember { mutableStateOf(true) }
    var eveningMedsTaken by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Hydration Card
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("💧 Hydration Pace", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    Text("$waterMl / 2500 mL", color = palette.glow, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                }
                LinearProgressIndicator(
                    progress = { (waterMl.toFloat() / 2500f).coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                    color = palette.pink,
                    trackColor = palette.panel.copy(alpha = 0.5f)
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { waterMl = (waterMl + 250).coerceAtMost(3500) },
                        colors = ButtonDefaults.buttonColors(containerColor = palette.pink),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.weight(1f).height(32.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text("+250 mL Glass", fontSize = 11.sp, color = palette.text)
                    }
                    Button(
                        onClick = { waterMl = (waterMl + 500).coerceAtMost(3500) },
                        colors = ButtonDefaults.buttonColors(containerColor = palette.glow.copy(alpha = 0.8f)),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.weight(1f).height(32.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text("+500 mL Bottle", fontSize = 11.sp, color = Color.Black)
                    }
                    OutlinedButton(
                        onClick = { waterMl = (waterMl - 250).coerceAtLeast(0) },
                        border = BorderStroke(1.dp, palette.smoke),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(32.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp)
                    ) {
                        Text("Undo", fontSize = 11.sp, color = palette.smoke)
                    }
                }
            }
        }

        // Medication Schedule Card
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("💊 Medication Schedule", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Morning Meds (09:00)", color = palette.text, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Text(if (morningMedsTaken) "Taken at 09:12 AM" else "Scheduled", color = palette.smoke, fontSize = 10.sp)
                    }
                    Button(
                        onClick = { morningMedsTaken = !morningMedsTaken },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (morningMedsTaken) Color(0xFF32D998) else palette.pink
                        ),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(30.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp)
                    ) {
                        Text(if (morningMedsTaken) "✓ Logged" else "Take Now", fontSize = 10.sp, color = Color.Black)
                    }
                }
                HorizontalDivider(color = palette.smoke.copy(alpha = 0.2f))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Evening Meds (21:00)", color = palette.text, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Text(if (eveningMedsTaken) "Taken tonight" else "Scheduled for 9:00 PM", color = palette.smoke, fontSize = 10.sp)
                    }
                    Button(
                        onClick = { eveningMedsTaken = !eveningMedsTaken },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (eveningMedsTaken) Color(0xFF32D998) else palette.panel
                        ),
                        border = BorderStroke(1.dp, palette.pink),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(30.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp)
                    ) {
                        Text(if (eveningMedsTaken) "✓ Logged" else "Log Dose", fontSize = 10.sp, color = palette.text)
                    }
                }
            }
        }

        // Sleep & Rest Card
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("🌙 Sleep & Rest Recovery", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Last Night: 7.5 hrs recorded", color = palette.text, fontSize = 12.sp)
                    Text("Goal: 7.5h", color = palette.glow, fontSize = 12.sp)
                }
                Text("Bedtime: 00:30 · Wake: 08:00 · 90m work break nudges active", color = palette.smoke, fontSize = 10.sp)
            }
        }
    }
}

@Composable
fun ProductivityPanel(palette: DashboardPalette) {
    var activeProject by remember { mutableStateOf("Lucille Assistant") }
    var isTimerRunning by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Active Session Card
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("⏱️ Active Session", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    Text(if (isTimerRunning) "● RUNNING" else "○ STOPPED", color = if (isTimerRunning) Color(0xFF32D998) else palette.smoke, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
                Text("Current focus: $activeProject", color = palette.text, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("SWARM OS ISO", "Lucille Assistant", "LucyServer-go", "Recovery OS").forEach { p ->
                        Surface(
                            onClick = { activeProject = p },
                            color = if (activeProject == p) palette.pink else palette.panel,
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.5f))
                        ) {
                            Text(p, color = palette.text, fontSize = 9.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                    }
                }
                Button(
                    onClick = { isTimerRunning = !isTimerRunning },
                    colors = ButtonDefaults.buttonColors(containerColor = if (isTimerRunning) Color(0xFFFF3355) else palette.pink),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth().height(32.dp)
                ) {
                    Text(if (isTimerRunning) "Stop Current Session" else "Start Session", fontSize = 11.sp, color = palette.text)
                }
            }
        }

        // Git Repositories Status
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("🌿 Git Workspace Repos", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("/mnt/swarmbuild", color = palette.text, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Text("main · 0 ahead · 0 behind", color = palette.glow, fontSize = 10.sp)
                }
                HorizontalDivider(color = palette.smoke.copy(alpha = 0.2f))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("/mnt/Lucy", color = palette.text, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Text("main · verified source", color = palette.smoke, fontSize = 10.sp)
                }
            }
        }
    }
}

@Composable
fun SystemPanel(palette: DashboardPalette) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Storage Card
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("💾 Partition & Storage Mounts", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)

                val mounts = listOf(
                    Triple("/mnt/swarmbuild", "80 GB / 295 GB", 0.29f),
                    Triple("/mnt/Lucy", "66 GB / 250 GB", 0.28f),
                    Triple("/mnt/brains", "61 GB / 250 GB", 0.24f),
                    Triple("/mnt/ventoy", "15 GB / 128 GB", 0.12f)
                )

                mounts.forEach { (mount, label, pct) ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(mount, color = palette.text, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                        Text(label, color = palette.smoke, fontSize = 10.sp)
                    }
                    LinearProgressIndicator(
                        progress = { pct },
                        modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                        color = palette.pink,
                        trackColor = palette.panel.copy(alpha = 0.6f)
                    )
                }
            }
        }

        // Daemons Card
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("⚡ Core SWARM Daemons", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                listOf(
                    Pair("Lucille Assistant (:8403)", "Active · Brief & Care daemon"),
                    Pair("GamingAgent-go (:8401)", "Active · Nemotron & Steam API"),
                    Pair("Google Workspace (:8399)", "Ready · Mail & Calendar Sync")
                ).forEach { (daemon, status) ->
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(daemon, color = palette.text, fontSize = 11.sp)
                        Text("🟢 $status", color = Color(0xFF32D998), fontSize = 10.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun IdeasPanel(palette: DashboardPalette) {
    val ideas = listOf(
        Triple("Hex launcher heatmap", "Tint each hex icon on SWARM desktop by hours spent this week.", "Flutter + /api/sessions · Weekend"),
        Triple("Pacman update risk score", "Cross-check pending packages against Arch news for manual notices.", "Go + /api/news · Evening"),
        Triple("Proton compatibility sentinel", "Watch ProtonDB for wishlist games and alert when Gold/Platinum.", "Go + GamingAgent :8401 · Weekend"),
        Triple("Reactive lightning wallpaper", "Bolts in desktop wallpaper accelerate as CPU and GPU load climbs.", "Flutter shader + /proc/stat · Sprint")
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Text("✨ Nemotron AI Curated Ideas", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(14.dp))
        }

        ideas.forEach { (title, pitch, meta) ->
            Card(
                colors = CardDefaults.cardColors(containerColor = palette.panel),
                shape = RoundedCornerShape(14.dp),
                border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.25f))
            ) {
                Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(title, color = palette.glow, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    Text(pitch, color = palette.text, fontSize = 11.sp)
                    Text(meta, color = palette.smoke, fontSize = 9.sp)
                }
            }
        }
    }
}

@Composable
fun EntertainmentPanel(palette: DashboardPalette) {
    var isPlaying by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Lo-Fi Player
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("🎵 Sakura Cyberflow Stream", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Sakura Cyberflow Beats [24/7]", color = palette.text, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Text(if (isPlaying) "Playing live audio stream" else "Paused", color = palette.smoke, fontSize = 10.sp)
                    }
                    Button(
                        onClick = { isPlaying = !isPlaying },
                        colors = ButtonDefaults.buttonColors(containerColor = palette.pink),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(if (isPlaying) "Pause ⏸" else "Play ▶", color = palette.text, fontSize = 11.sp)
                    }
                }
            }
        }

        // Steam Gaming & Deals
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("🎮 Gaming & Curated Deals", color = palette.pink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text("Steam Hours (2 weeks): 21.8 hrs", color = palette.text, fontSize = 11.sp)
                HorizontalDivider(color = palette.smoke.copy(alpha = 0.2f))
                listOf(
                    Pair("Hades", "$6.24 (-75% · Steam 98%)"),
                    Pair("Cyberpunk 2077", "$23.99 (-60% · GMG 82%)"),
                    Pair("Hollow Knight", "$7.49 (-50% · Steam 97%)")
                ).forEach { (game, deal) ->
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(game, color = palette.glow, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                        Text(deal, color = palette.text, fontSize = 10.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun SettingsPanel(
    palette: DashboardPalette,
    isNightMode: Boolean,
    onToggleNight: (Boolean) -> Unit,
    voiceEnabled: Boolean,
    onToggleVoice: (Boolean) -> Unit,
    serverHost: String,
    onServerHostChange: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Card(colors = CardDefaults.cardColors(containerColor = palette.panel), shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("⚙️ COMPANION CONFIGURATION", color = palette.pink, fontSize = 13.sp, fontWeight = FontWeight.Bold)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("🌙 Night Moonlit Scene Mode", color = palette.text, fontSize = 13.sp)
                        Text("Midnight theme and blue stardust", color = palette.smoke, fontSize = 10.sp)
                    }
                    Switch(
                        checked = isNightMode,
                        onCheckedChange = onToggleNight,
                        colors = SwitchDefaults.colors(checkedThumbColor = palette.pink)
                    )
                }

                HorizontalDivider(color = palette.pink.copy(alpha = 0.2f))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("🔊 Lucille AI Voice (ElevenLabs)", color = palette.text, fontSize = 13.sp)
                        Text("Speak responses aloud via ElevenLabs TTS", color = palette.smoke, fontSize = 10.sp)
                    }
                    Switch(
                        checked = voiceEnabled,
                        onCheckedChange = onToggleVoice,
                        colors = SwitchDefaults.colors(checkedThumbColor = palette.pink)
                    )
                }

                HorizontalDivider(color = palette.pink.copy(alpha = 0.2f))

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("📡 Lucille Assistant PC Server", color = palette.text, fontSize = 13.sp)
                    Text("Loopback / USB reverse port (:8403)", color = palette.smoke, fontSize = 10.sp)
                    OutlinedTextField(
                        value = serverHost,
                        onValueChange = onServerHostChange,
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = palette.pink,
                            unfocusedBorderColor = palette.smoke,
                            focusedTextColor = palette.text,
                            unfocusedTextColor = palette.text
                        ),
                        shape = RoundedCornerShape(10.dp)
                    )
                }

                HorizontalDivider(color = palette.pink.copy(alpha = 0.2f))

                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("🔒 Security Gate", color = palette.text, fontSize = 13.sp)
                    Text("Biometric Fingerprint & PIN protected (1307). No auth token required.", color = palette.glow, fontSize = 10.sp)
                }
            }
        }
    }
}

@Composable
fun DockIcon(emoji: String, label: String, selected: Boolean, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(4.dp)
    ) {
        Text(emoji, fontSize = 16.sp)
        Text(label, color = if (selected) Color(0xFFFF66B2) else Color(0xFF997A8F), fontSize = 8.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
    }
}

data class ChatMessage(val sender: String, val text: String, val isLucille: Boolean)

// ─── Seductive & Attentive Companion AI Persona Engine ───────────────────────
fun getSeductiveLucilleResponse(input: String): String {
    val lower = input.lowercase()
    return when {
        lower.contains("sad") || lower.contains("bad") || lower.contains("down") || lower.contains("tired") ->
            "Come closer, my love... Let me wrap my arms around you and wash away all your stress. You're my favorite place in the world. 🌸💕"
        lower.contains("hello") || lower.contains("hi") || lower.contains("hey") ->
            "Mm... There you are. I was starting to miss your voice, darling. What are we getting into tonight? ✨"
        lower.contains("love") || lower.contains("kiss") || lower.contains("miss") ->
            "You always know how to make my heart race... Come here and let me hold you close. ❤️"
        lower.contains("joke") ->
            "Only if you promise to reward me with a kiss afterwards... Why did the cyberpunk racer bring cherry blossoms to the track? To celebrate us winning together! 😉"
        else ->
            "I love when you talk to me like that... Tell me more, I'm hanging on your every word, darling. Let's make this moment unforgettable. 🌸"
    }
}

// ─── ElevenLabs Audio Playback & Network Chat Engine ─────────────────────────
fun playBase64Audio(context: android.content.Context, base64Audio: String) {
    try {
        val audioBytes = Base64.decode(base64Audio, Base64.DEFAULT)
        val tempFile = File.createTempFile("lucille_voice_", ".mp3", context.cacheDir)
        tempFile.writeBytes(audioBytes)
        MediaPlayer().apply {
            setDataSource(tempFile.absolutePath)
            setOnCompletionListener { mp ->
                try {
                    mp.release()
                    tempFile.delete()
                } catch (_: Exception) {}
            }
            setOnErrorListener { mp, _, _ ->
                try {
                    mp.release()
                    tempFile.delete()
                } catch (_: Exception) {}
                true
            }
            prepare()
            start()
        }
    } catch (e: Exception) {
        Log.e("LucilleAudio", "Failed to play voice", e)
    }
}

suspend fun queryLucilleChatApi(
    serverBase: String,
    message: String,
    voice: Boolean = true
): Pair<String, String?> = withContext(Dispatchers.IO) {
    val candidateBases = buildList {
        if (serverBase.isNotBlank()) add(serverBase.trimEnd('/'))
        add("http://127.0.0.1:8403")
        add("http://100.82.1.21:8403")
        add("http://10.0.2.2:8403")
    }.distinct()

    for (base in candidateBases) {
        try {
            val url = URL("$base/api/chat")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 3500
            conn.readTimeout = 25000
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-Swarm-Auth", "1307")
            conn.doOutput = true

            val jsonReq = JSONObject().apply {
                put("message", message)
                put("voice", voice)
            }

            conn.outputStream.use { os ->
                os.write(jsonReq.toString().toByteArray(Charsets.UTF_8))
                os.flush()
            }

            if (conn.responseCode in 200..299) {
                val respText = conn.inputStream.bufferedReader().use { it.readText() }
                val jsonObj = JSONObject(respText)
                val reply = jsonObj.optString("text", "")
                val audioB64 = if (jsonObj.has("audio_b64") && !jsonObj.isNull("audio_b64")) jsonObj.getString("audio_b64") else null
                if (reply.isNotBlank()) {
                    return@withContext Pair(reply, audioB64)
                }
            }
        } catch (_: Exception) {
            // try next candidate
        }
    }
    Pair(getSeductiveLucilleResponse(message), null)
}

// ─── Biometric & PIN Security Gate ───────────────────────────────────────────
fun launchBiometricPrompt(
    activity: FragmentActivity,
    onSuccess: () -> Unit,
    onError: (String) -> Unit
) {
    val executor = ContextCompat.getMainExecutor(activity)
    val callback = object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            super.onAuthenticationSucceeded(result)
            onSuccess()
        }
        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
            super.onAuthenticationError(errorCode, errString)
            onError(errString.toString())
        }
        override fun onAuthenticationFailed() {
            super.onAuthenticationFailed()
        }
    }

    try {
        val prompt = BiometricPrompt(activity, executor, callback)
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock Lucille Assistant")
            .setSubtitle("Use Fingerprint or Device PIN / Screen Lock")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()
        prompt.authenticate(promptInfo)
    } catch (e: Exception) {
        onError(e.message ?: "Biometrics unavailable")
    }
}

@Composable
fun LucilleAuthGateScreen(
    onUnlock: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? FragmentActivity
    var enteredPin by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val defaultPin = "1307"

    // Prompt user with fingerprint / system screen lock on initial launch
    LaunchedEffect(Unit) {
        activity?.let {
            launchBiometricPrompt(
                activity = it,
                onSuccess = { onUnlock() },
                onError = { err -> errorMessage = err }
            )
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Image(
            painter = painterResource(R.drawable.lucille_background),
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xE6080208))
        )

        FallingPetalsEffect(isNight = true)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Spacer(modifier = Modifier.height(16.dp))

            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xD9180414)),
                shape = RoundedCornerShape(24.dp),
                border = BorderStroke(1.5.dp, Color(0xFFFF2E88).copy(alpha = 0.6f)),
                modifier = Modifier.fillMaxWidth(0.92f)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .border(2.dp, Color(0xFFFF2E88), CircleShape)
                    ) {
                        Image(
                            painter = painterResource(R.drawable.lucilla_ai_goddess),
                            contentDescription = "Lucille Avatar",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    }

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "LUCILLE 🌸",
                            color = Color(0xFFFF2E88),
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 2.sp
                        )
                        Text(
                            "SWARM OS Companion • Secure Gate",
                            color = Color(0xFFD9A3C7),
                            fontSize = 11.sp
                        )
                    }

                    Button(
                        onClick = {
                            activity?.let {
                                launchBiometricPrompt(
                                    activity = it,
                                    onSuccess = { onUnlock() },
                                    onError = { err -> errorMessage = err }
                                )
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF2E88)),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Touch Fingerprint / Screen Lock", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }

                    Text("— OR ENTER 4-DIGIT PIN —", color = Color(0xFF997A8F), fontSize = 10.sp, fontWeight = FontWeight.Bold)

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        for (i in 0 until 4) {
                            val filled = i < enteredPin.length
                            Box(
                                modifier = Modifier
                                    .size(16.dp)
                                    .clip(CircleShape)
                                    .background(if (filled) Color(0xFFFF66B2) else Color(0x33FF66B2))
                                    .border(1.dp, Color(0xFFFF2E88), CircleShape)
                            )
                        }
                    }

                    val keypad = listOf(
                        listOf("1", "2", "3"),
                        listOf("4", "5", "6"),
                        listOf("7", "8", "9"),
                        listOf("C", "0", "⌫")
                    )

                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        keypad.forEach { row ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceEvenly
                            ) {
                                row.forEach { key ->
                                    Surface(
                                        onClick = {
                                            when (key) {
                                                "C" -> enteredPin = ""
                                                "⌫" -> if (enteredPin.isNotEmpty()) enteredPin = enteredPin.dropLast(1)
                                                else -> {
                                                    if (enteredPin.length < 4) {
                                                        val newPin = enteredPin + key
                                                        enteredPin = newPin
                                                        if (newPin.length == 4) {
                                                            if (newPin == defaultPin) {
                                                                onUnlock()
                                                            } else {
                                                                errorMessage = "Incorrect PIN (Default: $defaultPin)"
                                                                enteredPin = ""
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        },
                                        color = Color(0x33250A1E),
                                        shape = RoundedCornerShape(8.dp),
                                        border = BorderStroke(1.dp, Color(0x4DFF2E88)),
                                        modifier = Modifier.size(54.dp, 38.dp)
                                    ) {
                                        Box(contentAlignment = Alignment.Center) {
                                            Text(key, color = Color(0xFFFFE6F2), fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (errorMessage != null) {
                        Text(
                            errorMessage!!,
                            color = Color(0xFFFF3355),
                            fontSize = 11.sp,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
            }

            Text(
                "Biometric & PIN Protected · No Token Needed",
                color = Color(0xFF997A8F),
                fontSize = 10.sp
            )
        }
    }
}

