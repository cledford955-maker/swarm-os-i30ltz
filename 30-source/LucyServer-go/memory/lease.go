package memory

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Lease timings. A holder heartbeats every HeartbeatInterval; if LeaseTTL
// passes without one (phone locked, out of range) the lease frees itself.
const (
	LeaseTTL          = 30 * time.Second
	HeartbeatInterval = 10 * time.Second
)

// Lease says which device is "main" for live editing. It governs live writes
// only — offline entries pushed through /sync are always accepted, because
// the append-only log cannot conflict.
type Lease struct {
	Holder   string `json:"holder,omitempty"`
	Acquired string `json:"acquired,omitempty"`
	Expires  string `json:"expires,omitempty"`
}

// Active reports whether someone currently holds the lease.
func (l Lease) Active(now time.Time) bool {
	if l.Holder == "" {
		return false
	}
	exp, err := time.Parse(time.RFC3339Nano, l.Expires)
	return err == nil && now.Before(exp)
}

// ErrLeaseHeld is returned when another device holds an active lease.
var ErrLeaseHeld = errors.New("lease held by another device")

// Leases persists the lease to <dir>/lease.json so every process on the
// machine (and the git mirror, if it ever copied it) sees the same holder.
type Leases struct {
	path string
	mu   sync.Mutex
	now  func() time.Time
}

func NewLeases(dir string) *Leases {
	return &Leases{path: filepath.Join(dir, "lease.json"), now: time.Now}
}

func (l *Leases) load() Lease {
	var ls Lease
	if data, err := os.ReadFile(l.path); err == nil {
		_ = json.Unmarshal(data, &ls)
	}
	return ls
}

func (l *Leases) save(ls Lease) error {
	data, _ := json.MarshalIndent(ls, "", "  ")
	tmp := l.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, l.path)
}

// Get returns the lease, cleared if it has expired.
func (l *Leases) Get() Lease {
	l.mu.Lock()
	defer l.mu.Unlock()
	ls := l.load()
	if !ls.Active(l.now()) {
		return Lease{}
	}
	return ls
}

// Acquire takes the lease if it is free, already ours, or force is set
// (the explicit "take over" action).
func (l *Leases) Acquire(device string, force bool) (Lease, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	cur := l.load()
	if cur.Active(now) && cur.Holder != device && !force {
		return cur, ErrLeaseHeld
	}
	ls := Lease{Holder: device, Acquired: now.UTC().Format(time.RFC3339Nano)}
	if cur.Active(now) && cur.Holder == device {
		ls.Acquired = cur.Acquired
	}
	ls.Expires = now.Add(LeaseTTL).UTC().Format(time.RFC3339Nano)
	return ls, l.save(ls)
}

// Heartbeat extends the holder's lease.
func (l *Leases) Heartbeat(device string) (Lease, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	cur := l.load()
	if !cur.Active(now) || cur.Holder != device {
		return cur, ErrLeaseHeld
	}
	cur.Expires = now.Add(LeaseTTL).UTC().Format(time.RFC3339Nano)
	return cur, l.save(cur)
}

// Release frees the lease if device holds it.
func (l *Leases) Release(device string) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	cur := l.load()
	if cur.Holder != device {
		return nil
	}
	return l.save(Lease{})
}

// CanWriteLive reports whether device may write live right now.
func (l *Leases) CanWriteLive(device string) (bool, Lease) {
	ls := l.Get()
	return ls.Holder == "" || ls.Holder == device, ls
}
