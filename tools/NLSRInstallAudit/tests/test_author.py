"""Real-filesystem public CLI checks for the integrated RC4 installation auditor."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).absolute().parent
KIT = HERE.parent if (HERE.parent / 'audit_installation.py').is_file() else HERE.parent / 'kit'
SCRIPT = KIT / 'audit_installation.py'
INVENTORY = json.loads((KIT / 'runtime_inventory.json').read_text())
RELEASE_ROOT = KIT.parent.parent
RUNTIME_BYTES = {row['path']: (RELEASE_ROOT / row['path']).read_bytes() for row in INVENTORY['runtime_files']}
LUA = Path('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')
REDS = Path('r6/scripts/NeverLockSavesReborn')


class AuditCli(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='private-Acceptance-')
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name)
        self.game = self.parent / 'PRIVATE_USERNAME-game'
        self.game.mkdir()
        for row in INVENTORY['runtime_files']:
            target = self.game / row['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(RUNTIME_BYTES[row['path']])

    def run_audit(self, *args, script=SCRIPT):
        proc = subprocess.run([sys.executable, '-B', str(script), '--game-root', str(self.game), *map(str, args)], capture_output=True)
        self.assertEqual(proc.stderr, b'')
        report = json.loads(proc.stdout)
        self.assertNotIn(str(self.parent), proc.stdout.decode())
        self.assertNotIn('PRIVATE_USERNAME', proc.stdout.decode())
        return proc.returncode, report

    def put(self, rel, data=b'ordinary unrelated data'):
        path = self.game / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def link(self, path, target, directory=False):
        try:
            path.symlink_to(target, target_is_directory=directory)
        except (OSError, NotImplementedError):
            self.skipTest('Host cannot create this symlink fixture; Windows privileges may be required')

    def require_case_sensitive(self):
        probe = self.parent / 'CaseProbe'
        probe.write_bytes(b'probe')
        if (self.parent / 'CASEPROBE').exists():
            self.skipTest('Case-collision fixture requires a case-sensitive filesystem')

    def test_clean_exact_runtime(self):
        code, report = self.run_audit()
        self.assertEqual(code, 0)
        self.assertEqual(report['audit_status'], 'exact_match')
        self.assertEqual(len(report['runtime']['files']), 16)
        self.assertTrue(all(r['status'] == 'match' for r in report['runtime']['files']))
        self.assertTrue(all(s['status'] == 'complete' for s in report['scans']))
        self.assertEqual(report['archive']['status'], 'not_supported_embedded_tool')

    def test_no_source_writes(self):
        def snapshot():
            return {p.relative_to(self.game).as_posix(): (p.stat().st_mtime_ns, hashlib.sha256(p.read_bytes()).hexdigest()) for p in self.game.rglob('*') if p.is_file()}
        before = snapshot()
        self.assertEqual(self.run_audit()[0], 0)
        self.assertEqual(snapshot(), before)
        self.assertEqual(set(p.relative_to(self.game).as_posix() for p in self.game.rglob('*') if p.is_file()), set(before))

    def test_missing_runtime_is_drift(self):
        (self.game / LUA / 'init.lua').unlink()
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        self.assertIn('missing', [r['status'] for r in report['runtime']['files']])

    def test_changed_runtime_same_length(self):
        path = self.game / LUA / 'init.lua'
        data = path.read_bytes()
        path.write_bytes(b'X' + data[1:])
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        self.assertEqual(report['runtime']['status'], 'drift')

    def test_absent_known_directories_definite_drift(self):
        shutil.rmtree(self.game / 'r6')
        self.assertEqual(self.run_audit()[0], 1)

    def test_extra_lua(self):
        self.put(LUA / 'SECRET-USERNAME-leftover.lua')
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        self.assertNotIn('SECRET-USERNAME', json.dumps(report))
        self.assertTrue(any(r['code'] == 'extra_runtime_script' for r in report['issues']))

    def test_extra_reds_nested(self):
        self.put(REDS / 'subdir' / 'old.reds')
        self.assertEqual(self.run_audit()[0], 1)

    def test_config_report_and_non_script_files_ignored(self):
        for name in ('config.json', 'profile-settings.json', 'support-report.json', 'notes.txt'):
            self.put(LUA / name)
        self.assertEqual(self.run_audit()[0], 0)

    def test_duplicate_token_in_other_folder(self):
        self.put(Path('r6/scripts/PRIVATE_CHARACTER_oldmod/example.reds'), b'// NLSReborn old definition')
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        self.assertNotIn('PRIVATE_CHARACTER', json.dumps(report))
        self.assertTrue(any(r['code'] == 'duplicate_definition_candidate' for r in report['issues']))

    def test_duplicate_second_token_case_insensitive(self):
        self.put(Path('r6/scripts/other/source.REDS'), b'NeverLockSaves')
        self.assertEqual(self.run_audit()[0], 1)

    def test_unrelated_redscript_not_review(self):
        self.put(Path('r6/scripts/other/source.reds'), b'public class OtherMod {}')
        self.assertEqual(self.run_audit()[0], 0)

    def test_case_alias_runtime_file(self):
        self.require_case_sensitive()
        self.put(LUA / 'INIT.LUA')
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        self.assertTrue(any(r['code'] == 'case_insensitive_alias' for r in report['issues']))

    def test_case_alias_mod_directory(self):
        self.require_case_sensitive()
        self.put(LUA.parent / 'neverlocksavesreborn' / 'init.lua')
        self.assertEqual(self.run_audit()[0], 1)

    def test_symlink_runtime_file(self):
        path = self.game / LUA / 'init.lua'
        target = self.parent / 'original.lua'
        path.rename(target)
        self.link(path, target)
        self.assertEqual(self.run_audit()[0], 2)

    def test_symlink_runtime_directory(self):
        path = self.game / LUA
        target = self.parent / 'original-mod'
        path.rename(target)
        self.link(path, target, directory=True)
        self.assertEqual(self.run_audit()[0], 2)

    def test_symlink_inside_broad_scan_no_follow(self):
        target = self.parent / 'outside'
        target.mkdir()
        (target / 'source.reds').write_bytes(b'NLSReborn')
        self.link(self.game / 'r6/scripts/linked', target, directory=True)
        code, report = self.run_audit()
        self.assertEqual(code, 2)
        self.assertTrue(any(r['code'] == 'unsafe_path' for r in report['issues']))

    def test_game_root_ancestor_symlink(self):
        link = self.parent / 'game-link'
        self.link(link, self.game, directory=True)
        self.game = link
        self.assertEqual(self.run_audit()[0], 2)

    def test_nonregular_file(self):
        if not hasattr(os, 'mkfifo'):
            self.skipTest('FIFO unavailable')
        os.mkfifo(self.game / LUA / 'pipe')
        self.assertEqual(self.run_audit()[0], 2)

    def test_oversize_runtime(self):
        self.put(LUA / 'init.lua', b'x' * (2 * 1024 * 1024 + 1))
        self.assertEqual(self.run_audit()[0], 2)

    def test_oversize_redscript_candidate(self):
        self.put(Path('r6/scripts/other/huge.reds'), b'x' * (2 * 1024 * 1024 + 1))
        self.assertEqual(self.run_audit()[0], 2)

    def test_depth_budget(self):
        self.put(Path('r6/scripts') / Path(*(['d'] * 18)) / 'source.reds')
        self.assertEqual(self.run_audit()[0], 2)

    def test_entry_budget(self):
        directory = self.game / 'r6/scripts/many'
        directory.mkdir()
        for index in range(8200):
            (directory / str(index)).touch()
        self.assertEqual(self.run_audit()[0], 2)

    def test_log_tail_counts_digest_and_privacy(self):
        path = self.parent / 'PRIVATE_GAME.log'
        prefix = b'PRIVATE_LOG_CONTENT\nerror\n' * 10000
        tail = b'warning failed 1.0.0-rc1 1.0.0-rc2 1.0.0-RC3 1.0.0-RC4 ERROR\n'
        path.write_bytes(prefix + tail)
        code, report = self.run_audit('--cet-log', path)
        self.assertEqual(code, 0)
        log = report['logs'][0]
        observed = (prefix + tail)[-128 * 1024:]
        self.assertEqual(log['observed_bytes'], 128 * 1024)
        self.assertEqual(log['tail_sha256'], hashlib.sha256(observed).hexdigest())
        self.assertEqual(log['marker_counts']['rc1_label'], 1)
        self.assertEqual(log['marker_counts']['rc2_label'], 1)
        self.assertEqual(log['marker_counts']['rc3_label'], 1)
        self.assertEqual(log['marker_counts']['rc4_label'], 1)
        self.assertEqual(log['marker_counts']['warning'], 1)
        self.assertNotIn('PRIVATE_LOG_CONTENT', json.dumps(report))
        self.assertEqual(log['current_compilation'], 'unknown')

    def test_missing_optional_log_is_incomplete(self):
        self.assertEqual(self.run_audit('--redscript-log', self.parent / 'absent.log')[0], 2)

    def test_versions_are_user_reported(self):
        code, report = self.run_audit('--version', 'game=2.31', '--version', 'cet=1.37.0+local (test)')
        self.assertEqual(code, 0)
        self.assertEqual(report['version_labels']['game'], {'value': '2.31', 'source': 'user_reported'})

    def test_invalid_version_labels_private_input_not_echoed(self):
        for value in ('game=C:\\Users\\PRIVATE_USERNAME', 'game=/home/PRIVATE_USERNAME', 'cet=x\nPRIVATE_USERNAME', 'game=abc:123', 'unknown=1', 'game=' + 'a' * 81):
            with self.subTest(value=value):
                code, report = self.run_audit('--version', value)
                self.assertEqual(code, 2)
                self.assertNotIn('PRIVATE_USERNAME', json.dumps(report))
                self.assertEqual(report['issues'][0]['code'], 'invalid_input')

    def test_duplicate_version_refused(self):
        self.assertEqual(self.run_audit('--version', 'game=2.31', '--version', 'game=2.3')[0], 2)

    def test_unknown_argument_sanitized(self):
        code, report = self.run_audit('--PRIVATE_USERNAME')
        self.assertEqual(code, 2)
        self.assertEqual(report['issues'][0]['code'], 'invalid_input')

    def test_archive_changed_and_missing(self):
        path = self.parent / 'private.zip'
        path.write_bytes(b'not zip')
        code, report = self.run_audit('--archive', path)
        self.assertEqual(code, 2)
        self.assertEqual(report['issues'][0]['code'], 'invalid_input')
        path.unlink()
        self.assertEqual(self.run_audit('--archive', path)[0], 2)

    def test_dependency_presence_not_version(self):
        self.put(Path('red4ext/RED4ext.dll'), b'pretend bytes')
        code, report = self.run_audit()
        self.assertEqual(code, 0)
        red4ext = next(r for r in report['dependencies'] if r['component'] == 'red4ext')
        self.assertEqual(red4ext['status'], 'present')
        self.assertEqual(red4ext['version'], 'unknown')
        self.assertEqual(red4ext['evidence_scope'], 'file_presence_only')
        cet = next(r for r in report['dependencies'] if r['component'] == 'cet')
        self.assertEqual(cet['status'], 'not_found_at_checked_path')

    def test_unsafe_optional_dependency_incomplete(self):
        target = self.parent / 'dll'
        target.write_bytes(b'bytes')
        path = self.game / 'red4ext/RED4ext.dll'
        path.parent.mkdir()
        self.link(path, target)
        self.assertEqual(self.run_audit()[0], 2)

    def test_inventory_pin(self):
        folder = self.parent / 'kit'
        folder.mkdir()
        shutil.copyfile(SCRIPT, folder / SCRIPT.name)
        raw = (KIT / 'runtime_inventory.json').read_bytes()
        (folder / 'runtime_inventory.json').write_bytes(raw + b'\n')
        code, report = self.run_audit(script=folder / SCRIPT.name)
        self.assertEqual(code, 2)
        self.assertEqual(report['issues'][0]['code'], 'inventory_pin_mismatch')

    def test_missing_game_root_and_traversal(self):
        self.game = self.parent / 'does-not-exist'
        self.assertEqual(self.run_audit()[0], 2)
        self.game = self.parent / 'part' / '..' / 'game'
        self.assertEqual(self.run_audit()[0], 2)

    def test_renamed_cet_duplicate(self):
        self.put(LUA.parent / 'PRIVATE_COPY_old' / 'init.lua', b'-- NeverLockSaves copied init')
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        self.assertNotIn('PRIVATE_COPY', json.dumps(report))
        self.assertTrue(any(row['code'] == 'duplicate_cet_mod_candidate' for row in report['issues']))

    def test_unrelated_cet_mod_init(self):
        self.put(LUA.parent / 'other' / 'init.lua', b'print("ordinary unrelated mod")')
        self.assertEqual(self.run_audit()[0], 0)

    def test_other_cet_directory_symlink(self):
        target = self.parent / 'outside-mod'
        target.mkdir()
        self.link(self.game / LUA.parent / 'other', target, directory=True)
        self.assertEqual(self.run_audit()[0], 2)

    def test_other_cet_init_symlink(self):
        target = self.parent / 'outside-init'
        target.write_bytes(b'no marker')
        path = self.game / LUA.parent / 'other' / 'init.lua'
        path.parent.mkdir()
        self.link(path, target)
        self.assertEqual(self.run_audit()[0], 2)

    def test_other_cet_init_oversize(self):
        self.put(LUA.parent / 'other' / 'init.lua', b'x' * (2 * 1024 * 1024 + 1))
        self.assertEqual(self.run_audit()[0], 2)

    def test_other_cet_nested_file_out_of_scope(self):
        self.put(LUA.parent / 'other' / 'nested' / 'init.lua', b'NLSReborn')
        self.assertEqual(self.run_audit()[0], 0)

    def test_evidence_environment_and_time(self):
        from datetime import datetime
        code, report = self.run_audit()
        self.assertEqual(code, 0)
        self.assertEqual(report['audit_host']['platform'], sys.platform)
        self.assertEqual(report['audit_host']['python_version'], '.'.join(str(n) for n in sys.version_info[:3]))
        timestamp = datetime.fromisoformat(report['observed_at_utc'])
        self.assertEqual(timestamp.utcoffset().total_seconds(), 0)

    def test_archive_option_is_explicitly_rejected(self):
        code, report = self.run_audit('--archive', self.parent / 'PRIVATE_USERNAME.zip')
        self.assertEqual(code, 2)
        self.assertEqual(report['archive']['status'], 'not_supported_embedded_tool')
        self.assertEqual(report['issues'][0]['code'], 'invalid_input')

    def test_new_dependency_collector_missing_is_drift(self):
        (self.game / LUA / 'dependency_versions.lua').unlink()
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        row = next(r for r in report['runtime']['files'] if r['path'].endswith('/dependency_versions.lua'))
        self.assertEqual(row['status'], 'missing')

    def test_new_dependency_collector_changed_is_drift(self):
        path = self.game / LUA / 'dependency_versions.lua'
        data = path.read_bytes()
        path.write_bytes(b'X' + data[1:])
        code, report = self.run_audit()
        self.assertEqual(code, 1)
        row = next(r for r in report['runtime']['files'] if r['path'].endswith('/dependency_versions.lua'))
        self.assertEqual(row['status'], 'changed')

    def test_stable_read_rejects_observed_change(self):
        import importlib.util
        from unittest import mock
        spec = importlib.util.spec_from_file_location('nlsr_audit_author', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        target = self.parent / 'changing'
        target.write_bytes(b'initial bytes')
        real_fstat = os.fstat
        calls = [0]
        def change_before_final_fstat(fd):
            calls[0] += 1
            if calls[0] == 2:
                target.write_bytes(b'changed bytes with a different length')
            return real_fstat(fd)
        with mock.patch.object(module.os, 'fstat', side_effect=change_before_final_fstat):
            with self.assertRaises(module.AuditError) as raised:
                module.stable_read(target, 1024)
        self.assertEqual(raised.exception.code, 'file_changed_during_read')

    def test_read_error_fails_closed(self):
        import importlib.util
        from unittest import mock
        spec = importlib.util.spec_from_file_location('nlsr_audit_author_io', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        report = module.base_report()
        auditor = module.Auditor(report, self.game, INVENTORY)
        real_read = module.stable_read
        def denied(path, *args, **kwargs):
            if str(path).endswith('init.lua'):
                raise PermissionError('PRIVATE_USERNAME must not be reported')
            return real_read(path, *args, **kwargs)
        with mock.patch.object(module, 'stable_read', side_effect=denied):
            auditor.runtime()
        self.assertTrue(auditor.incomplete)
        self.assertEqual(report['runtime']['status'], 'incomplete')
        self.assertNotIn('PRIVATE_USERNAME', json.dumps(report))

    def test_cet_total_byte_budget(self):
        for index in range(33):
            self.put(LUA.parent / ('other' + str(index)) / 'init.lua', b'x' * (2 * 1024 * 1024))
        self.assertEqual(self.run_audit()[0], 2)

    def test_redscript_total_byte_budget(self):
        for index in range(33):
            self.put(Path('r6/scripts/other') / (str(index) + '.reds'), b'x' * (2 * 1024 * 1024))
        self.assertEqual(self.run_audit()[0], 2)

    def test_help(self):
        proc = subprocess.run([sys.executable, '-B', str(SCRIPT), '--help'], capture_output=True)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stderr, b'')
        self.assertIn(b'--game-root', proc.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
