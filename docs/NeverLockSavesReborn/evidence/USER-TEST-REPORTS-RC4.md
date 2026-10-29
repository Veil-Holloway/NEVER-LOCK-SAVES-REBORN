# RC4 gameplay reports

## October 25, 2026 — vehicle combat (corrected)

**Status: USER_REPORTED_FAILURE — notification appears, save absent from load menu during vehicle combat.**

The tester corrected the earlier report that vehicle combat worked: the notification appears, but no save shows in the load menu while vehicle combat is active. The earlier limited USER_REPORTED_SUCCESS is withdrawn and superseded by this result. Installed package fingerprint, game/dependency versions, request route, Deferred Save setting and whether a save appears after combat were initially unspecified. The user subsequently confirmed it never appears, including after combat.

The reported acceptance outcome (an actual vehicle-combat save) is not met. Do not promote RC4 based on notification display. The full `UNRESTRICTED-IMMEDIATE` route/settings case is unverified, and `UNRESTRICTED-STALE` and `UNRESTRICTED-WRITE-RELOAD` remain UNTESTED. Source routing checks do not prove native acceptance, a file write or a usable reload.

Source diagnosis: all four REDscript calls to `gameAutoSaveSystem.RequestForcedCheckpoint()` discard its Bool return. The three immediate wrappers display their request notification afterwards without checking that result. The deferred dispatcher also returns true after the call without checking its return. Consequently notification display alone cannot distinguish a rejected native request from an accepted one; even a true native result does not establish save completion. Native implementation and runtime rejection reason remain unverified.

Next evidence needed: current RC version, request route and Deferred Save setting; a support report exported immediately after one failed attempt and fresh relevant logs. No engine-lock or quest-fact changes are justified by this report alone.

This additive report supersedes the earlier success entry. Existing RC4 ZIPs, checksum sidecars, frozen evidence and the packaged matrix remain unchanged. No runtime change, merge or release promotion is made by recording it.

