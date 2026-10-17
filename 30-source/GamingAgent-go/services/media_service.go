package services

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"swarm-os/gaming-agent/models"
)

// MediaService controls whatever's playing (Spotify, a Chrome/YouTube tab, or
// any other MPRIS-compliant player) via playerctl, the standard Linux CLI
// wrapper around the MPRIS D-Bus interface. This is why one implementation
// here covers "control music youtube spotify" uniformly: MPRIS is a desktop
// standard those apps already implement, not something GamingAgent has to
// integrate with per-service (no Spotify OAuth, no per-site scraping).
type MediaService struct {
	timeout time.Duration
}

func NewMediaService() *MediaService {
	return &MediaService{timeout: 5 * time.Second}
}

func (s *MediaService) run(args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, "playerctl", args...).Output()
	return strings.TrimSpace(string(out)), err
}

// ListPlayers returns active MPRIS player instances (e.g. "spotify",
// "chromium.instance1"). An empty result with no error means nothing is
// currently playing anywhere — that's the normal common case, not a failure.
func (s *MediaService) ListPlayers() ([]string, error) {
	out, err := s.run("-l")
	if err != nil {
		// playerctl exits non-zero with "No players found" on stderr when
		// nothing is active; Output() only captures stdout, so err here
		// genuinely means "no players" rather than a real failure.
		return nil, nil
	}
	if out == "" {
		return nil, nil
	}
	return strings.Split(out, "\n"), nil
}

// GetStatus returns now-playing info for the given player, or playerctl's
// default (most-recently-active) player if player is "". Never errors just
// because nothing is playing — check Available instead.
func (s *MediaService) GetStatus(player string) (*models.MediaStatus, error) {
	players, _ := s.ListPlayers()
	result := &models.MediaStatus{Players: players}
	if len(players) == 0 {
		return result, nil
	}

	pArgs := func(base ...string) []string {
		if player != "" {
			return append(base, "-p", player)
		}
		return base
	}

	// Unit-separator delimited so titles/artists containing normal
	// punctuation can't be mistaken for the delimiter.
	const sep = "\x1f"
	format := strings.Join([]string{
		"{{title}}", "{{artist}}", "{{album}}", "{{mpris:artUrl}}",
		"{{duration(position)}}", "{{duration(mpris:length)}}",
	}, sep)
	meta, err := s.run(pArgs("metadata", "--format", format)...)
	if err == nil && meta != "" {
		fields := strings.Split(meta, sep)
		for len(fields) < 6 {
			fields = append(fields, "")
		}
		result.Title = fields[0]
		result.Artist = fields[1]
		result.Album = fields[2]
		result.ArtUrl = fields[3]
		result.Position = fields[4]
		result.Duration = fields[5]
		result.Available = true
	}

	if status, err := s.run(pArgs("status")...); err == nil && status != "" {
		result.Status = status
		result.Available = true
	}

	if player != "" {
		result.Player = player
		result.PlayerLabel = player
	} else if len(players) > 0 {
		result.Player = players[0]
		result.PlayerLabel = players[0]
	}

	if volStr, err := s.run(pArgs("volume")...); err == nil && volStr != "" {
		if vol, perr := strconv.ParseFloat(volStr, 64); perr == nil {
			result.Volume = vol
			result.VolumeKnown = true
		}
	}

	return result, nil
}

// Control issues play/pause/play-pause/next/previous/stop to the given
// player, or playerctl's default player if player is "". action is assumed
// validated by the caller (MediaHandler.Control checks it against
// validMediaActions before this is reached).
func (s *MediaService) Control(action, player string) error {
	args := []string{action}
	if player != "" {
		args = append(args, "-p", player)
	}
	if _, err := s.run(args...); err != nil {
		return fmt.Errorf("playerctl %s: %w", action, err)
	}
	return nil
}

// SetVolume sets playback volume to vol (0.0-1.0, caller-validated) on the
// given player, or playerctl's default player if player is "".
func (s *MediaService) SetVolume(vol float64, player string) error {
	args := []string{"volume", strconv.FormatFloat(vol, 'f', -1, 64)}
	if player != "" {
		args = append(args, "-p", player)
	}
	if _, err := s.run(args...); err != nil {
		return fmt.Errorf("playerctl volume: %w", err)
	}
	return nil
}
