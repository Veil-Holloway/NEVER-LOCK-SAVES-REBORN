# scope-reconciliation.1 — current package contract

October 29, 2026 (America/Vancouver). This focused revision starts from GitHub
PR #1 head `d0df83807c9ba2899d195fdb40d934c32d7183ee` and retains its
`1.0.0-vehicle-diagnostic.3` runtime identity and save behavior. The package
revision is `scope-reconciliation.1`, unpublished and experimental. No release,
tag, merge, stable promotion or change to published assets is performed.
The newer Drive runtime is a separate lineage and is not silently imported here.

## Current scope and history

The exact v2.6 addendum is at
`docs/NeverLockSavesReborn/Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md`.
Game-save backup creation/hashing/rotation/retention/storage and recovery/restore,
backup-copy integrity monitoring and automatic character identity configuration
are removed. The five `tools/NLSRSaveGuardian` files are removed from current
source; their original sources/tests remain in Git history and historic releases.
Guardian ledger/observers and on-demand local reports remain retained. Manual
named presets (`profiles.lua`) and settings `.bak` recovery remain supported;
they do not identify characters or access game-save copies.

Historical release notes, fixtures, logs, tags and archives retain their original
meaning and bytes. The latest published GitHub diagnostic.3 full ZIP still
contains the five companion files: SHA-256
`e5ae77ca5de18836c2c92db5cfde6d9ab6383453d114c1ea2ccdfda2ead01ccc`,
7,392,014 bytes. It predates the freeze and is not a current scope-clean package.
The current builder omits the preserved historical `packages/` ZIPs from new
packages and refuses reintroduced companion paths anywhere else in its payload.
Historical documentation is explicitly provenance, never current instructions.

## Build review packages

From a committed clean source root, use its exact 40-digit commit SHA:

```sh
python .github/scripts/build_scope_reconciliation.py --source . --commit COMMIT_SHA --output dist/scope-reconciliation.1
```

The builder creates uniquely named source/tests and runtime-only ZIPs, external
SHA-256 and JSON manifests, and the current validation document. Runtime identity
and package revision are separate manifest fields; tag is null and publication
is `unpublished_review_only`. No publishing workflow is wired to this builder.
The previous diagnostic builder refuses this scope-reconciled source so it cannot
reuse the immutable diagnostic.3 artifact identity for changed bytes.
Runtime installation audit pins the one revised CET panel sentence as well as
the other 15 unchanged runtime files. Hashes establish identity, not game safety.

## Verification and limits

Fresh results are recorded in VALIDATION-SCOPE-RECONCILIATION.md. Run the legacy
suite with `python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output /tmp/nlsr-scope-checks`.
Its three removed-companion groups are no longer active. Historical source freeze
and mutation guards may still assume the old companion/UI bytes; fixtures are
preserved and such failures must be reported rather than rewritten as passes.
Current Guardian/manual-preset/configuration behavior needs its existing focused
checks, and packaging needs inventory/hash checks and a reintroduction rejection.

Vehicle-combat save creation, reload and progression remain unresolved. A native
true return and offline tests are insufficient. The retained on-foot physical-save
control has no independently correlated per-request write/reload proof. Continue
actual parked-vehicle/noncombat, mounted-combat, after-combat and reload/progression
checks from the retained diagnostic evidence, then four-mode/queue/autosave/DF/
settings/install acceptance on a documented supported framework matrix. No game
is available in this workspace.

## Install and rollback

Close the game and preserve external saves/settings. Install only the complete
runtime `bin/` and `r6/` trees with one Reborn copy enabled, Deploy and restart.
The panel retains .3; use the package revision manifest to distinguish this
scope-clean review payload. Stop at compilation errors. Roll back with the full
previous payload while closed, then Deploy and restart. Older packages may contain
the removed companion and unresolved vehicle-saving limitations; no known-good
vehicle-combat build is asserted. Do not run historical companion instructions.
