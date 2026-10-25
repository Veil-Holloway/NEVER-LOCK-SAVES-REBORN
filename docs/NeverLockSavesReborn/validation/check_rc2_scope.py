#!/usr/bin/env python3
"""Exact RC1 preservation outside the reported autosave type and RC2 labels.

This is a byte-identity/source-contract check, not a REDscript compilation.
Only complete pinned RC3/RC2 files may be normalized for earlier preservation guards.
The RC3 adapter first proves exact reviewed Smart routing and recovers pinned RC2 bytes.
"""
from pathlib import Path
from check_vehicle_diag_scope import normalized_rc4
from check_rc3_scope import normalized_rc2
import hashlib
import json
import sys

FIXTURE = Path(__file__).parent / 'fixtures/rc2_scope.json'


def fixture():
    return json.loads(FIXTURE.read_text())


def sha(value):
    return hashlib.sha256(value).hexdigest()


def exact_candidate_to_rc1(root, rel):
    f = fixture()
    spec = f['label_files'][rel]
    data = normalized_rc2(root, rel)
    old = f['baseline_version'].encode()
    new = f['candidate_version'].encode()
    assert data.count(new) == spec['version_count'], 'Unexpected RC2 version count: ' + rel
    assert data.count(old) == 0, 'Mixed RC1/RC2 labels: ' + rel
    replacement = f['annotation_replacement']
    if rel == replacement['path']:
        assert data.count(replacement['after'].encode()) == replacement['count'], 'Verified autosave type declaration missing'
        assert data.count(replacement['before'].encode()) == 0, 'Unresolved autosave type declaration retained'
    assert sha(data) == spec['candidate_sha256'], 'RC2 source differs outside exact type/labels: ' + rel
    data = data.replace(new, old)
    if rel == replacement['path']:
        data = data.replace(replacement['after'].encode(), replacement['before'].encode())
    assert sha(data) == spec['baseline_sha256'], 'Unrelated RC1 runtime source changed: ' + rel
    return data


def normalized_rc1(root, rel):
    """Adapt exact reviewed RC2 files only; all other bytes reach the old guard."""
    f = fixture()
    data = normalized_rc2(root, rel)
    if sha(data) == f['label_files'][rel]['candidate_sha256']:
        return exact_candidate_to_rc1(root, rel)
    return data


def check(root):
    f = fixture()
    for rel in f['label_files']:
        exact_candidate_to_rc1(root, rel)
    actual = set()
    for top in f['protected_roots']:
        for p in (root / top).rglob('*'):
            if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.pyc', '.pyo'):
                assert not p.is_symlink(), 'Unexpected source symlink'
                actual.add(p.relative_to(root).as_posix())
    expected = set(f['label_files']) | set(f['unchanged_files'])
    assert actual == expected, 'RC2 runtime/helper file inventory changed'
    for rel, expected_hash in f['unchanged_files'].items():
        assert sha(normalized_rc4(root, rel)) == expected_hash, 'Changed protected RC2 file: ' + rel
    print('PASS exact RC1 preservation: one autosave type annotation and eight version labels only; '
          + str(len(f['unchanged_files'])) + ' whole runtime/helper files unchanged; '
          + str(len(actual)) + ' exact protected paths. Source identity only.')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
