# 1.0.0-rc3 — Smart interaction queue routing

October 24, 2026 (America/Los_Angeles). **Testing candidate.**

- Smart checks deferred queue admission independently of immediate checkpoint
  fallback permission in manual, pause-quicksave and gameplay-quicksave hooks.
- Smart blocked requests that cannot queue and have no combat exception show a
  truthful, tone-aware custom message, with master notifications respected.
- Optional queue status notifications and original queued notices retain their
  existing selection; successful admission is never reported as a written save.
- Native-unlocked dispatch, stable window/cooldown, serial checks, introduction
  protection, quicksave busy guards, other modes and existing modules remain.
- Eight identification labels become `1.0.0-rc3`; RC2's native type fix remains.

Only main REDscript and CET init change at runtime. No new API, runtime file,
setting, dependency or first-release capability is introduced. Fourteen runtime
files and all five recovery-companion files are byte-identical to RC2.

Actual-source regression reproduces RC2's skipped queue and checks RC3 across
lock reasons, guards, notification controls and dispatch boundaries. These are
offline boundary checks, not native compilation or gameplay verification.
