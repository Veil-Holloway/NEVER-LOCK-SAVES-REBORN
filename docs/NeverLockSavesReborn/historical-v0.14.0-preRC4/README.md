# Never Lock Saves: Reborn — 0.14.0-preRC4

**Release Testing Preview / Developer Preview.** Builds on user-reported working
preRC3. This update improves the local support report's dependency versions;
new game/Windows acceptance remains outstanding.

## New: dependency versions in support export

Click **Export support report** in the CET overlay. The local
`support-report.json` now attempts to read available CET, Codeware and Native
Settings version declarations. Every export samples fresh values. There is no
background version polling and no automatic upload.

`dependencies` retains the existing string-valued fields and adds `codeware`.
`dependency_evidence` records a fixed status/source for each dependency:

- `observed`: that loaded API supplied a valid version value.
- `unavailable`: the selected version API supplied no value.
- `read_failed` or `invalid`: its read failed or its value was rejected.
- `not_supported`: this collector has no established version getter for that dependency.
- `not_sampled`: version evidence was not supplied or could not be accepted.

REDscript, RED4ext and Dark Future versions remain unknown. Their version status
is not a claim that the framework is absent or that DF integration is broken.
An observed version is a self-report, not a compatibility or compilation pass.
Native Settings supplies a numeric declaration; it cannot establish trailing
zeroes or an exact three-component download-package version. CET's optional
leading `v` is normalized, while a valid Git suffix is retained.

Missing optional modules, failed readers and malformed values leave appropriate
unknown fields while the rest of the report can still be exported. Raw API
errors, object handles, paths and URLs are excluded. Report schema remains 1
with additive fields. No new settings are introduced.

## Install and next test

1. Close the game. Retain complete preRC3, external game-save backups, and copies
   of `config.json`, `profile-settings.json` and their `.bak` files.
2. Install `bin/` and `r6/` at the game root as one complete Reborn installation.
   Preserve settings and remove duplicate older Reborn scripts. No framework
   binaries or actual user settings/saves are bundled.
3. Launch, inspect fresh REDscript/CET logs and confirm `0.14.0-preRC4`.
4. Export the support report and compare its available version values with your
   installed versions. Record unknown versions manually in the test matrix.
   Export again to confirm useful report output, then send the JSON with the
   actual save/reload/progression outcomes from your game tests.

The report is written inside
`bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/`.
Review it before sharing. Detailed cases and the compatibility matrix are in
`docs/NeverLockSavesReborn/IN-GAME-TEST-PLAN.md` and `TEST-MATRIX.csv`.
The old preRC2-only installation checker remains pinned to preRC2 and will
correctly flag this build as changed; use this build's manifest/version/checksum.

## Existing behavior and rollback

preRC3's validated main-settings recovery, manual presets, four save modes,
intro guards, one-item queue, optional autosaves and status messages are retained.
Original-apartment entry still covers only `LittleChina_VApartment`. Automatic
persistent character binding, broader owned-safehouse coverage and correlated
live-write evidence remain open. Queueing, dispatch and UI acceptance do not
establish a written, reloadable or progressed save.

The optional `tools/NLSRSaveGuardian/` companion remains manually run with the
game closed; read its README. Config backups are not game-save backups. No quest
facts or game-save bytes are changed.

For rollback, close the game, remove this build's `dependency_versions.lua`,
and reinstall complete preRC3 with its retained config and preset bank. This
build adds no settings fields or preset schema changes. Keep external save and
recovery copies separately.

## Offline verification

Python 3.10+ and texlua/luatex:

```sh
python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output /path/to/results
```

These checks use actual Lua modules and controlled CET/Game/UI/store boundaries,
not the installed native APIs, a REDscript compiler, Windows or a live game.
See the validation report, source diff and primary-interface evidence for exact
scope. Attribution is retained; upstream redistribution permission is unresolved.
