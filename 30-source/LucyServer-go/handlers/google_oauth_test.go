package handlers

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// Spins up a mock upstream Google Workspace service and points the proxy at it.
func withMockUpstream(t *testing.T, handler http.Handler) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	t.Setenv("GOOGLE_WORKSPACE_URL", srv.URL)
}

func TestGoogleAuthStatus_Proxies(t *testing.T) {
	withMockUpstream(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/status" {
			t.Errorf("upstream path = %s, want /auth/status", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Errorf("upstream method = %s, want GET", r.Method)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"authenticated":true,"email":"user@example.com"}`))
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/google/auth/status", nil)
	rec := httptest.NewRecorder()
	GoogleAuthStatus(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "authenticated") {
		t.Errorf("body = %q", rec.Body.String())
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json" {
		t.Errorf("content-type = %q, want application/json", got)
	}
}

func TestGoogleAuthURL_ForwardsErrorStatus(t *testing.T) {
	// Upstream returns 400 when credentials.json hasn't been uploaded.
	// Proxy must preserve the 400 (not remap to 200 or 500).
	withMockUpstream(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error":"Upload credentials.json first"}`))
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/google/auth/url", nil)
	rec := httptest.NewRecorder()
	GoogleAuthURL(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", rec.Code)
	}
}

func TestGoogleAuthUploadCredentials_ForwardsBody(t *testing.T) {
	var receivedBody []byte
	var receivedContentType string
	withMockUpstream(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedContentType = r.Header.Get("Content-Type")
		receivedBody, _ = io.ReadAll(r.Body)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"ok":true}`))
	}))

	body := strings.NewReader("--boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"credentials.json\"\r\n\r\n{}\r\n--boundary--\r\n")
	req := httptest.NewRequest(http.MethodPost, "/api/google/auth/upload_credentials", body)
	req.Header.Set("Content-Type", `multipart/form-data; boundary=boundary`)

	rec := httptest.NewRecorder()
	GoogleAuthUploadCredentials(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", rec.Code)
	}
	if !strings.HasPrefix(receivedContentType, "multipart/form-data") {
		t.Errorf("upstream content-type = %q", receivedContentType)
	}
	if !strings.Contains(string(receivedBody), "credentials.json") {
		t.Errorf("upstream body did not include filename: %q", string(receivedBody))
	}
}

func TestGoogleAuth_UpstreamUnreachable(t *testing.T) {
	// Point the proxy at an unroutable address; expect 503 + JSON error, not a
	// hang or a 500.
	t.Setenv("GOOGLE_WORKSPACE_URL", "http://127.0.0.1:1") // rejected instantly

	req := httptest.NewRequest(http.MethodGet, "/api/google/auth/status", nil)
	rec := httptest.NewRecorder()
	GoogleAuthStatus(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Errorf("status = %d, want 503 when upstream is unreachable", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "google-workspace") {
		t.Errorf("body did not name upstream: %q", rec.Body.String())
	}
}

func TestGoogleAuthURL_ForwardsQueryString(t *testing.T) {
	var receivedQuery string
	withMockUpstream(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedQuery = r.URL.RawQuery
		w.Write([]byte(`{"ok":true}`))
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/google/auth/url?scope=gmail&prompt=consent", nil)
	rec := httptest.NewRecorder()
	GoogleAuthURL(rec, req)

	if receivedQuery != "scope=gmail&prompt=consent" {
		t.Errorf("upstream query = %q, want scope=gmail&prompt=consent", receivedQuery)
	}
}

func TestJsonEscape(t *testing.T) {
	cases := map[string]string{
		`simple`:        `simple`,
		`"quoted"`:      `\"quoted\"`,
		`back\slash`:    `back\\slash`,
		"line\nbreak":   `line\nbreak`,
		"tab\there":     `tab\there`,
		"ctrl\x01char":  `ctrlchar`, // stripped
	}
	for in, want := range cases {
		got := jsonEscape(in)
		if got != want {
			t.Errorf("jsonEscape(%q) = %q, want %q", in, got, want)
		}
	}
}
