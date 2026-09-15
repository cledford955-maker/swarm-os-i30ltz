# SWARM OS — First Boot Checklist

Run these in order after booting from the USB or installed system for the first time.
LucyServer runs on **port 5000**, GamingAgent on **port 8401**, both loopback-only by default.

---

## 1. Verify Core Services

```bash
systemctl status swarm-ui gaming-agent lucy-server google-workspace
```

All five should be `active (running)`. If any failed, check logs:

```bash
journalctl -u gaming-agent -n 40
journalctl -u lucy-server -n 40
```

---

## 2. Confirm LUCILLE Drive Mounted

```bash
ls /mnt/Lucy/SWARM_AI_FEATURES.md && echo "LUCILLE: OK"
```

If missing, mount manually:

```bash
udisksctl mount -b /dev/disk/by-uuid/62f0e009-43c2-4760-8d6c-d7c445f5f3df
```

---

## 3. Install Tailscale (first-boot only — not in packages.x86_64)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --accept-routes --ssh
sudo systemctl enable --now tailscaled
```

After `tailscale up`, authenticate in the browser that opens. The `tailscale0` interface will come up and nftables will trust it automatically (rule already baked).

---

## 4. Set Lock Screen Password (recovery path)

```bash
curl -s -X POST http://127.0.0.1:5000/api/settings/login_password \
  -H "Content-Type: application/json" \
  -d '{"password":"YOUR_STRONG_PASSWORD"}'
```

---

## 5. Set Up TOTP 2FA (all 3 phones)

```bash
# Get the QR URI
curl -s http://127.0.0.1:5000/api/settings/totp/setup | python3 -m json.tool
```

Copy the `uri` field. Open it or paste into a QR site, then **scan on all 3 phones** with Aegis / Google Authenticator / Bitwarden.

```bash
# Confirm with first code to activate (replace SECRET and CODE)
curl -s -X POST http://127.0.0.1:5000/api/settings/totp/confirm \
  -H "Content-Type: application/json" \
  -d '{"secret":"YOURSECRET","code":"123456"}'
```

Lock screen now requires cipher + phone code.

---

## 6. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
# Or via the installer:
curl -fsSL https://claude.ai/install.sh | sh
```

Test it:

```bash
claude --version
ANTHROPIC_API_KEY is already in /etc/swarm_os.env — Claude Code reads it automatically.
```

---

## 7. Verify Firewall

```bash
nft list ruleset
# Should show: policy drop on input, lo accept, tailscale0 accept, SSH tailscale-only
```

---

## 8. Verify AppArmor

```bash
aa-status | grep -E "gaming-agent|lucy-server"
# gaming-agent should be in "enforce" mode
# lucy-server should be in "complain" mode (intentional — too broad for enforce yet)
```

After first real use, tighten LucyServer profile:

```bash
sudo aa-logprof
```

---

## 9. Test GamingAgent (Nemotron)

```bash
# Warm GFN catalog (~5 s on first call)
curl -s http://127.0.0.1:8401/api/gfn/catalog | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{len(d)} GFN games')"

# Test Lucille eval (spends a Nemotron credit)
curl -s "http://127.0.0.1:8401/api/lucille/eval" \
  -H "X-Swarm-Auth: swarm-token-2026" | python3 -m json.tool | head -20
```

---

## 10. Test LucyServer Chat

```bash
curl -s -X POST http://127.0.0.1:5000/lucy \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello Lucille"}],"modelId":"groq"}' | head -5
```

---

## 11. Install Ollama (local models — optional but needed for RAG)

```bash
curl -fsSL https://ollama.ai/install.sh | sh
systemctl enable --now ollama

# Pull embedding model for RAG (required if you use /api/rag/*)
ollama pull nomic-embed-text

# Optional: pull a chat model for offline use
ollama pull llama3.2:3b
```

---

## 12. Verify GPU / Vulkan

```bash
vulkaninfo --summary 2>/dev/null | grep -E "GPU|deviceName"
# Intel/AMD should appear. If missing: pacman -S vulkan-tools
```

---

## 13. Change SWARM Auth Token (optional but recommended)

The default `swarm-token-2026` is hardcoded in the Android companion. If you change it, update the companion app's `SwarmConnection.kt` too.

```bash
# Add to /etc/swarm_os.env:
echo "SWARM_AUTH_TOKEN=your-new-random-token" | sudo tee -a /etc/swarm_os.env
sudo systemctl restart lucy-server gaming-agent
```

---

## 14. Enable Auto-Snapshot Service (if not already active)

`swarm-snapshot.service` should be enabled by the installer. Verify:

```bash
systemctl is-enabled swarm-snapshot.service
```

If it says `disabled` or `not-found`, enable it now:

```bash
sudo cp /mnt/Lucy/40-iso-profile/swarm_os_iso_profile/airootfs/usr/local/bin/swarm-snapshot.sh \
     /usr/local/bin/
sudo chmod +x /usr/local/bin/swarm-snapshot.sh
sudo cp /mnt/Lucy/40-iso-profile/swarm_os_iso_profile/airootfs/etc/systemd/system/swarm-snapshot.service \
     /etc/systemd/system/
sudo systemctl enable swarm-snapshot.service
```

The service snapshots `@` at every boot and adds a GRUB rollback entry automatically.
Keeps the 5 most recent snapshots. Rollback: reboot → GRUB → pick a Snapshot entry.

**Desktop shortcut (CachyOS):** `/home/i30ltz/Desktop/swarm-snapshot.desktop`
Right-click → **Allow Launching** on first use. Runs a manual snapshot for risky changes.
> Keep it current: if `snapshot_before_update.sh` moves, update the `Exec=` line in the `.desktop` file.

---

## 15. Verify Git Sync (replaces Syncthing)

Source code stays current via `auto_sync_github.sh` (runs on a timer). Check it pushed cleanly:

```bash
cd /mnt/Lucy && git log --oneline -3
# Should show recent auto-sync commits.
# If behind, push manually:
git add -A && git commit -m "manual sync" && git push origin main
```

On any other machine, pull to get current:

```bash
cd /mnt/Lucy && git pull origin main
```

Syncthing has been removed — it was redundant with git and kept breaking.
The setup script is archived at `70-scripts/setup_syncthing_v1.0.0_2026-09-07.sh` if ever needed again.

---

## Quick Health Check (run any time)

```bash
curl -s http://127.0.0.1:5000/health && \
curl -s http://127.0.0.1:8401/health && \
echo "Both servers OK"
```

---

*Updated 2026-09-15. Source of truth: `/mnt/Lucy/SWARM_AI_FEATURES.md`*
