# Never Lock Saves: Reborn — 1.0.0-rc2

**Release candidate for testing.** October 24, 2026 (America/Los_Angeles).

RC2 fixes the source declaration identified by the latest uploaded REDscript
compiler log. The log reports `UNRESOLVED_TYPE` for `AutoSaveSystem` at the
deferred-dispatch autosave variable. That declaration is present in RC1 and blocks
compilation in the reported installation, so the earlier broad working feedback
does not clear this failure for release.

The declaration now uses `ref<gameAutoSaveSystem>`, matching the verified engine
type returned by `GameInstance.GetAutoSaveSystem`. The checkpoint request and its
queue/native-permission guards remain unchanged. Runtime changes are this one
type annotation and eight identification labels updated to `1.0.0-rc2`. The other
14 runtime files and all five existing recovery-companion files are unchanged.

The source correction addresses the reported cause. A fresh compile and game
launch after the fix remain unverified here; this package is not a stable release.

## Install and first test

1. Close the game. Retain your pre-update installation, external game-save copies
   and Reborn's `config.json`, `profile-settings.json` and their `.bak` files.
2. Install this package's complete `bin/` and `r6/` trees at the game root. Preserve
   settings and keep one copy of Reborn's scripts. Framework binaries, user
   configuration and game saves are not bundled.
3. Keep the current dependency/mod setup for the first retest. This correction
   does not require a Dark Future installation or dependency changes.
4. Launch and inspect newly generated REDscript/CET logs. Confirm the unresolved
   type error is gone, compilation succeeds and Reborn identifies `1.0.0-rc2`.
   If compilation fails, provide the new first error before further gameplay tests.
5. Once the launch succeeds, test an actual save, successful reload and continued
   gameplay/quest progression separately. Export the local support report and
   record the actual game/framework versions and cases exercised.

See `docs/NeverLockSavesReborn/TESTING-RC2.md`, `TEST-MATRIX.csv` and the current
validation report. The matrix preserves prior individual statuses and records
the reported RC1-declaration failure as history. No case becomes passed from this
source correction alone. Record tests already completed; repeat only the affected
compile/launch and changed-path checks or cases a failure makes necessary.

## Existing feature scope

The first-release feature contract remains in
`docs/NeverLockSavesReborn/RELEASE-CONTRACT-1.0.0-rc1.md`: four modes with experimental
Smart/Unrestricted qualifications, introduction protection, an optional one-item
deferred checkpoint queue, optional autosave triggers, validated settings/manual
presets, read-only DF integration, contextual messages and bounded diagnostics.
Apartment entry covers only `LittleChina_VApartment`. Queued manual requests
dispatch checkpoints, not named manual saves. Guardian write/reload outcomes
remain Unknown without independent evidence.

The optional Windows/Python recovery companion remains manually run with the game
closed, with hash-verified copies, reversible retention/reactivation and confirmed
restore to a separate new destination. Follow `tools/NLSRSaveGuardian/README.md`.

Automatic playthrough binding, all-owned-safehouse triggers, automatic live
backups/correlated write-reload evidence and dependent in-game completion messages
remain explicitly deferred until after 1.0. RC2 adds none of those capabilities.

## Diagnostics, checks and rollback

**Export support report** writes local `support-report.json` in the Reborn CET
folder without automatic upload. Review it before sharing. Available dependency
declarations are self-reports; record versions the export cannot measure manually.

With Python 3.10+, the optional read-only installation checker is:

```sh
python tools/NLSRInstallAudit/audit_installation.py --game-root "C:/Games/Cyberpunk 2077"
```

Use your actual game root. Its refreshed RC2 inventory checks all 16 runtime
files; an identity match does not prove compilation or gameplay. Verify the ZIP
separately against its checksum sidecar. The older RC1 auditor is pinned to RC1.

Portable checks require Python 3.10+ and texlua/luatex:

```sh
python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output /path/to/results
```

The validation report records actual check results. These tests use Lua 5.3 and
controlled game/framework boundaries; a native REDscript compiler, CET LuaJIT/5.1,
Windows and the running game are unavailable here.

To back out, close the game and restore only a retained installation independently
verified in your environment, with its retained settings. RC1 contains the reported
declaration and is not a verified working fallback for this compiler failure.
Keep external save/recovery copies; RC2 adds no runtime file or settings schema
requiring migration. If a working fallback is unavailable, keep the game closed
and move the installed `r6/scripts/NeverLockSavesReborn/` and
`bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/` folders to a backup
outside the game directory. This retains their settings while removing Reborn's
runtime from the installation.

Based on user-provided Never Lock Saves v2.2.1.0 by RalphModding. Upstream permission
is pending and the user will arrange it. No whole-package MIT grant, public
repository, public release or author message is created by this candidate.
