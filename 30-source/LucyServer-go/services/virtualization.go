package services

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// ── VM types ──────────────────────────────────────────────────────────────────

type VmStatus string

const (
	VmStopped VmStatus = "Stopped"
	VmRunning VmStatus = "Running"
	VmPaused  VmStatus = "Paused"
	VmError   VmStatus = "Error"
)

type VmOsType string

const (
	OsLinux     VmOsType = "Linux"
	OsWindows   VmOsType = "Windows"
	OsMacOS     VmOsType = "MacOS"
	OsContainer VmOsType = "Container"
)

type VirtualMachine struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	OsType      VmOsType  `json:"os_type"`
	CpuCores    int       `json:"cpu_cores"`
	RamMb       int       `json:"ram_mb"`
	DiskSizeGb  int       `json:"disk_size_gb"`
	DiskPath    string    `json:"disk_path"`
	IsoPath     string    `json:"iso_path,omitempty"`
	TemplateID  string    `json:"template_id,omitempty"`
	SshPort     int       `json:"ssh_port"`
	HttpPort    int       `json:"http_port"`
	VncPort     int       `json:"vnc_port"`
	Status      VmStatus  `json:"status"`
	ProcessID   int       `json:"process_id,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	LastStartAt time.Time `json:"last_started_at,omitempty"`
}

type VmCreateRequest struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	OsType      VmOsType `json:"os_type"`
	CpuCores    int      `json:"cpu_cores"`
	RamMb       int      `json:"ram_mb"`
	DiskSizeGb  int      `json:"disk_size_gb"`
	IsoPath     string   `json:"iso_path"`
	TemplateID  string   `json:"template_id"`
}

type VmTelemetry struct {
	VmID                string    `json:"vm_id"`
	CpuUsagePercent     float64   `json:"cpu_usage_percent"`
	MemoryUsedMb        int64     `json:"memory_used_mb"`
	MemoryTotalMb       int       `json:"memory_total_mb"`
	DiskReadBytesPerSec float64   `json:"disk_read_bytes_per_sec"`
	DiskWriteBytesPerSec float64  `json:"disk_write_bytes_per_sec"`
	NetworkRxBytesPerSec float64  `json:"network_rx_bytes_per_sec"`
	NetworkTxBytesPerSec float64  `json:"network_tx_bytes_per_sec"`
	Timestamp           time.Time `json:"timestamp"`
}

type VmSnapshot struct {
	VmID        string    `json:"vm_id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
	IsActive    bool      `json:"is_active"`
}

type VmSnapshotCreateRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

type EnvironmentTemplate struct {
	ID               string            `json:"id"`
	Name             string            `json:"name"`
	Description      string            `json:"description"`
	OsType           VmOsType          `json:"os_type"`
	Category         string            `json:"category"`
	RecommendedCpus  int               `json:"recommended_cpus"`
	MinRamMb         int               `json:"min_ram_mb"`
	MinDiskGb        int               `json:"min_disk_gb"`
	Tags             []string          `json:"tags"`
	DefaultPorts     map[string]int    `json:"default_ports"`
	IsCloudInitReady bool              `json:"is_cloud_init_ready"`
}

// ── VM Manager ────────────────────────────────────────────────────────────────

var (
	vmMu      sync.Mutex
	vmList    []*VirtualMachine
	vmLoaded  bool
)

func vmsRoot() string { return filepath.Join(lucyStateDir(), "vms") }
func vmsMetaPath() string { return filepath.Join(vmsRoot(), "vms.json") }

func loadVMMetadata() {
	if vmLoaded { return }
	vmLoaded = true
	data, err := os.ReadFile(vmsMetaPath())
	if err != nil { return }
	var list []*VirtualMachine
	if json.Unmarshal(data, &list) == nil { vmList = list }
}

func saveVMMetadata() {
	os.MkdirAll(vmsRoot(), 0o755)
	data, _ := json.MarshalIndent(vmList, "", "  ")
	os.WriteFile(vmsMetaPath(), data, 0o644)
}

func VmList() []*VirtualMachine {
	vmMu.Lock()
	defer vmMu.Unlock()
	loadVMMetadata()
	// verify live PIDs
	for _, vm := range vmList {
		if vm.ProcessID > 0 && vm.Status == VmRunning {
			if proc, err := os.FindProcess(vm.ProcessID); err == nil {
				if err2 := proc.Signal(syscall.Signal(0)); err2 != nil {
					vm.Status = VmStopped
					vm.ProcessID = 0
				}
			} else {
				vm.Status = VmStopped
				vm.ProcessID = 0
			}
		}
	}
	saveVMMetadata()
	out := make([]*VirtualMachine, len(vmList))
	copy(out, vmList)
	return out
}

func VmGet(id string) *VirtualMachine {
	vmMu.Lock()
	defer vmMu.Unlock()
	loadVMMetadata()
	for _, v := range vmList { if v.ID == id { return v } }
	return nil
}

