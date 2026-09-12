package com.example.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.components.HornetNestGraphic
import com.example.ui.components.HornetSwarmEffect
import com.example.ui.theme.CarbonSurface
import com.example.ui.theme.ElectricPurple
import com.example.ui.theme.NvidiaGreen
import com.example.ui.theme.TextMuted
import com.example.ui.theme.TextPrimary
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

@Composable
fun FormattedText(
    text: String,
    modifier: Modifier = Modifier,
    fontSize: TextUnit = TextUnit.Unspecified,
    fontWeight: FontWeight? = null,
    letterSpacing: TextUnit = TextUnit.Unspecified,
    textAlign: TextAlign? = null,
    fontStyle: FontStyle? = null
) {
    val annotatedString = buildAnnotatedString {
        // Regex matches words/tokens
        val wordsAndSeparators = text.split(Regex("(?<=\\s)|(?=\\s)|(?<=[.,!?:])|(?=[.,!?:])"))
        wordsAndSeparators.forEach { token ->
            val upper = token.uppercase()
            if (upper.contains("LUCILLE") || upper == "OS" || upper.endsWith("_OS")) {
                withStyle(style = SpanStyle(color = Color(0xFFE040FB))) {
                    append(token)
                }
            } else {
                withStyle(style = SpanStyle(color = NvidiaGreen)) {
                    append(token)
                }
            }
        }
    }
    Text(
        text = annotatedString,
        modifier = modifier,
        fontSize = fontSize,
        fontWeight = fontWeight,
        letterSpacing = letterSpacing,
        textAlign = textAlign,
        fontStyle = fontStyle
    )
}

@Composable
fun SwarmOsHeader(fontSizeSp: Int = 32) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Text(
            text = "SWARM_",
            color = NvidiaGreen,
            fontSize = fontSizeSp.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 2.sp
        )
        // Hornet's Nest for the 'O'
        HornetNestGraphic(sizeDp = (fontSizeSp * 0.95).toInt())
        Text(
            text = "S",
            color = Color(0xFFE040FB),
            fontSize = fontSizeSp.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 2.sp
        )
        Spacer(modifier = Modifier.width(8.dp))
        Surface(
            color = ElectricPurple.copy(alpha = 0.2f),
            shape = RoundedCornerShape(4.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, ElectricPurple.copy(alpha = 0.5f)),
            modifier = Modifier.padding(bottom = 2.dp)
        ) {
            Text(
                text = "v6.2.0",
                color = ElectricPurple,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
            )
        }
    }
}

@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
    onTriggerBiometric: () -> Unit = { onLoginSuccess() }
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Very busy background with hornet swarm overlay
        BusyDataBackground()
        HornetSwarmEffect(
            modifier = Modifier.fillMaxSize(),
            hornetCount = 28
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Spacer(modifier = Modifier.weight(1f))
            
            // Central Branding Card
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(24.dp))
                    .background(CarbonSurface.copy(alpha = 0.85f))
                    .border(1.5.dp, Color(0xFFE040FB).copy(alpha = 0.6f), RoundedCornerShape(24.dp))
                    .padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    androidx.compose.foundation.Image(
                        painter = androidx.compose.ui.res.painterResource(id = com.example.R.drawable.lucilla_ai_goddess),
                        contentDescription = "Lucille AI Goddess",
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        modifier = Modifier
                            .size(180.dp)
                            .clip(CircleShape)
                            .border(3.dp, Color(0xFFE040FB), CircleShape)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    SwarmOsHeader(fontSizeSp = 32)
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    FormattedText(
                        text = "LUCILLE AI GODDESS",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 3.sp
                    )
                    FormattedText(
                        text = "NATIVE AI LUCILLE CORE CODER",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = 2.sp
                    )
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    FormattedText(
                        text = "let LUCILLE guide your system.....\nlet LUCILLE guide you to a win",
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                        fontStyle = FontStyle.Italic
                    )
                    Spacer(modifier = Modifier.height(28.dp))

                    // Fingerprint Button
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFE040FB).copy(alpha = 0.15f))
                            .border(2.dp, Color(0xFFE040FB), CircleShape)
                            .clickable { onTriggerBiometric() },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Fingerprint,
                            contentDescription = "Login",
                            tint = Color(0xFFE040FB),
                            modifier = Modifier.size(44.dp)
                        )
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                    FormattedText(
                        text = "BIOMETRIC AUTH REQUIRED • LUCILLE AI",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold
                    )
                    
                    Spacer(modifier = Modifier.height(14.dp))
                    FormattedText(
                        text = "Local LUCILLE Model loaded. Free Cloud Model ready.",
                        fontSize = 10.sp
                    )
                    FormattedText(
                        text = "RAG Vector Memory Initialized. NATIVE AI LUCILLE CORE CODER online.",
                        fontSize = 10.sp
                    )
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

