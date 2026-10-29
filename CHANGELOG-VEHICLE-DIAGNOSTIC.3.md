# 1.0.0-vehicle-diagnostic.3 — cold-start observer bindings

October 25, 2026 (America/Los_Angeles). Developer diagnostic preview.

- Fixes three early captures of CET observer globals in `init.lua`. The quest
  and Guardian adapters now look up the same APIs when their protected
  registration functions run in `onInit`. No new observer targets are added.
- Restores attempted registration on a cold start when observer globals become
  available after initial mod loading. Missing or throwing APIs retain the
  existing unavailable result. Registration is not proof that a callback fired.
- Retains diagnostic.2's field-default correction and all native request checks.
  Save policy, native locks, request dispatch, queue and phone detection are
  unchanged. Existing engine callbacks remain uncorrelated result hints.
- Adds a cold-start lifecycle regression using the actual Lua modules and an
  exact source-preservation layer. Updates version labels and auditor pins.

The uploaded diagnostic.2 report records `native_accepted=true` for a vehicle-
combat quicksave with Combat and Script locks, but the user reports no visible
save. That downstream failure remains unresolved. The report also records zero
Guardian registrations and unavailable quest observation; the startup fix
addresses that separate, source-backed tracing defect.
