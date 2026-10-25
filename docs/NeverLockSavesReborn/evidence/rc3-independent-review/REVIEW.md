# RC3 Smart queue independent source review

No blocking source defect found in the proposed fix. Specification and engineering verdicts are **partial**: the actual-source boundary checks below pass, while REDscript compilation, interaction-time UI display, actual save writing/reload and progression remain unverified.

The shared defect is addressed directly. In all three request hooks, Smart queue admission now precedes immediate forced-checkpoint authorization. Scene, Quest, Script, mixed and unknown native locks can remain queued without receiving forced-checkpoint permission. Only Smart mode receives the added admission route; Vanilla and ordinary Immersion retain their existing delegation. Unrestricted and known Dark Future fallback routes remain unchanged.

Only two runtime source files differ from RC2: the Lua initializer has version labels only; the REDscript changes version labels, one added helper and three guarded call sites. Exact body comparison confirms no changes in queue admission internals, native-unlocked release, introduction completion, request dispatch, or existing Smart combat fallback. The serial check, clear-before-dispatch, explicit deferred enablement, one-item replacement and manual-over-autosave behavior remain intact.

The new helper respects the master custom-notification setting. Queued fallback notices are suppressed when the status emitter owns them; blocked messages remain truthful when Deferred Save is disabled. Pause-menu quicksave retains quicksave-in-progress, failed-notification and saved-notification guards; gameplay quicksave retains its existing in-progress guard. An interaction request never directly forces a checkpoint through the new helper. Existing deliberate combat exceptions remain available with Deferred Save disabled.

Fresh commands (all exited 0):

- `python3 .../test_smart_source.py work/rc3/release`: 2,115 policy cases, zero failures.
- `python3 .../test_autosave_source.py work/rc3/release`: 27,673 bridge assertions, zero failures.
- `python3 .../test_notifications.py --release work/rc3/release`: 17,499 notification-source assertions, zero failures; existing library inventories retained.
- Independent stdin evaluation of actual helper, all three hooks, actual queue and introduction methods: 72 cases covering queue enabled/disabled, global notifications, status notifications and all three tones; zero failures. Service boundaries doubled.

Evidence is in `smart-policy.json`, `autosave-bridge.json`, `notifications.log`, `PRESERVATION.json` and `SMART-ROUTE-CHECKS.json`. These bounded evaluators are not REDscript compilers and cannot establish live UI display or save completion. No production source or test was modified by this review.
