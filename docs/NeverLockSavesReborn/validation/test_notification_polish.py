"""Fresh actual-source presentation checks; external game/UI boundaries doubled."""
from pathlib import Path
import ast,re,sys,json
from types import SimpleNamespace as Obj
import subset_runner as subset
r=Path(sys.argv[1]);before=Path(sys.argv[2]) if len(sys.argv)>2 else None
core=(r/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds').read_text()
df=(r/'r6/scripts/NeverLockSavesReborn/DarkFutureMessages.reds').read_text()
m=r/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn'
checks=0
def check(v,label):
 global checks
 checks+=1;assert v,label
def funcs(s):
 result={}
 for match in re.finditer(r'(?m)^\s*(?:public|private|protected) (?:static |final )?func (\w+)\([^\n]*?\{',s):
  i=match.end();depth=1;quoted=False;escaped=False
  while depth:
   c=s[i];i+=1
   if quoted:
    if escaped:escaped=False
    elif c=='\\':escaped=True
    elif c=='"':quoted=False
   elif c=='"':quoted=True
   elif c=='{':depth+=1
   elif c=='}':depth-=1
  result[match[1]]=s[match.start():i].strip()
 return result
fixture=json.loads(Path(__file__).with_name('fixtures').joinpath('neutral-source-baseline.json').read_text()) if before is None else None
f=funcs(core);old=fixture['core_methods'] if fixture else funcs((before/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds').read_text())
allowed={'NLSRebornCheckpointFailure','NLSRebornDeferredDispatch','CheckpointMessage','NotifyImmersionSaveRequest','HandleSmartBlockedSave','Version'}
check(set(f)-set(old)=={'NLSRebornCompletionNotify'},'only completion presentation method added')
check(set(old)-set(f)==set(),'no previous method removed')
changed={k for k in old if old[k]!=f[k]};check(changed==allowed,'only expected notification methods changed: '+str(changed))
import hashlib
expected=fixture['runtime_files'] if fixture else {p.relative_to(before).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['bin','r6'] for p in (before/folder).rglob('*') if p.is_file()}
for relative,digest in expected.items():
 if Path(relative).name not in {'init.lua','status_messages.lua','status_message_library.lua','NeverLockSavesReborn.reds','DarkFutureMessages.reds','settings_ui.lua','overlay_ui.lua'}:
  check(hashlib.sha256((r/relative).read_bytes()).hexdigest()==digest,'unchanged policy/module '+relative)
strings=[]
for name in ['CheckpointMessage','NLSRebornCheckpointFailure','HandleSmartBlockedSave','NLSRebornShowActivation','NLSRebornCompletionNotify']:
 strings+=re.findall(r'"(?:\\.|[^"\\])*"',f[name])
strings+=re.findall(r'"(?:\\.|[^"\\])*"',df)
library=(m/'status_message_library.lua').read_text();strings+=re.findall(r'"(?:\\.|[^"\\])*"',library.split('function M.get')[0])
for literal in strings:
 text=json.loads(literal)
 check(not any(c in text for c in '()[]{}'),'no bracketed notification text: '+text)
 check(not re.search(r'\b(native|checkpoint|dispatch|callback|serialization|unconfirmed|lifecycle|evidence|bridge)\b',text,re.I),'plain-language notification: '+text)
check('(Request accepted' not in core,'developer suffix removed at all call sites')
emitted=[];enabled=True;ui=object();game=object()
ns={'IsDefined':lambda x:x is not None,'Equals':lambda a,b:a==b,
 'GameInstance':Obj(GetUISystem=lambda g:ui),'PauseMenuGameController':Obj(NLSRebornNotify=lambda g,t:emitted.append(t))}
player=Obj(GetGame=lambda:game,NLSRebornGetNotificationsEnabled=lambda:enabled)
notify=subset.compile_subset(core,'NLSRebornCompletionNotify',ns,instance=True)
for success,text in [(True,'Game saved.'),(False,'Could not save the game.')]:
 check(notify(player,success) is True,'UI bridge accepts completion notice')
 check(emitted[-1]==text,'exact completion text')
enabled=False;count=len(emitted);check(notify(player,True) is False and len(emitted)==count,'master OFF suppresses actual REDscript notice')
enabled=True;ui=None;check(notify(player,True) is False and len(emitted)==count,'missing UI stays silent')
print(json.dumps({'result':'PASS','assertions':checks,'core_method_changes':sorted(changed),'unchanged_core_methods':len(old)-len(changed),'notification_strings_checked':len(strings),'scope':'constrained actual REDscript source and exact policy-byte comparison; not live compilation'},indent=2))
