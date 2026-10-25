# Diagnostic.2 validation

October 25, 2026 (America/Los_Angeles). Build **1.0.0-vehicle-diagnostic.2**.

The supplied compiler log reports `INVALID_CONSTANT` on diagnostic.1's new
`nlsCheckpointCombat: Int32 = -1` at line 93. The adjacent mounted field has the
same cause. Both defaults are removed; serial-gated public readers return `-1`
before any attempt and preserve observations afterwards. Request-time assignments,
native-result checks, save policy, queue and notification behavior are unchanged.

Fresh integrated command:
`python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output <CHECK_OUTPUT>`

**70/70 offline groups pass, exit 0.** The clean preflight full ZIP extraction also
passes all 70 groups, exit 0. Its placeholder commit is only preflight metadata;
the final immutable source commit and all packaged file hashes are verified
separately during delivery. This includes 58 targeted initializer/reader
assertions and four detected mutations, all prior native-result/queue/autosave/
settings suites, historical scope controls and 89 installation-auditor tests.
The diagnostic.1 negative control detects both forbidden defaults plus unguarded
fresh readers: six intended failures, zero evaluator boundary errors.

One initial integrated run failed the auditor group because its embedded
inventory hash still pinned diagnostic.1. The pin was updated to the new
versioned inventory; all 89 auditor tests and the full 70-group suite then passed.
The failing run is retained locally and is not represented as a pass.

A separate optional tree-sitter grammar check exits 1 on both diagnostic.1 and .2:
its local grammar rejects existing semicolon forms across the shipped source
(2,001 baseline and 2,003 candidate nodes, 37 non-semicolon nodes in each).
It is unsuitable as a native compiler check here and is not counted as passed.
No production source was changed to satisfy that incompatible grammar.

The exact source guard permits only the two declarations, two public getter
guards, version labels and auditor inventory/pins within protected runtime/helper
roots. Historical fixtures remain byte-identical. New fixture normalization
accepts only complete hash-pinned reviewed files; unrelated mutations still fail.
14 of 16 runtime files remain byte-identical to diagnostic.1; init.lua changes
version labels only. No new API, dependency, schema, lifecycle hook, retry loop,
lock removal, quest-fact repair or save-byte edit.

Evidence: `docs/NeverLockSavesReborn/evidence/vehicle-diagnostic.2-integrated/`
and `vehicle-diagnostic.2-regression/`.

**NOT RUN:** native REDscript compilation, CET/game execution, visible
vehicle-combat save creation, reload/progression, Windows restoration and full
optional-mod/framework compatibility. Vehicle-combat saving remains an unresolved
user-reported failure. Native acceptance still does not establish a written save.

Baseline: diagnostic.1 source `8748f0b2513216265bdfd2927320d3f7b22001bc`,
Drive runtime ID `1V1yPn3v14yhJlDg44D1wChQCtLvt7U_a`, modified
`2026-10-25T21:11:55.361Z`, runtime ZIP SHA-256
`ad1f5f51628fa58638e13a1945ead6634598b0ce63058d304c6725a48713949e`.
This is the exact failed-build baseline, not a known-good vehicle-combat release.
The installed game/framework matrix is unknown; no dependency upgrade is made.

Install one complete .2 runtime copy, Deploy and launch. Check fresh compilation
and the CET version before trying a save. If launch succeeds, attempt once in
vehicle combat and immediately export the support report. Check visible save
creation, reload and progression separately. See RELEASE-NOTES for rollback.
