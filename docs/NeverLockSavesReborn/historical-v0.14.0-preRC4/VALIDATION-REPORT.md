# preRC4 validation report

October 24, 2026 (America/Vancouver). **0.14.0-preRC4 Release Testing Preview /
Developer Preview**. No stable promotion or actual native/game compatibility pass.

## Provenance and gap

The project Drive folder was freshly listed. Runtime input preRC3, ID
`1d3f6-kmx62iWSoPvKDiLvdlCFiUzNgV0`, modified `2026-10-24T17:42:22.232Z`, was
fetched again through authenticated access: 406,625 bytes, SHA-256
`ee0c241600e454fd690340dbc6e4c4dd58a3ee4255ff343a09901e4532a89229`.
CRC and all 222 manifest entries passed. Immutable input/baseline remain separate
from staging. Older releases are retained, with no overwrite.

The user reports preRC3 working with unspecified fingerprint, versions and test
coverage. This does not independently pass new API, compiler, Windows or game rows.

Actual preRC3 support export always passed `versions={}`. Independent actual-init
and report-module tests fail at their intended dependency-export/evidence assertions.
The new feature fills supported version values only during explicit support export.

## Positive source contracts

Exact commits, file blob identities, short declarations and URLs are in
`interfaces/dependency-versions/API-EVIDENCE.json` and its recommendations.

| Component | Proven read | Output interpretation |
|---|---|---|
| CET | Global `GetVersion()` returning CET_GIT_TAG | Loaded CET Git-tag/build string; one optional leading `v` removed, valid Git suffix retained |
| Codeware | Static `Codeware.Version()` returning String | Loaded facade's project-version self-report |
| Native Settings | `GetMod('nativeSettings').version` from returned plain table | Numeric module declaration; not an exact archive-version/three-component label |
| REDscript / RED4ext / DF | No suitable getter established | Version stays unknown/not_supported; no absence or global API-nonexistence claim |

The private DF Float 2.0 is a migration marker, not a proven public package-version
getter. It is not read or substituted. No method-name probe loop, file/path parsing,
plugin installation or version guess is added.

## Implementation and evidence

A pure optional collector takes fixed callback boundaries. It produces six fixed
version strings and six fixed status/source rows. Reads fail independently; unsafe
values and raw API errors/objects never reach exported text. Unsupported readers
are never invoked. CET/Codeware use bounded numeric-leading tokens; Native Settings
requires a finite 0..1,000,000 numeric declaration, controlled scalar formatting and
only decimal digits/dot. Numeric precision/trailing zeroes cannot be reconstructed.

The collector is loaded through the existing optional-module seam and called only
within explicit support export. Repeated exports read again. Missing, nonplain,
malformed or throwing collector modules leave report output usable with unknown
version evidence. An early new-integration poisoned-module control caught an
unguarded `sample` field access; the final integration uses a plain-table/rawget
boundary and the same fixture passes without invoking its metatable. This was a
new-integration finding, not an additional preRC3 gameplay defect.

Report schema remains 1. Existing dependency strings are retained, Codeware and
`dependency_evidence` are additive. Fixed source IDs/status combinations are
validated, and observed evidence requires a valid corresponding version.
`compatibility` is always unverified. Save/queue/Guardian completion evidence is
not upgraded from these diagnostic values.

| Acceptance criterion | Fresh evidence | Result |
|---|---|---|
| Available versions reach actual export | Actual init/report/collector with controlled native boundaries | Confirmed offline |
| Repeated export is fresh | Values changed between export calls; cache mutant rejected | Confirmed offline |
| Reader/collector failure isolation | Missing/throw/invalid/poisoned module and getter fixtures; report writer still called | Confirmed offline |
| No extra off-export polling | Active/absent-player fixtures, 1,000 updates +100 draws and actual Guardian export; version-read counters unchanged after warm-up | Confirmed controlled call budget, not game performance |
| Bounded privacy/provenance | Unsafe strings, objects, raw-error sentinels, source/status spoofing and bounds rejected | Confirmed offline |
| Settings/queue behavior retained | Actual public-UI dry-run pending request and settings remain intact; exact source checks | Confirmed offline/source identity |
| Installed native/API/game behavior | No current native/CET/game execution here | Unverified |

