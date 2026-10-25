# Vehicle checkpoint write reproduction — diagnostic.3

October 25, 2026 (America/Los_Angeles). Status: **USER_REPORTED_FAILURE; no observed save-file write in the sampled interval**.

The user confirms Unrestricted mode throughout. Diagnostic.3 support evidence records a gameplay quicksave reaching the existing native checkpoint call and returning true while mounted and in combat. Attempt-time locks contain Combat only. Guardian requests ten registrations, marks none unavailable and observes four target callbacks. It records Requested → Delegated; no engine-completion hint is captured. This is not evidence that all ten targets work, nor a universal save-completion channel.

The requested reproduction compared the newest physical sav.dat timestamps/sizes before and after one vehicle-combat quicksave with a ten-second unpaused interval. The user supplied identical before/after listings: newest slot AutoSave-16, October 25 at 15:32:06, 2,336,896 bytes; all five displayed rows unchanged. No observed new or updated save appears in that comparison. The command does not compare file hashes or prove hidden native cancellation. Elapsed time and settings changes were user-executed, not independently instrumented.

Source review finds no Reborn native cancellation or InvalidateAutoSaveRequests call after submission. Queue cancellation and scheduler resets modify mod-owned state only. The report does not identify a native rejection stage, a Script-lock owner, or an installed autosave-disabling mod. No claim of an engine defect or impossible saving follows from these observations alone.

Next discriminating test (NOT RUN): load ordinary unlocked free-roam on foot, with Smart Autosave OFF and Unrestricted retained. First verify a normal quicksave writes. Then invoke the existing public helper once through CET: `print(Game.GetPlayer():NLSRebornRequestCheckpoint(2))`. Let gameplay run unpaused and compare physical files. Normal quicksave delegates to vanilla; the helper tests the same native checkpoint route used by the failing locked fallback. Record the returned Bool, file outcome and fresh support evidence. Avoid multiple requests for the same attempt.

Native true is not confirmed save creation. Vehicle-combat save creation, reload and quest progression remain unresolved. No new code patch/build, native-lock removal, accepted-request retry, quest-fact repair or save-data edit is justified by these snapshots. Published diagnostic.3 assets and tag remain unchanged. Raw uploaded user reports are retained locally and are not included in public source.
