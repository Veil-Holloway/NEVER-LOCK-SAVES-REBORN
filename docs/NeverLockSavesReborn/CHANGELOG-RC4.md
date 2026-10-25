# 1.0.0-rc4.. Unrestricted immediate request routing

Unrestricted user requests now attempt the existing checkpoint fallback directly,
even when Deferred Save is enabled. They no longer enter a queue waiting for the
native combat lock to clear. This applies to manual, pause quicksave and gameplay
quicksave. No new game API or engine lock bypass is introduced.

Changing into Unrestricted clears older manual queued work. A fresh Unrestricted
request also consumes older pending work before its immediate attempt, preserving
player priority. Independently enabled automatic scheduling remains native-gated;
mode selection alone does not clear its source-3 pending work.

Introduction protection, quicksave busy guards, Smart/Immersion routing, native
queue dispatch/stability/serial guards, DF and notification libraries are retained.
Only two runtime files change: DeferredQueue/SetMode, eight version labels and one
queue-help string. Fourteen other runtime files and five companion files match RC3.

The game may reject a checkpoint request. Actual vehicle-combat save writing,
reload and progression remain unverified; do not call immediate submission a save.
MIT/publication permission and RalphModding credit remain included.
