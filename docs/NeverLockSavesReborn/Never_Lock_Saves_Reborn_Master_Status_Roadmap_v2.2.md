> Historical development snapshot. Current permission and acceptance status: [PUBLICATION-STATUS.md](PUBLICATION-STATUS.md).

# Never Lock Saves: Reborn — status and roadmap v2.2

October 24, 2026 (America/Los_Angeles). Current candidate: **1.0.0-rc3**.

## Current correction

The user reports Smart save queue failure and the vanilla cannot-save message
while interacting. Exact installed package/game/framework versions were not
supplied. A fresh authenticated RC2 baseline reproduces the mechanism in all
three actual-source save hooks: queue admission was nested under immediate
forced-checkpoint permission, which Smart denies for interaction/scene locks.

RC3 checks Smart deferred admission independently. Native saving permission,
introduction completion, stable window/cooldown and matching serial still gate
release. With Deferred Save OFF and no combat exception, Smart emits a truthful
custom blocked message without queueing or forcing. Quicksave busy guards,
notification switches, other modes and the one-item queue remain intact.

Only two runtime files differ from RC2: the REDscript helper/three calls and eight
version labels across REDscript/CET init. The remaining 14 runtime files and all
five recovery-companion files are identical. RC2's native autosave type fix is
retained. No dependency, configuration schema, runtime file or new API is added.

The offline validation report records actual results and their limits. Native
compilation, interaction-time display and save/reload/progression remain separate
runtime acceptance checks. The reported failure supersedes broad working feedback
for that path; it does not establish failures in unrelated tested scenarios.

## Approved first-release scope

The approved Option A scope remains unchanged: four modes; introduction protection;
optional one-item deferred queue and bounded autosave triggers; validated settings
and explicit presets; read-only DF integration; contextual messages, support export
and request-level Guardian; separate manually run closed-game recovery companion.
Apartment coverage remains only LittleChina_VApartment. Queued manual requests are
checkpoint requests. Written/reloaded outcomes stay Unknown without evidence.

Automatic persistent playthrough binding, all-owned-safehouse triggers, automatic
live backups/write-reload correlation and dependent completion messages remain
explicitly deferred until after 1.0.

## Next stages

1. Install/deploy RC3 and confirm fresh compilation and version identification.
2. Test Smart interaction quicksave with Deferred Save ON, queued feedback, pending
   while locked and one request after unlock/stability; separately verify actual
   save creation, reload and progression. Check all three request routes and queue
   OFF/master notification behavior. Record environment versions and exact cases.
3. Complete remaining relevant supported-environment acceptance and settings,
   optional-mod, installation/rollback and Windows recovery cases. Existing
   recorded unaffected checks need not be repeated without a new reason.
4. Resume the private repository handoff with current corrected source after
   acceptance. The user is arranging upstream permission. No public repository,
   release, author contact or whole-package MIT grant has been created.
5. Promote to stable 1.0 only after material regressions and acceptance/permission
   gates are resolved; pursue approved deferred features after 1.0.

The 47-row matrix retains historical statuses, the RC1 compiler failure and the
new reported Smart interaction failure, plus three untested RC3 changed paths.
The original v1.1 requirements and v2.0 approved scope remain historical inputs;
v2.1 records the RC2 type correction. This revision records the Smart routing fix.

Based on Never Lock Saves v2.2.1.0 by RalphModding. The separate permission message
remains a draft; the user will arrange permission before public publication.
