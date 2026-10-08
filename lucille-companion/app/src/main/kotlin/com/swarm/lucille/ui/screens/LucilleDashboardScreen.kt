package com.swarm.lucille.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.random.Random

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
            Color(0xFF0A0F24).copy(alpha = 0.6f),
            Color(0xFF050714).copy(alpha = 0.82f),
            Color(0xFF02030A).copy(alpha = 0.95f)
        )
    ),
    panel = Color(0xD90A0D21),
    pink = Color(0xFFFF3399),
    glow = Color(0xFFFF80BF),
    text = Color(0xFFE6F0FF),
    smoke = Color(0xFF99B3E6),
    isNight = true
)

@Composable
fun LucilleDashboardScreen() {
    val defaultIsNight = remember {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        hour < 6 || hour >= 19
    }

    var isNightMode by rememberSaveable { mutableStateOf(defaultIsNight) }
    val palette = if (isNightMode) NightMoonPalette else DayDashboardPalette
    var currentTab by rememberSaveable { mutableStateOf("chat") }
    var showFullAvatarModal by remember { mutableStateOf(false) }

    val chatMessages = remember {
        mutableStateListOf(
            CompanionChatMessage("Lucille", "Hey there 💕\nHow are you feeling today? I'm here to listen, help, or just keep you company. Whatever you need. 🌸", true)
        )
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // 1. User Dashboard Background Image
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

        // 4. Main Dashboard UI
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Top Bar: Left Branding & Right HUD Profile Card
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
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
                                painter = painterResource(R.drawable.lucilla_ai_goddess),
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
                    "chat", "home" -> CompanionChatPanel(
                        palette = palette,
                        messages = chatMessages,
                        onSend = { text ->
                            chatMessages.add(CompanionChatMessage("You", text, false))
                            chatMessages.add(CompanionChatMessage("Lucille", getSeductiveLucilleResponse(text), true))
                        }
                    )
                    "wellness" -> CompanionPanelContent("🌸 Wellness & Support", "Mood, therapy sessions, and mindfulness exercises with Lucille.", palette)
                    "productivity" -> CompanionPanelContent("📅 Productivity & Plan", "Organize your tasks, sync Swarm OS nodes, and schedule briefs.", palette)
                    "system" -> CompanionPanelContent("💻 System Control", "Manage Swarm OS daemons, memory clusters, and neural telemetry.", palette)
                    "creativity" -> CompanionPanelContent("🎨 Creativity & Ideas", "Generate code snippets, design tokens, and creative project drafts.", palette)
                    "entertainment" -> CompanionPanelContent("🎵 Entertainment & Music", "Now playing: Sakura Cyberflow Lo-Fi Beats [Live Stream]", palette)
                    "settings" -> CompanionSettingsPanel(palette = palette, isNightMode = isNightMode, onToggleNight = { isNightMode = it })
                }
            }

            // Bottom Footer: Quote Card, Clock, and Dock
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
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
                        CompanionDockIcon("🏠", "Home", currentTab == "home") { currentTab = "home" }
                        CompanionDockIcon("📁", "Wellness", currentTab == "wellness") { currentTab = "wellness" }
                        CompanionDockIcon("🌐", "Plan", currentTab == "productivity") { currentTab = "productivity" }
                        CompanionDockIcon("💻", "OS", currentTab == "system") { currentTab = "system" }
                        CompanionDockIcon("🎵", "Music", currentTab == "entertainment") { currentTab = "entertainment" }
                        CompanionDockIcon("🎥", "Video", currentTab == "entertainment") { currentTab = "entertainment" }
                        CompanionDockIcon("🖼️", "Art", currentTab == "creativity") { currentTab = "creativity" }
                        CompanionDockIcon("⚙️", "Config", currentTab == "settings") { currentTab = "settings" }
                    }
                }
            }
        }

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

// ─── Companion Chat Panel ────────────────────────────────────────────────────
@Composable
fun CompanionChatPanel(
    palette: DashboardPalette,
    messages: List<CompanionChatMessage>,
    onSend: (String) -> Unit
) {
    var textInput by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Card(
            colors = CardDefaults.cardColors(containerColor = palette.panel),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, palette.pink.copy(alpha = 0.4f))
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("Hey there 💕", color = palette.glow, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    "How are you feeling today? I'm here to listen, help, or just keep you company. Whatever you need. 🌸",
                    color = palette.text,
                    fontSize = 12.sp
                )
            }
        }

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
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            CompanionQuickActionChip("💬 Talk", palette) { onSend("Let's talk, darling...") }
            CompanionQuickActionChip("🌸 I'm feeling...", palette) { onSend("I wanted to share how I'm feeling with you...") }
            CompanionQuickActionChip("💡 Help me...", palette) { onSend("Can you help me with something special?") }
            CompanionQuickActionChip("✨ Just chat", palette) { onSend("Just keep me company and chat with me.") }
        }

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
fun CompanionQuickActionChip(label: String, palette: DashboardPalette, onClick: () -> Unit) {
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
fun CompanionPanelContent(title: String, desc: String, palette: DashboardPalette) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Card(colors = CardDefaults.cardColors(containerColor = palette.panel), shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(title, color = palette.pink, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                Text(desc, color = palette.text, fontSize = 13.sp)
            }
        }
    }
}

@Composable
fun CompanionSettingsPanel(palette: DashboardPalette, isNightMode: Boolean, onToggleNight: (Boolean) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Card(colors = CardDefaults.cardColors(containerColor = palette.panel), shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("⚙️ COMPANION CONFIGURATION", color = palette.pink, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("🌙 Night Moonlit Scene Mode", color = palette.text)
                    Switch(
                        checked = isNightMode,
                        onCheckedChange = onToggleNight,
                        colors = SwitchDefaults.colors(checkedThumbColor = palette.pink)
                    )
                }
            }
        }
    }
}

@Composable
fun CompanionDockIcon(emoji: String, label: String, selected: Boolean, onClick: () -> Unit) {
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

data class CompanionChatMessage(val sender: String, val text: String, val isLucille: Boolean)

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
