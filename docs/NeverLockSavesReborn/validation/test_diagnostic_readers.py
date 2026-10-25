#!/usr/bin/env python3
"""Independent checks of actual REDscript reader bodies through bounded lowering.

This is not REDscript compilation, native ABI verification, live dependency
resolution, game execution, or evidence of an actual save. Native services are
boundary doubles. The existing DF reader interpreter selects actual conditional
branches, including all sixteen required-module combinations.
"""
import argparse
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import re
import sys
from types import SimpleNamespace as O

MAIN=Path('r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds')
DF=Path('r6/scripts/NeverLockSavesReborn/DarkFutureSavePolicy.reds')
NAMES=('NLSRebornApartmentState','NLSRebornSaveLockSummary','NLSRebornDiagnosticDFState')
REASONS=('Nothing','Combat','Scene','Quest','Script','Boundary','MainMenu','LoadingScreen',
         'PlayerStateMachine','PlayerState','Tier','NotEnoughSlots','NotEnoughSpace','PlayerOnMovingPlatform')

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

def verify(source,df_source,release):
    validation=release/'docs/NeverLockSavesReborn/validation'
    bounded=load('independent_readers_source_subset',validation/'source_subset.py')
    reader=load('independent_readers_df_actual',validation/'test_df_reader.py')
    checks=0
    def eq(actual,expected,label):
        nonlocal checks
        checks+=1
        if actual!=expected:raise AssertionError(f'{label}: {actual!r} != {expected!r}')
    def expect(value,label):eq(bool(value),True,label)

    for name in NAMES:
        body=bounded.body(source,name)
        for forbidden in ('SetFact','RequestForcedCheckpoint','ManualSave','QuickSave','NLSRebornNotify','nlsRebornDFVehicleSleepState ='):
            expect(forbidden not in body,'read-only reader body '+name+' / '+forbidden)

    # Lower exactly the supported cast, retaining its type check at a doubled
    # native boundary. No guessed cast or generic truthiness is accepted.
    apartment_body=bounded.body(source,'NLSRebornApartmentState')
    lower,count=re.subn(r'systems\.Get\(n"PreventionSystem"\) as PreventionSystem',
                       'PreventionCast(systems.Get(n"PreventionSystem"))',apartment_body)
    eq(count,1,'one explicit supported PreventionSystem cast')
    state={};game=object();calls=[]
    def systems_get(key):
        calls.append(('Get',key))
        if key!='PreventionSystem':raise AssertionError('wrong system lookup')
        return state['prevention']
    ns={'__builtins__':{},'IsDefined':lambda value:value is not None,'Equals':lambda a,b:a==b,'NotEquals':lambda a,b:a!=b,
        'PreventionCast':lambda value:value if getattr(value,'kind',None)=='PreventionSystem' else None,
        'gamedataDistrict':O(LittleChina_VApartment=1001),
        'GameInstance':O(GetScriptableSystemsContainer=lambda _:state['systems'])}
    apartment=bounded.compile_function(lower,'NLSRebornApartmentState',ns,instance=True)
    player=O(GetGame=lambda:game)
    def fixture(*,systems=True,prevention=True,wrong_type=False,district=True,record=True,kind=1001):
        state.clear();calls.clear()
        rec=O(Type=lambda:kind) if record else None
        dist=O(GetDistrictRecord=lambda:rec) if district else None
        state['prevention']=O(kind='DifferentSystem' if wrong_type else 'PreventionSystem',GetCurrentDistrict=lambda:dist) if prevention else None
        state['systems']=O(Get=systems_get) if systems else None
    for flags in itertools.product((False,True),repeat=4):
        for kind in (1001,1002,0,-1,99999):
            fixture(systems=flags[0],prevention=flags[1],district=flags[2],record=flags[3],kind=kind)
            expected=(-1 if not all(flags) else 1 if kind==1001 else 0)
            eq(apartment(player),expected,'original apartment/missing service classification')
            if not flags[0]:eq(calls,[],'missing container causes no system lookup')
    fixture(wrong_type=True);eq(apartment(player),-1,'wrong native system type stays unknown')
    fixture(kind=1001);eq(apartment(player),1,'read known original apartment')
    fixture(kind=1002);eq(apartment(player),0,'next call observes leaving apartment')
    fixture(district=False);eq(apartment(player),-1,'unknown next district cannot reuse cached apartment')
    fixture(kind=1001);eq(apartment(player),1,'recovered read uses fresh district')

    # The oracle maps documented enum values independently of the source's
    # branch ordering. Mounted/safe-area state cannot add a Vehicle reason.
    state={};lock_calls=[]
    def saving_locked(_,locks):
        lock_calls.append(1);locks.extend(O(reason=value)for value in state['reasons'])
        return state['locked']
    namespace={'__builtins__':{},'ArraySize':len,'Equals':lambda a,b:a==b,
               'gameSaveLockReason':O(**{name:i for i,name in enumerate(REASONS)}),
               'GameInstance':O(IsSavingLocked=saving_locked)}
    summary=bounded.compile_function(source,'NLSRebornSaveLockSummary',namespace,instance=True)
    reason_sets=[[],*[list(values)for values in itertools.product(range(14),repeat=2)],
                 *[[i]for i in range(14)],[-1],[14],[999],[1,999],[999,1],
                 [1]*15,[1]*16,[1]*17,list(range(14)),list(range(14))+[999,1]]
    for locked,reasons in itertools.product((False,True),reason_sets):
        state.update(locked=locked,reasons=reasons);before=len(lock_calls)
        if len(reasons)>16:expected='overflow'
        elif not locked and not reasons:expected='unlocked'
        elif not locked or not reasons:expected='unknown'
        else:expected='locked'+''.join('|'+(REASONS[x]if 0<=x<len(REASONS)else'Unknown')for x in reasons)
        actual=summary(player)
        eq(actual,expected,'bounded native lock inventory and mixed/unknown reasons')
        eq(len(lock_calls),before+1,'native lock query fresh exactly once')
        expect('Vehicle'not in actual,'no fabricated vehicle lock inference')
        expect(len(actual)<400,'bounded summary payload')

    # Exercise the new main-file bridge through the actual DF reader bodies.
    runner=reader.load_runner(release)
    for bits in itertools.product((False,True),repeat=4):
        available={name for name,present in zip(reader.MODULES,bits)if present}
        runtime=reader.Runtime(df_source,runner,available)
        bridge=bounded.compile_function(source,'NLSRebornDiagnosticDFState',
            {'__builtins__':{},'NLSRebornDFPolicy':O(Read=runtime.read)},instance=True)
        first=bridge(runtime.player);second=bridge(runtime.player)
        expect(first is not second,'each explicit export gets a newly read snapshot')
        expected=(0,0,0,0)if all(bits)else(-1,-1,-1,-1)
        eq(tuple(getattr(second,f)for f in reader.FIELDS),expected,'actual optional-module snapshot')
        first.vehicleSleep=1;first.addiction=1;first.starvation=1;first.dehydration=1
        third=bridge(runtime.player)
        eq(tuple(getattr(third,f)for f in reader.FIELDS),expected,'previous diagnostic values cannot become a cache')
        if not all(bits):
            eq(runtime.lookups,[],'missing/partial modules use fallback without DF lookups')
            eq(runtime.game_reads,0,'missing module fallback does not enter game systems')
    runtime=reader.Runtime(df_source,runner)
    bridge=bounded.compile_function(source,'NLSRebornDiagnosticDFState',
        {'__builtins__':{},'NLSRebornDFPolicy':O(Read=runtime.read)},instance=True)
    for system in runtime.systems.values():system.stage=4;system.sleeping=True
    eq(tuple(getattr(bridge(runtime.player),f)for f in reader.FIELDS),(1,1,1,1),'fresh active DF diagnostic')
    for key in runtime.systems:runtime.systems[key]=None
    eq(tuple(getattr(bridge(runtime.player),f)for f in reader.FIELDS),(-1,-1,-1,-1),'lost DF services cannot retain active state')
    eq(tuple(getattr(bridge(None),f)for f in reader.FIELDS),(-1,-1,-1,-1),'absent player yields unknown DF fields')
    return checks

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('release',type=Path)
    p.add_argument('--baseline',type=Path)
    p.add_argument('--self-check',action='store_true')
    a=p.parse_args();source=(a.release/MAIN).read_text();df=(a.release/DF).read_text()
    checks=verify(source,df,a.release)
    missing=[]
    if a.baseline:
        original=(a.baseline/MAIN).read_text()
        missing=[name for name in NAMES if not re.search(r'\bfunc\s+'+name+r'\s*\(',original)]
        if missing!=list(NAMES):raise AssertionError('baseline absence control changed')
    controls=[]
    if a.self_check:
        mutations=[
          ('missing apartment district guessed clear','if !IsDefined(district) { return -1; };','if !IsDefined(district) { return 0; };',False),
          ('wrong apartment district accepted','if Equals(record.Type(), gamedataDistrict.LittleChina_VApartment)','if NotEquals(record.Type(), gamedataDistrict.LittleChina_VApartment)',False),
          ('lock inventory overflow guard weakened','if ArraySize(locks) > 16','if ArraySize(locks) > 17',False),
          ('unknown reason guessed combat','result = result + "|Unknown"','result = result + "|Combat"',False),
          ('quest reason guessed combat','result = result + "|Quest"','result = result + "|Combat"',False),
          ('missing DF modules report clear','snapshot.vehicleSleep = -1;','snapshot.vehicleSleep = 0;',True)]
        for label,before,after,is_df in mutations:
            selected=df if is_df else source
            if before not in selected:raise AssertionError('missing mutation anchor '+label)
            altered=selected.replace(before,after)
            try:verify(source if is_df else altered,altered if is_df else df,a.release)
            except AssertionError:controls.append(label)
            else:raise AssertionError('escaped mutation '+label)
    print(json.dumps({'checks':checks,'source_sha256':hashlib.sha256((a.release/MAIN).read_bytes()).hexdigest(),
        'df_sha256':hashlib.sha256((a.release/DF).read_bytes()).hexdigest(),'baseline_missing':missing,
        'negative_controls_detected':controls,'passed':True,
        'scope':'Independent bounded actual-source execution; native/DF boundaries doubled; NOT compilation, ABI or game/save evidence'},indent=2))

if __name__=='__main__':main()
