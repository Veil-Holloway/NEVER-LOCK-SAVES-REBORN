# Named settings presets and support snapshot

`profiles.lua` supplies explicit named presets as the documented fallback when a
supported stable character/playthrough identifier is unavailable. It never
detects, selects or applies a character profile automatically. Callers must apply
the complete returned settings only after a successful explicit `get(label)`.
Automatic character/playthrough identity and binding are removed from product scope by the October 28 v2.6 addendum; manual presets remain retained.

The bank is schema 1, a maximum of 16 presets. Labels are case-sensitive ASCII
letters, digits, underscore or hyphen, 1–32 bytes. They are table keys, never
paths. Current settings are strictly typed; unknown keys and malformed fields
refuse the entire update. Missing newer options migrate to safe defaults,
including autosave OFF and the new quest-milestone trigger OFF. `migrate_legacy` explicitly ignores unknown old fields
and never revives obsolete Dark Future blocking options.

The host supplies the existing `config_store`, a bank path under its CET mod
directory, and a checked `exists(path)` callback. New-bank creation requires
confirmed absence of primary, backup and temporary files. Unknown existence,
corrupt/malformed banks, an interrupted initial write or write failure refuses
the update and never applies cached settings. A valid JSON primary with invalid
bank schema is preserved for manual recovery rather than silently overwritten.
The existing store's `.bak` recovery applies to unreadable/invalid JSON.

`support_report.lua` creates a single on-demand structured snapshot and performs
no IO, uploads or continuous logging. It permits only known fields, enumerated
errors/reasons, constrained version tags and exact known notification diagnostic
formats. It captures the current settings, relevant introduction facts,
tri-state Dark Future data, context sensors and queue identifiers. It retains at
most 12 sanitized Guardian records and 8 failure codes. Raw errors, names,
profile labels, paths, save contents and unrelated input fields are excluded.
Autosave acceptances are explicitly labeled host queue acceptances, with the
legacy `accepted` field retained as the same counter. Actual scheduler status and
reason constants are retained through an allowlist/normalization. New
`request_accepted` / `queue_request_accepted` status vocabulary explicitly denotes
queue handoff; checkpoint submission remains Unknown. Current failed
scheduler/configuration boundaries appear as failure codes even without a
separate host failure ring. Write and reload evidence stays Unknown, including when an incoming record
claims Verified. Configuration write acknowledgement does not imply restart
persistence.

## Offline verification

Use the actual candidate `config_store.lua`, an isolated writable fixture
directory and a Lua host. For example:

```
texlua test_profiles.lua MODULE_DIR FIXTURE_DIR CONFIG_STORE_LUA
texlua test_support_report.lua MODULE_DIR
```

The 81 preset assertions exercise actual file replacement through the shipped
store, with a bounded CET JSON boundary double. The 83 support assertions cover
sanitization, false/unknown distinctions, immutability and evidence limits.
These tests run on Lua 5.3 in the available host, not CET LuaJIT/5.1. No game,
CET UI, actual framework versions or restart behavior was executed here.
