import importlib.util
import json
from pathlib import Path
import stat
import sys
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('diagnostics', Path(__file__).resolve().parents[1] / 'collect_swarm_diagnostics.py')
diag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diag)


class DiagnosticsTests(unittest.TestCase):
    def test_credentials(self):
        samples = [
            'OPENROUTER_API_KEY=secret-value',
            '{"access_token": "secret-value"}',
            'Authorization: Bearer secret-value',
            'https://user:secret-value@example.org',
            "password='secret-value with spaces'",
            '-----BEGIN PRIVATE KEY-----\nsecret-value\n-----END PRIVATE KEY-----',
        ]
        for sample in samples:
            with self.subTest(sample=sample):
                self.assertNotIn('secret-value', diag.redact(sample))
        self.assertEqual(diag.redact('ActiveState=active'), 'ActiveState=active')

    def test_command_failures_timeout_and_limit(self):
        self.assertIn('error', diag.collect_command(['/no/such/swarm-command']))
        result = diag.collect_command([sys.executable, '-c', 'import time; time.sleep(5)'], timeout=0.05)
        self.assertTrue(result['timed_out'])
        result = diag.collect_command([sys.executable, '-c', 'print("x" * 200000)'])
        self.assertTrue(result['truncated'])
        self.assertLessEqual(len(result['output']), diag.LIMIT)
        result = diag.collect_command([sys.executable, '-c', 'print("API_KEY=secret-value"); raise SystemExit(7)'])
        self.assertEqual(result['exit_code'], 7)
        self.assertNotIn('secret-value', result['output'])

    def test_archive_private_unique_and_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            report = {'commands': {'test': {'output': diag.redact('API_KEY=secret-value\nActiveState=active')}}}
            first = diag.write_bundle(report, Path(directory))
            second = diag.write_bundle(report, Path(directory))
            self.assertNotEqual(first, second)
            self.assertEqual(stat.S_IMODE(first.stat().st_mode), 0o600)
            with tarfile.open(first) as archive:
                self.assertEqual(archive.getnames(), ['report.json', 'README.txt'])
                self.assertEqual(json.load(archive.extractfile('report.json')), report)


if __name__ == '__main__':
    unittest.main()
