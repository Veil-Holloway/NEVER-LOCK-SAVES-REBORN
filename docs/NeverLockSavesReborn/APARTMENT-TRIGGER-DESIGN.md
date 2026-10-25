# Original V apartment scheduler extension

Production surface: existing pure `autosave_policy.lua` only. The runtime owner
implements the read-only native district reader and host snapshot integration.

## Public seam

- Config key: `autosaveApartmentEntry=false`.
- Scheduler option: `apartmentEntry=false`.
- Snapshot: `apartmentKnown` and `apartmentInside` are required Boolean evidence
  only when `apartmentEntry` is true. `apartmentKnown` must be literal true.
- Host maps the verified direct district reader `1` to known/inside, `0` to
  known/outside and `-1`/missing/invalid to unknown. No text or coordinate guess.
- Reason: `apartment_entry`.

The supporting location is only the actual native district enum
`gamedataDistrict.LittleChina_VApartment`, V's original apartment. This is not
universal safehouse/ownership detection. Read the pinned interface evidence in
`research_safehouse/API-EVIDENCE.json` and its coverage limits.

## Event and safety rules

A request can begin only on a known outside-to-inside edge in the same current
session, after the existing shared cooldown. First sampling/enabling inside,
unknown-to-inside and resumed session baselines are inert. Repeated inside
samples never replay an entry. An edge during cooldown is dropped rather than
queued for later catch-up.

Captured work uses the same thirty-second pending TTL, retry policy, serial
handoff, native unlock/stability and player priority as existing triggers. A
known native relock may wait within that TTL. Leaving the apartment before
acceptance discards the captured apartment request. Pause, phone/combat/vehicle,
player work, unknown evidence, session/config changes or long frames clear it.
When the option is ON, invalid apartment observations reset the scheduler rather
than inventing a safe outside state. When the option is OFF, apartment fields
are irrelevant and the existing four triggers retain their old behavior.

Priority remains postcombat, vehicle exit, verified journal milestone, then
apartment entry; exploration remains last. One pending event and the shared
cooldown deduplicate simultaneous signals. Queue acceptance remains separate
from engine submission, written state, reload and progression; all independent
completion evidence stays Unknown.

## Verification

The new public test first failed against preRC1 because the option was absent.
After the minimal extension: 126 dedicated public-boundary assertions pass,
eight exact single-condition mutations fail for the intended invariant, the
pre-existing author suite passes 339 assertions (the added status option accounts
for one extra copy assertion) and the independent scheduler suite passes 638
assertions with ninety stress handoffs. Lua host is 5.3. No REDscript compiler,
CET/native ABI, actual apartment entry, save/reload or progression was executed.

`run_apartment_checks.py` runs the final actual module and creates weakened
negative controls only in disposable temporary directories. It supports texlua
or a Lua executable with repeated `--lua-arg` flags, matching the parent runner's
Lua host convention. `checks/RESULTS.json` records exact source hash and results.
