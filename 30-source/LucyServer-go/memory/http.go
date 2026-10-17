package memory

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
)

// API serves the shared memory over HTTP. Mount Routes under /api/memory.
type API struct {
	Store  *Store
	Leases *Leases
	Device string // this server's device id
}

// Routes registers every memory endpoint on r (already scoped to /api/memory).
func (a *API) Routes(r chi.Router) {
	r.Get("/sync", a.pull)
	r.Post("/sync", a.push)
	r.Get("/entries", a.list)
	r.Post("/entries", a.create)
	r.Get("/current", a.current)
	r.Get("/status", a.status)
	r.Get("/lease", a.getLease)
	r.Post("/lease/acquire", a.acquire)
	r.Post("/lease/heartbeat", a.heartbeat)
	r.Post("/lease/release", a.release)
	r.Get("/stream", a.stream)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func fail(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// GET /sync?cursor=<opaque> — everything after cursor, plus the next cursor.
func (a *API) pull(w http.ResponseWriter, r *http.Request) {
	c, err := ParseCursor(r.URL.Query().Get("cursor"))
	if err != nil {
		fail(w, http.StatusBadRequest, "cursor is not one this server issued; pull again with an empty cursor")
		return
	}
	entries, next, err := a.Store.Since(c)
	if err != nil {
		fail(w, http.StatusInternalServerError, err.Error())
		return
	}
	if entries == nil {
		entries = []Entry{}
	}
	writeJSON(w, http.StatusOK, SyncResponse{Device: a.Device, Entries: entries, Cursor: next.Encode()})
}

// POST /sync {entries:[...]} — offline or gossiped entries. Always accepted:
// the write lease governs live edits only.
func (a *API) push(w http.ResponseWriter, r *http.Request) {
	var req PushRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<20)).Decode(&req); err != nil {
		fail(w, http.StatusBadRequest, "body must be {\"entries\": [...]}")
		return
	}
	n, err := a.Store.Ingest(req.Entries)
	if err != nil {
		fail(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, PushResponse{Accepted: n})
}

// GET /entries?kind=&key=&device=&q=&limit=
func (a *API) list(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	limit, _ := strconv.Atoi(q.Get("limit"))
	if limit <= 0 || limit > 1000 {
		limit = 200
	}
	entries, err := a.Store.Query(Query{Kind: q.Get("kind"), Key: q.Get("key"), Device: q.Get("device"), Text: q.Get("q"), Limit: limit})
	if err != nil {
		fail(w, http.StatusInternalServerError, err.Error())
		return
	}
	if entries == nil {
		entries = []Entry{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": entries})
}

// GET /current?kind= — newest entry per kind+key.
func (a *API) current(w http.ResponseWriter, r *http.Request) {
	entries, err := a.Store.Current(r.URL.Query().Get("kind"))
	if err != nil {
		fail(w, http.StatusInternalServerError, err.Error())
		return
	}
	if entries == nil {
		entries = []Entry{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": entries})
}

type createRequest struct {
	Device  string            `json:"device"`
	Kind    string            `json:"kind"`
	Key     string            `json:"key"`
	Content string            `json:"content"`
	Tags    []string          `json:"tags"`
	Meta    map[string]string `json:"meta"`
	Deleted bool              `json:"deleted"`
}

// POST /entries — a live write. Refused with 409 while another device holds
// the write lease; the client should queue it and push later instead.
func (a *API) create(w http.ResponseWriter, r *http.Request) {
	var req createRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, MaxContentBytes+4096)).Decode(&req); err != nil {
		fail(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Device == "" {
		req.Device = a.Device
	}
	if req.Kind == "" {
		req.Kind = KindNote
	}
	if ok, ls := a.Leases.CanWriteLive(req.Device); !ok {
		writeJSON(w, http.StatusConflict, map[string]any{
			"error": fmt.Sprintf("%s is main right now. Take over the lease or save offline and sync.", ls.Holder),
			"lease": ls,
		})
		return
	}
	e := NewEntry(req.Device, req.Kind, req.Key, req.Content)
	e.Tags, e.Meta, e.Deleted = req.Tags, req.Meta, req.Deleted
	if err := e.Validate(); err != nil {
		fail(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := a.Store.Append(e); err != nil {
		fail(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, e)
}

// GET /status — counts, this server's device id and the lease.
func (a *API) status(w http.ResponseWriter, r *http.Request) {
	if err := a.Store.Refresh(); err != nil {
		fail(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"device":  a.Device,
		"entries": a.Store.Count(),
		"dir":     a.Store.Dir(),
		"lease":   a.Leases.Get(),
		"peers":   PeerStates(a.Store, a.Device),
	})
}

type leaseRequest struct {
	Device string `json:"device"`
	Force  bool   `json:"force"`
}

func decodeLease(w http.ResponseWriter, r *http.Request) (leaseRequest, bool) {
	var req leaseRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&req); err != nil || !deviceRe.MatchString(req.Device) {
		fail(w, http.StatusBadRequest, "body must be {\"device\": \"<device id>\"}")
		return req, false
	}
	return req, true
}

func (a *API) getLease(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, a.Leases.Get())
}

func (a *API) leaseReply(w http.ResponseWriter, ls Lease, err error) {
	switch {
	case errors.Is(err, ErrLeaseHeld):
		writeJSON(w, http.StatusConflict, map[string]any{"error": "another device holds the lease", "lease": ls})
	case err != nil:
		fail(w, http.StatusInternalServerError, err.Error())
	default:
		a.Store.broadcastLease()
		writeJSON(w, http.StatusOK, ls)
	}
}

// POST /lease/acquire {device, force} — force is the explicit "take over".
func (a *API) acquire(w http.ResponseWriter, r *http.Request) {
	if req, ok := decodeLease(w, r); ok {
		ls, err := a.Leases.Acquire(req.Device, req.Force)
		a.leaseReply(w, ls, err)
	}
}

func (a *API) heartbeat(w http.ResponseWriter, r *http.Request) {
	if req, ok := decodeLease(w, r); ok {
		ls, err := a.Leases.Heartbeat(req.Device)
		if err == nil { // heartbeats are frequent; don't wake every stream
			writeJSON(w, http.StatusOK, ls)
			return
		}
		a.leaseReply(w, ls, err)
	}
}

func (a *API) release(w http.ResponseWriter, r *http.Request) {
	if req, ok := decodeLease(w, r); ok {
		a.leaseReply(w, Lease{}, a.Leases.Release(req.Device))
	}
}

// GET /stream — Server-Sent Events: "entry" for every new entry, "lease" when
// the holder changes. Other processes' writes arrive within 2 s via polling.
func (a *API) stream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		fail(w, http.StatusInternalServerError, "streaming unsupported")
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("X-Accel-Buffering", "no")

	entries, stop := a.Store.Subscribe()
	defer stop()
	leaseCh, stopLease := a.Store.subscribeLease()
	defer stopLease()

	send := func(event string, v any) {
		data, _ := json.Marshal(v)
		fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, data)
		flusher.Flush()
	}
	send("lease", a.Leases.Get())

	poll := time.NewTicker(2 * time.Second)
	keepalive := time.NewTicker(20 * time.Second)
	defer poll.Stop()
	defer keepalive.Stop()
	lastHolder := a.Leases.Get().Holder
	for {
		select {
		case <-r.Context().Done():
			return
		case e := <-entries:
			send("entry", e)
		case <-leaseCh:
			ls := a.Leases.Get()
			lastHolder = ls.Holder
			send("lease", ls)
		case <-poll.C:
			_ = a.Store.Refresh()
			if ls := a.Leases.Get(); ls.Holder != lastHolder { // expiry or another process
				lastHolder = ls.Holder
				send("lease", ls)
			}
		case <-keepalive.C:
			fmt.Fprint(w, ": keepalive\n\n")
			flusher.Flush()
		}
	}
}

// TokenOnly guards the LAN sync listener: unlike the main router there is no
// loopback bypass and no browser access at all.
func TokenOnly(token func() string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Origin") != "" {
				fail(w, http.StatusForbidden, "browser access is not allowed on the sync port")
				return
			}
			want := token()
			got := r.Header.Get("X-Swarm-Auth")
			if got == "" {
				got = strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			}
			if want == "" || got != want {
				fail(w, http.StatusUnauthorized, "missing or invalid X-Swarm-Auth token")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
