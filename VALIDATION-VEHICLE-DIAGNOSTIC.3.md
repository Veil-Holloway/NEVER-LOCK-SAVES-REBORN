# Diagnostic.3 validation

October 25, 2026 (America/Los_Angeles). Build **1.0.0-vehicle-diagnostic.3**.

## Finding and minimal correction

The uploaded diagnostic.2 snapshots record native true for mounted-combat
quicksave attempts (latest serials 1 and 22), with Combat and Script locks.
The deferred queue is empty. This is observed live bridge/request evidence;
visible save creation/reload/progression remain unverified, with the user's
missing-save report still unresolved. No per-attempt history is inferred.
Both uploaded Lua reporter copies match the published diagnostic.2 reporter.

Guardian records zero requested and ten unavailable observer registrations;
quest observation is unavailable too. Exact CET 1.38 source establishes:
Scripting.Initialize loads mods before PostInitializeScripting exports observer
functions. ScriptContext executes init.lua immediately; onInit runs later.
Reborn captured the functions eagerly into two adapters during that first load.
Three wrapper injections now resolve the same observer globals when protected
registration runs in onInit. No new target, callback contract, API or dependency.

Primary source: CET commit ed706fb8518712ffedf6b566e52873b257bc49fb,
https://github.com/maximegmd/CyberEngineTweaks/blob/ed706fb8518712ffedf6b566e52873b257bc49fb/src/scripting/Scripting.cpp
and its ScriptStore.cpp, ScriptContext.cpp and Sandbox.cpp. The supplied framework
self-report is CET 1.38.0; installed binary fingerprint remains unknown.

## Fresh offline checks

Command: `python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output <CHECK_OUTPUT>`.
**72/72 groups pass, exit 0.** The extracted clean preflight full ZIP also passes
all 72 groups, exit 0. The placeholder source SHA is only preflight metadata; final
source provenance and all packaged bytes are verified independently at delivery. This includes the new actual-Lua cold-start test,
new exact source scope, all prior request/queue/autosave/settings checks and 89
installation-auditor tests. Python 3 and texlua provide the offline hosts.

- Cold-start regression: 163 assertions against actual init, Guardian ledger/
  transport, quest transport and deferred modules, with external CET/game/IO
  doubles. Globals absent during module evaluation, then provided before onInit,
  yield ten Guardian and one quest registration. No calls occur at module load.
- The same test against diagnostic.2 detects the expected cold-start gap (125
  assertions in baseline mode), while its warm-load control succeeds. This
  distinguishes initial load timing from missing target definitions.
- Callback tracking, quest resolution/dedup, repeated onInit, two CET-style
  reloads, missing APIs and throwing registration functions are covered.
  Observation alone creates no checkpoint. Save-completion callbacks stay
  uncorrelated hints; they never become write/reload proof.
- Exact scope permits the three injected wrappers, version labels and auditor
  inventory/pins. All preexisting fixtures are unchanged; prior preservation
  and mutation controls pass through complete hash-pinned normalization only.
- 14 of 16 runtime files remain byte-identical to diagnostic.2. REDscript changes
  version strings only. Save policy, checkpoint helper, locks, dispatch, queue,
  notification content and phone-state reader are unchanged.

Evidence is packaged in vehicle-diagnostic.3-integrated and
vehicle-diagnostic.3-regression under docs/NeverLockSavesReborn/evidence.
No raw user support file is uploaded or included in the release source.

## Evidence limits and next test

The first report has phone unknown and scheduler reason phone_unknown; the later
report has phone clear and reason combat_active. Their 5,479 and 33,605 resets
are scheduler resets, not save requests. Unknown dependency-version reads do
not prove a missing plugin. Neither field explains the accepted immediate
checkpoint. No unrelated phone or dependency change is made.

**NOT RUN:** .3 native compilation/CET gameplay, actual observer attachment and
completion callbacks, vehicle-combat save creation, reload/progression, Windows
recovery and full optional-mod compatibility. Registration acceptance itself
can be silent in CET; only observed callbacks establish actual callback execution.
Native true remains request-level evidence, not a save-write guarantee.

Baseline: diagnostic.2 source ad339b34ccbcb77422db0b4d804baa6bcb229f4b; Drive
runtime ID 1_VFEkyPNqFf4j2CBiAFYuscfUPxyuCFq, modified 2026-10-25T22:02:30.828Z.
Runtime ZIP SHA-256 fc1aff783861eac256cee9b75d52f5fbf30851f02757e48280afc4bfdb342ce8.
This is a known source baseline, not a verified vehicle-combat save release.

Cold-launch one .3 copy, confirm fresh compilation and version, turn Smart
Autosave OFF for the focused test, request once in Unrestricted vehicle combat,
then export support-report.json before another save request. Inspect native
request, registration/callback evidence and visible save outcome separately.
See RELEASE-NOTES for installation and rollback. No retry loop, native lock
removal, alternative force-save API or quest/save-data editing was added.
