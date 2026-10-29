# scope-reconciliation.1 — unreleased documentation/package revision

October 29, 2026 (America/Vancouver). Runtime identity remains
`1.0.0-vehicle-diagnostic.3`; this is not a new game-save fix or stable release.

Applies the October 28 v2.6 scope freeze: removes the Windows/Python
`tools/NLSRSaveGuardian` companion and its active tests from source/package scope,
withdraws backup/retention/recovery and automatic-character roadmap claims, and
keeps bounded Guardian request tracking, manual settings presets and supported
configuration recovery. No native save route, lock, queue or quest fact changes.
The only runtime-file edit is one CET panel sentence explaining the removal.

Published releases/tags/assets and historical test records remain unchanged.
The latest GitHub diagnostic.3 full archive still contains the old companion;
it is a historical artifact, not a scope-clean current package. The current
review-package builder uses `scope-reconciliation.1` names and fails if the
companion reappears. No release/tag is created by the builder.

Vehicle-combat request acceptance has been observed, but actual vehicle-combat
save creation, reload integrity and progression remain unresolved. The retained
on-foot physical-save control does not establish vehicle-combat success.
PR #1 remains draft. Offline checks cannot justify merge or stable publication.

Verification, package identities and rollback: PACKAGING-SCOPE-RECONCILIATION.md.
