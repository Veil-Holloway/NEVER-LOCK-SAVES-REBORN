# Vehicle-combat save diagnostic — 1.0.0-vehicle-diagnostic.2

**Status: actual vehicle-combat saving is not fixed or verified by this build.**
This preview distinguishes a rejected request from a native-accepted request
that still has no visible save. All game/compiler acceptance below is NOT RUN.

1. Close the game. Preserve an ordinary pre-test save and external copies. Install
   the entire diagnostic runtime package; enable one Reborn installation, Deploy
   and restart. Check fresh compiler/CET logs and the panel version `1.0.0-vehicle-diagnostic.2`.
2. Use a disposable post-introduction save. Set Unrestricted, optional Smart
   Autosave OFF and Deferred Save ON. During vehicle combat press gameplay
   quicksave **once**. Record the exact feedback and check for an attributable
   new save in the load menu. Do not infer a file write from the popup.
3. Before making another save request, open Reborn's CET panel and click
   **Export support report**. The local file is
   `bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support-report.json`.
   Send that file and fresh relevant logs after reviewing them for personal data.
   The `checkpoint_attempt` section captures the most recent mod checkpoint
   attempt on the current player, so another request can overwrite it. Early deferred preflight failures can
   leave an older snapshot; this section is not correlated to the current queue.
4. Record whether any save appears after combat ends. The previous user report
   says it never does. If a new save exists, reload it and verify vehicle/player
   state, inventory, objectives and continued quest/interaction progression.
5. Repeat with Deferred Save OFF and the accessible pause-quicksave/manual
   routes separately. An inaccessible menu route is NOT RUN. Also retest an
   ordinary unlocked save and Smart's native-unlock queue behavior.

Interpretation: `native_accepted: false` means the native request returned false.
`native_accepted: true` means only that it returned true; it cannot prove a written
save. `service_unavailable`, `policy_blocked`, `not_attempted` and `unknown` retain
their literal limits. `write_status` and `reload_status` remain `Unknown`.

Feedback is optional, but the last-attempt report works with notifications OFF.
The report performs no automatic upload. No quest completion should be forced
to make a save appear usable. Do not promote this preview to stable on popup
display or offline tests.

Rollback: close the game, replace the complete `bin/` and `r6/` mod payload with
the previous package, Deploy and restart. Preserve settings and pre-test saves.
