# Never Lock Saves: Reborn — RC4 actual-game testing checklist

October 25, 2026 (America/Los_Angeles). Target: **1.0.0-rc4**.

## Current evidence

All actual-game acceptance cases start **NOT RUN**. Earlier broad working reports
are not used as acceptance evidence. Historical supplied compiler logs remain
evidence of their recorded compilation output; the Smart routing regression was
independently reproduced offline.

The 60 integrated and 60 extracted-package offline groups remain separate source
and controlled-boundary evidence. They are not in-game passes. Current permission
and publication status is in the repository PERMISSION.md and PUBLICATION-STATUS.md.

## Target and recording rules

Install the RC3 runtime-only ZIP, not RC1/RC2. Its SHA256 is:
`f50fdb1aece38eed977de157c545a68fa45748cf6fcacf3e98b8f5bef1965e6e`
for the original private RC3 runtime archive. Public RC3 packaging adds MIT/credit
notes without changing any runtime file; use its new .sha256 sidecar instead.
The full RC3 ZIP is required for the optional Python recovery companion and
audit tools; runtime bytes are identical between the two ZIPs.

Use **PASS / FAIL / NOT RUN / NOT APPLICABLE**. A checked box means the complete
pass condition was observed. Use NOT APPLICABLE only for a capability outside
your declared release support scope; an unavailable scene/save/installed-mod
combination you still intend to support remains NOT RUN. Record an actual result
and evidence with every pass/failure; one “everything works” does not close rows.
Record results beside each case or use the failure template below. If you split
a case into variants, keep its case ID and record each variant separately.

For each save-path claim record separately: **requested → queued (if applicable)
→ checkpoint submitted → actual new save → successfully reloaded → progression**.
A popup, ledger or source hash does not prove the later steps. Leave the existing
vanilla autosave setting alone, and use request/source diagnostics to avoid
mistaking a coincidental native autosave for a Reborn trigger. If ambiguous,
repeat and mark the result inconclusive/NOT RUN until distinguished.

Run the phases in order. Stop at a compile/load failure. If a new save fails to
reload, progression breaks, requests duplicate or recovery copies are lost, stop
experimental tests, preserve evidence and use retained copies. Keep queues and
all optional automatic triggers OFF until the baseline is established.

For the first queue regression use Autosave OFF, Smart, Deferred Save ON, master
notifications ON, queue status OFF, queue expiry 120 seconds and queue cooldown
0. Close overlays/menus before observing release. Later use shorter expiry and a
nonzero cooldown for their own tests. Use the displayed countdown; manual queue
clock behavior is not asserted to pause in menus. Autosave timing counts safe
active gameplay and resets on pauses/menus/safety gaps. After enabling/changing
an autosave trigger, allow its full configured cooldown before creating its edge.

## Setup

- [ ] **S01 — Protect the test saves.** Close the game. Make an external copy of the save folders and Reborn settings/preset files. Use a disposable character/save for experimental modes.
  **Pass:** The original copies remain outside the test installation; later tests do not rely on a single save.

- [ ] **S02 — Record the environment.** Record game build, Windows version, RC3, installed CET/redscript/RED4ext/Codeware/Native Settings/DF versions or absent, and mod-list identity.
  **Pass:** Versions are actual observations; unknown versions remain Unknown. Record save/character, quest and test time.

- [ ] **S03 — Install and identify RC3.** Enable only the intended Reborn installation, Deploy in Vortex, launch and open the Reborn CET panel.
  **Pass:** Version reads 1.0.0-rc3; fresh REDscript/CET logs have no Reborn compilation/load error; bridge connects.

- [ ] **S04 — Isolate the first test.** Set Smart Autosave OFF, Deferred Save OFF and enable master save-request notifications. Keep the ordinary game autosave setting unchanged.
  **Pass:** The Reborn scheduler and deferred queue are idle. A native autosave is never counted as a mod submission solely because it appeared.

