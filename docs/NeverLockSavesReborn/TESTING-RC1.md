> Historical development snapshot. Current permission and acceptance status: [PUBLICATION-STATUS.md](PUBLICATION-STATUS.md).

# RC1 testing handoff

**Build: 1.0.0-rc1.** October 24, 2026 (America/Vancouver).

Your preRC4 working report is recorded. RC1 preserves that behavior and changes runtime identification only. Record what you already tested; repeating a successful test solely to complete paperwork is unnecessary. Results should identify which build they came from. The exact RC1 ZIP checksum is in its sidecar; the manifest identifies installed files.

## Supply a useful result

1. Confirm the installed `1.0.0-rc1` version and the package checksum. Record the actual game patch, framework versions, mod list and fresh REDscript/CET logs for this install.
2. Click **Export support report** in the CET overlay. Review the local `support-report.json` in Reborn's CET directory before sharing it. Record versions the report cannot measure manually; observed API declarations are not compatibility passes.
3. In `TEST-MATRIX.csv`, record pass/fail and evidence for cases actually exercised. Preserve untested or unknown results. Include save creation, reload and subsequent progression separately from request/queue/submission.
4. If a case fails, provide steps, expected/actual behavior, active mode/options, timestamp, reproducible save context and relevant sanitized logs/report. Preserve rollback/recovery copies.

The inherited 42-row matrix contains one broad preRC4 USER_REPORTED_WORKING report, 38 UNTESTED cases and three UNAVAILABLE capabilities now deferred after 1.0. An RC1 version label does not convert those rows to passes.

## Optional read-only installation audit

From the extracted RC1 package outside the game directory, run:

```sh
python tools/NLSRInstallAudit/audit_installation.py --game-root "C:/Games/Cyberpunk 2077"
```

Use your actual game root and Python 3.10+. The auditor checks all 16 pinned runtime files and bounded duplicate-script markers without repairs or deletion. Include its JSON and exit status with installation results. Exit 0 means its scans completed and pinned installed bytes matched; it does not pass compilation, compatibility, save/reload/progression or licensing. See `tools/NLSRInstallAudit/README.md` for options and limits. There is no `--archive` option; compare the ZIP digest with its separate `.sha256` sidecar. The earlier preRC2 checker remains specific to preRC2.

## Cases that establish release readiness

| Area | Record the actual observation |
|---|---|
| Install/update | One complete installation, current version, fresh compile/runtime logs and retained settings. Record clean install separately if exercised. |
| Modes/intro | All four modes and manual-save/pause quicksave/gameplay quicksave paths; completed, unfinished and unknown introduction cases; Smart combat-only/mounted/mixed/unknown lock behavior. |
| Queue | One item, manual priority, replacement/cancellation, expiry/cooldown, renewed locks, frame stalls, session loss/change and dry-run producing no save. Include automatic-only cancellation. |
| Autosave | Exploration/post-combat/vehicle-exit/verified milestone triggers and original-apartment known outside-to-inside entry; no first/enabling-inside/unknown-gap event or delayed dispatch after leaving. |
| Settings/UI/messages | Main/preset recovery and restart persistence, failure retention, future preset-schema refusal, CET/Native Settings sync, tones/body/neutral rotation, master OFF, status throttle/coalescing/TTL and presentation-failure isolation. |
| DF/compatibility | Actually tested absent/installed/partial configurations, individual and combined states and unknown transitions. DF switches only change messages; they must not alter survival mechanics. |
| Actual saves | An actual save entry followed by reload, inventory/position/objectives and continued progression, using disposable backed-up saves. Report each outcome explicitly. |
| Companion | Windows closed-game checks, copy/verification, reversible retention/reactivation, confirmed separate restore, then actual restored-game reload/progression. Hash success alone does not establish loadability. |
| Rollback | Close the game and reinstall complete retained preRC4 with its retained settings/preset bank; inspect version/logs/settings and actual save behavior. No new runtime file is introduced by RC1. |

Automatic identity, all-owned-safehouse coverage and automatic live backup/correlated completion are deferred capabilities, not RC1 cases to mark passed. In-game written/reload/backup/recovery completion notifications await those later interfaces.

The optional companion is documented in `tools/NLSRSaveGuardian/README.md`; use a separate new destination, explicit confirmation and disposable backed-up game data. No automatic quest edits or save-format rewrites are provided. Known offline checks and evidence limitations belong in `VALIDATION-REPORT.md`, separate from these game results.

Stable promotion follows recorded supported-environment evidence and distribution status. No exact game/framework support matrix or upstream permission clearance is invented from “works.”
