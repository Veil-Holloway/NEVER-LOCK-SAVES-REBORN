# RC4 installation auditor refresh — offline validation

The checker pins all 16 finalized **1.0.0-rc4** runtime files (13 CET Lua files
and three REDscript files). It refreshes exact runtime sizes/hashes, the embedded
inventory digest, release labels and descriptive text. It adds `rc4_label` while
retaining the separate RC1, RC2 and RC3 counters. Filesystem scanning, link checks,
limits, read-only behavior, statuses and privacy rules remain unchanged.

## Fresh verification

```sh
python3 -B -m unittest discover -s work/rc4_audit/output/test_release/tools/NLSRInstallAudit/tests -p 'test_*.py' -v
```

**89 tests passed, no skips.** All original test names remain. Added assertions
inside the existing log tests check RC1–RC4 independently, including mixed-case
RC4 text. Inputs are real disposable filesystem trees; the game is not launched.

Independent CLI probes: clean RC4 runtime returns 0/exact_match; stale RC3 main
REDscript and stale RC3 init separately return 1/drift_or_review. Every probe
preserves input bytes, file sets and modification times. Private path/name/log
poison markers do not leak, and log-derived compilation remains Unknown.

Independent bounded execution performs **6864 assertions** against the actual
changed queue and mode-setter methods, with zero failures. Source comparison
confirms 15 existing native/automatic/Smart/notification/request-hook methods
match RC3 exactly. Those checks establish source behavior, not engine acceptance.

RC4 makes Unrestricted user requests attempt immediately after introduction
protection instead of being intercepted by the manual queue. Mode changes clear
old manual work while retaining the separately enabled automatic lane; a fresh
Unrestricted user request takes priority over prior pending work. Actual vehicle
combat save creation, native compilation, reload and progression remain untested.

No Windows-specific runtime, Cyberpunk launch, actual save writing, restore or
stable release is established by this tool or its offline tests.
