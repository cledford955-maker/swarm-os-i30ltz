package memory

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
)

// Store is the on-disk log at <dir>/log/<device>.jsonl — one file per device,
// each appended only by whoever ingests that device's entries.
//
// Several processes can share a Store directory at once (LucyServer and the
// swarm-memory CLI on the same OS): writes take an flock on the target file,
// and every read first calls refresh(), which picks up bytes other processes
// appended. Only complete lines are consumed, so a half-written line is never
// parsed.
type Store struct {
	dir string

	mu        sync.Mutex
	offsets   map[string]int64 // file name -> bytes consumed
	ids       map[string]struct{}
	entries   []stored
	subs      map[chan Entry]struct{}
	leaseSubs map[chan struct{}]struct{}
}

func (s *Store) subscribeLease() (<-chan struct{}, func()) {
	ch := make(chan struct{}, 1)
	s.mu.Lock()
	s.leaseSubs[ch] = struct{}{}
	s.mu.Unlock()
	return ch, func() {
		s.mu.Lock()
		delete(s.leaseSubs, ch)
		s.mu.Unlock()
	}
}

func (s *Store) broadcastLease() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for ch := range s.leaseSubs {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

type stored struct {
	Entry
	file string
	end  int64 // file offset just past this entry's line
}

// Open creates the directory layout if needed and loads the log.
func Open(dir string) (*Store, error) {
	for _, sub := range []string{"log", "state"} {
		if err := os.MkdirAll(filepath.Join(dir, sub), 0o755); err != nil {
			return nil, err
		}
	}
	s := &Store{
		dir:       dir,
		offsets:   map[string]int64{},
		ids:       map[string]struct{}{},
		subs:      map[chan Entry]struct{}{},
		leaseSubs: map[chan struct{}]struct{}{},
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.refreshLocked(); err != nil {
		return nil, err
	}
	return s, nil
}

// Dir returns the store's root directory.
func (s *Store) Dir() string { return s.dir }

func (s *Store) logPath(name string) string { return filepath.Join(s.dir, "log", name) }

func fileFor(device string) string { return device + ".jsonl" }

// Refresh picks up entries appended by other processes.
func (s *Store) Refresh() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.refreshLocked()
}

func (s *Store) refreshLocked() error {
	names, err := filepath.Glob(s.logPath("*.jsonl"))
	if err != nil {
		return err
	}
	for _, path := range names {
		name := filepath.Base(path)
		fi, err := os.Stat(path)
		if err != nil || fi.Size() <= s.offsets[name] {
			continue
		}
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		start := s.offsets[name]
		buf := make([]byte, fi.Size()-start)
		_, err = f.ReadAt(buf, start)
		f.Close()
		if err != nil && err != io.EOF {
			return err
		}
		last := bytes.LastIndexByte(buf, '\n')
		if last < 0 {
			continue // only a partial line so far
		}
		pos := start
		for _, line := range bytes.Split(buf[:last], []byte{'\n'}) {
			pos += int64(len(line)) + 1
			line = bytes.TrimSpace(line)
			if len(line) == 0 {
				continue
			}
			var e Entry
			if json.Unmarshal(line, &e) != nil || e.Validate() != nil {
				continue // a corrupt line must not take the whole log down
			}
			if _, dup := s.ids[e.ID]; dup {
				continue
			}
			s.ids[e.ID] = struct{}{}
			s.entries = append(s.entries, stored{Entry: e, file: name, end: pos})
			for ch := range s.subs {
				select {
				case ch <- e:
				default: // a slow subscriber misses live events, not data
				}
			}
		}
		s.offsets[name] = start + int64(last) + 1
	}
	return nil
}

// Append writes new entries authored on this machine.
func (s *Store) Append(entries ...Entry) error {
	_, err := s.Ingest(entries)
	return err
}

// Ingest stores entries received from any device, skipping ids already known.
// It returns how many were new.
func (s *Store) Ingest(entries []Entry) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.refreshLocked(); err != nil {
		return 0, err
	}
	byFile := map[string][]Entry{}
	seen := map[string]struct{}{}
	for _, e := range entries {
		if err := e.Validate(); err != nil {
			return 0, fmt.Errorf("entry %q: %w", e.ID, err)
		}
		if _, dup := s.ids[e.ID]; dup {
			continue
		}
		if _, dup := seen[e.ID]; dup {
			continue
		}
		seen[e.ID] = struct{}{}
		byFile[fileFor(e.Device)] = append(byFile[fileFor(e.Device)], e)
	}
	n := 0
	for name, batch := range byFile {
		if err := appendLocked(s.logPath(name), batch); err != nil {
			return n, err
		}
		n += len(batch)
	}
	return n, s.refreshLocked()
}

