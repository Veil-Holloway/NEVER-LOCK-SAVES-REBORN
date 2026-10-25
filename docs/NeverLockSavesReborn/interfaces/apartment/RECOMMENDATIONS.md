# Safehouse-entry interface research

## Result

A **narrow original V apartment entry trigger** has a source-backed read-only
location seam. A generic owned-safehouse trigger remains unestablished. This
research does not implement a production adapter or claim game validation.

The actual game source declares the enum
`gamedataDistrict.LittleChina_VApartment`. It also exposes a direct current
district lookup through `PreventionSystem`, `District` and `District_Record`.
This is substantially stronger evidence than generic safe-area membership,
distance to a guessed coordinate, localized location text or apartment furniture.

## Exact supported chain

1. `GameInstance.GetScriptableSystemsContainer(game).Get(n"PreventionSystem")`
   cast to `PreventionSystem`. The game's `DistrictPrereq.IsFulfilled` uses this
   exact lookup and calls the current district getter.
2. `PreventionSystem.GetCurrentDistrict() -> wref<District>` is public and returns
   the district manager's current stack entry.
3. `District.GetDistrictRecord() -> ref<District_Record>` is public.
4. `District_Record.Type() -> gamedataDistrict` is used by the game's
   `District.IsDogTown` and `District.IsBadlands` implementations.
5. Compare that enum directly to `gamedataDistrict.LittleChina_VApartment`.
   Missing container/system/district/record must produce Unknown, never outside.

The current district stack is managed by actual `DistrictEnteredEvent` requests.
The game also writes `UI_Map.currentLocationEnumName` from the district record,
but direct current-district lookup is preferable to a potentially stale UI cache.
No observer or quest-fact write is necessary for a polling adapter.

## Conservative adapter contract if root chooses this scope

- Label it **Original V apartment entry** and document that it covers the
  source-identified `LittleChina_VApartment` district only.
- Keep it default OFF. Master autosave OFF remains an absolute off switch.
- Read the current district on the ordinary game/update thread through guarded
  read-only boundaries. No game calls in observer callbacks are needed.
- Require a known outside baseline followed by a known inside observation in
  the same current runtime session. First sample inside creates no event.
- Unknown readings, session changes, pause/menu, phone/combat/vehicle state,
  player queue priority and long-frame interruption invalidate pending work and
  require a new baseline. Do not interpret Unknown-to-inside as entry.
- Use the existing native-save-unlocked, fresh intro and serial checks,
  stabilization, bounded pending TTL and shared cooldown. This location trigger
  does not prove quest serialization safety, save completion or loadability.
- Test true-to-true deduplication, known outside-to-inside, repeated exit/entry
  under cooldown, direct service failures, nested subdistrict changes, starting
  the game inside, enabling inside, reload and unknown gaps.

## Coverage deliberately not established

The enum also includes `CorpoPlaza_Apartment`, `Glen_Apartment`,
`JapanTown_Apartment` and `Northside_Apartment`. These identify apartment
locations but this research did not establish ownership/rental state. Other
enum values include Judy's/Hiromi's apartments and an abandoned apartment
building, demonstrating why an unrestricted `*Apartment*` substring is invalid.
Do not whitelist every apartment enum or treat a map purchase offer as ownership.

No generic owned-safehouse API, complete Phantom Liberty/Kress Street coverage,
modded safehouse identity or ownership contract was established. The supplied
Dark Future scripts identify individual apartment interaction captions, selected
quest events and furniture actions; these are interactions, not an entry or
ownership contract. Generic `SafeAreaManager.IsPointInSafeArea` remains unrelated
to safehouse identity. The original request for all safehouse entries therefore
remains partial unless a broader verified adapter is later established.

## Provenance and limits

`API-EVIDENCE.json` pins actual source paths, commit and blob identities. Critical
district manager and prevention getter blobs are unchanged from the previously
reviewed game-script snapshot. The new research uses pinned commit
`cfcf5071e5363962a44c33cb7cab749688b0ca51`, not invented method probes.
Only source declarations/uses and supplied Dark Future text were inspected.
There was no REDscript compiler, CET/native ABI execution, actual district
transition, game save, reload or progression test. Installed compatibility and
the physical trigger-volume coverage still require game testing.
