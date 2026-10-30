# Never Lock Saves: Reborn 1.0.0

**Stable release.**

Reborn adds configurable saving, an event-driven deferred queue and optional Smart Autosave to Cyberpunk 2077. This release contains the latest user-tested notification and queue fixes, with the experimental/preview labels removed from menu controls.

## Included

- Four save modes: Vanilla, Immersion, Unrestricted and Smart. Native saving restrictions and introduction protection remain in place.
- One queued player save that waits for saving to become available, including release after combat or an active phone call. Remaining in a vehicle does not by itself block a queued player save.
- Optional Smart Autosave for exploration intervals, post-combat, vehicle exit, supported quest milestones and entry to V's original Little China apartment area.
- CET controls, optional Native Settings integration, persistent settings and manual named presets.
- Optional, read-only Dark Future integration for vehicle sleep, addiction, starvation and dehydration notifications.
- Neutral notifications without bracketed developer text. Saving game indicates work in progress; Game saved follows the existing matching successful game callback; failures receive plain-language feedback.
- Local diagnostics, an optional Guardian request ledger and on-demand support reports. No report is uploaded automatically.

## Install or update

Download **Never_Lock_Saves_Reborn_v1.0.0_RUNTIME_ONLY.zip** for installation. Close the game, install the bin/ and r6/ folders into the game root or use your mod manager, and keep one Reborn installation. Existing config.json and profile-settings.json are retained. Restart and confirm 1.0.0 in CET. Full install/update/rollback instructions are in INSTALL.md.

Cyber Engine Tweaks and redscript are required, with their separately installed dependencies. Native Settings and Dark Future are optional. No frameworks or game saves are bundled. The SOURCE_AND_TESTS ZIP is for developers, not the player installation.

## Verification and scope

The preceding game code was reported working by the user, including the notification update. Stable promotion changes version/menu/status labels only; save logic and config values are preserved. The current release suite and package verification are documented in VALIDATION.md. Offline tests do not establish a previously unrecorded game/framework compatibility matrix, and a game completion callback is not independent reload-integrity verification.

Game-save backup/recovery tooling, automatic character profiles and every-safehouse coverage remain outside this release. Previous releases remain available for rollback.

## Credits

Based on **Never Lock Saves v2.2.1.0 by RalphModding**. Reborn modifications and maintenance: **Veil Ashen Holloway**. Thanks to RalphModding for the original work and the recorded permission to publish the continuation under MIT. See LICENSE, ATTRIBUTION.md and PERMISSION.md.

Original mod: https://www.nexusmods.com/cyberpunk2077/mods/9662
