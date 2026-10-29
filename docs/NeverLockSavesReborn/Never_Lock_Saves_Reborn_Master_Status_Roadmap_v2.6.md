# Never Lock Saves: Reborn roadmap v2.6 addendum — scope freeze

Evidence date: October 28, 2026. This addendum supersedes future-scope items in earlier roadmaps where they conflict. Historical roadmaps remain for provenance.

## Approved scope removals

The following are removed from the product roadmap and are not release requirements:

- game-save backup creation, rotation, retention, hashing or storage management;
- Save Recovery Assistant and any save restore workflow;
- backup-copy integrity monitoring;
- automatic character/playthrough profiles, character identity detection, per-character settings binding or migration.

The previously shipped closed-game `tools/NLSRSaveGuardian` companion is removed from current source/package scope. Historical evidence may still mention it.

## Retained systems

- Vanilla, Immersion, Unrestricted and Smart save modes;
- event-driven Deferred Save queue with native-lock, combat, phone, lifecycle and stabilization checks;
- Smart Autosave triggers already implemented in current source;
- completion evidence / one-in-flight protection and bounded Guardian request ledger;
- Dark Future read-only compatibility and contextual notifications;
- CET overlay, Native Settings synchronization, validated settings persistence and on-demand support reports;
- explicit manual named settings presets. These are not character profiles.

Completion tracking remains safety/diagnostic plumbing. It does not perform backups or restoration and must preserve unknown outcomes honestly.

## Frozen feature scope

No new major feature subsystem is planned before first stable release. Remaining work is validation, bug fixing, compatibility and release polish.

### Release-candidate acceptance

1. Validate all four save modes and supported manual/pause/gameplay request paths in-game.
2. Validate Smart Autosave exploration, post-combat, vehicle-exit, apartment and verified quest-milestone triggers with deduplication/cooldown and actual save/reload checks.
3. Regress combat, vehicle combat, phone calls, native relocks, session changes, death/reload and cyberpsycho/quest progression on disposable saves.
4. Validate Dark Future absent/present states and message-only noninterference.
5. Validate CET/Native Settings synchronization, restart persistence, manual presets and clean install/update/rollback.
6. Publish the exact supported game/framework matrix, known limitations, install instructions, changelog, attribution/license and test evidence.

### Stable acceptance

Stable requires representative real-game save creation, reload integrity and quest-progression tests on supported versions, with no unresolved high-severity regression. Backup/restore workflows and character-profile persistence are explicitly not part of stable acceptance.
