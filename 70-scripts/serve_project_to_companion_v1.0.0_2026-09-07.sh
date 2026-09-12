#!/usr/bin/env bash
# =============================================================================
#  serve_project_to_companion  —  expose LucyServer to the SWARM Companion IDE
#  Script version : 1.0.0            Date: 2026-09-07
#
#  The Companion does NOT read synced files. It talks HTTP + WebSocket to
#  LucyServer on port 5000 and browses the project through /api/fs.
#  This script binds the server so the phones can reach it, with a real
#  auth token instead of the hardcoded default.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRIVE_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$DRIVE_ROOT/20-runtime/LucyServer"
PROJECT_ROOT="${PROJECT_ROOT:-$DRIVE_ROOT/30-source}"
PORT="${PORT:-5000}"
TOKEN_FILE="$HOME/Documents/.swarm_auth_token"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
die() { echo -e "${RED}FATAL: $*${NC}" >&2; exit 1; }

[ -f "$SERVER_DIR/LucyServer.dll" ] || die "LucyServer.dll not found in $SERVER_DIR"
command -v dotnet >/dev/null || die "dotnet runtime not found (needs ASP.NET Core 10)"

# ── Auth token: never ship the hardcoded default ────────────────────────────
if [ ! -f "$TOKEN_FILE" ]; then
  umask 077
  head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32 > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo -e "${GREEN}Generated a new auth token at $TOKEN_FILE${NC}"
fi
SWARM_AUTH_TOKEN="$(cat "$TOKEN_FILE")"
[ "$SWARM_AUTH_TOKEN" = "swarm-token-2026" ] && die "refusing to start with the default token"

# ── Pick the transport: Tailscale preferred, LAN with a warning ─────────────
TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
LAN_IP="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)"

if [ -n "$TS_IP" ]; then
  BIND_IP="$TS_IP"; TARGET_IP="$TS_IP"; MODE="Tailscale (encrypted, device-scoped)"
else
  BIND_IP="0.0.0.0"; TARGET_IP="${LAN_IP:-THIS-MACHINE-IP}"; MODE="OPEN WiFi LAN"
  echo -e "\n${RED}${BOLD}  WARNING — no Tailscale interface found.${NC}"
  echo -e "${YELLOW}  Binding to 0.0.0.0 exposes /api/run_command and /api/terminal/ws${NC}"
  echo -e "${YELLOW}  (arbitrary shell execution) to every device on this network.${NC}"
  echo -e "${YELLOW}  The token below is the only thing standing in the way.${NC}"
  echo -e "${YELLOW}  Strongly prefer: sudo tailscale up   then re-run this script.${NC}\n"
  read -r -p "  Continue on open WiFi anyway? [y/N] " ok
  [[ "$ok" =~ ^[Yy]$ ]] || exit 1
fi

echo -e "\n${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  SWARM Companion bridge — LucyServer${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "  transport    : ${BOLD}$MODE${NC}"
echo -e "  bind         : http://$BIND_IP:$PORT"
echo -e "  project root : $PROJECT_ROOT\n"
echo -e "${BOLD}Enter these in the Companion app (Settings -> Remote PC):${NC}\n"
echo -e "  Target IP    : ${BOLD}${TARGET_IP}${NC}"
echo -e "  Port         : ${BOLD}${PORT}${NC}"
echo -e "  Auth header  : ${BOLD}X-Swarm-Auth: ${SWARM_AUTH_TOKEN}${NC}"
echo -e "  Project path : ${BOLD}${PROJECT_ROOT}${NC}\n"
echo -e "  Test from the phone browser:"
echo -e "    ${BOLD}http://${TARGET_IP}:${PORT}/api/fs?path=${PROJECT_ROOT}${NC}\n"

# ── Firewall hint (does not change rules on its own) ────────────────────────
if command -v firewall-cmd >/dev/null 2>&1 && ! firewall-cmd --query-port="$PORT/tcp" >/dev/null 2>&1; then
  echo -e "${YELLOW}  Port $PORT looks closed. To open it for this session only:${NC}"
  echo -e "    sudo firewall-cmd --add-port=$PORT/tcp\n"
fi

echo -e "${CYAN}Starting LucyServer... (Ctrl-C to stop)${NC}\n"
cd "$SERVER_DIR"
ASPNETCORE_URLS="http://$BIND_IP:$PORT" \
SWARM_AUTH_TOKEN="$SWARM_AUTH_TOKEN" \
SWARM_PROJECT_ROOT="$PROJECT_ROOT" \
exec dotnet ./LucyServer.dll
