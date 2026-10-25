# Independent preRC4 dependency diagnostics review

Verdict: **passes the scoped offline contract**. No unresolved material finding
in the final reviewed source. This is not actual CET, native ABI, Windows or game
acceptance and does not establish dependency compatibility.

## Target and fresh evidence

- init SHA-256: `d01299cf73937deb60f6ae9885182bda65f82a023f0e8b9149e5f9835430cf77`.
- Collector SHA-256: `32c132404062f25594684567b4a50acdbc61687e6eb59fee8a25fbee2393b53a`.
- Report SHA-256: `0dfdd44ae3baa6a5a20b0a2121e2844b52e1be4ae6f4b0db366aa061e6c838c6`.

The independently authored actual-init suite passes **16,590 assertions across
38 fixtures**. It executes the shipped init, report, collector, Guardian ledger
and deferred-queue modules. External CET/Game/UI and report storage are controlled
boundaries. The broad count includes recursive output shape/privacy assertions;
it is not 16,590 independent gameplay scenarios.

The portable runner also detects **four intended mutation controls**:

| Mutation | Intended observed failure |
|---|---|
| Discard collected versions before report construction | Available APIs remain unknown in actual export |
| Cache the first collector result | Changed API values do not appear on later export |
| Remove per-reader protected call | One throwing getter loses the required isolated failure status |
| Read optional collector methods through an unguarded index | A malformed collector's metatable aborts support export |

Each mutant exits nonzero at its expected assertion, rather than merely failing
for an unrelated syntax/environment error. Final source and test hashes,
commands/results and log names are recorded in `final/RESULTS.json`.

The authenticated preRC3 input fails the intended
`NLSR-DEPENDENCY-EXPORT` regression: actual support export does not sample
available source-backed getters. Its failure is retained separately.

During the new feature's integration, a separate focused control reproduced an
unguarded `dependencyVersions.sample` field lookup invoking a throwing
metamethod and writing no report. This was a new-integration issue, not an
additional preRC3 defect. Root corrected it using a plain-table/raw-field
boundary. The final tests verify useful report export with all versions unknown,
without invoking that malformed module's index metamethod.

## Contract coverage

- CET tags normalize their optional lowercase `v` and preserve safe git suffixes.
  Codeware uses its string API. Native Settings uses its numeric declaration;
  no three-part package precision is invented.
- The exported flat dependency values and per-component status/source rows are
  validated through actual support-export button actions. Old flat field types
  remain strings; the existing game-version observation is retained.
- Every support export samples current values afresh. Missing, throwing and
  malformed getters affect their own component while other supported readers
  continue and a useful report is written.
- Unsupported REDscript, RED4ext and Dark Future versions stay unknown. Direct
  collector tests supply throwing functions for those and extra keys; none are
  invoked. No private migration constant is used as a public version.
- Both no-player and active-player paths run 1,000 updates and 100 overlay draws
  plus a separate real Guardian export without additional version API reads.
  The existing Native Settings UI lookup at initialization is treated separately
  from new diagnostic polling.
- Missing/non-table/no-method/poisoned/throwing collectors and malformed return
  values leave an ordinary support report with unknown versions and not-sampled
  provenance. Raw errors, paths, unsafe strings and objects do not enter output.
- Native Settings export tables must be plain; raw field access does not invoke
  arbitrary index methods. Returned version objects do not invoke `__tostring`.
- Selected mode, tone, combat/vehicle switches, queue fields, lane enables and
  settings-write counts remain unchanged by diagnostic collection. A dry-run
  pending request seeded through the actual UI survives report export unchanged.
- Output tables remain plain, finite, bounded, JSON-compatible and free of the
  synthetic private-data sentinels. Scope remains runtime self-report and
  compatibility remains unverified.

## Independent scope review

Whole-byte normalization removes only the new module load, on-demand sampling
block, snapshot version/evidence fields and version labels; the result exactly
matches preRC3 init SHA-256
`5330c2d0aa71dcca8ce9bbc5ae63b11e45b0be83dc70eac2768661ae347d3054`.
The report normalizes to its unchanged preRC3 body after removing only the fixed
keys/evidence helper and replacing its dependency loop. Complete REDscript differs
only in version labels. The remaining **16 existing runtime/helper code files**
are byte-identical. `SCOPE-REVIEW.json` records those comparisons.

The new collector has no Game/IO/logging/RNG/global API calls or mutable cache;
it receives explicit reader functions and returns fresh scalar/table output.
The report extension is additive and retains schema version 1. Source/API
research is recorded separately in the author's pinned API evidence; this review
executes the declared interfaces through doubles and does not validate native
method dispatch in an installed CET/Codeware build.

## Limits

The host is Lua 5.3 via texlua, not CET LuaJIT/Lua 5.1. No actual Windows process,
game compiler, runtime dependency binary, save writing, reload or quest progression
was exercised. An API self-reported version does not prove a complete installation,
current compilation, compatibility, or any save outcome. Native numeric labels
cannot establish release-package precision. Unavailable/not-supported states do
not assert that a framework is absent from the user's installation.
