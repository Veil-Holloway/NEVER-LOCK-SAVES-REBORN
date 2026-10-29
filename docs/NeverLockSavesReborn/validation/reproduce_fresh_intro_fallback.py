#!/usr/bin/env python3
"""Actual-source constrained execution; boundary doubles; NOT REDscript compile/gameplay.

Reuses the historical bounded translator only, not historical expected results.
Expected invariant: with a native save lock and fresh introduction completion <=0,
no forced checkpoint attempt may occur even if cached CET protection is stale.
"""
from pathlib import Path
import argparse,importlib.util,json,sys
from types import SimpleNamespace as O
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('historical_bounded_parser',HERE/'bounded_source_runner.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
p=argparse.ArgumentParser();p.add_argument('release',type=Path);p.add_argument('--expect-fixed',action='store_true');args=p.parse_args()
source=(args.release/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds').read_text()
# CName literal representation is irrelevant to the quest boundary double.
source=source.replace('n"q000_done"','"q000_done"')
r=m.Runtime(source)
intro=m.compile_subset(source,'NLSRebornDeferredIntroComplete',r.namespace,instance=True)
queue=m.compile_subset(source,'NLSRebornDeferredQueue',r.namespace,instance=True)
if 'func HandleSmartBlockedSave(' in source:
 r.namespace['NLSRebornPolicy'].HandleSmartBlockedSave=m.compile_subset(source,'HandleSmartBlockedSave',r.namespace)
results=[]
for mode in (0,1,2,3):
 for hook in m.HOOKS:
  for done in (0,-1,1,None):
   for enabled in (False,True):
    for protected in (False,True):
     for notifications in (False,True):
      player=r.prepare(mode=mode,protected=protected,locked=True,states=(1,0,0,0),notifications=notifications)
      r.namespace['GameInstance'].GetQuestsSystem=lambda game:None if done is None else O(GetFact=lambda fact:done)
      player.nlsDeferredEnabled=enabled;player.nlsDeferredPending=False;player.nlsDeferredSerial=0;player.nlsDeferredSource=0
      player.NLSRebornEnsureDFStateInitialized=lambda:None
      player.NLSRebornDeferredIntroComplete=lambda:intro(player)
      player.NLSRebornDeferredQueue=lambda src:queue(player,src)
      error=None
      try:r.invoke(hook)
      except AttributeError as exc:error=type(exc).__name__+': '+str(exc)
      # All fixture DF states are active, so all three non-Vanilla modes
      # have fallback eligibility when fresh completion is positive. RC4 mode2 attempts
      # immediately; other eligible modes keep their deferred preference.
      eligible=(mode in (1,2,3) and not protected and done is not None and done>0)
      expected_forced=int(eligible and (mode==2 or not enabled))
      expected_queued=bool(eligible and enabled and mode!=2)
      row={'mode':mode,'hook':hook,'cached_protection':protected,'q000_done':done,'deferred_enabled':enabled,'notifications':notifications,
           'queued':player.nlsDeferredPending,'forced_checkpoint_attempts':r.state['forced'],'boundary_error':error,
           'expected_forced_checkpoint_attempts':expected_forced,'expected_queued':expected_queued,
           'invariant_met':r.state['forced']==expected_forced and player.nlsDeferredPending==expected_queued and error is None}
      results.append(row)
failed=[x for x in results if not x['invariant_met']]
print(json.dumps({'scope':'actual-source bounded Python translation; external game boundaries doubled, not compiler or runtime evidence','cases':len(results),'failed_cases':len(failed),'results':results},indent=2))
if args.expect_fixed and failed:sys.exit(1)
if failed:print('REPRODUCED: fresh intro rejects queue, then stale cached policy permits an immediate forced-checkpoint attempt.')
else:print('PASS: fresh incomplete introduction prevents forced fallback in all exercised routes.')
