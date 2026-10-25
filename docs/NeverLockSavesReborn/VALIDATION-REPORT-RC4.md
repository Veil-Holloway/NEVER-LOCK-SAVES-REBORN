# RC4 verification

The user reports Unrestricted creates a queue during vehicle combat rather than
saving. Actual-source RC3 reproduction confirms Deferred ON intercepts the direct
checkpoint attempt. RC4 repairs manual routing and stale manual work cleanup;
all other native/automatic/Smart/intro guards remain. No new engine API is used.

Fresh integrated verification: 63/63 groups pass. The focused actual-source suite
passes 9,641 assertions with zero boundary errors; the RC3 baseline produces
2,639 intended failures with zero boundary errors. Six behavior mutations and
sixteen RC4 scope mutations are detected. Older RC3/RC2/RC1 controls still pass.
Only intentional Unrestricted mode oracles change in three existing tests; the
autosave fixture gains its existing mode getter. See the packaged oracle diff.

The refreshed read-only auditor passes all89originaltests/noskips and three real
clean/stale-source CLI probes. Independent source review passes6,864 assertions;
15prior methods retain exact bodies. Fourteen other runtime and all five recovery
companion files are identical. Complete source diff/freeze and manifests are kept.

These tests run Lua5.3/constrained actual-source translation and service doubles,
not the native REDscript compiler or CET/game. RequestForcedCheckpoint remains an
attempt; the game may reject it. Actual vehicle-combat save creation, reload and
progression remain unverified and must be tested via TESTING-RC4.md. Extracted
package results and exact frozen record count are recorded in FINAL-RESULT.json.

RC3 remains the published prerelease. RC4 is prepared separately for review and
testing; no stable acceptance or automatic public release promotion is claimed.
