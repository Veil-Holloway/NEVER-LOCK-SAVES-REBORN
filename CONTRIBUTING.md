# Development and verification

Current contract: preserve the four modes, native/introduction guards, event-driven one-item player queue, independent automatic/test expiry, phone-manager gating, completion matching, read-only Dark Future readers and message-only switches. Never use quest-fact writes or game-save edits as a workaround.

The canonical release suite is docs/NeverLockSavesReborn/validation/run_release_checks.py with RELEASE-TEST-PLAN.json. Run:

    python docs/NeverLockSavesReborn/validation/run_release_checks.py --release . --output ../reborn-checks --lupa

The optional Python host requires the Lupa package with its lua53 module. Alternatively use --lua followed by a Lua 5.3-compatible executable path. Nested checks inherit the explicitly selected command; no sitecustomize patch or machine-specific launcher is needed. Lua 5.3 execution is not CET LuaJIT or native REDscript compilation.

All active checks must return zero. Mutation controls must fail at their intended assertions, not merely because imports/hosts are missing. Output includes exact commands, exit codes, logs and explicit retired checks. Original version-frozen plans and old evidence remain in prior immutable developer archives; they are not the current release contract. TEST-DISPOSITION.json documents their replacements and the three retired backup/recovery checks. Removed checks are not counted as passes.

Keep runtime changes minimal and preserve license/attribution. Do not bundle user configs, personal reports/logs, game saves, framework binaries or bytecode caches. PERMISSION.md supersedes the historical permission-pending notes. Public publication and repository changes remain separate user-directed actions.
