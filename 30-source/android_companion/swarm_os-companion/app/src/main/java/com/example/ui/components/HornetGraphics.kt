package com.example.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import androidx.compose.material3.Text
import com.example.ui.theme.NvidiaGreen
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws a high-detail Hornet's Nest to replace the 'O' in OS.
 */
@Composable
fun HornetNestGraphic(
    modifier: Modifier = Modifier,
    sizeDp: Int = 32
) {
    val infiniteTransition = rememberInfiniteTransition(label = "hornet_nest_anim")
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "nest_pulse"
    )

    Canvas(
        modifier = modifier
            .size((sizeDp * pulse).dp)
    ) {
        val w = size.width
        val h = size.height
        val cx = w / 2f
        val cy = h / 2f

        // Outer Glow (Purple/Gold)
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color(0xFFE040FB).copy(alpha = 0.6f), Color(0xFFFFD700).copy(alpha = 0.3f), Color.Transparent),
                center = Offset(cx, cy),
                radius = w * 0.7f
            ),
            radius = w * 0.7f
        )

        // Hornet Nest Body Layers (Swirled/Ribbed Paper Hive Structure)
        val nestColorLight = Color(0xFFD7CCC8)
        val nestColorBase = Color(0xFF8D6E63)
        val nestColorDark = Color(0xFF4E342E)
        val nestGold = Color(0xFFFFB300)

        // Nest Base Oval
        drawOval(
            brush = Brush.verticalGradient(
                colors = listOf(nestColorLight, nestColorBase, nestColorDark)
            ),
            topLeft = Offset(w * 0.15f, h * 0.1f),
            size = Size(w * 0.7f, h * 0.8f)
        )

        // Ribbed Hive Swirl Lines
        for (i in 1..5) {
            val yOffset = h * (0.15f + i * 0.12f)
            val path = Path().apply {
                moveTo(w * 0.2f, yOffset)
                quadraticTo(cx, yOffset + h * 0.1f, w * 0.8f, yOffset)
            }
            drawPath(
                path = path,
                color = nestColorDark.copy(alpha = 0.8f),
                style = Stroke(width = w * 0.05f)
            )
            drawPath(
                path = path,
                color = nestGold.copy(alpha = 0.4f),
                style = Stroke(width = w * 0.02f)
            )
        }

        // Entrance Hole (Dark Core)
        drawCircle(
            color = Color.Black,
            radius = w * 0.18f,
            center = Offset(cx, cy + h * 0.1f)
        )
        drawCircle(
            color = nestGold,
            radius = w * 0.18f,
            center = Offset(cx, cy + h * 0.1f),
            style = Stroke(width = w * 0.03f)
        )

        // Tiny Hornets Orbiting Nest
        val time = System.currentTimeMillis() / 200f
        for (i in 0..4) {
            val angle = time + i * (2 * Math.PI / 5)
            val hx = cx + cos(angle).toFloat() * (w * 0.42f)
            val hy = cy + sin(angle).toFloat() * (h * 0.42f)

            // Hornet body (Yellow/Black)
            drawCircle(color = Color(0xFFFFD54F), radius = w * 0.06f, center = Offset(hx, hy))
            drawCircle(color = Color.Black, radius = w * 0.04f, center = Offset(hx + 1f, hy))
            // Wing
            drawLine(
                color = Color.White.copy(alpha = 0.9f),
                start = Offset(hx, hy),
                end = Offset(hx - 4f, hy - 6f),
                strokeWidth = 2f
            )
        }
    }
}

/**
 * Draws animated swarming hornets over a container.
 */
@Composable
fun HornetSwarmEffect(
    modifier: Modifier = Modifier,
    hornetCount: Int = 16
) {
    val infiniteTransition = rememberInfiniteTransition(label = "hornet_swarm")
    val animTime by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween(10000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "swarm_time"
    )

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height

        for (i in 0 until hornetCount) {
            val seed = i * 1337
            val random = Random(seed)
            val baseX = random.nextFloat() * w
            val baseY = random.nextFloat() * h

            // Swarm movement physics (sinusoidal orbit + noise)
            val offsetAngle = animTime * (0.8f + (i % 5) * 0.2f) + i
            val dx = sin(offsetAngle + i).toFloat() * 30f
            val dy = cos(offsetAngle * 1.3f + i).toFloat() * 25f

            val hx = (baseX + dx).coerceIn(10f, w - 10f)
            val hy = (baseY + dy).coerceIn(10f, h - 10f)

            // Hornet Body: Abdomen, Thorax, Stripes, Wings
            // Black Abdomen
            drawOval(
                color = Color(0xFF111111),
                topLeft = Offset(hx - 6f, hy - 4f),
                size = Size(12f, 8f)
            )
            // Yellow Stripes
            drawLine(
                color = Color(0xFFFFC107),
                start = Offset(hx - 2f, hy - 4f),
                end = Offset(hx - 2f, hy + 4f),
                strokeWidth = 2f
            )
            drawLine(
                color = Color(0xFFFFC107),
                start = Offset(hx + 2f, hy - 4f),
                end = Offset(hx + 2f, hy + 4f),
                strokeWidth = 2f
            )
            // Electric Purple Stinger Glow
            drawCircle(
                color = Color(0xFFE040FB),
                radius = 2f,
                center = Offset(hx + 6f, hy)
            )
            // Translucent Wings
            val wingFlap = (sin(animTime * 15f + i) * 6f).toFloat()
            drawLine(
                color = Color.White.copy(alpha = 0.8f),
                start = Offset(hx, hy - 2f),
                end = Offset(hx - 6f, hy - 10f + wingFlap),
                strokeWidth = 2f
            )
            drawLine(
                color = Color.White.copy(alpha = 0.8f),
                start = Offset(hx, hy - 2f),
                end = Offset(hx + 6f, hy - 10f - wingFlap),
                strokeWidth = 2f
            )
        }
    }
}
