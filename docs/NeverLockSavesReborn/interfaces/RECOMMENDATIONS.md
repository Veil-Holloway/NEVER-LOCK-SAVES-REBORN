# Runtime interface findings for release preparation

These are source-inspection findings. No REDscript compiler, game, CET hook
registration, Windows helper or save/reload test ran in this research task.
`API-EVIDENCE.json` records exact NativeDB interfaces and blob identities;
`GAME-SOURCE-EVIDENCE.json` records corroborating pinned game script interfaces
and callback semantics. NativeDB's snapshot is old (2021-12-15); the separate
game script snapshot is pinned to `fce9ab7e6a608b0d729290d898003589515900e1`.
Installed game/framework compatibility remains unverified.

## Smart policy

- `GameInstance.IsSavingLocked(game, out locks)` supplies actual `gameSaveLock`
  entries. Each has `.reason: gameSaveLockReason`.
- A narrow whitelist may accept **only** nonempty lists exclusively containing
  `gameSaveLockReason.Combat`, only when fresh combat is true and the explicit
  combat preference is enabled. Mixed/unknown/empty-under-locked lists deny.
- `Nothing` is not a Combat reason. Reject Scene, Quest, Script, Boundary,
  MainMenu, LoadingScreen, PlayerStateMachine, PlayerState, Tier,
  NotEnoughSlots, NotEnoughSpace and PlayerOnMovingPlatform. Reject any future
  unknown value too.
- There is no Vehicle reason in the inspected enum. A mounted observation must
  never reinterpret PlayerStateMachine or PlayerState as a vehicle-only lock.
  The vehicle setting can additionally restrict a Combat exception while
  mounted. Vehicle-only blocking stays unavailable without a supported cause.
- Keep vanilla-unlocked requests on their normal native route. Check intro,
  player/session, native locks and actual context immediately before fallback.
  This remains an experimental request policy, not serialization proof.

## Supported mounted and combat queries

The current pinned game source confirms both `PlayerPuppet.IsInCombat(): Bool`
and `PlayerPuppet.GetMountedVehicle(): VehicleObject`. The latter is absent
from the old NativeDB PlayerPuppet snapshot; that absence alone does not make
the baseline method fictitious.

For a fresh Boolean mounted bridge, prefer the independently corroborated
`VehicleComponent.IsMountedToVehicle(game, player): Bool`. The actual supplied
Dark Future `DFAnimationService.reds` uses this at lines 1123 and 1220, alongside
`player.IsInCombat()`. Verify the player/game services exist first; a missing
player must stay unknown rather than being reported as unmounted.

## Autosave readiness and triggers

Supported signals include `GameInstance.GetTimeSystem(game).IsPausedState()`
and the `UI_System.IsInMenu` blackboard field; Dark Future uses both. CET kit
also uses `GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():IsPreGame()`.
That handler declares `IsGamePaused(): Bool` and `GetGameVersion(): String`.
Read all through guarded boundaries and require known safe observations.
Neither a false pause flag nor a false menu flag independently establishes that
loading or a scripted transition is absent.

An exploration interval, post-combat true-to-false and vehicle true-to-false
trigger can use existing sensors, provided unknown readings and every new
session reset edge history. No edge on first sample; no catch-up bursts; cap
long-frame credit; bound pending age; enforce cooldown and deduplication.
Scheduled work must yield to a pending player request and dispatch through the
same fresh native-unlocked gate. A timer or dispatch is never Written/Reloaded.

### Verified journal completion seam

The pinned game's `quest_tracker.script` registers `OnStateChanges` with
`gameJournalListenerType.State` during initialization. Its callback has
`(hash: Uint32, className: CName, notifyOption: JournalNotifyOption,
changeType: JournalChangeType)`. It resolves `GetEntry(hash)`, reads
`GetEntryState(entry)`, and uses `gameJournalEntryState.Succeeded` to mark
an objective finished. The corresponding NativeDB callback declaration agrees.

A conservative adapter may record scalar callback arguments in a bounded
buffer, drain on ordinary `onUpdate`, resolve a defined journal entry and
verify a Quest or QuestObjective type with current `Succeeded` state. Deduplicate
hashes per runtime session and discard unknown/overflow/session-change events.
Do not scan already-completed entries on initialization, and do not read game
systems or write files inside the observer callback. Hook registration must
remain requested/unconfirmed until seen. This supplies a verified completion
**trigger**, not proof the quest transition is safe to serialize; the ordinary
readiness, stabilization and native lock checks still apply.

### Safehouse boundary

`SafeAreaManager.IsPointInSafeArea(point): Bool` exists. It describes a safe
area, not a recognized apartment/safehouse, ownership or an entry event. The
supplied Dark Future has specific apartment interaction and quest-fact handling,
not a generic safehouse-entry contract. Do not ship a generic safehouse trigger
based on a security zone or guessed coordinates. Leave it unavailable until a
verified explicit adapter is selected and tested.

## Character/playthrough identity

No stable read-only playthrough identifier was established by the inspected
interfaces. Player-system object getters return player objects; body, voice,
lifepath, entity ID, runtime session tokens and elapsed playthrough time are not
robust playthrough keys. `GetLatestSaveMetadata()` is not guaranteed to describe
the currently loaded save and its inspected structure has no playthrough ID.

The original psiberx GameSession persistent key mechanism writes a custom quest
fact. Adopting that mechanism would violate the current no-new-quest-fact-write
boundary. Do not copy it or silently derive identity from a fingerprint.

Feasible partial scope is explicit named settings presets, with manual selection
and binding reset per runtime session. Label them manual presets, not automatic
character detection. Full automatic character profiles remain unsupported until
a real read-only persistent identity seam is available, or the user explicitly
changes the persistence constraint.

## Evidence and release boundary

The existing Guardian engine callback still lacks request ID and save-file
path, so it remains an uncorrelated hint. Pure CET cannot read the external save
directory under the inspected sandbox. Keep automatic live backup unavailable;
the closed-game external helper remains the supported copying route.

Runtime compatibility, actual save creation, restoration/reload and quest
progression need the user's disposable in-game test matrix. Do not promote a
source-tested package to stable solely because these interface declarations
exist or offline boundary doubles pass.