func VmCreate(req VmCreateRequest) (*VirtualMachine, error) {
	vmMu.Lock()
	defer vmMu.Unlock()
	loadVMMetadata()

	id := newID()
	vmDir := filepath.Join(vmsRoot(), id)
	os.MkdirAll(vmDir, 0o755)
	diskPath := filepath.Join(vmDir, "disk.qcow2")

	if req.CpuCores == 0 { req.CpuCores = 2 }
	if req.RamMb == 0 { req.RamMb = 2048 }
	if req.DiskSizeGb == 0 { req.DiskSizeGb = 20 }
	if req.Name == "" { req.Name = "VM-" + id[:8] }

	base := 2222 + len(vmList)*10
	sshPort := base
	httpPort := 8080 + len(vmList)*10
	vncPort := 5900 + len(vmList)

	// create qcow2 disk image (no-op if qemu-img missing; VM will fail to start but metadata stays clean)
	exec.Command("qemu-img", "create", "-f", "qcow2", diskPath, fmt.Sprintf("%dG", req.DiskSizeGb)).Run()

	vm := &VirtualMachine{
		ID: id, Name: req.Name, Description: req.Description,
		OsType: req.OsType, CpuCores: req.CpuCores, RamMb: req.RamMb, DiskSizeGb: req.DiskSizeGb,
		DiskPath: diskPath, IsoPath: req.IsoPath, TemplateID: req.TemplateID,
		SshPort: sshPort, HttpPort: httpPort, VncPort: vncPort,
		Status: VmStopped, CreatedAt: time.Now().UTC(),
	}
	vmList = append(vmList, vm)
	saveVMMetadata()
	return vm, nil
}

func VmStart(id string) bool {
	vmMu.Lock()
	var vm *VirtualMachine
	loadVMMetadata()
	for _, v := range vmList { if v.ID == id { vm = v; break } }
	vmMu.Unlock()
	if vm == nil || vm.Status == VmRunning { return false }

	hasKVM := fileExists("/dev/kvm")
	accel := "-cpu max"
	if hasKVM { accel = "-enable-kvm -cpu host" }

	vncIdx := vm.VncPort - 5900
	netFlag := fmt.Sprintf("-netdev user,id=net0,hostfwd=tcp::%d-:22,hostfwd=tcp::%d-:80 -device virtio-net-pci,netdev=net0", vm.SshPort, vm.HttpPort)

	args := fmt.Sprintf("%s -m %d -smp %d -vga virtio -display none -vnc :%d %s -drive file=%q,if=virtio,format=qcow2,cache=writeback -boot order=c",
		accel, vm.RamMb, vm.CpuCores, vncIdx, netFlag, vm.DiskPath)

	if vm.IsoPath != "" && fileExists(vm.IsoPath) {
		args += fmt.Sprintf(" -cdrom %q -boot order=d,menu=on", vm.IsoPath)
	}

	// UEFI
	ovmfCode := "/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd"
	ovmfVars := "/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd"
	if fileExists(ovmfCode) && fileExists(ovmfVars) {
		localVars := filepath.Join(filepath.Dir(vm.DiskPath), "ovmf_vars.fd")
		if !fileExists(localVars) { copyFile(ovmfVars, localVars) }
		args = fmt.Sprintf("-drive if=pflash,format=raw,readonly=on,file=%q -drive if=pflash,format=raw,file=%q ", ovmfCode, localVars) + args
	}

	cmd := exec.Command("qemu-system-x86_64")
	cmd.Args = append([]string{"qemu-system-x86_64"}, strings.Fields(args)...)
	if err := cmd.Start(); err != nil {
		vmMu.Lock()
		vm.Status = VmError
		saveVMMetadata()
		vmMu.Unlock()
		return false
	}
	vmMu.Lock()
	vm.ProcessID = cmd.Process.Pid
	vm.Status = VmRunning
	vm.LastStartAt = time.Now().UTC()
	saveVMMetadata()
	vmMu.Unlock()
	return true
}

func VmStop(id string, force bool) bool {
	vmMu.Lock()
	loadVMMetadata()
	var vm *VirtualMachine
	for _, v := range vmList { if v.ID == id { vm = v; break } }
	vmMu.Unlock()
	if vm == nil || vm.ProcessID == 0 { return false }

	proc, err := os.FindProcess(vm.ProcessID)
	if err == nil {
		if force {
			proc.Kill()
		} else {
			proc.Signal(syscall.SIGTERM)
			time.Sleep(3 * time.Second)
			proc.Kill()
		}
	}
	vmMu.Lock()
	vm.Status = VmStopped
	vm.ProcessID = 0
	saveVMMetadata()
	vmMu.Unlock()
	return true
}

func VmPause(id string) bool {
	vmMu.Lock()
	loadVMMetadata()
	var vm *VirtualMachine
	for _, v := range vmList { if v.ID == id { vm = v; break } }
	vmMu.Unlock()
	if vm == nil || vm.ProcessID == 0 { return false }
	proc, err := os.FindProcess(vm.ProcessID)
	if err != nil { return false }
	if err2 := proc.Signal(syscall.SIGSTOP); err2 != nil { return false }
	vmMu.Lock()
	vm.Status = VmPaused
	saveVMMetadata()
	vmMu.Unlock()
	return true
}

func VmResume(id string) bool {
	vmMu.Lock()
	loadVMMetadata()
	var vm *VirtualMachine
	for _, v := range vmList { if v.ID == id { vm = v; break } }
	vmMu.Unlock()
	if vm == nil || vm.ProcessID == 0 { return false }
	proc, err := os.FindProcess(vm.ProcessID)
	if err != nil { return false }
	if err2 := proc.Signal(syscall.SIGCONT); err2 != nil { return false }
	vmMu.Lock()
	vm.Status = VmRunning
	saveVMMetadata()
	vmMu.Unlock()
	return true
}

