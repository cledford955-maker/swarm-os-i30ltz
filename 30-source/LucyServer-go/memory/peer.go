package memory

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// SyncPath is served by LucyServer (ports 5000 and 8402) and by every
// companion phone's embedded server (port 8402).
const SyncPath = "/api/memory/sync"

// SyncResponse is the body of GET /api/memory/sync.
type SyncResponse struct {
	Device  string  `json:"device"`
	Entries []Entry `json:"entries"`
	Cursor  string  `json:"cursor"`
}

// PushRequest is the body of POST /api/memory/sync.
type PushRequest struct {
	Entries []Entry `json:"entries"`
}

// PushResponse is the reply to a push.
type PushResponse struct {
	Accepted int `json:"accepted"`
}

// PeerState remembers, per peer, how far we have pulled (their cursor) and
// pushed (our cursor). Saved in <store>/state/peers-<device>.json.
type PeerState struct {
	PullCursor string `json:"pull_cursor"`
	PushCursor string `json:"push_cursor"`
	LastOK     string `json:"last_ok,omitempty"`
	LastError  string `json:"last_error,omitempty"`
}

// PeerResult is the outcome of syncing with one peer.
type PeerResult struct {
	Peer           string
	Pulled, Pushed int
	Err            error
}

// SyncWithPeer pulls everything new from base (e.g. "http://100.105.12.16:8402")
// and pushes everything the peer has not had from us — including entries we
// received from other devices, which is what makes the mesh converge by gossip.
func SyncWithPeer(s *Store, device, base, token string) PeerResult {
	res := PeerResult{Peer: base}
	states := loadPeerStates(s, device)
	st := states[base]
	defer func() {
		if res.Err != nil {
			st.LastError = res.Err.Error()
		} else {
			st.LastOK, st.LastError = time.Now().UTC().Format(time.RFC3339), ""
		}
		states[base] = st
		savePeerStates(s, device, states)
	}()

	client := &http.Client{Timeout: 20 * time.Second}

	// Pull.
	u := strings.TrimRight(base, "/") + SyncPath + "?cursor=" + url.QueryEscape(st.PullCursor)
	req, _ := http.NewRequest(http.MethodGet, u, nil)
	req.Header.Set("X-Swarm-Auth", token)
	resp, err := client.Do(req)
	if err != nil {
		res.Err = err
		return res
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 256<<20))
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		res.Err = fmt.Errorf("pull: %s: %s", resp.Status, strings.TrimSpace(string(body)))
		return res
	}
	var pulled SyncResponse
	if err := json.Unmarshal(body, &pulled); err != nil {
		res.Err = fmt.Errorf("pull: %w", err)
		return res
	}
	n, err := s.Ingest(pulled.Entries)
	if err != nil {
		res.Err = err
		return res
	}
	res.Pulled = n
	st.PullCursor = pulled.Cursor

	// Push, in batches so a first sync of large docs stays under body limits.
	cur, err := ParseCursor(st.PushCursor)
	if err != nil {
		cur = Cursor{}
	}
	pending, next, err := s.Since(cur)
	if err != nil {
		res.Err = err
		return res
	}
	for start := 0; start < len(pending); start += 200 {
		end := min(start+200, len(pending))
		data, _ := json.Marshal(PushRequest{Entries: pending[start:end]})
		req, _ := http.NewRequest(http.MethodPost, strings.TrimRight(base, "/")+SyncPath, bytes.NewReader(data))
		req.Header.Set("X-Swarm-Auth", token)
		req.Header.Set("Content-Type", "application/json")
		resp, err := client.Do(req)
		if err != nil {
			res.Err = err
			return res
		}
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			res.Err = fmt.Errorf("push: %s: %s", resp.Status, strings.TrimSpace(string(msg)))
			return res
		}
		res.Pushed += end - start
	}
	st.PushCursor = next.Encode()
	return res
}

func peerStatePath(s *Store, device string) string {
	return filepath.Join(s.Dir(), "state", "peers-"+device+".json")
}

func loadPeerStates(s *Store, device string) map[string]PeerState {
	m := map[string]PeerState{}
	if data, err := os.ReadFile(peerStatePath(s, device)); err == nil {
		_ = json.Unmarshal(data, &m)
	}
	return m
}

func savePeerStates(s *Store, device string, m map[string]PeerState) {
	data, _ := json.MarshalIndent(m, "", "  ")
	_ = writeFileAtomic(peerStatePath(s, device), string(data))
}

// PeerStates exposes saved sync status for display.
func PeerStates(s *Store, device string) map[string]PeerState { return loadPeerStates(s, device) }

// Peers lists sync peers from <store>/peers.json: {"peers": ["http://host:8402", ...]}.
func Peers(s *Store) []string {
	var cfg struct {
		Peers []string `json:"peers"`
	}
	if data, err := os.ReadFile(filepath.Join(s.Dir(), "peers.json")); err == nil {
		_ = json.Unmarshal(data, &cfg)
	}
	return cfg.Peers
}

// AuthToken finds the SWARM token the same way LucyServer does, falling back
// to the env files the services load.
func AuthToken() string {
	if t := os.Getenv("SWARM_AUTH_TOKEN"); t != "" {
		return t
	}
	for _, f := range []string{"/run/swarm_os.env", "/etc/swarm_os.env"} {
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			if v, ok := strings.CutPrefix(strings.TrimSpace(line), "SWARM_AUTH_TOKEN="); ok {
				return strings.Trim(v, `"'`)
			}
		}
	}
	return "swarm-token-2026"
}
