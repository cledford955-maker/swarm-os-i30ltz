// Package storage resolves where LucyServer keeps its flat-file state.
//
// The .NET LucyServer does NOT use SQLite for its core services — chat
// history (ChatService), WebAuthn credentials (WebAuthnService), and
// login/sudo password hashes (SettingsService) are all flat JSON files or
// plain text, read/written directly. This package mirrors that, it does not
// introduce a database the original never had.
package storage

import "os"

// BaseDir is the directory LucyServer-go keeps its own state in: chat
// history JSON, webauthn_credentials.json, login/sudo password hash files.
//
// The .NET original hardcoded chat history specifically to
// "/mnt/i30ltz-brains/AI/memory.json" (ChatService.cs). That path does not
// exist anywhere on this system — not in /etc/fstab, not created by
// install_swarm_os.sh, not mentioned in CLAUDE.md's documented mount list.
// It looks like a latent bug in the .NET source (chat history silently
// failing to persist, or throwing, on every real boot) rather than an
// intentional design this port should carry forward. Using
// /etc/swarm_os/lucy/ instead, consistent with GamingAgent-go's
// /etc/swarm_os/gaming.db convention — same parent directory, same
// ExecStartPre provisioning pattern in the systemd unit.
func BaseDir() string {
	if d := os.Getenv("LUCY_STATE_DIR"); d != "" {
		return d
	}
	return "/etc/swarm_os/lucy"
}
