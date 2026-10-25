# Optional Save Guardian backup/recovery companion

This is a manually run Python tool for **Windows**, separate from the CET mod.
It does not launch automatically and adds no mandatory dependency to Reborn.
Install Python 3.10 or newer if you choose to use it; no standalone `.exe` is
provided. It has no third-party Python packages or network access.

CET's filesystem sandbox cannot read ordinary game-save folders. This helper
therefore receives an explicit save-slot folder and backup destination from you.
It checks Windows `tasklist` for the standard `Cyberpunk2077.exe` process before
source inspection, immediately before copying, after copying and before publication. Unknown/malformed process status,
non-Windows hosts, or a running game stop backup and restore. There is no CLI
option to bypass that guard. A renamed executable is outside that detection;
close your game manually and leave it closed while using the tool.

## Make a snapshot

Close Cyberpunk 2077. Select one existing save-slot folder containing all of its
files. Use a separate backup root outside that folder and outside its parents.
The examples use placeholder paths; replace them with your actual locations.

```powershell
py save_guardian.py backup --save-dir "C:\YourSaveFolder\SelectedSlot" --backup-root "D:\RebornBackups" --game-build "your installed build" --mod-build "your Reborn build"
```

The tool hashes every source file, copies into an unpublished staging directory,
rehashes the source inventory, verifies copied hashes, then publishes a new
UUID-named directory. Changes or failures discard only the new unpublished
staging copy. It never overwrites an earlier snapshot or changes source save
bytes. The snapshot contains `manifest.json` and a `data` directory. The manifest
records UTC timestamp, source-slot name, byte counts, SHA-256 values and supplied
metadata. Unprovided game, character and mod identity remain `unknown`.

Limits: 2,048 regular files, 1,024 directories, depth 16, 4 GiB total per snapshot,
and a 1 MiB manifest. Symlinks/reparse points, traversal, Windows unsafe names and
case-insensitive collisions are rejected. Insufficient available capacity stops
creation. No game save format, quest fact, or character metadata is rewritten.

## List, verify and preview recovery

```powershell
py save_guardian.py list --backup-root "D:\RebornBackups"
py save_guardian.py verify --snapshot "D:\RebornBackups\SNAPSHOT_ID"
py save_guardian.py preview --snapshot "D:\RebornBackups\SNAPSHOT_ID"
```

Replace `SNAPSHOT_ID` with the returned 32-character identifier. Verification
requires the complete file/directory inventory to match the manifest; extra,
missing or changed files fail. Invalid snapshots are listed as invalid rather
than silently treated as recovery candidates.

## Recovery assistant and read-only checks

Start with these commands to understand the backup store or find a copy to review.
All three leave files, locks and snapshots alone.

```powershell
py save_guardian.py doctor --backup-root "D:\RebornBackups"
py save_guardian.py inspect-source --save-dir "C:\YourSaveFolder\SelectedSlot"
py save_guardian.py recovery-plan --backup-root "D:\RebornBackups"
```

`doctor` reads the existing root's available capacity, possible unpublished
staging directories, retention lock presence and retired-store ownership. It
reports whether the Windows process guard established a closed game **at the
check**. A guard failure is shown as `not_confirmed_closed`; it is never treated
as permission to make a backup or restore. A present lock needs manual review,
not automatic removal. Pending stages, invalid ownership markers and unknown
files are not repaired or deleted. The snapshot-name count only counts
identifier-shaped entries; use `recovery-plan` to verify their contents.

`inspect-source` requires the same closed-game guard as backup. It hashes the
complete selected source inventory twice and rejects observed content,
inventory or timestamp changes. The result includes relative file names,
byte counts, SHA-256 values, filesystem modification times in nanoseconds,
observation time and a digest of the source path. It omits the absolute source
path and does not parse game-save contents. This establishes which disk bytes
were observed while the guard reported the game closed. It cannot identify the
request that produced them or prove a successful engine write, loadability or
quest progression. Those fields remain `unknown`.

`recovery-plan` verifies the complete contents of active snapshots and snapshots
in the **owned** retired store. Its `candidates` include game/mod labels, supplied
character label, source-slot name, byte counts and next actions. Invalid copies
are listed separately and never offered for copying. Newest timestamp sorts
first; this is not a recommendation or a loadability rating. The helper neither
selects a copy nor initiates recovery. A lock present at either inventory boundary
causes refusal; this read-only report is a per-copy observation, not a locked
transaction. Preview, reactivation and restore reverify their own inputs.

To restrict choices to labels you supplied yourself:

```powershell
py save_guardian.py recovery-plan --backup-root "D:\RebornBackups" --retention-profile MainPlaythrough --character-id "your explicit character label"
```

Both filters are exact, case-sensitive metadata comparisons. They do not detect
your current character or playthrough. Unknown and mismatched labels are not
silently assigned to a character. Invalid copies are still listed separately.

For an **active** candidate, use its identifier as `SNAPSHOT_ID` in `preview`,
then use `restore` below with that identifier in `--confirm`. For a **retired**
candidate, run confirmed `reactivate` first, then preview and restore from the
normal active root. `next_actions` lists this order and the exact confirmation
identifier. The new destination must be outside the backup root and must not
already exist. Nothing is automatically installed into live saves.

## Restore a separate copy

Review the preview, keep the game closed, and supply the exact identifier as
confirmation. The destination's parent must exist; the destination itself must
**not exist** and must be outside the backup root.

```powershell
py save_guardian.py restore --snapshot "D:\RebornBackups\SNAPSHOT_ID" --destination "C:\RecoveryReview\NewSlotCopy" --confirm SNAPSHOT_ID
```

