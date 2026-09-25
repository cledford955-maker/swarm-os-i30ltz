package com.example.ui.hitl

import android.os.Bundle
import android.widget.Toast
import androidx.activity.compose.setContent
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.example.data.hitl.HitlApprovalService
import com.example.ui.theme.CarbonBackground
import com.example.ui.theme.CarbonSurfaceVariant
import com.example.ui.theme.ElectricRed
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.theme.NvidiaGreen
import com.example.ui.theme.TextPrimary
import kotlinx.coroutines.delay

/**
 * Review screen for one SWARM approval request. Deny is immediate; Approve
 * requires the phone's biometric or screen lock, so a lost unlocked phone or
 * a stray tap on a notification can't approve a destructive command.
 */
class HitlApprovalActivity : FragmentActivity() {

    private val authenticators =
        BiometricManager.Authenticators.BIOMETRIC_STRONG or
        BiometricManager.Authenticators.BIOMETRIC_WEAK or
        BiometricManager.Authenticators.DEVICE_CREDENTIAL

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent.getStringExtra(HitlApprovalService.EXTRA_CHALLENGE_ID)
        if (id.isNullOrEmpty()) { finish(); return }
        val command = intent.getStringExtra(HitlApprovalService.EXTRA_COMMAND).orEmpty()
        val risk = intent.getStringExtra(HitlApprovalService.EXTRA_RISK) ?: "HIGH"
        val expiresAt = intent.getLongExtra(HitlApprovalService.EXTRA_EXPIRES_AT, 0L)

        setContent {
            MyApplicationTheme {
                ApprovalScreen(
                    command = command,
                    risk = risk,
                    expiresAtSec = expiresAt,
                    onDeny = {
                        HitlApprovalService.respond(this, id, approved = false)
                        finish()
                    },
                    onApprove = { confirmThenApprove(id) },
                    onExpired = {
                        Toast.makeText(this, "Request expired — SWARM treated it as denied.", Toast.LENGTH_LONG).show()
                        finish()
                    }
                )
            }
        }
    }

    private fun confirmThenApprove(id: String) {
        if (BiometricManager.from(this).canAuthenticate(authenticators) != BiometricManager.BIOMETRIC_SUCCESS) {
            // No screen lock = no way to prove it's you; refuse rather than approve
            Toast.makeText(this, "Set an Android screen lock to approve SWARM actions from this phone.", Toast.LENGTH_LONG).show()
            return
        }
        val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    HitlApprovalService.respond(this@HitlApprovalActivity, id, approved = true)
                    finish()
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    Toast.makeText(this@HitlApprovalActivity, errString, Toast.LENGTH_SHORT).show()
                }
            })
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Approve SWARM action")
                .setSubtitle("Confirm it's you")
                .setAllowedAuthenticators(authenticators)
                .build()
        )
    }
}

@Composable
private fun ApprovalScreen(
    command: String,
    risk: String,
    expiresAtSec: Long,
    onDeny: () -> Unit,
    onApprove: () -> Unit,
    onExpired: () -> Unit,
) {
    var secondsLeft by remember { mutableLongStateOf(expiresAtSec - System.currentTimeMillis() / 1000) }
    LaunchedEffect(expiresAtSec) {
        if (expiresAtSec <= 0) return@LaunchedEffect
        while (true) {
            secondsLeft = expiresAtSec - System.currentTimeMillis() / 1000
            if (secondsLeft <= 0) { onExpired(); break }
            delay(1000)
        }
    }
    val riskColor = if (risk == "CRITICAL") ElectricRed else Color(0xFFFFB300)

    Surface(modifier = Modifier.fillMaxSize(), color = CarbonBackground) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text("SWARM wants approval", color = TextPrimary, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Text(
                risk + if (expiresAtSec > 0) " · expires in ${secondsLeft.coerceAtLeast(0)}s" else "",
                color = riskColor, fontSize = 13.sp, fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(16.dp))
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurfaceVariant),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    command,
                    color = Color.White, fontFamily = FontFamily.Monospace, fontSize = 13.sp,
                    modifier = Modifier.padding(12.dp)
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "No answer before it expires counts as denied.",
                color = TextPrimary.copy(alpha = 0.7f), fontSize = 12.sp
            )
            Spacer(Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(onClick = onDeny, modifier = Modifier.weight(1f)) {
                    Text("Deny", color = ElectricRed, fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = onApprove,
                    colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen),
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Approve…", color = Color.Black, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
