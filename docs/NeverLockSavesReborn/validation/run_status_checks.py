#!/usr/bin/env python3
"""Pure final-source status checks plus deliberately weakened guard controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

here=Path(__file__).resolve().parent
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--module-dir',type=Path,default=here)
p.add_argument('--output',type=Path,default=here/'checks')
p.add_argument('--lua',default=shutil.which('texlua') or 'texlua')
p.add_argument('--lua-arg',action='append',default=[])
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
module=a.module_dir.resolve();test=here/'test_status_messages.lua'
source=(module/'status_messages.lua').read_text()
library=(module/'status_message_library.lua').read_bytes()
def run(path):
    r=subprocess.run([a.lua,*a.lua_arg,str(test),str(path)],capture_output=True,text=True,timeout=30)
    return {'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
positive=run(module)
controls=[
 ('disabled_intake',"if not enabled then return false,'disabled' end","if false then return false,'disabled' end",'disabled intake ignored'),
 ('truthy_emit','if not ok or value~=true then','if not ok then','rejected UI handoff'),
 ('advance_rng_on_failure','local index,nextBag,nextRng=choice(key)','local index,nextBag,nextRng=choice(key);rng=nextRng','failed emit never advances RNG'),
 ('cycle_boundary','if nextBag.order[1]==nextBag.last then','if false then','no adjacent repeat across cycle boundary'),
 ('duplicate_event','if not transitions[previous] or transitions[previous][kind]~=true then','if false then','same event deduplicated'),
 ('expired_event','if now-event.created>=TTL then','if false then','TTL exact boundary expires'),
 ('unthrottled_failures','if lastAttempt~=nil and now-lastAttempt<COOLDOWN then','if false then','failure attempts throttled'),
 ('capacity_priority','if worst and priority[kind]<priority[worst.kind] then','if false then','low-priority intake cannot displace full high-priority buffer'),
 ('cross_session','current~=session','false','other session cannot be adopted'),
 ('reentrant_commit','if epoch~=generation or not enabled or pending[event.serial]~=event or session~=event.session then','if false then','disable during emit prevents unpublished commit'),
 ('shared_body_progress',"local key=event.kind..'/'..tone..'/'..body","local key=event.kind..'/'..tone..'/0'",'body pool progress is independent'),
]
rows=[]
with tempfile.TemporaryDirectory(prefix='nlsr-status-controls-') as tmp:
    tmp=Path(tmp);(tmp/'status_message_library.lua').write_bytes(library)
    for name,before,after,expected in controls:
        assert source.count(before)==1,(name,'control seam must be unique')
        (tmp/'status_messages.lua').write_text(source.replace(before,after))
        result=run(tmp)
        result.update(name=name,detected_for_intended_reason=result['exit_code']!=0 and expected in result['stdout']+result['stderr'])
        rows.append(result)
report={'scope':'Pure Lua5.3 execution and boundary callbacks; no CET/game/save-file evidence',
        'source_sha256':{name:hashlib.sha256((module/name).read_bytes()).hexdigest() for name in ['status_messages.lua','status_message_library.lua']},
        'positive':positive,'negative_controls':rows,
        'passed':positive['exit_code']==0 and all(row['detected_for_intended_reason'] for row in rows)}
(a.output/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'positive_exit_code':positive['exit_code'],'positive_output':positive['stdout'].strip(),
                  'negative_controls_detected':sum(row['detected_for_intended_reason'] for row in rows),
                  'negative_controls':len(rows),'passed':report['passed']},indent=2))
raise SystemExit(0 if report['passed'] else 1)