## Ordinary save baseline

- [ ] **B01 — Save through every ordinary route.** In an unlocked post-introduction area use gameplay quicksave, pause-menu quicksave and the manual-save item, separately.
  **Pass:** Each accessible route behaves normally; record disabled/unreachable controls as NOT RUN rather than pretending to click them.

- [ ] **B02 — Prove save creation and reload.** For each tested route inspect the actual save entry/time, reload that newly created save and check restored location/state.
  **Pass:** A new intended save exists and reloads; a request popup or Guardian submission alone is insufficient.

- [ ] **B03 — Prove progression.** After reloading, continue the current quest/objective, travel and interact normally.
  **Pass:** Progression and interaction still work. Keep one confirmed baseline before experimental-mode tests.

## RC3 Smart interaction regression

- [ ] **Q01 — Gameplay quicksave during an interaction.** After the intro select Smart, Deferred Save ON, master notifications ON, Queue status notifications OFF and Autosave OFF. Use an interaction with a native save lock; quicksave once.
  **Pass:** One pending quicksave request and a custom queued notice appear. No immediate forced checkpoint is submitted while that lock remains.

- [ ] **Q02 — Release the queued interaction request.** End the interaction before the displayed expiry and let normal saving remain available for the existing two-second sampled stability window and configured cooldown.
  **Pass:** Exactly one attributable checkpoint request is submitted after timely unlock/stability/cooldown; pending clears and no additional request follows. Zero submissions or expiry is a failure for this release test. Verify a new save, reload and continued progression separately.

- [ ] **Q03 — Pause-menu quicksave route.** Repeat the same blocked-state test through pause-menu quicksave, then resume before judging dispatch.
  **Pass:** The accessible route queues once and meets the Q02 exact-one successful release and write/reload/progression checks. Existing busy/saved/failed-notification guards may suppress repeated input.

- [ ] **Q04 — Manual-save route.** Repeat through the manual-save item where the UI lets the request reach it.
  **Pass:** One queued request meets the Q02 exact-one release and write/reload/progression checks, as a checkpoint rather than a named manual save. An unclickable native menu item is a coverage gap, not a queue pass.

- [ ] **Q05 — Queue-status presentation ON.** Repeat one successful blocked quicksave with Queue status notifications ON; leave time between tests.
  **Pass:** Status feedback appears without duplicate legacy queued text. Permission and one-shot dispatch match the OFF case.

- [ ] **Q06 — Deferred Save OFF refusal.** Keep Smart and notifications ON, turn Deferred Save OFF and attempt a noncombat interaction-locked quicksave.
  **Pass:** Custom blocked text appears; no new queued or forced checkpoint request is created. Existing pure-combat opt-in exceptions are a different test.

- [ ] **Q07 — Master notifications OFF.** Repeat blocked queue ON and queue OFF scenarios with master notifications OFF.
  **Pass:** Reborn custom messages are silent; queue admission/permission remains the same as the corresponding notification-ON scenario. Native game messages are separate.

## Queue lifecycle

- [ ] **L01 — Replace, do not accumulate.** With a real request pending, press quicksave several times, then try a supported manual request.
  **Pass:** The queue stays one item; newer eligible requests replace/reset it. Unlocking does not produce a save for every press.

- [ ] **L02 — Cancel and disable.** Queue a blocked request and cancel it. Repeat with Deferred Save disabled before release; keep Autosave OFF.
  **Pass:** Pending clears in each case and the cancelled/disabled request never dispatches later.

- [ ] **L03 — Expire while still locked.** Choose a short queue expiry and keep the native lock active beyond the displayed countdown, then unlock.
  **Pass:** Expiry is reported, pending clears and that expired request never dispatches. Do timed tests in active gameplay and use the displayed timer; do not assume menu/wall-clock semantics.

