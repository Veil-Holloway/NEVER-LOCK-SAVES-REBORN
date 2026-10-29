> Historical contract. Superseded for current scope by
> [the October 28 v2.6 addendum](Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md).
> Backup/recovery companion and automatic-character requirements below no longer apply.
> Original bytes are preserved in `history/pre-freeze-github-vehicle-diagnostic.3/`.

> Historical development snapshot. Current permission and acceptance status: [PUBLICATION-STATUS.md](PUBLICATION-STATUS.md).

# First-release feature contract — 1.0.0-rc1

October 24, 2026 (America/Vancouver). **Approved scope; release candidate for testing.**

The user replied **“Do it”** to the concrete request to prepare RC1 with Option A and explicitly defer the listed automatic capabilities until after 1.0. This records that decision. It supersedes the pending status in `Never_Lock_Saves_Reborn_First_Release_Scope_Proposal_v1.md` and the original roadmap's requirement to finish those capabilities before 1.0. Deferred work remains planned, rather than completed.

RC1 preserves preRC4 behavior with identification labels only. The candidate contains 16 runtime files: 13 Lua and three REDscript files. No framework binaries, user settings or game saves are bundled. The baseline is the 459,091-byte preRC4 ZIP with SHA-256 `f3f68651a12e91a0e7145375e11217818b38b2d9bb4c82b553fd61a9e341529c`.

## Included in the first-release scope

| Capability | Contract and limit |
|---|---|
| Save policy | Existing four modes; Smart/Unrestricted keep their experimental qualification. Native/intro guards and fail-closed unknown observations remain. |
| Deferred queue | Optional one-item queue, native stability/serial checks, configurable expiry/cooldown, replace/cancel/reset behavior and dry-run no-save path. Manual queue requests dispatch checkpoints. |
| Smart Autosave | Individually controlled exploration, post-combat, vehicle-exit and verified journal milestone triggers, plus known outside-to-inside entry to original V apartment district only. Native/intro/session/priority/cooldown checks remain. |
| Settings and presets | Validated main-settings recovery, versioned explicit named presets and optional Native Settings synchronization. Preset selection is a user action. |
| Guardian/diagnostics | Bounded request/queue/submission ledger and observer hints; on-demand sanitized support export and supported API version declarations. Written/reloaded stay Unknown. |
| Backup/recovery companion | Optional manually run Windows/Python closed-game tool: stable hash-verified copies, reversible active retention, reactivation, reviewed and explicitly confirmed restore to a new separate destination. No automatic live-slot installation. |
| Notifications/DF | Existing core/DF messages, three tones and pool rotation; optional queued/autoqueued/submitted/expired/cancelled/error messages. DF readers are read-only and the four DF switches control messages only. |

The original notification libraries are retained: 1,560 core/DF gender/tone entries plus 60 neutral introduction entries. The optional status library has 1,080 pool entries (54 × 20), using 360 distinct neutral texts shared across body profiles; those counts do not imply 1,080 distinct new sentences. Queue/UI handoffs never become written/reloaded claims.

## Explicitly deferred until after 1.0

| Requirement | Current boundary and future exit evidence |
|---|---|
| Automatic persistent character/playthrough profiles | Manual named presets ship. A supported getter for the currently loaded playthrough, persistence/migration and cross-character tests are still required. Save-menu/latest-save metadata is not a substitute. |
| Triggers for every owned safehouse | Only `LittleChina_VApartment` entry ships. Verified location, ownership and supported base/PL/modded coverage are required before expanding it. Apartment enums alone do not establish ownership. |
| Automatic live backups and request-to-write/reload correlation | Engine callbacks remain uncorrelated hints; the separate helper requires the game closed. A real supported file bridge and correlated events must be demonstrated before automatic protection claims. |
| In-game written/reloaded and backup/recovery completion notifications | Await the correlated events/bridge above. The helper reports its own external operations; dispatch and hash verification cannot manufacture game-completion evidence. |

No quest-fact writes, guessed identities, generic safe-area heuristic, sandbox escape or save-byte modification substitutes for the missing interfaces.

## Acceptance and promotion

RC1 is ready for candidate testing once its source-preservation, portable checks and package verification pass. The validation report is the evidence record; this contract does not assert their results in advance.

The user's “Everything works let's go” is retained as broad user-reported preRC4 feedback. It does not supply exact installed versions, the package fingerprint or per-case evidence. The game matrix retains one USER_REPORTED_WORKING row, 38 UNTESTED rows and three UNAVAILABLE deferred capability rows. Record tests already completed; no repeat is required solely because a result was not written down.

Before stable promotion, record the exact supported environment and relevant fresh compile/runtime logs, exercised modes/request/intro/queue/autosave/DF/settings cases, actual save creation/reload/progression, Windows companion and restored-game results, clean install/update/rollback, and material performance/compatibility observations. Narrow supported configurations honestly if combinations remain untested. Duplicate dispatch, lost recovery copies, failed reload/progression or another unresolved high-severity regression blocks promotion.

Attribution is retained, but no verified upstream license or redistribution permission record is present. Resolve that record before public repository/distribution publication; no whole-package MIT grant or public release clearance is claimed. This scope approval does not create a public repository, publish a stable release or contact the original author.
