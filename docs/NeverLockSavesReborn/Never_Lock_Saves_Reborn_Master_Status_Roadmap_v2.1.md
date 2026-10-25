# Never Lock Saves: Reborn — status and roadmap v2.1

October 24, 2026 (America/Los_Angeles). Current candidate: **1.0.0-rc2**.

## Current finding and correction

The latest uploaded REDscript compiler log reports `UNRESOLVED_TYPE` for
`AutoSaveSystem` in Reborn's deferred-dispatch declaration. That declaration is
present in RC1 source. The actual compiler failure supersedes broad working
feedback for release clearance; it does not supply an exact installed package
fingerprint or complete game/framework version matrix.

RC2 uses `ref<gameAutoSaveSystem>`, matching the verified type returned by
`GameInstance.GetAutoSaveSystem`, and updates eight runtime version labels. The
checkpoint call and existing guards are unchanged. Fourteen other runtime files
and all five existing recovery-companion files remain byte-identical to RC1.
No new runtime file, settings schema or dependency is introduced.

The correction addresses the reported source cause. The post-fix native compiler,
game launch, save/reload/progression and Windows recovery outcomes remain
unverified here. The current validation report records fresh offline/package
checks without presenting them as native or gameplay evidence.

## Approved first-release scope retained

The user approved Option A: freeze the current feature set and explicitly defer
the missing automatic capabilities until after 1.0. RC2 does not change that
decision or promote the candidate to stable/public release.

| Area | First-release scope |
|---|---|
| Save policy/intro | Four modes; Smart and Unrestricted remain experimental; introduction/native guards retained |
| Queue | Optional one-item checkpoint queue, configurable expiry/cooldown, cancellation, priority/session/native/serial/stability checks and dry-run |
| Autosave | Exploration, post-combat, vehicle exit, verified journal milestones and original `LittleChina_VApartment` entry only |
| Settings/profiles | Validated main-settings recovery, explicit named presets and optional Native Settings sync |
| Guardian/diagnostics | Bounded request/queue/submission ledger and hints, sanitized on-demand support export; written/reloaded remain Unknown |
| Recovery | Optional manually run closed-game Windows/Python verified copies, reversible retention/reactivation and confirmed separate restore |
| Messages/DF | Existing core/DF pools and optional queue-status messages; read-only DF state readers and message-only DF switches |

Deferred after 1.0: automatic persistent playthrough/character binding;
all-owned-safehouse triggers; automatic live backups and request-to-written/reloaded
correlation; dependent in-game write/reload/backup/recovery completion messages.
These remain planned work, not completed features.

## Next stages

1. **RC2 delivery and compile retest:** verify the focused source correction and
   packaging, install one complete candidate, launch with the existing dependency
   setup and inspect fresh REDscript/CET logs. Confirm `1.0.0-rc2` and actual compile
   success. Address a new first compiler error if one appears before gameplay tests.
2. **Candidate acceptance:** record the exact supported environment and actual
   affected queue/checkpoint/save/reload/progression results, plus the settings,
   optional-mod, Windows recovery and install/update/rollback cases exercised.
   Preserve unknown and untested outcomes; avoid unnecessary repetition of already
   recorded unaffected tests.
3. **Repository/public release preparation:** resume the private GitHub handoff
   after the compile retest and release records. The user will arrange upstream
   modification and redistribution permission. Public publication remains paused;
   no whole-package MIT grant is assumed.
4. **Stable 1.0 decision:** promote only after recorded supported-environment
   acceptance, resolution of material regressions and publication terms. Candidate
   labels and portable checks alone do not establish stable status.
5. **Later releases:** pursue the explicitly deferred automatic capabilities through
   verified supported interfaces and focused acceptance contracts.

## Evidence and attribution

The test matrix preserves the original 42 rows and statuses and adds the reported
RC1-declaration compiler failure as history. Prior broad preRC4 and RC1 working
reports remain attributed as reports, not exact per-case passes. No exact game or
framework support version is invented from screenshots or general feedback.

Based on user-provided Never Lock Saves v2.2.1.0 by RalphModding. The original
[Nexus mod page](https://www.nexusmods.com/cyberpunk2077/mods/9662) records restrictive
modification/redistribution terms. Permission has not yet been obtained; the user
will arrange it. A permission request remains a separate unsent draft. No public
repository, public release or original-author contact is performed by this update.

The v1.1 roadmap remains the original requirements/history source; v2.0 records
the approved first-release scope. This revision adds the concrete compiler failure,
focused RC2 correction and compile-first acceptance sequence while preserving
those approved post-1.0 deferrals.
