# Contribution and release preparation

The October 28, 2026 [v2.6 scope freeze](docs/NeverLockSavesReborn/Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md)
and README govern current work. Earlier release contracts are historical where
they conflict. No major subsystem is planned before first stable release.

Preserve all four save modes, introduction protection, deferred queue, existing
Smart Autosave, bounded Guardian request tracking, optional settings
synchronization, manual presets, Dark Future read-only readers and message-only
switches. Excluded game-save backup/retention/storage/recovery systems and
automatic character identity/configuration binding must not be reintroduced.
Never infer written/reloaded success from native acceptance, alter native locks,
edit quest facts as a workaround or modify game-save bytes.

Use focused changes and the verification commands in
PACKAGING-SCOPE-RECONCILIATION.md. Record commands, exit status and limits.
Historical identity fixtures remain intact; failures caused by the scope removal
must be distinguished from current runtime regressions. Actual native/game
acceptance is separate from offline results.

Do not bundle private settings/reports/saves/logs, framework binaries or caches.
Preserve MIT, RalphModding's attribution and PERMISSION.md. Existing published
tags/assets and test evidence remain unchanged. Review packages need a unique
package revision, checksums/manifests and rollback instructions. This source
reconciliation authorizes neither stable publication nor merging PR #1.
