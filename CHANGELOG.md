# 1.0.0-rc2 — autosave-system type correction

October 24, 2026 (America/Los_Angeles). **Release candidate for testing.**

The uploaded REDscript log reports an unresolved `AutoSaveSystem` type in Reborn's
deferred checkpoint-dispatch method. RC1 contains that declaration, so its prior
broad working report does not establish compilation success for the reported
installation.

- Replaced that variable's `ref<AutoSaveSystem>` annotation with the verified
  `ref<gameAutoSaveSystem>` type returned by `GameInstance.GetAutoSaveSystem`.
- Updated eight runtime identification labels to `1.0.0-rc2`.
- Refreshed the installation auditor's 16-file pins and focused regression/source
  preservation coverage. The validation report records the actual results.
- Updated the test handoff and roadmap; retained the reported compiler failure
  as history without converting untested gameplay cases to passes.

The queue guards, checkpoint call, settings, DF readers/messages, autosave policy
and recovery companion are retained. Fourteen other runtime files and all five
existing recovery-companion files are byte-identical to RC1. No runtime file,
setting, schema, dependency or first-release scope change is introduced.

The source fix addresses the logged declaration. Post-fix native compilation,
launch, actual save/reload/progression and Windows recovery remain acceptance
checks. Retest with fresh logs before gameplay testing. Permission is still
pending; stable/public promotion and the unfinished GitHub handoff remain paused.


---

## Historical release notes

# 1.0.0-rc1 — first-release feature freeze

October 24, 2026 (America/Vancouver).

- Accepted the user's approval of Option A in the first-release scope proposal. The current implemented feature set is frozen for RC1 and the first stable release's scope.
- Promoted the working preRC4 behavior to a release candidate for testing, with runtime identification labels updated to `1.0.0-rc1`. No queue, save-policy, scheduler, notification selection, settings/preset schema, observer, DF reader or companion behavior is changed.
- Published the first-release feature contract, current install/update/rollback instructions, testing handoff and roadmap v2.0. Automatic identity, all-owned-safehouses, automatic live backups and correlated write/reload/completion notifications remain planned after 1.0.
- Retained the user's broad working preRC4 report. Individual runtime/Windows/compatibility cases remain unrecorded; offline checks do not fill those rows.

Baseline ZIP: `Never_Lock_Saves_Reborn_v0.14.0-preRC4_Release_Testing_Preview.zip` (459,091 bytes), SHA-256 `f3f68651a12e91a0e7145375e11217818b38b2d9bb4c82b553fd61a9e341529c`.

RC1 is a testing milestone. Stable/public promotion still requires supported-environment acceptance and a resolved upstream distribution/attribution record. Earlier changelog entries and evidence remain historical.


---

## Earlier changelog entries (historical)

# Changelog

## v0.14.0-preRC4 — On-demand dependency diagnostics / Developer Preview

- Read available CET, Codeware and Native Settings version declarations only on
  explicit support export. Each export samples fresh values; no background polling.
- Keep existing dependency strings, add Codeware and fixed status/source evidence.
  Unsupported/unavailable/error/invalid values remain explicit and bounded.
- Preserve unknown REDscript/RED4ext/Dark Future versions; no private DF migration
  constant, filename or guessed method is substituted for an installed version.
- Isolate malformed collectors and failed readers so useful report output continues;
  raw API errors/objects/private text are not exported.
- Preserve game policies/settings/queue/observers/helpers and preRC3 recovery.
  Add primary-source pins, actual-init checks, negative controls and rollback notes.

## v0.14.0-preRC3 — Main settings recovery / Developer Preview

- Validate all present recognized main-settings fields before accepting a primary
  config or rotating it over a backup. Invalid primary settings now recover a
  validated `.bak`; failed replacement preserves that sole valid recovery copy.
- Use the same validator for startup loading, ordinary settings writes and
  preset application. Failed preset persistence retains runtime and pending work.
- Preserve partial legacy objects, ignored obsolete string keys, defaults and
  the existing within-range mode/tone flooring behavior. No new config schema
  marker or future-format migration is added.
- Carry preRC2 game policies, notification libraries, scheduler, observers and
  recovery companion unchanged; runtime version labels advance for identification.
- Add actual-init/real-disk regression checks and explicit source-preservation
  evidence. Current game/Windows tests remain outstanding.

## v0.14.0-preRC2 — Recovery and status polish / Developer Preview

- Recover schema-invalid preset data through validated backups; protect valid
  backup bytes on replacement failure and refuse unknown future schemas.
