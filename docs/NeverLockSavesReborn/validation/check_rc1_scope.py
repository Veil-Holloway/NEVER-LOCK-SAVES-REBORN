#!/usr/bin/env python3
"""RC1 label-only preservation against the exact authenticated preRC4 payload.

Byte identity is evidence about source scope, not gameplay or compatibility.
The original preRC4->preRC3 and preRC3->preRC2 guards remain in force.
"""
from pathlib import Path
from check_rc2_scope import normalized_rc1
import hashlib
import json
import sys

FIXTURE = Path(__file__).parent / 'fixtures/rc1_scope.json'


def fixture():
    return json.loads(FIXTURE.read_text())


def sha(value):
    return hashlib.sha256(value).hexdigest()


def normalized_pre_rc4(root, rel, require_candidate=False):
    """Normalize only the two reviewed labels; require exact pinned source."""
    f = fixture()
    spec = f['label_files'][rel]
    data = normalized_rc1(root, rel)
    before = f['baseline_version'].encode()
    after = f['candidate_version'].encode()
    title_before = f['baseline_title'].encode()
    title_after = f['candidate_title'].encode()
    if not require_candidate and sha(data) == spec['baseline_sha256']:
        return data
    assert data.count(after) == spec['version_count'], 'Unexpected RC1 version count: ' + rel
    assert data.count(before) == 0, 'Mixed preview/candidate versions: ' + rel
    assert data.count(title_after) == spec['title_count'], 'Unexpected RC1 title count: ' + rel
    assert data.count(title_before) == 0, 'Mixed preview/candidate titles: ' + rel
    assert sha(data) == spec['candidate_sha256'], 'RC1 source differs from frozen labels: ' + rel
    data = data.replace(after, before).replace(title_after, title_before)
    assert sha(data) == spec['baseline_sha256'], 'Unrelated runtime source changed: ' + rel
    return data


def check(root):
    f = fixture()
    for rel in f['label_files']:
        normalized_pre_rc4(root, rel, require_candidate=True)
    actual = set()
    # New support/audit tools are frozen separately; preserve the entire old companion.
    for top in f['protected_roots']:
        for p in (root / top).rglob('*'):
            if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.pyc', '.pyo'):
                assert not p.is_symlink(), 'Unexpected source symlink'
                actual.add(p.relative_to(root).as_posix())
    expected = set(f['label_files']) | set(f['unchanged_files'])
    assert actual == expected, 'Runtime/helper file inventory changed'
    for rel, expected_hash in f['unchanged_files'].items():
        assert sha((root / rel).read_bytes()) == expected_hash, 'Changed protected RC1 file: ' + rel
    print('PASS RC1 source freeze: eight version labels and five adjacent titles only; '
          + str(len(f['unchanged_files'])) + ' whole runtime/helper files unchanged; '
          + str(len(actual)) + ' exact source/helper paths. Source identity only.')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
