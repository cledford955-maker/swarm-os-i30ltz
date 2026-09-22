"""Render the installer heredoc without executing any installation operations."""
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]

class InstallerVoiceStagingTests(unittest.TestCase):
    def test_chroot_variables_survive_host_expansion(self):
        source = (ROOT / 'install_swarm_os.sh').read_text()
        block = source.split('arch-chroot "$MOUNT_POINT" /bin/bash <<EOF\n', 1)[1].split('\nEOF', 1)[0]
        result = subprocess.run(['bash', '-c', 'set -eu\ncat <<EOF\n' + block + '\nEOF\n'],
                                env=dict(os.environ, HOST_PW_HASH='!', ROOT_UUID='test-root-uuid'),
                                text=True, capture_output=True, check=True)
        rendered = result.stdout
        self.assertIn('/etc/systemd/system/$svc', rendered)
        self.assertIn('lucille-wake-listener.service; do', rendered)
        self.assertIn('s/^Group=swarm$/Group=i30ltz/', rendered)
        self.assertIn('SWARM_RUNTIME_UID=$(id -u i30ltz)', rendered)
        self.assertIn('/run/user/$SWARM_RUNTIME_UID', rendered)
        self.assertIn('ollama pull "$1"', rendered)
        self.assertIn('[ -f "$STAMP" ]', rendered)
        self.assertIn('test-root-uuid', rendered)
        subprocess.run(['bash', '-n'], input=rendered, text=True, check=True)

if __name__ == '__main__':
    unittest.main()
