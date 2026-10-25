# Optional request-status notification channel

This is a pure Lua module and an authored status library. It never calls Game,
CET, file APIs, Guardian or a save-policy method. The host decides when an
observed request event is eligible for notification and supplies a UI emitter.
Failures and return values must not enter save eligibility or dispatch policy.

## Integration contract

```lua
local notices = require('status_messages').new(seed)
notices:configure(enabled_boolean, tone_0_to_2)
notices:reset(positive_runtime_session)
notices:enqueue(kind, session, positive_request_serial, now_seconds)
local result = notices:drain(now_seconds, body_0_to_2, function(message)
  return ui_bridge(message) == true
end)
local status = notices:status()
```

Supported kinds: `queued`, `auto_queued`, `submitted`, `expired`, `cancelled`,
`error`. Zero serials, unknown sessions and arbitrary strings are rejected.
The fourth enqueue argument is required: the caller's finite monotonic clock
gives each event an accurate ten-second expiry. Backward/invalid clocks clear
stale pending messages. The host should reset on player/session/readiness gaps,
not every frame. A reset drops pending messages; a different session also
resets request-history identity. Neither operation rewinds pool cycles or RNG.

The host must combine the feature's default-OFF switch with the existing master
notification switch. Configure is atomic and accepts only an actual Boolean and
zero-based tone: 0 Professional, 1 Sarcastic, 2 Unhinged. Body is 0 neutral,
1 female, 2 male; unknown/malformed body input uses the neutral pool. Host body
sampling should be fresh at display time. No body field is a playthrough ID.

Only new real queue events should enter the channel. Do not enqueue dry-run
previews or convert uncorrelated engine completion hints into written/reloaded
status. Suppressing legacy queue text is a host integration choice and must
require a functioning new module/verified bridge. No duplicate generic queue
message is needed alongside a new-channel queue notice.

## Bounded lifecycle and selection

- At most sixteen messages wait. Error/expiry take priority over submission,
  cancellation and queue notices. New lower-priority work cannot displace a
  full higher-priority buffer. Equal-priority overflow drops the oldest entry.
- One pending notice per session/serial coalesces queue-to-terminal changes.
  A terminal cannot regress or announce a second terminal state. The latest
  128 request states are remembered. A monotonic serial high-water mark refuses
  evicted older requests rather than letting them become fresh again.
- UI attempts are spaced by two seconds, including rejected/throwing attempts.
  The attempt clock and failure counter may change on failure; pool state, RNG
  and accepted sequence do not. There is no unbounded retry backlog.
- Each of the 54 event/tone/body pools has an independent twenty-entry
  Fisher-Yates bag. It visits every entry once before a new bag and prevents an
  adjacent repeat at the cycle boundary. A private Park-Miller/Schrage generator
  avoids changing the process-wide RNG. Candidate permutation/cursor/RNG state
  commit only after the emitter returns literal `true`.
- Recursive drain calls return `busy`. Reentrant resets/configuration/events
  invalidate the unpublished candidate, so its permutation/cursor/RNG do not
  advance after the channel was cleared or changed during the UI callback.

`emitter_accepted` means only the explicit UI bridge accepted the text. Actual
visibility, a file write, a usable save, reload and quest progression remain
unknown. The engine's public status labels this as `ui_bridge_handoff_only`,
with `write_status` and `reload_status` permanently `Unknown`.

## Inventory and wording boundary

Six events × three tones × three body profiles × twenty entries = **1,080
status entries in 54 independent pools**. There are **360 distinct texts**:
status wording is neutral and shared across body profiles. This is deliberate;
status information does not require gendered forms of address. The pools and
their independent selection histories still use the selected body profile.
`INVENTORY.csv` publishes exact event/tone/body counts. Do not present 1,080 as
the number of distinct authored strings or merge these counts with the existing
core/DF library without naming the boundary.

Every notice describes a request lifecycle. Submission/error text explicitly
says completion/outcome is unconfirmed. Timeout/cancellation refers only to the
tracked queued request, never to the presence or absence of other game saves.
Unhinged is profane; no threats, protected-group slurs, self-harm language or
unsupported success/reload promises are included. Core/DF message files and the
activation message are not edited by this module.

## Verification

`test_status_messages.lua MODULE_DIRECTORY` executes both actual production
files under Lua 5.3. It checks all pools, three full cycles for every pool,
boundary repeats, truthy/throwing/disabled emitters, RNG non-advancement,
coalescing, session/serial guards, expiry, priority, bounded buffers, reentrancy,
unknown body fallback and independent body-pool progress.

`run_status_checks.py --module-dir DIRECTORY --output RESULTS` reruns the
positive suite and eleven deliberately weakened final-source controls. Each
control must fail for its intended public invariant. Temporary variants are not
part of the mod. No CET/LuaJIT, game, notification visibility, file-write,
reload or progression evidence is claimed by these offline checks.
