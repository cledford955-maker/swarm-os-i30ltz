package com.swarm.lucille.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import android.graphics.Paint
import com.swarm.lucille.ui.theme.CarbonBackground
import com.swarm.lucille.ui.theme.ElectricPurple
import com.swarm.lucille.ui.theme.ElectricRed
import com.swarm.lucille.ui.theme.LightningYellow

@Composable
fun CarbonBackgroundCanvas(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "carbon_electric")
    val pulseAnim by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(4000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulse"
    )

    Canvas(modifier = modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height

        // Base Carbon Dark Fill
        drawRect(color = CarbonBackground)

        // Carbon weave diagonal crosshatch pattern
        val spacing = 28f
        var x = -h
        while (x < w + h) {
            drawLine(
                color = Color(0xFF1E2130),
                start = Offset(x, 0f),
                end = Offset(x + h, h),
                strokeWidth = 2f
            )
            drawLine(
                color = Color(0xFF151722),
                start = Offset(x, h),
                end = Offset(x + h, 0f),
                strokeWidth = 2f
            )
            x += spacing
        }

        // Ambient Electric Gradient Pulses
        val electricCenter = Offset(w * 0.5f, h * (0.2f + 0.6f * pulseAnim))
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    ElectricPurple.copy(alpha = 0.15f),
                    ElectricRed.copy(alpha = 0.08f),
                    Color.Transparent
                ),
                center = electricCenter,
                radius = w * 0.7f
            ),
            radius = w * 0.7f,
            center = electricCenter
        )

        // Persistent Diagonal App Watermark: DR. I30LTZ NATIVE CORE CODER
        val watermarkText = "DR. I30LTZ NATIVE CORE CODER"
        val paint = Paint().apply {
            color = android.graphics.Color.argb(35, 224, 64, 251) // Semi-transparent electric purple
            textSize = 34f
            isAntiAlias = true
            isFakeBoldText = true
            letterSpacing = 0.15f
        }

        drawContext.canvas.nativeCanvas.save()
        drawContext.canvas.nativeCanvas.rotate(-30f, w / 2f, h / 2f)
        
        var yPos = -h * 0.5f
        while (yPos < h * 1.5f) {
            var xPos = -w * 0.5f
            while (xPos < w * 1.5f) {
                drawContext.canvas.nativeCanvas.drawText(watermarkText, xPos, yPos, paint)
                xPos += 620f
            }
            yPos += 140f
        }
        drawContext.canvas.nativeCanvas.restore()

        // Decorative subtle lightning arc line at top right
        val arcPath = Path().apply {
            moveTo(w * 0.7f, h * 0.05f)
            lineTo(w * 0.75f, h * 0.08f + pulseAnim * 10f)
            lineTo(w * 0.72f, h * 0.11f)
            lineTo(w * 0.82f, h * 0.16f)
        }
        drawPath(
            path = arcPath,
            color = LightningYellow.copy(alpha = 0.35f + 0.15f * kotlin.math.sin(pulseAnim * 6.28f)),
            style = Stroke(width = 3f)
        )
    }
}

