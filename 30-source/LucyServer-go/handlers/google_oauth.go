// Package handlers — proxy for the GoogleWorkspaceService OAuth flow.
//
// The GoogleWorkspaceService (.NET, port 8399) already implements the full
// OAuth handshake: upload credentials.json → get auth URL → user approves in
// browser → callback exchanges the code → refresh token stored in tokens
// data-dir. LucyServer just proxies the auth endpoints so:
//   1. Flutter/Companion only need to know one origin (LucyServer :5000)
//      instead of adding CORS to 8399.
//   2. The proxy carries LucyServer's own auth token (X-Swarm-Auth); nothing
//      else on the network can start an OAuth flow.
//   3. Endpoints stay symmetric with the rest of the /api/* surface.
package handlers

import (
	"errors"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"
)

// googleWorkspaceBase points at the .NET service. Loopback by default; the
// AppArmor + nftables rules already keep :8399 loopback-only.
func googleWorkspaceBase() string {
	if v := os.Getenv("GOOGLE_WORKSPACE_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:8399"
}

var googleClient = &http.Client{Timeout: 10 * time.Second}

// proxyToGoogleWorkspace forwards the request to path on the Google Workspace
// service. `method` is the upstream HTTP verb; `path` is the upstream path
// (e.g. "/auth/url"). Query string and body are copied verbatim. Response
// status, Content-Type and body are copied back.
//
// On upstream connection failure we return 503 (service unavailable) with a
// short JSON body so the Flutter UI can render an "offline" state rather than
// hanging.
func proxyToGoogleWorkspace(w http.ResponseWriter, r *http.Request, method, path string) {
	upstreamURL, err := url.Parse(googleWorkspaceBase() + path)
	if err != nil {
		http.Error(w, `{"error":"bad upstream URL"}`, http.StatusInternalServerError)
		return
	}
	upstreamURL.RawQuery = r.URL.RawQuery

	req, err := http.NewRequestWithContext(r.Context(), method, upstreamURL.String(), r.Body)
	if err != nil {
		http.Error(w, `{"error":"upstream request build failed"}`, http.StatusInternalServerError)
		return
	}
	// Forward content type for multipart/form-data uploads (credentials.json).
	if ct := r.Header.Get("Content-Type"); ct != "" {
		req.Header.Set("Content-Type", ct)
	}

	resp, err := googleClient.Do(req)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		var netErr *url.Error
		msg := "google workspace service unreachable"
		if errors.As(err, &netErr) {
			msg = netErr.Err.Error()
		}
		w.Write([]byte(`{"error":"` + jsonEscape(msg) + `","upstream":"google-workspace"}`))
		return
	}
	defer resp.Body.Close()

	// Copy Content-Type so JSON stays JSON and the OAuth callback HTML stays HTML.
	if ct := resp.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// jsonEscape performs the minimum escaping needed to embed msg inside a JSON
// string literal we're constructing manually (backslash + double-quote).
func jsonEscape(msg string) string {
	// Small enough that a linear scan is faster than a strings.Replacer alloc.
	out := make([]byte, 0, len(msg))
	for i := 0; i < len(msg); i++ {
		c := msg[i]
		switch c {
		case '\\', '"':
			out = append(out, '\\', c)
		case '\n':
			out = append(out, '\\', 'n')
		case '\r':
			out = append(out, '\\', 'r')
		case '\t':
			out = append(out, '\\', 't')
		default:
			if c < 0x20 {
				continue // strip control chars
			}
			out = append(out, c)
		}
	}
	return string(out)
}

// GoogleAuthStatus proxies GET /auth/status.
func GoogleAuthStatus(w http.ResponseWriter, r *http.Request) {
	proxyToGoogleWorkspace(w, r, http.MethodGet, "/auth/status")
}

// GoogleAuthURL proxies GET /auth/url.
func GoogleAuthURL(w http.ResponseWriter, r *http.Request) {
	proxyToGoogleWorkspace(w, r, http.MethodGet, "/auth/url")
}

// GoogleAuthUploadCredentials proxies POST /auth/upload_credentials (multipart).
func GoogleAuthUploadCredentials(w http.ResponseWriter, r *http.Request) {
	proxyToGoogleWorkspace(w, r, http.MethodPost, "/auth/upload_credentials")
}

// GoogleAuthExchange proxies POST /auth/exchange.
func GoogleAuthExchange(w http.ResponseWriter, r *http.Request) {
	proxyToGoogleWorkspace(w, r, http.MethodPost, "/auth/exchange")
}

// GoogleAuthLogout proxies POST /auth/logout.
func GoogleAuthLogout(w http.ResponseWriter, r *http.Request) {
	proxyToGoogleWorkspace(w, r, http.MethodPost, "/auth/logout")
}
