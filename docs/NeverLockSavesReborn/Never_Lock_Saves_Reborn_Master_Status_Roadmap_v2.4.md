# Never Lock Saves: Reborn — current status addendum v2.4

October 25, 2026 (America/Los_Angeles). Current preview: **1.0.0-vehicle-diagnostic.3**.
The approved first-release scope and post-1.0 deferrals remain unchanged.

## New runtime evidence

The uploaded support report identifies diagnostic.2, game 2.5, CET 1.38.0 and
Native Settings 1.97. Its Lua reporter matches the released .2 reporter bytes.
This is partial live bridge evidence, not a full installation fingerprint or
an acceptance pass for every feature/framework.

The first helper snapshot is quicksave serial 1; the later export is serial 22.
Both latest snapshots are mounted and in combat, with native return true;
this does not establish outcomes for all intervening calls. The recorded
locks are Combat and Script. The deferred queue is empty
in Unrestricted mode. Combined with the user's missing-save report, this narrows
the defect downstream of request submission. It does not identify the Script
lock owner, prove write completion or justify a second attempt/lock removal.

Guardian requested zero observer registrations and marked ten unavailable;
quest observation is also unavailable. CET 1.38 initializes those globals after
initial mod loading, but Reborn captured them during that loading. diagnostic.3
uses three late-bound injections at existing protected onInit registrations.
This source fix restores registration opportunities; actual runtime callbacks
and save creation remain separate acceptance gates.

Smart Autosave is enabled. The first report waits on unknown phone state with
5,479 resets; the newer export reads phone clear and waits on combat with 33,605
resets. Those are scheduling resets, not save attempts. No phone workaround
is needed or added from these snapshots. Codeware's unavailable version read does not establish
whether the dependency is installed. These findings do not explain the already
accepted immediate checkpoint.

Next: cold-launch one .3 copy, confirm compile/version, turn Smart Autosave OFF
for a focused test, make one vehicle-combat quicksave and export support evidence
before another save. Record observer registration/callbacks and actual visible
save creation separately. Vehicle-combat saving is still an unresolved failure.
