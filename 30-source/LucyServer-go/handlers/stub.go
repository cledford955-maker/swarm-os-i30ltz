package handlers

import (
	"encoding/json"
	"net/http"
)

// NotImplemented returns a handler that responds 501 naming the task that
// will port this route, so a client hitting it gets an honest signal instead
// of a generic 404 (indistinguishable from a typo'd URL) or — worse — a
// silent fake 200 with empty/wrong data.
func NotImplemented(task string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotImplemented)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "not yet ported from .NET LucyServer",
			"track": task,
		})
	}
}
