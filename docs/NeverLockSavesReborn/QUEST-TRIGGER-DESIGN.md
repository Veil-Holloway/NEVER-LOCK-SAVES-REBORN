# Optional journal milestone adapter

`quest_milestones.lua` is a pure transport and validation module. It does not
request a save, change journal/quest state, write files or inspect save data.
Source evidence is in the sibling `interface_review` directory.

## Public contract

```lua
local journal = require('quest_milestones').new({
  observe = ObserveAfter,
  enabled = function() return questMilestoneEnabled end,
  resolve = function(hash, className)
    -- This runs on ordinary drain/onUpdate, never inside the observer.
    -- Resolve the current entry, verify its actual Quest/Objective type and
    -- current Succeeded state. Return nil for unknown/incomplete entries.
    return {defined=true, kind='quest', succeeded=true}
  end,
})
journal:register()
local fresh = journal:drain(positiveRuntimeSessionToken)
snapshot.questMilestone = #fresh > 0
```

`resolve` is an injected game boundary, not the constant example result above.
It must provide current source-backed evidence. Return `kind='objective'` for
an actual objective. The module checks this against the event's canonical class
name (`gameJournalQuest` or `gameJournalQuestObjective`). The integration maps
the returned fresh observations to the scheduler's optional literal Boolean
`snapshot.questMilestone`. The scheduler owns opt-in, readiness, stabilization,
cooldown, priority and dispatch; the adapter owns observed event deduplication.

Methods may be called with colon syntax. `register()` is idempotent. Registration
success means requested/unconfirmed until the target callback is observed.
`drain(session)` returns a list of fresh records containing `hash`, `className`,
`kind`, `session` and `key`, with no save-completion claim. The first drain arms
intake; it performs no initial scan and produces no event by itself.

`clear()` drops the current buffer and disarms intake. Disabled or unknown-session
drains also disarm. Deduplication for the last known session survives pause,
disable/re-enable and temporary unknown tokens; only a different positive session
token resets it. New callbacks before a rearming drain are deliberately dropped.

The buffer holds 64 records. A 65th eligible observation discards the entire
ambiguous batch. The dedup set saturates at 128 completed hashes per session;
it never evicts old entries and therefore suppresses further milestones until
a different known session. This conservative limit is visible in `status()`.

## Supported callback boundary

`QuestTrackerGameController.OnStateChanges(self, hash, className, notifyOption,
changeType)` is registered by the pinned game source specifically for
`gameJournalListenerType.State`. Tracking/counter notifications use separate
callbacks. Intake copies only a valid nonzero Uint32 hash and one of the two
canonical class names. CName `.value` is the CET binding's raw name-string
property; `tostring(CName)` is a formatted expression and is not used.

The observer reads only module-local arm/session state and scalar arguments.
It calls no injected enabled/resolver function, game system, filesystem or
Guardian ledger. Resolution occurs only on `drain`. Exceptions and malformed
evidence stay fail closed. A generation guard invalidates the entire unpublished
result batch when an injected boundary reenters `clear` or `drain`; the explicit
opt-in is rechecked after each resolution so mid-resolution disable cannot
publish an observation.

## Suggested source-backed game bridge

The integration owner can add a scalar method on PlayerPuppet that:

1. Gets the current `JournalManager` from `GameInstance.GetJournalManager`.
2. Resolves `GetEntry(hash)` and rejects undefined entries/services.
3. Requires `GetEntryState(entry) == gameJournalEntryState.Succeeded`.
4. Casts the actual entry to `JournalQuest` or `JournalQuestObjective` and returns
   a scalar success kind only for a defined cast.

These declarations/cast types are corroborated by pinned game scripts and the
supplied Dark Future sources. Class-name evidence alone must not substitute for
the actual entry cast and current state read.

## Verification boundary

Run:

```sh
texlua test_quest_milestones.lua quest_milestones.lua
python3 run_quest_checks.py --module quest_milestones.lua --output check-results
```

The tests execute this Lua module on the available Lua 5.3 host with game/CET
boundary doubles. They do not compile REDscript, execute CET, prove observer
coverage, create a game save, reload a save or establish quest serialization
safety. A completed journal milestone is a trigger only; all ordinary save
readiness/native-lock gates still apply.
