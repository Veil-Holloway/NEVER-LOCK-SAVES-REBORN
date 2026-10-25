# Never Lock Saves: Reborn — status and roadmap v1.6

October 24, 2026 (America/Vancouver). Current output:
**0.14.0-preRC2 Release Testing Preview / Developer Preview**.

Baseline: freshly downloaded preRC1, SHA-256
`8956ab9594ab3ef31e8c3dbb2efc5df7649fc5a7310455af31ca739f47868735`.
User report: “It works let's go.” This records working preRC1 feedback with
unspecified coverage, and permission to continue. It does not close every game
or Windows acceptance row. Planning version numbers are not milestone passes.

## Current progress

| Planning target | Current delivered code | Remaining exit criteria |
|---|---|---|
| Stabilization | User-reported working preRC1; original mode/intro/DF/message policies retained; three reproduced UI/persistence/report gaps repaired | Exact runtime versions and full compatibility/save/reload matrix |
| v0.11 Guardian/recovery | Bounded lifecycle ledger, hash-verified closed-game copies, reversible rotation/reactivation/restore and recovery inventory | Engine write correlation, live backups, Windows behavior and restored-game progression |
| v0.12 Smart Autosave | Four prior triggers plus default-OFF original V apartment district entry; player priority, cooldown, native/intro/serial gates | Broader safehouse coverage and actual trigger-to-save-to-reload testing |
| v0.13 profiles/diagnostics | Schema-aware manual presets with future-version protection; fresh bounded observer/lock/status support snapshot | Automatic current-playthrough identity, real failing-case report and restart evidence |
| v0.14 polish | Shared automatic-only cancellation; optional lifecycle notification pools; current package/rollback and steady-state call-budget checks | Game UI/compatibility/performance, clean update/rollback and restore evidence |
| v1.0 stable | Not released | Remaining capabilities or agreed scope revision, repeatable save/reload/progression and compatibility evidence, recoverable rollback and upstream redistribution permission |

Forty-three integrated/extracted check groups pass. They use Lua 5.3, actual
module/source evaluation and doubled engine boundaries, not a current REDscript
compiler, CET/LuaJIT or game. See VALIDATION-REPORT.md for exact counts and scope.

The original-apartment trigger identifies `LittleChina_VApartment`, not every
owned safehouse. First sampling inside or after unknown data cannot infer entry.
Modern metadata's playthroughID field is not a verified current-loaded-playthrough
getter. Automatic character binding remains unavailable; no quest/save mutation
is used as a substitute. Manual named presets are explicit fallback behavior.

New status messages distinguish queueing, submission, expiry, cancellation and
errors. No state advances to Written or Reloaded from a toast or dispatch. UI
bridge acceptance is also distinct from actual visibility. Original core/DF
pools remain untouched. New status inventory is published separately by
event/tone/body; 1,080 entries use 360 distinct neutral-worded texts.

Next gate: test preRC2's cancellation, preset recovery/future-schema refusal,
status channel, apartment boundary and fresh report on disposable data using
IN-GAME-TEST-PLAN.md. Preserve preRC1 and its settings/preset bank for rollback.
Record exact package hash, versions and outcomes in TEST-MATRIX.csv. No stable
promotion follows from unspecified smoke feedback alone.
