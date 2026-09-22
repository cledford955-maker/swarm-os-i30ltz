#!/usr/bin/env python3
"""Opt-in real Vosk decoding test using synthetic speech, without a microphone.

Run: python3 70-scripts/tests/wake_acoustic_smoke.py [model-directory]
Requires vosk, espeak-ng and ffmpeg. Does not contact a cloud provider.
"""
import importlib.util
import subprocess
import sys
from pathlib import Path
import vosk

spec = importlib.util.spec_from_file_location('wake', Path(__file__).resolve().parents[1] / 'lucille_wake_listener.py')
wake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wake)
vosk.SetLogLevel(-1)
model = vosk.Model(sys.argv[1] if len(sys.argv) > 1 else str(
    Path(__file__).resolve().parents[2] / '20-runtime/vosk-model-cache/vosk-model-small-en-us-0.15'))
cases = {
    'hey lucille': True,
    'hey lucy': True,
    'hey lucille open the overlay': True,
    'hey lucy what games are on sale': True,
    'the weather is lovely today': False,
    'lucille': False,
    'lucy': False,
    'hey lucifer': False,
}
for phrase, expected in cases.items():
    wav = subprocess.check_output(['espeak-ng', '--stdout', '-s', '140', phrase])
    pcm = subprocess.run(['ffmpeg', '-v', 'error', '-i', 'pipe:0', '-f', 's16le',
                          '-ar', '16000', '-ac', '1', 'pipe:1'], input=wav,
                         stdout=subprocess.PIPE, check=True).stdout + b'\0' * 64000
    decoder = wake.SpeechDecoder(model)
    results = [result for offset in range(0, len(pcm), wake.CHUNK_BYTES)
               if (result := decoder.feed(pcm[offset:offset + wake.CHUNK_BYTES]))]
    assert bool(results) == expected, (phrase, results)
    if phrase.endswith('overlay'):
        assert 'overlay' in ' '.join(results), results
    print(f'PASS {phrase!r}: {results}')
