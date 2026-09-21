package handlers

import (
	"archive/zip"
	"bytes"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

func archiveForTest(t *testing.T, names []string, symlink bool) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "project.zip")
	f, err := os.Create(p)
	if err != nil {
		t.Fatal(err)
	}
	z := zip.NewWriter(f)
	for _, name := range names {
		h := &zip.FileHeader{Name: name, Method: zip.Deflate}
		if symlink {
			h.SetMode(os.ModeSymlink | 0777)
		}
		w, e := z.CreateHeader(h)
		if e != nil {
			t.Fatal(e)
		}
		_, _ = w.Write([]byte("sample"))
	}
	if e := z.Close(); e != nil {
		t.Fatal(e)
	}
	_ = f.Close()
	return p
}
func TestAndroidZIPRejectsUnsafePaths(t *testing.T) {
	for _, path := range []string{"../escape", "a/../../escape", "/absolute", "C:/file", "..\\escape"} {
		t.Run(path, func(t *testing.T) {
			if e := extractAndroidZIP(archiveForTest(t, []string{path}, false), t.TempDir()); e == nil {
				t.Fatal("unsafe path accepted")
			}
		})
	}
	if e := extractAndroidZIP(archiveForTest(t, []string{"link"}, true), t.TempDir()); e == nil {
		t.Fatal("symlink accepted")
	}
}
func TestAndroidZIPPreservesExistingFiles(t *testing.T) {
	dest := t.TempDir()
	_ = os.WriteFile(filepath.Join(dest, "gradlew"), []byte("keep"), 0600)
	if e := extractAndroidZIP(archiveForTest(t, []string{"gradlew"}, false), dest); e == nil {
		t.Fatal("existing file overwritten")
	}
	data, _ := os.ReadFile(filepath.Join(dest, "gradlew"))
	if string(data) != "keep" {
		t.Fatal("content changed")
	}
}
func TestAndroidZIPExtractsProject(t *testing.T) {
	dest := t.TempDir()
	if e := extractAndroidZIP(archiveForTest(t, []string{"gradlew", "app/src/main/Test.java"}, false), dest); e != nil {
		t.Fatal(e)
	}
	if b, e := os.ReadFile(filepath.Join(dest, "app/src/main/Test.java")); e != nil || string(b) != "sample" {
		t.Fatal("missing content")
	}
}
func TestAndroidDownloadsOnlySuccessfulJobs(t *testing.T) {
	h := NewAndroidHandler()
	h.jobs["failed"] = &AndroidBuild{ID: "failed", State: "failed"}
	r := chi.NewRouter()
	r.Get("/{id}", h.Download)
	for _, id := range []string{"missing", "failed"} {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest("GET", "/"+id, nil))
		if w.Code != 404 {
			t.Fatalf("%s: %d", id, w.Code)
		}
	}
}
func TestAndroidStatusDoesNotExposeHostPath(t *testing.T) {
	h := NewAndroidHandler()
	h.jobs["done"] = &AndroidBuild{ID: "done", State: "success", APK: "/private/build/app-debug.apk"}
	r := chi.NewRouter()
	r.Get("/{id}", h.Status)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("GET", "/done", nil))
	if strings.Contains(w.Body.String(), "/private") || !strings.Contains(w.Body.String(), "app-debug.apk") {
		t.Fatal(w.Body.String())
	}
}
func TestAndroidLogIsBounded(t *testing.T) {
	h := NewAndroidHandler()
	j := &AndroidBuild{}
	l := androidLog{h, j}
	_, _ = l.Write(bytes.Repeat([]byte("x"), 3<<20))
	if len(j.Log) > (2<<20)+100 {
		t.Fatal("log unbounded")
	}
}
