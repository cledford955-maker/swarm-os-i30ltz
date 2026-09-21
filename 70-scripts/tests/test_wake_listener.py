import importlib.util
import os
import stat
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'lucille_wake_listener', Path(__file__).resolve().parents[1] / 'lucille_wake_listener.py')
wake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wake)


class WakePhraseTests(unittest.TestCase):
    def test_matches_both_wake_phrases(self):
        for text in ['hey lucille', 'Hey Lucille', 'hey lucy', 'well hey lucy there', "hey lucille's"]:
            with self.subTest(text=text):
                self.assertIsNotNone(wake.WAKE_RE.search(text))

    def test_does_not_match_bare_name_without_hey(self):
        for text in ['lucille is great', 'a lucy movie', 'heylucille', 'hey lucifer']:
            with self.subTest(text=text):
                self.assertIsNone(wake.WAKE_RE.search(text))

    def test_extract_command_strips_trailing_punctuation(self):
        match = wake.WAKE_RE.search('hey lucille what is on sale today?')
        self.assertEqual(wake._extract_command('hey lucille what is on sale today?', match),
                          'what is on sale today')

    def test_extract_command_empty_for_bare_wake_phrase(self):
        match = wake.WAKE_RE.search('hey lucille')
        self.assertEqual(wake._extract_command('hey lucille', match), '')


class DebounceTests(unittest.TestCase):
    def test_skips_during_cooldown(self):
        self.assertTrue(wake._should_skip(now=10.0, cooldown_until=12.0, flag_pending=False))
        self.assertFalse(wake._should_skip(now=13.0, cooldown_until=12.0, flag_pending=False))

    def test_skips_while_flag_still_pending(self):
        self.assertTrue(wake._should_skip(now=100.0, cooldown_until=0.0, flag_pending=True))
        self.assertFalse(wake._should_skip(now=100.0, cooldown_until=0.0, flag_pending=False))


class FireTests(unittest.TestCase):
    def test_writes_command_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            flag_path = os.path.join(directory, 'lucille_wake.flag')
            original = wake.FLAG_PATH
            wake.FLAG_PATH = flag_path
            try:
                match = wake.WAKE_RE.search('hey lucy tell me a joke')
                wake._fire('hey lucy tell me a joke', match)
                self.assertTrue(os.path.exists(flag_path))
                self.assertEqual(Path(flag_path).read_text(), 'tell me a joke')
                self.assertEqual(stat.S_IMODE(os.stat(flag_path).st_mode), 0o600)
            finally:
                wake.FLAG_PATH = original

    def test_bare_trigger_writes_empty_flag(self):
        with tempfile.TemporaryDirectory() as directory:
            flag_path = os.path.join(directory, 'lucille_wake.flag')
            original = wake.FLAG_PATH
            wake.FLAG_PATH = flag_path
            try:
                match = wake.WAKE_RE.search('hey lucille')
                wake._fire('hey lucille', match)
                self.assertEqual(Path(flag_path).read_text(), '')
            finally:
                wake.FLAG_PATH = original


if __name__ == '__main__':
    unittest.main()
