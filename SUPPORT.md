# Support for 1.0.0

Include the build/version and ZIP SHA-256, actual game/framework versions, expected behavior, observed behavior and the shortest reproduction. Record whether Dark Future, Native Settings, Deferred Save and Smart Autosave are enabled.

Distinguish a queued request, saving started, a game completion confirmation, an actual Load-menu entry, successful reload and subsequent progression. If a save fails, preserve the fresh relevant CET/redscript log excerpts. Review any exported support-report.json or guardian-report.json for personal information before sharing. The mod does not upload reports automatically.

tools/NLSRInstallAudit/audit_installation.py is a read-only installed-source auditor. Run it against the game installation directory, never the saved-games directory. It checks runtime identity and potential duplicates; it does not repair files or certify compilation, compatibility or save integrity.

The Windows auditor's timestamp/manifest-pin issues are fixed in this release and covered by regression tests. Symbolic-link/case-collision filesystem fixtures may be unavailable on hosts without the necessary filesystem features or privileges; validation records those skips explicitly.
