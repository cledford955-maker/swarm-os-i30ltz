package services

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestChatHTTPError_IncludesStatusAndProviderMessage(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error":{"message":"User not found.","code":401}}`))
	}))
	t.Cleanup(srv.Close)

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	got := chatHTTPError(resp)
	for _, want := range []string{"HTTP 401", "User not found."} {
		if !strings.Contains(got, want) {
			t.Errorf("chatHTTPError() = %q, want it to contain %q", got, want)
		}
	}
}

func TestChatHTTPError_CapsLongBodies(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte(strings.Repeat("x", 5000)))
	}))
	t.Cleanup(srv.Close)

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if got := chatHTTPError(resp); len(got) > 700 {
		t.Errorf("chatHTTPError() returned %d bytes, want the provider body capped", len(got))
	}
}
