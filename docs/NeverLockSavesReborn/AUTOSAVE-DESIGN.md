# Smart Autosave policy module

This optional pure Lua module schedules checkpoint **requests**. It does not
call game APIs, read or write files, modify quests, create backups, prove save
completion, or establish reload/progression integrity. The host must collect
fresh observations, calculate the existing two-second native unlock stability
window, and queue through the guarded REDscript path.

## Public API

- `new()` creates default-OFF scheduler state.
- `configure(state, options)` merges valid options atomically and returns
  `true`, or `false, error`. Changed options reset transient work; identical
  options preserve it. The caller's options table is copied.
- `reset(state, session, reason)` clears baseline, elapsed credit, pending work
  and retry state, and imposes a full cooldown. Session may be nil or a positive
  Int32-compatible whole number. Reason is limited to 80 characters.
- `tick(state, delta, snapshot, callback)` evaluates observations and returns a
  status string. `callback(reason, session)` must return literal `true` to accept
  the request into the host queue. Reentrant ticks return `dispatching`.
- `status(state)` returns a detached flat scalar report. `written` and `reload`
  always remain `Unknown`. `checkpointSubmission` also remains `Unknown`.
  `accepted` counts queue handoffs only. A literal true callback returns/statuses
  `queue_request_accepted`; it is not evidence that REDscript dispatched a
  checkpoint to the engine.

Options: `enabled=false`, `intervalSeconds=300` (whole 60..1800),
`cooldownSeconds=60` (whole 30..600), `exploration=true`, `postCombat=true`,
`vehicleExit=true`, `questMilestone=false`. Boolean values are strict; unknown keys
are refused. The quest trigger requires a separate source-verified event adapter.

Every valid snapshot supplies a positive integer `session`, literal true
`playerReady`, `introComplete`, `bridgeReady`, known combat/vehicle/phone sensors,
Boolean active fields, explicit Boolean `nativeUnlocked`, `stableReady` and
`queueBusy`, and literal false `paused`. Missing/invalid safety observations,
pause, session change, and invalid/negative/nonfinite or greater-than-one-second
frame delta clear transient work and require a new baseline. Frame credit is
capped at 0.25 seconds. There is no wall-clock catchup.

## Trigger and priority rules

Exploration cadence counts only verified noncombat, unmounted, phone-inactive,
native-unlocked and stable active time. Postcombat and vehicle-exit triggers
require a true-to-false observation in the same session after warmup/cooldown.
Combat has priority when both edges occur together. Native locks may be sampled
while combat is active; they do not erase the valid combat baseline.

When separately enabled, optional `snapshot.questMilestone==true` represents a
freshly drained verified journal completion event. False, nil and unknown values
produce no event. The adapter owns callback verification, deduplication and
buffer clearing across suspension, load and session boundaries. The scheduler
does no initial quest-state scan. The first fresh session/baseline sample drops
incoming events rather than preserving them across a load. Quest events have
the same native/stability/cooldown gates and bounded pending lifetime. Active
combat, mounting, phone activity or player queue work discards them.

One captured event may wait up to 30 active seconds for native unlock and
stability. User queue work, phone activity, new combat/mounting, safety
interruption, configuration change and reset clear it. User queue work also
rearms automatic cooldown, preventing an immediate second request when a manual
request clears. The integration must actually observe that user work before
dispatch; a pure scheduler cannot infer requests omitted from its snapshot.

Only raw native unlock plus stable readiness can dispatch. A missing callback
does not consume the event. Rejection/error retries wait at least five active
seconds and stop at the event's original deadline. Accepted queue handoffs reset
cadence/cooldown. No acceptance text claims a written or reloadable save.

## Evidence

`texlua test_autosave_policy.lua autosave_policy.lua` passes **338 assertions**.
The alpha2 baseline has no module (recorded missing-feature negative control).
Nine intentionally defective module variants are detected by the same suite:
master OFF ignored, native gate removed, user queue ignored, long-frame reset
removed, postcombat edge removed, user-queue cooldown omitted, quest opt-in ignored
quest event type coercion, and falsely presenting queue acceptance as engine
submission.

The user-queue cooldown regression was independently reproduced before fixing:
on the queue-clear frame a simultaneous postcombat edge produced one unwanted
automatic request; after the fix it produces zero. See `RESULTS.json` for exact
fresh outputs and source hash. The runtime is Lua 5.3 via texlua, not CET Lua
5.1/LuaJIT. Game integration, actual checkpoint creation and reload/progression
remain unverified by these module tests.

## Unsupported trigger evidence

Safehouse entry is not implemented here; no unproven game event or heuristic is
presented as a verified trigger. It needs a source-backed host adapter before
being enabled. Quest completion is implemented only as the explicit verified
event input above; real callback behavior remains a host/in-game verification
boundary.
