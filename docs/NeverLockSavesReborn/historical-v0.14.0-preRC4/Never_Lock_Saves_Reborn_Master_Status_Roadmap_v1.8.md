# Never Lock Saves: Reborn — status and roadmap v1.8

October 24, 2026 (America/Vancouver).
Current output: **0.14.0-preRC3 Release Testing Preview / Developer Preview**.

The user reports “It works let's go” after the preRC2 acceptance kit. Working
feedback is recorded with unspecified package fingerprint, versions and case
coverage. It does not independently pass every gameplay or Windows test row.

## New release-hardening fix

A reproduced main-config defect let a JSON-valid but semantically invalid
primary hide a valid backup and overwrite it on the next settings save. preRC3
adds the same known-field validator to main loading, ordinary saving and preset
application. Recovery reads do not rewrite files; a failed recovered-settings
replacement preserves the valid backup. Legacy partial configs, ignored unknown
string keys and existing mode/tone flooring remain supported. No new main-file
schema marker or future migration is claimed. Preset-bank protections are retained.

Fresh verification: **46 integrated and extracted check groups pass**, including all prior 43,
480 author assertions across 43 real-file fixtures, 277 independent assertions
across 27 fixtures, three intended call-site mutation controls and full-source
preservation checks. Final extracted-package results are in the validation report.
The tests use Lua 5.3 and doubled engine/JSON/UI boundaries, not actual Windows,
CET LuaJIT, a current REDscript compiler or the game.

## Roadmap position

| Target | Delivered scope | Remaining exit criteria |
|---|---|---|
| Stabilization | User-reported working preRC2; reproduced main-config recovery/rotation repaired in preRC3 | Actual versions, fresh compile/runtime and compatibility/save/reload matrix |
| v0.11 Guardian/recovery | Bounded ledger, stable hash-verified closed-game copies, reversible rotation/reactivation/restore and recovery inventory | Engine write correlation/live copying; Windows and restored-game progression |
| v0.12 Smart Autosave | Four prior triggers plus original V apartment district entry, with native/intro/serial/cooldown gates | Broader owned-safehouse support and actual trigger/save/reload tests |
| v0.13 profiles/diagnostics | Validated main settings and manual presets, fresh bounded support snapshots, preRC2 installation acceptance kit | Automatic current-loaded-playthrough identity, live failing-case report and restart evidence |
| v0.14 polish | Optional lifecycle messages, automatic-only cancellation, settings-backup protection and source/rollback audit | Real UI/performance/compatibility, update/rollback and restore observations |
| v1.0 stable | Not released | Remaining capabilities or explicit scope revision; repeatable compatibility/reload/progression and redistribution permission |

## Genuine capability constraints

Modern metadata has a playthrough ID, but no supported current-loaded-playthrough
getter has been established. Manual presets remain the fallback; no quest facts
or save bytes are edited to manufacture identity. The four additional apartment
district enum names establish locations, not ownership. Their purchase-offer UI
records do not prove rental/ownership; no all-safehouse whitelist is invented.
Original-apartment coverage remains limited. UI acceptance, queueing, checkpoint
submission and stable disk hashes never imply correlated Written or Reloaded.

## Next test and rollback

Retain complete preRC2 and copies of its main config, preset bank and `.bak`
files. Install preRC3, inspect fresh logs and exercise the new main-settings
recovery/failure cases on disposable settings. Record actual versions and each
save/reload/progression result in the 37-row matrix. Preserve unknown outcomes.

The preRC2-only installation auditor remains pinned to its exact release and
will flag preRC3 as changed; use this build's manifest/version/checksum. preRC3
adds no settings fields or preset schema changes. Rollback is a complete preRC2
reinstall with its retained configuration and preset-bank backups.