- [ ] **L04 — Relock and cooldown.** Queue, begin to unlock, then renew a lock before stabilization completes. Separately set a nonzero queue cooldown and make a second request soon after a submission.
  **Pass:** Relocking resets stabilization. Cooldown prevents an early second submission; it must also beat request expiry. Restore the normal test settings afterwards.

- [ ] **L05 — Dry run never saves.** Use Queue test request once with no real request; then try the dry-run button while a real request is pending.
  **Pass:** The preview produces no checkpoint and cannot replace real pending work. Other native autosaves are not counted as preview saves.

- [ ] **L06 — Load/session transition.** With pending work, reload a save or change to another disposable character/session, then resume play.
  **Pass:** No stale request executes in the new session. Bridge reconnects and only a fresh request can queue.

## Modes and introduction protection

- [ ] **M01 — Vanilla.** With Reborn Autosave OFF test unlocked and locked requests in Vanilla, even if Deferred Save is enabled.
  **Pass:** Native behavior is retained; Vanilla need not use Reborn deferred routing.

- [ ] **M02 — Immersion without active DF context.** Test unlocked and locked requests in Immersion without one of the four positively observed DF contexts.
  **Pass:** Normal/native routing is retained; ordinary Immersion locks need not queue.

- [ ] **M03 — Unrestricted experimental.** On a disposable post-intro save test one locked request with Deferred Save ON and one with it OFF.
  **Pass:** ON and OFF both attempt the existing checkpoint fallback immediately; no new user queue should be created. Submission is not proof the engine wrote a usable save; verify write/reload/progression.

- [ ] **M04 — Smart combat and mounted controls.** On a disposable save, test combat with combat exception OFF/ON and Deferred Save OFF. Repeat mounted combat with vehicle exception OFF/ON. Inspect native lock reasons.
  **Pass:** Immediate Smart fallback is eligible only when all measured native reasons are Combat, combat is current and combat opt-in is ON; mounted combat also needs vehicle opt-in. Extra/unknown reasons must not force. Record unavailable lock combinations NOT RUN.

- [ ] **M05 — Introduction remains protected.** Use an actual pre-introduction-completion save and try the supported locked routes with experimental settings.
  **Pass:** No Reborn forced/deferred checkpoint bypass. Unknown or incomplete completion evidence cannot release protection. Do not edit quest facts to manufacture this test.

- [ ] **M06 — Completed introduction releases protection.** Use an actual post-intro save; inspect readable q000_done and repeat ordinary/Smart queue tests.
  **Pass:** Positive q000_done clears the intro gate. q001_started is diagnostic only. Calls after the intro must not revive stale introduction/Jackie-only wording.

## Optional Smart Autosave: one trigger at a time

- [ ] **A01 — Exploration interval.** Set interval to 60 seconds and cooldown to 30 seconds; enable only exploration and the Autosave master. Close menus/CET overlay and wait through warmup/cooldown plus stable active play.
  **Pass:** One exploration queue/submission is attributed in diagnostics; no immediate configuration-change catch-up or rapid repeated requests. Check actual write/reload separately.

- [ ] **A02 — Post-combat and vehicle exit.** Test post-combat alone after the full cooldown; then test vehicle exit alone after a fresh cooldown.
  **Pass:** A new same-session transition can produce one automatic request when normal readiness returns; standing idle without a fresh edge does not replay it.

- [ ] **A03 — Fresh journal milestone.** Enable only Verified quest milestone, wait for cooldown and complete a fresh objective/quest while observing journal diagnostics.
  **Pass:** A supported newly observed completion can trigger; enabling or loading with old completed quests does not scan/replay them. No observed callback means NOT RUN/inconclusive, not a pass.

- [ ] **A04 — Original apartment entry.** Enable only original-apartment entry while already inside, then wait for cooldown and cross from a known outside area into V's original apartment district.
  **Pass:** Enabling/first sampling inside is inert; a fresh known outside-to-inside edge can trigger once. This is LittleChina_VApartment district coverage, not every safehouse.

