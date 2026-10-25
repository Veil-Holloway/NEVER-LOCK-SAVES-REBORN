# RC4 installation audit

This optional Python 3.10+ tool checks the installed **1.0.0-rc4** runtime against
16 pinned files: 13 CET Lua files and 3 REDscript files. Python is not required
for the mod itself. Run this tool from the extracted RC4 package, outside the
game directory. In PowerShell, replace the example with your game root:

```powershell
py -3 .\tools\NLSRInstallAudit\audit_installation.py --game-root "C:\Games\Cyberpunk 2077"
```

The tool prints JSON. Exit `0` means all pinned installed bytes matched and its
scans completed; `1` means drift or a review candidate; `2` means incomplete or
invalid input. It identifies extra Reborn scripts, possible duplicate REDscript
definitions and Reborn markers in other CET mods' immediate `init.lua` files.
It never repairs or deletes files. Settings, support-report and save contents are
not read. An exact result does not prove compilation, compatibility, save
creation, reload or progression.

To save a report, choose a new temporary filename:

```powershell
$reportPath = Join-Path $env:TEMP ("NLSR-install-audit-{0}.json" -f [guid]::NewGuid().ToString("N"))
py -3 .\tools\NLSRInstallAudit\audit_installation.py --game-root "C:\Games\Cyberpunk 2077" | Set-Content -LiteralPath $reportPath -Encoding utf8
$auditExit = $LASTEXITCODE
Write-Host "Report: $reportPath (audit exit: $auditExit)"
```

Add `--version "game=actual build" --version "cet=actual installed version"`
for labels you checked yourself. Accepted labels also include `redscript`,
`red4ext`, `codeware`, `native_settings` and `dark_future`. They are explicitly
user-reported; presence checks do not determine versions or compatibility.
Missing labels remain unknown. Use `--help` for options.

Optional `--redscript-log "C:\Path\To\redscript.log"` and `--cet-log
"C:\Path\To\cyber_engine_tweaks.log"` return a bounded tail's digest and
marker counts, with no log text. RC1, RC2, RC3 and RC4 labels have separate counters. These observations are unscoped: old logs and
zero error markers do not pass current compilation. Inspect fresh logs from an
actual launch separately.

This embedded tool pins runtime bytes only. It does not accept the earlier
acceptance kit's `--archive` option: a package cannot contain its own final ZIP
hash. Verify the downloaded RC4 ZIP separately with its accompanying `.sha256`
sidecar, for example `Get-FileHash -Algorithm SHA256 <ZIP path>`, and compare the
full digest. Neither a ZIP match nor an installation match supplies a gameplay
pass.

The auditor performs no network requests or process launches. It deliberately
follows no links/reparse points; IO, unsafe entries and exceeded size/count limits
prevent an exact result. Scans are bounded and point in time, without a locked
filesystem snapshot. Absolute paths, discovered filenames and raw errors are
omitted; unexpected names use digest identifiers. A review candidate may require
manual local directory inspection to locate it.

The included regression tests use temporary directories and the extracted RC4
runtime as fixture input. Run from the extracted package root:

```powershell
py -3 -m unittest discover -s tools/NLSRInstallAudit/tests -p "test_*.py" -v
```

These tests do not launch the game or establish Windows-specific behavior. Record
actual outcomes in `docs/NeverLockSavesReborn/TEST-MATRIX.csv`; preserve untested
and deferred rows. Earlier broad gameplay working reports were withdrawn; current game acceptance
remains untested. The retained RC2 native-type and RC3 Smart interaction fixes, plus RC4's Unrestricted immediate-request routing, still need actual game compilation and gameplay tests.
