# RC3 changed-path acceptance

Record the deployed version/hash and actual game/framework versions. Offline
passes and broad working feedback do not establish individual runtime outcomes.

1. Compile and launch RC3; confirm version and fresh logs. Preserve the first new
   compiler error if it fails.
2. On a post-introduction test save, select Smart, Deferred Save ON and master
   notifications ON. During an interaction that locks saving, quicksave once.
   Expect pending quicksave and queued feedback, without an immediate checkpoint.
   Test queue status notifications both ON and OFF.
3. Leave before queue expiry. It must stay pending while native saving is locked,
   then submit at most one checkpoint request after stable window/cooldown.
   Verify save creation, reload and progression independently.
4. Repeat supported manual/pause-quicksave routes. Busy guards still apply.
5. With Deferred Save OFF, Smart noncombat blocked requests show a custom blocked
   message and create no queue or forced checkpoint. With master notifications
   OFF, the same permission decision applies silently.
6. Introduction protection still refuses queue admission. Vanilla and ordinary
   Immersion retain prior behavior. Explicit Smart pure-combat fallback and
   Unrestricted/known-DF paths remain separate.
7. Check cancellation, expiry, renewed locks, replacement and session changes if
   changed-path testing reveals a problem. Do not mark unrelated cases passed.

If still broken, export support-report.json immediately after the attempt and
retain fresh REDscript/CET logs. Useful fields: mode, deferred enabled, bridge,
session, q000_done, native lock summary, queue source/serial/event and notification
state. Record gameplay quicksave versus pause quicksave/manual save. Actual
notification display during interactions requires in-game observation.

Close the game before installation/rollback. Preserve settings and external save
copies; restore only an independently verified retained installation.
