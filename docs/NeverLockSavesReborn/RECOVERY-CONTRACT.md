> Historical contract. Superseded for current scope by
> [the October 28 v2.6 addendum](Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md).
> Backup/recovery companion and automatic-character requirements below no longer apply.
> Original bytes are preserved in `history/pre-freeze-github-vehicle-diagnostic.3/`.

# Optional recovery assistant release contract

Scope: extend the existing manually run stdlib companion, without changing game
runtime, snapshot format, backup/restore mutators, retention, or reactivation.

1. `doctor` reads an existing backup root, reports process-guard state, disk
   capacity, pending stages, lock presence and retired-store ownership. It never
   removes locks, stages, files, or markers. A present lock is not declared stale.
2. `inspect-source` requires a closed-game guard, observes a selected slot's
   complete inventory twice, and reports stable source hashes, file timestamps,
   source fingerprint and observation time. It does not infer an engine write,
   Guardian request correlation, loadability, or quest progression.
3. `recovery-plan` verifies both active and owned retired snapshots, reports bad
   copies as invalid, and lists explicit safe next actions with identifiers.
   Optional profile/character filters are exact user metadata, not automatic
   character detection. Invalid snapshots never become copy candidates.
4. All new commands are read-only. Existing mutators and their format/security
   contracts remain unchanged. No guessing a game path, engine metadata parsing,
   live backup, automatic source selection, permanent deletion, game-file edits,
   or implicit restoration.

Evidence: real temporary files and adversarial filesystem/process boundary
tests, followed by all legacy backup/retention tests. Windows tasklist and actual
game reload/progression remain unverified in this environment.
