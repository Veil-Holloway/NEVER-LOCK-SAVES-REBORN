"""Regression for Windows path/handle timestamp semantics and retained mutation guards."""
import importlib.util
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest import mock

SOURCE=Path(os.environ.get('NLSR_AUDITOR_SOURCE',Path(__file__).resolve().parents[1]/'audit_installation.py'))
spec=importlib.util.spec_from_file_location('identity_auditor',SOURCE)
auditor=importlib.util.module_from_spec(spec);spec.loader.exec_module(auditor)

class WindowsIdentity(unittest.TestCase):
    def simulate(self,change=None):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'fixture';p.write_bytes(b'known bytes')
            real=p.stat()
            def observed(ctime):
                return SimpleNamespace(st_dev=real.st_dev,st_ino=real.st_ino,st_mode=real.st_mode,
                    st_size=real.st_size,st_mtime_ns=real.st_mtime_ns,
                    st_birthtime_ns=123,st_ctime_ns=ctime,st_file_attributes=0)
            before,opened,after_fd,after_path=observed(123),observed(999),observed(999),observed(123)
            if change=='handle_ctime':after_fd.st_ctime_ns+=1
            if change=='path_ctime':after_path.st_ctime_ns+=1
            if change=='inode':opened.st_ino+=1
            if change=='mtime':after_fd.st_mtime_ns+=1
            if change=='birthtime':opened.st_birthtime_ns+=1
            if change=='reparse':opened.st_file_attributes=0x400
            proxy=SimpleNamespace(name='nt',O_RDONLY=os.O_RDONLY,O_BINARY=getattr(os,'O_BINARY',0),
                O_NOFOLLOW=getattr(os,'O_NOFOLLOW',0),open=os.open,fdopen=os.fdopen,
                fstat=mock.Mock(side_effect=[opened,after_fd]))
            with mock.patch.object(auditor,'os',proxy),mock.patch.object(auditor,'checked_stat',side_effect=[before,after_path]):
                return auditor.stable_read(p,1024)[0]

    def test_windows_creation_vs_change_time_is_not_false_drift(self):
        self.assertEqual(self.simulate(),b'known bytes')

    def test_observed_handle_change_is_still_rejected(self):
        with self.assertRaises(auditor.AuditError):self.simulate('handle_ctime')

    def test_observed_path_change_is_still_rejected(self):
        with self.assertRaises(auditor.AuditError):self.simulate('path_ctime')

    def test_file_identity_and_reparse_changes_are_still_rejected(self):
        for change in ('inode','mtime','birthtime','reparse'):
            with self.subTest(change=change),self.assertRaises(auditor.AuditError):self.simulate(change)

    def test_inventory_pin_matches_saved_bytes(self):
        import hashlib
        self.assertEqual(auditor.INVENTORY_SHA256,hashlib.sha256(SOURCE.with_name('runtime_inventory.json').read_bytes()).hexdigest())

if __name__=='__main__':unittest.main()