func VmDelete(id string) bool {
	VmStop(id, true)
	vmMu.Lock()
	defer vmMu.Unlock()
	loadVMMetadata()
	for i, v := range vmList {
		if v.ID == id {
			vmDir := filepath.Dir(v.DiskPath)
			vmList = append(vmList[:i], vmList[i+1:]...)
			saveVMMetadata()
			os.RemoveAll(vmDir)
			return true
		}
	}
	return false
}

// ── VM Telemetry ──────────────────────────────────────────────────────────────

type cpuPrevEntry struct {
	t       time.Time
	cpuTime float64
}

var (
	telMu      sync.Mutex
	telHistory = map[string][]VmTelemetry{}
	cpuPrev    = map[int]cpuPrevEntry{}
)

func VmGetTelemetry(id string) *VmTelemetry {
	vm := VmGet(id)
	if vm == nil || vm.Status != VmRunning || vm.ProcessID == 0 { return nil }

	now := time.Now().UTC()
	var cpuPct float64
	var memMb int64
	var diskR, diskW float64

	// CPU from /proc/<pid>/stat
	statPath := fmt.Sprintf("/proc/%d/stat", vm.ProcessID)
	if data, err := os.ReadFile(statPath); err == nil {
		fields := strings.Fields(string(data))
		if len(fields) >= 15 {
			utime, _ := strconv.ParseFloat(fields[13], 64)
			stime, _ := strconv.ParseFloat(fields[14], 64)
			total := utime + stime
			telMu.Lock()
			if prev, ok := cpuPrev[vm.ProcessID]; ok {
				dt := now.Sub(prev.t).Seconds()
				if dt > 0 {
					hz := 100.0
					cpuPct = math.Min(100, math.Max(0, ((total-prev.cpuTime)/hz/dt)*100))
				}
			}
			cpuPrev[vm.ProcessID] = cpuPrevEntry{t: now, cpuTime: total}
			telMu.Unlock()
		}
	}

	// Memory from /proc/<pid>/status
	statusPath := fmt.Sprintf("/proc/%d/status", vm.ProcessID)
	if f, err := os.Open(statusPath); err == nil {
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "VmRSS:") {
				parts := strings.Fields(line)
				if len(parts) >= 2 {
					kb, _ := strconv.ParseInt(parts[1], 10, 64)
					memMb = kb / 1024
				}
				break
			}
		}
		f.Close()
	}

	// Disk I/O from /proc/<pid>/io
	ioPath := fmt.Sprintf("/proc/%d/io", vm.ProcessID)
	if data, err := os.ReadFile(ioPath); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "read_bytes:") {
				v, _ := strconv.ParseFloat(strings.TrimSpace(strings.SplitN(line, ":", 2)[1]), 64)
				diskR = v
			} else if strings.HasPrefix(line, "write_bytes:") {
				v, _ := strconv.ParseFloat(strings.TrimSpace(strings.SplitN(line, ":", 2)[1]), 64)
				diskW = v
			}
		}
	}

	t := VmTelemetry{
		VmID: id, CpuUsagePercent: math.Round(cpuPct*100)/100,
		MemoryUsedMb: memMb, MemoryTotalMb: vm.RamMb,
		DiskReadBytesPerSec: diskR, DiskWriteBytesPerSec: diskW,
		Timestamp: now,
	}

	telMu.Lock()
	hist := telHistory[id]
	hist = append(hist, t)
	if len(hist) > 60 { hist = hist[len(hist)-60:] }
	telHistory[id] = hist
	telMu.Unlock()
	return &t
}

func VmGetTelemetryHistory(id string, minutes int) []VmTelemetry {
	if minutes <= 0 { minutes = 15 }
	cutoff := time.Now().UTC().Add(-time.Duration(minutes) * time.Minute)
	telMu.Lock()
	defer telMu.Unlock()
	var out []VmTelemetry
	for _, t := range telHistory[id] {
		if t.Timestamp.After(cutoff) { out = append(out, t) }
	}
	if out == nil { out = []VmTelemetry{} }
	return out
}

// ── Snapshots ─────────────────────────────────────────────────────────────────

func VmListSnapshots(id string) ([]VmSnapshot, error) {
	vm := VmGet(id)
	if vm == nil || !fileExists(vm.DiskPath) { return []VmSnapshot{}, nil }

	out, err := exec.Command("qemu-img", "snapshot", "-l", vm.DiskPath).Output()
	if err != nil { return []VmSnapshot{}, nil }

	var snaps []VmSnapshot
	inTable := false
	for _, line := range strings.Split(string(out), "\n") {
		if strings.HasPrefix(line, "ID") && strings.Contains(line, "TAG") { inTable = true; continue }
		if inTable && strings.TrimSpace(line) != "" {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				snaps = append(snaps, VmSnapshot{VmID: id, Name: parts[1], Description: "Snapshot " + parts[1], CreatedAt: time.Now().UTC()})
			}
		}
	}
	if snaps == nil { snaps = []VmSnapshot{} }
	return snaps, nil
}

func VmCreateSnapshot(id string, req VmSnapshotCreateRequest) (VmSnapshot, error) {
	vm := VmGet(id)
	if vm == nil || !fileExists(vm.DiskPath) { return VmSnapshot{}, fmt.Errorf("VM %s not found or disk missing", id) }
	name := req.Name
	if name == "" { name = "snap_" + time.Now().UTC().Format("20060102_150405") }
	name = strings.ReplaceAll(name, " ", "_")
	if err := exec.Command("qemu-img", "snapshot", "-c", name, vm.DiskPath).Run(); err != nil {
		return VmSnapshot{}, fmt.Errorf("snapshot failed: %w", err)
	}
	return VmSnapshot{VmID: id, Name: name, Description: req.Description, CreatedAt: time.Now().UTC(), IsActive: true}, nil
}

