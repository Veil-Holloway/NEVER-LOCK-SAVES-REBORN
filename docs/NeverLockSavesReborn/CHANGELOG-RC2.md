# 1.0.0-rc2 — autosave-system type correction

October 24, 2026 (America/Los_Angeles). **Release candidate for testing.**

The uploaded REDscript log reports an unresolved `AutoSaveSystem` type in Reborn's
deferred checkpoint-dispatch method. RC1 contains that declaration, so its prior
broad working report does not establish compilation success for the reported
installation.

- Replaced that variable's `ref<AutoSaveSystem>` annotation with the verified
  `ref<gameAutoSaveSystem>` type returned by `GameInstance.GetAutoSaveSystem`.
- Updated eight runtime identification labels to `1.0.0-rc2`.
- Refreshed the installation auditor's 16-file pins and focused regression/source
  preservation coverage. The validation report records the actual results.
- Updated the test handoff and roadmap; retained the reported compiler failure
  as history without converting untested gameplay cases to passes.

The queue guards, checkpoint call, settings, DF readers/messages, autosave policy
and recovery companion are retained. Fourteen other runtime files and all five
existing recovery-companion files are byte-identical to RC1. No runtime file,
setting, schema, dependency or first-release scope change is introduced.

The source fix addresses the logged declaration. Post-fix native compilation,
launch, actual save/reload/progression and Windows recovery remain acceptance
checks. Retest with fresh logs before gameplay testing. Permission is still
pending; stable/public promotion and the unfinished GitHub handoff remain paused.
