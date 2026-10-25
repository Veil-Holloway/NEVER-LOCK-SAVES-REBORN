#!/usr/bin/env python3
"""Independent actual-init/real-disk regression plus three call-site mutation controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
REL = Path('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')
MUTATIONS = (
    ('load-validator-omitted', 'pcall(configStore.load, file, validateMainSettings)',
     'pcall(configStore.load, file)', 'NLSR-MAIN-CONFIG-RECOVERY'),
    ('save-validator-omitted', 'configStore.save(file,currentSettings(),validateMainSettings)',
     'configStore.save(file,currentSettings())', 'saveConfig must pass the same validator'),
    ('preset-validator-omitted', 'pcall(configStore.save,file,settings,validateMainSettings)',
     'pcall(configStore.save,file,settings)', 'preset application must use same main validator'),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--lua', required=True)
    parser.add_argument('--lua-arg', action='append', default=[])
    args = parser.parse_args()
    release, output = args.release.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    test = HERE / 'test_main_config_runtime.lua'
    source = (release / REL / 'init.lua').read_bytes()
    command = [args.lua, *args.lua_arg, str(test)]
    rows = []
    with tempfile.TemporaryDirectory(prefix='nlsr-main-independent-') as tmp:
        disk = Path(tmp) / 'disk'
        disk.mkdir()
        result = subprocess.run(command + [str(release), str(disk)], text=True, capture_output=True, timeout=60)
        combined = result.stdout + result.stderr
        (output / 'runtime.log').write_text(combined)
        passed = result.returncode == 0 and 'PASS independent main-config runtime:' in combined
        rows.append({'case': 'actual_init_real_disk', 'exit_code': result.returncode, 'passed': passed, 'log': 'runtime.log'})
        print(('PASS' if passed else 'FAIL') + ' actual_init_real_disk')
    for name, before, after, expected in MUTATIONS:
        if source.count(before.encode()) != 1:
            raise RuntimeError('mutation seam missing or ambiguous: ' + name)
        with tempfile.TemporaryDirectory(prefix='nlsr-main-mutant-') as tmp:
            root = Path(tmp)
            mod = root / 'release' / REL
            mod.mkdir(parents=True)
            for file in (release / REL).glob('*.lua'):
                shutil.copyfile(file, mod / file.name)
            (mod / 'init.lua').write_bytes(source.replace(before.encode(), after.encode()))
            disk = root / 'disk'
            disk.mkdir()
            result = subprocess.run(command + [str(root / 'release'), str(disk)], text=True, capture_output=True, timeout=60)
            combined = result.stdout + result.stderr
            (output / (name + '.log')).write_text(combined)
            passed = result.returncode != 0 and expected in combined
            rows.append({'case': name, 'exit_code': result.returncode, 'passed': passed,
                         'intended_assertion': expected, 'log': name + '.log'})
            print(('PASS' if passed else 'FAIL') + ' mutation_control ' + name)
    record = {'scope': 'Actual init/config_store and real temporary files; doubled CET/Game/UI/JSON only. Lua5.3 host, not real game or Windows.',
              'init_sha256': hashlib.sha256(source).hexdigest(),
              'test_sha256': hashlib.sha256(test.read_bytes()).hexdigest(),
              'results': rows, 'passed': all(row['passed'] for row in rows)}
    (output / 'RESULTS.json').write_text(json.dumps(record, indent=2) + '\n')
    return 0 if record['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