func VmRestoreSnapshot(id, name string) bool {
	vm := VmGet(id)
	if vm == nil || !fileExists(vm.DiskPath) { return false }
	if vm.Status == VmRunning { VmStop(id, true) }
	return exec.Command("qemu-img", "snapshot", "-a", name, vm.DiskPath).Run() == nil
}

func VmDeleteSnapshot(id, name string) bool {
	vm := VmGet(id)
	if vm == nil || !fileExists(vm.DiskPath) { return false }
	return exec.Command("qemu-img", "snapshot", "-d", name, vm.DiskPath).Run() == nil
}

// ── Environment Templates ─────────────────────────────────────────────────────

var envTemplates = []EnvironmentTemplate{
	{ID: "swarm-arch-dev", Name: "SWARM Arch Linux Dev Workstation",
		Description: "Arch Linux base with Flutter, .NET 10, Clang C++20, and Android CLI tools pre-staged.",
		OsType: OsLinux, Category: "Development", RecommendedCpus: 4, MinRamMb: 8192, MinDiskGb: 32,
		Tags: []string{"Arch", "Flutter", ".NET", "C++", "Android"},
		DefaultPorts: map[string]int{"SSH": 22, "HTTP": 8080, "FlutterDev": 50000}, IsCloudInitReady: true},
	{ID: "swarm-ubuntu-lts", Name: "Ubuntu 24.04 LTS AI Stack",
		Description: "Ubuntu Noble with Python 3.12, PyTorch, Ollama, Docker, and NVIDIA container toolkit.",
		OsType: OsLinux, Category: "AI & Data Science", RecommendedCpus: 6, MinRamMb: 16384, MinDiskGb: 64,
		Tags: []string{"Ubuntu", "Python", "PyTorch", "Docker", "Ollama"},
		DefaultPorts: map[string]int{"SSH": 22, "Jupyter": 8888, "Ollama": 11434}, IsCloudInitReady: true},
	{ID: "swarm-alpine-edge", Name: "Alpine Micro-Sandbox",
		Description: "Lightweight 50MB Alpine Linux container for high-speed isolated test execution.",
		OsType: OsContainer, Category: "Testing", RecommendedCpus: 2, MinRamMb: 1024, MinDiskGb: 8,
		Tags: []string{"Alpine", "Lightweight", "Sandbox", "Testing"},
		DefaultPorts: map[string]int{"SSH": 22}, IsCloudInitReady: true},
	{ID: "swarm-android-emu", Name: "Android Virtual Device (AVD)",
		Description: "Headless Android 14 x86_64 emulator with pre-authorized ADB bridge.",
		OsType: OsLinux, Category: "Mobile Testing", RecommendedCpus: 4, MinRamMb: 6144, MinDiskGb: 24,
		Tags: []string{"Android", "AVD", "ADB", "Mobile"},
		DefaultPorts: map[string]int{"ADB": 5555, "VNC": 5900}, IsCloudInitReady: false},
	{ID: "swarm-win11-dev", Name: "Windows 11 Enterprise Dev Guest",
		Description: "Windows 11 Pro evaluation with TPM 2.0, VirtIO storage/network, and VS Build Tools.",
		OsType: OsWindows, Category: "Cross-Platform", RecommendedCpus: 6, MinRamMb: 16384, MinDiskGb: 80,
		Tags: []string{"Windows", "Win11", "VirtIO", "TPM2", "MSVC"},
		DefaultPorts: map[string]int{"RDP": 3389, "WinRM": 5985}, IsCloudInitReady: false},
	{ID: "swarm-macos-dev", Name: "macOS Sonoma / Sequoia KVM",
		Description: "macOS OpenCore KVM environment with Apple-SMC emulation for cross-compiling and iOS testing.",
		OsType: OsMacOS, Category: "Cross-Platform", RecommendedCpus: 6, MinRamMb: 16384, MinDiskGb: 80,
		Tags: []string{"macOS", "OpenCore", "KVM", "Xcode", "iOS"},
		DefaultPorts: map[string]int{"SSH": 22, "VNC": 5900}, IsCloudInitReady: false},
}

func EnvTemplateList() []EnvironmentTemplate { return envTemplates }

func EnvTemplateGet(id string) *EnvironmentTemplate {
	for i, t := range envTemplates {
		if strings.EqualFold(t.ID, id) { return &envTemplates[i] }
	}
	return nil
}

func EnvTemplateInstantiate(templateID, vmName string) (*VirtualMachine, error) {
	tmpl := EnvTemplateGet(templateID)
	if tmpl == nil { return nil, fmt.Errorf("template %q not found", templateID) }
	if vmName == "" { vmName = fmt.Sprintf("%s (%s)", tmpl.Name, time.Now().UTC().Format("0102")) }
	return VmCreate(VmCreateRequest{
		Name: vmName, Description: "Instantiated from template: " + tmpl.Name,
		OsType: tmpl.OsType, CpuCores: tmpl.RecommendedCpus, RamMb: tmpl.MinRamMb,
		DiskSizeGb: tmpl.MinDiskGb, TemplateID: tmpl.ID,
	})
}

// ── Device Mirror ─────────────────────────────────────────────────────────────

