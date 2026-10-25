# preRC4 on-demand dependency-version diagnostics

Baseline: freshly authenticated preRC3 ZIP, 406625 bytes, SHA256
 ee0c241600e454fd690340dbc6e4c4dd58a3ee4255ff343a09901e4532a89229.
User reports preRC3 working; exact versions/cases remain unspecified.

Gap: actual support export always supplies versions={}, so dependency versions
are unknown even when a source-backed self-report API is available.

Outcome: on explicit support export only, sample three primary-source getters:
CET GetVersion() string git tag; Codeware.Version() string; nativeSettings mod's
plain-table version numeric export via GetMod('nativeSettings'). Source pins
and exact declarations must be documented. No API-name probing or fallback to
private migration constants, package filenames, timestamps or guessed methods.
REDscript, RED4ext and Dark Future versions remain not_supported/unknown.

Pure module dependency_versions.lua exposes sample(readers) returning exactly
{versions={six fixed keys},evidence={six fixed keys}}. Fixed keys: cet,codeware,
redscript,red4ext,nativeSettings,darkFuture. Known APIs have function boundaries;
no function, nil result=>unavailable; exception=>read_failed; bad output=>invalid.
Unsupported components=>not_supported without calling supplied reader. Success
=>observed. Only fixed source IDs cet_get_version,codeware_version,
native_settings_version,none. No side effects, caches, RNG, Game, IO or logging.
CET accepts bounded safe digit-leading version text after removing one optional
lowercase v; preserve allowed git suffix. Codeware accepts safe version string.
Native numeric version: finite bounded scalar only, controlled formatting to a
digit/decimal string (no exponent/sign/objects), documenting numeric API label
rather than inventing package precision. Never arbitrary tostring/metamethods.

Report schema remains1. Preserve old dependencies string keys; add codeware.
Add dependency_evidence {scope='on_demand_runtime_self_report',
compatibility='unverified', six components {status,source}}. Status allowlist:
observed,unavailable,invalid,read_failed,not_supported,not_sampled. Validate
source-component mapping; observed requires matching valid version data.
Absent/malformed evidence=>not_sampled/none. Raw values/errors/extra metadata,
paths, URLs and object handles never exported. Version is not installation,
compatibility, current compilation or successful save evidence.

init loads new module through existing optional() seam. Call only within
exportSupportReport, afresh each export. Getter faults isolated per component.
Missing/malformed/throwing collector cannot prevent remaining support export or
alter save policy/settings/queue. Integration passes values+evidence to report;
no calls at module load/onInit/update/draw/Guardian export. No new settings.
No new REDscript behavior, hooks, observers, DF readers or external helper code.

Write ownership: researcher owns dependency_versions.lua and support_report.lua
plus author tests in work/dependency_versions; root owns init/version labels,
runner/package/docs; independent reviewer owns work/prerc4/independent tests only.

Evidence: actual module/report tests, actual-init export with source-proven
getter doubles, baseline intended failure, fresh repeated exports, fault/missing/
invalid variants, bounded/privacy/adversarial cases, zero off-export calls,
settings/queue/policy unchanged, meaningful negative controls; old46 groups
fresh pass. Source preservation outside explicit diagnostic seams. Full clean
ZIP, manifest, diff, tests/limits, rollback, versioned matrix/report/roadmap;
upload new ZIP+sidecar and fullbyte readback. DeveloperPreview, not stable.
