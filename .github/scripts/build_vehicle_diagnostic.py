#!/usr/bin/env python3
"""Deterministic diagnostic packaging and read-only release verification.

No network calls, credentials, clock-dependent metadata or compression library
are used. This packages a diagnostic build; it cannot prove in-game save writes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath

VERSION = "1.0.0-vehicle-diagnostic.3"
TAG = "v" + VERSION
BASELINE_COMMIT = "ad339b34ccbcb77422db0b4d804baa6bcb229f4b"
FULL_ZIP = f"Never_Lock_Saves_Reborn_v{VERSION}_Release_Diagnostic.zip"
RUNTIME_ZIP = f"Never_Lock_Saves_Reborn_v{VERSION}_RUNTIME_ONLY.zip"
VALIDATION = "VALIDATION-VEHICLE-DIAGNOSTIC.3.md"
NOTES = "RELEASE-NOTES-VEHICLE-DIAGNOSTIC.3.md"
RUNTIME_DOCS = (
    "README.md", "LICENSE", "ATTRIBUTION.md", "PERMISSION.md",
    "CHANGELOG-VEHICLE-DIAGNOSTIC.3.md", "DIAGNOSTIC-VEHICLE-SAVE.md",
    VALIDATION, NOTES,
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


def verify_release_downloads(receipt: dict, directory: Path, tag_commit: str) -> str:
    """Verify downloaded GitHub assets against an explicit Drive readback receipt.

    This verifies the recorded Drive hashes; it does not authenticate to Drive.
    The operator must produce the receipt only after authenticated raw readback.
    """
    require(type(receipt) is dict and receipt.get("schema_version") == 1 and receipt.get("version") == VERSION, "Invalid publication receipt version")
    commit = receipt.get("source_commit")
    require(isinstance(commit, str) and bool(HEX40.fullmatch(commit)) and commit == tag_commit, "Receipt/tag commit mismatch")
    require(receipt.get("drive_verification_method") == "authenticated_raw_readback", "Missing authenticated Drive readback attestation")
    rows = receipt.get("assets")
    require(type(rows) is list and len(rows) == 2, "Expected exactly two ZIP receipt records")
    by_name = {}
    fields = {"name", "sha256", "size_bytes", "drive_file_id", "drive_sha256", "drive_size_bytes", "drive_verified"}
    for row in rows:
        require(type(row) is dict and set(row) == fields, "Invalid ZIP receipt record")
        name = row["name"]
        require(name in {FULL_ZIP, RUNTIME_ZIP} and name not in by_name, "Unexpected or duplicate ZIP receipt name")
        sha = row["sha256"]
        require(isinstance(sha, str) and bool(HEX64.fullmatch(sha)) and row["drive_sha256"] == sha, "GitHub/Drive hash mismatch in receipt")
        size = row["size_bytes"]
        require(type(size) is int and 0 < size <= 100_000_000 and type(row["drive_size_bytes"]) is int and row["drive_size_bytes"] == size and row["drive_verified"] is True, "Invalid Drive size/readback evidence")
        require(isinstance(row["drive_file_id"], str) and re.fullmatch(r"[A-Za-z0-9_-]{10,200}", row["drive_file_id"]) is not None, "Invalid Drive file identifier")
        data = (directory / name).read_bytes()
        require(len(data) == size and digest(data) == sha, "Downloaded ZIP differs from verified receipt")
        by_name[name] = row
    require(set(by_name) == {FULL_ZIP, RUNTIME_ZIP}, "Missing ZIP receipt")
    require({path.name for path in directory.iterdir()} == expected_assets(), "Unexpected or missing release assets")
    checked = {}
    for name, scope in ((FULL_ZIP, "full_source"), (RUNTIME_ZIP, "runtime_only")):
        manifest, payload = verify_archive(directory / name, commit, scope)
        require((directory / (name[:-4] + ".manifest.json")).read_bytes() == payload["BUILD-MANIFEST.json"], "External JSON manifest mismatch")
        require((directory / (name + ".sha256")).read_bytes() == (by_name[name]["sha256"] + "  " + name + "\n").encode("ascii"), "External ZIP checksum mismatch")
        checked[name] = (manifest, payload)
    full_payload = checked[FULL_ZIP][1]
    for name, data in checked[RUNTIME_ZIP][1].items():
        if name not in GENERATED_MANIFESTS:
            require(full_payload.get(name) == data, "Runtime/full payload mismatch: " + name)
    require((directory / VALIDATION).read_bytes() == full_payload.get(VALIDATION), "Validation report asset mismatch")
    return commit


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
    if output.is_relative_to(source):
        relative = output.relative_to(source)
        require(bool(relative.parts) and relative.parts[0] in {"dist", "packages"}, "Output inside source must be under dist/ or packages/")
    require(not output.exists() or not any(output.iterdir()), "Output must be absent or empty")
    require(not (source / "docs/NeverLockSavesReborn/Never_Lock_Saves_Reborn_Master_Status_Roadmap_v2.6.md").exists(),
            "Historical diagnostic builder cannot package scope-reconciled source; use build_scope_reconciliation.py")
    files = source_files(source)
    names = runtime_files(files)
    require(all(name in files for name in RUNTIME_DOCS), "Missing required diagnostic documentation")
    output.mkdir(parents=True, exist_ok=True)
    package(output, FULL_ZIP, files, args.commit, "full_source")
    package(output, RUNTIME_ZIP, {name: files[name] for name in names + list(RUNTIME_DOCS)}, args.commit, "runtime_only")
    (output / VALIDATION).write_bytes(files[VALIDATION])
    require({path.name for path in output.iterdir()} == expected_assets(), "Unexpected output inventory")
    print(json.dumps({"version": VERSION, "source_commit": args.commit, "assets": [{"name": path.name, "size_bytes": path.stat().st_size, "sha256": digest(path.read_bytes())} for path in sorted(output.iterdir())]}, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