- [ ] **A05 — Apartment cancellation.** Arrange an entry request still waiting for readiness, then leave the apartment district before handoff/dispatch.
  **Pass:** The entry-related work is cancelled rather than submitting later from elsewhere; if no waiting state was observed, record NOT RUN.

- [ ] **A06 — Safety and manual priority.** During automatic scheduling open menus/pause, enter combat or a vehicle, start a call, or queue a player request; test transitions individually.
  **Pass:** Automatic work resets/yields as required. No burst when resuming, no automatic replacement of a player request, and no immediate automatic echo after its submission.

- [ ] **A07 — Autosave OFF.** Turn the Autosave master OFF, then separately turn each trigger OFF and try its corresponding event with other triggers disabled.
  **Pass:** Reborn creates no request from the disabled lane/trigger. Native game autosaves may still occur; use diagnostics to tell them apart.

## Settings and explicit presets

- [ ] **P01 — CET and Native Settings synchronization.** If Native Settings is installed, change mode/tone/queue/numeric options in each UI and inspect the other.
  **Pass:** Values match without loops, repeated writes or unexpected enablement. Without Native Settings, CET remains usable; absent-module coverage does not prove installed-module compatibility.

- [ ] **P02 — Restart persistence.** Set distinctive valid values, close the game normally, restart and inspect settings.
  **Pass:** Mode, tone, queue controls, autosave options and notification switches persist correctly; transient queued work does not.

- [ ] **P03 — Save and apply two presets.** Create two named presets with clearly different options; change current options, then explicitly apply each.
  **Pass:** The intended saved values are applied and both UIs synchronize. Applying a preset clears old pending work rather than dispatching it under new settings.

- [ ] **P04 — Preset list and restart.** Refresh the preset list, restart and load each previously saved preset using Load named preset or its list button.
  **Pass:** Saved names and values survive restart; the correct preset loads explicitly. Do not expect rename/delete controls or automatic character binding that the UI does not expose.

- [ ] **P05 — Configuration recovery: isolated copy only.** If doing the advanced recovery drill, back up all settings first and use a disposable mod/settings copy with a known-valid .bak; make only its primary JSON invalid, then load.
  **Pass:** A valid backup recovers without being overwritten by bad primary data. Restore the original files after the drill. Never corrupt the only live settings or save data; deeper failure injection stays developer-only.

## Notifications

- [ ] **N01 — Three tones and context.** Exercise Professional, Sarcastic and Unhinged using genuine request contexts such as combat, vehicle, phone and exploration; inspect context diagnostics.
  **Pass:** Selected tone/context is used. No stale intro text after completion; Jackie-specific call wording requires the verified introductory subtype. Ordinary unlocked native saves need not generate custom fallback messages.

- [ ] **N02 — Status lifecycle.** With status messages ON, cause queue, submission, cancellation and expiry events; observe automatic-queued events during the autosave tests.
  **Pass:** Feedback matches the request state, has no duplicate terminal message and never calls a submission a confirmed written/reloaded save. Do not manufacture errors in the live install.

- [ ] **N03 — Rate and rotation.** Leave at least two seconds between intentional requests; sample repeated events in the same tone/context, then briefly press rapidly.
  **Pass:** No uncontrolled notification flood or obvious stuck selection. The bounded status channel may coalesce/expire messages; not every press must display a separate notice.

- [ ] **N04 — Body/neutral coverage when available.** Repeat representative context/tone cases on available body profiles; record unknown/neutral diagnostics if naturally observed.
  **Pass:** Pool selection matches observed profile, and unknown uses neutral. Missing profile/context combinations remain untested; manually reading every message is unnecessary.

## Optional Dark Future compatibility

