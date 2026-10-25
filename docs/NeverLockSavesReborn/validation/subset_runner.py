#!/usr/bin/env python3
"""Save invariants and actual-source routing checks in a constrained subset.

The subset runner translates only the declarations, assignments, calls, if/else
and returns used by these helpers/hooks. External game/framework boundaries are
doubles. It is not REDscript compilation, game execution, or save-file evidence.
"""
from __future__ import annotations

import argparse
import itertools
import re
import sys
from pathlib import Path
from types import SimpleNamespace as Object

MAIN = Path('r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds')
HOOKS = ('HandlePressToSaveGame', 'HandlePressToQuickSaveGame', 'HandleQuickSave')
PRESERVED = ('ShuffleSlot', 'CheckpointMessage', 'IsProtectedIntroduction', 'AllowForcedCheckpointFallback')
ADDED = ('NLSRebornSetDFNotifications', 'NLSRebornGetDFNotificationMask', 'NLSRebornGetDFPolicyStatus',
         'NLSRebornGetDFNotificationContext', 'GetImmersionSaveContext', 'NotifyImmersionSaveRequest')
LEXER = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/|&&|\|\||==|!=|<=|>=|\+=|\w+|[^\s]', re.S)


def lex(source):
    return [m.group() for m in LEXER.finditer(source) if not m.group().startswith(('//', '/*'))]


def function_range(source, name):
    match = re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', source)
    if match is None:
        raise ValueError('missing function: ' + name)
    depth = 0
    for token in LEXER.finditer(source, source.index('{', match.end())):
        if token.group() == '{':
            depth += 1
        elif token.group() == '}':
            depth -= 1
            if depth == 0:
                return match.start(), token.end()
    raise ValueError('unclosed function: ' + name)


def body(source, name):
    start, end = function_range(source, name)
    return source[start:end]


def compile_subset(source, name, namespace, *, instance=False):
    function = body(source, name)
    params = function[function.index('(') + 1:function.index(')')]
    args = re.findall(r'(\w+)\s*:', params)
    if instance:
        args.insert(0, 'this')
    lines = ['def actual_' + name + '(' + ', '.join(args) + '):']
    depth = 1
    pending = []

    def expression(parts):
        result = []
        for index, part in enumerate(parts):
            if part == 'as':
                if parts[index + 1:] != ['PlayerPuppet']:
                    raise ValueError('unsupported cast in ' + name)
                break  # Game types have no meaning in the external boundary doubles.
            # Audit helpers use Int32 operands; preserve REDscript integer division.
            result.append({'true': 'True', 'false': 'False', '&&': 'and', '||': 'or', '!': 'not', '/': '//'}.get(part, part))
        return ' '.join(result)

    def statement(parts):
        if not parts:
            return
        if parts[0] == 'let':
            if len(parts) < 4 or parts[2] != ':':
                raise ValueError('unsupported declaration in ' + name)
            rhs = expression(parts[parts.index('=') + 1:]) if '=' in parts else 'None'
            value = parts[1] + ' = ' + rhs
        elif parts[0] == 'return':
            value = 'return ' + expression(parts[1:])
        else:
            value = expression(parts)
        lines.append('    ' * depth + value)

    content = function[function.index('{') + 1:function.rfind('}')]
    for token in lex(content):
        if token == '{':
            if pending[:1] == ['if']:
                header = 'if ' + expression(pending[1:]) + ':'
            elif pending[:2] == ['else', 'if']:
                header = 'elif ' + expression(pending[2:]) + ':'
            elif pending == ['else']:
                header = 'else:'
            else:
                raise ValueError('unsupported block in ' + name + ': ' + repr(pending))
            lines.append('    ' * depth + header)
            pending = []
            depth += 1
        elif token == '}':
            statement(pending)
            pending = []
            depth -= 1
            if depth < 1:
                raise ValueError('unbalanced blocks in ' + name)
        elif token == ';':
            statement(pending)
            pending = []
        else:
            pending.append(token)
    statement(pending)
    if depth != 1:
        raise ValueError('unclosed block in ' + name)
    code = '\n'.join(lines) + '\n'
    exec(compile(code, '<actual REDscript constrained subset: ' + name + '>', 'exec'), namespace)
    return namespace['actual_' + name]

