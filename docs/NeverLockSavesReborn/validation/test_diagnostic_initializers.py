#!/usr/bin/env python3
"""Regression for compiler-rejected negative field defaults and unknown readers.

Inspects current runtime REDscript member declarations and executes the actual
diagnostic getters through the existing strict bounded evaluator. This is source
contract/boundary evidence, NOT native REDscript compilation or gameplay proof.
Mutation controls run only in memory and never modify the release source.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
from types import SimpleNamespace


MAIN = 'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds'
STATES = ('Combat', 'Mounted')
MEMBER = re.compile(
    r'(?:@addField\s*\([^)]*\)\s*(?:(?:public|private|protected|persistent|native|static)\s+)*'
    r'|(?:public|private|protected)\s+(?:(?:persistent|native|static)\s+)*)'
    r'let\s+(?P<name>\w+)\s*:\s*[^;={}]+?\s*=\s*(?P<value>[^;]+);')
COMMENTS = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/', re.S)


def load_subset(release):
    path = release / 'docs/NeverLockSavesReborn/validation/source_subset.py'
    spec = importlib.util.spec_from_file_location('diagnostic_initializer_subset', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def without_comments(source):
    return COMMENTS.sub(lambda match: match.group() if match.group().startswith('"') else ' ', source)


def verify(sources, subset):
    assertions = 0
    failures, errors = [], []

    def check(label, condition, detail):
        nonlocal assertions
        assertions += 1
        if not condition:
            failures.append(dict(label=label, detail=detail))

    # A leading unary minus is an expression in the affected compiler, rather
    # than the literal accepted for member defaults. Local assignments and
    # ordinary runtime returns of -1 are deliberately outside this check.
    for path, source in sorted(sources.items()):
        for member in MEMBER.finditer(without_comments(source)):
            value = member.group('value').strip()
            negative = bool(re.match(r'^\(*\s*-', value))
            check('field-default constant compatibility', not negative,
                  dict(file=path, field=member.group('name'), value=value))

    source = sources[MAIN]
    for suffix in STATES:
        name = 'NLSRebornCheckpointGet' + suffix
        field = 'nlsCheckpoint' + suffix
        try:
            getter = subset.compile_function(source, name, {'__builtins__': {}}, instance=True)
        except Exception as exc:
            errors.append(dict(getter=name, error=type(exc).__name__ + ': ' + str(exc)))
            continue
        for serial in (0, 1, 2147483647):
            for stored in (-1, 0, 1):
                player = SimpleNamespace(nlsCheckpointSerial=serial, **{field: stored})
                before = dict(vars(player))
                detail = dict(getter=name, serial=serial, backing_value=stored)
                try:
                    actual = getter(player)
                except Exception as exc:
                    errors.append(dict(**detail, error=type(exc).__name__ + ': ' + str(exc)))
                    continue
                expected = -1 if serial == 0 else stored
                label = 'no attempt stays unknown' if serial == 0 else 'attempt observation preserved'
                check(label, type(actual) is int and actual == expected,
                      dict(**detail, actual=actual, expected=expected))
                check('diagnostic getter is read-only', vars(player) == before, detail)
    return dict(assertions=assertions, failed=len(failures), boundary_errors=len(errors),
                failures=failures, errors=errors,
                passed=not failures and not errors)


def controls(sources, subset):
    source = sources[MAIN]
    outcomes = []
    for suffix in STATES:
        field = 'nlsCheckpoint' + suffix
        declaration = re.compile(
            r'(@addField\(PlayerPuppet\)\s+private\s+let\s+' + field +
            r'\s*:\s*Int32)(?:\s*=\s*[^;]+)?\s*;')
        mutant, count = declaration.subn(r'\g<1> = -1;', source)
        if count != 1:
            raise ValueError('Expected unique field mutation anchor: ' + field)
        variants = dict(sources, **{MAIN: mutant})
        result = verify(variants, subset)
        detected = any(row['label'] == 'field-default constant compatibility' and
                       row['detail']['field'] == field for row in result['failures'])
        outcomes.append(dict(name='restore_negative_default_' + suffix.lower(),
                             detected_for_intended_reason=detected and not result['boundary_errors'],
                             failed=result['failed'], boundary_errors=result['boundary_errors']))

        name = 'NLSRebornCheckpointGet' + suffix
        body = subset.body(source, name)
        guard = re.compile(r'if\s+this\.nlsCheckpointSerial\s*==\s*0\s*\{\s*return\s+-1\s*;\s*\}\s*;?')
        changed_body, count = guard.subn('', body)
        if count != 1:
            raise ValueError('Expected unique no-attempt guard mutation anchor: ' + name)
        variants = dict(sources, **{MAIN: source.replace(body, changed_body, 1)})
        result = verify(variants, subset)
        detected = any(row['label'] == 'no attempt stays unknown' and
                       row['detail']['getter'] == name for row in result['failures'])
        outcomes.append(dict(name='remove_serial_guard_' + suffix.lower(),
                             detected_for_intended_reason=detected and not result['boundary_errors'],
                             failed=result['failed'], boundary_errors=result['boundary_errors']))
    return outcomes


def evaluate(release, expect_gap=False):
    paths = sorted((release / 'r6/scripts/NeverLockSavesReborn').rglob('*.reds'))
    if not paths:
        raise ValueError('Runtime REDscript sources are missing')
    raw = {path.relative_to(release).as_posix(): path.read_bytes() for path in paths}
    sources = {name: data.decode('utf-8') for name, data in raw.items()}
    subset = load_subset(release)
    result = verify(sources, subset)
    result.update(scope=__doc__.strip(), source_sha256={name: hashlib.sha256(data).hexdigest()
                                                    for name, data in raw.items()},
                  negative_control=expect_gap)
    if expect_gap:
        fields = {row['detail']['field'] for row in result['failures']
                  if row['label'] == 'field-default constant compatibility'}
        getters = {row['detail']['getter'] for row in result['failures']
                   if row['label'] == 'no attempt stays unknown'}
        result['expected_gap_detected'] = (
            {'nlsCheckpointCombat', 'nlsCheckpointMounted'} <= fields and
            {'NLSRebornCheckpointGetCombat', 'NLSRebornCheckpointGetMounted'} <= getters and
            not result['boundary_errors'])
        result['passed'] = result['expected_gap_detected']
    elif result['passed']:
        result['controls'] = controls(sources, subset)
        result['controls_detected'] = sum(row['detected_for_intended_reason'] for row in result['controls'])
        result['passed'] = result['controls_detected'] == len(result['controls']) == 4
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release', type=Path)
    parser.add_argument('--expect-gap', action='store_true',
                        help='Succeed only when both original field/default and fresh-reader defects are detected')
    args = parser.parse_args()
    report = evaluate(args.release.resolve(), args.expect_gap)
    print(json.dumps(report, indent=2))
    raise SystemExit(not report['passed'])
