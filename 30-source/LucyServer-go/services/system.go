package services

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"syscall"

	"swarm-os/lucy-server/models"
)

// RunCommand shells out via `/bin/bash -c <command>`. Go's exec.Command
// passes each argument directly via execve (no shell re-tokenization of the
// argument list), so unlike the .NET original this needs no manual quote
// escaping — passing `command` as one argv element to bash -c is already
// exactly correct.
//
// SECURITY: this is an intentionally unrestricted remote-command-execution
// endpoint, same as the .NET original. Its only protection is the
// swarmAuthMiddleware in main.go (loopback or X-Swarm-Auth token). Do not
// add "improvements" here without checking that middleware stays in place.
func RunCommand(command, cwd string) models.CommandResult {
	if cwd == "" {
		cwd, _ = os.Getwd()
	}
	cmd := exec.Command("/bin/bash", "-c", command)
	cmd.Dir = cwd

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = -1
		}
	}

	return models.CommandResult{
		ExitCode:       exitCode,
		StandardOutput: stdout.String(),
		StandardError:  stderr.String(),
	}
}

// GetSystemStats mirrors the .NET original's approach of parsing `free -m`
// and `top -bn1` rather than reading /proc directly (kept for behavioral
// parity, not because it's the better approach).
func GetSystemStats() models.SystemStats {
	var stats models.SystemStats

	memResult := RunCommand("free -m | grep Mem", "")
	memParts := strings.Fields(memResult.StandardOutput)
	if len(memParts) >= 4 {
		if total, err := strconv.ParseFloat(memParts[1], 64); err == nil {
			stats.TotalMemoryMb = total
		}
		if used, err := strconv.ParseFloat(memParts[2], 64); err == nil {
			stats.UsedMemoryMb = used
		}
		if free, err := strconv.ParseFloat(memParts[3], 64); err == nil {
			stats.FreeMemoryMb = free
		}
	}

	// CPU: computed as 100 - idle% from `top -bn1 | grep 'Cpu(s)'`.
	//
	// DELIBERATE DEVIATION from the .NET original, not a straight port: its
	// code did `cpuParts[1].Replace("%us,", "").Replace("%us", "")`, written
	// for an older top format where the value and "%us" label were one
	// concatenated token (e.g. "12.3%us,"). This system's actual top
	// (procps-ng, verified via `top -bn1 | grep Cpu`) splits them into
	// separate tokens ("3.6", "us,"), so those Replace() calls are silent
	// no-ops — the .NET code ends up returning raw user-mode CPU% only
	// (excluding sy/ni/wa/hi/si/st, and definitely excluding idle) under a
	// field named CpuUsagePercentage, which is misleading. Since this is a
	// monitoring-only metric with no other endpoint depending on its exact
	// semantics, computing the standard "100 - idle%" here instead — this is
	// an intentional accuracy fix, called out so it isn't mistaken for an
	// accidental behavior change.
	cpuResult := RunCommand("top -bn1 | grep 'Cpu(s)'", "")
	cpuParts := strings.Fields(cpuResult.StandardOutput)
	for i, tok := range cpuParts {
		if i > 0 && strings.HasPrefix(tok, "id") {
			if idle, err := strconv.ParseFloat(cpuParts[i-1], 64); err == nil {
				stats.CpuUsagePercentage = 100 - idle
			}
			break
		}
	}

	return stats
}

// GetProcesses walks /proc directly (Go has no equivalent to .NET's
// Process.GetProcesses()). Best-effort like the original: a process that
// exits mid-scan or is inaccessible is silently skipped, not an error.
func GetProcesses() []models.ProcessInfo {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}

	var procs []models.ProcessInfo
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue // not a PID directory
		}

		commBytes, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
		if err != nil {
			continue // process exited mid-scan, or inaccessible
		}
		name := strings.TrimSpace(string(commBytes))

		statusBytes, err := os.ReadFile(fmt.Sprintf("/proc/%d/status", pid))
		if err != nil {
			continue
		}
		var vmRssKb float64
		for _, line := range strings.Split(string(statusBytes), "\n") {
			if strings.HasPrefix(line, "VmRSS:") {
				fields := strings.Fields(line)
				if len(fields) >= 2 {
					if kb, err := strconv.ParseFloat(fields[1], 64); err == nil {
						vmRssKb = kb
					}
				}
				break
			}
		}

		procs = append(procs, models.ProcessInfo{
			Pid:           pid,
			Name:          name,
			MemoryUsageMb: vmRssKb / 1024.0,
		})
	}

	sort.Slice(procs, func(i, j int) bool { return procs[i].MemoryUsageMb > procs[j].MemoryUsageMb })
	return procs
}

