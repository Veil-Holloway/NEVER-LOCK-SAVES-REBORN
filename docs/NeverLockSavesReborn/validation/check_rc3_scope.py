#!/usr/bin/env python3
"""Exact RC2 preservation outside reviewed Smart blocked-request routing and labels.

This proves byte identity only. Exact RC4 is first recovered to pinned RC3 bytes.
Normalization requires a complete pinned RC3 file,
then reconstructs and hashes the pinned RC2 source. It is not a compiler/runtime.
"""
from pathlib import Path
from check_rc4_scope import normalized_rc3
import hashlib
import json
import sys

FIXTURE = Path(__file__).parent / 'fixtures/rc3_scope.json'


def fixture():
    return json.loads(FIXTURE.read_text())


def sha(value):
    return hashlib.sha256(value).hexdigest()


def exact_candidate_to_rc2(root, rel):
    spec = fixture()['changed_files'][rel]
    data = normalized_rc3(root, rel)
    assert sha(data) == spec['candidate_sha256'], 'RC3 source differs outside reviewed Smart routing/labels: ' + rel
    lines = data.decode('utf-8').splitlines(keepends=True)
    for splice in reversed(spec['splices']):
        start, end = splice['candidate_start_line'], splice['candidate_end_line']
        assert ''.join(lines[start:end]) == splice['after'], 'RC3 approved splice mismatch: ' + rel
        lines[start:end] = splice['before'].splitlines(keepends=True)
    baseline = ''.join(lines).encode('utf-8')
    assert sha(baseline) == spec['baseline_sha256'], 'Unrelated RC2 bytes changed: ' + rel
    return baseline


def normalized_rc2(root, rel):
    """Only a complete exact RC3 source is adapted; mutations reach prior guards."""
    spec = fixture()['changed_files'].get(rel)
    data = normalized_rc3(root, rel)
    if spec and sha(data) == spec['candidate_sha256']:
        return exact_candidate_to_rc2(root, rel)
    return data


def check(root):
    f = fixture()
    for rel in f['changed_files']:
        exact_candidate_to_rc2(root, rel)
    actual = set()
    for top in f['protected_roots']:
        for path in (root / top).rglob('*'):
            if path.is_file() and '__pycache__' not in path.parts and path.suffix not in ('.pyc', '.pyo'):
                assert not path.is_symlink(), 'Unexpected RC3 source symlink'
                actual.add(path.relative_to(root).as_posix())
    expected = set(f['changed_files']) | set(f['unchanged_files'])
    assert actual == expected, 'RC3 runtime/helper file inventory changed'
    for rel, expected_hash in f['unchanged_files'].items():
        assert sha((root / rel).read_bytes()) == expected_hash, 'Changed protected RC3 file: ' + rel
    print('PASS exact RC3 scope: one Smart request helper, three guarded call sites and eight version labels; '
          + str(len(f['unchanged_files'])) + ' complete runtime/helper files unchanged; '
          + str(len(actual)) + ' exact paths. Source identity only.')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
