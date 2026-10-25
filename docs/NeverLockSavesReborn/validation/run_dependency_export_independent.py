#!/usr/bin/env python3
"""Independent actual-init export checks and four intended diagnostic mutation controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
MOD=Path('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')
MUTATIONS=(
 ('omit_versions_snapshot','init.lua',[(b'versions=versionSnapshot.versions,dependencyEvidence=versionSnapshot.evidence',b'versions={},dependencyEvidence=versionSnapshot.evidence')],'NLSR-DEPENDENCY-EXPORT'),
 ('cache_first_sample','dependency_versions.lua',[(b'function M.sample(readers)\n',b'local cached\nfunction M.sample(readers)\n  if cached then return cached end\n'),(b'  return result\nend\n',b'  cached=result\n  return result\nend\n')],'each export samples current values without cache'),
 ('remove_reader_isolation','dependency_versions.lua',[(b'local ok,raw=pcall(reader)',b'local ok,raw=true,reader()')],'expected evidence status cet read_failed'),
 ('unsafe_collector_lookup','init.lua',[(b"local dependencySample=type(dependencyVersions)=='table' and getmetatable(dependencyVersions)==nil and rawget(dependencyVersions,'sample') or nil",b'local dependencySample=dependencyVersions and dependencyVersions.sample or nil')],'actual draw/export must not throw'),
)

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--release',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--lua',required=True);p.add_argument('--lua-arg',action='append',default=[])
 a=p.parse_args();release=a.release.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 test=HERE/'test_dependency_export_runtime.lua';command=[a.lua,*a.lua_arg,str(test)]
 source={name:(release/MOD/name).read_bytes() for name in ['init.lua','dependency_versions.lua','support_report.lua']}
 results=[]
 r=subprocess.run(command+[str(release)],text=True,capture_output=True,timeout=60);combined=r.stdout+r.stderr
 (out/'runtime.log').write_text(combined)
 passed=r.returncode==0 and 'PASS independent dependency export runtime:' in combined
 results.append(dict(case='actual_init_export',exit_code=r.returncode,passed=passed,log='runtime.log'))
 print(('PASS' if passed else 'FAIL')+' actual_init_export')
 for name,filename,replacements,expected in MUTATIONS:
  raw=source[filename]
  for before,after in replacements:
   if raw.count(before)!=1:raise RuntimeError('missing or ambiguous mutation seam: '+name)
   raw=raw.replace(before,after)
  with tempfile.TemporaryDirectory(prefix='nlsr-dependency-mutant-') as temp:
   root=Path(temp)/'release';mod=root/MOD;mod.mkdir(parents=True)
   for original in (release/MOD).glob('*.lua'):shutil.copyfile(original,mod/original.name)
   (mod/filename).write_bytes(raw)
   r=subprocess.run(command+[str(root)],text=True,capture_output=True,timeout=60);combined=r.stdout+r.stderr
  (out/(name+'.log')).write_text(combined)
  passed=r.returncode!=0 and expected in combined
  results.append(dict(case=name,exit_code=r.returncode,passed=passed,intended_assertion=expected,log=name+'.log'))
  print(('PASS' if passed else 'FAIL')+' mutation_control '+name)
 record=dict(scope='Actual Lua init/report/collector; doubled external CET/Game/UI/store APIs. No actual game, CET, REDscript compiler or Windows runtime.',source_hashes={n:hashlib.sha256(b).hexdigest() for n,b in source.items()},test_sha256=hashlib.sha256(test.read_bytes()).hexdigest(),results=results,passed=all(r['passed']for r in results))
 (out/'RESULTS.json').write_text(json.dumps(record,indent=2)+'\n')
 return 0 if record['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
