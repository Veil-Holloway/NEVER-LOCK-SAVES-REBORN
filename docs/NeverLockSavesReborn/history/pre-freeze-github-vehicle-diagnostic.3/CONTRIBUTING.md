# Contribution and release preparation

RC2 corrects one native autosave type annotation reported by the user's compiler. Other save-policy behavior is preserved; retain the source-contract and preservation checks.
Read `docs/NeverLockSavesReborn/RELEASE-CONTRACT-1.0.0-rc1.md` before proposing work.

Keep changes focused. Preserve all four modes, introduction protection, one-item
queue, optional settings synchronization, Dark Future read-only readers and
message-only switches. Never infer written/reloaded success from submission,
edit quest facts as a workaround or modify game-save bytes.

Run the packaged offline runner as described in README.md. Include the command,
exit status and evidence boundary. Native/game/Windows acceptance is separate.
Do not bundle user settings, reports, saves, logs with personal data, framework
binaries or bytecode caches. Preserve source attribution. Upstream redistribution
permission is unresolved; this candidate does not grant an MIT license to the
whole derived package. Repository creation and public release remain separate
user-directed actions.