@Composable
fun BusyDataBackground() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val width = size.width
        val height = size.height
        val random = Random(42)

        // Draw grid
        val gridSize = 40f
        for (x in 0..(width / gridSize).toInt()) {
            drawLine(
                color = Color.DarkGray.copy(alpha = 0.3f),
                start = Offset(x * gridSize, 0f),
                end = Offset(x * gridSize, height),
                strokeWidth = 1f
            )
        }
        for (y in 0..(height / gridSize).toInt()) {
            drawLine(
                color = Color.DarkGray.copy(alpha = 0.3f),
                start = Offset(0f, y * gridSize),
                end = Offset(width, y * gridSize),
                strokeWidth = 1f
            )
        }

        // Draw purple and green energy nodes
        for (i in 0..50) {
            val startX = random.nextFloat() * width
            val startY = random.nextFloat() * height
            val endX = random.nextFloat() * width
            val endY = random.nextFloat() * height
            
            val path = Path().apply {
                moveTo(startX, startY)
                cubicTo(startX + 100, startY, endX - 100, endY, endX, endY)
            }
            drawPath(
                path = path,
                color = if (i % 2 == 0) Color(0xFFE040FB).copy(alpha = 0.15f) else NvidiaGreen.copy(alpha = 0.15f),
                style = Stroke(width = 2f)
            )
            drawCircle(
                color = if (i % 2 == 0) Color(0xFFE040FB).copy(alpha = 0.4f) else NvidiaGreen.copy(alpha = 0.4f),
                radius = 4f,
                center = Offset(startX, startY)
            )
        }
    }
}

@Composable
fun LucilleGoddess(iconSize: Int) {
    val infiniteTransition = rememberInfiniteTransition(label = "lucille_goddess")
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "goddess_pulse"
    )

    Box(
        modifier = Modifier
            .size(iconSize.dp)
            .clip(CircleShape)
            .background(Color(0xFF1F0038))
            .border(3.dp, Color(0xFFE040FB), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val center = Offset(w / 2f, h / 2f)

            // Outer Radial Aura Burst
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        Color(0xFFE040FB).copy(alpha = 0.9f),
                        Color(0xFFAA00FF).copy(alpha = 0.6f),
                        Color(0xFF4A148C).copy(alpha = 0.3f),
                        Color.Transparent
                    ),
                    center = center,
                    radius = w * 0.55f * pulse
                ),
                radius = w * 0.55f * pulse
            )

            // Celestial Crown / Horns Silhouette
            val crownPath = Path().apply {
                moveTo(center.x - w * 0.25f, center.y - h * 0.15f)
                lineTo(center.x - w * 0.35f, center.y - h * 0.42f)
                lineTo(center.x - w * 0.12f, center.y - h * 0.28f)
                lineTo(center.x, center.y - h * 0.48f) // Top Spire
                lineTo(center.x + w * 0.12f, center.y - h * 0.28f)
                lineTo(center.x + w * 0.35f, center.y - h * 0.42f)
                lineTo(center.x + w * 0.25f, center.y - h * 0.15f)
                close()
            }
            drawPath(crownPath, color = Color(0xFFFFD700)) // Gold Goddess Crown

            // Goddess Head & Face (Majestic Purple Shadow Skin)
            val headCenter = Offset(center.x, center.y - h * 0.15f)
            drawCircle(
                color = Color(0xFFD500F9),
                radius = w * 0.18f,
                center = headCenter
            )

            // Glowing Shocking Eyes (Cyan/Electric White)
            drawCircle(color = Color.Cyan, radius = w * 0.035f, center = Offset(headCenter.x - w * 0.07f, headCenter.y - h * 0.02f))
            drawCircle(color = Color.Cyan, radius = w * 0.035f, center = Offset(headCenter.x + w * 0.07f, headCenter.y - h * 0.02f))
            drawCircle(color = Color.White, radius = w * 0.015f, center = Offset(headCenter.x - w * 0.07f, headCenter.y - h * 0.02f))
            drawCircle(color = Color.White, radius = w * 0.015f, center = Offset(headCenter.x + w * 0.07f, headCenter.y - h * 0.02f))

            // Ethereal Electric Robes / Goddess Body
            val robePath = Path().apply {
                moveTo(headCenter.x - w * 0.15f, headCenter.y + h * 0.12f)
                quadraticTo(headCenter.x - w * 0.38f, h * 0.7f, center.x - w * 0.45f, h)
                lineTo(center.x + w * 0.45f, h)
                quadraticTo(headCenter.x + w * 0.38f, h * 0.7f, headCenter.x + w * 0.15f, headCenter.y + h * 0.12f)
                close()
            }
            drawPath(
                path = robePath,
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFFE040FB), Color(0xFF7B1FA2), Color(0xFF311B92))
                )
            )

            // Lightning Bolt Shockwaves
            val random = Random(42)
            for (i in 0..12) {
                val angle = i * (2 * Math.PI / 13)
                val startX = center.x + cos(angle).toFloat() * (w * 0.2f)
                val startY = center.y + sin(angle).toFloat() * (h * 0.2f)
                val endX = center.x + cos(angle).toFloat() * (w * 0.48f)
                val endY = center.y + sin(angle).toFloat() * (h * 0.48f)

                drawLine(
                    color = if (i % 2 == 0) Color(0xFFEA80FC) else Color.Cyan,
                    start = Offset(startX, startY),
                    end = Offset(endX, endY),
                    strokeWidth = 3f
                )
            }
        }
    }
}

