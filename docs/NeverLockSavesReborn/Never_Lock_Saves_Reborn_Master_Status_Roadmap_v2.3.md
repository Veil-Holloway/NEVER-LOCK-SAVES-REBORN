# Never Lock Saves: Reborn — current status addendum v2.3

October 25, 2026 (America/Los_Angeles). Current preview: **1.0.0-vehicle-diagnostic.2**.

This addendum supersedes older documents only for current release/evidence status.
The approved first-release scope and post-1.0 deferrals remain unchanged.

- RC3 is public under MIT with RalphModding's explicit permission and attribution.
  The earlier pending-permission language in v2.1 is historical; see `PERMISSION.md`.
- Earlier broad game-test claims were withdrawn by the user. No unobserved game
  tests are promoted to passed. RC4 vehicle-combat saving is a user-reported
  failure: notification appears, no save ever shows, including after combat.
- diagnostic.1 checks the native return value and captures attempt-time state,
  but the supplied launch log reports a compilation failure from negative field
  defaults. Its 68 offline groups did not constitute compiler evidence.
- diagnostic.2 removes the two rejected field defaults and returns unknown from
  combat/mounted readers before any attempt. The source correction is implemented;
  offline evidence is recorded separately in `VALIDATION-VEHICLE-DIAGNOSTIC.2.md`.
- Native compilation of diagnostic.2, actual vehicle-combat save creation, reload,
  progression and the installed game/framework matrix remain unverified.

Next: install one diagnostic.2 copy, Deploy and launch. Resolve any first compiler
error before gameplay testing. If compilation succeeds, make one vehicle-combat
attempt and immediately export its support report. No alternate force-save API,
native-lock removal, retry loop or quest/save-data workaround is approved here.

Automatic character/playthrough binding, all-owned-safehouse triggers, automatic
live backups and write/reload correlation remain deferred after 1.0.
