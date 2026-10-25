#!/usr/bin/env python3
"""Actual pure-Lua scheduler checks and intended-failure mutation controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--module',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--lua',default=shutil.which('texlua') or 'texlua')
p.add_argument('--lua-arg',action='append',default=[])
a=p.parse_args()
source=a.module.read_text();a.output.mkdir(parents=True,exist_ok=True)
test=Path(__file__).parent/'test_apartment_policy.lua'
def run(path):
    r=subprocess.run([a.lua,*a.lua_arg,str(test),str(path)],text=True,capture_output=True,timeout=30)
    return {'exit_code':r.returncode,'output':r.stdout+r.stderr}
positive=run(a.module)
controls=[
 ('ignore_optin','local apartmentEntered=state.options.apartmentEntry and','local apartmentEntered=','disabled apartment option creates no entry request'),
 ('ignore_outside_baseline','state.baseline.apartment==false and snapshot.apartmentInside==true','snapshot.apartmentInside==true','initial inside observation creates no request'),
 ('ignore_unknown_location','if options.apartmentEntry and (snapshot.apartmentKnown~=true or not boolean(snapshot.apartmentInside)) then','if false and (snapshot.apartmentKnown~=true or not boolean(snapshot.apartmentInside)) then','unknown apartment data cancels captured event'),
 ('retain_work_after_exit',"if state.pending and state.pending.reason=='apartment_entry' and snapshot.apartmentInside~=true then",'if false then','leaving before readiness cancels apartment work'),
 ('ignore_cooldown','if not state.pending and state.cooldownRemaining<=0 then','if not state.pending then','shared cooldown wins'),
 ('ignore_session_change','if state.session~=snapshot.session or not state.baseline then','if not state.baseline then','readiness interruption clears apartment event'),
 ('ignore_master_off','if not state.options.enabled then','if false then','master off suppresses apartment trigger'),
 ('ignore_stabilization','if not snapshot.nativeUnlocked or not snapshot.stableReady then','if not snapshot.nativeUnlocked then','entry does not bypass stabilization'),
]
negative=[]
with tempfile.TemporaryDirectory(prefix='nlsr-apartment-controls-') as tmp:
    for name,before,after,needle in controls:
        assert source.count(before)==1,'Control seam is not unique: '+name
        path=Path(tmp)/(name+'.lua');path.write_text(source.replace(before,after))
        result=run(path)
        negative.append({'name':name,**result,'detected_for_intended_reason':result['exit_code']!=0 and needle in result['output']})
result={'scope':'Actual Lua5.3 scheduler and doubled game observations; no game/save evidence',
        'module_sha256':hashlib.sha256(a.module.read_bytes()).hexdigest(),
        'positive':positive,'negative_controls':negative,
        'passed':positive['exit_code']==0 and all(x['detected_for_intended_reason'] for x in negative)}
(a.output/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
raise SystemExit(0 if result['passed'] else 1)