// KillProcess sends SIGKILL, matching .NET's Process.Kill() default on Linux.
func KillProcess(pid int) bool {
	proc, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	// os.FindProcess never fails to "find" on Linux (no existence check) —
	// the actual existence check happens on Signal().
	return proc.Signal(syscall.SIGKILL) == nil
}

func ListPackages() []string {
	if r := RunCommand("which apt", ""); r.ExitCode == 0 {
		result := RunCommand(`dpkg-query -f '${binary:Package}\n' -W`, "")
		return splitNonEmpty(result.StandardOutput)
	}
	if r := RunCommand("which pacman", ""); r.ExitCode == 0 {
		result := RunCommand("pacman -Qqe", "")
		return splitNonEmpty(result.StandardOutput)
	}
	return []string{}
}

func UninstallPackage(packageName string) models.CommandResult {
	// Reject anything that isn't a valid package name to prevent shell injection.
	// apt/pacman names are alphanumeric plus - _ . +
	for _, c := range packageName {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
			(c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '+') {
			return models.CommandResult{ExitCode: -1, StandardError: "invalid package name: contains disallowed characters"}
		}
	}
	if packageName == "" {
		return models.CommandResult{ExitCode: -1, StandardError: "package name must not be empty"}
	}
	runDirect := func(args ...string) models.CommandResult {
		var stdout, stderr bytes.Buffer
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Stdout = &stdout
		cmd.Stderr = &stderr
		err := cmd.Run()
		exitCode := 0
		if err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				exitCode = exitErr.ExitCode()
			} else {
				exitCode = -1
			}
		}
		return models.CommandResult{ExitCode: exitCode, StandardOutput: stdout.String(), StandardError: stderr.String()}
	}
	if r := RunCommand("which apt", ""); r.ExitCode == 0 {
		return runDirect("sudo", "apt", "remove", "-y", packageName)
	}
	if r := RunCommand("which pacman", ""); r.ExitCode == 0 {
		return runDirect("sudo", "pacman", "-Rns", "--noconfirm", packageName)
	}
	return models.CommandResult{ExitCode: -1, StandardError: "No supported package manager found."}
}

// SetClipboardText shells out to wl-copy (Wayland) or xclip (X11).
//
// LIKELY BROKEN as of the Slint rewrite (SWARM_AI_FEATURES.md, Slint tasks
// #1-9): swarm-ui.service now runs Slint's backend-linuxkms directly against
// DRM — there is no Wayland compositor and no X server anywhere on this OS
// anymore, so neither wl-copy nor xclip has a display to connect to. Ported
// faithfully rather than silently "fixed" here, because the real fix needs a
// design decision this task shouldn't make unilaterally: does clipboard even
// make sense in a single-app kiosk, and if so, does it need its own IPC
// instead of a display-server clipboard protocol? Flagged in
// SWARM_AI_FEATURES.md for a real decision.
func SetClipboardText(text string) models.CommandResult {
	escaped := strings.NewReplacer(`"`, `\"`, `$`, `\$`, "`", "\\`").Replace(text)
	if r := RunCommand("which wl-copy", ""); r.ExitCode == 0 {
		return RunCommand(fmt.Sprintf(`echo "%s" | wl-copy`, escaped), "")
	}
	return RunCommand(fmt.Sprintf(`echo "%s" | xclip -selection clipboard`, escaped), "")
}

func splitNonEmpty(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		if line != "" {
			out = append(out, line)
		}
	}
	return out
}
