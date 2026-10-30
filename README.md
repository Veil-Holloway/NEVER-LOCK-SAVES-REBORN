# Never Lock Saves: Reborn 1.0.0

Reborn adds configurable saving, a deferred save queue and optional Smart Autosave to Cyberpunk 2077. Native game restrictions and introduction protection remain authoritative. This is the stable 1.0.0 release.

[Download the latest stable release](https://github.com/Veil-Holloway/NEVER-LOCK-SAVES-REBORN/releases/latest). Choose the RUNTIME_ONLY ZIP to install the mod.

## Features

- Four save modes: Vanilla, Immersion, Unrestricted and Smart. Unrestricted is a retained mode name; it does not bypass native locks.
- One queued player save, retained for the current session until it can run, is replaced/cancelled, or the session ends. Automatic and test requests retain their configured expiry.
- Optional Smart Autosave triggers for exploration intervals, post-combat, vehicle exit, supported quest milestones and entry to V's original Little China apartment area. This is not coverage of every safehouse.
- CET controls, optional Native Settings integration and explicit named settings presets.
- Read-only Dark Future integration with separate notification switches for vehicle sleep, addiction, starvation and dehydration.
- Neutral notifications: Saving game while pending, Game saved after a matching successful game callback, and a clear failure notice when the game reports failure. No selectable personalities or bracketed developer text.
- Local diagnostics, an optional Guardian request ledger, and on-demand support reports. No reports are uploaded automatically.

## Install

Cyber Engine Tweaks and redscript are required for the Lua and REDscript halves. Install their own dependencies separately. Native Settings and Dark Future are optional. No framework binaries or game saves are bundled. Exact compatibility with every game/framework version combination is not claimed.

Use the RUNTIME_ONLY ZIP. Close the game and copy its bin/ and r6/ folders into the game root, or install it through your mod manager. Replace matching files; keep one Reborn installation. Keep existing config.json and profile-settings.json. See INSTALL.md for update, rollback and removal.

## Status

The user reports the preceding notification-polish.1 build works and has authorized stable publication. This stable release preserves that game code, with version and menu-label changes only. The release-readiness changes fix tests and the separate installation auditor. Experimental and preview menu labels have been removed. Read VALIDATION.md for fresh offline results and the limits of that evidence. A successful game callback is not an independent reload-integrity check.

For problems, see SUPPORT.md. For tests and release preparation, see CONTRIBUTING.md and PUBLISH-CHECKLIST.md. Game-save backup/recovery and automatic character profiles are outside this release's scope.

## Credits and license

Based on Never Lock Saves v2.2.1.0 by RalphModding. Reborn modifications and maintenance: Veil Ashen Holloway. See ATTRIBUTION.md, PERMISSION.md and LICENSE for the recorded MIT permission and original-mod link.
