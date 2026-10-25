#!/usr/bin/env python3
"""Exact preRC3 identity outside the new on-demand diagnostic seams."""
from pathlib import Path
from check_rc1_scope import normalized_pre_rc4
import hashlib,json,sys
FIXTURE=Path(__file__).parent/'fixtures/dependency_scope.json'
def fixture():return json.loads(FIXTURE.read_text())
def sha(value):return hashlib.sha256(value).hexdigest()
def normalized_init(root):
 f=fixture();b=normalized_pre_rc4(root,f['init_path']);assert b.count(b'0.14.0-preRC4')==6
 b=b.replace(b'0.14.0-preRC4',b'0.14.0-preRC3')
 addition=b"local dependencyVersions=optional('dependency_versions')\r\n";assert b.count(addition)==1;b=b.replace(addition,b'')
 start=b.index(b'  -- Collect only on explicit support export.');end=b.index(b'  local snapshot=',start)
 assert sha(b[start:end])==f['init_block_sha256'],'Export block differs from reviewed source';b=b[:start]+b[end:]
 before=b'versions=versionSnapshot.versions,dependencyEvidence=versionSnapshot.evidence,';assert b.count(before)==1;b=b.replace(before,b'versions={},')
 assert sha(b)==f['baseline_hashes'][f['init_path']],'Unrelated init source changed';return b

def normalized_redscript(root):
 f=fixture();b=normalized_pre_rc4(root,f['redscript_path']);assert b.count(b'0.14.0-preRC4')==2
 b=b.replace(b'0.14.0-preRC4',b'0.14.0-preRC3');assert sha(b)==f['baseline_hashes'][f['redscript_path']],'Unrelated REDS source changed';return b

def normalized_report(root):
 f=fixture();b=(root/f['report_path']).read_bytes();start=b.index(b'local DEPENDENCY_KEYS=');end=b.index(b'local function tri(',start)
 assert sha(b[start:end])==f['report_block_sha256'],'Evidence helper differs from reviewed source';b=b[:start]+b[end:]
 before=b"  for _,key in ipairs(DEPENDENCY_KEYS) do report.dependencies[key]=version(deps[key]) end\n  report.dependency_evidence=dependencyEvidence(s.dependencyEvidence,report.dependencies)\n"
 after=b"  for _,key in ipairs({'cet','redscript','red4ext','nativeSettings','darkFuture'}) do report.dependencies[key]=version(deps[key]) end\n"
 assert b.count(before)==1;b=b.replace(before,after)
 assert sha(b)==f['baseline_hashes'][f['report_path']],'Unrelated report source changed';return b

def normalized_syntax(root):
 f=fixture();b=(root/f['syntax_path']).read_bytes();addition=b",'dependency_versions.lua'";assert b.count(addition)==1;b=b.replace(addition,b'');assert b.count(b'thirteen Lua files')==1;b=b.replace(b'thirteen Lua files',b'twelve Lua files')
 assert sha(b)==f['baseline_hashes'][f['syntax_path']],'Unrelated syntax check changed';return b

def check(root):
 f=fixture();normalized_init(root);normalized_redscript(root);normalized_report(root);normalized_syntax(root)
 assert sha((root/f['module_path']).read_bytes())==f['module_sha256'],'Collector differs from reviewed source'
 for rel,expected in f['unchanged_files'].items():assert sha((root/rel).read_bytes())==expected,'Changed protected file: '+rel
 print('PASS exact preRC3 scope: init export/optional seam, additive report fields, thirteen-file syntax coverage and version labels only; '+str(len(f['unchanged_files']))+' complete runtime/helper files unchanged. Source identity only.')
if __name__=='__main__':check(Path(sys.argv[1]))
