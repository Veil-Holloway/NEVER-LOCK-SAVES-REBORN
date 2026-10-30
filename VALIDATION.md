# Validation - Never Lock Saves: Reborn 1.0.0

October 29, 2026. Stable release, explicitly authorized by the maintainer after the user-reported working notification-polish build. Version and menu/status display labels change; game logic is frozen.

## Current release gate

**65/65 active check groups passed.** No active group failed. The canonical plan is docs/NeverLockSavesReborn/validation/RELEASE-TEST-PLAN.json, invoked by run_release_checks.py. The suite includes full current module/integration/source checks plus all applicable recent phone, completion, notification and scheduler regressions.

The separate installation-auditor unittest group ran **94 tests: 73 passed, 21 skipped**. Skips are explicit host limits for symbolic-link privileges and case-distinct path fixtures on this Windows filesystem. The new host-independent timestamp, mutation, inode, creation-time, reparse and saved-byte-pin regression cases pass. The skips are not counted as tested behavior. Broader existing link tests remain available for a capable host.

## Resolution of the seven previous failing groups

| Previous group | Resolution |
|---|---|
| backup_recovery | Retired: the backup companion was explicitly removed by the approved scope freeze. |
| retention_journal_review | Retired: no shipping backup-retention journal exists. |
| retention_protected_review | Retired: no shipping backup-retention journal exists. |
| dependency_report | Updated the stale schema-1 assertion to current schema 2; 669 report assertions now pass. |
| dependency_mutation_controls | Added the current settings_ui dependency to isolated report fixtures. Both positive checks and all nine deliberately broken variants now reach their intended assertions. |
| test_guardian_integration_organized_events | Corrected two stale expectations: a queue source of 2 identifies generic quicksave; no pause/gameplay subtype is invented. All 330 assertions pass. |
| installation_auditor | Fixed Windows path/handle timestamp semantics and a saved-byte SHA pin mismatch. The 94-test group now passes with the documented 21 host skips. |

Retired groups are recorded in the plan and TEST-DISPOSITION.json; they are not relabeled as passed. Prior version-frozen/historical source checks are superseded by a current working-runtime contract, current UI/event integration, and current scope/policy/mutation checks. Their originals and earlier failing results remain in the immutable preceding developer archives. The clean source package includes the current test closure instead of old release workflows, stale plans or historical logs.

## Proof of the actual fixes

The Windows failure was reproduced: path lstat and open-file fstat returned identical device, inode, size, mode, mtime and birthtime but different legacy ctime values. Cross-API identity now uses Windows creation time; each API's own change time is checked before/after reading. The old auditor fails the new positive timestamp regression. New mutation/replacement/reparse rejection cases still pass. The manifest pin now hashes the actual saved inventory bytes, not an LF template later converted to CRLF.

The auditor reports exact_match on the current clean release tree. File mutation, duplicate detection, privacy, budgets and invalid/unsupported input remain covered by its existing suite. No game policy was changed to make tests pass.

## Runtime, notifications and safety coverage

- All **18** runtime Lua files compile under the test host, including save_completion.lua, which the older fixed 17-file syntax list omitted.
- 58 release-contract assertions verify all 21 runtime entries, unique inventory coverage, auditor/package inventory equality, saved-byte SHA pins, active test coverage and the frozen user-tested game code. Seventeen runtime files are byte-identical to RC1. Four files contain only the exact version/menu/status presentation replacements recorded in BASELINE-RUNTIME.json. The new menu-label group passes 74 assertions covering both menus and persisted defaults.
- Core/Dark Future notifications: 12,256 assertions. Player-copy/source checks: 320 assertions, scanning 148 notification string literals. Completion notices: 26 actual-init assertions; completion tracker: 35 assertions.
- Status notifications: 10,566 assertions, 6,101 independent public-contract assertions, and all 11 mutation controls detected. Tone migration: 990 assertions.
- Guardian, combat/queue retention, phone manager, Dark Future states, autosave scheduling, settings recovery, manual presets and current UI/report integration pass their active tests. Deliberate mutation controls must fail at the intended assertions, not merely at missing imports or syntax errors.

## Reproduction and evidence boundary

Host: Python 3.12.14, Lupa 2.8 Lua 5.3, Windows. The optional requirements-test.txt pins the Python Lua host used here. Run:

    python docs/NeverLockSavesReborn/validation/run_release_checks.py --release . --output ../reborn-checks --lupa

Alternatively supply --lua with a compatible executable. Nested tests use that same explicit host through NLSR_LUA_COMMAND. No machine-specific launcher or sitecustomize patch is required. Redacted passing results and logs are included under validation-evidence/; the test plan retains reproducible command templates.

These are offline tests with explicit game/framework/UI boundaries and constrained REDscript-source execution. They are not native REDscript compilation or CET LuaJIT/game execution. The user-reported working predecessor is retained as runtime evidence without inferring exact framework versions or an exhaustive compatibility matrix. Callback success is not independent save-file/reload certification. Stable status does not extend the recorded compatibility evidence to untested configurations. Native game compilation and live menu rendering of these presentation-only edits have not been rerun here.

## Package and publication

Both runtime and clean source/testing archives receive complete SHA-256 manifests, safe unique path, CRC, inventory and decompressed-byte checks. The source/testing archive is extracted and its canonical suite rerun before handoff. Separate delivery receipts record the extracted-package rerun and authenticated GitHub asset readback; this document does not predict those future results. Original-author MIT permission/credits are retained. The stable release is published to the existing GitHub repository only after final package and extracted-source checks. Prior releases and tags are retained.
