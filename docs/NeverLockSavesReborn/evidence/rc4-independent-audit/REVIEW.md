# RC4 Unrestricted routing — independent audit review

No blocking source finding. The specification and engineering verdicts remain
**partial** until native compilation, vehicle-combat save creation, reload and
progression are exercised in the game.

The queue admission change addresses the shared cause at the existing seam:
valid post-introduction Unrestricted user requests decline deferred admission
and consume prior pending work, so the unchanged caller reaches its existing
immediate checkpoint request. A fresh manual request also supersedes automatic
pending work. Invalid request sources, incomplete/unknown introduction and
cached safety protection cannot use the new mode branch.

The mode setter clears pending manual source1/source2 work when a valid mode2 is
applied; it preserves source3 automatic work. Invalid mode inputs leave the mode
and pending state untouched. This prevents old player requests from dispatching
after switching to Unrestricted without disabling the independently enabled,
native-gated automatic lane.

Independent constrained execution of the actual two changed method bodies passes
6,864 assertions across mode, deferred switch, request source, fresh intro
completion, protection, old pending state and old source combinations. Tests use
an external quest-service double. They are source-boundary evidence, not a
REDscript compiler, native service or game test.

Source comparison confirms 15 retained methods match RC3: introduction reader;
deferred dispatch and native release; automatic readiness/admission/enablement;
deferred enablement; Smart blocked request/combat/fallback policy; all three user
save wrappers; context selection and contextual notification text. Thus existing
quicksave busy guards and all native/automatic dispatch guards are retained.

The refreshed installation auditor retains all original89 test names and passes
89 tests with no skips. Three independent real-filesystem CLI probes return0 for
cleanRC4 and1 for each isolated staleRC3 mainREDS/init. Every probe preserves the
complete input file set, bytes and modification times; private path/log poison
strings do not leak and log compilation state remains Unknown. Output changes
are metadata/pins/descriptive text and additive rc4_label counting only, retaining
rc1_label, rc2_label and rc3_label. No scan/repair/network/process behavior changes.

The six auditor integration files are under `../tools/NLSRInstallAudit` relative
to this evidence's parent output directory. UNITTEST.json/log, PROBES.json,
SOURCE-REVIEW.json and CHANGES.json/diff retain the commands, outcomes and hashes.
No production release/runtime or remote repository was modified by this review.
