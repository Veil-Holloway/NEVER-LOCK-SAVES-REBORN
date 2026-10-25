#!/usr/bin/env python3
"""Byte identity outside the explicitly reviewed main-config validator/call seams."""
import hashlib,json,sys
from pathlib import Path
from check_dependency_scope import normalized_init,normalized_redscript,normalized_report,normalized_syntax
root=Path(sys.argv[1]);fixture=json.loads((Path(__file__).parent/'fixtures/main_config_scope.json').read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
for rel,h in fixture['unchanged_files'].items():
 data=normalized_report(root) if rel.endswith('/support_report.lua') else normalized_syntax(root) if rel.endswith('/check_lua_syntax.lua') else (root/rel).read_bytes()
 assert sha(data)==h,'Unexpected change: '+rel
b=normalized_init(root)
assert b.count(b'0.14.0-preRC3')==6,'Expected runtime version-label count'
b=b.replace(b'0.14.0-preRC3',b'0.14.0-preRC2')
start=b.index(b'-- Main configs predate named presets:');end=b.index(b'local function saveConfig()',start)
assert sha(b[start:end])==fixture['validator_block_sha256'],'Validator block differs from reviewed source'
b=b[:start]+b[end:]
changes=[(b'local validateMainSettings\r\n',b''),(b'pcall(configStore.load, file, validateMainSettings)',b'pcall(configStore.load, file)'),(b'configStore.save(file,currentSettings(),validateMainSettings)',b'configStore.save(file,currentSettings())'),(b'pcall(configStore.save,file,settings,validateMainSettings)',b'pcall(configStore.save,file,settings)')]
for before,after in changes:
 assert b.count(before)==1,'Unexpected main-config seam count'
 b=b.replace(before,after)
assert sha(b)==fixture['baseline_init_sha256'],'Unrelated init.lua behavior changed'
r=normalized_redscript(root);assert r.count(b'0.14.0-preRC3')==2
assert sha(r.replace(b'0.14.0-preRC3',b'0.14.0-preRC2'))==fixture['baseline_redscript_sha256'],'REDS changed beyond version labels'
print('PASS exact preRC2 preservation: entire init.lua outside validator and three persistence seams; complete REDscript except version labels; '+str(len(fixture['unchanged_files']))+' protected source/helper/test files after explicit dependency-diagnostic normalization. Source identity only.')
