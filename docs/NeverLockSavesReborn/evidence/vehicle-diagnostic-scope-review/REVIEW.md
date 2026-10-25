# Diagnostic scope and installation-auditor verification

The candidate normalizer requires a complete exact pinned diagnostic file before applying reviewed line splices to recover exact RC4 bytes. All other changes pass through unchanged and fail earlier guards. Existing historical fixtures are byte-identical.

Production scope: three runtime files change (native Bool capture/failure feedback and request-only suffix, CET on-demand snapshot, sanitized support-report section). Thirteen runtime files and all five existing recovery-companion files remain byte-identical to RC4. The installation auditor updates only its release/pins, matching release assertion and package description.

Fresh post-integration runner: **68/68 groups passed**, exit 0, in `../scope_checks_final/RESULTS.json`. The first run preserved in `../scope_checks` had a single harness failure: the bounded translator had not yet added strict else-if handling for the notification guard. After adding the supported strict translation, the fresh introduction test passed 384 cases and the complete runner passed. No failure was reclassified as a gameplay pass.

Source identity controls: 13 diagnostic mutation controls and the original 16 RC4, 14 RC3, 12 RC2 and nine RC1 controls passed. Historical controls operate on exact recovered historical byte views; the new diagnostic controls operate on current candidate bytes. Eight prior fixtures are unchanged. Functional native-result tests execute current candidate source with explicit external native doubles.

Auditor unit tests: 89 passed, no skips. CLI probes: clean installation exit 0; stale RC4 main REDscript and stale RC4 CET init each exit 1. Each probe preserved all input bytes, sizes and mtimes; raw temporary-root paths were absent from JSON.

These results are offline source/Lua/Python boundary evidence. Native REDscript compilation, CET LuaJIT compatibility, actual vehicle-combat save creation, load-menu visibility, reload and quest progression are not demonstrated. The build diagnoses an unresolved save failure and repairs misleading feedback; it does not establish an actual vehicle-combat save fix.