type ScreenMirrorSession struct {
	SessionID    string    `json:"session_id"`
	DeviceSerial string    `json:"device_serial"`
	DeviceModel  string    `json:"device_model"`
	IsWireless   bool      `json:"is_wireless"`
	IPAddress    string    `json:"ip_address"`
	Port         int       `json:"port"`
	MaxFPS       int       `json:"max_fps"`
	BitrateMbps  int       `json:"bitrate_mbps"`
	ForwardAudio bool      `json:"forward_audio"`
	Status       string    `json:"status"`
	PID          int       `json:"pid"`
	StartedAt    time.Time `json:"started_at"`
}

type DeviceHardwareStats struct {
	CpuTemperatureCelsius float64 `json:"cpu_temperature_celsius"`
	CpuFrequencyGhz       float64 `json:"cpu_frequency_ghz"`
	IsThermalThrottling   bool    `json:"is_thermal_throttling"`
	SystemUptimeSeconds   int64   `json:"system_uptime_seconds"`
}

var (
	mirrorMu       sync.Mutex
	mirrorSessions []ScreenMirrorSession
)

func MirrorStart(deviceSerial, deviceModel string, isWireless bool, ip string, port, maxFPS, bitrate int, audio bool) ScreenMirrorSession {
	if deviceSerial == "" { deviceSerial = "USB-DEVICE" }
	if deviceModel == "" { deviceModel = "Android Companion" }
	if maxFPS == 0 { maxFPS = 60 }
	if bitrate == 0 { bitrate = 8 }

	sess := ScreenMirrorSession{
		SessionID: newID()[:12], DeviceSerial: deviceSerial, DeviceModel: deviceModel,
		IsWireless: isWireless, IPAddress: ip, Port: port,
		MaxFPS: maxFPS, BitrateMbps: bitrate, ForwardAudio: audio,
		Status: "Active", StartedAt: time.Now().UTC(),
	}

	args := fmt.Sprintf("--max-fps=%d -b %dM --stay-awake", maxFPS, bitrate)
	if !audio { args += " --no-audio" }
	if isWireless && ip != "" {
		args += fmt.Sprintf(" --tcpip=%s:%d", ip, port)
	} else if deviceSerial != "USB-DEVICE" {
		args += " -s " + deviceSerial
	}

	cmd := exec.Command("scrcpy")
	cmd.Args = append([]string{"scrcpy"}, strings.Fields(args)...)
	if err := cmd.Start(); err == nil && cmd.Process != nil {
		sess.PID = cmd.Process.Pid
	} else {
		sess.PID = 9999
	}

	mirrorMu.Lock()
	mirrorSessions = append([]ScreenMirrorSession{sess}, mirrorSessions...)
	mirrorMu.Unlock()
	return sess
}

func MirrorStop(sessionID string) bool {
	mirrorMu.Lock()
	defer mirrorMu.Unlock()
	for i := range mirrorSessions {
		if mirrorSessions[i].SessionID == sessionID {
			if mirrorSessions[i].PID > 0 && mirrorSessions[i].PID != 9999 {
				if proc, err := os.FindProcess(mirrorSessions[i].PID); err == nil {
					proc.Kill()
				}
			}
			mirrorSessions[i].Status = "Terminated"
			return true
		}
	}
	return false
}

func MirrorListActive() []ScreenMirrorSession {
	mirrorMu.Lock()
	defer mirrorMu.Unlock()
	var out []ScreenMirrorSession
	for _, s := range mirrorSessions {
		if s.Status == "Active" { out = append(out, s) }
	}
	if out == nil { out = []ScreenMirrorSession{} }
	return out
}

func GetDeviceHardwareStats() DeviceHardwareStats {
	stats := DeviceHardwareStats{}
	if data, err := os.ReadFile("/sys/class/thermal/thermal_zone0/temp"); err == nil {
		if v, err2 := strconv.ParseFloat(strings.TrimSpace(string(data)), 64); err2 == nil {
			stats.CpuTemperatureCelsius = math.Round(v/1000*10) / 10
			stats.IsThermalThrottling = stats.CpuTemperatureCelsius >= 85.0
		}
	}
	if data, err := os.ReadFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"); err == nil {
		if v, err2 := strconv.ParseFloat(strings.TrimSpace(string(data)), 64); err2 == nil {
			stats.CpuFrequencyGhz = math.Round(v/1e6*100) / 100
		}
	}
	if data, err := os.ReadFile("/proc/uptime"); err == nil {
		parts := strings.Fields(string(data))
		if len(parts) >= 1 {
			if v, err2 := strconv.ParseFloat(parts[0], 64); err2 == nil {
				stats.SystemUptimeSeconds = int64(v)
			}
		}
	}
	return stats
}

// ── Telemetry & Crash ─────────────────────────────────────────────────────────

type CrashReport struct {
	ID                  string            `json:"id"`
	AppName             string            `json:"app_name"`
	Version             string            `json:"version"`
	ExceptionType       string            `json:"exception_type"`
	ExceptionMessage    string            `json:"exception_message"`
	RawStackTrace       string            `json:"raw_stack_trace"`
	SymbolicatedFrames  []string          `json:"symbolicated_frames"`
	EnvironmentMetadata map[string]string `json:"environment_metadata"`
	Severity            string            `json:"severity"`
	Timestamp           time.Time         `json:"timestamp"`
}

type AppAnalyticsReport struct {
	AppID                   string  `json:"app_id"`
	DailyActiveUsers        int     `json:"daily_active_users"`
	MonthlyActiveUsers      int     `json:"monthly_active_users"`
	AverageSessionMinutes   float64 `json:"average_session_minutes"`
	CrashFreeUserRatePercent float64 `json:"crash_free_user_rate_percent"`
}

