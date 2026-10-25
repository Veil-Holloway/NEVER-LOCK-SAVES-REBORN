# Never Lock Saves: Reborn — status and roadmap v2.0

October 24, 2026 (America/Vancouver). Current target: **1.0.0-rc1, release candidate for testing**.

## Approved first-release scope

The user approved Option A by replying **“Do it”** to the concrete RC1 proposal: freeze the current working feature set and explicitly defer the missing automatic capabilities until after 1.0. This revision supersedes the pending decision and the original v1.1 roadmap's before-1.0 scope for those capabilities. It does not mark them complete or promote the mod to stable/public release.

RC1 carries forward preRC4 behavior with runtime identification labels only. Baseline ZIP: `Never_Lock_Saves_Reborn_v0.14.0-preRC4_Release_Testing_Preview.zip`, 459,091 bytes, SHA-256 `f3f68651a12e91a0e7145375e11217818b38b2d9bb4c82b553fd61a9e341529c`. There are 16 runtime files: 13 Lua and three REDscript. The current release contract defines the authoritative scope; earlier preview contracts and plans remain historical.

The user reports preRC4 working. Exact installed fingerprint, versions and individual coverage were not supplied. The 42-row matrix retains one broad USER_REPORTED_WORKING report, 38 UNTESTED cases and three UNAVAILABLE deferred capabilities. Record already-completed results without inventing precision or requiring unnecessary repetition. The RC1 validation report records fresh offline/package evidence separately.

## First-release feature position

| Area | Included in RC1/first stable scope | Remaining acceptance |
|---|---|---|
| Modes/introduction | Four modes, experimental Smart/Unrestricted, guarded intro policy; Smart explicit combat-lock whitelist and mounted opt-in | Actual mode/request/intro/native-lock cases, save/reload and progression |
| Deferred queue | Optional one item, configurable expiry/cooldown, guarded checkpoint dispatch, cancellation and dry-run | Manual/automatic priority, lifecycle and duplicate prevention in-game |
| Smart Autosave | Exploration, post-combat, vehicle exit, verified milestones and original `LittleChina_VApartment` entry only | Actual trigger boundaries, deduplication, native stability and save/reload results |
| Settings/profiles | Validated main settings and backup recovery, explicit named presets, optional Native Settings sync | Actual restart, failure retention, update/rollback and supported UI combinations |
| Guardian/diagnostics | Bounded request/queue/submission ledger and observer hints, local sanitized support export with supported version declarations | Native/export behavior, current installed versions and performance observations; written/reloaded stay Unknown |
| Recovery companion | Optional manually run closed-game Windows/Python hash-verified copies, reversible retention/reactivation and confirmed separate restore | Actual Windows/process/filesystem and restored-game reload/progression |
| Notifications/DF | Original core/DF libraries, three tones/rotation, optional queue-lifecycle status; read-only DF readers and message-only DF switches | Actual tone/context/pool/DF absent-present-combined/partial regression and noninterference |

## Deferred until after 1.0

| Capability | Required next evidence |
|---|---|
| Automatic persistent playthrough/character binding | Supported currently loaded playthrough getter, identity lifecycle and migration/cross-character tests; manual presets remain first-release fallback |
| All-owned-safehouse entry triggers | Source-backed ownership/location interface and defined base/PL/modded support; other apartment enums alone are insufficient |
| Automatic live backups and request-to-written/reloaded correlation | Supported file bridge and independently correlated engine events, robust copying/recovery tests; current helper requires game closed |
| In-game written/reloaded and backup/recovery completion messages | The real correlated event/bridge above, preserving all request/queue/submission/verification distinctions |

No completion date is promised for missing supported interfaces. No guessed metadata, quest-fact mutation, generic safe-area heuristic, sandbox escape or save-byte edits substitute for them.

## Next release stages

1. **RC1 package and handoff:** freeze the defined feature contract, verify label-only source changes and portable regression/package checks, retain complete rollback copies, and provide install/testing/support documents.
2. **Candidate acceptance:** record the exact environment and existing/new game results, including actual save creation, reload/progression, supported optional-mod configurations, settings persistence, Windows restore and install/update/rollback. Failures become reproducible fixes and a new candidate when warranted.
3. **1.0 stable/public decision:** promote only after repeatable supported-environment evidence and distribution/attribution status are resolved. Experimental mode qualifications remain unless evidence and a deliberate scope change justify otherwise. High-severity regressions block promotion.
4. **Later releases:** pursue the explicitly deferred automatic capabilities through verified interfaces and focused acceptance contracts.

Attribution to user-provided Never Lock Saves v2.2.1.0 is retained. The baseline contains no verified upstream license/redistribution permission record; no whole-package MIT grant is asserted. No public repository, public release or author contact is performed by this roadmap update.

## Traceability

The supplied master roadmap v1.1 remains the original requirements/history source. Proposal v1 records the concrete alternatives; the user's approval selects Option A. `RELEASE-CONTRACT-1.0.0-rc1.md`, `TESTING-RC1.md`, the current matrix and validation report are the candidate handoff. Historical preRC4 and earlier validation retains its original environment/coverage limits and is not reclassified as fresh RC1 game evidence.
