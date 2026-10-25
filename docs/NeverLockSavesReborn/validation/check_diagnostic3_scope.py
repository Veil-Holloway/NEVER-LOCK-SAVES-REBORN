#!/usr/bin/env python3
"""Exact source preservation across the diagnostic.3 observer startup repair."""
from pathlib import Path
import hashlib
import json
import sys

FIXTURE = Path(__file__).parent / 'fixtures/diagnostic3_scope.json'

def fixture():
    return json.loads(FIXTURE.read_text())

def sha(data):
    return hashlib.sha256(data).hexdigest()

def normalized_diagnostic2(root, rel):
    data = (root / rel).read_bytes()
    spec = fixture()['changed_files'].get(rel)
    if not spec or sha(data) != spec['candidate_sha256']:
        return data
    lines = data.decode().splitlines(keepends=True)
    for splice in reversed(spec['splices']):
        start, end = splice['candidate_start_line'], splice['candidate_end_line']
        assert ''.join(lines[start:end]) == splice['after'], 'Diagnostic.3 splice mismatch'
        lines[start:end] = splice['before'].splitlines(keepends=True)
    result = ''.join(lines).encode()
    assert sha(result) == spec['baseline_sha256'], 'Diagnostic.2 recovery mismatch'
    return result

def normalize_reviewed_files(root):
    for rel in fixture()['changed_files']:
        path = root / rel
        if path.is_file():
            path.write_bytes(normalized_diagnostic2(root, rel))

def check(root):
    f = fixture()
    actual = {p.relative_to(root).as_posix() for top in f['protected_roots']
              for p in (root / top).rglob('*')
              if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.pyc', '.pyo')}
    assert actual == set(f['changed_files']) | set(f['unchanged_files']), 'Diagnostic.3 inventory changed'
    for rel, spec in f['changed_files'].items():
        assert sha((root / rel).read_bytes()) == spec['candidate_sha256'], 'Unreviewed diagnostic.3 file: ' + rel
        assert sha(normalized_diagnostic2(root, rel)) == spec['baseline_sha256']
    for rel, expected in f['unchanged_files'].items():
        assert sha((root / rel).read_bytes()) == expected, 'Unrelated protected file changed: ' + rel
    print('PASS exact diagnostic.3 scope: three late-bound observer bindings, labels and auditor pins; no save-policy change.')

if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
