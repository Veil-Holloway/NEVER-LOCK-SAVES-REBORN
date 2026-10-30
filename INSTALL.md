# Installation, update and rollback

Use the RUNTIME_ONLY ZIP for 1.0.0. The source/testing ZIP is for development.

1. Close Cyberpunk 2077. Keep the previous Reborn runtime ZIP and copies of config.json and profile-settings.json if you want a complete settings rollback.
2. Install Cyber Engine Tweaks and redscript, plus the dependencies required by those frameworks. Native Settings and Dark Future are optional integrations installed separately.
3. Install through one mod manager, or copy the complete bin/ and r6/ folders into the game root. The CET folder is bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn; the REDscript folder is r6/scripts/NeverLockSavesReborn.
4. Replace existing Reborn runtime files in those paths. Do not leave an old renamed duplicate mod/script folder installed. Keep user config/preset files; the archive supplies none.
5. Launch and confirm 1.0.0 in CET. Check fresh CET/redscript logs if the mod does not load. The archive manifest verifies installed bytes; it does not prove game compilation.

Old tone values are ignored and omitted on the next successful settings or preset write. No reset is needed. Optional Deferred Save, Smart Autosave and request tracking retain their current saved preferences.

To roll back, close the game and replace the same runtime paths with the previous ZIP. Restore your saved config/preset copies if you need their exact previous contents. To uninstall, close the game and remove only the two Reborn mod directories named above, or remove/deploy through your mod manager. Keep any desired settings copies outside the installation. Do not remove framework installations used by other mods.

After changing versions, test a save and load it before continuing a long session. Queued player requests become checkpoints rather than named manual saves. Saved-game backup/restore is not supplied by this mod.
