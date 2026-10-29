# Scope reconciliation verification — October 29, 2026

Runtime `1.0.0-vehicle-diagnostic.3`; package revision `scope-reconciliation.1`.
Specification result: offline source/package scope corrected. Runtime acceptance:
partial; actual game/native/save/reload/progression checks remain NOT RUN and
vehicle-combat saving remains an unresolved reported failure. No stable claim.

## Fresh offline results

- `python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output .../validation-final`
  returned exit **1**: **54/69 active groups PASS, 15 FAIL**, plus three explicit
  `SKIP_REMOVED_SCOPE` companion groups. This is not an all-green suite.
- The 15 failures are historical exact-source inventory/hash/preservation guards
  and their mutation controls. They still require the removed companion or the
  exact older `init.lua` sentence/normalization chain. They are retained as failed
  evidence; no historical fixture was normalized or weakened. Failed groups:
  `diagnostic3_source_scope`, `diagnostic2_source_scope`, `preserved_scope`, `dependency_scope`, `rc1_source_freeze`, `vehicle_diag_source_freeze`, `vehicle_diag_scope_controls`, `rc4_source_freeze`, `rc4_scope_controls`, `rc3_source_freeze`, `rc3_scope_controls`, `rc2_source_freeze`, `rc2_scope_controls`, `rc1_scope_controls`, `main_config_scope`.
- Existing Guardian ledger/observer/integration, cold-start observation, manual
  preset memory/disk/fault checks, validated settings recovery, queue/native
  routes, Smart Autosave, read-only Dark Future and support-report groups PASS.
- The installation auditor now pins the single revised CET panel sentence and
  other 15 unchanged runtime files; all **89 existing auditor tests PASS** after
  its inventory digest was regenerated. Its initial stale-pin failure was
  diagnosed before the final suite; no final auditor failure is hidden.
- `python -m py_compile .github/scripts/build_scope_reconciliation.py .github/scripts/build_vehicle_diagnostic.py`
  returned exit 0. `git -c core.whitespace=cr-at-eol,-blank-at-eof diff d0df838 --check`
  returned exit 0 (raw captured logs retain their original final blank lines);
  the one edited Lua sentence preserves the existing CRLF bytes.
- Direct comparison with baseline `d0df83807c9ba2899d195fdb40d934c32d7183ee`
  confirms exactly one runtime string edit; no `r6/` file, native save/queue/lock
  behavior or Guardian/manual-preset implementation changed. Existing evidence,
  fixtures, historical packages, MIT and attribution remain unchanged. Twelve
  archived original documents/runner/manifests match baseline bytes exactly.
- Deterministic package preflight returned exit 0 and reverified ZIP CRC, each
  file size/SHA-256, embedded/external manifests, unique package revision, null
  tag and `unpublished_review_only` state. A disposable reintroduced
  `tools/NLSRSaveGuardian/save_guardian.py` fixture was rejected. The historical
  builder refused scope-reconciled source. Preflight used an explicit fixture
  source SHA and is not deliverable provenance. Final review artifacts must be
  built from the exact clean committed source; the current builder enforces both
  matching HEAD and a clean worktree before packaging.

Raw final runner results/logs and packaging preflight evidence are retained at
`docs/NeverLockSavesReborn/evidence/scope-reconciliation.1/`. Package SHA-256,
exact source commit and file inventories are emitted in final review manifests;
no manifest hash is a game acceptance claim.

## Remaining acceptance

No Cyberpunk runtime is available here. Native REDscript/CET compilation, current
CET panel display, framework compatibility, save creation, reload integrity and
quest progression are NOT RUN for this revision. Keep PR #1 draft. Retain the
reported missing vehicle-combat saves and limited on-foot physical-file control.
Continue parked-vehicle/noncombat and mounted-combat comparisons with one request,
Smart Autosave OFF, fresh reports and actual file/load/progression observations.
Then execute the v2.6 four-mode, deferred queue, autosave/quest, Dark Future,
settings/restart and install/update/rollback acceptance on supported versions.

The 15 historical identity guards need a separately reviewed current-revision
adapter if they are to certify this changed inventory. They are not evidence of
an observed gameplay regression, and they are not reported as passing.
