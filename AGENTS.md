# Current scope authority

October 28, 2026 v2.6 addendum supersedes conflicting earlier feature plans.
See `docs/NeverLockSavesReborn/Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md`.
Game-save backup/retention/storage/recovery and automatic character identity
configuration are removed from source/package scope. Retain Guardian request
tracking, manual presets and supported settings recovery. This branch is the
unreleased `scope-reconciliation.1` package/documentation revision over runtime
`1.0.0-vehicle-diagnostic.3`; historical tags/assets are immutable. Current
packaging and test boundaries are in PACKAGING-SCOPE-RECONCILIATION.md.

---

# Never Lock Saves: Reborn

Preserve save integrity, quest progression, existing features, licenses and
RalphModding's credit. The project instructions revision 1.1 and attached master
roadmap govern scope; historical release numbers are not current acceptance.

Use small reviewed changes and verified game/framework interfaces. Never invent
a force-save API, remove native locks, change quest facts or rewrite save bytes
to conceal a failure. Preserve input packages, published tags and release assets.
Do not log secrets, private saves or arbitrary exception strings.

The current branch contains 1.0.0-vehicle-diagnostic.3. Vehicle-combat saving is
an unresolved user-reported failure, including after combat. The diagnostic.2 report records a native true request during Combat+Script locks,
but no visible save is reported. This preview also defers three CET observer
lookups until existing onInit registration; no new targets or save-policy change.
diagnostic.1 had a user-reported negative-field-default compilation failure.
The .2 hotfix removes those defaults and preserves unknown through reader guards.
Request acceptance is not a completed save, a usable reload or quest progression.
Early deferred preflight failures can leave an older attempt snapshot. Preserve
native gates, intro protection, one-item queue and one-shot behavior. No new retry
loop or actual save-creation fix is claimed.

Run the documented checks from the source root:

    python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output /tmp/nlsr-checks

Python 3.10+ and a Lua 5.3+ test host are required. Missing native REDscript/CET/
Windows/game checks are NOT RUN. Exact historical fixtures stay unchanged; only
fully pinned reviewed changes may normalize for historical identity guards.

The user authorized GitHub commits, pushes and prereleases with changelogs,
notes and identical Drive mirrors. Keep changes on a focused branch/PR. Every
completed build needs a unique version, immutable tag, installable ZIP, checksum,
manifest, validation evidence and rollback procedure. Generated ZIPs belong in
release assets, not new source commits. Preserve existing historical packages.

Dedicated trusted-branch workflows stage a diagnostic draft release, download
and verify its assets, then require an authenticated Drive readback receipt
before publishing it as a prerelease. Never promote this diagnostic to stable
or latest on offline evidence. Verify the exact source commit and bytes at both
destinations. No unsolicited external messages or private-data uploads.
