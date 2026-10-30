#!/usr/bin/env python3
"""Build clean deterministic publication ZIPs; never install or publish."""
import argparse
import ast
import hashlib
import json
from pathlib import Path,PurePosixPath
import re
import zipfile

def digest(data):return hashlib.sha256(data).hexdigest()

def verify_archive(path,expected=None):
    with zipfile.ZipFile(path)as z:
        names=z.namelist()
        assert len(names)==len({n.casefold()for n in names}),'duplicate path'
        for name in names:
            p=PurePosixPath(name)
            assert not p.is_absolute()and '..'not in p.parts and '\\'not in name and ':'not in name,'unsafe path'
        assert z.testzip()is None,'CRC failure'
        covered=set()
        for line in z.read('FILE_MANIFEST.sha256').decode().splitlines():
            sha,name=line.split('  ',1);assert digest(z.read(name))==sha,name;covered.add(name)
        assert covered==set(names)-{'FILE_MANIFEST.sha256'},'incomplete file manifest'
        inventory=json.loads(z.read('RUNTIME_MANIFEST.json'))
        for row in inventory['runtime_files']:
            data=z.read(row['path']);assert digest(data)==row['sha256']and len(data)==row['size'],row['path']
        if expected is not None:
            assert set(names)==set(expected),'archive inventory differs'
            for name,data in expected.items():assert z.read(name)==data,'byte readback '+name
    return {'file':path.name,'size':path.stat().st_size,'sha256':digest(path.read_bytes()),'entries':len(names),
        'runtime_files':len(inventory['runtime_files']),'safe_unique_paths':True,'CRC':'PASS','complete_SHA256_manifest':'PASS','full_byte_readback':'PASS'}

def test_closure(root):
    v=root/'docs/NeverLockSavesReborn/validation'
    plan=json.loads((v/'RELEASE-TEST-PLAN.json').read_text())
    found={v/'RELEASE-TEST-PLAN.json',v/'run_release_checks.py'}
    for case in plan['checks']:
        for token in case['command']:
            if token.startswith('{validation}/'):
                p=v/token.split('/',1)[1]
                if p.is_file():found.add(p)
    processed=set()
    while found-processed:
        p=next(iter(found-processed));processed.add(p)
        if p.suffix not in ('.py','.lua'):continue
        text=p.read_text()
        if p.suffix=='.py':
            for node in ast.walk(ast.parse(text)):
                modules=([node.module]if isinstance(node,ast.ImportFrom)else [n.name for n in node.names]if isinstance(node,ast.Import)else [])
                for module in modules:
                    if module and (v/(module.split('.')[0]+'.py')).is_file():found.add(v/(module.split('.')[0]+'.py'))
        for name in re.findall(r'[A-Za-z0-9_./-]+\.(?:py|lua|json)',text):
            base=Path(name).name
            for candidate in (v/base,v/'fixtures'/base):
                if candidate.is_file():found.add(candidate)
    return found

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=Path(__file__).resolve().parents[2])
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();root=a.source.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    inv=json.loads((root/'RUNTIME_MANIFEST.json').read_text());version=inv['release']
    runtime={root/row['path']for row in inv['runtime_files']}
    actual={p for folder in ('bin','r6')for p in (root/folder).rglob('*')if p.is_file()and p.suffix in ('.lua','.reds')}
    assert runtime==actual,'runtime inventory must be exact'
    for row in inv['runtime_files']:
        data=(root/row['path']).read_bytes();assert len(data)==row['size']and digest(data)==row['sha256'],row['path']
    docs={root/name for name in ('README.md','INSTALL.md','SUPPORT.md','RELEASE-NOTES.md','CHANGELOG.md','ROADMAP.md','VALIDATION.md','LICENSE','ATTRIBUTION.md','PERMISSION.md','BUILD-MANIFEST.json','PUBLIC-DELIVERY.json','RUNTIME_MANIFEST.json','CHANGED-FILES.md','PUBLISH-CHECKLIST.md','TEST-DISPOSITION.json')}
    source=runtime|docs|test_closure(root)|{root/name for name in ('CONTRIBUTING.md','requirements-test.txt','BASELINE-RUNTIME.json','DESCRIPTION.txt','READINESS.diff','.gitattributes','.gitignore')}
    source|={p for p in (root/'tools/NLSRInstallAudit').rglob('*')if p.is_file()and (p.suffix=='.py'or p.name in ('README.md','runtime_inventory.json'))}
    source|={root/'tools/release/build_release.py'}
    source|={p for p in (root/'validation-evidence').iterdir()if p.is_file()and p.suffix in ('.log','.json')}
    source|={root/'docs/NeverLockSavesReborn/README.md'}
    reports=[]
    for kind,paths in [('RUNTIME_ONLY',runtime|docs),('SOURCE_AND_TESTS',source)]:
        files={p.relative_to(root).as_posix():p.read_bytes()for p in paths}
        assert not any(n.startswith('.github/')or '__pycache__'in n or n.endswith('.pyc')for n in files)
        files['FILE_MANIFEST.sha256']=''.join(digest(data)+'  '+name+'\n'for name,data in sorted(files.items())).encode()
        path=out/f'Never_Lock_Saves_Reborn_v{version}_{kind}.zip'
        assert not path.exists(),'refusing to overwrite existing build: '+str(path)
        with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as z:
            for name,data in sorted(files.items()):
                info=zipfile.ZipInfo(name,(2026,10,29,12,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,data)
        reports.append(verify_archive(path,files))
        path.with_suffix('.zip.sha256').write_text(digest(path.read_bytes())+'  '+path.name+'\n',encoding='ascii',newline='\n')
    (out/'PACKAGE-VERIFICATION.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(reports,indent=2))

if __name__=='__main__':main()
