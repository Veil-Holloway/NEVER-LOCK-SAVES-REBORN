# Read-only installation auditor

This kit audits the 1.0.0 runtime files against its pinned runtime_inventory.json. Run python audit_installation.py --game-root <game-installation-directory>. It does not install, repair or edit files. It never reads game-save contents.

Exit 0 means an exact observed runtime match; 1 means drift or a review candidate; 2 means incomplete/unsafe/unreadable input. Dependencies are observed as presence only. File identity, scan budgets, reparse/symlink safeguards, before/after stability, inventory pinning and redacted discovery names remain enforced.

Windows path and handle queries can expose different legacy change-time semantics. The auditor compares common identity using creation time on Windows, and separately checks path/handle change times before and after reading. Its inventory pin hashes actual saved bytes. Cross-API mismatch, observed mutation, replacement and reparse cases have targeted regressions.

Exact installed bytes do not certify live compilation, framework compatibility, save creation or reload integrity. The canonical release test runner also runs this kit's unittest suite. Host-dependent symlink/case-collision tests report explicit skips when unsupported.
