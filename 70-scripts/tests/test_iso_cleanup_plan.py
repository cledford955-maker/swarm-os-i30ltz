import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(SCRIPTS))
import apply_iso_cleanup as cleanup


class CleanupPlanTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
  self.roots=patch.object(cleanup,'ROOTS',(self.root,));self.roots.start()
 def tearDown(self):self.roots.stop();self.temp.cleanup()
 def record(self,path):
  s=path.stat();return dict(path=str(path),device=s.st_dev,inode=s.st_ino,bytes=s.st_size,mtime_ns=s.st_mtime_ns)
 def test_changed_file_is_rejected(self):
  p=self.root/'image.iso';p.write_bytes(b'old');r=self.record(p);p.write_bytes(b'changed')
  with self.assertRaisesRegex(RuntimeError,'changed'):cleanup.validate(r)
 def test_symlink_is_rejected(self):
  p=self.root/'image.iso';p.write_bytes(b'old');r=self.record(p)
  target=self.root/'other.iso';p.rename(target);p.symlink_to(target)
  with self.assertRaisesRegex(RuntimeError,'redirected'):cleanup.validate(r)
 def test_missing_retained_image_prevents_all_deletions(self):
  keep=self.root/'keep.iso';keep.write_bytes(b'keep');k=self.record(keep);k['destination']=str(keep);keep.unlink()
  extra=self.root/'extra.iso';extra.write_bytes(b'extra')
  plan={'keep':[k],'delete':[self.record(extra)]}
  with patch.object(cleanup.iso,'require_store'),patch.object(cleanup.iso,'STORE',self.root):
   with self.assertRaisesRegex(RuntimeError,'missing'):cleanup.apply(plan,owned_only=True)
  self.assertTrue(extra.exists())

if __name__=='__main__':unittest.main()
