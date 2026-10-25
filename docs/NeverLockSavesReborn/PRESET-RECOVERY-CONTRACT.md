# Schema-aware preset recovery

Production ownership released to root after this change. Only config_store.lua and profiles.lua were changed; UI/status/default-key changes belong to the coordinator.

## Behavior

- `config_store.load(path, optionalValidator)` validates each JSON-table candidate before accepting it. Invalid recognized-schema primary data may fall back to a validated `.bak`. Validator exceptions and nonfunction validators fail closed.
- `config_store.save(path, data, optionalValidator)` validates incoming data before encoding or file access. It checks primary and backup schema before writing, and freshly checks again before rotation.
- An invalid primary cannot rotate over the sole validated backup. New replacement bytes are fully written before invalid-primary removal, and the prior validated backup is retained on failed install/removal/write/close paths.
- `profiles` passes `M.validate_bank` for both load and save, and retains its own result validation for existing simple boundary stores. Read recovery performs no repair or file writes.
- `schema_version > 1` emits `unsupported_schema`. A future primary is not silently downgraded to an older backup. Validated writes also refuse a future primary or backup before opening a temporary write file. No automatic migration or deletion of unknown future bank data is introduced.
- Calls without a validator retain legacy JSON-table acceptance and replacement behavior; there is no sticky global per-path validator/recovery state.

## Fresh evidence

`test_schema_recovery.lua MODULEDIR EXISTING_ISOLATED_FIXTUREDIR` executes actual Lua modules and real filesystem operations, with only CET JSON and injected OS failures doubled.

All five groups pass:

- 78 schema/recovery/future-schema/failure assertions.
- Existing 47 configuration recovery assertions.
- Existing 81 profile disk assertions.
- Existing independent 172 profile validation assertions.
- Existing independent 57 disk-failure assertions.

The authenticated preRC1 baseline fails the first expected recovery assertion. Three focused final-source mutation controls detect a naive load-only recovery fix, future-schema downgrade, and removal of incoming validation before IO. `RESULTS.json` contains full commands, outputs, exit statuses and pre-integration source hashes; production files are frozen.

## Remaining boundary

Lua 5.3 host, not CET/LuaJIT or Windows runtime. No live game/save bytes or quest facts were read or changed. Preset schema compatibility beyond the currently supported schema remains deliberately refused. Existing manual selection semantics are unchanged.
