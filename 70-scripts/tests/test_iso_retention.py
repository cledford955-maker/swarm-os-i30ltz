import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
import datetime

spec=importlib.util.spec_from_file_location('iso',Path(__file__).resolve().parents[1]/'swarm_iso_manager.py')
iso=importlib.util.module_from_spec(spec);spec.loader.exec_module(iso)

class ReleaseTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.store=self.root/'store';self.store.mkdir()
 def tearDown(self): self.tmp.cleanup()
 def release(self,n,store=None):
  p=(store or self.store)/f'swarm-os-v6.2.{n}.iso';p.write_bytes(f'image {n}'.encode());os.utime(p,(n,n));return p
 def test_five_per_os_stable_does_not_exempt_and_other_os_is_untouched(self):
  items=[self.release(n) for n in range(15)]
  items[0].with_name(items[0].name+'.stable').write_text('user approved')
  other=self.store/'endeavour.iso';other.write_bytes(b'other');os.utime(other,(0,0))
  iso.prune(self.store)
  self.assertFalse(items[0].exists())
  self.assertTrue(other.exists())
  self.assertEqual(len(iso.releases(self.store)),5)
 def test_stable_filename_does_not_exempt_quota(self):
  for n in range(12): self.release(n)
  p=self.store/'swarm-os-v1-stable.iso';p.write_bytes(b'stable');os.utime(p,(0,0))
  iso.prune(self.store);self.assertFalse(p.exists())
 def test_dry_run_deletes_nothing(self):
  for n in range(12): self.release(n)
  self.assertEqual(len(iso.prune(self.store,True)),7);self.assertEqual(len(iso.releases(self.store)),12)
 def test_failed_build_not_promoted(self):
  old=self.release(1);iso.atomic_text(self.store/'latest.txt',old.name+'\n')
  source=self.store/'.incoming'/'build';source.mkdir(parents=True);p=source/'raw.iso';p.write_bytes(b'failed')
  iso.publish(self.store,p,'swarm-os-v2.iso','failed')
  self.assertEqual(iso.latest(self.store),old)
 def test_publish_cannot_overwrite_stable(self):
  old=self.release(1);old.with_name(old.name+'.stable').touch()
  source=self.store/'.incoming';source.mkdir();p=source/'raw.iso';p.write_bytes(b'new')
  with self.assertRaises(FileExistsError):iso.publish(self.store,p,old.name,'pass')
  self.assertEqual(old.read_bytes(),b'image 1')
 def test_symlink_never_pruned(self):
  outside=self.root/'outside.iso';outside.write_bytes(b'important');p=self.store/'swarm-os-v0.iso';p.symlink_to(outside)
  for n in range(1,13):self.release(n)
  iso.prune(self.store);self.assertTrue(p.is_symlink());self.assertEqual(outside.read_bytes(),b'important')
 def test_migration_conflict_preserves_source(self):
  source=self.release(1,self.root);target=self.release(1);target.write_bytes(b'conflict')
  with self.assertRaises(RuntimeError):iso.migrate(self.store,[source])
  self.assertTrue(source.exists());self.assertEqual(target.read_bytes(),b'conflict')
 def test_migration_verified_move_preserves_stable(self):
  source=self.release(1,self.root);source.with_name(source.name+'.stable').write_text('keep for a while')
  iso.migrate(self.store,[source]);self.assertFalse(source.exists())
  self.assertEqual((self.store/source.name).read_bytes(),b'image 1');self.assertTrue(iso.stable(self.store/source.name))
 def test_duplicate_alias_removal_requires_identical_content(self):
  self.release(1);alias=self.store/'swarm-os-latest.iso';alias.write_bytes(b'image 1')
  fallback=self.store/'swarm-os-fallback.iso';fallback.write_bytes(b'unknown')
  iso.migrate(self.store,[]);self.assertFalse(alias.exists());self.assertTrue(fallback.exists())
 def test_no_releases_is_clear_error(self):
  with self.assertRaisesRegex(RuntimeError,'No usable'):iso.latest(self.store)
 def verified(self,n):
  p=self.release(n)
  iso.atomic_text(p.with_name(p.name+'.json'),'{"boot_gate":"pass"}')
  iso.atomic_text(p.with_name(p.name+'.sha256'),iso.digest(p)+'  '+p.name+'\n')
  return p
 def test_quota_is_recursive_skips_active_builds_and_other_os(self):
  for n in range(10):self.release(n)
  other=self.store/'Linux';other.mkdir();old=other/'old.ISO';old.write_bytes(b'old');os.utime(old,(0,0))
  incoming=self.store/'.incoming';incoming.mkdir();active=incoming/'new.iso';active.write_bytes(b'building')
  iso.prune(self.store);self.assertTrue(old.exists());self.assertTrue(active.exists());self.assertEqual(len(iso.releases(self.store)),5)
 def test_weekly_archive_requires_boot_pass(self):
  self.release(1)
  self.assertIsNone(iso.archive_weekly(self.store,self.root/'archive'))
  self.assertFalse((self.root/'archive').exists())
 def test_verified_archive_and_same_week_idempotence(self):
  source=self.verified(1);root=self.root/'archive';day=datetime.date(2026,9,24)
  result=iso.archive_weekly(self.store,root,day)
  self.assertEqual(result.read_bytes(),source.read_bytes())
  self.verified(2)
  self.assertEqual(iso.archive_weekly(self.store,root,day),result)
  self.assertEqual(len(list(root.rglob('*.iso'))),1)
 def test_same_build_is_not_copied_again_next_week(self):
  self.verified(1);root=self.root/'archive'
  first=iso.archive_weekly(self.store,root,datetime.date(2026,9,24))
  self.assertEqual(iso.archive_weekly(self.store,root,datetime.date(2026,10,1)),first)
 def test_archive_rejects_corrupt_source(self):
  p=self.verified(1);p.write_bytes(b'corrupt')
  with self.assertRaisesRegex(RuntimeError,'checksum'):iso.archive_weekly(self.store,self.root/'archive')
  self.assertFalse((self.root/'archive').exists())

if __name__=='__main__':unittest.main()
