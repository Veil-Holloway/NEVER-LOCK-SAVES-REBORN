# RC2 autosave type hotfix — validation

October 24, 2026 (America/Los_Angeles). **1.0.0-rc2, release candidate for testing.**

## Reported failure and correction

The supplied current REDscript log reports `UNRESOLVED_TYPE` at
NeverLockSavesReborn.reds:170: `ref<AutoSaveSystem>` does not resolve. This actual
compiler failure supersedes earlier broad RC1 working reports as evidence of
release readiness for that installation. The log lists only the three Reborn
scripts and contains no subsequent successful compilation. The screenshot's
Vortex version labels are recorded as labels, not independently measured runtime
versions or a complete supported-environment matrix.

RC2 replaces that one annotation with `ref<gameAutoSaveSystem>`. The service
getter, absence guard, pending/serial/native/intro/autosave checks, clear-before-call
order, forced-checkpoint method and submission semantics are unchanged. Eight
runtime version labels become 1.0.0-rc2. The other 14 runtime files and all five
existing recovery-companion files are byte-identical to RC1. No settings, preset
schema, quest facts, save contents, DF policy or message libraries change.

## Primary interface evidence

The current primary script snapshot at commit
`cfcf5071e5363962a44c33cb7cab749688b0ca51` declares that GetAutoSaveSystem returns
gameAutoSaveSystem and declares that native class with RequestForcedCheckpoint():
Bool. The coordinator and an independent reviewer retrieved the pinned source.

- [gameInstance.script](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Scripts/blob/cfcf5071e5363962a44c33cb7cab749688b0ca51/scripts/core/systems/gameInstance.script),
  blob `6113815dfcebbc98207a6ec394acff6df34fa1a8`, line 92.
- [gameSystem.script](https://github.com/CDPR-Modding-Documentation/Cyberpunk-Scripts/blob/cfcf5071e5363962a44c33cb7cab749688b0ca51/scripts/core/systems/gameSystem.script),
  blob `7dfa9b96334b35472ff4a543eddb02d344655fc9`, lines 37–40.

Detailed pins and short declarations are in
`interfaces/autosave-type/API-EVIDENCE.json`. Historical NativeDB RTTI is
corroboration, not current-game compatibility proof. No guessed AutosaveSystem
alias or new dependency is substituted.

## Provenance and verification

The project Drive folder was freshly listed. The complete latest RC1 runtime
ZIP, ID `1JELXKtMFNUR2r7pdKM-_b8Wj40XyM8YP`, modified
`2026-10-24T22:14:41.201Z`, was authenticated and downloaded again. Its 634,218
bytes matched SHA-256
`b48c052a0d6a52e3ad5be6590bff053b003563fb1deef9c3375c99907ed49b7a`.
CRC, all 477 manifest entries, 478 safe unique/casefold-unique paths and all 88
frozen records passed. Input, baseline and candidate staging are separate.

The user's compiler log is retained as an immutable local input. Only a redacted
copy with the absolute game root replaced by `<GAME_ROOT>` is packaged; its raw
digest and redaction are recorded in evidence. No support-report, personal game
save, user configuration, framework binary or raw account information is bundled.

The focused source-contract check fails RC1 for the intended AutoSaveSystem
annotation and passes the corrected declaration and fail-closed/one-shot order.
The exact RC2 guard pins complete files before normalizing only the one type
correction and eight version labels back to RC1. The previous RC1/preRC4/preRC3/
preRC2 preservation chain remains active. Nine existing RC1 mutation controls
and 12 new RC2 controls reject their intended source edits.

All original 54 runner groups remain; three groups add type-contract, RC2 scope
and RC2 mutation coverage. The initial integrated run passed 56 of 57 groups.
The older preserved_scope check correctly rejected the intentionally changed
dispatch annotation. Its two-line adapter now accepts only the exact pinned RC2
file, normalizes it to RC1, then enforces the original 49 protected method hashes.
An independent changed-pending-guard mutation still fails at the original method
check. This validation adaptation does not waive dispatch or save-policy checks.

Both final integrated and extracted-package runs pass all **57 groups**, exit 0.
Their outcomes are recorded in `FINAL-RESULT.json`
and `evidence/integrated/` / `evidence/extracted/`. They are separate from the
historical RC1 logs and the first run's preserved-scope failure. Portable tests
exercise actual Lua modules, real temporary files and controlled native/game
boundaries; source checks are explicitly not REDscript compilation.

The read-only installation auditor is repinned to all 16 RC2 runtime files. Its
89 real-filesystem tests are retained. The prior rc1_label log counter retains
its meaning; an additive rc2_label counter reports the new label. Independent
clean-RC2 and stale-RC1 Lua/REDscript probes verify exact-match versus drift,
without writes or private-path leakage. No audit repairs, networking, process
launches or save-folder reads are introduced.

## Limits and next test

The current game cache, REDscript compiler, CET LuaJIT/5.1, Windows and game are
unavailable here. The fix removes the exact source error supported by the log and
primary declarations; a complete post-fix native compilation or gameplay pass is
not claimed. Existing Lua tests execute on Lua 5.3 with Python 3.12 on Linux.

Replace RC1 with RC2 as one installation, preserve config/preset backups and keep
one active Reborn copy. Launch and inspect the fresh compiler log first. Confirm
1.0.0-rc2 in the overlay/logs after successful compilation, then test saving,
reload and continued quest progression. A new compiler diagnostic should be
reported with that launch's current log rather than masked with dependency
changes or a cache purge. RC1 has the reported defect and is not advertised as a
working fallback. Retain a separately verified earlier installation or disable
Reborn while preserving settings if rollback is needed.

The 43-row matrix preserves the 42 prior records and adds the historical RC1
compiler failure. The 38 RC2 runtime cases remain untested here; three automatic
capabilities and dependent in-game completion notifications retain their approved
post-1.0 deferral. Public publication and MIT licensing remain pending upstream
permission, which the user is arranging. The parallel permission message is a
draft for the user to send; no author contact or public repository was created.

The package freezes **92 code/fixture/identity records**. The complete clean ZIP
retains installable bin/r6 paths, tests, optional tools,
source diff, manifest and these limits. Final packaging verifies every hash,
CRC, unique safe paths and the frozen code/fixture records against the tested
bytes. Drive delivery is read back in full, with a matching checksum sidecar,
before the new candidate is handed over. The final archive SHA is external to
avoid a circular self-hash.
