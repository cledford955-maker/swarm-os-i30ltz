package handlers

// Android builds execute the signed-in user's project on the paired build host.
// They never run as root; ZIP extraction and APK retrieval stay inside each job.
import (
	"archive/zip"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
)

type AndroidBuild struct {
	ID        string `json:"id"`
	State     string `json:"state"`
	Log       string `json:"log"`
	Error     string `json:"error,omitempty"`
	APK       string `json:"apk,omitempty"`
	directory string
}
type AndroidHandler struct {
	mu      sync.Mutex
	jobs    map[string]*AndroidBuild
	running bool
	root    string
}

func NewAndroidHandler() *AndroidHandler {
	root := os.Getenv("I30LTZ_ANDROID_BUILDS")
	if root == "" {
		home, _ := os.UserHomeDir()
		root = filepath.Join(home, ".local", "state", "i30ltz-companion", "android-builds")
	}
	return &AndroidHandler{jobs: make(map[string]*AndroidBuild), root: root}
}
func androidSDK() string {
	for _, p := range []string{os.Getenv("ANDROID_HOME"), os.Getenv("ANDROID_SDK_ROOT"), filepath.Join(os.Getenv("HOME"), "Android", "Sdk")} {
		if st, e := os.Stat(filepath.Join(p, "platform-tools")); e == nil && st.IsDir() {
			return p
		}
	}
	return ""
}
func adbExecutable() (string, error) {
	if p, e := exec.LookPath("adb"); e == nil {
		return p, nil
	}
	p := filepath.Join(androidSDK(), "platform-tools", "adb")
	if st, e := os.Stat(p); e == nil && !st.IsDir() {
		return p, nil
	}
	return "", fmt.Errorf("ADB is not installed on the paired computer")
}
func (h *AndroidHandler) Capabilities(w http.ResponseWriter, r *http.Request) {
	_, javaErr := exec.LookPath("java")
	_, adbErr := adbExecutable()
	writeJSON(w, map[string]any{"buildHost": "paired computer", "sdkAvailable": androidSDK() != "", "javaAvailable": javaErr == nil, "adbAvailable": adbErr == nil, "maxUploadBytes": 100 << 20})
}
func extractAndroidZIP(source, dest string) error {
	z, e := zip.OpenReader(source)
	if e != nil {
		return e
	}
	defer z.Close()
	if len(z.File) > 10000 {
		return fmt.Errorf("project contains too many files")
	}
	var total int64
	for _, f := range z.File {
		name := strings.ReplaceAll(f.Name, "\\", "/")
		if name == "" || strings.HasPrefix(name, "/") || strings.Contains(name, ":") || f.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("invalid project path: %q", name)
		}
		for _, part := range strings.Split(name, "/") {
			if part == ".." {
				return fmt.Errorf("project path escapes root")
			}
		}
		target := filepath.Join(dest, filepath.FromSlash(name))
		rel, e := filepath.Rel(dest, target)
		if e != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
			return fmt.Errorf("invalid project path")
		}
		if f.FileInfo().IsDir() {
			if e = os.MkdirAll(target, 0700); e != nil {
				return e
			}
			continue
		}
		if f.UncompressedSize64 > 300<<20 {
			return fmt.Errorf("project file too large")
		}
		if e = os.MkdirAll(filepath.Dir(target), 0700); e != nil {
			return e
		}
		src, e := f.Open()
		if e != nil {
			return e
		}
		dst, e := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if e != nil {
			src.Close()
			return e
		}
		n, copyErr := io.Copy(dst, io.LimitReader(src, (300<<20)-total+1))
		closeErr := dst.Close()
		src.Close()
		total += n
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
		if total > 300<<20 {
			return fmt.Errorf("expanded project exceeds 300 MiB")
		}
	}
	return nil
}
func (h *AndroidHandler) Start(w http.ResponseWriter, r *http.Request) {
	if os.Geteuid() == 0 {
		http.Error(w, "Build service must run as a normal user", 503)
		return
	}
	if androidSDK() == "" {
		http.Error(w, "Android SDK missing on paired computer", 503)
		return
	}
	h.mu.Lock()
	if h.running {
		h.mu.Unlock()
		http.Error(w, "Another Android build is running; try again after it finishes", 409)
		return
	}
	h.running = true
	h.mu.Unlock()
	accepted := false
	defer func() {
		if !accepted {
			h.mu.Lock()
			h.running = false
			h.mu.Unlock()
		}
	}()
	b := make([]byte, 16)
	if _, e := rand.Read(b); e != nil {
		http.Error(w, "Could not allocate build", 500)
		return
	}
	id := hex.EncodeToString(b)
	dir := filepath.Join(h.root, id)
	if e := os.MkdirAll(dir, 0700); e != nil {
		http.Error(w, e.Error(), 500)
		return
	}
	archive := filepath.Join(dir, "upload.zip")
	f, e := os.OpenFile(archive, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if e != nil {
		http.Error(w, e.Error(), 500)
		return
	}
	_, e = io.Copy(f, http.MaxBytesReader(w, r.Body, 100<<20))
	f.Close()
	if e != nil {
		os.Remove(archive)
		http.Error(w, "Upload failed or exceeds 100 MiB", 413)
		return
	}
	project := filepath.Join(dir, "project")
	if e = extractAndroidZIP(archive, project); e != nil {
		os.Remove(archive)
		http.Error(w, e.Error(), 400)
		return
	}
	os.Remove(archive)
	if _, e = os.Stat(filepath.Join(project, "gradlew")); e != nil {
		http.Error(w, "Project must include gradlew and its gradle/wrapper files at ZIP root", 400)
		return
	}
	job := &AndroidBuild{ID: id, State: "running", directory: dir}
	h.mu.Lock()
	h.jobs[id] = job
	h.mu.Unlock()
	accepted = true
	go h.build(job, project)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	writeJSON(w, map[string]string{"id": id, "state": "running"})
}

type androidLog struct {
	h   *AndroidHandler
	job *AndroidBuild
}

func (l androidLog) Write(p []byte) (int, error) {
	l.h.mu.Lock()
	defer l.h.mu.Unlock()
	l.job.Log += string(p)
	if len(l.job.Log) > 2<<20 {
		l.job.Log = "[Earlier log trimmed]\n" + l.job.Log[len(l.job.Log)-(2<<20):]
	}
	return len(p), nil
}
func (h *AndroidHandler) build(job *AndroidBuild, project string) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Minute)
	defer cancel()
	// SDK location is always the host's SDK, never a phone's local.properties.
	sdk := androidSDK()
	e := os.WriteFile(filepath.Join(project, "local.properties"), []byte("sdk.dir="+strings.ReplaceAll(sdk, "\\", "\\\\")+"\n"), 0600)
	if e == nil {
		cmd := exec.CommandContext(ctx, "sh", "./gradlew", "--no-daemon", "--console=plain", "assembleDebug")
		cmd.Dir = project
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
		cmd.WaitDelay = 5 * time.Second
		// Do not forward service API keys/tokens into Gradle subprocesses.
		cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + os.Getenv("HOME"), "LANG=C.UTF-8", "ANDROID_HOME=" + sdk, "ANDROID_SDK_ROOT=" + sdk}
		if java := os.Getenv("JAVA_HOME"); java != "" {
			cmd.Env = append(cmd.Env, "JAVA_HOME="+java)
		}
		cmd.Stdout = androidLog{h, job}
		cmd.Stderr = cmd.Stdout
		e = cmd.Run()
	}
	apk := ""
	if e == nil {
		e = filepath.WalkDir(project, func(p string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.Type()&os.ModeSymlink != 0 {
				return nil
			}
			if !d.IsDir() && strings.HasSuffix(p, "-debug.apk") && strings.Contains(filepath.ToSlash(p), "/build/outputs/apk/") {
				if apk != "" {
					return fmt.Errorf("Multiple debug APKs: build a single application module")
				}
				apk = p
			}
			return nil
		})
		if e == nil && apk == "" {
			e = fmt.Errorf("Gradle finished without a debug APK")
		}
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	h.running = false
	if e != nil {
		job.State = "failed"
		job.Error = e.Error()
	} else {
		job.State = "success"
		job.APK = apk
	}
	snapshot := *job
	snapshot.APK = filepath.Base(apk)
	if apk == "" {
		snapshot.APK = ""
	}
	encoded, _ := json.MarshalIndent(snapshot, "", "  ")
	_ = os.WriteFile(filepath.Join(job.directory, "result.json"), encoded, 0600)
}
func (h *AndroidHandler) lookup(id string) (AndroidBuild, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	job, ok := h.jobs[id]
	if !ok {
		return AndroidBuild{}, false
	}
	return *job, true
}
func (h *AndroidHandler) Status(w http.ResponseWriter, r *http.Request) {
	job, ok := h.lookup(chi.URLParam(r, "id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	if job.APK != "" {
		job.APK = filepath.Base(job.APK)
	}
	writeJSON(w, job)
}
func (h *AndroidHandler) Download(w http.ResponseWriter, r *http.Request) {
	job, ok := h.lookup(chi.URLParam(r, "id"))
	if !ok || job.State != "success" {
		http.Error(w, "APK not available", 404)
		return
	}
	w.Header().Set("Content-Type", "application/vnd.android.package-archive")
	w.Header().Set("Content-Disposition", `attachment; filename="app-debug.apk"`)
	http.ServeFile(w, r, job.APK)
}
func (h *AndroidHandler) Devices(w http.ResponseWriter, r *http.Request) {
	p, e := adbExecutable()
	if e != nil {
		http.Error(w, e.Error(), 503)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	out, e := exec.CommandContext(ctx, p, "devices", "-l").CombinedOutput()
	if e != nil {
		http.Error(w, string(out), 502)
		return
	}
	writeJSON(w, map[string]string{"output": string(out)})
}

var serialPattern = regexp.MustCompile(`^[A-Za-z0-9._:\[\]-]{1,128}$`)

func (h *AndroidHandler) ADB(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Action  string `json:"action"`
		Address string `json:"address"`
		Code    string `json:"code"`
		Serial  string `json:"serial"`
		BuildID string `json:"buildId"`
	}
	if e := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&req); e != nil {
		http.Error(w, "Invalid ADB request", 400)
		return
	}
	p, e := adbExecutable()
	if e != nil {
		http.Error(w, e.Error(), 503)
		return
	}
	var args []string
	switch req.Action {
	case "pair", "connect":
		host, port, e := net.SplitHostPort(req.Address)
		if e != nil || host == "" || port == "" || strings.HasPrefix(host, "-") {
			http.Error(w, "Use device IP:port from Wireless debugging", 400)
			return
		}
		if req.Action == "pair" && !regexp.MustCompile(`^\d{6}$`).MatchString(req.Code) {
			http.Error(w, "Enter the six-digit pairing code", 400)
			return
		}
		args = []string{req.Action, req.Address}
	case "install":
		if !serialPattern.MatchString(req.Serial) || strings.HasPrefix(req.Serial, "-") {
			http.Error(w, "Choose an ADB device serial", 400)
			return
		}
		job, ok := h.lookup(req.BuildID)
		if !ok || job.State != "success" {
			http.Error(w, "Build a successful APK first", 400)
			return
		}
		args = []string{"-s", req.Serial, "install", "-r", job.APK}
	default:
		http.Error(w, "Unsupported ADB operation", 400)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, p, args...)
	if req.Action == "pair" {
		cmd.Stdin = strings.NewReader(req.Code + "\n")
	}
	out, e := cmd.CombinedOutput()
	output := string(out)
	if req.Code != "" {
		output = strings.ReplaceAll(output, req.Code, "[redacted]")
	}
	ok := e == nil && !strings.Contains(strings.ToLower(output), "failed") && !strings.Contains(strings.ToLower(output), "cannot connect")
	if req.Action == "install" {
		ok = ok && strings.Contains(output, "Success")
	}
	writeJSON(w, map[string]any{"success": ok, "output": output})
}
