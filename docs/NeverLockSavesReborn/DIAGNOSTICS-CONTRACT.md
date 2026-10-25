# Structured observer and native-lock diagnostics

Scope: `guardian_bridge.lua`, `quest_milestones.lua`, `support_report.lua` only.
These additions report observations; they do not enter save policy, register
extra observers, resolve game services, perform IO or advance lifecycle state.

Both observer modules gain `:diagnostics()`, returning a new plain table with
bounded Boolean/integer values. Guardian exposes attempted/requested/observed/
unconfirmed/unavailable/buffered/capacity/overflow/dropped/ledgerFaults. Journal
exposes attempted/requested/callbackObserved/unconfirmed/unavailable/armed/
buffered/capacity/overflow/dedupCount/dedupCapacity/resolved/dropped/saturated/faults.
Guardian counts are numbers; journal registration/callback state is Boolean.
Counter values saturate at signed 32-bit maximum. No raw exception or callback
argument is exported. Existing status strings and observer/drain logic remain
unchanged; `PRESERVATION.json` records insertion-only diffs against preRC1.

The host supplies `snapshot.observers={guardian=...,quest=...}`. The support
report copies only known bounded fields and uses `unknown` for missing or invalid
values. Output field names use snake_case. Registration requested and callback
observed remain separate. These observations cannot become Written/Reloaded.

The host may supply `snapshot.locks={known=Bool,overflow=Bool,codes={...}}`.
Fourteen source-verified native reason names and the sanitized `Unknown` marker
are supported. At most sixteen reason slots/keys are inspected; output contains
at most sixteen names. Unknown values, sparse/non-list/metatable data, truncation
or unknown overflow cannot preserve a claim of complete known reasons. No raw
reason text is copied. This is a report of the host's current measurement, not
an independent lock query or authorization.

`snapshot.sensors.inMenu` becomes `context.in_menu` with strict Boolean/unknown
semantics. Profiles own effective-settings schema; the coordinator adds Boolean
`statusNotificationsEnabled` and `autosaveApartmentEntry`. This task does not
edit profiles or introduce automatic character identity.

On explicit export the host can supply `snapshot.statusNotifications` from the
pure presentation engine's `:status()`. Only its known scalar capacities,
pending/tracked/counter state, six event enums and validated event/tone/body pool
key are copied. Accepted counts are explicitly UI-bridge handoffs. UI visibility
stays unknown; written/reloaded stay Unknown. No RNG state, message text, raw
exception or extra host field is exported. Missing/malformed snapshots remain
unknown, separate from a measured disabled/empty state. The module has no
dedicated coalesced counter; the report does not invent one.

Verification uses actual Lua modules on Lua 5.3 and injected observer boundaries.
There is no CET/LuaJIT, REDscript compiler or real game evidence here.
