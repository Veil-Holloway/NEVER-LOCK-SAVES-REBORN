# 1.0.0-vehicle-diagnostic.1 — checkpoint-result diagnostics

October 25, 2026 (America/Los_Angeles). **Developer preview / diagnostic prerelease.**

Vehicle-combat saving remains a reported failure. The user corrected an earlier
working report: a notification appears, but a save never appears, including after
combat. This build fixes unchecked native request-result handling and supplies
the missing runtime evidence. It does not claim to fix actual save creation.

- Check the native `RequestForcedCheckpoint(): Bool` result on all three user
  routes and deferred dispatch. False no longer receives an accepted-request
  notification or a successful deferred submission result.
- Record one bounded last-attempt snapshot: serial, source, native result,
  native locks, combat and mounted state. Capture state at the attempt, rather
  than substituting the state at later report export.
- Export that snapshot as `checkpoint_attempt` in the existing local support
  report. Native acceptance, file creation and reload remain distinct.
- Preserve contextual message rotation for accepted requests and qualify those
  messages as request-only. Rejection/service/protection feedback respects the
  notification master and the three tones.
- Retain the immediate Unrestricted attempt, fresh introduction protection,
  native-gated queue/automatic lane, one-shot behavior and existing settings.

There is no new retry loop, native lock override, quest-fact repair or save-byte
edit. No alternative force-save API was established by the inspected interfaces.
Only three of sixteen runtime files change: REDscript, CET init and support
report. All five recovery-companion files remain byte-identical to RC4.

Use the complete diagnostic runtime package. Keep one active Reborn installation
and restart the game. To roll back, close the game and reinstall a complete
previous package, retaining external save copies and settings. RC3 remains the
published earlier candidate; RC4 and this preview do not establish save integrity.
