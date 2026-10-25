# Never Lock Saves: Reborn — first release scope proposal

October 24, 2026 (America/Vancouver).
**Decision pending. This document does not change the agreed roadmap or promote a release.**

## Recommendation

Freeze the working preRC4 feature set for RC1 and explicitly schedule the missing
automatic identity, all-owned-safehouse and live write-correlation capabilities
for a later release. Use the candidate to complete acceptance records and prepare
the repository/support handoff. Stable/public status still needs the applicable
runtime, recovery and distribution records.

The alternative is to keep the complete roadmap mandatory before the first stable
release and continue development while preRC4 remains the working preview.
“Everything works” is accepted as your broad working report; it does not silently
remove features that the roadmap still requires.

## Exact build to preserve

- Runtime: **0.14.0-preRC4 Release Testing Preview / Developer Preview**.
- ZIP: `Never_Lock_Saves_Reborn_v0.14.0-preRC4_Release_Testing_Preview.zip`.
- Size: **459,091 bytes**.
- SHA-256: `f3f68651a12e91a0e7145375e11217818b38b2d9bb4c82b553fd61a9e341529c`.
- Drive file: `1__E1pN7mN-aPkvAZ9HazX3l7qUu06kLg`, modified `2026-10-24T18:07:00.564Z`.

A fresh authenticated download matched size, checksum, CRC, all 281 manifest
entries, unique archive paths and all 76 frozen source hashes. The archive has
16 runtime files: 13 Lua and 3 REDscript files. Its 51 integrated/extracted check
groups remain the previously recorded evidence for these identical bytes; this
scope review did not rerun them or claim new gameplay tests. No runtime edits or
new runtime version were needed for this decision.

Latest feedback: **“Everything works let's go.”** Recorded as user-reported working
preRC4 feedback. Exact installed fingerprint, versions and individual case results
have not been supplied. The existing 42-row matrix still contains one broad working
report, 38 unrecorded/UNTESTED cases and three UNAVAILABLE capability rows.

## Option A — current feature set for the first candidate

| Capability | First-release scope proposed |
|---|---|
| Save policy | Existing four modes, intro protection and optional one-item queue; current experimental mode labels/limits retained |
| Smart Autosave | Existing exploration, post-combat, vehicle-exit and verified quest-milestone triggers; original V apartment district entry only |
| Settings/profiles | Validated main-settings recovery and explicit named presets; user chooses the preset |
| Guardian | Request/queue/engine-submission history and bounded observer hints; written/reloaded states remain Unknown without independent evidence |
| Backups/recovery | Optional manually run Windows/Python companion with the game closed; verified copies, reversible retention/reactivation and separate confirmed restore |
| Notifications | Existing core/DF and queue-lifecycle messages; no written/reloaded success inferred from requests |
| Diagnostics | Local bounded support export, available API version declarations, explicit unknown/error/provenance states |
| DF integration | Existing read-only state readers and notification switches, with actually tested configurations documented accurately |

This option needs **explicit deferral** of the following roadmap requirements:

| Deferred requirement | Why it is not complete |
|---|---|
| Automatic persistent character/playthrough profiles | No verified current-loaded-playthrough getter is established. Manual named presets are a fallback, not automatic identity. |
| All-owned-safehouse entry triggers | Only the original apartment district is implemented. Other apartment location enums do not establish ownership or complete PL/modded coverage. |
| Automatic live backups and request-to-written/reloaded correlation | Current engine callbacks are uncorrelated hints and CET has no established ordinary save-folder bridge. The separate helper operates with the game closed. |
| In-game written/reloaded and backup/recovery completion notifications | These depend on real correlated events/bridges; the helper reports its own results outside the running game. |

Deferred items remain planned work. They are not renamed as completed features.
No quest-fact edits, guessed identities, generic safe-area inference or invented
save-completion claims substitute for these interfaces.

## Option B — complete the roadmap before the first stable release

Keep all the automatic features above in the first stable release's required scope.
Retain preRC4 as a working preview and continue focused interface research and
implementation. No candidate is called feature complete merely because its current
implemented features work. This option has no established completion date: the
missing supported interfaces remain real constraints.

## Acceptance records needed for either stable path

Record the tests already completed; do not repeat successful work solely because
its result has not yet been written into the matrix. Supply the exported local
`support-report.json` and identify the actual game/framework versions, manually
recording those the report cannot measure.

Record which four-mode/request/intro/queue/autosave/DF/settings cases were exercised,
and specifically whether save creation, reload and subsequent progression passed.
For the recovery companion, record the actual Windows copy/rotation/reactivation/
restore and restored-game results. Record clean update/rollback and the supported
optional-mod combinations. Leave unexercised cases untested rather than guessing.

The provided archive contains attribution but no verified upstream license or
permission record. The preferred MIT license has not been applied to the whole
derived package. Preserve attribution and resolve that record as part of the
public repository/distribution handoff; no licensing clearance is claimed here.
No repository was created, public release published or original author contacted
by this scope review.

## Next action after the choice

- **Option A:** record the deferrals, freeze RC1's defined feature contract, and
  prepare its acceptance handoff and local repository/support files against the
  working runtime. Stable promotion follows the recorded evidence and distribution
  status, not the version label alone.
- **Option B:** preserve the full roadmap and working preRC4, then pursue the
  missing automatic capabilities through verified supported interfaces.

**Choice to record: Option A or Option B. Until then, the existing roadmap and
Developer Preview designation remain in force.**
