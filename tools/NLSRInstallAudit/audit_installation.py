#!/usr/bin/env python3
"""Read-only, bounded RC4 installation observations; standard library only."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

RELEASE = '1.0.0-vehicle-diagnostic.2'
INVENTORY_SHA256 = 'd60af3e039cffc975bf65b59c2e9c5f28f676429ca48ae69bfdd5b715d9d1578'
LUA_ROOT = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn'
REDS_ROOT = 'r6/scripts/NeverLockSavesReborn'
MAX_FILE = 2 * 1024 * 1024
MAX_SCAN_ENTRIES = 8192
MAX_SCAN_BYTES = 64 * 1024 * 1024
MAX_DEPTH = 16
LOG_TAIL = 128 * 1024
VERSION_KEYS = {'game', 'cet', 'redscript', 'red4ext', 'codeware', 'native_settings', 'dark_future'}
DEPENDENCIES = (
    ('cet', 'bin/x64/plugins/cyber_engine_tweaks.asi'),
    ('red4ext', 'red4ext/RED4ext.dll'),
    ('codeware', 'red4ext/plugins/Codeware/Codeware.dll'),
    ('redscript', 'engine/tools/scc.exe'),
    ('native_settings', 'bin/x64/plugins/cyber_engine_tweaks/mods/nativeSettings/init.lua'),
)
LIMITATIONS = [
    'File matches establish installed bytes only; no game compilation or runtime compatibility is verified.',
    'Versions are explicit user labels; dependency observations establish file presence only.',
    'Optional log tails are unscoped observations and may describe earlier sessions or unrelated mods.',
    'No save creation, written-file correlation, reload, quest progression, or stable release is established.',
    'Link and stability checks are best effort; hostile concurrent path replacement cannot be excluded.',
]


class AuditError(Exception):
    def __init__(self, code):
        self.code = code


def unsafe(st):
    return stat.S_ISLNK(st.st_mode) or bool(getattr(st, 'st_file_attributes', 0) & 0x400)


def identity(st):
    return (st.st_dev, st.st_ino, st.st_mode, st.st_size, st.st_mtime_ns, st.st_ctime_ns)


def path_input(value):
    if not value or len(value) > 4096 or '\x00' in value or '..' in Path(value).parts:
        raise AuditError('invalid_input')
    return Path(os.path.abspath(value))


def checked_stat(path):
    """lstat each ancestor before using a path; never deliberately follow a link."""
    absolute = Path(os.path.abspath(path))
    current = Path(absolute.anchor)
    for component in absolute.parts[1:]:
        current = current / component
        st = current.lstat()
        if unsafe(st):
            raise AuditError('unsafe_path')
        if current != absolute and not stat.S_ISDIR(st.st_mode):
            raise AuditError('unsafe_ancestor')
    return absolute.lstat()


def stable_read(path, limit, tail=False):
    before = checked_stat(path)
    if not stat.S_ISREG(before.st_mode):
        raise AuditError('not_regular_file')
    if before.st_size < 0 or (not tail and before.st_size > limit):
        raise AuditError('file_budget_exceeded')
    flags = os.O_RDONLY | getattr(os, 'O_BINARY', 0) | getattr(os, 'O_NOFOLLOW', 0)
    fd = os.open(path, flags)
    with os.fdopen(fd, 'rb') as handle:
        opened = os.fstat(handle.fileno())
        if identity(before) != identity(opened) or unsafe(opened) or not stat.S_ISREG(opened.st_mode):
            raise AuditError('file_changed_during_read')
        if tail:
            handle.seek(max(0, opened.st_size - limit))
        data = handle.read(limit + 1)
        after_fd = os.fstat(handle.fileno())
    after_path = checked_stat(path)
    if len(data) > limit or identity(before) != identity(after_fd) or identity(before) != identity(after_path):
        raise AuditError('file_changed_during_read')
    expected = min(limit, before.st_size) if tail else before.st_size
    if len(data) != expected:
        raise AuditError('file_changed_during_read')
    return data, before


def digest(data):
    return hashlib.sha256(data).hexdigest()


def anonymous(relative):
    # Discovered names may contain personal data or control characters.
    return {'relative_path_sha256': digest(relative.encode('utf-8', 'surrogatepass'))}


def load_inventory():
    data, _ = stable_read(Path(__file__).absolute().parent / 'runtime_inventory.json', 256 * 1024)
    if digest(data) != INVENTORY_SHA256:
        raise AuditError('inventory_pin_mismatch')
    value = json.loads(data)
    if value.get('schema') != 1 or value.get('release') != RELEASE:
        raise AuditError('invalid_inventory')
    rows = value.get('runtime_files')
    if not isinstance(rows, list) or len(rows) != 16:
        raise AuditError('invalid_inventory')
    paths = set()
    for row in rows:
        path = row.get('path', '')
        parts = path.split('/')
        if not path.startswith((LUA_ROOT + '/', REDS_ROOT + '/')) or any(p in ('', '.', '..') for p in parts) or '\\' in path:
            raise AuditError('invalid_inventory')
        if path.casefold() in paths or type(row.get('size')) is not int or not 0 <= row['size'] <= MAX_FILE:
            raise AuditError('invalid_inventory')
        if not re.fullmatch('[0-9a-f]{64}', row.get('sha256', '')):
            raise AuditError('invalid_inventory')
        paths.add(path.casefold())
    return value


def base_report():
    return {'schema_version': 1, 'release': RELEASE, 'audit_status': 'incomplete',
            'observed_at_utc': datetime.now(timezone.utc).isoformat(),
            'audit_host': {'platform': sys.platform, 'python_version': '.'.join(str(n) for n in sys.version_info[:3])},
            'runtime': {'status': 'incomplete', 'files': []},
            'archive': {'status': 'not_supported_embedded_tool'}, 'scans': [],
            'version_labels': {}, 'dependencies': [], 'logs': [], 'issues': [],
            'limitations': LIMITATIONS}


class Auditor:
    def __init__(self, report, root, inventory):
        self.report, self.root, self.inventory = report, root, inventory
        self.incomplete, self.review = False, False
        self.expected = {r['path']: r for r in inventory['runtime_files']}
        self.expected_folded = {p.casefold(): p for p in self.expected}

    def issue(self, code, scope, path=None, discovered=None, incomplete=False):
        self.incomplete |= incomplete
        self.review |= not incomplete
        row = {'code': code, 'scope': scope}
        if path is not None:
            row['path'] = path
        if discovered is not None:
            row.update(anonymous(discovered))
        if len(self.report['issues']) < 256:
            self.report['issues'].append(row)
        else:
            self.report['issues_omitted'] = self.report.get('issues_omitted', 0) + 1

    def runtime(self):
        has_drift, incomplete = False, False
        for path, expected in self.expected.items():
            row = {'path': path, 'expected_size': expected['size'], 'expected_sha256': expected['sha256']}
            try:
                data, st = stable_read(self.root / path, MAX_FILE)
                row.update(observed_size=st.st_size, observed_sha256=digest(data))
                row['status'] = 'match' if st.st_size == expected['size'] and row['observed_sha256'] == expected['sha256'] else 'changed'
                if row['status'] == 'changed':
                    has_drift = True
                    self.issue('runtime_changed', 'runtime', path=path)
            except FileNotFoundError:
                row['status'] = 'missing'
                has_drift = True
                self.issue('runtime_missing', 'runtime', path=path)
            except (OSError, AuditError) as exc:
                code = exc.code if isinstance(exc, AuditError) else 'io_error'
                row['status'] = 'unsafe' if code in ('unsafe_path', 'unsafe_ancestor', 'not_regular_file') else 'unreadable'
                row['reason'] = code
                incomplete = True
                self.issue(code, 'runtime', path=path, incomplete=True)
            self.report['runtime']['files'].append(row)
        self.report['runtime']['status'] = 'incomplete' if incomplete else 'drift' if has_drift else 'exact_match'

    def scan(self, relative, kind):
        result = {'scope': kind, 'status': 'complete', 'entries': 0, 'files': 0,
                  'bytes_read': 0, 'review_candidates': [], 'candidates_omitted': 0}
        self.report['scans'].append(result)
        seen = set()

        def issue(code, rel, incomplete=False):
            if incomplete:
                result['status'] = 'incomplete'
            self.issue(code, kind, discovered=rel, incomplete=incomplete)

        def candidate(code, rel):
            issue(code, rel)
            if len(result['review_candidates']) < 64:
                result['review_candidates'].append(dict(kind=code, **anonymous(rel)))
            else:
                result['candidates_omitted'] += 1

        def walk(folder, rel, depth):
            if depth > MAX_DEPTH:
                issue('scan_depth_exceeded', rel, True)
                return
            try:
                before = checked_stat(folder)
                if not stat.S_ISDIR(before.st_mode):
                    issue('not_directory', rel, True)
                    return
                with os.scandir(folder) as entries:
                    for entry in entries:
                        result['entries'] += 1
                        if result['entries'] > MAX_SCAN_ENTRIES:
                            raise AuditError('scan_entry_budget_exceeded')
                        child_rel = rel + '/' + entry.name
                        folded = child_rel.casefold()
                        if folded in seen:
                            candidate('case_insensitive_alias', child_rel)
                        seen.add(folded)
                        child = folder / entry.name
                        try:
                            st = entry.stat(follow_symlinks=False)
                            if unsafe(st):
                                issue('unsafe_path', child_rel, True)
                                continue
                            if stat.S_ISDIR(st.st_mode):
                                walk(child, child_rel, depth + 1)
                                continue
                            if not stat.S_ISREG(st.st_mode):
                                issue('not_regular_file', child_rel, True)
                                continue
                            result['files'] += 1
                            suffix = Path(entry.name).suffix.casefold()
                            if suffix not in ('.lua', '.reds'):
                                continue
                            canonical = self.expected_folded.get(folded)
                            if canonical is not None and child_rel != canonical:
                                candidate('case_insensitive_alias', child_rel)
                            if kind != 'redscript_duplicate_candidates':
                                if child_rel not in self.expected:
                                    candidate('extra_runtime_script', child_rel)
                            elif suffix == '.reds' and child_rel not in self.expected:
                                if result['bytes_read'] + st.st_size > MAX_SCAN_BYTES:
                                    raise AuditError('scan_byte_budget_exceeded')
                                data, observed = stable_read(child, MAX_FILE)
                                result['bytes_read'] += observed.st_size
                                lower = data.lower()
                                if b'nlsreborn' in lower or b'neverlocksaves' in lower:
                                    candidate('duplicate_definition_candidate', child_rel)
                        except FileNotFoundError:
                            issue('scan_entry_disappeared', child_rel, True)
                        except (OSError, AuditError) as exc:
                            code = exc.code if isinstance(exc, AuditError) else 'io_error'
                            issue(code, child_rel, True)
                after = checked_stat(folder)
                if identity(before) != identity(after):
                    issue('directory_changed_during_scan', rel, True)
            except FileNotFoundError:
                # Missing known roots are definite absence; expected files report drift.
                if depth:
                    issue('scan_entry_disappeared', rel, True)
            except (OSError, AuditError) as exc:
                code = exc.code if isinstance(exc, AuditError) else 'io_error'
                issue(code, rel, True)

        walk(self.root / relative, relative, 0)

    def mod_directory_aliases(self):
        relative = str(Path(LUA_ROOT).parent).replace('\\', '/')
        scope = 'cet_mod_directory_aliases'
        result = {'scope': scope, 'status': 'complete', 'entries': 0,
                  'files': 0, 'bytes_read': 0, 'review_candidates': [], 'candidates_omitted': 0,
                  'inspection_scope': 'immediate_mod_directories_init_lua_only'}
        self.report['scans'].append(result)
        seen = set()

        def candidate(code, rel):
            self.issue(code, scope, discovered=rel)
            if len(result['review_candidates']) < 64:
                result['review_candidates'].append(dict(kind=code, **anonymous(rel)))
            else:
                result['candidates_omitted'] += 1

        try:
            folder = self.root / relative
            before = checked_stat(folder)
            if not stat.S_ISDIR(before.st_mode):
                raise AuditError('not_directory')
            with os.scandir(folder) as entries:
                for entry in entries:
                    result['entries'] += 1
                    if result['entries'] > MAX_SCAN_ENTRIES:
                        raise AuditError('scan_entry_budget_exceeded')
                    rel = relative + '/' + entry.name
                    if entry.name.casefold() in seen:
                        candidate('case_insensitive_alias', rel)
                    seen.add(entry.name.casefold())
                    try:
                        st = entry.stat(follow_symlinks=False)
                        if unsafe(st):
                            raise AuditError('unsafe_mod_directory')
                        if stat.S_ISREG(st.st_mode):
                            continue
                        if not stat.S_ISDIR(st.st_mode):
                            raise AuditError('not_directory')
                        if entry.name.casefold() == 'neverlocksavesreborn' and entry.name != 'NeverLockSavesReborn':
                            candidate('case_insensitive_alias', rel)
                        if entry.name == 'NeverLockSavesReborn':
                            continue
                        init = folder / entry.name / 'init.lua'
                        try:
                            init_st = checked_stat(init)
                        except FileNotFoundError:
                            continue
                        if result['bytes_read'] + init_st.st_size > MAX_SCAN_BYTES:
                            raise AuditError('scan_byte_budget_exceeded')
                        data, observed = stable_read(init, MAX_FILE)
                        result['files'] += 1
                        result['bytes_read'] += observed.st_size
                        if b'nlsreborn' in data.lower() or b'neverlocksaves' in data.lower():
                            candidate('duplicate_cet_mod_candidate', rel + '/init.lua')
                    except FileNotFoundError:
                        result['status'] = 'incomplete'
                        self.issue('scan_entry_disappeared', scope, discovered=rel, incomplete=True)
                    except (OSError, AuditError) as exc:
                        result['status'] = 'incomplete'
                        self.issue(exc.code if isinstance(exc, AuditError) else 'io_error', scope, discovered=rel, incomplete=True)
            if identity(before) != identity(checked_stat(folder)):
                raise AuditError('directory_changed_during_scan')
        except FileNotFoundError:
            pass
        except (OSError, AuditError) as exc:
            result['status'] = 'incomplete'
            self.issue(exc.code if isinstance(exc, AuditError) else 'io_error', scope, incomplete=True)

    def dependencies(self):
        for component, relative in DEPENDENCIES:
            row = {'component': component, 'path': relative, 'evidence_scope': 'file_presence_only', 'version': 'unknown'}
            try:
                st = checked_stat(self.root / relative)
                if not stat.S_ISREG(st.st_mode):
                    raise AuditError('not_regular_file')
                row['status'] = 'present'
            except FileNotFoundError:
                row['status'] = 'not_found_at_checked_path'
            except (OSError, AuditError) as exc:
                row['status'] = 'incomplete'
                self.issue(exc.code if isinstance(exc, AuditError) else 'io_error', 'dependency_presence', path=relative, incomplete=True)
            self.report['dependencies'].append(row)
        self.report['dependencies'].append({'component': 'dark_future', 'status': 'not_measured', 'version': 'unknown',
                                           'evidence_scope': 'no_pinned_presence_path'})

    def log(self, kind, path):
        if path is None:
            return
        row = {'kind': kind, 'scope': 'unscoped_tail_observation', 'current_compilation': 'unknown'}
        self.report['logs'].append(row)
        try:
            data, st = stable_read(path, LOG_TAIL, tail=True)
            row.update(status='observed', file_size=st.st_size, observed_bytes=len(data), tail_sha256=digest(data),
                       truncated=st.st_size > LOG_TAIL,
                       marker_counts={
                           'error': len(re.findall(rb'\berror\b', data, re.I)),
                           'warning': len(re.findall(rb'\bwarn(?:ing)?\b', data, re.I)),
                           'failed': len(re.findall(rb'\bfailed\b', data, re.I)),
                           'rc1_label': data.lower().count(b'1.0.0-rc1'),
                           'rc2_label': data.lower().count(b'1.0.0-rc2'),
                           'rc3_label': data.lower().count(b'1.0.0-rc3'),
                           'rc4_label': data.lower().count(b'1.0.0-rc4')})
        except (OSError, AuditError) as exc:
            row['status'] = 'incomplete'
            self.issue(exc.code if isinstance(exc, AuditError) else 'io_error', kind + '_log', incomplete=True)


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise AuditError('invalid_input')


def main(argv=None):
    report = base_report()
    try:
        parser = Parser(description='Read-only RC4 runtime byte audit. Prints JSON; does not install, repair, run the game or certify save safety.')
        parser.add_argument('--game-root', required=True, metavar='DIRECTORY', help='Cyberpunk installation directory; never the save directory')
        parser.add_argument('--version', action='append', default=[], metavar='COMPONENT=VALUE',
                            help='User-reported label: game,cet,redscript,red4ext,codeware,native_settings,dark_future; repeat per component')
        parser.add_argument('--redscript-log', metavar='FILE', help='Optional explicit log: observe last 128 KiB only; never establishes current compilation')
        parser.add_argument('--cet-log', metavar='FILE', help='Optional explicit CET log: counts/digest only; no raw text is exported')
        args = parser.parse_args(argv)
        root = path_input(args.game_root)
        logs = [('redscript', path_input(args.redscript_log) if args.redscript_log else None),
                ('cet', path_input(args.cet_log) if args.cet_log else None)]
        if len(args.version) > len(VERSION_KEYS):
            raise AuditError('invalid_input')
        for label in args.version:
            component, separator, value = label.partition('=')
            if separator != '=' or component not in VERSION_KEYS or component in report['version_labels'] or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 ._()+-]{0,79}', value):
                raise AuditError('invalid_input')
            report['version_labels'][component] = {'value': value, 'source': 'user_reported'}
        root_st = checked_stat(root)
        if not stat.S_ISDIR(root_st.st_mode):
            raise AuditError('invalid_game_root')
        inventory = load_inventory()
        report['reference'] = {'inventory_sha256': INVENTORY_SHA256, 'scope': 'runtime_files_only',
                               'runtime_file_count': len(inventory['runtime_files'])}
        audit = Auditor(report, root, inventory)
        audit.runtime()
        audit.scan(LUA_ROOT, 'reborn_lua_directory')
        audit.scan(REDS_ROOT, 'reborn_redscript_directory')
        audit.scan('r6/scripts', 'redscript_duplicate_candidates')
        audit.mod_directory_aliases()
        audit.dependencies()
        for kind, path in logs:
            audit.log(kind, path)
        if audit.incomplete:
            report['audit_status'], exit_code = 'incomplete', 2
        elif audit.review:
            report['audit_status'], exit_code = 'drift_or_review', 1
        else:
            report['audit_status'], exit_code = 'exact_match', 0
    except (AuditError, OSError, ValueError, TypeError, KeyError) as exc:
        code = exc.code if isinstance(exc, AuditError) else 'invalid_or_unreadable_input'
        report['audit_status'] = 'incomplete'
        report['issues'].append({'code': code, 'scope': 'input'})
        exit_code = 2
    print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    return exit_code


if __name__ == '__main__':
    sys.exit(main())
