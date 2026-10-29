# 1.0.0-vehicle-diagnostic.2 — diagnostic field initialization hotfix

October 25, 2026 (America/Los_Angeles). Developer preview; native compilation pending.

- Fixes the reported `INVALID_CONSTANT` at line 93 of diagnostic.1: two newly
  added `Int32` fields used `= -1`, which the installed compiler rejects as a
  member default. Both declarations now omit the initializer.
- Both public readers return `-1` while the attempt serial is zero. After an
  attempt, they return its recorded combat/mounted observation. No lifecycle
  hook, save-policy change, retry, native-lock override or quest-fact edit.
- Adds a source regression for negative member defaults and actual-source
  no-attempt readers, with four mutation controls. The old harness fabricated
  defaults from types and therefore did not exercise the compiler restriction.
- Updates version labels and read-only installation inventory checksums.

Vehicle-combat save creation remains unresolved. Native compilation, a visible
save, reload and progression must be checked independently on the installed game.
Historical packages and their validation evidence remain unchanged.
