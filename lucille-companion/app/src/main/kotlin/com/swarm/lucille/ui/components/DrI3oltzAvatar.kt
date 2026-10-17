package com.swarm.lucille.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ElectricBolt
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.ui.theme.*

@Composable
fun DrI3oltzAvatar(
    isSpeaking: Boolean = false,
    speechText: String? = null,
    onAvatarClick: () -> Unit = {}
) {
    val infiniteTransition = rememberInfiniteTransition(label = "avatar_anim")
    val energyRotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(6000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    val eyeGlowPulse by infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "eye_glow"
    )

    val floatScale by infiniteTransition.animateFloat(
        initialValue = 0.97f,
        targetValue = 1.03f,
        animationSpec = infiniteRepeatable(
            animation = tween(1800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "float"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    ) {
        // Speech Bubble if active
        if (!speechText.isNullOrBlank()) {
            val textToDisplay = speechText ?: ""
            Box(
                modifier = Modifier
                    .padding(horizontal = 24.dp, vertical = 8.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(
                                CarbonSurfaceVariant.copy(alpha = 0.95f),
                                CarbonSurface.copy(alpha = 0.95f)
                            )
                        )
                    )
                    .border(
                        1.5.dp,
                        Brush.horizontalGradient(
                            listOf(ElectricPurple, ElectricRed)
                        ),
                        RoundedCornerShape(16.dp)
                    )
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (isSpeaking) {
                        Icon(
                            imageVector = Icons.Default.VolumeUp,
                            contentDescription = "Speaking",
                            tint = LightningYellow,
                            modifier = Modifier
                                .size(20.dp)
                                .padding(end = 6.dp)
                        )
                    }
                    Text(
                        text = textToDisplay,
                        color = TextPrimary,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }

            // Main 3D Vector Animated Avatar Core
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(170.dp)
                    .scale(floatScale)
                    .clickable { onAvatarClick() }
            ) {
                // Background Electric Aura Particle Rings
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val center = Offset(size.width / 2f, size.height / 2f)
                    val radius = size.width * 0.44f

                    // Outer Glowing Purple/Red Shield Ring
                    drawCircle(
                        brush = Brush.sweepGradient(
                            colors = listOf(
                                ElectricPurple,
                                ElectricRed,
                                LightningYellow,
                                ElectricCyan,
                                ElectricPurple
                            ),
                            center = center
                        ),
                        radius = radius,
                        center = center,
                        style = Stroke(width = 4f)
                    )

                    // Inner Electric Energy Arc Ring
                    drawCircle(
                        color = ElectricPurple.copy(alpha = 0.25f),
                        radius = radius * 0.88f,
                        center = center
                    )
                }

                // New DR. I30LTZ Avatar
                com.swarm.lucille.ui.screens.DrI3oltzSmallAvatar(size = 110)

                // Name Tag Badge Overlay
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .offset(y = 8.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF0F101A))
                        .border(1.dp, LightningYellow, RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 3.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "DR. I30LTZ",
                            color = TextPrimary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Icon(
                            imageVector = Icons.Default.MedicalServices,
                            contentDescription = "Medical",
                            tint = LightningYellow,
                            modifier = Modifier.size(13.dp)
                        )
                    }
                }
            }
    }
}
