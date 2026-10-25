# 1.0.0-vehicle-diagnostic.1 .. checkpoint-result diagnostic preview

October 25, 2026 (America/Los_Angeles). **Experimental prerelease. Actual vehicle-combat saving remains unresolved.**

the vehicle combat popup appeared but the save never showed up.. so RC4 does not
pass that test.. this build checks the game's checkpoint return value instead of
throwing up a message either way.. it also records the locks and player state at
the attempt in the local support report..

false gets rejection feedback.. true means the game accepted a request.. it still
doesnt mean a save was written or will reload.. Unrestricted still attempts
immediately after the introduction.. there is no new lock override or retry loop..

Download `Never_Lock_Saves_Reborn_v1.0.0-vehicle-diagnostic.1_RUNTIME_ONLY.zip` for installation.
The full `Never_Lock_Saves_Reborn_v1.0.0-vehicle-diagnostic.1_Release_Diagnostic.zip` includes source, validation and recovery tools.
Both include MIT, RalphModding's credit and the original Nexus link in README.

Dependencies: CET and redscript; Native Settings and Dark Future integrations are
optional with their own dependencies. No exact tested game/framework matrix or
native compilation result is claimed. No framework binaries are bundled.

Validation is recorded in `VALIDATION-VEHICLE-DIAGNOSTIC.1.md`. Native compilation,
actual save creation, reload, progression, Windows restoration and full optional
framework compatibility remain NOT RUN for this preview. The reported RC4 save
failure is retained; offline success does not erase it.

Install/update: close the game, preserve external saves/settings, install the
complete runtime, enable one Reborn copy, Deploy and restart. Check the version
and fresh logs before requesting a save. Roll back by replacing the complete
mod payload with a previous package while the game is closed.

Test procedure: `DIAGNOSTIC-VEHICLE-SAVE.md`. Export the local support report
immediately after one vehicle-combat attempt, before another request. Report the
native result, visible save outcome and fresh logs. If a save exists, test reload
and progression independently.

[GitHub repository](https://github.com/Veil-Holloway/NEVER-LOCK-SAVES-REBORN)
| [issue reports](https://github.com/Veil-Holloway/NEVER-LOCK-SAVES-REBORN/issues)
| [draft implementation PR](https://github.com/Veil-Holloway/NEVER-LOCK-SAVES-REBORN/pull/1)
| [Drive release mirror](https://drive.google.com/drive/folders/1iLGmdT5tNZVhgvpDkZeT-u582KUFKzk1)

RalphModding created the original [Never Lock Saves](https://www.nexusmods.com/cyberpunk2077/mods/9662).
Publication and MIT permission are recorded in `PERMISSION.md`.
