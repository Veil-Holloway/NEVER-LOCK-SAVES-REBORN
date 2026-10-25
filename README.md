# NEVER-LOCK-SAVES-REBORN

I took Never Lock Saves by RalphModding and started updating and expanding it.. added CET controls.. Native Settings support.. and a bridge so CET and redscript can communicate..

**current branch build is 1.0.0-vehicle-diagnostic.2.. diagnostic developer preview..** vehicle combat shows a notification but the user reports no save ever appears.. this is still unresolved.. this build also removes two negative field defaults that stopped diagnostic.1 compiling.. unknown state is preserved until an attempt.. compilation still needs checking in game.. it does not claim to fix actual saving..

## thanks Ralph

this started with **Never Lock Saves v2.2.1.0 by RalphModding**.. he gave permission to publish this modified version and release it under MIT.. thank you for the original work and for letting the mod keep going..

[original Never Lock Saves on Nexus](https://www.nexusmods.com/cyberpunk2077/mods/9662)

credit stays with Ralph for the original.. Reborn changes are by Veil Ashen Holloway.. [MIT license](LICENSE) and [permission record](PERMISSION.md)..

## what it does

**Vanilla** keeps the normal save behavior..

**Immersion** keeps normal requests and uses the existing checkpoint fallback when one of the four supported Dark future contexts is positively observed.. compatibility still needs actual testing..

**Unrestricted** sends user checkpoint requests straight to the existing fallback after the introduction.. even with Deferred Save ON.. switching into it clears old manual queued work.. its experimental.. a request doesnt mean the game accepted it or wrote a usable save..

**smart mode** respects normal save locks.. with Deferred Save enabled it remembers one request and waits until normal saving unlocks.. optional combat exceptions require combat-only lock reasons.. mounted combat also needs the vehicle switch.. quest and scene locks dont become combat exceptions..

theres also..

- a one-item deferred queue.. configurable expiry and cooldown.. cancellation and a dry run that never requests a save.. queued manual requests become checkpoints rather than named manual saves..
- optional smart autosaves for exploration.. after combat.. vehicle exit.. verified quest milestones and entering V's original apartment area.. each trigger has its own switch..
- professional sarcastic and unhinged notification tones.. contextual messages and optional queue status messages..
- read-only Dark future checks for vehicle sleep.. addiction.. starvation and dehydration.. the four message switches dont change Dark futures settings or survival systems..
- named settings presets you apply manually.. settings recovery.. CET and Native Settings synchronization..
- Save Guardian request tracking.. local support reports and an installation checker.. submitted never gets passed off as written or reloaded..
- a separate optional Windows/Python backup and recovery tool in the full package.. it runs with the game closed and restores to a new separate destination..

automatic character profiles.. every owned safehouse and automatic live backups are still outside the first release..

## install

you need **Cyber Engine Tweaks and redscript** for the two runtime halves.. **Native Settings** is optional for its menu.. **Dark Future** is optional for its integration.. install any dependencies those frameworks require separately.. no framework binaries are bundled and no exact supported version combination is claimed yet..

1. close the game.. keep external save copies and your existing Reborn settings..
2. download `Never_Lock_Saves_Reborn_v1.0.0-vehicle-diagnostic.2_RUNTIME_ONLY.zip` from [Releases](https://github.com/Veil-Holloway/NEVER-LOCK-SAVES-REBORN/releases).. older packages remain historical..
3. install with Vortex.. enable one Reborn installation and Deploy.. or copy the complete `bin/` and `r6/` trees to the game root..
4. launch.. check fresh logs and confirm the panel says `1.0.0-vehicle-diagnostic.2`.. stop at compilation errors before testing saves..

## testing and issues

RC4 removed Unrestricteds queue interception but the user still reports no actual vehicle-combat save.. the earlier success report was withdrawn.. this preview checks native acceptance and captures last-attempt diagnostics.. see [the diagnostic procedure](DIAGNOSTIC-VEHICLE-SAVE.md) and [validation report](VALIDATION-VEHICLE-DIAGNOSTIC.2.md).. those are offline boundaries.. not game tests..

start with an ordinary save.. confirm a new save exists.. reload it and continue gameplay.. then test Smart with Deferred Save ON during an interaction.. wait for native unlock and exactly one checkpoint request before checking save creation and reload separately..

use the [testing checklist](docs/NeverLockSavesReborn/TESTING-CHECKLIST-RC4.md) and record each result.. untested cases stay NOT RUN and the reported vehicle-combat failure stays recorded..

for an [issue](https://github.com/Veil-Holloway/NEVER-LOCK-SAVES-REBORN/issues).. include version.. game/framework versions.. relevant mods.. steps.. expected and actual behavior.. fresh logs and a reviewed support report.. dont post private paths or personal information..

MIT permission and Ralphs credit stay included.. use the checksum sidecars matching the downloaded preview.. actual save creation.. reload and progression still need proof..