- Expose shared cancellation in automatic-only operation and clarify lane status.
- Add opt-in six-state notifications with independent twenty-entry pools,
  coalescing, throttling, bounded history and transactional shuffle advancement.
- Add default-OFF original V apartment district-entry scheduling and invalidate
  apartment work on departure before handoff or dispatch.
- Refresh support snapshots on demand; add bounded observer, native-lock and
  status-message evidence while retaining Unknown write/reload outcomes.
- Preserve save-policy methods, core/DF libraries and all companion mutators.
  Three request hooks change only a notification-suppression condition.
- Bundle current tests/evidence and references to retained original archives;
  document config/preset rollback and the limited apartment coverage.

PreRC1 was user-reported working with unspecified coverage. New runtime cases
remain untested. Automatic character binding, complete safehouse coverage,
independent write/reload correlation and stable public release remain open.

## v0.14.0-preRC1 — Release Testing Preview / Developer Preview

- Make Smart combat/vehicle controls enforce a precise native Combat-only lock
  whitelist. Reject mixed and unknown reasons; vehicle permission is mounted
  combat permission, never a fabricated vehicle-only lock classification.
- Add separately opt-in native-gated custom checkpoint scheduling, a bounded
  journal event adapter, cooldown/deduplication, pause/session resets and player
  queue priority. Native autosaves remain unchanged.
- Add configurable deferred TTL and cooldown, manually selected settings presets
  and explicit bounded support export. Preserve unknown identity, dependency
  versions and independent save-write/reload evidence.
- Add optional closed-game diagnostic/source inspection and recovery inventory
  commands. Preserve prior copy/retirement/reactivation/restore mutators.
- Preserve existing DF/message libraries and all three manual request hooks;
  retain introduction and request-time serial/native gates.
- Bundle source-backed interface evidence, regression/independent tests,
  manifest/provenance, focused gameplay matrix and alpha2 rollback instructions.

This is a release-testing handoff, not completion of every roadmap requirement.
Safehouse triggers, automatic persistent playthrough identity, live automatic
backups, runtime compatibility and independent save/reload/progression remain
open. Upstream public redistribution permission remains unverified.

## v0.11.0-alpha2 — Reversible Backup Rotation / Developer Preview

- Add explicit profile/keep opt-in to the optional closed-game helper, with exact
  source-folder digest/character metadata streams, UTC chronology and minimum
  protected active-copy count of two.
- Publish/verify a new snapshot before reversible retirement. Hold an exclusive
  global lock across profiled publication and rotation. Use owned same-filesystem
  rename only, never overwrite an old snapshot or permanently delete one.
- Add previewed-plan confirmation, partial moved/remaining reports, retired-copy
  listing and confirmed reactivation. Retired snapshots must be reactivated before
  normal new-directory restoration.
- Recheck process, store ownership, protected/candidate hashes and destinations
  after preparatory journal IO and immediately around moves.
- Preserve original schema1 snapshots and legacy helper calls; invalid/unmanaged
  snapshots are untouched. Update source/time validation and tests.
- Core gameplay files change only explicit version strings; existing save hooks,
  policies, tracker implementation, settings, DF and messages remain alpha1.

Status: fresh offline suites pass. Actual Windows rotation/reactivation,
real restored-save loadability and quest progression remain unverified. Retired
copies consume storage; no permanent pruning or automatic in-game backup is added.

## v0.11.0-alpha1 — Save Guardian Foundations / Developer Preview

- Add opt-in bounded request ledger, run/session/serial correlation and explicit
  unknown write/reload evidence. Add telemetry-only CET observers for original
  sources/queue mutations and unassociated engine-result hints.
- Add CET/Native Settings synchronization, recent history and explicit sanitized
  local report export. Tracking errors and toggles cannot change save policy.
- Observe existing deferred lifecycle, including consumed expiry/rejection states.
- Add optional manually run Windows/Python closed-game snapshots, hash checks,
  recovery preview and confirmed new-directory restoration. Retention preview
  deletes nothing; automatic rotation and in-game backup remain planned.
- Preserve all REDscript methods except the version label; retain original hook
  bodies, DF readers/messages, deferred_save.lua and config_store.lua unchanged.
- Bundle new and existing checks, source evidence, rollback and updated roadmap.

The user's v0.10.4b smoke pass does not certify this new build or the complete
compatibility matrix. No independent in-game write/reload, automatic backup,
live-slot restoration, custom autosave or Smart classifier is delivered.

## v0.10.4b — retained working smoke-test baseline

Configuration-backup recovery and fresh-intro fallback guard fixes. Retained
complete for rollback. Full earlier compatibility/save-reload coverage was not
separately supplied by the user's smoke-test report.
