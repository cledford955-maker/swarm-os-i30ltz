package services

import (
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// HandleTerminalSession spawns `/bin/bash -l` and relays bytes bidirectionally
// between it and the WebSocket, mirroring the .NET original exactly: plain
// redirected stdin/stdout/stderr pipes, NOT a pty (no job control, prompts
// may not render identically to a real terminal — same limitation the
// original had).
func HandleTerminalSession(conn *websocket.Conn) {
	defer conn.Close()

	home := os.Getenv("HOME")
	if home == "" {
		home = "/"
	}

	cmd := exec.Command("/bin/bash", "-l")
	cmd.Dir = home
	cmd.Env = append(os.Environ(), "TERM=xterm-256color")

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return
	}

	if err := cmd.Start(); err != nil {
		return
	}

	// Task.WhenAny(receive, sendOut, sendErr, WaitForExit) equivalent — first
	// of any of these to finish triggers cleanup of the rest.
	done := make(chan struct{})
	var once sync.Once
	finish := func() { once.Do(func() { close(done) }) }

	go func() { // WS -> process stdin
		defer finish()
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				return
			}
			if _, err := stdin.Write(data); err != nil {
				return
			}
		}
	}()

	go func() { // process stdout -> WS
		defer finish()
		relayToWebSocket(stdout, conn)
	}()

	go func() { // process stderr -> WS
		defer finish()
		relayToWebSocket(stderr, conn)
	}()

	go func() { // process exit
		defer finish()
		_ = cmd.Wait()
	}()

	<-done

	if cmd.Process != nil {
		_ = cmd.Process.Kill()
	}

	// Graceful WS close handshake — matches the .NET original's `finally`
	// block (webSocket.CloseAsync(...) if still Open). Without this the
	// client sees an abrupt TCP close (code 1006, "abnormal") instead of a
	// clean 1000; verified the difference with a real WS client before
	// adding this.
	_ = conn.WriteControl(
		websocket.CloseMessage,
		websocket.FormatCloseMessage(websocket.CloseNormalClosure, "Terminal closed"),
		time.Now().Add(time.Second),
	)
}

type reader interface {
	Read(p []byte) (n int, err error)
}

func relayToWebSocket(r reader, conn *websocket.Conn) {
	buf := make([]byte, 4096)
	for {
		n, err := r.Read(buf)
		if n > 0 {
			if werr := conn.WriteMessage(websocket.TextMessage, buf[:n]); werr != nil {
				return
			}
		}
		if err != nil {
			return
		}
	}
}