- [ ] **D01 — Without DF.** Only if you can test a separate profile without DF, launch Reborn and inspect DF diagnostics.
  **Pass:** No required-DF compile/load failure; unavailable readers remain Unknown and ordinary saving still works. Never remove dependencies from the only working mod profile for this test.

- [ ] **D02 — Four DF states separately.** With DF installed, in Immersion observe vehicle sleep, addiction, starvation and dehydration one at a time using disposable saves.
  **Pass:** Each positively observed state maps to its intended context and existing request path; unknown data never invents a state. Record actual DF/framework versions.

- [ ] **D03 — Each DF message switch.** In each of the four observed states turn its Reborn message switch OFF and ON, keeping all other conditions fixed.
  **Pass:** Only the corresponding contextual message changes; save eligibility and DF settings do not change because of the message switch.

- [ ] **D04 — Combined states and clearing.** Naturally combine supported DF states, then clear them and retest.
  **Pass:** Priority/fallback selection is consistent with current diagnostics; cleared conditions do not leave stale DF messages. Record exact combinations exercised.

- [ ] **D05 — DF survival noninterference.** Compare survival counters/settings and normal DF interactions before/after Reborn requests and message toggles.
  **Pass:** Reborn does not write DF state/settings or disrupt the survival mechanics.

- [ ] **D06 — Write/reload with DF.** For each exercised DF request path observe submission, actual new save, reload and continued gameplay separately.
  **Pass:** Every claimed supported DF case has real write/reload/progression evidence. Merely compiling with DF or absent DF is not that evidence.

## Guardian and support reports

- [ ] **R01 — Request ledger truthfulness.** Enable Guardian and make a request, queue, wait and submit/cancel/expire it. Export its report.
  **Pass:** The ledger tracks those observed request states. Written and reloaded stay Unknown unless independently established elsewhere; uncorrelated engine hints do not become confirmations.

- [ ] **R02 — Fresh support export.** Export while exploring and after combat/vehicle/phone/DF transitions, and inspect settings, queue/source/serial, native locks, version evidence and observer fields.
  **Pass:** Values reflect current observations; unavailable versions/sensors remain Unknown. Registration requested and callback seen remain distinct. Keep before/after reports separately.

- [ ] **R03 — Report privacy and disabled behavior.** Review a copy before sharing; disable Guardian/optional reporting where available and play normally.
  **Pass:** No automatic upload or private path/raw exception dump; unavailable diagnostics do not stop the queue/save path. Do not mark unavailable APIs as installed or compatible.

## Optional Windows recovery companion: separate test folders

- [ ] **H01 — Game-running refusal.** Using the full RC3 package and Python 3.10+, point the helper at a disposable copied save slot and a separate test backup root while the standard game process is running.
  **Pass:** Backup refuses and publishes no snapshot. After H02 supplies a valid snapshot, repeat a restore attempt with the game running and a valid new external destination; expect process-guard refusal and no restored copy. Keep the game closed for all other helper operations; there is no bypass to use.

- [ ] **H02 — Backup and verify.** With the game closed, snapshot one complete disposable save-slot folder to the separate test backup root; list, verify, preview and inspect/recovery-plan it.
  **Pass:** A complete hash-verified snapshot and manifest appear; source bytes are unchanged. These results do not themselves prove game loadability.

- [ ] **H03 — Reversible retention.** Keep one source folder path and explicit test labels; make three snapshots with a profiled keep-count of two. Preview active/retired copies.
  **Pass:** Two newest protected copies remain active in that stream; older valid copy moves to owned retired storage without permanent deletion. Original data remains verifiable.

- [ ] **H04 — Confirmed reactivation.** Preview a retired copy and reactivate using its exact confirmation identifier.
  **Pass:** It returns to active storage with the same manifest/data; nothing is installed into the live save directory.

- [ ] **H05 — Separate restore and refusal.** Preview and confirm restore to a new external destination whose parent exists. Separately try an already-existing disposable destination or wrong confirmation.
  **Pass:** New restored copy verifies; existing destinations/wrong confirmations refuse without overwriting anything. Never point the destination at the only live slot.

