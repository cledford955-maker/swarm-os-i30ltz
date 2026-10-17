package handlers

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMediaHandler_ControlValidation(t *testing.T) {
	h := NewMediaHandler(nil)

	// Invalid action
	req := httptest.NewRequest("POST", "/api/media/control", bytes.NewReader([]byte(`{"action":"destroy"}`)))
	rec := httptest.NewRecorder()
	h.Control(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for unknown action, got %d", rec.Code)
	}

	// Bad json
	reqBad := httptest.NewRequest("POST", "/api/media/control", bytes.NewReader([]byte(`{bad`)))
	recBad := httptest.NewRecorder()
	h.Control(recBad, reqBad)
	if recBad.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for bad json, got %d", recBad.Code)
	}
}

func TestMediaHandler_VolumeValidation(t *testing.T) {
	h := NewMediaHandler(nil)

	// Out of bounds volume: > 1.0
	reqHigh := httptest.NewRequest("POST", "/api/media/volume", bytes.NewReader([]byte(`{"volume":1.5}`)))
	recHigh := httptest.NewRecorder()
	h.Volume(recHigh, reqHigh)
	if recHigh.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for volume > 1.0, got %d", recHigh.Code)
	}

	// Out of bounds volume: < 0.0
	reqLow := httptest.NewRequest("POST", "/api/media/volume", bytes.NewReader([]byte(`{"volume":-0.5}`)))
	recLow := httptest.NewRecorder()
	h.Volume(recLow, reqLow)
	if recLow.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for volume < 0.0, got %d", recLow.Code)
	}
}
