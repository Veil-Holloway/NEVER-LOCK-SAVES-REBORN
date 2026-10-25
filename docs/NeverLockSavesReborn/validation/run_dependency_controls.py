#!/usr/bin/env python3
"""Focused author module/report checks plus intended-failure mutation controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
MUTANTS=(
 ('cet-prefix-omitted','dependency_versions.lua',"if value:sub(1,1)=='v' then value=value:sub(2) end",'if false then value=value:sub(2) end','collector','CET optional prefix and git suffix'),
 ('unsupported-reader-invoked','dependency_versions.lua','    if source then\n','    if source or key==\'redscript\' then\n','collector','unsupported readers never invoked'),
 ('reader-error-falsely-observed','dependency_versions.lua',"if not ok then status='read_failed'","if not ok then status='observed'",'collector','object error isolated'),
 ('native-string-accepted','dependency_versions.lua',"  if type(value)~='number' or value~=value", "  if type(value)=='string' then return safeVersion(value) end\n  if type(value)~='number' or value~=value",'collector','invalid numeric stripped'),
 ('native-upper-bound-omitted','dependency_versions.lua',' or value>1000000','', 'collector','invalid numeric stripped'),
 ('partial-version-text-accepted','dependency_versions.lua',"value:match('^%d+[A-Za-z0-9._+-]*$')","value:match('%d+[A-Za-z0-9._+-]*')",'collector','unsafe text stripped'),
 ('component-source-unchecked','support_report.lua','source==expected','true','report','bad component mapping'),
 ('observed-version-unchecked','support_report.lua'," or (status=='observed' and versions[key]=='unknown')",'', 'report','observed needs a valid corresponding version'),
 ('unsupported-api-observed','support_report.lua',"not expected and status=='not_supported'", "not expected and (status=='not_supported' or status=='observed')",'report','unsupported cannot become measured'),
)

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--module-dir',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True)
 p.add_argument('--lua',required=True)
 p.add_argument('--lua-arg',action='append',default=[])
 a=p.parse_args();module_dir=a.module_dir.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 def run(kind,root):
  script='test_dependency_versions.lua' if kind=='collector' else 'test_dependency_report.lua'
  target=root/'dependency_versions.lua' if kind=='collector' else root
  return subprocess.run([a.lua,*a.lua_arg,str(HERE/script),str(target)],text=True,capture_output=True,timeout=30)
 rows=[]
 for kind in ['collector','report']:
  r=run(kind,module_dir);text=r.stdout+r.stderr;(out/(kind+'.log')).write_text(text)
  marker='PASS dependency versions:' if kind=='collector' else 'PASS dependency report:'
  passed=r.returncode==0 and marker in text
  rows.append(dict(case=kind,exit_code=r.returncode,passed=passed,log=kind+'.log'))
  print(('PASS ' if passed else 'FAIL ')+kind)
 for name,file,before,after,kind,marker in MUTANTS:
  source=(module_dir/file).read_bytes()
  if source.count(before.encode())!=1:raise RuntimeError('Missing/ambiguous mutation seam: '+name)
  with tempfile.TemporaryDirectory(prefix='nlsr-dep-mutant-') as td:
   root=Path(td)
   for f in ['dependency_versions.lua','support_report.lua','profiles.lua']:shutil.copyfile(module_dir/f,root/f)
   (root/file).write_bytes(source.replace(before.encode(),after.encode()))
   r=run(kind,root);text=r.stdout+r.stderr;(out/(name+'.log')).write_text(text)
   passed=r.returncode!=0 and marker in text
   rows.append(dict(case=name,exit_code=r.returncode,passed=passed,intended_assertion=marker,log=name+'.log'))
   print(('PASS ' if passed else 'FAIL ')+'mutation '+name)
 record=dict(scope='Pure actual Lua collector/report, explicit callback boundaries; no game/CET/native ABI execution',module_hashes={f:hashlib.sha256((module_dir/f).read_bytes()).hexdigest() for f in ['dependency_versions.lua','support_report.lua']},results=rows,passed=all(row['passed'] for row in rows))
 (out/'RESULTS.json').write_text(json.dumps(record,indent=2)+'\n')
 return 0 if record['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
