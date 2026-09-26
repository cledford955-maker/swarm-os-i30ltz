// SetupScreen.kt — first-run config  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun SetupScreen(onConnect: (host: String, token: String) -> Unit) {
    var host  by remember { mutableStateOf("http://100.82.1.19:8403") }
    var token by remember { mutableStateOf("") }
    var showToken by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Void),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Logo
            Text(
                text       = "LUCILLE",
                fontSize   = 40.sp,
                fontWeight = FontWeight.Bold,
                color      = Plasma,
                letterSpacing = 4.sp
            )
            Text(
                text     = "SWARM OS · Personal Assistant",
                fontSize = 12.sp,
                color    = Smoke
            )

            Spacer(Modifier.height(24.dp))

            // Host
            OutlinedTextField(
                value         = host,
                onValueChange = { host = it },
                label         = { Text("Lucille Host", color = SmokeDim) },
                placeholder   = { Text("http://100.82.1.19:8403", color = SmokeDim) },
                modifier      = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor   = Plasma,
                    unfocusedBorderColor = SmokeDim,
                    focusedTextColor     = Filament,
                    unfocusedTextColor   = Filament,
                    cursorColor          = Arc
                ),
                singleLine = true
            )

            // Token
            OutlinedTextField(
                value         = token,
                onValueChange = { token = it },
                label         = { Text("SWARM_AUTH_TOKEN", color = SmokeDim) },
                modifier      = Modifier.fillMaxWidth(),
                visualTransformation = if (showToken) VisualTransformation.None
                                       else PasswordVisualTransformation(),
                trailingIcon  = {
                    TextButton(onClick = { showToken = !showToken }) {
                        Text(if (showToken) "Hide" else "Show", color = SmokeDim, fontSize = 11.sp)
                    }
                },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor   = Plasma,
                    unfocusedBorderColor = SmokeDim,
                    focusedTextColor     = Filament,
                    unfocusedTextColor   = Filament,
                    cursorColor          = Arc
                ),
                singleLine = true
            )

            Spacer(Modifier.height(8.dp))

            Button(
                onClick  = { if (host.isNotBlank() && token.isNotBlank()) onConnect(host.trimEnd('/'), token) },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape    = RoundedCornerShape(10.dp),
                colors   = ButtonDefaults.buttonColors(containerColor = Plasma)
            ) {
                Text("CONNECT TO LUCILLE", color = Filament, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            }

            Text(
                text     = "Token is saved locally — enter SWARM_AUTH_TOKEN from your PC's .env",
                fontSize = 11.sp,
                color    = SmokeDim,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}
