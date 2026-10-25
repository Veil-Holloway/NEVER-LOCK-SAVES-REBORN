# Vehicle checkpoint diagnostic validation

October 25, 2026 (America/Los_Angeles). Build **1.0.0-vehicle-diagnostic.1**.

**Actual vehicle-combat saving remains unresolved.** The user reports that RC4
shows a notification but never creates a visible save, even after combat. That
failure is not erased by these offline results. This preview repairs unchecked
request-result reporting and captures the boundary needed for the next game test.

Fresh integrated validation: **68/68 groups passed**, exit 0. The verified clean
preflight ZIP extraction also passed **68/68 groups**, exit 0. Its manifest used
a zero-filled placeholder source commit; final provenance is generated only
after the real source commit exists. The final package must preserve all 109
frozen code/fixture records and verify its own complete manifest. The command was
`python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output <evidence-directory>`.
Exact commands, exits and logs are retained in the integrated RESULTS.json.
Python 3 and `/usr/bin/texlua` (Lua 5.3 test host) exercised actual Lua and a
constrained REDscript-source evaluator with external game-service doubles.
These checks do not compile REDscript or establish CET LuaJIT behavior.

- Native-result regression: **1,943 assertions**, zero failures/boundary errors.
  Original RC4 produces **20 intended failures**, zero boundary errors. Six
  behavioral mutations were detected: discarded native false, removed intro
  guard, ignored notification switch, wrong rejection result, ignored helper
  return and broken serial bounds.
- Report sanitizer: **692 assertions**, RC4 negative control and four detected
  behavior mutations. Native true/false remain distinct from Unknown write/reload.
- Existing Smart **2,082**, Unrestricted **9,641**, autosave **27,673** assertions
  and fresh-introduction **384 cases** passed through the adapted real helper.
  The adapters add method bindings/state and explicit native return values;
  earlier behavioral assertions remain in place.
- New exact scope guard: **13 mutations** detected. Historical fixture bytes are
  unchanged; prior RC4/RC3/RC2/RC1 **16/14/12/9** controls still pass. Only exact
  fully pinned candidate files normalize for historical source-identity checks.
- Installation auditor: **89 tests**, no skips. Clean candidate CLI exits 0;
  stale RC4 REDscript/init each exit 1. Input bytes, size and mtime remain
  unchanged and temporary private paths do not appear in the audit result.
- Independent review checked all four request paths, one-shot/reentry handling,
  introduction/source/safety gates, notification OFF and DF message switches.

The independent tests caught an initial notification-OFF regression caused by
adding a suffix to an empty message. Explicit master-switch guards corrected
all four affected paths before the fully passing run. An initial harness-only
else-if parsing failure was preserved, then fixed before the fresh green run.
Neither earlier failing run is represented as a pass.

**Coverage limits:** the last-attempt snapshot describes the latest call into
Reborn's shared checkpoint helper on the current player, not the currently
queued request or a correlated native completion. Early deferred preflight
rejection (including missing service) preserves the previous queue contract and
may leave an older snapshot. Immediate routes capture missing-service failures.
A native true result still does not prove that a file was written or will load.

**NOT RUN:** native REDscript compilation, actual CET/game execution, visible
vehicle-combat save creation, reload/quest progression, Windows restoration and
full optional Dark Future/framework compatibility. No guessed alternative API,
native lock removal, retry loop, quest-fact repair or save-byte editing was added.
See DIAGNOSTIC-VEHICLE-SAVE.md for the required real-game procedure.
