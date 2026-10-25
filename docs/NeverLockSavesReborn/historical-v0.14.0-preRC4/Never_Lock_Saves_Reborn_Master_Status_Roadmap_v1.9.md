# Never Lock Saves: Reborn — status and roadmap v1.9

October 24, 2026 (America/Vancouver).
Current output: **0.14.0-preRC4 Release Testing Preview / Developer Preview**.

The user reports “It works let's go” after preRC3. This is recorded as current-build
working feedback with unspecified fingerprint, versions and case coverage. New
preRC4 native/API/game acceptance remains unverified here.

## New diagnostic improvement

Explicit support export now reads source-backed CET and Codeware version strings
and Native Settings' numeric module declaration. The collector is optional, fresh
on every export, and inactive outside export. Flat dependency strings are retained,
Codeware is added, and fixed status/source evidence separates observed, unavailable,
invalid, failed, unsupported and unsampled values. Raw API errors/objects and unsafe
strings are excluded. Native Settings numeric metadata is not an exact package label.

REDscript, RED4ext and Dark Future versions remain unknown: no suitable getter
was established. A version observation does not prove installation completeness,
compatibility, current compilation or save/reload safety. No dependency or setting
is added; no game-save, quest, queue, scheduler or helper policy changes are made.

Fresh **51 integrated and extracted groups pass**, including all prior 46. New evidence includes
834 collector assertions, 554 report assertions, 16,590 independent assertions across
38 actual-init fixtures, 13 detected new negative controls and exact source identity
outside the diagnostic seams. Tests use Lua 5.3 and controlled CET/Game/UI/store
boundaries; they are not Windows, native ABI, compiler or gameplay acceptance.
Final extracted-package evidence is provided in the validation report.

## Roadmap position

| Target | Delivered scope | Remaining exit criteria |
|---|---|---|
| Stabilization | User-reported working preRC3; main-settings recovery retained, fresh source-preservation checks | Actual native/API versions, fresh compile/runtime, compatibility/save/reload matrix |
| v0.11 Guardian/recovery | Bounded ledger, stable verified closed-game copies and reversible recovery workflow | Correlated engine writes/live copying, Windows and restored-game progression |
| v0.12 Smart Autosave | Four prior triggers plus original V apartment district, with native/intro/serial/cooldown guards | Broader owned-safehouse coverage and actual trigger/save/reload observations |
| v0.13 profiles/diagnostics | Validated main settings/manual presets, fresh bounded snapshots and on-demand version evidence | Automatic current-loaded-playthrough identity, actual exported report and restart evidence |
| v0.14 polish | Optional lifecycle messages, shared cancel, settings backup recovery, package/source/rollback checks | Real UI/performance/compatibility, update/rollback and restore testing |
| v1.0 stable | Not released | Outstanding capabilities or explicit scope revision, repeatable compatibility/reload/progression and redistribution permission |

## Next test

Install preRC4 with retained rollback copies, inspect fresh logs, then click
**Export support report**. Provide the local `support-report.json` with actual
save/reload/progression outcomes and fill the 42-row matrix for what was tested.
Record unmeasured dependency versions manually. Unknown outcomes remain unknown.

Rollback: close game, remove `dependency_versions.lua`, and reinstall complete
preRC3 with its retained config/preset bank. No settings fields or preset schema
change in preRC4. The old preRC2 installation checker remains pinned to preRC2 and
will correctly report this newer build as changed.

Automatic identity still lacks a verified currently loaded playthrough getter.
Additional apartment location enums do not establish ownership; no all-safehouse
whitelist is invented. No quest facts/save bytes are modified to manufacture identity
or success. Written/reloaded/progressed states never follow from queueing, dispatch,
UI handoff or stable hashes alone. These remain explicit release constraints.