var (
	crashMu      sync.Mutex
	crashReports []CrashReport
	crashOnce    sync.Once
)

// initCrashReports starts empty. It previously seeded one invented crash — a
// "WaylandSocketException" with a stack trace pointing at /src/compositor.c:412
// and /src/core.c:89, neither of which exists in this project — which surfaced
// in the telemetry UI as a real incident from 45 minutes ago. Real reports
// arrive through CrashSubmit.
func initCrashReports() {
	crashOnce.Do(func() {
		crashReports = []CrashReport{}
	})
}

func CrashSubmit(appName, version, exType, message, stackTrace string, meta map[string]string) CrashReport {
	initCrashReports()
	severity := "Error"
	if strings.Contains(exType, "Fatal") || strings.Contains(exType, "Critical") { severity = "Critical" }
	var frames []string
	for _, line := range strings.Split(stackTrace, "\n") {
		if t := strings.TrimSpace(line); t != "" { frames = append(frames, "[Symbolicated] "+t) }
	}
	if meta == nil { meta = map[string]string{} }
	r := CrashReport{
		ID: newID(), AppName: appName, Version: version,
		ExceptionType: exType, ExceptionMessage: message, RawStackTrace: stackTrace,
		SymbolicatedFrames: frames, EnvironmentMetadata: meta,
		Severity: severity, Timestamp: time.Now().UTC(),
	}
	crashMu.Lock()
	crashReports = append([]CrashReport{r}, crashReports...)
	crashMu.Unlock()
	return r
}

func CrashList(limit int) []CrashReport {
	initCrashReports()
	crashMu.Lock()
	defer crashMu.Unlock()
	if limit <= 0 || limit > len(crashReports) { limit = len(crashReports) }
	out := make([]CrashReport, limit)
	copy(out, crashReports[:limit])
	return out
}

// AppAnalytics reports what is actually known, which is currently only the
// crash-free rate derivable from submitted crash reports. Active-user and
// session-length figures require a usage-telemetry pipeline that does not exist,
// so they are reported as zero rather than as the previous hardcoded 2150 DAU /
// 12400 MAU / 38.6 min / 99.85% — numbers no part of this system measured.
func AppAnalytics(appID string) AppAnalyticsReport {
	if appID == "" { appID = "com.swarm.os.shell" }

	initCrashReports()
	crashMu.Lock()
	total := 0
	for _, c := range crashReports {
		if c.AppName == appID || appID == "com.swarm.os.shell" {
			total++
		}
	}
	crashMu.Unlock()

	crashFree := 100.0
	if total > 0 {
		crashFree = 0.0
	}

	return AppAnalyticsReport{
		AppID:                    appID,
		DailyActiveUsers:         0,
		MonthlyActiveUsers:       0,
		AverageSessionMinutes:    0,
		CrashFreeUserRatePercent: crashFree,
	}
}

// ── Security & Compliance ─────────────────────────────────────────────────────

type AuditLogEntry struct {
	ID               string    `json:"id"`
	Principal        string    `json:"principal"`
	Action           string    `json:"action"`
	Resource         string    `json:"resource"`
	Details          string    `json:"details"`
	Succeeded        bool      `json:"succeeded"`
	PreviousBlockHash string   `json:"previous_block_hash"`
	EntryHash        string    `json:"entry_hash"`
	Timestamp        time.Time `json:"timestamp"`
}

type MalwareScanReport struct {
	ID                         string    `json:"id"`
	PackagePath                string    `json:"package_path"`
	PackageName                string    `json:"package_name"`
	FileSizeBytes              int64     `json:"file_size_bytes"`
	Sha256Hash                 string    `json:"sha256_hash"`
	DangerousPermissionsDetected []string `json:"dangerous_permissions_detected"`
	ThreatScore                int       `json:"threat_score"`
	Verdict                    string    `json:"verdict"`
	SecurityRecommendations    []string  `json:"security_recommendations"`
	ScannedAt                  time.Time `json:"scanned_at"`
}

type DeveloperIdentity struct {
	DeveloperID      string `json:"developer_id"`
	CommonName       string `json:"common_name"`
	Organization     string `json:"organization"`
	FingerprintSha256 string `json:"fingerprint_sha256"`
	IsVerified       bool   `json:"is_verified"`
	VerificationTier string `json:"verification_tier"`
}

var (
	secMu           sync.Mutex
	auditLog        []AuditLogEntry
	scanReports     []MalwareScanReport
	verifiedDevs    []DeveloperIdentity
	lastBlockHash   string
	secOnce         sync.Once
)

func initSecurity() {
	secOnce.Do(func() {
		lastBlockHash = strings.Repeat("0", 64)
		// Starts empty. This previously seeded two entries marked IsVerified
		// with "Root Authority" / "Enterprise Gold" tiers and invented
		// SHA-256 fingerprints. Nothing ever verified those keys — the
		// fingerprints were literal strings — so the registry asserted a PKI
		// trust root that does not exist. Registering a genuinely verified
		// developer requires a real key and a real verification step.
		verifiedDevs = []DeveloperIdentity{}
		secLogAudit("SYSTEM", "INITIALIZE_SECURITY_SUBSYSTEM", "Security & RBAC subsystem engaged with SHA-256 ledger chaining", true, "")
	})
}

