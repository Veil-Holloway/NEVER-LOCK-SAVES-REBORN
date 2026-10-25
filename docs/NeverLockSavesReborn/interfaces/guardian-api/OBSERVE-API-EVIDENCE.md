# Save Guardian observer interface evidence

Primary sources were fetched through the authenticated GitHub connector. Exact
blob identities and line ranges are in `API-PROVENANCE.json`; no live game ran.

## Verified registration and callback contract

- `ObserveBefore(typeName, fullName, callback)` registers a before observer.
- `ObserveAfter(typeName, fullName, callback)` registers an after observer.
- `Observe` aliases `ObserveBefore`.
- Both registration functions return **void**. `pcall` success means only that
  the Lua call did not throw. CET logs an absent class/function and returns
  normally, so attachment cannot honestly be marked verified at registration.
  Use requested/unconfirmed until an actual matching callback has been seen.
- Instance callbacks receive **self first, followed by original method arguments
  in declared order**. Before and After get the same original argument list.
  Neither includes the original return value. Ignore observer return values.
- CET's source explicitly notes that hooked functions can run on worker threads.
  Keep observer callbacks bounded, telemetry-only and free of filesystem IO or
  unrelated game-system calls. Defer persistence/rendering to ordinary events.

Examples of shapes supported by these inspected contracts:

| Target | Lua callback parameters |
|---|---|
| `PauseMenuGameController.HandlePressToSaveGame` | `self, target` |
| `PauseMenuGameController.HandlePressToQuickSaveGame` | `self` |
| `gameuiInGameMenuGameController.HandleQuickSave` | `self` |
| `PlayerPuppet.NLSRebornDeferredQueue` | `self, source` |
| Either observed controller's `OnSavingComplete` | `self, success, locks` |

For the existing Reborn queue, do not interpret an After callback's return value
as queue acceptance: there is no such return value. A pre/post comparison of the
mod-owned pending flag and serial may establish an observed mutation, provided
the getter/field boundary is safe and actual source signatures are retained.

## Engine-result evidence is not file evidence

Pinned RTTI confirms `OnSavingComplete(success: Bool, locks: array<gameSaveLock>)`
on both controllers, returning Bool to the game. The gameplay controller's
decompiled OnInitialize/OnUninitialize explicitly registers/unregisters that
callback. No request ID or save-file path is supplied. Collect the Boolean as an
uncorrelated engine-result hint; it cannot promote a particular Guardian request
to Written, Verified or Reloaded. Normal engine autosaves can also produce
unrelated signals, and multiple controller observations may duplicate a signal.

## Filesystem and version boundary

CET's own `GetLuaPath` rejects absolute and escaped paths. `io.open`, directory
listing, rename and removal use this resolver; normal saves outside the mod
sandbox are unavailable to pure CET. Red File System similarly restricts access
to its own `r6/storages` locations. No sandbox workaround is implemented.

The installed CET/game versions were not supplied; pinned RTTI/decompiled sources
do not independently identify the supported distribution version. Callback
registration and coverage must be checked in the user's actual installation.
The user's statement that v0.10.4b works records the requested smoke-test pass;
it does not certify every historical gameplay/compatibility row.
