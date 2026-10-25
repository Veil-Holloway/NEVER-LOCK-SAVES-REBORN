# RC4 gameplay reports

## October 25, 2026 — vehicle combat

**Status: USER_REPORTED_SUCCESS (limited scope).**

The tester reports that vehicle combat works now, following delivery of the RC4 Unrestricted queue fix. This records success for the previously reported symptom on their current installation. The installed package fingerprint, game/dependency versions, request route and Deferred Save setting were not supplied with this result.

This report does not establish the complete `UNRESTRICTED-IMMEDIATE` matrix case (all three user request routes with Deferred Save ON and OFF). `UNRESTRICTED-STALE` and `UNRESTRICTED-WRITE-RELOAD` remain UNTESTED. Actual save creation, successful reload and continued quest/interaction progression were not separately confirmed in this report.

Next gameplay check: load the new vehicle-combat save and confirm normal vehicle/player state, inventory, objectives and continued quest or interaction progression. Preserve the prior save for comparison.

This is an additive report after packaging. Existing RC4 ZIPs, checksum sidecars, frozen test evidence and the packaged matrix remain unchanged. No runtime change, merge or release promotion is made by recording it.