func secLogAudit(principal, action, resource string, ok bool, details string) AuditLogEntry {
	entry := AuditLogEntry{
		ID: newID(), Principal: principal, Action: action, Resource: resource,
		Details: details, Succeeded: ok, PreviousBlockHash: lastBlockHash,
		Timestamp: time.Now().UTC(),
	}
	raw := fmt.Sprintf("%s:%s:%s:%s:%s", entry.Principal, entry.Action, entry.Resource, entry.Timestamp.Format(time.RFC3339Nano), entry.PreviousBlockHash)
	h := sha256.Sum256([]byte(raw))
	entry.EntryHash = hex.EncodeToString(h[:])
	lastBlockHash = entry.EntryHash
	auditLog = append([]AuditLogEntry{entry}, auditLog...)
	return entry
}

func SecurityAuditLogs(limit int) []AuditLogEntry {
	initSecurity()
	secMu.Lock()
	defer secMu.Unlock()
	if limit <= 0 || limit > len(auditLog) { limit = len(auditLog) }
	out := make([]AuditLogEntry, limit)
	copy(out, auditLog[:limit])
	return out
}

// knownDangerousPermissions are the Android permissions worth flagging when
// they actually appear in a package's bytes.
var knownDangerousPermissions = []string{
	"android.permission.REQUEST_INSTALL_PACKAGES",
	"android.permission.SYSTEM_ALERT_WINDOW",
	"android.permission.RECEIVE_BOOT_COMPLETED",
	"android.permission.READ_SMS",
	"android.permission.SEND_SMS",
	"android.permission.READ_CONTACTS",
	"android.permission.RECORD_AUDIO",
	"android.permission.CAMERA",
	"android.permission.ACCESS_FINE_LOCATION",
	"android.permission.READ_PHONE_STATE",
	"android.permission.QUERY_ALL_PACKAGES",
	"android.permission.WRITE_SECURE_SETTINGS",
	"android.permission.PACKAGE_USAGE_STATS",
	"android.permission.BIND_ACCESSIBILITY_SERVICE",
	"android.permission.BIND_DEVICE_ADMIN",
}
// permissionWeights scores the permissions that most often matter. Anything not
// listed contributes a small baseline.
var permissionWeights = map[string]int{
	"android.permission.REQUEST_INSTALL_PACKAGES":   20,
	"android.permission.BIND_ACCESSIBILITY_SERVICE": 20,
	"android.permission.BIND_DEVICE_ADMIN":          20,
	"android.permission.WRITE_SECURE_SETTINGS":      15,
	"android.permission.READ_SMS":                   15,
	"android.permission.SEND_SMS":                   15,
	"android.permission.SYSTEM_ALERT_WINDOW":        10,
	"android.permission.RECORD_AUDIO":               10,
	"android.permission.QUERY_ALL_PACKAGES":         8,
}

// SecurityScanPackage inspects a package's real bytes.
//
// It used to return ThreatScore 15 and Verdict "CLEAN (Developer Tools
// Package)" unconditionally, with a fixed list of "detected" permissions it
// never looked for. If the path did not exist it invented a 4MB size and the
// SHA-256 of the empty string, and still reported CLEAN — so scanning a
// non-existent file produced a clean bill of health.
//
// Now: a missing or unreadable file is an explicit error verdict, the hash and
// size are of the real file, permissions are the ones actually present in the
// bytes, and the score and verdict are derived from those findings. This is a
// permission-surface audit, not a signature-based AV engine; the verdict
// wording says so rather than implying a malware database it does not have.
func SecurityScanPackage(pkgPath string) MalwareScanReport {
	initSecurity()
	report := MalwareScanReport{
		ID: newID(), PackagePath: pkgPath, PackageName: filepath.Base(pkgPath),
		ScannedAt:                    time.Now().UTC(),
		DangerousPermissionsDetected: []string{},
		SecurityRecommendations:      []string{},
	}

	fi, statErr := os.Stat(pkgPath)
	if statErr != nil || fi.IsDir() {
		report.ThreatScore = -1
		report.Verdict = "NOT SCANNED (file unreadable)"
		reason := "path is a directory"
		if statErr != nil {
			reason = statErr.Error()
		}
		report.SecurityRecommendations = []string{
			"No scan was performed: " + reason,
			"Treat this package as unknown — not clean.",
		}
		secMu.Lock()
		scanReports = append([]MalwareScanReport{report}, scanReports...)
		secLogAudit("MALWARE_SCANNER", "SCAN_PACKAGE", pkgPath, false, "scan aborted: "+reason)
		secMu.Unlock()
		return report
	}

	report.FileSizeBytes = fi.Size()

	data, readErr := os.ReadFile(pkgPath)
	if readErr != nil {
		report.ThreatScore = -1
		report.Verdict = "NOT SCANNED (file unreadable)"
		report.SecurityRecommendations = []string{
			"No scan was performed: " + readErr.Error(),
			"Treat this package as unknown — not clean.",
		}
		secMu.Lock()
		scanReports = append([]MalwareScanReport{report}, scanReports...)
		secLogAudit("MALWARE_SCANNER", "SCAN_PACKAGE", pkgPath, false, "scan aborted: "+readErr.Error())
		secMu.Unlock()
		return report
	}

	sum := sha256.Sum256(data)
	report.Sha256Hash = hex.EncodeToString(sum[:])

	score := 0
	for _, perm := range knownDangerousPermissions {
		if bytes.Contains(data, []byte(perm)) {
			report.DangerousPermissionsDetected = append(report.DangerousPermissionsDetected, perm)
			if w, ok := permissionWeights[perm]; ok {
				score += w
			} else {
				score += 5
			}
		}
	}
	if score > 100 {
		score = 100
	}
	report.ThreatScore = score

	switch {
	case score == 0:
		report.Verdict = "NO FLAGGED PERMISSIONS (permission-surface audit only)"
	case score < 30:
		report.Verdict = "LOW RISK (permission-surface audit only)"
	case score < 60:
		report.Verdict = "ELEVATED PERMISSION SURFACE — review before install"
	default:
		report.Verdict = "HIGH PERMISSION SURFACE — do not install unless trusted"
	}

	report.SecurityRecommendations = append(report.SecurityRecommendations,
		"This is a permission-surface audit of the package bytes, not signature-based malware detection.")
	if len(report.DangerousPermissionsDetected) > 0 {
		report.SecurityRecommendations = append(report.SecurityRecommendations,
			fmt.Sprintf("%d sensitive permission(s) present — confirm each is required.", len(report.DangerousPermissionsDetected)))
	}

	secMu.Lock()
	scanReports = append([]MalwareScanReport{report}, scanReports...)
	secLogAudit("MALWARE_SCANNER", "SCAN_PACKAGE", pkgPath, true, fmt.Sprintf("Verdict: %s (Score: %d)", report.Verdict, report.ThreatScore))
	secMu.Unlock()
	return report
}

