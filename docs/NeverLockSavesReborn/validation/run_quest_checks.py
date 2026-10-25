#!/usr/bin/env python3
"""Execute the actual Lua module plus focused negative controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument('--module', type=Path, default=here / 'quest_milestones.lua')
    parser.add_argument('--output', type=Path, default=here / 'checks')
    parser.add_argument('--lua', default=shutil.which('texlua') or 'texlua')
    parser.add_argument('--lua-arg', action='append', default=[])
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    module = args.module.resolve()
    test = here / 'test_quest_milestones.lua'
    source = module.read_text()

    def run(path):
        result = subprocess.run([args.lua, *args.lua_arg, str(test), str(path)], text=True,
                                capture_output=True, timeout=30)
        return {'exit_code': result.returncode, 'stdout': result.stdout,
                'stderr': result.stderr}

    positive = run(module)
    mutations = {
        'cross_session_event_transfer':
            ('if event.session~=current then', 'if false then'),
        'accept_incomplete_entry':
            ('evidence.succeeded==true and evidence.kind==CLASSES[event.className]',
             'true and evidence.kind==CLASSES[event.className]'),
        'disable_deduplication':
            ('elseif seen[event.hash] then', 'elseif false then'),
        'allow_buffer_overflow':
            ('if count>=CAPACITY then', 'if count>CAPACITY then'),
        'forget_dedup_on_interrupt':
            ('buffer={};count=0;overflow=false;currentSession=0;armed=false',
             'buffer={};count=0;overflow=false;currentSession=0;armed=false;seen={};seenCount=0;dedupSession=0'),
        'trust_callback_class_without_actual_type':
            ('evidence.kind==CLASSES[event.className]', 'true'),
        'publish_after_reentrant_clear':
            ('if epoch~=drainEpoch or not stillEnabled then', 'if not stillEnabled then'),
        'publish_after_mid_resolution_disable':
            ('if epoch~=drainEpoch or not stillEnabled then', 'if epoch~=drainEpoch then'),
    }
    controls = {}
    with tempfile.TemporaryDirectory(prefix='nlsr-quest-controls-') as temporary:
        for name, (old, new) in mutations.items():
            if source.count(old) != 1:
                raise RuntimeError(f'Control target is not unique: {name}')
            path = Path(temporary) / (name + '.lua')
            path.write_text(source.replace(old, new))
            controls[name] = run(path)
            controls[name]['detected'] = controls[name]['exit_code'] != 0
    report = {
        'scope': 'Lua 5.3 module execution; CET/game and REDscript unverified',
        'module_sha256': hashlib.sha256(module.read_bytes()).hexdigest(),
        'test_sha256': hashlib.sha256(test.read_bytes()).hexdigest(),
        'positive': positive,
        'negative_controls': controls,
        'passed': positive['exit_code'] == 0 and all(x['detected'] for x in controls.values()),
    }
    (args.output / 'RESULTS.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
