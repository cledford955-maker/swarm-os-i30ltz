#!/usr/bin/env python3
"""Continuous acoustic listener for Lucille's wake phrases ("Hey Lucille" / "Hey Lucy").

Runs as its own systemd service (lucille-wake-listener.service), independent of any
particular window having focus — that's what makes it OS-wide rather than tied to the
Flutter shell being the active app. Everything else in the voice pipeline already exists
(frontend/lib/services/wake_word_service.dart polls $XDG_RUNTIME_DIR/lucille-wake/wake.flag, transcribes
the follow-up command via Groq/OpenAI/Gemini, asks Lucille, speaks the reply); this script
only supplies the missing producer of that flag file. Speech recognition is fully local
(Vosk) — no audio is sent anywhere just to detect the wake phrase.
"""
import json
import os
import re
import signal
import selectors
import tempfile
from pathlib import Path
import subprocess
import sys
import time

MODEL_PATH = os.environ.get('LUCILLE_WAKE_MODEL_PATH', '/opt/swarm_os/models/vosk-small-en-us')
SAMPLE_RATE = 16000
CHUNK_BYTES = 4000  # ~0.125s of 16-bit mono PCM at 16kHz
RUNTIME_DIR = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'lucille-wake'
FLAG_PATH = str(RUNTIME_DIR / 'wake.flag')
BUSY_PATH = RUNTIME_DIR / 'busy'
WAKE_GRAMMAR = ['hey lucille', 'hey lucy', 'hey lucifer', '[unk]']
POST_TRIGGER_COOLDOWN = 6.0  # covers Dart's own ack speech + its 4s follow-up recording

# The constrained decoder includes a distractor and unknown speech so unrelated
# speech need not be forced into either wake phrase. Match complete phrases only.
WAKE_RE = re.compile(r'\bhey\s+luc(?:y|ille)\b', re.IGNORECASE)

_running = True


def _handle_stop(signum, frame):
    global _running
    _running = False


def _start_arecord():
    return subprocess.Popen(
        ['arecord', '-q', '-f', 'S16_LE', '-r', str(SAMPLE_RATE), '-c', '1', '-t', 'raw'],
        stdout=subprocess.PIPE,
    )


def _extract_command(text, match):
    return text[match.end():].strip(' \t\n\r.,!?-')


def _should_skip(now, cooldown_until, flag_pending):
    return now < cooldown_until or flag_pending


def _fire(text, match):
    command = _extract_command(text, match)
    temporary = None
    try:
        # Publish only complete files; never follow or overwrite an existing flag.
        fd, temporary = tempfile.mkstemp(dir=Path(FLAG_PATH).parent, prefix='.wake-')
        with os.fdopen(fd, 'w') as f:
            f.write(command)
        os.link(temporary, FLAG_PATH)
    except OSError as exc:
        print(f'lucille_wake_listener: cannot publish wake event: {exc}', file=sys.stderr)
        return False
    finally:
        if temporary is not None:
            os.unlink(temporary)
    print('lucille_wake_listener: wake phrase detected', file=sys.stderr)
    return True


def _recognized_prompt(wake_text, full_text):
    """Use constrained decoding for the names and unrestricted decoding for commands."""
    match = WAKE_RE.search(wake_text)
    if not match:
        return None
    full_match = re.search(r'\bluc(?:y|ille)\b', full_text, re.IGNORECASE)
    command = _extract_command(full_text, full_match) if full_match else ''
    return match.group() + (' ' + command if command else '')


def _busy():
    try:
        # Recover after a shell crash instead of staying muted forever.
        return time.time() - BUSY_PATH.stat().st_mtime < 180
    except FileNotFoundError:
        return False


class SpeechDecoder:
    def __init__(self, model):
        from vosk import KaldiRecognizer
        self.full = KaldiRecognizer(model, SAMPLE_RATE)
        self.wake = KaldiRecognizer(model, SAMPLE_RATE, json.dumps(WAKE_GRAMMAR))
        self.segments = []

    def reset(self):
        self.full.Reset()
        self.wake.Reset()
        self.segments.clear()

    def feed(self, data):
        if self.wake.AcceptWaveform(data):
            self.segments.append(json.loads(self.wake.Result()).get('text', ''))
        if not self.full.AcceptWaveform(data):
            return None
        full_text = json.loads(self.full.Result()).get('text', '')
        self.segments.append(json.loads(self.wake.FinalResult()).get('text', ''))
        prompt = _recognized_prompt(' '.join(self.segments), full_text)
        self.reset()
        return prompt


def main():
    try:
        from vosk import Model
    except ImportError:
        print('lucille_wake_listener: python-vosk not installed', file=sys.stderr)
        return 1

    if not os.path.isdir(MODEL_PATH):
        print(f'lucille_wake_listener: model not found at {MODEL_PATH}', file=sys.stderr)
        return 1

    signal.signal(signal.SIGTERM, _handle_stop)
    signal.signal(signal.SIGINT, _handle_stop)

    RUNTIME_DIR.mkdir(mode=0o700, exist_ok=True)
    info = RUNTIME_DIR.lstat()
    if RUNTIME_DIR.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o077:
        print('lucille_wake_listener: unsafe runtime directory', file=sys.stderr)
        return 1
    model = Model(MODEL_PATH)

    while _running:
        decoder = SpeechDecoder(model)
        proc = _start_arecord()
        cooldown_until = 0.0
        selector = selectors.DefaultSelector()
        selector.register(proc.stdout, selectors.EVENT_READ)
        try:
            while _running:
                if not selector.select(timeout=0.25):
                    continue
                data = os.read(proc.stdout.fileno(), CHUNK_BYTES)
                if not data:
                    break  # arecord died; restart it in the outer loop

                if _should_skip(time.monotonic(), cooldown_until, os.path.exists(FLAG_PATH)) or _busy():
                    decoder.reset()
                    continue  # draining audio during cooldown, or prior trigger not consumed yet

                text = decoder.feed(data)
                if text and _fire(text, WAKE_RE.search(text)):
                    cooldown_until = time.monotonic() + POST_TRIGGER_COOLDOWN
        finally:
            selector.close()
            proc.stdout.close()
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()

        if _running:
            time.sleep(1)  # brief backoff before restarting a dead arecord

    return 0


if __name__ == '__main__':
    sys.exit(main())
