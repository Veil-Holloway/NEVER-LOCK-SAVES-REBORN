# On-demand runtime dependency-version research

October 24, 2026. Read-only source research. No production edits or game tests.
The exact repository commits, file blob identities and relevant lines are in
API-EVIDENCE.json. Fetches used the connected GitHub repository tools.

## Three supported observations

| Report key | Source-backed read | Proven type | Interpretation |
| --- | --- | --- | --- |
| cet | `GetVersion()` | String | CET build's Git tag from git-describe; may start with v and contain distance/hash suffix |
| codeware | `Codeware.Version()` | String | Codeware native facade returns its project's semantic-version string |
| nativeSettings | `GetMod('nativeSettings').version` | Number | Loaded NativeSettings module's declared numeric API/version value |

CET commit ed706fb8518712ffedf6b566e52873b257bc49fb exports GetVersion in
src/scripting/Scripting.cpp and whitelists it in LuaSandbox.cpp. xmake.lua derives
CET_GIT_TAG using git-describe with tags. This is CET's version, not the game build.
Do not parse arbitrary descriptive text, paths or object tostring output as a version.

Codeware commit a652bbbcf6feb65988c67f15f428e9398a3d827c declares the public
abstract native Codeware class in scripts/Facade.reds with static Version returning
String. Facade.hpp maps the internal C++ GetVersion name to the exposed name
Version. Facade.cpp returns the semantic version's string form. Do not call the
unexposed guessed method Codeware.GetVersion. The static call needs no player.

NativeSettings commit 4065b51456f5e3df8f29e1dc3c07edcc294e68e9 contains numeric
version 1.97 in nativeSettings/init.lua and returns the same table. README.md uses
GetMod('nativeSettings') as its documented import. Observe the actual raw version
field on a plain returned table, rather than introspecting arbitrary members.
A numeric field cannot recover trailing zeroes or three-component package labels;
report it as the module's numeric declaration, not a guaranteed Nexus archive label.

## Conservative implementation contract

Collect only when support export is explicitly invoked. Each external read and
format conversion is independently protected. No per-frame polling, filesystem
read, plugin reload, probe-name loop, dependency installation or state mutation is
needed. No failure can feed save policy or prevent the other independent reads.

For CET, strip at most the source-supported leading v and then accept the entire
bounded numeric-leading version token. Preserve valid git suffixes; do not mine
a version-looking substring from a larger unknown value. For Codeware, accept
only its entire bounded version string. NativeSettings needs controlled formatting
of a known finite bounded number; never stringify an arbitrary object/userdata.
A plain-table rawget avoids an unexpected __index callback on the optional module.

Current support_report.version permits strings only, <=40 bytes, numeric-leading,
letters/digits/dot/underscore/plus/hyphen. Canonicalize at the specific collector
seam or make an explicitly typed extension; avoid loosening free-form report
strings globally. Add codeware to the dependency allowlist if collected. Missing,
throwing, wrong-type or unsafe-format values stay unknown, with bounded fixed
status/source codes if the report contract supports those. No raw error text.

Version observed means only the loaded API reported a value. It does not prove
compatibility, current compilation of all mods, freshness of game caches, save
creation, reload or progression. Missing optional APIs do not establish missing
installations; keep unavailable/unknown wording honest.

## Keep three dependencies unknown

No runtime CET-callable RED4ext release-version getter was established. The
RED4ext GetVersion search returned internal C++ configuration/plugin interfaces,
not a safe public scripting getter. No runtime redscript compiler-version getter
was established either. File presence or another plugin working cannot manufacture
a version for either component. Manual acceptance labels can remain separate.

The supplied Dark Future DFMainSystem.reds has a private Float 2.0 and persistent
lastKnownVersion used by migration logic. That is not a proven public getter or
an exact distribution version. Do not add field/method probes or hardcode 2.0 as
the installed dependency version. Preserve unknown for darkFuture.

The search establishes usable positive seams, not a guarantee that no other API
exists anywhere. Installed compatibility of every new getter remains untested.