func appendLocked(path string, batch []Entry) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	var buf bytes.Buffer
	for _, e := range batch {
		line, err := json.Marshal(e)
		if err != nil {
			return err
		}
		buf.Write(line)
		buf.WriteByte('\n')
	}
	if _, err := f.Write(buf.Bytes()); err != nil {
		return err
	}
	return f.Sync()
}

// Cursor marks a position in the log: bytes consumed per device file. Because
// files are append-only it is exact and independent of any device's clock.
type Cursor map[string]int64

// Encode returns the opaque string clients echo back.
func (c Cursor) Encode() string {
	data, _ := json.Marshal(c)
	return base64.RawURLEncoding.EncodeToString(data)
}

// ParseCursor accepts "" (start of log) or a value from Encode.
func ParseCursor(v string) (Cursor, error) {
	c := Cursor{}
	if v == "" {
		return c, nil
	}
	data, err := base64.RawURLEncoding.DecodeString(v)
	if err != nil {
		return nil, fmt.Errorf("bad cursor")
	}
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("bad cursor")
	}
	return c, nil
}

// Since returns entries after cursor, oldest first, plus the cursor that
// covers everything returned.
func (s *Store) Since(c Cursor) ([]Entry, Cursor, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.refreshLocked(); err != nil {
		return nil, nil, err
	}
	var out []Entry
	for _, e := range s.entries {
		if e.end > c[e.file] {
			out = append(out, e.Entry)
		}
	}
	next := Cursor{}
	for k, v := range s.offsets {
		next[k] = v
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Before(out[j]) })
	return out, next, nil
}

// Query filters the log. Empty fields match everything; limit <= 0 means all.
// Results are newest first.
type Query struct {
	Kind, Key, Device, Text string
	Limit                   int
}

func (s *Store) Query(q Query) ([]Entry, error) {
	all, _, err := s.Since(nil)
	if err != nil {
		return nil, err
	}
	text := strings.ToLower(q.Text)
	var out []Entry
	for i := len(all) - 1; i >= 0; i-- {
		e := all[i]
		if (q.Kind != "" && e.Kind != q.Kind) || (q.Key != "" && e.Key != q.Key) || (q.Device != "" && e.Device != q.Device) {
			continue
		}
		if text != "" && !strings.Contains(strings.ToLower(e.Content+" "+e.Key), text) {
			continue
		}
		out = append(out, e)
		if q.Limit > 0 && len(out) >= q.Limit {
			break
		}
	}
	return out, nil
}

// Current returns the newest entry for every kind+key, tombstones removed.
func (s *Store) Current(kind string) ([]Entry, error) {
	all, _, err := s.Since(nil)
	if err != nil {
		return nil, err
	}
	latest := map[string]Entry{}
	for _, e := range all { // oldest first, so later ones win
		if e.Key == "" || (kind != "" && e.Kind != kind) {
			continue
		}
		latest[e.Kind+"\x00"+e.Key] = e
	}
	var out []Entry
	for _, e := range latest {
		if !e.Deleted {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Kind != out[j].Kind {
			return out[i].Kind < out[j].Kind
		}
		return out[i].Key < out[j].Key
	})
	return out, nil
}

// Subscribe delivers entries as they are seen. Call the returned func to stop.
func (s *Store) Subscribe() (<-chan Entry, func()) {
	ch := make(chan Entry, 64)
	s.mu.Lock()
	s.subs[ch] = struct{}{}
	s.mu.Unlock()
	return ch, func() {
		s.mu.Lock()
		delete(s.subs, ch)
		s.mu.Unlock()
	}
}

// Count returns the number of entries in the log.
func (s *Store) Count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.entries)
}