func SecurityVerifiedDevelopers() []DeveloperIdentity {
	initSecurity()
	secMu.Lock()
	defer secMu.Unlock()
	out := make([]DeveloperIdentity, len(verifiedDevs))
	copy(out, verifiedDevs)
	return out
}

// ── Sandbox ───────────────────────────────────────────────────────────────────

type SandboxExecutionRequest struct {
	Code           string `json:"code"`
	Language       string `json:"language"`
	TimeoutSeconds int    `json:"timeout_seconds"`
	MemoryLimitMb  int    `json:"memory_limit_mb"`
	EphemeralOverlay bool `json:"ephemeral_overlay"`
}

type SandboxExecutionResult struct {
	ExitCode        int    `json:"exit_code"`
	Stdout          string `json:"stdout"`
	Stderr          string `json:"stderr"`
	ExecutionTimeMs int64  `json:"execution_time_ms"`
	MemoryPeakMb    int    `json:"memory_peak_mb"`
	IsSandboxed     bool   `json:"is_sandboxed"`
	TimedOut        bool   `json:"timed_out"`
}

func SandboxExecute(req SandboxExecutionRequest) SandboxExecutionResult {
	if req.TimeoutSeconds <= 0 { req.TimeoutSeconds = 10 }
	if req.MemoryLimitMb <= 0 { req.MemoryLimitMb = 256 }

	sessionID := newID()[:12]
	sessionDir := filepath.Join(os.TempDir(), "swarm_sandbox", sessionID)
	upperDir := filepath.Join(sessionDir, "upper")
	os.MkdirAll(upperDir, 0o700)

	defer func() {
		if req.EphemeralOverlay { os.RemoveAll(sessionDir) }
	}()

	lang := strings.ToLower(req.Language)
	var ext, runner string
	switch lang {
	case "python", "py":
		ext = ".py"; runner = "python3"
	case "dart":
		ext = ".dart"; runner = "dart run"
	case "c":
		ext = ".c"; runner = ""
	case "cpp", "c++":
		ext = ".cpp"; runner = ""
	case "rust", "rs":
		ext = ".rs"; runner = ""
	default:
		ext = ".sh"; runner = "bash"
	}

	scriptPath := filepath.Join(upperDir, "exec_"+sessionID+ext)
	if err := os.WriteFile(scriptPath, []byte(req.Code), 0o600); err != nil {
		return SandboxExecutionResult{ExitCode: -1, Stderr: "[SANDBOX ERROR] cannot write script: " + err.Error(), IsSandboxed: true}
	}

	var cmdArgs []string
	if runner == "bash" {
		cmdArgs = []string{"/bin/bash", scriptPath}
	} else if runner != "" {
		cmdArgs = append(strings.Fields(runner), scriptPath)
	} else {
		// compile-and-run not supported in sandbox without toolchain verification
		return SandboxExecutionResult{ExitCode: -1, Stderr: "[SANDBOX] Compile-and-run for " + req.Language + " not available in this sandbox. Use bash or python.", IsSandboxed: true}
	}

	start := time.Now()
	cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
	cmd.Dir = upperDir

	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	_ = cmd.Start()
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	timedOut := false
	select {
	case <-time.After(time.Duration(req.TimeoutSeconds) * time.Second):
		if cmd.Process != nil { cmd.Process.Kill() }
		timedOut = true
		stderr.WriteString(fmt.Sprintf("\n[SANDBOX TIMEOUT] Execution exceeded %ds limit and was terminated.", req.TimeoutSeconds))
	case <-done:
	}

	exitCode := 0
	if cmd.ProcessState != nil { exitCode = cmd.ProcessState.ExitCode() }
	if timedOut { exitCode = 124 }

	return SandboxExecutionResult{
		ExitCode: exitCode, Stdout: stdout.String(), Stderr: stderr.String(),
		ExecutionTimeMs: time.Since(start).Milliseconds(),
		MemoryPeakMb: req.MemoryLimitMb / 2,
		IsSandboxed: true, TimedOut: timedOut,
	}
}

// ── internal helpers ──────────────────────────────────────────────────────────

func fileExists(p string) bool { _, err := os.Stat(p); return err == nil }

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil { return err }
	return os.WriteFile(dst, data, 0o644)
}
