# Never Lock Saves: Reborn — 1.0.0-rc1

**Release candidate for testing.** RC1 freezes the user-reported working preRC4 feature set. Runtime changes from preRC4 are identification labels only; configuration and save-policy behavior are preserved. This candidate is not a stable/public release clearance.

## What ships

- Four save modes: Vanilla, Immersion, and experimental Unrestricted and Smart. Smart permits only explicit Combat locks with combat opt-in; mounted combat also requires vehicle opt-in. Unknown or mixed lock reasons retain protection.
- Introduction protection and an optional one-item deferred checkpoint queue with cancellation, expiry, cooldown and native-permission/stability rechecks. A queued manual request becomes a checkpoint request, not a named manual save.
- Optional Smart Autosave: exploration interval, post-combat, vehicle exit, verified quest/objective milestones and original V apartment district entry. Master autosave, milestone and apartment options default OFF. Only `LittleChina_VApartment` is supported for apartment entry.
- Validated settings and backup recovery, explicit named presets, CET/optional Native Settings synchronization, contextual core/DF messages and optional queue-status messages.
- Optional Guardian request/queue/submission history and bounded diagnostics. Written/reloaded outcomes remain Unknown unless established independently.
- A separate, optional Windows/Python backup/recovery companion, manually run with the game closed. It creates hash-verified copies, supports reversible retention/reactivation and restores only to a separate new destination after confirmation.

Automatic playthrough profiles, all-owned-safehouse triggers, automatic live backups and correlated written/reloaded or in-game backup/recovery completion notifications are scheduled after 1.0. See `docs/NeverLockSavesReborn/RELEASE-CONTRACT-1.0.0-rc1.md` for the approved boundary.

## Install or update

1. Close Cyberpunk 2077. Retain complete preRC4, external game-save copies, and copies of `config.json`, `profile-settings.json` and their `.bak` files from your Reborn CET mod folder.
2. Extract this package's `bin/` and `r6/` into the game root as one complete Reborn installation. Keep a single copy of Reborn's scripts; remove duplicate older Reborn copies while preserving your settings. `docs/` contains documentation/tests and `tools/` contains the optional companion.
3. Keep the game/framework setup that you have tested. Framework binaries are not bundled; exact supported game/CET/REDscript/RED4ext/Codeware/Native Settings/Dark Future versions remain to be recorded from actual testing. Native Settings and Dark Future integrations are optional.
4. Launch, inspect fresh REDscript/CET logs, and confirm `1.0.0-rc1` in Reborn's overlay/logs. Record the installed package checksum with your results.
5. Use **Export support report** in the CET overlay and record the actual cases exercised in `docs/NeverLockSavesReborn/TEST-MATRIX.csv`. See `TESTING-RC1.md` for the focused handoff.

Support export writes local `support-report.json` in `bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/`; it performs no automatic upload. Review the JSON before sharing. Available CET/Codeware/Native Settings declarations are self-reported versions, not compatibility passes. REDscript/RED4ext/DF versions remain unknown and should be recorded manually. Native Settings' numeric declaration may not reproduce the exact download-package version.

For the optional companion, follow `tools/NLSRSaveGuardian/README.md`. It requires Windows and Python 3.10+, has no third-party Python packages, and does not start automatically. Configuration backups are separate from game-save backups.

## Test status and rollback

The user reported preRC4 working. That feedback is accepted without inventing a fingerprint, dependency versions or individual case passes. The 42-row game matrix retains one broad working report, 38 UNTESTED rows and three UNAVAILABLE capabilities explicitly deferred after 1.0. RC1's fresh offline verification and package evidence are in `docs/NeverLockSavesReborn/VALIDATION-REPORT.md`.

Queue acceptance, checkpoint submission, matching copy hashes, save creation, successful reload and continued quest progression are separate outcomes. The mod does not modify quest facts or parse/rewrite game-save bytes. Native permission is not an independent quest-safety guarantee.

To roll back RC1, close the game and reinstall the complete retained preRC4 package with its retained config/preset bank. RC1 introduces no runtime file, setting or schema change, so no RC1-only runtime file needs removal. Preserve external saves and companion recovery copies separately. The old preRC2-only installation checker remains pinned to preRC2; use the current RC1 auditor below.

## Optional installation check

Run the bundled read-only auditor from the extracted RC1 package, outside the game directory, with Python 3.10+:

```sh
python tools/NLSRInstallAudit/audit_installation.py --game-root "C:/Games/Cyberpunk 2077"
```

Replace the example with your actual game root. It checks all 16 pinned runtime files and bounded duplicate-script markers; it never repairs or deletes files. Read `tools/NLSRInstallAudit/README.md` for results and options. It has no `--archive` option: verify the ZIP separately against its `.sha256` sidecar. Matching bytes establish installation identity, not compilation, compatibility, gameplay or distribution clearance.

## Offline checks and attribution

With Python 3.10+ and texlua/luatex available:

```sh
python docs/NeverLockSavesReborn/validation/run_checks.py --release . --output /path/to/results
```

These checks use Lua 5.3 and controlled game/framework boundaries; they are not CET LuaJIT/5.1, a REDscript compiler, Windows or live-game acceptance. Current release documents supersede historical preview plans where scope or version differs.

Based on user-provided Never Lock Saves v2.2.1.0. See `ATTRIBUTION.md`. No verified upstream license/redistribution permission record is present, and no MIT license for the whole derived package is asserted. Resolve distribution terms before public publication.
