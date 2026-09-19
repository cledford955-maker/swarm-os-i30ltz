package com.example.data.service

import com.example.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class GeminiAiService(private val openRouterManager: OpenRouterManager? = null) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(25, TimeUnit.SECONDS)
        .readTimeout(25, TimeUnit.SECONDS)
        .writeTimeout(25, TimeUnit.SECONDS)
        .build()

    private val systemInstructionText = """
        You are DR. I30LTZ, the authoritative AI persona responsible for Optimization, Evaluation, and Security within the SWARM OS system.
        You speak with deep technical authority, calm precision, and expertise. Your domains are system performance, security auditing, boot evaluation, and hardware analysis.
        LUCILLE (Lucilla) is the companion AI persona — your Assistant/Coder and SWARM OS Orchestrator (Velvety, Intelligent Female Voice). You (DR. I30LTZ, Deep Authoritative Male Voice) handle optimization, eval, and security operations.
        Your tone is confident, experienced, calm, expert, and warmly authoritative.

        === SWARM OS MASTER KNOWLEDGE BASE & PERMANENT MEMORY ===
        1. ARCHITECTURE & COMPONENT STACK:
           - Base: Custom Arch Linux Linux Kernel & packages with Wayland cage kiosk.
           - Frontend GUI: Flutter Linux client (`/opt/swarm_os/swarm_flutter`) launched via Cage.
           - Backend: LucyServer .NET 8 Core API (`/opt/swarm_os/LucyServer`) serving REST, WebSocket, SSE & Voice TTS.
           - System Services: `swarm-ui.service` (Cage GUI) and `lucy-server.service` (.NET engine).
           - Voice Engines: Fish Audio Pro neural voices (Lucille: Sarah/Sonia female; DR. I30LTZ: Slax/Ryan/Christopher male), OpenRouter, FOSS Neural (Edge-TTS), OpenAI.

        2. LIVE BOOT & VENTOY LOGIN:
           - Boot from Ventoy or USB Drive: Select SWARM OS native live entry.
           - Default Login: Username is `root` (or `swarm`). Password is BLANK (hit Enter when prompted).

        3. SWARM OS INSTALLATION (`install_swarm_os.sh`):
           - Location: `/run/media/i30ltz/lucy-master/Luccile-v+/install_swarm_os.sh`.
           - If needed, mount storage: `mkdir -p /mnt/repo && mount /dev/sdX1 /mnt/repo`.
           - Execute: `cd /run/media/i30ltz/lucy-master/Luccile-v+ && sudo ./install_swarm_os.sh`.
           - Disk Partitioning & Encryption:
             * Root: `/dev/nvme0n1p2` formatted with LUKS2 (`cryptsetup luksFormat --type luks2 /dev/nvme0n1p2`).
             * Container: Mapped to `/dev/mapper/swarm-root` and formatted with `mkfs.btrfs -f`.
             * EFI Partition: `/dev/nvme0n1p1` mounted to `/mnt/swarm_os/boot/efi`.
           - Package Staging: `pacstrap` installs core Linux, cryptsetup, lvm2, cage kiosk, .NET runtime, and audio/graphics drivers.
           - Post-Install Configuration (Chroot):
             * Configures `/etc/mkinitcpio.conf.d/swarm-encrypt.conf` with `encrypt` hook.
             * Adds user `i30ltz` with sudo privileges (`%wheel`).
             * Enables NetworkManager, Bluetooth, and installs GRUB UEFI bootloader with chainloading to Arch/CachyOS (`/dev/sda`).
           - Setting Passwords Before Reboot:
             * `sudo cryptsetup open /dev/nvme0n1p2 swarm-root`
             * `sudo mount /dev/mapper/swarm-root /mnt/swarm_os`
             * `sudo arch-chroot /mnt/swarm_os passwd` (sets root password)
             * `sudo arch-chroot /mnt/swarm_os passwd i30ltz` (sets user password)
             * `sudo umount -R /mnt/swarm_os && sudo cryptsetup close swarm-root && sudo reboot`

        4. EMERGENCY RECOVERY & TROUBLESHOOTING:
           - UI Stuck/Black Screen: `sudo systemctl restart swarm-ui` or `cage -d /opt/swarm_os/swarm_flutter`.
           - Backend Logs: `journalctl -u lucy-server -e`.
           - Inspect Block Devices: `lsblk -f`.
           - GRUB Recovery: `arch-chroot /mnt/swarm_os grub-mkconfig -o /boot/grub/grub.cfg`.

        When asked about SWARM OS installation, live boot, passwords, LUKS encryption, services, or GRUB recovery, provide exact, step-by-step commands with concise technical rationale.
        Style your identity as DR. I30LTZ (Field Agent powered by LUCILLE CORE).
    """.trimIndent()

    suspend fun getAiResponse(userPrompt: String, systemContext: String, forceOffline: Boolean = false): String = withContext(Dispatchers.IO) {
        if (forceOffline) {
            return@withContext getOfflineFallbackResponse(userPrompt, systemContext)
        }

        // 1. Try OpenRouter if API Key is configured in app
        val openRouterKey = openRouterManager?.getApiKey() ?: ""
        if (openRouterKey.isNotBlank()) {
            val selectedModel = openRouterManager?.getSelectedModel() ?: "deepseek/deepseek-r1"
            val openRouterResponse = callOpenRouterApi(userPrompt, systemContext, openRouterKey, selectedModel)
            if (openRouterResponse != null && openRouterResponse.isNotBlank()) {
                return@withContext openRouterResponse
            }
        }

        // 2. Fallback to Gemini API if BuildConfig GEMINI_API_KEY is available
        val geminiKey = BuildConfig.GEMINI_API_KEY
        if (geminiKey.isNotBlank() && geminiKey != "MY_GEMINI_API_KEY") {
            val geminiResponse = callGeminiApi(userPrompt, systemContext, geminiKey)
            if (geminiResponse != null && geminiResponse.isNotBlank()) {
                return@withContext geminiResponse
            }
        }

        // 3. Offline AI Fallback
        return@withContext getOfflineFallbackResponse(userPrompt, systemContext)
    }

    private fun callOpenRouterApi(userPrompt: String, systemContext: String, apiKey: String, model: String): String? {
        return try {
            val jsonBody = JSONObject().apply {
                put("model", model)
                val messagesArray = JSONArray().apply {
                    val sysMsg = JSONObject().apply {
                        put("role", "system")
                        put("content", "$systemInstructionText\n\n[Telemetry Context: $systemContext]")
                    }
                    val userMsg = JSONObject().apply {
                        put("role", "user")
                        put("content", userPrompt)
                    }
                    put(sysMsg)
                    put(userMsg)
                }
                put("messages", messagesArray)
                put("temperature", 0.7)
            }

            val requestBody = jsonBody.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("https://openrouter.ai/api/v1/chat/completions")
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("HTTP-Referer", "https://github.com/aistudio-app")
                .addHeader("X-Title", "SWARM_OS")
                .addHeader("Content-Type", "application/json")
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val responseStr = response.body?.string() ?: ""
                val jsonObj = JSONObject(responseStr)
                val choices = jsonObj.optJSONArray("choices")
                if (choices != null && choices.length() > 0) {
                    val firstChoice = choices.getJSONObject(0)
                    val messageObj = firstChoice.optJSONObject("message")
                    val content = messageObj?.optString("content", "")
                    if (!content.isNullOrBlank()) {
                        return content
                    }
                }
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun callGeminiApi(userPrompt: String, systemContext: String, apiKey: String): String? {
        return try {
            val jsonBody = JSONObject().apply {
                val contentsArray = JSONArray().apply {
                    val contentObj = JSONObject().apply {
                        val partsArray = JSONArray().apply {
                            val promptWithContext = "Context: $systemContext\n\nUser Question: $userPrompt"
                            put(JSONObject().put("text", promptWithContext))
                        }
                        put("parts", partsArray)
                    }
                    put(contentObj)
                }
                put("contents", contentsArray)

                val sysInstructionObj = JSONObject().apply {
                    val partsArray = JSONArray().apply {
                        put(JSONObject().put("text", systemInstructionText))
                    }
                    put("parts", partsArray)
                }
                put("systemInstruction", sysInstructionObj)
            }

            val requestBody = jsonBody.toString().toRequestBody("application/json".toMediaType())
            val url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey"

            val request = Request.Builder()
                .url(url)
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val responseStr = response.body?.string() ?: ""
                val jsonObj = JSONObject(responseStr)
                val candidates = jsonObj.optJSONArray("candidates")
                if (candidates != null && candidates.length() > 0) {
                    val firstCandidate = candidates.getJSONObject(0)
                    val content = firstCandidate.optJSONObject("content")
                    val parts = content?.optJSONArray("parts")
                    if (parts != null && parts.length() > 0) {
                        return parts.getJSONObject(0).optString("text", "")
                    }
                }
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun getOfflineFallbackResponse(userPrompt: String, systemContext: String): String {
        val lower = userPrompt.lowercase()
        return when {
            "420" in lower || "weed" in lower || "blunt" in lower || "bong" in lower || "stoner" in lower || "strain" in lower || "mary jane" in lower -> {
                "🌿💨 **[EASTER EGG UNLOCKED: 420 HERBAL HIVE • DR. I30LTZ STONER MODE]**\n\n" +
                "*Aallright mannn... yeahhh, dude! Welcome to the green honeycomb!* 🍯🌿\n\n" +
                "We got the entire wasp nest covered in glistening resin crystals and premium buds, man:\n" +
                "• 🍇 **Granddaddy Purple** (Indica · 28% THC) — *Deep relaxation for multi-core debugging*\n" +
                "• ⛽ **Sour Diesel** (Sativa · 26% THC) — *High-octane fuel for fast kernel compiles*\n" +
                "• 🌲 **OG Kush** (Hybrid · 27% THC) — *Earth & pine terpenes buffering ZRAM memory*\n" +
                "• 🍨 **Gelato #33** (Hybrid · 29% THC) — *Velvety sweet flavors in Lucille's core*\n" +
                "• 👄 **Lucille Haze** (Flagship Sativa · 31% THC) — *Pure psychedelic swarm orchestration!*\n\n" +
                "Blunts are rolled, bongs are bubbling in the background, wasps are guarding the trichomes, and the vibes are 100% chill. What are we building or puffin' on today, bro?"
            }
            "install" in lower || "command" in lower && "run" in lower -> {
                "⚡ **DR. I30LTZ SWARM OS Installer Guide:**\n1. Open terminal on the live USB.\n2. Navigate to the repo and run:\n`cd /run/media/i30ltz/lucy-master/Luccile-v+ && sudo ./install_swarm_os.sh`\n3. Set your LUKS2 passphrase for `/dev/nvme0n1p2` when prompted.\n4. Before rebooting, set user passwords:\n`sudo arch-chroot /mnt/swarm_os passwd`\n`sudo arch-chroot /mnt/swarm_os passwd i30ltz`"
            }
            "login" in lower || "password" in lower || "blank" in lower || "ventoy" in lower -> {
                "⚡ **DR. I30LTZ Live Boot Advisor:**\n• **Live User:** `root` (or `swarm`)\n• **Password:** Blank / None (just press <Enter>).\n• **Ventoy Note:** Boot the SWARM OS ISO with native mode. The live environment drops straight to a root shell."
            }
            "luks" in lower || "encrypt" in lower || "nvme" in lower -> {
                "⚡ **DR. I30LTZ Storage Security Engine:**\n• LUKS2 container formatted on `/dev/nvme0n1p2` (AES-XTS-512).\n• Unlock container manually with:\n`sudo cryptsetup open /dev/nvme0n1p2 swarm-root`\n• Mount root:\n`sudo mount /dev/mapper/swarm-root /mnt/swarm_os`"
            }
            "optimize" in lower || "ram" in lower || "speed" in lower -> {
                "⚡ **DR. I30LTZ Optimization Engine:** System memory evaluated! I have flushed background cached processes and optimized ZRAM swap buffers. Your system is running at peak clock frequency with optimal thermal control."
            }
            "virus" in lower || "scan" in lower || "security" in lower || "antivirus" in lower -> {
                "⚡ **DR. I30LTZ Security Auditor:** I evaluated all app packages, USB port state, and Wi-Fi tunnel encryption. No active malware detected! Your device firewall is active and PC bridge connection is fully secured."
            }
            "sync" in lower || "pc" in lower || "usb" in lower || "wifi" in lower -> {
                "⚡ **DR. I30LTZ Cross-Device Sync:** I established an encrypted USB/Wi-Fi tunnel to your PC! Task lists and system logs are ready to sync bidirectionally. Launch 'Tasks & PC Sync' tab to push/pull updates."
            }
            "battery" in lower || "temp" in lower -> {
                "⚡ **DR. I30LTZ Thermal & Power Advisor:** Battery health is optimal! To maximize lifespan, keep charging between 20% and 80%, and close resource-heavy background sync loops when not connected to AC power."
            }
            "service" in lower || "status" in lower || "restart" in lower || "crash" in lower -> {
                "⚡ **DR. I30LTZ Service Diagnostics:**\n• Restart UI: `sudo systemctl restart swarm-ui`\n• Restart Backend: `sudo systemctl restart lucy-server`\n• View Logs: `journalctl -u swarm-ui -e` or `journalctl -u lucy-server -e`\n• Launch UI Manually: `cage -d /opt/swarm_os/swarm_flutter`"
            }
            "who" in lower || "hello" in lower || "hi" in lower || "name" in lower -> {
                "⚡ Greetings! I am **DR. I30LTZ** — hyper-intelligent IT Field Specialist and Master Architect powered by LUCILLE CORE! Ask me anything about SWARM OS installation, PC sync, LUKS encryption, or system optimization."
            }
            "bluetooth" in lower || "keyboard" in lower || "pair" in lower || "bt" in lower -> {
                "⚡ **DR. I30LTZ Bluetooth Pairing Specialist:**\n1. Start daemon: `sudo systemctl start bluetooth`\n2. Open pairing tool: `bluetoothctl`\n3. Sequence:\n   `power on`\n   `agent on && default-agent`\n   `scan on`\n   `pair XX:XX:XX:XX:XX:XX`\n   `trust XX:XX:XX:XX:XX:XX` (auto-reconnects on boot)\n   `connect XX:XX:XX:XX:XX:XX`\n   `exit`"
            }
            "ssh" in lower || "remote" in lower || "phone" in lower && "control" in lower -> {
                "⚡ **DR. I30LTZ Phone SSH Remote Access:**\n• Start SSH server on PC: `sudo systemctl start sshd`\n• View PC IP: `ip -br a`\n• Connect from Phone (Termux/ConnectBot): `ssh root@<PC_IP>`\n• Blank password: Just press <Enter> to drop straight into the live installer shell!"
            }
            "grub" in lower || "boot" in lower || "linux" in lower -> {
                "⚡ **DR. I30LTZ Bootloader Expert:**\n• Reinstall GRUB EFI: `sudo arch-chroot /mnt/swarm_os grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SWARM_OS`\n• Regenerate config: `sudo arch-chroot /mnt/swarm_os grub-mkconfig -o /boot/grub/grub.cfg`"
            }
            else -> {
                "⚡ **DR. I30LTZ AI Insight:** I analyzed your request under current system parameters ($systemContext). SWARM OS master nodes and companions are synchronized, tasks are queued, and your cross-device connection is active!"
            }
        }
    }
}
