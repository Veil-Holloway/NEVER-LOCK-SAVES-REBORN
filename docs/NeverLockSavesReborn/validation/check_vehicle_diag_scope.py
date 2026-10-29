#!/usr/bin/env python3
"""Recover exact RC4 bytes only from complete pinned diagnostic files.

This is a source-identity guard, not compilation or save-creation evidence.
Historical fixtures are immutable. Every modified or partial file remains
visible to the earlier guard; normalization never accepts approximate matches.
"""
from check_diagnostic2_scope import normalized_diagnostic1, normalize_reviewed_files as normalize_diagnostic2
from pathlib import Path
import hashlib
import json
import sys

FIXTURE = Path(__file__).parent / 'fixtures/vehicle_diag_scope.json'


def fixture():
    return json.loads(FIXTURE.read_text())


def sha(data):
    return hashlib.sha256(data).hexdigest()


def exact_candidate_to_rc4(root, rel):
    spec = fixture()['changed_files'][rel]
    data = normalized_diagnostic1(root, rel)
    assert sha(data) == spec['candidate_sha256'], 'Diagnostic source differs outside reviewed request-result changes: ' + rel
    lines = data.decode('utf-8').splitlines(keepends=True)
    for splice in reversed(spec['splices']):
        start, end = splice['candidate_start_line'], splice['candidate_end_line']
        assert ''.join(lines[start:end]) == splice['after'], 'Diagnostic approved splice mismatch: ' + rel
        lines[start:end] = splice['before'].splitlines(keepends=True)
    baseline = ''.join(lines).encode('utf-8')
    assert sha(baseline) == spec['baseline_sha256'], 'Unrelated RC4 bytes changed: ' + rel
    return baseline


def normalized_rc4(root, rel):
    """Adapt only complete exact diagnostic files; edits still fail old guards."""
    spec = fixture()['changed_files'].get(rel)
    data = normalized_diagnostic1(root, rel)
    if spec and sha(data) == spec['candidate_sha256']:
        return exact_candidate_to_rc4(root, rel)
    return data


def normalize_reviewed_files(root):
    """For temporary historical mutation views, recover only exact pinned files."""
    normalize_diagnostic2(root)
    for rel, spec in fixture()['changed_files'].items():
        path = root / rel
        if path.is_file() and sha(path.read_bytes()) == spec['candidate_sha256']:
            path.write_bytes(exact_candidate_to_rc4(root, rel))


def check(root):
    f = fixture()
    for rel in f['changed_files']:
        exact_candidate_to_rc4(root, rel)
    actual = set()
    for top in f['protected_roots']:
        for path in (root / top).rglob('*'):
            if path.is_file() and '__pycache__' not in path.parts and path.suffix not in ('.pyc', '.pyo'):
                assert not path.is_symlink(), 'Unexpected diagnostic source symlink'
                actual.add(path.relative_to(root).as_posix())
    assert actual == set(f['changed_files']) | set(f['unchanged_files']), 'Diagnostic runtime/helper file inventory changed'
    for rel, expected in f['unchanged_files'].items():
        assert sha(normalized_diagnostic1(root, rel)) == expected, 'Changed protected diagnostic file: ' + rel
    print('PASS exact diagnostic scope: checked native Bool, bounded request-only diagnostics and exact labels/auditor pins; '
          + str(len(f['changed_files'])) + ' reviewed complete files; '
          + str(len(f['unchanged_files'])) + ' unchanged protected files. Source identity only.')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
