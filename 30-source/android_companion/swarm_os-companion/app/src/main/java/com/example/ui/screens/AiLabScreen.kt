package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.db.AIChatEntity
import com.example.data.service.OpenRouterManager
import com.example.ui.theme.*

@Composable
fun AiLabScreen(
    chatMessages: List<AIChatEntity>,
    isSpeaking: Boolean,
    isMuted: Boolean,
    openRouterApiKey: String = "",
    selectedOpenRouterModel: String = "deepseek/deepseek-r1",
    onSendMessage: (String) -> Unit,
    onToggleMute: () -> Unit,
    onSaveOpenRouterKey: (String) -> Unit = {},
    onSaveOpenRouterModel: (String) -> Unit = {},
    onClearOpenRouterKey: () -> Unit = {}
) {
    var inputText by remember { mutableStateOf("") }
    var isConfigExpanded by remember { mutableStateOf(openRouterApiKey.isBlank()) }
    var keyInput by remember { mutableStateOf(openRouterApiKey) }
    var showKeyText by remember { mutableStateOf(false) }

    LaunchedEffect(openRouterApiKey) {
        keyInput = openRouterApiKey
    }

    val quickPrompts = listOf(
        "⚡ Optimize RAM & ZRAM",
        "🛡️ Run Antivirus Scan",
        "💻 Check PC Bridge",
        "🔋 Battery Health Check"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
    ) {
        // Top Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "DR. I30LTZ Command Lab",
                        color = TextPrimary,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Default.ElectricBolt,
                        contentDescription = "Icon",
                        tint = LightningYellow,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    text = "Optimization · Eval · Security (Wise Male)",
                    color = TextSecondary,
                    fontSize = 10.sp
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                if (isSpeaking) {
                    Text(
                        text = "SPEAKING...",
                        color = LightningYellow,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 8.dp)
                    )
                }

                IconButton(
                    onClick = onToggleMute,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(CarbonSurfaceVariant)
                        .border(1.dp, CarbonBorder, CircleShape)
                        .testTag("ai_voice_mute_button")
                ) {
                    Icon(
                        imageVector = if (isMuted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp,
                        contentDescription = "Mute",
                        tint = if (isMuted) TextMuted else LightningYellow
                    )
                }
            }
        }

        // OpenRouter API & Swarm Models Config Card
        Card(
            colors = CardDefaults.cardColors(containerColor = CarbonSurface),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 10.dp)
                .border(1.dp, if (openRouterApiKey.isNotBlank()) NvidiaGreen.copy(alpha = 0.5f) else CarbonBorder, RoundedCornerShape(14.dp))
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { isConfigExpanded = !isConfigExpanded },
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.VpnKey,
                            contentDescription = "API Key",
                            tint = if (openRouterApiKey.isNotBlank()) NvidiaGreen else LightningYellow,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = "OpenRouter Swarm Engine",
                                color = TextPrimary,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = if (openRouterApiKey.isNotBlank()) "Selected: $selectedOpenRouterModel" else "Tap to set personal OpenRouter Key",
                                color = if (openRouterApiKey.isNotBlank()) NvidiaGreen else TextMuted,
                                fontSize = 11.sp
                            )
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            color = if (openRouterApiKey.isNotBlank()) NvidiaGreen.copy(alpha = 0.15f) else ElectricPurple.copy(alpha = 0.15f),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text(
                                text = if (openRouterApiKey.isNotBlank()) "SAVED" else "CONFIG",
                                color = if (openRouterApiKey.isNotBlank()) NvidiaGreen else ElectricPurple,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(6.dp))
                        Icon(
                            imageVector = if (isConfigExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                            contentDescription = "Toggle",
                            tint = TextMuted
                        )
                    }
                }

                AnimatedVisibility(visible = isConfigExpanded) {
                    Column(modifier = Modifier.padding(top = 12.dp)) {
                        Text(
                            text = "Enter your OpenRouter API Key (sk-or-v1-...). Stored strictly in local app memory and never committed to Git/source code:",
                            color = TextSecondary,
                            fontSize = 11.sp,
                            lineHeight = 15.sp
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        OutlinedTextField(
                            value = keyInput,
                            onValueChange = { keyInput = it },
                            placeholder = { Text("sk-or-v1-...", fontSize = 12.sp, color = TextMuted) },
                            singleLine = true,
                            visualTransformation = if (showKeyText) VisualTransformation.None else PasswordVisualTransformation(),
                            trailingIcon = {
                                IconButton(onClick = { showKeyText = !showKeyText }) {
                                    Icon(
                                        imageVector = if (showKeyText) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                        contentDescription = "Toggle key visibility",
                                        tint = TextMuted
                                    )
                                }
                            },
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = ElectricPurple,
                                unfocusedBorderColor = CarbonBorder,
                                focusedContainerColor = CarbonSurfaceVariant,
                                unfocusedContainerColor = CarbonSurfaceVariant,
                                focusedTextColor = TextPrimary,
                                unfocusedTextColor = TextPrimary
                            ),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("openrouter_key_input")
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            if (openRouterApiKey.isNotBlank()) {
                                OutlinedButton(
                                    onClick = {
                                        keyInput = ""
                                        onClearOpenRouterKey()
                                    },
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = ElectricRed),
                                    border = ButtonDefaults.outlinedButtonBorder.copy(brush = androidx.compose.ui.graphics.SolidColor(ElectricRed)),
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.padding(end = 8.dp)
                                ) {
                                    Text("CLEAR KEY", fontSize = 11.sp)
                                }
                            }

                            Button(
                                onClick = {
                                    onSaveOpenRouterKey(keyInput)
                                    isConfigExpanded = false
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = ElectricPurple),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("SAVE KEY", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Spacer(modifier = Modifier.height(10.dp))

                        Text(
                            text = "⚡ AI SWARM CONSENSUS FLEET (Kimi + Qwen Coder + GLM-4 + DeepSeek):",
                            color = Color(0xFFE040FB),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.ExtraBold
                        )

                        Spacer(modifier = Modifier.height(6.dp))

                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            items(OpenRouterManager.AVAILABLE_MODELS) { (modelId, label) ->
                                val isSelected = modelId == selectedOpenRouterModel
                                FilterChip(
                                    selected = isSelected,
                                    onClick = { onSaveOpenRouterModel(modelId) },
                                    label = { Text(label, fontSize = 10.sp) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = ElectricPurple,
                                        selectedLabelColor = Color.White,
                                        containerColor = CarbonSurfaceVariant,
                                        labelColor = TextPrimary
                                    )
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Surface(
                            color = NvidiaGreen.copy(alpha = 0.15f),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.border(1.dp, NvidiaGreen.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column {
                                    Text("OFFLINE AI", color = NvidiaGreen, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                    Text("No inference runtime or GGUF model installed", color = TextMuted, fontSize = 9.sp)
                                }
                                Surface(
                                    color = NvidiaGreen,
                                    shape = RoundedCornerShape(6.dp)
                                ) {
                                    Text("UNAVAILABLE", color = Color.Black, fontSize = 9.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
                                }
                            }
                        }
                    }
                }
            }
        }

        // Quick Prompt Chips
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 8.dp)
        ) {
            items(quickPrompts) { prompt ->
                SuggestionChip(
                    onClick = { onSendMessage(prompt) },
                    label = { Text(prompt, fontSize = 11.sp) },
                    colors = SuggestionChipDefaults.suggestionChipColors(
                        containerColor = CarbonSurface,
                        labelColor = TextPrimary
                    ),
                    border = SuggestionChipDefaults.suggestionChipBorder(
                        enabled = true,
                        borderColor = CarbonBorder
                    )
                )
            }
        }

        // Chat Log List
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(vertical = 8.dp)
        ) {
            if (chatMessages.isEmpty()) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(
                            modifier = Modifier.padding(20.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(
                                imageVector = Icons.Default.Psychology,
                                contentDescription = "AI",
                                tint = ElectricPurple,
                                modifier = Modifier.size(44.dp)
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = "Ask DR. I30LTZ anything about system optimization, PC sync, or antivirus protection!",
                                color = TextSecondary,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            } else {
                items(chatMessages, key = { it.id }) { msg ->
                    ChatMessageBubble(msg = msg)
                }
            }
        }

        // Input Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 80.dp, top = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = inputText,
                onValueChange = { inputText = it },
                placeholder = { Text("Command DR. I30LTZ...", fontSize = 13.sp, color = TextMuted) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = ElectricPurple,
                    unfocusedBorderColor = CarbonBorder,
                    focusedContainerColor = CarbonSurface,
                    unfocusedContainerColor = CarbonSurface,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary
                ),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .weight(1f)
                    .testTag("ai_chat_input")
            )

            Spacer(modifier = Modifier.width(8.dp))

            IconButton(
                onClick = {
                    if (inputText.isNotBlank()) {
                        onSendMessage(inputText)
                        inputText = ""
                    }
                },
                modifier = Modifier
                    .size(50.dp)
                    .clip(CircleShape)
                    .background(ElectricPurple)
                    .testTag("send_ai_message_button")
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    tint = Color.White
                )
            }
        }
    }
}

@Composable
private fun ChatMessageBubble(msg: AIChatEntity) {
    val isUser = msg.sender == "USER"

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 2.dp)
        ) {
            Text(
                text = if (isUser) "You" else "DR. I30LTZ⚡",
                color = if (isUser) TextSecondary else LightningYellow,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold
            )
        }

        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(
                    RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isUser) 16.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 16.dp
                    )
                )
                .background(if (isUser) ElectricPurpleDark else CarbonSurface)
                .border(
                    1.dp,
                    if (isUser) ElectricPurple else CarbonBorder,
                    RoundedCornerShape(16.dp)
                )
                .padding(12.dp)
        ) {
            Text(
                text = msg.message,
                color = TextPrimary,
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
    }
}
