#!/usr/bin/env python3
"""Exact RC3 preservation outside reviewed Unrestricted admission/cleanup and labels.

Only complete pinned RC4 files may be normalized. Line splices recover exact
pinned RC3 bytes; mutations must reach and fail previous preservation guards.
This verifies source identity, not compilation, checkpoint acceptance or gameplay.
"""
from pathlib import Path
from check_vehicle_diag_scope import normalized_rc4
import hashlib
import json
import sys

FIXTURE = Path(__file__).parent / 'fixtures/rc4_scope.json'


def fixture():
    return json.loads(FIXTURE.read_text())


def sha(data):
    return hashlib.sha256(data).hexdigest()


def exact_candidate_to_rc3(root, rel):
    spec = fixture()['changed_files'][rel]
    data = normalized_rc4(root, rel)
    assert sha(data) == spec['candidate_sha256'], 'RC4 source differs outside reviewed Unrestricted routing/cleanup: ' + rel
    lines = data.decode('utf-8').splitlines(keepends=True)
    for splice in reversed(spec['splices']):
        start, end = splice['candidate_start_line'], splice['candidate_end_line']
        assert ''.join(lines[start:end]) == splice['after'], 'RC4 approved splice mismatch: ' + rel
        lines[start:end] = splice['before'].splitlines(keepends=True)
    baseline = ''.join(lines).encode('utf-8')
    assert sha(baseline) == spec['baseline_sha256'], 'Unrelated RC3 bytes changed: ' + rel
    return baseline


def normalized_rc3(root, rel):
    """Only complete exact RC4 files are adapted; every other edit stays visible."""
    spec = fixture()['changed_files'].get(rel)
    data = normalized_rc4(root, rel)
    if spec and sha(data) == spec['candidate_sha256']:
        return exact_candidate_to_rc3(root, rel)
    return data


def check(root):
    f = fixture()
    for rel in f['changed_files']:
        exact_candidate_to_rc3(root, rel)
    actual = set()
    for top in f['protected_roots']:
        for path in (root / top).rglob('*'):
            if path.is_file() and '__pycache__' not in path.parts and path.suffix not in ('.pyc', '.pyo'):
                assert not path.is_symlink(), 'Unexpected RC4 source symlink'
                actual.add(path.relative_to(root).as_posix())
    expected = set(f['changed_files']) | set(f['unchanged_files'])
    assert actual == expected, 'RC4 runtime/helper file inventory changed'
    for rel, expected_hash in f['unchanged_files'].items():
        assert sha(normalized_rc4(root, rel)) == expected_hash, 'Changed protected RC4 file: ' + rel
    print('PASS exact RC4 scope: Unrestricted manual admission/cleanup and valid-mode manual cancellation; '
          'eight version labels and one CET help string; '
          + str(len(f['unchanged_files'])) + ' complete runtime/helper files unchanged; '
          + str(len(actual)) + ' exact protected paths. Source identity only.')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
