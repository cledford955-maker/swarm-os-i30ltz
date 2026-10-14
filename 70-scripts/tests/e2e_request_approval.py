#!/usr/bin/env python3
"""End-to-end test of lucille-core's `request_approval` IPC command with a stand-in phone.

    python3 e2e_request_approval.py /path/to/lucille-core

Starts the real binary on a scratch socket and port with a random token, connects a fake phone
over the companion WebSocket (same handshake and JSON the Android app uses), raises approvals over
the IPC socket and checks: approved, rejected, no phone / timeout, and bad input. Touches nothing
outside a temp dir. The fake phone speaks only what the real app speaks: it answers pings and sends
{"action":"hitl_response","challenge_id":...,"approved":bool}.
"""
import base64, json, os, re, secrets, socket, struct, subprocess, sys, tempfile, threading, time


def ws_connect(host, port, token):
    s = socket.create_connection((host, port), timeout=5)
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall((f"GET /?token={token} HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\n"
               f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
    buf = b""
    while b"\r\n\r\n" not in buf:
        buf += s.recv(4096)
    assert b" 101 " in buf.split(b"\r\n")[0], buf[:100]
    return s


def ws_send(s, text, opcode=0x1):
    data = text.encode() if isinstance(text, str) else text
    mask = os.urandom(4)
    hdr = bytes([0x80 | opcode])
    n = len(data)
    hdr += bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n)
    s.sendall(hdr + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))


def ws_recv(s):
    def rd(n):
        b = b""
        while len(b) < n:
            c = s.recv(n - len(b))
            if not c:
                raise EOFError
            b += c
        return b
    h = rd(2)
    op, n = h[0] & 0x0F, h[1] & 0x7F
    if n == 126:
        n = struct.unpack(">H", rd(2))[0]
    elif n == 127:
        n = struct.unpack(">Q", rd(8))[0]
    return op, rd(n)


class FakePhone(threading.Thread):
    def __init__(self, host, port, token):
        super().__init__(daemon=True)
        self.s = ws_connect(host, port, token)
        self.s.settimeout(1)
        self.answer = True          # what to reply to the next challenge
        self.seen = []
        self.stop = False

    def run(self):
        while not self.stop:
            try:
                op, payload = ws_recv(self.s)
            except socket.timeout:
                continue
            except Exception:
                return
            if op == 0x9:                                  # ping -> pong
                ws_send(self.s, payload, 0xA)
            elif op == 0x1:
                msg = json.loads(payload)
                if msg.get("event") == "hitl_challenge":
                    self.seen.append(msg)
                    ws_send(self.s, json.dumps({"action": "hitl_response",
                                                "challenge_id": msg["challenge_id"],
                                                "approved": self.answer}, separators=(",", ":")))  # compact, like Android's JSONObject


def ipc(sock_path, obj, timeout=30):
    c = socket.socket(socket.AF_UNIX)
    c.settimeout(timeout)
    c.connect(sock_path)
    # lucille-core's IPC parser only understands compact JSON ("key":"value", no spaces)
    c.sendall((json.dumps(obj, separators=(",", ":")) + "\n").encode())
    out = b""
    while not out.endswith(b"\n"):
        chunk = c.recv(4096)
        if not chunk:
            break
        out += chunk
    c.close()
    return json.loads(out)


def main():
    binary = sys.argv[1]
    failures = []

    def check(name, cond, extra=""):
        print(("PASS " if cond else "FAIL ") + name + (" " + extra if extra and not cond else ""))
        if not cond:
            failures.append(name)

    with tempfile.TemporaryDirectory(dir="/tmp", prefix="lc") as d:  # AF_UNIX paths max out near 107 chars
        sock = os.path.join(d, "ipc.sock")
        port = 19000 + secrets.randbelow(900)
        env = dict(os.environ, SWARM_AUTH_TOKEN=secrets.token_hex(16))
        log = open(os.path.join(d, "core.log"), "w+")
        p = subprocess.Popen([binary, "--socket", sock, "--telemetry-port", str(port)],
                             env=env, stdout=log, stderr=subprocess.STDOUT, cwd=d)  # output is block-buffered into the file
        try:
            host = None
            cands = ["127.0.0.1"]
            try:  # the daemon binds the Tailscale address when it has one, loopback otherwise
                ts = subprocess.run(["tailscale", "ip", "-4"], capture_output=True, text=True, timeout=5).stdout.split()
                cands = ts[:1] + cands
            except Exception:
                pass
            for _ in range(100):
                time.sleep(0.2)
                if not os.path.exists(sock):
                    continue
                for h in cands:
                    try:
                        socket.create_connection((h, port), timeout=1).close()
                        host = h
                        break
                    except OSError:
                        pass
                if host:
                    break
            if not host:
                log.seek(0)
                print(log.read()[-1500:])
                sys.exit("lucille-core did not start")

            r = ipc(sock, {"command": "request_approval"})
            check("missing text is rejected", r.get("status") == "error" and "requires text" in r.get("message", ""), str(r))

            # no phone connected: a short timeout must deny (min allowed is 10 s)
            t0 = time.time()
            r = ipc(sock, {"command": "request_approval", "text": "no phone", "timeout_sec": 10})
            check("no phone -> denied after the timeout", r.get("approved") is False and time.time() - t0 >= 9, str(r))

            phone = FakePhone(host, port, env["SWARM_AUTH_TOKEN"])
            phone.start()
            time.sleep(0.5)

            phone.answer = True
            r = ipc(sock, {"command": "request_approval", "text": "backup key: sudo true"})
            check("phone approves -> approved", r.get("approved") is True, str(r))
            check("phone saw the text", bool(phone.seen) and "backup key: sudo true" in phone.seen[-1].get("command", ""))

            phone.answer = False
            r = ipc(sock, {"command": "request_approval", "text": "backup key: sudo true"})
            check("phone rejects -> denied", r.get("approved") is False, str(r))

            phone.answer = True
            r = ipc(sock, {"command": "request_approval", "text": 'quote " and \\ slash', "timeout_sec": 999})
            check("odd text + out-of-range timeout still works", r.get("approved") is True, str(r))

            bad = socket.socket()
            bad.settimeout(3)
            try:
                bad.connect((host, port))
                bad.sendall(b"GET /?token=wrong HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                            b"Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA==\r\nSec-WebSocket-Version: 13\r\n\r\n")
                resp = bad.recv(200)
            except Exception:
                resp = b""
            check("wrong token cannot join", b" 101 " not in resp, repr(resp[:60]))
            phone.stop = True
        finally:
            p.terminate()
            try:
                p.wait(5)
            except subprocess.TimeoutExpired:
                p.kill()
    print("\nALL PASSED" if not failures else "\nFAILED: " + ", ".join(failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
