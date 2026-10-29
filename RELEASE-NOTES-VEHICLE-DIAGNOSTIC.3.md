# 1.0.0-vehicle-diagnostic.3 .. startup observer fix

the report shows the game accepted the checkpoint request while combat and script
locks were active.. so the request reached the native service but a written save
still hasnt been established..

I also found the observer functions were captured before CET finished starting..
that left Guardian and quest observation unavailable on a cold launch.. this build
looks up those same functions when registration actually runs..

this repairs existing tracing.. it does not claim to fix actual vehicle combat
saving.. native locks and save behavior are unchanged..

Install `Never_Lock_Saves_Reborn_v1.0.0-vehicle-diagnostic.3_RUNTIME_ONLY.zip` with
the game closed.. disable the previous Reborn entry.. enable one copy.. Deploy
and restart the whole game.. use a full launch rather than Reload all mods..
keep your existing frameworks and external save/settings backups..

Confirm version .3 and fresh compilation first.. for the focused test switch
Smart Autosave OFF.. use Unrestricted and try one quicksave during vehicle combat..
after a few seconds export support-report.json before making another save request..
send that report and the fresh Reborn CET log.. distinguish request acceptance,
actual save creation, reloading and progression..

No missing dependency is diagnosed merely from an unknown version field. The
phone state remains unknown when unreadable; autosave keeps its existing safety
gate. No retry loop, lock removal, alternative save API or quest-fact edit.

Full source and tests are in the Release_Diagnostic ZIP. Offline evidence and
limits: VALIDATION-VEHICLE-DIAGNOSTIC.3.md. Roll back by replacing the full Reborn
payload with diagnostic.2 while closed, then Deploy. It retains the reported
vehicle-save and observer limitations; no known-good vehicle-combat build exists.

MIT and RalphModding's credit remain included. Original mod:
https://www.nexusmods.com/cyberpunk2077/mods/9662
