# RC3 validation report

October 24, 2026 (America/Los_Angeles). **Candidate, not stable clearance.**

## Root cause and scope

RC2's actual-source hooks reproduce the reported Smart interaction symptom:
noncombat locked requests skip the queue because it is inside immediate forced
checkpoint authorization, then reach vanilla without a custom message. RC3 adds
one Smart-specific helper and three guarded calls; eight runtime labels change.
Fourteen other runtime files and all five recovery-companion files match RC2.
Existing queue, dispatch, native-unlock, introduction and combat-policy bodies are
unchanged. The source diff and exact 21-path preservation contract are included.

## Fresh evidence

- Integrated and extracted-package runners: **60/60 groups passed each**, preserving the prior 57 and adding
  Smart interaction routing plus RC3 exact scope and mutation controls.
- Smart interaction routing: **2,082 actual-source assertions, zero failures**
  across all three wrappers, lock reasons, queue/notification controls, combat
  exceptions, intro, other modes, busy guards and one-shot native-gated dispatch.
- RC2 baseline control: **853 expected assertion failures** reproduce missing
  Smart queue/feedback; no fixture-boundary errors caused that result.
- Two behavior mutations are detected: disabling Smart routing and removing the
  native-unlock guard. Fourteen RC3 identity controls, twelve RC2 controls and
  nine RC1 controls reject their intended mutations.
- Read-only installation auditor: original **89 tests pass, no skips**; clean RC3
  returns zero, stale RC2 REDscript and init separately return nonzero. Independent
  probes preserve input bytes/mtimes and do not leak private paths.
- Independent review: 72 routing combinations pass, along with 2,115 Smart policy
  cases, 27,673 bridge assertions and 17,499 notification-source assertions.
- **96 frozen code/fixture/identity records** bind tested sources to the package.
  ZIP checks cover safe unique/case-insensitive paths, CRC, complete manifest and
  frozen bytes. The final extracted-package result is recorded in FINAL-RESULT.json.

The first integrated run was 59/60: the older introduction harness lacked the
new actual helper binding and raised boundary AttributeErrors in all 384 cases.
A conditional actual-source binding was added to that test only. Its 384 cases
and the full final suite pass. Initial failure evidence is retained under
`evidence/rc3-first-integrated`; it was not a runtime code failure or hidden pass.

Older current-location integrated/extracted evidence without the rc3 prefix is
RC2 history. Current runs use `evidence/rc3-integrated` and
`evidence/rc3-extracted`. The RC3 first/final runs and independent evidence are
retained separately. No untested gameplay row was changed to a pass.

## Verification boundary

These checks execute actual Lua under Lua 5.3 and a constrained translation of
REDS methods with external game/service doubles. They are not a REDscript compiler,
CET LuaJIT/5.1, Windows or Cyberpunk runtime. They do not establish live interaction
notification rendering, actual save writing/reload, quest progression, full DF
compatibility or Windows restoration. Those remain explicit acceptance cases.
Native save permission is necessary for deferred dispatch, not a serialization
or quest-safety guarantee. Checkpoint submission is never proof of completion.

The exact baseline was freshly fetched from Drive and verified: 825,594 bytes,
SHA256 24e36eaec40a2be1484024cc86d71ae1fee56a3817cd0787ce16a75fea88285d,
CRC and all 755 manifest hashes. See BASELINE-PROVENANCE.json and source diffs.
