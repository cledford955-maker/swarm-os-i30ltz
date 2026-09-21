#!/usr/bin/env python3
"""Continuous acoustic listener for Lucille's wake phrases ("Hey Lucille" / "Hey Lucy").

Runs as its own systemd service (lucille-wake-listener.service), independent of any
particular window having focus — that's what makes it OS-wide rather than tied to the
Flutter shell being the active app. Everything else in the voice pipeline already exists
(frontend/lib/services/wake_word_service.dart polls /tmp/lucille_wake.flag, transcribes
the follow-up command via Groq/OpenAI/Gemini, asks Lucille, speaks the reply); this script
only supplies the missing producer of that flag file. Speech recognition is fully local
(Vosk) — no audio is sent anywhere just to detect the wake phrase.
"""
import json
import os
import re
import signal
import subprocess
import sys
import time

MODEL_PATH = os.environ.get('LUCILLE_WAKE_MODEL_PATH', '/opt/swarm_os/models/vosk-small-en-us')
SAMPLE_RATE = 16000
CHUNK_BYTES = 4000  # ~0.125s of 16-bit mono PCM at 16kHz
FLAG_PATH = '/tmp/lucille_wake.flag'
POST_TRIGGER_COOLDOWN = 6.0  # covers Dart's own ack speech + its 4s follow-up recording

# Literal phrases only — guessing at phonetic mis-hears without real audio to test
# against would just be superstition. Widen this once real usage shows what Vosk's
# generic English model actually mishears "Lucille"/"Lucy" as.
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
    try:
        fd = os.open(FLAG_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w') as f:
            f.write(command)
    except OSError as exc:
        print(f'lucille_wake_listener: failed to write {FLAG_PATH}: {exc}', file=sys.stderr)
        return
    print(f'lucille_wake_listener: wake phrase detected, command={command!r}', file=sys.stderr)


def main():
    try:
        from vosk import Model, KaldiRecognizer
    except ImportError:
        print('lucille_wake_listener: python-vosk not installed', file=sys.stderr)
        return 1

    if not os.path.isdir(MODEL_PATH):
        print(f'lucille_wake_listener: model not found at {MODEL_PATH}', file=sys.stderr)
        return 1

    signal.signal(signal.SIGTERM, _handle_stop)
    signal.signal(signal.SIGINT, _handle_stop)

    model = Model(MODEL_PATH)

    while _running:
        recognizer = KaldiRecognizer(model, SAMPLE_RATE)
        proc = _start_arecord()
        cooldown_until = 0.0
        try:
            while _running:
                data = proc.stdout.read(CHUNK_BYTES)
                if not data:
                    break  # arecord died; restart it in the outer loop

                if _should_skip(time.time(), cooldown_until, os.path.exists(FLAG_PATH)):
                    continue  # draining audio during cooldown, or prior trigger not consumed yet

                if recognizer.AcceptWaveform(data):
                    text = (json.loads(recognizer.Result()).get('text') or '').strip()
                    if text:
                        match = WAKE_RE.search(text)
                        if match:
                            _fire(text, match)
                            cooldown_until = time.time() + POST_TRIGGER_COOLDOWN
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()

        if _running:
            time.sleep(1)  # brief backoff before restarting a dead arecord

    return 0


if __name__ == '__main__':
    sys.exit(main())
