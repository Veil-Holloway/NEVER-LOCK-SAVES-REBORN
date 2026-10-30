#!/usr/bin/env python3
"""Canonical current-release offline checks. No game launch or save-file access."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from lua_test_host import lua_command

HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--release',type=Path,default=HERE.parents[2])
p.add_argument('--output',type=Path,required=True)
host=p.add_mutually_exclusive_group();host.add_argument('--lua');host.add_argument('--lupa',action='store_true')
a=p.parse_args();root=a.release.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
lua=[sys.executable,str(HERE/'lupa_host.py')]if a.lupa else [a.lua]if a.lua else lua_command()
env=os.environ.copy();env['NLSR_LUA_COMMAND']=json.dumps(lua)
plan=json.loads((HERE/'RELEASE-TEST-PLAN.json').read_text())
names=[c['check']for c in plan['checks']]
if len(names)!=len(set(names)):raise SystemExit('Duplicate check names')
rows=[]
with tempfile.TemporaryDirectory(prefix='nlsr-release-checks-')as disk:
    values={'root':str(root),'output':str(out),'validation':str(HERE),'fixture':disk,'python':sys.executable}
    for case in plan['checks']:
        cmd=[]
        for token in case['command']:
            if token=='{lua}':
                if cmd and cmd[-1]=='--lua':cmd.extend([lua[0],*['--lua-arg='+value for value in lua[1:]]])
                else:cmd.extend(lua)
            elif token=='{runtime_lua}':
                cmd.extend(str(f)for f in sorted((root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn').glob('*.lua')))
            else:cmd.append(token.format(**values))
        try:
            result=subprocess.run(cmd,env=env,text=True,capture_output=True,timeout=300)
            text=result.stdout+result.stderr;code=result.returncode
        except subprocess.TimeoutExpired as exc:text='TIMEOUT: '+str(exc);code=124
        (out/(case['check']+'.log')).write_text(text,encoding='utf-8')
        rows.append({'check':case['check'],'exit_code':code,'command':cmd,'log':case['check']+'.log'})
        print(('PASS 'if code==0 else 'FAIL ')+case['check'],flush=True)
summary={'release':plan['release'],'scope':plan['scope'],'lua_command':lua,'results':rows,
    'passed':all(row['exit_code']==0 for row in rows),'retired_checks':plan['retired_checks']}
(out/'RESULTS.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
sys.exit(not summary['passed'])