## Fresh verification

All **51 integrated and 51 extracted-package groups pass**, including all previous 46 groups rerun on the
final source. New checks include:

- Collector: **834 assertions**.
- Report sanitization/provenance: **554 assertions**.
- Independent actual init/export: **16,590 assertions across 38 fixtures**; counts
  include recursive output checks and repeated-frame budgets, not gameplay cases.
- **Nine author and four independent intended mutation controls** detected, covering
  formatting, unsupported/provenance claims, omitted values, stale caching, reader
  isolation and unsafe collector access.
- Exact new diagnostic source identity, chained with prior main-config recovery
  preservation. Thirteen runtime Lua files are syntax-checked.

The baseline's 46 groups pass separately. One initial runner entry incorrectly
passed the collector test a directory rather than its required filename; the runner
argument was corrected, the focused test passed, and the final complete run passed.
No product failure was hidden or reclassified as a successful first run.

Fresh commands/exits/logs are packaged under `evidence/integrated/`, with focused
runner result files in subdirectories. Independent review and source diff are included.
The report export integration uses controlled CET/Game/UI/store boundaries, not an
actual Windows report-file write. Existing real-file config-store/recovery suites
were also rerun. Actual native ABI and framework versions remain user acceptance.

## Source and packaging checks

Final runtime hashes:

- init.lua: `d01299cf73937deb60f6ae9885182bda65f82a023f0e8b9149e5f9835430cf77`
- dependency_versions.lua: `32c132404062f25594684567b4a50acdbc61687e6eb59fee8a25fbee2393b53a`
- support_report.lua: `0dfdd44ae3baa6a5a20b0a2121e2844b52e1be4ae6f4b0db366aa061e6c838c6`
- main REDscript: `9a8580e237a9b08c55a2eacdd02262749d1ebe0b840298b165ef2be8ff966365`

Whole init normalizes to preRC3 after removing only the optional-module/export
seam and version labels. Whole report normalizes after removing only additive
dependency helpers/fields. Complete REDscript differs only in version labels.
Seventeen other runtime/helper files remain identical. The prior config recovery
proof remains enforced after this explicit normalization; it is not broadly disabled.

The complete ZIP supplies installable bin/r6 paths, optional closed-game companion,
current tests/docs, source diff, manifest, matrix and rollback notes. It contains no
user config/save files, bytecode caches, temp fixtures, framework binaries or signed
URLs. Safe unique/casefold-unique paths, CRC and all manifest hashes are checked.
All 76 runtime/tool/test source files are frozen and compared with extracted-tested
bytes. Extracted-package logs are added under `evidence/extracted/` without changing
code. Final delivery SHA-256 appears in the external report/sidecar to avoid a
circular self-hash.

## Limits and next gate

Tests execute on Lua 5.3 with doubled native/game boundaries, not CET LuaJIT/Lua 5.1,
a current REDscript compiler, Windows or the game. Version observed does not prove
installation completeness, compatibility, current compilation, save creation,
reload or quest progression. Exact installed/dependency versions and those runtime
outcomes remain unverified here. There is no new background IO, upload, setting,
quest write, save-byte edit or backup/restore operation.

Install and export `support-report.json`, then record actual versions and individual
save/reload/progression results in TEST-MATRIX.csv. Automatic identity, correlated
live writes, broader owned-safehouse coverage and upstream redistribution permission
remain release gates. Rollback removes the new collector file and reinstalls complete
preRC3 with retained config/preset-bank backups. The old preRC2-only auditor remains
pinned to its own release. Offline success alone cannot establish a stable build.
