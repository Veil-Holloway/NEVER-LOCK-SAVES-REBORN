# RC3 installation auditor refresh — offline validation

The embedded checker pins all 16 finalized **1.0.0-rc3** runtime files (13 CET Lua files and three REDscript files). This refresh changes the release label, exact runtime sizes/hashes, embedded inventory digest and descriptive text. It adds a separate `rc3_label` log counter and retains the earlier `rc1_label` and `rc2_label` counters. The filesystem scan, link handling, limits, read-only behavior, result statuses and privacy behavior are unchanged.

The runtime inventory is byte-specific. Clean file matches establish installed source identity only, and do not establish REDscript compilation or successful saving.

Fresh command on a mirrored RC3 package:

```sh
python3 -B -m unittest discover -s work/rc3_audit/test_release/tools/NLSRInstallAudit/tests -p 'test_*.py' -v
```

Result: **89 tests passed, no skips**. All earlier test names remain. Log fixtures now check RC1, RC2 and RC3 counters independently, including mixed-case RC3 text. These tests use real temporary filesystem inputs and CLI subprocesses; the game is not launched.

Three additional disposable game-root probes gave the expected results:

| Probe | Exit | Observation |
| --- | --- | --- |
| All 16 RC3 runtime files | 0 | Exact runtime match |
| Main REDscript replaced by retained RC2 source | 1 | Runtime drift |
| CET init replaced by retained RC2 source | 1 | Runtime drift |

Each probe preserved its input file set, byte hashes and modification timestamps, and emitted no private path or raw-error leak. Optional log observations remain unscoped and do not claim current compilation.

No Windows-specific runtime, Cyberpunk launch, REDscript compilation, actual save creation, reload, restoration or quest progression is verified. The RC3 Smart interaction-queue behavior still requires an actual game test.
