# 1.0.0-vehicle-diagnostic.2 .. compilation hotfix

the diagnostic build hit a redscript error.. two new fields had negative defaults
the compiler wouldnt accept.. those defaults are removed and the readers keep
unknown state until an actual checkpoint attempt records the values..

this fixes the reported source cause.. it still needs your game launch to confirm
compilation.. actual vehicle combat saving is still unresolved..

Download `Never_Lock_Saves_Reborn_v1.0.0-vehicle-diagnostic.2_RUNTIME_ONLY.zip`.
The full `Release_Diagnostic.zip` includes source, tests and optional closed-game
backup/recovery tools. Both include MIT, RalphModding's credit and the original
[Never Lock Saves Nexus page](https://www.nexusmods.com/cyberpunk2077/mods/9662).

Close the game, preserve external save/settings copies, disable the old Reborn
entry, install this complete runtime, enable one Reborn entry, Deploy and restart.
Keep the existing dependencies. Confirm `1.0.0-vehicle-diagnostic.2` in CET and
check fresh logs. If compilation fails, send the new `redscript_rCURRENT.log`.

After successful compilation, attempt one vehicle-combat save and immediately
export the local support report. Native request acceptance is separate from
visible save creation, reload and progression. See `DIAGNOSTIC-VEHICLE-SAVE.md`.

Rollback: close the game and replace the entire Reborn payload with the retained
previous package, then Deploy. diagnostic.1 has a reported compilation failure;
do not choose it as a working rollback. RC3/RC4 also have unresolved vehicle-save
behavior. No last-known-good vehicle-combat build is established.

Fresh offline results and limits: `VALIDATION-VEHICLE-DIAGNOSTIC.2.md`.
This remains a developer diagnostic preview, not a stable release.