Restore verifies the snapshot, builds and verifies a separate copy, rechecks
the snapshot and game process status, then publishes the new destination. It
never overwrites an existing live slot or an existing destination. The helper
does not automatically install that copy into the game's save folder. Validate
any later manual import using disposable backed-up saves and an actual game
reload/progression check.

## Optional reversible active-retention rotation (alpha2)

Rotation is OFF for existing backup commands. Opt in explicitly with **both** a
profile name and a keep count of at least two:

```powershell
py save_guardian.py backup --save-dir "C:\YourSaveFolder\SelectedSlot" --backup-root "D:\RebornBackups" --retention-profile MainPlaythrough --keep 3 --character-id "your explicit character label"
```

Profile names permit 1–64 letters, digits, underscores or hyphens. An invalid name,
a missing paired option, or `--keep 1` is refused before a snapshot is written.
The new manifest remains schema 1, adding optional `retention_profile` and
`retention_source` fields. Old manifests remain readable and verifiable.

Retention groups use the **exact profile label + SHA-256 of the canonical source
folder path + supplied character label**. The source digest does not disclose the
full path. Two source folders with the same basename remain different streams;
so do different explicitly supplied character labels. Profile names and character
labels are user choices, not game-detected identities. If character metadata is
`unknown`, use a separate profile when switching playthroughs at the same source
path. Moving a source folder starts a new stream; previous copies are preserved.

After a new snapshot is fully published and verified, the helper rechecks that
the game is closed. It keeps the newest requested number **in each stream** and
atomically moves older validated copies into its owned `.retired` directory.
Creation times are parsed and normalized to UTC. Unprofiled copies, older manifests
without a source fingerprint, other profiles, invalid copies and unknown files
are left untouched. A stream with fewer copies is not reduced; the helper cannot
manufacture missing recovery copies. Clock skew may leave more than the requested
count because the newly published snapshot is additionally protected.

This is **active-retention rotation, not disk-space reclamation**. Nothing is
permanently deleted and no old snapshot is overwritten. Retired bytes still use
storage, so disk usage can grow. `.retired` must be an owned ordinary directory
on the same filesystem as the backup root; cross-filesystem moves are refused
without any copy/delete fallback.

All profiled backup publication/rotation, explicit retirement and reactivation
use one exclusive `.guardian-retention.lock` file at the backup root. Another
operation or an existing stale lock causes refusal; no lock is automatically
stolen. After an interrupted process, inspect the situation and ensure no helper
is running before manually removing a stale lock. Do not edit ownership markers.

If a move, process check or journal write fails, rotation stops. Already moved
copies remain reversible, and the fixed protected copies are not retired. When a plan was established, the
result reports `retired_ids`, `remaining_ids` and the error. If planning itself
fails, the remaining set is unknown and an explicit error is returned. A published backup is
reported as `backup_status: published_hash_verified` even when `rotation.status`
is `stopped`; it is not discarded or falsely reported as a failed backup. A
bounded `last-operation.json` journal sits beside the retired copies, never
inside a snapshot. Verify the returned statuses and review any partial result.

## Preview and explicitly apply retirement

The original preview command remains read-only and performs no rotation:

```powershell
py save_guardian.py retention-preview --backup-root "D:\RebornBackups" --keep 2
```

For a managed profile, preview a concrete retirement plan, then confirm its exact
`plan_digest` with the same profile and keep count:

```powershell
py save_guardian.py retention-preview --backup-root "D:\RebornBackups" --retention-profile MainPlaythrough --keep 3
py save_guardian.py retention-apply --backup-root "D:\RebornBackups" --retention-profile MainPlaythrough --keep 3 --confirm PLAN_DIGEST
```

Replace `PLAN_DIGEST` with the returned 64-character digest. If snapshots changed
since the preview, apply refuses and a fresh preview is required. The helper
reverifies the protected minimum and candidate before every move and after any
preparatory journal IO. The game is checked immediately before and after each
move. A game reopening after a completed move stops further moves and reports
that completed reversible action; it does not attempt an unsafe rollback.

## Inspect and reactivate a retired copy

```powershell
py save_guardian.py list-retired --backup-root "D:\RebornBackups"
py save_guardian.py preview --snapshot "D:\RebornBackups\.retired\SNAPSHOT_ID"
py save_guardian.py reactivate --backup-root "D:\RebornBackups" --snapshot-id SNAPSHOT_ID --confirm SNAPSHOT_ID
```

Reactivation verifies the owned store, snapshot and game status, then moves the
original directory back to the active backup root. Existing identifiers and
invalid copies are refused. It changes no manifest or data file and does not
install anything into the game's save folder. If the game reopens after the
move, the result explicitly reports successful reactivation plus a stopped
follow-up status. Direct restore from `.retired` is refused: reactivate first,
then use the normal confirmed restore to a **new external directory**.

## Evidence limits

`hash_verified` means copied bytes match the recorded inventory. It does not
prove the original file was a valid engine save, that the game can reload it,
or that a quest progresses correctly. `loadability` and `quest_progression`
remain `unknown`. Stable hashes are not an in-game save-completion event. This
manual, game-closed snapshot has no claimed correlation with a Guardian ledger
request ID. Background cloud/sync software is not locked by this tool; observed
source changes are rejected. This is not a power-loss-proof transactional store.

The regression suite uses real temporary files and injected process/IO boundaries:

```powershell
py -m unittest discover -s . -p "test_*.py" -v
```

Those tests do not run real Windows `tasklist`, open Cyberpunk, load a restored
save or verify quest progression. The Windows guard and real-game restore path
still need user testing before any stable-release claim.
