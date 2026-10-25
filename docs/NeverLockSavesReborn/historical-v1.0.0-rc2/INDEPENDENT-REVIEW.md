# RC2 independent source and installation-audit review

October 24, 2026 (America/Los_Angeles).

**No unresolved blocking finding in the reviewed fix, preservation adapters or
installation-auditor refresh. Actual REDscript recompilation remains unverified.**

The supplied compiler log reports an unresolved `AutoSaveSystem` type in the
deferred dispatch declaration at line 170. I independently fetched the pinned
primary game-script declarations at commit
`cfcf5071e5363962a44c33cb7cab749688b0ca51` of
CDPR-Modding-Documentation/Cyberpunk-Scripts. `gameInstance.script` returns
`gameAutoSaveSystem` from `GetAutoSaveSystem`; `gameSystem.script` declares that
class and its `RequestForcedCheckpoint(): Bool` method. Returned blob identities
were `6113815dfcebbc98207a6ec394acff6df34fa1a8` and
`7dfa9b96334b35472ff4a543eddb02d344655fc9` respectively. This supports the exact
annotation correction rather than a guessed alternate spelling.

An independent byte comparison of the authenticated RC1 baseline and integrated
RC2 candidate confirms exactly one annotation replacement and eight version-label
replacements. All other 14 runtime files and all five original closed-game
companion files are byte-identical. The dispatch's pending/serial/native gates,
automatic-versus-manual lane guards, service null check, pending clear before
submission, forced-checkpoint call and request-versus-completion meaning remain
unchanged. The other three direct checkpoint calls are untouched.

The integrated validation subtree retains every original file and all 54 original
group names, adding three groups for a total of 57. Only four original validation
files change: the runner, RC1 source adapter, RC1 mutation-fixture adapter and prior
preservation adapter. The latter normalizes only a complete, exactly pinned RC2
file before applying the unchanged 49 protected-method hashes. My independent
temporary mutation flipping the dispatch pending guard still fails at the intended
`Changed protected method: NLSRebornDeferredDispatch` assertion. No broad source
replacement or disabled check substitutes for preservation.

The focused source contract rejects the RC1 baseline specifically at its reported
wrong type and passes RC2. I also executed the candidate exact scope, prior RC1
adapter, original nine mutation controls and new twelve controls in a complete
isolated validation tree. All produced their intended outcomes. An initial direct
invocation from the sparse output directory lacked the unchanged RC1 fixture; the
fixture setup was corrected without changing product or tests, and that setup
limit is recorded in `CONTRACT-PROBES.json`. These are source checks, not compiler
executions.

I independently recomputed all 16 refreshed installation inventory sizes/hashes
and its embedded inventory digest. Three public-CLI probes on real temporary
files pass: clean RC2 returns exact match/exit 0; stale RC1 REDscript or stale RC1
init bytes each return drift/exit 1. The auditor changes no input contents, sizes
or mtimes and omits private input paths. Its code refresh is limited to candidate
identity, matching pins and an additive RC2 log-label count; the old RC1 count is
retained and scans, bounds, no-write/privacy behavior and unknown compilation
status are preserved.

Evidence is in `INTEGRATED-SOURCE-AND-AUDIT.json`,
`INTEGRATED-VALIDATION-SCOPE.json`, `CONTRACT-PROBES.json` and
`ADAPTER-MUTATION.json`. `check_rc2_independent.py` reproduces the source/auditor
checks. The coordinator owns the complete final runner, extracted-package checks,
current release documents, archive integrity and authenticated delivery readback.

No current REDscript compiler/game cache, installed native ABI, CET LuaJIT/5.1,
Windows restore, real save creation, reload or progression was exercised by this
review. Correcting the reported type does not prove the entire mod now compiles
or that no later diagnostic exists. A fresh user launch/log is the next native
acceptance check. Upstream publication permission remains pending; no public
repository, release or author contact was made by this review.
