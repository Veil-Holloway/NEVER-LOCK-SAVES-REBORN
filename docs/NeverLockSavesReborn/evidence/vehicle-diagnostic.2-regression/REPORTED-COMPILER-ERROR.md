# Reported compiler failure

User-supplied REDscript log, October 25, 2026 at 14:52:33 America/Los_Angeles.
Diagnostic.1 source: `NeverLockSavesReborn.reds:93:67`.

```text
[INVALID_CONSTANT]
@addField(PlayerPuppet) private let nlsCheckpointCombat: Int32 = -1;
this value must be a constant (e.g. 1, "string")
```

The neighboring mounted-state field has the same negative initializer.
This records a reported native compilation failure, not a full environment fingerprint.
Exact game and compiler/framework versions were not supplied in the log.
