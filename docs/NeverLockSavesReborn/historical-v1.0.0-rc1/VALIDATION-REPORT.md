# RC1 validation report

October 24, 2026 (America/Vancouver). **1.0.0-rc1 — release candidate for testing.**

## Outcome and approved scope

The user approved Option A by replying “Do it” to the concrete first-release
proposal. RC1 freezes the working preRC4 feature set. Automatic current-playthrough
binding, all-owned-safehouse triggers, automatic live backups/correlated
written/reloaded evidence and dependent in-game completion notifications are
explicitly deferred until after 1.0. They remain planned work, not completed features.

The runtime changes are eight version literals and five adjacent release titles
in init.lua and NeverLockSavesReborn.reds. All other 14 runtime files and all five
existing recovery-companion files are byte-identical to preRC4. No save policy,
configuration schema, queue lifecycle, API getter, message library, observer,
quest fact or game-save behavior changes in this candidate.

RC1 also includes current install/testing/support documents, local issue templates,
an updated roadmap, a version-only source guard and an optional read-only
installation auditor. No public repository, stable release or author message was
created. Attribution is preserved; upstream distribution permission remains
unresolved and no whole-package MIT grant is asserted.

## Authenticated baseline

The live project Drive folder was listed afresh and its newest runtime preview
selected, excluding the acceptance kit and documents. The complete preRC4 ZIP was
downloaded through authenticated access into a separate immutable input:

- File: Never_Lock_Saves_Reborn_v0.14.0-preRC4_Release_Testing_Preview.zip.
- Drive ID: `1__E1pN7mN-aPkvAZ9HazX3l7qUu06kLg`.
- Modified: `2026-10-24T18:07:00.564Z`.
- Size: 459,091 bytes.
- SHA-256: `f3f68651a12e91a0e7145375e11217818b38b2d9bb4c82b553fd61a9e341529c`.
- CRC, all 281 manifest entries and 282 safe unique/casefold-unique archive paths
  passed. Input, baseline and candidate staging remain separate.

The user reports preRC4 working. Exact installed fingerprint, environment and
individual case coverage were not supplied. The 42-row game matrix retains one
attributed broad USER_REPORTED_WORKING report, 38 UNTESTED cases and three
UNAVAILABLE capabilities marked as post-1.0 deferrals. No runtime row was passed
from a version-label change or offline assertion. Record already-completed tests
with their actual build and outcome; repetition solely for paperwork is unnecessary.

## Fresh verification

All **54 integrated groups pass**, exit 0, on the final frozen source. The runner
retains all 51 preRC4 groups and adds source-freeze, source-mutation and installation
auditor groups. Original test sources are unchanged; only the runner and narrow
version adapter were modified in the original validation subtree.

- Exact source preservation compares the whole 16-file runtime and five-file
  recovery companion against pinned preRC4 bytes after only the reviewed labels.
- Nine temporary mutations are rejected for their intended reasons:
  mixed/wrong versions/titles, nonlabel Lua/REDscript edits, changed module/helper,
  an extra runtime path and a missing runtime path. Harness/setup errors do not
  count as detected mutants.
- The optional installation auditor passes **89 real-filesystem CLI tests**, no
  skips. It pins all 16 RC1 runtime files, including the dependency collector;
  missing or same-length changed collector bytes cannot pass. Existing privacy,
  bounded scans, duplicate candidates, IO/link errors and no-write cases remain.
  Its prior author/independent suites were adapted by one agent for RC1; they are
  not presented as newly independently authored RC1 tests.
- Prior module, actual-init, disk-recovery, source-boundary and mutation suites
  all rerun, including 834 collector assertions, 554 dependency-report assertions
  and 16,590 independent export assertions across 38 fixtures. Repeated-frame and
  recursive checks contribute to assertion counts; these are not gameplay cases.
- Thirteen Lua files pass syntax loading on the available Lua 5.3 test host.

Commands, exit statuses and logs are under `evidence/integrated/`. The extracted
package is checked with the same full runner and its source compared to the same
88 frozen code/fixture/identity records; its results are under `evidence/extracted/`.
The final package record reports the actual outcome. An isolated agent mirror's
51-group pass is supplementary; it does not replace the integrated run.

Reproduce from the extracted package with Python 3.10+ and texlua/luatex:

```sh
python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output /path/to/results
```

## Installed identity and package boundaries

Final version-labelled runtime hashes:

- init.lua: `869800a7ab82ed380090d5a84e78a30b7d79869763ed4e4ffb3669c53f1ef41f`.
- NeverLockSavesReborn.reds: `293a0089f0d3c7591501497ac813b0f3bb5de7d9da4de4b5e233936049333e3e`.

The RC-to-preRC4 guard requires exact counts and complete pinned bytes before
normalization. The prior preRC4-to-preRC3 and preRC3-to-preRC2 source checks stay
intact; arbitrary source changes are not allowed through a broad replacement.
The runtime-version-only diff and complete code diff are packaged separately.

The auditor checks installed runtime bytes, not its containing ZIP, and rejects
the old acceptance kit's --archive option. ZIP identity uses the external sidecar.
Auditor output has no private paths, discovered filenames or raw log/error text;
optional log-tail counts/digests are unscoped and do not prove a fresh compilation.
The checker performs no repairs, networking, process launches or save access.

The ZIP includes complete bin/r6 install paths, current docs/tests, optional tools,
manifest and rollback instructions. Packaging checks safe/casefold-unique paths,
CRC, every manifest hash and all 88 frozen code/fixture/identity hashes, excluding
bytecode caches, temporary fixtures and actual user settings/reports/saves. Final
archive SHA-256 is external to avoid a circular self-hash. New Drive upload and
sidecar are fully read back and compared before delivery; older packages remain.

## Evidence limits and next gate

Tests execute on Linux/Python 3.12 and Lua 5.3 with controlled CET/Game/UI boundaries.
No current REDscript compiler, CET LuaJIT/Lua 5.1, native ABI, Windows process/file
behavior or live game is exercised here. Matching hashes do not establish
compilation, compatibility, actual save creation, reload or quest progression.
Queue acceptance, checkpoint submission, file copying and game outcomes remain
separate. Guardian written/reloaded states stay Unknown.

The companion remains optional, manually run with the game closed, with verified
copies and confirmed restore to a separate new destination. Its portable tests
are not a Windows restoration or restored-game pass. Source-preserving version
changes do not turn prior broad feedback into RC1 gameplay evidence.

The user handoff is TESTING-RC1.md and TEST-MATRIX.csv: record the exact supported
environment, relevant fresh logs, exercised cases, actual save/reload/progression,
Windows recovery and install/update/rollback results. Stable/public promotion
follows that evidence and distribution status. Rollback closes the game and
reinstalls complete preRC4 with its retained config and preset bank; RC1 adds no
runtime file or schema requiring migration. Keep external save/recovery copies.
