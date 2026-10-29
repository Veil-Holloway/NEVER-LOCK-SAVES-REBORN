#!/usr/bin/env python3
"""Deterministic unpublished scope-reconciliation review packaging.

No network calls, credentials, clock-dependent metadata or compression library
are used. Git is invoked locally to verify clean committed source provenance. This packages a diagnostic build; it cannot prove in-game save writes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import subprocess
import zipfile
from pathlib import Path, PurePosixPath

VERSION = "1.0.0-vehicle-diagnostic.3"
PACKAGE_REVISION = "scope-reconciliation.1"
TAG = None
BASELINE_COMMIT = "d0df83807c9ba2899d195fdb40d934c32d7183ee"
FULL_ZIP = f"Never_Lock_Saves_Reborn_v{VERSION}_{PACKAGE_REVISION}_SOURCE_AND_TESTS.zip"
RUNTIME_ZIP = f"Never_Lock_Saves_Reborn_v{VERSION}_{PACKAGE_REVISION}_RUNTIME_ONLY.zip"
VALIDATION = "VALIDATION-SCOPE-RECONCILIATION.md"
NOTES = "RELEASE-NOTES.md"
RUNTIME_DOCS = (
    "README.md", "LICENSE", "ATTRIBUTION.md", "PERMISSION.md",
    "CHANGELOG-VEHICLE-DIAGNOSTIC.3.md", "DIAGNOSTIC-VEHICLE-SAVE.md",
    VALIDATION, NOTES, "PACKAGING-SCOPE-RECONCILIATION.md",
    "docs/NeverLockSavesReborn/Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md",
)
GENERATED_MANIFESTS = {"BUILD-MANIFEST.json", "FILE_MANIFEST.sha256"}
EXCLUDED_PARTS = {
    ".git", "packages", "dist", "__pycache__", ".pytest_cache",
    ".mypy_cache", ".ruff_cache", ".cache",
}
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return (
        bool(name) and not path.is_absolute() and str(path) == name
        and ".." not in path.parts and "\\" not in name and ":" not in name
        and all(ord(char) >= 32 and ord(char) != 127 for char in name)
    )


def source_files(source: Path) -> dict[str, bytes]:
    files = {}
    # Inspect symlinks before exclusions: excluded package/cache paths must not
    # hide a path that escapes the source tree. Never follow symlink directories.
    for path in sorted(source.rglob("*"), key=lambda item: item.relative_to(source).as_posix()):
        require(not path.is_symlink(), "Symlink rejected: " + path.relative_to(source).as_posix())
        mode = path.stat().st_mode
        require(stat.S_ISDIR(mode) or stat.S_ISREG(mode), "Non-regular source entry rejected")
        if not stat.S_ISREG(mode):
            continue
        relative = path.relative_to(source).as_posix()
        require(safe_name(relative), "Unsafe source name")
        if EXCLUDED_PARTS.intersection(PurePosixPath(relative).parts):
            continue
        if relative in GENERATED_MANIFESTS or path.suffix in {".pyc", ".pyo"}:
            continue
        require("nlsrsaveguardian" not in relative.lower() and path.name.lower() != "save_guardian.py",
                "Excluded backup/recovery companion in current package scope: " + relative)
        files[relative] = path.read_bytes()
    return files


def runtime_files(files: dict[str, bytes]) -> list[str]:
    inventory_path = "tools/NLSRInstallAudit/runtime_inventory.json"
    require(inventory_path in files, "Missing runtime inventory")
    inventory = json.loads(files[inventory_path])
    require(inventory.get("release") == VERSION, "Runtime inventory version mismatch")
    rows = inventory.get("runtime_files")
    require(isinstance(rows, list) and len(rows) == 16, "Expected exactly 16 runtime records")
    names = []
    for row in rows:
        require(isinstance(row, dict), "Invalid inventory record")
        name = row.get("path")
        require(isinstance(name, str) and safe_name(name), "Unsafe runtime path")
        require(name.startswith(("bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/", "r6/scripts/NeverLockSavesReborn/")), "Unexpected runtime path")
        require(name not in names and name in files, "Duplicate or missing runtime path")
        require(type(row.get("size")) is int and row["size"] == len(files[name]), "Runtime size mismatch: " + name)
        require(row.get("sha256") == digest(files[name]), "Runtime hash mismatch: " + name)
        names.append(name)
    return sorted(names)


def file_records(files: dict[str, bytes]) -> list[dict]:
    return [{"path": name, "size_bytes": len(files[name]), "sha256": digest(files[name])} for name in sorted(files)]


def text_manifest(files: dict[str, bytes]) -> bytes:
    return "".join(digest(files[name]) + "  " + name + "\n" for name in sorted(files)).encode("utf-8")


def package(output: Path, name: str, files: dict[str, bytes], commit: str, scope: str) -> Path:
    manifest = {
        "schema_version": 1, "version": VERSION, "tag": TAG,
        "package_revision": PACKAGE_REVISION, "publication": "unpublished_review_only",
        "scope_authority": "roadmap_v2.6_2026-10-28",
        "excluded_product_systems": ["game_save_backup_retention_storage", "save_recovery_restore", "automatic_character_identity_configuration"],
        "source_commit": commit, "baseline_commit": BASELINE_COMMIT,
        "scope": scope, "maturity": "experimental_diagnostic",
        "native_compilation": "NOT_RUN", "vehicle_combat_save_creation": "UNRESOLVED",
        "save_write_reload_progression": "UNVERIFIED",
        "toolchain": {"builder": "python3_stdlib", "compression": "ZIP_STORED", "timestamp": "1980-01-01T00:00:00", "file_mode": "100644"},
        "manifest_exclusions": sorted(GENERATED_MANIFESTS),
        "files": file_records(files),
    }
    payload = dict(files)
    payload["BUILD-MANIFEST.json"] = json_bytes(manifest)
    payload["FILE_MANIFEST.sha256"] = text_manifest(payload)
    path = output / name
    require(not path.exists(), "Refusing to overwrite existing artifact: " + name)
    with zipfile.ZipFile(path, "x", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for relative in sorted(payload):
            info = zipfile.ZipInfo(relative, (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_STORED
            info.extra = b""
            info.comment = b""
            archive.writestr(info, payload[relative])
    verify_archive(path, commit, scope)
    (output / (name + ".sha256")).write_bytes((digest(path.read_bytes()) + "  " + name + "\n").encode("ascii"))
    (output / (name[:-4] + ".manifest.json")).write_bytes(payload["BUILD-MANIFEST.json"])
    return path


def verify_archive(path: Path, commit: str, scope: str) -> tuple[dict, dict[str, bytes]]:
    require(bool(HEX40.fullmatch(commit)), "Invalid source commit")
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        require(len(names) == len(set(names)) and names == sorted(names), "Duplicate or unsorted ZIP entries")
        require(all(safe_name(name) for name in names), "Unsafe ZIP entry")
        require(len(entries) <= 10_000 and sum(entry.file_size for entry in entries) <= 100_000_000, "ZIP verification bounds exceeded")
        for entry in entries:
            require(entry.compress_type == zipfile.ZIP_STORED and entry.date_time == (1980, 1, 1, 0, 0, 0), "Non-deterministic ZIP entry metadata")
            require(entry.create_system == 3 and entry.external_attr == 0o100644 << 16 and not entry.extra and not entry.comment, "Unexpected ZIP mode or extra data")
        require(archive.testzip() is None, "ZIP CRC verification failed")
        payload = {name: archive.read(name) for name in names}
    require(GENERATED_MANIFESTS.issubset(payload), "Missing generated manifests")
    raw = payload["BUILD-MANIFEST.json"]
    manifest = json.loads(raw)
    require(manifest.get("schema_version") == 1 and manifest.get("version") == VERSION and manifest.get("tag") == TAG, "Build manifest version mismatch")
    require(manifest.get("package_revision") == PACKAGE_REVISION and manifest.get("publication") == "unpublished_review_only", "Review package revision mismatch")
    require(not any("nlsrsaveguardian" in name.lower() or PurePosixPath(name).name.lower() == "save_guardian.py" for name in names), "Excluded companion in ZIP")
    require(manifest.get("source_commit") == commit and manifest.get("baseline_commit") == BASELINE_COMMIT and manifest.get("scope") == scope, "Build provenance mismatch")
    require(manifest.get("maturity") == "experimental_diagnostic" and manifest.get("vehicle_combat_save_creation") == "UNRESOLVED", "Diagnostic maturity mismatch")
    require(manifest.get("native_compilation") == "NOT_RUN" and manifest.get("save_write_reload_progression") == "UNVERIFIED", "Unsupported runtime validation claim")
    data = {name: value for name, value in payload.items() if name not in GENERATED_MANIFESTS}
    require(manifest.get("files") == file_records(data) and raw == json_bytes(manifest), "Build manifest contents mismatch")
    without_text = {name: value for name, value in payload.items() if name != "FILE_MANIFEST.sha256"}
    require(payload["FILE_MANIFEST.sha256"] == text_manifest(without_text), "Text manifest mismatch")
    return manifest, payload


def expected_assets() -> set[str]:
    return {FULL_ZIP, RUNTIME_ZIP, FULL_ZIP + ".sha256", RUNTIME_ZIP + ".sha256", FULL_ZIP[:-4] + ".manifest.json", RUNTIME_ZIP[:-4] + ".manifest.json", VALIDATION}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(bool(HEX40.fullmatch(args.commit)), "--commit must be a lowercase 40-digit Git SHA")
    require(not args.source.is_symlink(), "Symlink source root rejected")
    source, output = args.source.resolve(strict=True), args.output.resolve()
    require(source.is_dir(), "Source must be a directory")
    head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    require(head == args.commit, "Source HEAD differs from --commit")
    status = subprocess.check_output(["git", "-C", str(source), "status", "--porcelain", "--untracked-files=normal"], text=True)
    require(not status, "Source must be a clean committed tree before review packaging")
    if output.is_relative_to(source):
        relative = output.relative_to(source)
        require(bool(relative.parts) and relative.parts[0] in {"dist", "packages"}, "Output inside source must be under dist/ or packages/")
    require(not output.exists() or not any(output.iterdir()), "Output must be absent or empty")
    files = source_files(source)
    names = runtime_files(files)
    require(all(name in files for name in RUNTIME_DOCS), "Missing required diagnostic documentation")
    output.mkdir(parents=True, exist_ok=True)
    package(output, FULL_ZIP, files, args.commit, "full_source")
    package(output, RUNTIME_ZIP, {name: files[name] for name in names + list(RUNTIME_DOCS)}, args.commit, "runtime_only")
    (output / VALIDATION).write_bytes(files[VALIDATION])
    require({path.name for path in output.iterdir()} == expected_assets(), "Unexpected output inventory")
    print(json.dumps({"version": VERSION, "package_revision": PACKAGE_REVISION, "publication": "unpublished_review_only", "source_commit": args.commit, "assets": [{"name": path.name, "size_bytes": path.stat().st_size, "sha256": digest(path.read_bytes())} for path in sorted(output.iterdir())]}, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