- [ ] **H06 — Actual restored-game acceptance.** Keep original external copies. If comfortable, manually import only into a disposable game-save environment, then launch and reload the restored copy.
  **Pass:** The actual restored save loads and progresses. If you do not perform the manual-import/game step, mark it NOT RUN; hash verification is not a substitute.

## Release acceptance

- [ ] **X01 — Update and removal/rollback.** In an isolated game/mod-manager profile test a complete RC3 update with retained settings, then disable/remove Reborn and deploy. Reinstall RC3 afterwards if needed.
  **Pass:** Settings remain intact and the game launches normally. Roll back only to an independently working retained install; RC1/RC2 are not certified fallbacks for their known source defects.

- [ ] **X02 — Normal mod list and play session.** Repeat the core Smart queue and actual save/reload checks with the intended full mod list; include travel, menus, reloads and a normal 30–60 minute session.
  **Pass:** No crashes, accumulating errors, duplicate dispatch, stuck queue or material performance regression; record duration and exact profile. A finite soak is not proof of all playthrough safety.

- [ ] **X03 — Release record.** Review results and list every FAIL/NOT RUN and supported game/framework/mod configuration. Keep logs/report timestamps for failures.
  **Pass:** No compilation, save-integrity, duplicate-dispatch, restore-data-loss or progression blocker remains in the claimed supported scope. Untested optional/deferred capabilities are not advertised as verified; public permission is tracked separately.
## Advanced developer-only failure tests

Do these only in isolated disposable fixtures, never by damaging the live save,
only valid backup or main mod installation. Keep them NOT RUN for the real
Windows/game boundary until actually exercised:

- Invalid recognized main-settings/preset primary recovers a valid backup;
  failed replacement preserves the sole good backup and effective runtime state.
- Future preset schema refuses downgrade/overwrite; invalid labels, malformed or
  partial legacy data remain bounded and do not erase good settings.
- Disk-full/access-denied/write/close/rename failures are reported accurately;
  temp-file failures do not publish partial settings/snapshots/restores.
- Missing optional services, bridge/player gaps, unknown sensors and malformed
  observer evidence fail closed without inventing permission or completion.
- Notification emitter errors, long-frame stalls, observer overflow/reentrancy
  and duplicate journal callbacks do not alter save eligibility or multiply work.
- Invalid/tampered duplicate recovery snapshots, busy/stale locks and interrupted
  rotation are refused/reported without automatic live repair or permanent loss.

Existing portable fault-injection tests cover controlled doubles/temporary files;
they are not evidence that these Windows/game failures were produced in practice.
Do not manufacture unknown quest facts or write quest facts to obtain coverage.

## Explicitly outside RC3 acceptance

Automatic persistent character/playthrough binding, every owned/rental/modded/PL
safehouse, automatic live backups, correlated save-written/reloaded events and
dependent completion messages remain deferred until after 1.0. They are neither
expected RC3 successes nor new regressions. Explicit presets, the original
apartment district trigger and the closed-game helper are the shipped alternatives.

Publication permission is separate from functional acceptance. RalphModding has granted publication and MIT licensing permission. Functional
acceptance remains separate; this checklist starts every game case NOT RUN.

## Failure report to paste back

```text
Case ID / variant:
RC3 version shown:
Game + framework versions:
Mod profile / relevant optional mods:
Test save, quest and current interaction:
Mode / Deferred Save / Autosave / notification switches:
Exact steps:
Expected:
Actual:
Request / queue / submitted / new-save / reload / progression outcomes:
Time and fresh log/report filenames:
Reproduces: always / sometimes / once
```

Start with S01–S04 and B01–B03, then Q01–Q07. Report that batch before trying to
complete the optional framework and recovery cases. A failed early stage should
be resolved before accumulating ambiguous downstream results.
