"""Independent public-CLI contract tests using real disposable filesystem inputs."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
KIT = PROJECT if (PROJECT/'audit_installation.py').is_file() else PROJECT/'kit'
TOOL = KIT / 'audit_installation.py'
INVENTORY = json.loads((KIT / 'runtime_inventory.json').read_text())
PATHS = [item['path'] for item in INVENTORY['runtime_files']]
RELEASE_ROOT = KIT.parent.parent
ORIGINAL_BYTES = {relative:(RELEASE_ROOT/relative).read_bytes() for relative in PATHS}
RUNTIME_PATHS = [p.relative_to(RELEASE_ROOT).as_posix() for directory in
    ('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn','r6/scripts/NeverLockSavesReborn')
    for p in (RELEASE_ROOT/directory).rglob('*') if p.is_file() and p.suffix in ('.lua','.reds')]
LUA_DIR = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn'
REDS_DIR = 'r6/scripts/NeverLockSavesReborn'
PRIVATE = 'PRIVATE_PERSON_DONOTPRINT_75349'


def supports_symlinks():
    if not hasattr(os,'symlink'):
        return False
    try:
        with tempfile.TemporaryDirectory(prefix='nlsr-link-probe-') as tmp:
            root=Path(tmp);source=root/'source';source.write_text('probe')
            (root/'file_link').symlink_to(source)
            directory=root/'directory';directory.mkdir()
            (root/'dir_link').symlink_to(directory,target_is_directory=True)
            return (root/'file_link').is_symlink() and (root/'dir_link').is_symlink()
    except (OSError,NotImplementedError):
        return False


def supports_case_distinct_names():
    try:
        with tempfile.TemporaryDirectory(prefix='nlsr-case-probe-') as tmp:
            root=Path(tmp);(root/'CaseProbe').write_text('probe')
            return not (root/'caseprobe').exists()
    except OSError:
        return False


SYMLINK_AVAILABLE=supports_symlinks()
CASE_DISTINCT_NAMES=supports_case_distinct_names()


def tree_fingerprint(root):
    result = {}
    for path in sorted(root.rglob('*')):
        s = path.lstat()
        result[str(path.relative_to(root))] = (s.st_mode, s.st_size, s.st_mtime_ns,
            hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() and not path.is_symlink() else None)
    return result


class AuditorCLI(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix=PRIVATE)
        self.root = Path(self.tmp.name) / 'game'
        self.root.mkdir()
        self.reference = Path(self.tmp.name) / 'reference'
        for relative in PATHS:
            for folder in (self.root,self.reference):
                target = folder / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(ORIGINAL_BYTES[relative])

    def tearDown(self):
        self.tmp.cleanup()

    def run_audit(self, *args, root=None, tool=TOOL, expected=None):
        p = subprocess.run([sys.executable, str(tool), '--game-root', str(root or self.root), *map(str,args)],
                           capture_output=True, text=True, timeout=20)
        self.assertNotIn(PRIVATE, p.stdout + p.stderr, 'private input path/name leaked')
        self.assertEqual(p.stderr, '', 'valid command should return structured stdout, not raw stderr')
        try:
            payload = json.loads(p.stdout)
        except Exception:
            self.fail(f'one JSON report required, exit={p.returncode}: {p.stdout[:400]!r}')
        self.assertEqual(payload['schema_version'], 1)
        if expected is not None:
            self.assertEqual(p.returncode, expected, payload)
        self.assertEqual({'exact_match':0, 'drift_or_review':1, 'incomplete':2}[payload['audit_status']], p.returncode)
        self.assertEqual(payload['release'], '1.0.0-rc4')
        return payload

    def test_clean_exact_bytes_and_no_input_writes(self):
        before = tree_fingerprint(self.root)
        report = self.run_audit(expected=0)
        self.assertEqual(report['runtime']['status'], 'exact_match')
        self.assertEqual(len(report['runtime']['files']), 16)
        self.assertTrue(all(f['status']=='match' for f in report['runtime']['files']))
        for row in report['runtime']['files']:
            expected = next(i for i in INVENTORY['runtime_files'] if i['path']==row['path'])
            self.assertEqual(row['observed_sha256'], expected['sha256'])
            self.assertEqual(row['observed_size'], expected['size'])
        self.assertEqual(before, tree_fingerprint(self.root))
        self.assertEqual(report['archive']['status'], 'not_supported_embedded_tool')
        self.assertEqual(report['version_labels'], {})

    def test_one_changed_byte_is_drift(self):
        path=self.root/PATHS[0]
        data=bytearray(path.read_bytes()); data[0]^=1; path.write_bytes(data)
        report=self.run_audit(expected=1)
        self.assertEqual(report['runtime']['status'],'drift')
        self.assertEqual(next(f for f in report['runtime']['files'] if f['path']==PATHS[0])['status'],'changed')

    def test_missing_file_is_definite_drift(self):
        (self.root/PATHS[0]).unlink()
        report=self.run_audit(expected=1)
        self.assertEqual(next(f for f in report['runtime']['files'] if f['path']==PATHS[0])['status'],'missing')

    def test_extra_lua_requires_review_and_redacts_name(self):
        (self.root/LUA_DIR/(PRIVATE+'.lua')).write_text('return {}')
        report=self.run_audit(expected=1)
        self.assertTrue(report['issues'])

    def test_extra_nested_reds_requires_review(self):
        p=self.root/REDS_DIR/'nested'/(PRIVATE+'.reds');p.parent.mkdir();p.write_text('module SomethingElse')
        self.run_audit(expected=1)

    @unittest.skipUnless(CASE_DISTINCT_NAMES,'filesystem does not permit case-distinct aliases')
    def test_case_alias_lua_requires_review(self):
        original=self.root/LUA_DIR/'init.lua';alias=original.with_name('INIT.LuA')
        shutil.copyfile(original,alias)
        self.run_audit(expected=1)

    def test_duplicate_candidate_outside_reborn_requires_review(self):
        p=self.root/'r6/scripts'/PRIVATE/'extra.reds';p.parent.mkdir();p.write_text('public class NLSRebornWhatever {}')
        report=self.run_audit(expected=1)
        self.assertTrue(any(s['review_candidates'] for s in report['scans']))

    def test_unrelated_redscript_not_a_conflict(self):
        p=self.root/'r6/scripts/Unrelated/extra.reds';p.parent.mkdir();p.write_text('public class SomethingElse {}')
        self.run_audit(expected=0)

    def test_user_config_json_ignored_without_contents(self):
        (self.root/LUA_DIR/'config.json').write_text('{"secret":"'+PRIVATE+'"}')
        (self.root/LUA_DIR/'profile-settings.json.bak').write_text(PRIVATE)
        (self.root/LUA_DIR/'support-report.json').write_text(PRIVATE)
        self.run_audit(expected=0)

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_expected_file_symlink_cannot_match(self):
        p=self.root/PATHS[0];p.unlink();p.symlink_to(self.reference/PATHS[0])
        report=self.run_audit(expected=2)
        self.assertEqual(report['runtime']['status'],'incomplete')

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_root_symlink_rejected(self):
        alias=Path(self.tmp.name)/'alias';alias.symlink_to(self.root,target_is_directory=True)
        self.run_audit(root=alias,expected=2)

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_root_ancestor_symlink_rejected(self):
        alias=Path(self.tmp.name)/'alias';alias.symlink_to(self.root.parent,target_is_directory=True)
        self.run_audit(root=alias/self.root.name,expected=2)

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_extra_symlink_directory_not_followed(self):
        outside=Path(self.tmp.name)/'outside';outside.mkdir();(outside/'extra.reds').write_text(PRIVATE)
        (self.root/'r6/scripts/external').symlink_to(outside,target_is_directory=True)
        self.run_audit(expected=2)

    def test_missing_root_incomplete_no_raw_path(self):
        self.run_audit(root=Path(self.tmp.name)/'absent',expected=2)

    def test_user_reported_version_source(self):
        report=self.run_audit('--version','game=2.31','--version','cet=1.37.1',expected=0)
        self.assertEqual(report['version_labels']['game'],{'value':'2.31','source':'user_reported'})
        self.assertEqual(report['version_labels']['cet'],{'value':'1.37.1','source':'user_reported'})
        self.assertNotIn('redscript', report['version_labels'])

    def test_unsupported_version_component_rejected(self):
        self.run_audit('--version','private_component=123',expected=2)

    def test_oversized_version_label_rejected(self):
        self.run_audit('--version','game='+'x'*81,expected=2)

    def test_control_character_version_label_rejected(self):
        self.run_audit('--version','game=hello\nworld',expected=2)

    def test_path_version_label_rejected_without_echo(self):
        self.run_audit('--version','game=C:/Users/'+PRIVATE,expected=2)

    def test_archive_option_is_not_supported(self):
        report=self.run_audit('--archive',TOOL,expected=2)
        self.assertEqual(report['archive']['status'],'not_supported_embedded_tool')

    def test_archive_option_cannot_claim_a_match(self):
        p=Path(self.tmp.name)/'test.zip';p.write_bytes(b'wrong archive')
        report=self.run_audit('--archive',p,expected=2)
        self.assertEqual(report['issues'][0]['code'],'invalid_input')

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_archive_option_does_not_follow_symlink(self):
        p=Path(self.tmp.name)/'test.zip';p.symlink_to(TOOL)
        self.run_audit('--archive',p,expected=2)

    def test_inventory_tampering_cannot_pass(self):
        copied=Path(self.tmp.name)/'copied_tool';copied.mkdir()
        shutil.copyfile(TOOL,copied/TOOL.name)
        inventory=json.loads((KIT/'runtime_inventory.json').read_text());inventory['release']='modified'
        (copied/'runtime_inventory.json').write_text(json.dumps(inventory))
        self.run_audit(tool=copied/TOOL.name,expected=2)

    def test_log_evidence_redacts_private_contents_and_is_unscoped(self):
        log=Path(self.tmp.name)/'log.txt';log.write_text('[ERROR] '+PRIVATE+'\n[warning] message\n')
        report=self.run_audit('--redscript-log',log,expected=0)
        entry=next(e for e in report['logs'] if e['kind']=='redscript')
        self.assertEqual(entry['scope'],'unscoped_tail_observation')
        self.assertNotIn(PRIVATE,json.dumps(entry))
        self.assertIn('sha256',json.dumps(entry))
        self.assertNotIn('compile_pass',json.dumps(report))

    def test_large_log_tail_bounded(self):
        log=Path(self.tmp.name)/'log.txt';log.write_bytes((PRIVATE+'\n').encode()*20000+b'[warning] tail\n')
        report=self.run_audit('--cet-log',log,expected=0)
        entry=next(e for e in report['logs'] if e['kind']=='cet')
        self.assertEqual(entry['scope'],'unscoped_tail_observation')
        # A digest of the observed bounded tail must not claim complete-log coverage.
        self.assertNotIn(PRIVATE,json.dumps(entry))
        self.assertTrue(any(isinstance(v,int) and v<=131072 for k,v in entry.items() if 'bytes' in k and 'size' not in k),entry)

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_log_symlink_incomplete(self):
        log=Path(self.tmp.name)/'log.txt';log.symlink_to(TOOL)
        self.run_audit('--cet-log',log,expected=2)

    def test_overlarge_candidate_scan_cannot_be_green(self):
        p=self.root/'r6/scripts/large.reds';p.write_bytes(b' '*((2*1024*1024)+1))
        self.run_audit(expected=2)

    def test_inventory_covers_every_baseline_runtime_file(self):
        found = sorted(name for name in RUNTIME_PATHS
                       if any(name.startswith(directory+'/') for directory in (LUA_DIR,REDS_DIR))
                       and Path(name).suffix in ('.lua','.reds'))
        self.assertEqual(sorted(PATHS),found)
        self.assertEqual(len(found),16)
        for row in INVENTORY['runtime_files']:
            b=ORIGINAL_BYTES[row['path']]
            self.assertEqual(len(b),row['size'])
            self.assertEqual(hashlib.sha256(b).hexdigest(),row['sha256'])

    @unittest.skipUnless(CASE_DISTINCT_NAMES,'filesystem does not permit case-distinct aliases')
    def test_case_alias_mod_directory_requires_review(self):
        alias=self.root/LUA_DIR.lower()
        # Only final directory component differs; retain known parent spelling.
        alias=(self.root/LUA_DIR).with_name('neverlocksavesreborn')
        alias.mkdir()
        self.run_audit(expected=1)

    def test_depth_budget_incomplete(self):
        p=self.root/'r6/scripts'
        for i in range(18):
            p=p/('d'+str(i));p.mkdir()
        (p/'extra.reds').write_text('public class Other {}')
        report=self.run_audit(expected=2)
        self.assertTrue(any(s['status']=='incomplete' for s in report['scans']))

    def test_entry_budget_incomplete(self):
        p=self.root/'r6/scripts/many';p.mkdir()
        for i in range(8200):
            (p/('entry'+str(i)+'.txt')).touch()
        report=self.run_audit(expected=2)
        self.assertTrue(any(s['status']=='incomplete' for s in report['scans']))

    @unittest.skipUnless(hasattr(os,'mkfifo'),'FIFO API unavailable')
    def test_nonregular_entry_incomplete_without_hanging(self):
        os.mkfifo(self.root/'r6/scripts/fifo')
        self.run_audit(expected=2)

    def test_missing_requested_log_incomplete(self):
        self.run_audit('--cet-log',Path(self.tmp.name)/'absent.log',expected=2)

    def test_unknown_argument_is_structured_and_redacted(self):
        self.run_audit('--unknown-private-argument',PRIVATE,expected=2)

    def test_log_marker_counts_do_not_promote_compilation(self):
        log=Path(self.tmp.name)/'log.txt'
        log.write_text('error ERROR errorless\nwarning WARN failed FAILED 1.0.0-rc1 1.0.0-rc2 1.0.0-rc3 1.0.0-rc4\n')
        report=self.run_audit('--cet-log',log,expected=0)
        item=next(e for e in report['logs'] if e['kind']=='cet')
        self.assertEqual(item['current_compilation'],'unknown')
        self.assertEqual(item['marker_counts'],{'error':2,'warning':2,'failed':2,'rc1_label':1,'rc2_label':1,'rc3_label':1,'rc4_label':1})

    def test_renamed_cet_copy_candidate_requires_review(self):
        p=(self.root/LUA_DIR).parent/PRIVATE/'init.lua'
        p.parent.mkdir();p.write_text("local NLSReborn = {} -- old copy")
        self.run_audit(expected=1)

    def test_unrelated_immediate_cet_init_not_a_conflict(self):
        p=(self.root/LUA_DIR).parent/'OtherMod'/'init.lua'
        p.parent.mkdir();p.write_text("return {} -- other mod")
        self.run_audit(expected=0)

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_cet_candidate_symlink_init_incomplete(self):
        p=(self.root/LUA_DIR).parent/'OtherMod'/'init.lua'
        p.parent.mkdir();p.symlink_to(self.reference/PATHS[0])
        self.run_audit(expected=2)

    @unittest.skipUnless(SYMLINK_AVAILABLE,'file/directory symlink privileges unavailable')
    def test_cet_candidate_symlink_child_directory_incomplete(self):
        p=(self.root/LUA_DIR).parent/'OtherMod'
        p.symlink_to(self.reference/LUA_DIR,target_is_directory=True)
        self.run_audit(expected=2)

    def test_overlarge_cet_candidate_init_incomplete(self):
        p=(self.root/LUA_DIR).parent/'OtherMod'/'init.lua'
        p.parent.mkdir();p.write_bytes(b' '*((2*1024*1024)+1))
        self.run_audit(expected=2)

    def test_help_is_available_without_game_root(self):
        p=subprocess.run([sys.executable,str(TOOL),'--help'],capture_output=True,text=True,timeout=10)
        self.assertEqual(p.returncode,0);self.assertIn('--game-root',p.stdout)


if __name__=='__main__':
    unittest.main(verbosity=2)
