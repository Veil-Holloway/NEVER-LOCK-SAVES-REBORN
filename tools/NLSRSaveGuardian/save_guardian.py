#!/usr/bin/env python3
"""Optional offline backup/recovery helper. No game-save modification or networking.

Backup and restore fail closed unless Windows tasklist confirms Cyberpunk2077.exe
is absent. Hash validity does not establish game loadability or quest correctness.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import uuid

OWNER = "NeverLockSavesReborn.SaveGuardian"
VERSION = 1
MAX_FILES, MAX_DIRS, MAX_DEPTH = 2048, 1024, 16
MAX_BYTES, MAX_MANIFEST = 4 * 1024**3, 1024**2
ID = re.compile(r"^[0-9a-f]{32}$")
PROFILE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
RETIRED = ".retired"
LOCK = ".guardian-retention.lock"
RETIRED_MARKER = ".owner.json"
RESERVED = {"CON", "PRN", "AUX", "NUL"} | {f"{p}{n}" for p in ("COM", "LPT") for n in range(1, 10)}


class GuardianError(Exception):
    pass


def _check_node(path: Path) -> os.stat_result:
    s = path.lstat()
    if stat.S_ISLNK(s.st_mode) or getattr(s, "st_file_attributes", 0) & 0x400:
        raise GuardianError("Symlinks and Windows reparse points are refused")
    return s


def _safe_path(value: str | Path, *, exists: bool = True) -> Path:
    p = Path(value).expanduser().absolute()
    if ".." in p.parts:
        raise GuardianError("Parent traversal is refused")
    for node in reversed((p, *p.parents)):
        if node.exists() or node.is_symlink():
            _check_node(node)
    p = p.resolve(strict=exists)
    if exists and not p.is_dir():
        raise GuardianError("Expected a directory")
    return p


def _overlap(a: Path, b: Path) -> bool:
    return a == b or a in b.parents or b in a.parents


def _relative(raw: str) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or ":" in raw:
        raise GuardianError("Unsafe relative file path")
    p = PurePosixPath(raw)
    if p.is_absolute() or raw != p.as_posix() or any(part in ("", ".", "..") for part in raw.split("/")):
        raise GuardianError("Unsafe relative file path")
    if len(p.parts) > MAX_DEPTH:
        raise GuardianError("Directory depth limit exceeded")
    for part in p.parts:
        if any(ord(c) < 32 for c in part) or part[-1:] in (".", " ") or part.split(".")[0].upper() in RESERVED:
            raise GuardianError("Unsafe Windows-compatible file name")
    return raw


def _open_source(path: Path):
    before = _check_node(path)
    if not stat.S_ISREG(before.st_mode):
        raise GuardianError("Only regular files can be copied")
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        opened = os.fstat(fd)
        if (before.st_dev, before.st_ino) != (opened.st_dev, opened.st_ino):
            raise GuardianError("File changed while opening")
        return os.fdopen(fd, "rb")
    except BaseException:
        os.close(fd)
        raise


def _hash(path: Path) -> tuple[int, str]:
    before = _check_node(path)
    h = hashlib.sha256()
    size = 0
    with _open_source(path) as f:
        while chunk := f.read(1024 * 1024):
            size += len(chunk)
            if size > MAX_BYTES:
                raise GuardianError("File size limit exceeded")
            h.update(chunk)
    after = _check_node(path)
    if (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino) or size != after.st_size:
        raise GuardianError("Source changed while hashing")
    return size, h.hexdigest()


def _scan(root: Path) -> tuple[list[dict], list[str]]:
    _safe_path(root)
    files, directories, seen, total = [], [], set(), 0
    pending = [root]
    while pending:
        here = pending.pop()
        _safe_path(here)
        with os.scandir(here) as entries:
            for entry in entries:
                node = Path(here) / entry.name
                s = _check_node(node)
                rel = _relative(node.relative_to(root).as_posix())
                if rel.casefold() in seen:
                    raise GuardianError("Case-insensitive path collision")
                seen.add(rel.casefold())
                if stat.S_ISDIR(s.st_mode):
                    directories.append(rel)
                    if len(directories) > MAX_DIRS:
                        raise GuardianError("Directory count limit exceeded")
                    pending.append(node)
                elif stat.S_ISREG(s.st_mode):
                    size, digest = _hash(node)
                    total += size
                    if total > MAX_BYTES or len(files) >= MAX_FILES:
                        raise GuardianError("Snapshot capacity limit exceeded")
                    files.append({"path": rel, "size": size, "sha256": digest})
                else:
                    raise GuardianError("Non-regular filesystem objects are refused")
    return sorted(files, key=lambda f: f["path"]), sorted(directories)


def _game_closed() -> None:
    if os.name != "nt":
        raise GuardianError("Game status unknown: backup/restore requires Windows tasklist")
    try:
        result = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, timeout=15, check=False)
    except (OSError, UnicodeError, subprocess.SubprocessError) as e:
        raise GuardianError("Unable to establish game process status") from e
    if result.returncode != 0 or not result.stdout.strip():
        raise GuardianError("Unable to establish game process status")
    rows = list(csv.reader(io.StringIO(result.stdout)))
    if not rows or any(len(row) < 5 or not row[1].isdigit() for row in rows):
        raise GuardianError("Unrecognized process inventory; game status unknown")
    if any(row[0].casefold() == "cyberpunk2077.exe" for row in rows):
        raise GuardianError("Close Cyberpunk 2077 before backup or restore")


def _copy_tree(source: Path, target: Path, files: list[dict], directories: list[str]) -> None:
    target.mkdir()
    for rel in sorted(directories, key=lambda p: (len(PurePosixPath(p).parts), p)):
        (target / rel).mkdir()
    for entry in files:
        with _open_source(source / entry["path"]) as src, (target / entry["path"]).open("xb") as dst:
            shutil.copyfileobj(src, dst, 1024 * 1024)
            dst.flush(); os.fsync(dst.fileno())


def _metadata(value: str) -> str:
    if not isinstance(value, str) or len(value) > 128 or any(ord(c) < 32 for c in value):
        raise GuardianError("Metadata must be at most 128 printable characters")
    return value or "unknown"


def _profile(value: str) -> str:
    if not isinstance(value, str) or not PROFILE.fullmatch(value):
        raise GuardianError("Retention profile must be 1-64 letters, digits, underscores or hyphens")
    return value


def _keep(value: int) -> int:
    if type(value) is not int or value < 2:
        raise GuardianError("Retention must keep at least two verified active snapshots per stream")
    return value


def _created(value: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value)
        if parsed.tzinfo is None:
            raise ValueError("timezone missing")
        return parsed.astimezone(timezone.utc)
    except (ValueError, OverflowError) as e:
        raise GuardianError("Invalid snapshot timestamp") from e


def _source_fingerprint(source: Path) -> str:
    return hashlib.sha256(os.path.normcase(str(source)).encode("utf-8")).hexdigest()


def _load_manifest(snapshot: Path, *, expected_id: str | None = None) -> dict:
    _safe_path(snapshot)
    name = expected_id or snapshot.name
    if not ID.fullmatch(name):
        raise GuardianError("Invalid snapshot identifier")
    path = snapshot / "manifest.json"
    _check_node(path)
    if path.stat().st_size > MAX_MANIFEST:
        raise GuardianError("Manifest capacity limit exceeded")
    try:
        with _open_source(path) as f:
            data = f.read(MAX_MANIFEST + 1)
            if len(data) > MAX_MANIFEST:
                raise GuardianError("Manifest capacity limit exceeded")
            manifest = json.loads(data)
    except (ValueError, UnicodeError) as e:
        raise GuardianError("Malformed snapshot manifest") from e
    if not isinstance(manifest, dict) or manifest.get("owner") != OWNER or type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != VERSION or manifest.get("snapshot_id") != name:
        raise GuardianError("Snapshot ownership/schema mismatch")
    files, dirs = manifest.get("files"), manifest.get("directories")
    if not isinstance(files, list) or not files or len(files) > MAX_FILES or not isinstance(dirs, list) or len(dirs) > MAX_DIRS:
        raise GuardianError("Invalid snapshot inventory")
    seen = set()
    for raw in dirs + [x.get("path") if isinstance(x, dict) else None for x in files]:
        rel = _relative(raw)
        if rel.casefold() in seen:
            raise GuardianError("Duplicate manifest path")
        seen.add(rel.casefold())
    for entry in files:
        if type(entry.get("size")) is not int or entry["size"] < 0 or not isinstance(entry.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
            raise GuardianError("Invalid file integrity metadata")
    if sum(f["size"] for f in files) > MAX_BYTES:
        raise GuardianError("Snapshot capacity limit exceeded")
    for field in ("created_utc", "game_build", "mod_build", "character_id", "source_slot"):
        _metadata(manifest.get(field))
    _created(manifest["created_utc"])
    if "retention_profile" in manifest:
        _profile(manifest["retention_profile"])
    if "retention_source" in manifest and (not isinstance(manifest["retention_source"], str) or not re.fullmatch(r"[0-9a-f]{64}", manifest["retention_source"])):
        raise GuardianError("Invalid retention source fingerprint")
    return manifest


def verify_snapshot(snapshot: str | Path, *, _expected_id: str | None = None) -> dict:
    path = _safe_path(snapshot)
    manifest = _load_manifest(path, expected_id=_expected_id)
    if {p.name for p in path.iterdir()} != {"data", "manifest.json"}:
        raise GuardianError("Unexpected snapshot contents")
    files, dirs = _scan(path / "data")
    if files != sorted(manifest["files"], key=lambda e: e["path"]) or dirs != sorted(manifest["directories"]):
        raise GuardianError("Snapshot integrity mismatch")
    return manifest


def backup(save_dir: str | Path, backup_root: str | Path, *, game_build="unknown", mod_build="unknown", character_id="unknown", retention_profile: str | None = None, keep: int | None = None, _probe=_game_closed) -> dict:
    source = _safe_path(save_dir)
    root = _safe_path(backup_root, exists=False)
    if _overlap(source, root):
        raise GuardianError("Save and backup directories must not overlap")
    meta = {"game_build": _metadata(game_build), "mod_build": _metadata(mod_build), "character_id": _metadata(character_id)}
    if retention_profile is not None or keep is not None:
        if retention_profile is None or keep is None:
            raise GuardianError("Automatic rotation requires both retention profile and keep count")
        meta["retention_profile"] = _profile(retention_profile)
        meta["retention_source"] = _source_fingerprint(source)
        _keep(keep)
    _probe()
    files, dirs = _scan(source)
    if not files:
        raise GuardianError("Empty source directory; select a save-slot folder")
    required = sum(f["size"] for f in files)
    root.mkdir(parents=True, exist_ok=True)
    _safe_path(root)
    if shutil.disk_usage(root).free < required + 1024**2:
        raise GuardianError("Insufficient free space for snapshot")
    if retention_profile is not None:
        with _retention_lock(root) as lock:
            result = _publish_backup(source, root, files, dirs, meta, keep, _probe=_probe)
        if lock["release_error"]:
            result["rotation"].update(status="stopped", error="Retention lock needs manual review: " + lock["release_error"])
        return result
    return _publish_backup(source, root, files, dirs, meta, keep, _probe=_probe)


def _publish_backup(source: Path, root: Path, files: list[dict], dirs: list[str], meta: dict, keep: int | None, *, _probe) -> dict:
    _probe()
    ident = uuid.uuid4().hex
    stage, final = root / (".pending-" + ident), root / ident
    stage.mkdir()
    try:
        _copy_tree(source, stage / "data", files, dirs)
        if _scan(source) != (files, dirs):
            raise GuardianError("Source changed during snapshot; nothing published")
        _probe()
        manifest = {"owner": OWNER, "schema_version": VERSION, "snapshot_id": ident,
                    "created_utc": datetime.now(timezone.utc).isoformat(), "source_slot": _metadata(source.name),
                    "files": files, "directories": dirs, **meta,
                    "evidence": "game_closed_and_source_hashes_unchanged", "loadability": "unknown", "quest_progression": "unknown"}
        with (stage / "manifest.json").open("x", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2); f.flush(); os.fsync(f.fileno())
        verify_snapshot(stage, _expected_id=ident)
        _probe()
        if final.exists():
            raise GuardianError("Snapshot destination already exists")
        stage.rename(final)
        if "retention_profile" in meta:
            # Publication succeeded independently of retention. Never discard or
            # misreport the new snapshot because a later retirement step fails.
            result = dict(manifest, backup_status="published_hash_verified")
            try:
                verify_snapshot(final)
                result["rotation"] = _apply_locked(root, meta["retention_profile"], keep, protect_id=ident, _probe=_probe)
            except (GuardianError, OSError) as e:
                result["rotation"] = {"status": "stopped", "retired_ids": [], "error": str(e), "new_snapshot_preserved": True}
            return result
        return manifest
    finally:
        if stage.exists() and not stage.is_symlink():
            shutil.rmtree(stage)


def list_snapshots(backup_root: str | Path) -> list[dict]:
    root = _safe_path(backup_root)
    records = []
    for index, entry in enumerate(root.iterdir()):
        if index >= MAX_FILES:
            raise GuardianError("Backup root inventory limit exceeded")
        if ID.fullmatch(entry.name):
            try:
                m = verify_snapshot(entry)
                record = {"snapshot_id": m["snapshot_id"], "created_utc": m["created_utc"], "status": "hash_verified", "source_slot": m["source_slot"], "game_build": m["game_build"], "character_id": m["character_id"], "loadability": "unknown"}
                for key in ("retention_profile", "retention_source"):
                    if key in m: record[key] = m[key]
                records.append(record)
            except (OSError, GuardianError):
                records.append({"snapshot_id": entry.name, "status": "invalid", "loadability": "unknown"})
    return sorted(records, key=lambda x: (_created(x["created_utc"]) if "created_utc" in x else datetime.min.replace(tzinfo=timezone.utc), x["snapshot_id"]), reverse=True)


def recovery_preview(snapshot: str | Path) -> dict:
    m = verify_snapshot(snapshot)
    return {"snapshot_id": m["snapshot_id"], "files": len(m["files"]), "bytes": sum(x["size"] for x in m["files"]), "game_build": m["game_build"], "mod_build": m["mod_build"], "character_id": m["character_id"], "source_slot": m["source_slot"], "loadability": "unknown", "quest_progression": "unknown", "action": "copy_to_new_directory_only"}


def restore(snapshot: str | Path, destination: str | Path, *, confirm: str, _probe=_game_closed) -> dict:
    src = _safe_path(snapshot)
    if src.parent.name.casefold() == RETIRED:
        raise GuardianError("Reactivate a retired snapshot before restoring a separate copy")
    m = verify_snapshot(src)
    if confirm != m["snapshot_id"]:
        raise GuardianError("Confirmation must equal the previewed snapshot identifier")
    dst = _safe_path(destination, exists=False)
    if dst.exists() or _overlap(src.parent, dst):
        raise GuardianError("Restore requires a new destination outside the backup root")
    parent = _safe_path(dst.parent)
    _probe()
    stage = parent / (".guardian-restore-" + uuid.uuid4().hex)
    try:
        _copy_tree(src / "data", stage, m["files"], m["directories"])
        if _scan(stage) != (sorted(m["files"], key=lambda f: f["path"]), sorted(m["directories"])):
            raise GuardianError("Restored copy integrity mismatch")
        verify_snapshot(src)
        _probe(); _probe()
        if dst.exists():
            raise GuardianError("Restore destination appeared during copy")
        stage.rename(dst)
        return {"snapshot_id": m["snapshot_id"], "status": "restored_copy_hash_verified", "loadability": "unknown", "quest_progression": "unknown"}
    finally:
        if stage.exists() and not stage.is_symlink():
            shutil.rmtree(stage)


def _root_entries(root: Path) -> dict[str, Path]:
    entries = {}
    for index, entry in enumerate(root.iterdir()):
        if index >= MAX_FILES:
            raise GuardianError("Backup root inventory limit exceeded")
        key = entry.name.casefold()
        if key in entries:
            raise GuardianError("Case-insensitive backup-root collision")
        entries[key] = entry
    return entries


def _read_control(path: Path) -> dict:
    _check_node(path)
    with _open_source(path) as f:
        raw = f.read(MAX_MANIFEST + 1)
    if len(raw) > MAX_MANIFEST:
        raise GuardianError("Control file capacity limit exceeded")
    try:
        value = json.loads(raw)
    except (ValueError, UnicodeError) as e:
        raise GuardianError("Malformed retention control file") from e
    if not isinstance(value, dict):
        raise GuardianError("Invalid retention control file")
    return value


def _retired_store(root: Path, *, create: bool = False) -> Path:
    entries = _root_entries(root)
    existing = entries.get(RETIRED)
    if existing is not None and existing.name != RETIRED:
        raise GuardianError("Unsafe retirement-directory case alias")
    path = root / RETIRED
    expected = {"owner": OWNER, "schema_version": VERSION, "purpose": "reversible_retirement"}
    if existing is None:
        if not create:
            raise GuardianError("No owned retirement directory exists")
        path.mkdir()
        with (path / RETIRED_MARKER).open("x", encoding="utf-8") as f:
            json.dump(expected, f); f.flush(); os.fsync(f.fileno())
    _safe_path(path)
    children = _root_entries(path)
    marker = children.get(RETIRED_MARKER)
    value = _read_control(marker) if marker is not None and marker.name == RETIRED_MARKER else None
    if value != expected or type(value.get("schema_version") if value else None) is not int:
        raise GuardianError("Retirement ownership marker is missing or invalid")
    if _check_node(root).st_dev != _check_node(path).st_dev:
        raise GuardianError("Retirement must remain on the same filesystem; no copy fallback")
    return path


@contextmanager
def _retention_lock(root: Path):
    entries = _root_entries(root)
    if LOCK in entries:
        raise GuardianError("Retention lock exists; no stale lock is automatically removed")
    path = root / LOCK
    payload = json.dumps({"owner": OWNER, "nonce": uuid.uuid4().hex}).encode("utf-8")
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_BINARY", 0), 0o600)
    except FileExistsError as e:
        raise GuardianError("Another retention operation owns the lock") from e
    held = os.fstat(fd)
    state = {"release_error": None}
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(payload); f.flush(); os.fsync(f.fileno())
        yield state
    finally:
        try:
            now = _check_node(path)
            with _open_source(path) as f: current = f.read(len(payload) + 1)
            if (held.st_dev, held.st_ino) != (now.st_dev, now.st_ino) or current != payload:
                raise GuardianError("Retention lock ownership changed")
            path.unlink()
        except (GuardianError, OSError) as e:
            state["release_error"] = str(e)


def _stream(manifest: dict, profile: str) -> tuple[str, str] | None:
    if manifest.get("retention_profile") != profile or "retention_source" not in manifest:
        return None
    return manifest["retention_source"], manifest["character_id"]


def _profile_plan(root: Path, profile: str, keep: int, *, protect_id: str | None = None) -> dict:
    profile, keep = _profile(profile), _keep(keep)
    streams, invalid, unmanaged, other = {}, [], [], []
    for entry in _root_entries(root).values():
        if not ID.fullmatch(entry.name):
            continue
        try:
            manifest = verify_snapshot(entry)
        except (GuardianError, OSError):
            invalid.append(entry.name)
            continue
        key = _stream(manifest, profile)
        if key is None:
            (other if manifest.get("retention_profile") not in (None, profile) else unmanaged).append(entry.name)
            continue
        digest = _hash(entry / "manifest.json")[1]
        streams.setdefault(key, []).append((manifest, digest))
    groups = []
    for (source, character), snapshots in sorted(streams.items()):
        snapshots.sort(key=lambda pair: (_created(pair[0]["created_utc"]), pair[0]["snapshot_id"]), reverse=True)
        protected = [m["snapshot_id"] for m, _ in snapshots[:keep]]
        if protect_id is not None and any(m["snapshot_id"] == protect_id for m, _ in snapshots) and protect_id not in protected:
            protected.append(protect_id)
        candidates = [m["snapshot_id"] for m, _ in snapshots if m["snapshot_id"] not in protected]
        groups.append({"retention_source": source, "character_id": character, "protected_ids": protected,
                       "candidate_ids": candidates, "manifest_hashes": {m["snapshot_id"]: digest for m, digest in snapshots}})
    plan = {"schema_version": VERSION, "retention_profile": profile, "keep_count": keep,
            "streams": groups, "invalid_preserved": sorted(invalid), "unmanaged_preserved": sorted(unmanaged),
            "other_profiles_preserved": sorted(other), "action": "reversible_retirement_only"}
    plan["plan_digest"] = hashlib.sha256(json.dumps(plan, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
    return plan


def _journal(store: Path, value: dict) -> None:
    _retired_store(_safe_path(store.parent))
    target = store / "last-operation.json"
    entries = _root_entries(store)
    if target.name.casefold() in entries:
        if entries[target.name.casefold()].name != target.name:
            raise GuardianError("Unsafe retirement journal case alias")
        _check_node(target)
    temp = store / (".journal-" + uuid.uuid4().hex + ".tmp")
    try:
        with temp.open("x", encoding="utf-8") as f:
            json.dump(value, f, sort_keys=True); f.flush(); os.fsync(f.fileno())
        os.replace(temp, target)
    finally:
        if temp.exists() and not temp.is_symlink(): temp.unlink()


def _checked_plan_copy(root: Path, ident: str, group: dict, profile: str) -> dict:
    manifest = verify_snapshot(root / ident)
    if _stream(manifest, profile) != (group["retention_source"], group["character_id"]) or _hash(root / ident / "manifest.json")[1] != group["manifest_hashes"][ident]:
        raise GuardianError("Snapshot changed after retention planning")
    return manifest


def _retire_locked(root: Path, plan: dict, *, _probe) -> dict:
    result = {"status": "complete", "retired_ids": [], "plan_digest": plan["plan_digest"],
              "active_retention_only": True, "permanent_deletion": False}
    pending = [(group, ident) for group in plan["streams"] for ident in group["candidate_ids"]]
    result["remaining_ids"] = [ident for _, ident in pending]
    if not pending:
        return result
    store = None
    try:
        store = _retired_store(root, create=True)
        for group, ident in pending:
            _probe()
            if len(group["protected_ids"]) < plan["keep_count"]:
                raise GuardianError("Protected active-copy minimum is not met")
            _root_entries(root)
            for protected in group["protected_ids"]:
                _checked_plan_copy(root, protected, group, plan["retention_profile"])
            _checked_plan_copy(root, ident, group, plan["retention_profile"])
            if ident in group["protected_ids"]:
                raise GuardianError("Cannot retire a protected snapshot")
            store = _retired_store(root)
            if ident.casefold() in _root_entries(store):
                raise GuardianError("Retired snapshot identifier already exists")
            _probe()
            journal = {"owner": OWNER, "schema_version": VERSION, "operation": "retire", "plan_digest": plan["plan_digest"],
                       "protected_streams": plan["streams"], "retired_ids": list(result["retired_ids"]), "next_id": ident, "status": "in_progress"}
            _journal(store, journal)
            # Journal IO can block. Revalidate ownership, ancestors, protected
            # copies and candidate after that boundary, then probe before moving.
            _safe_path(root)
            _root_entries(root)
            store = _retired_store(root)
            for protected in group["protected_ids"]:
                _checked_plan_copy(root, protected, group, plan["retention_profile"])
            _checked_plan_copy(root, ident, group, plan["retention_profile"])
            if ident.casefold() in _root_entries(store):
                raise GuardianError("Retirement destination appeared during journal write")
            _probe()
            (root / ident).rename(store / ident)
            result["retired_ids"].append(ident)
            result["remaining_ids"].remove(ident)
            _probe()
            journal.update(retired_ids=list(result["retired_ids"]), next_id=None)
            _journal(store, journal)
        _journal(store, {"owner": OWNER, "schema_version": VERSION, "operation": "retire", **result})
    except (GuardianError, OSError) as e:
        result.update(status="stopped", error=str(e))
        # A failed journal write must not hide the reversible moves already made.
        if store is not None:
            try: _journal(store, {"owner": OWNER, "schema_version": VERSION, "operation": "retire", **result})
            except (GuardianError, OSError): pass
    return result


def _apply_locked(root: Path, profile: str, keep: int, *, confirm: str | None = None, protect_id: str | None = None, _probe=_game_closed) -> dict:
    _probe()
    plan = _profile_plan(root, profile, keep, protect_id=protect_id)
    if confirm is not None and confirm != plan["plan_digest"]:
        raise GuardianError("Retention plan changed or confirmation digest does not match")
    return _retire_locked(root, plan, _probe=_probe)


def _execute_retention(root: Path, profile: str, keep: int, *, confirm: str | None = None, protect_id: str | None = None, _probe=_game_closed) -> dict:
    with _retention_lock(root) as lock:
        result = _apply_locked(root, profile, keep, confirm=confirm, protect_id=protect_id, _probe=_probe)
    if lock["release_error"]:
        result.update(status="stopped", error="Retention lock needs manual review: " + lock["release_error"])
    return result


def retention_apply(backup_root: str | Path, retention_profile: str, keep: int, *, confirm: str, _probe=_game_closed) -> dict:
    if not isinstance(confirm, str) or not re.fullmatch(r"[0-9a-f]{64}", confirm):
        raise GuardianError("Supply the exact previewed retention plan digest")
    return _execute_retention(_safe_path(backup_root), _profile(retention_profile), _keep(keep), confirm=confirm, _probe=_probe)


def list_retired(backup_root: str | Path) -> list[dict]:
    root = _safe_path(backup_root)
    store = _retired_store(root)
    return list_snapshots(store)


def reactivate(backup_root: str | Path, snapshot_id: str, *, confirm: str, _probe=_game_closed) -> dict:
    if not isinstance(snapshot_id, str) or not ID.fullmatch(snapshot_id) or confirm != snapshot_id:
        raise GuardianError("Confirm the exact retired snapshot identifier")
    root = _safe_path(backup_root)
    with _retention_lock(root) as lock:
        _probe()
        store = _retired_store(root)
        manifest = verify_snapshot(store / snapshot_id)
        expected_manifest_hash = _hash(store / snapshot_id / "manifest.json")[1]
        if snapshot_id.casefold() in _root_entries(root):
            raise GuardianError("An active snapshot with that identifier already exists")
        _probe()
        # Recheck the owned store and copy immediately before the atomic move.
        _retired_store(root)
        verify_snapshot(store / snapshot_id)
        _probe()
        _journal(store, {"owner": OWNER, "schema_version": VERSION, "operation": "reactivate", "snapshot_id": snapshot_id, "status": "in_progress"})
        _safe_path(root)
        store = _retired_store(root)
        verify_snapshot(store / snapshot_id)
        if _hash(store / snapshot_id / "manifest.json")[1] != expected_manifest_hash:
            raise GuardianError("Retired snapshot changed during journal write")
        if snapshot_id.casefold() in _root_entries(root):
            raise GuardianError("Reactivation destination appeared during verification")
        _probe()
        (store / snapshot_id).rename(root / snapshot_id)
        result = {"status": "reactivated_hash_verified", "snapshot_id": manifest["snapshot_id"], "loadability": "unknown", "quest_progression": "unknown"}
        try: _probe()
        except (GuardianError, OSError) as e:
            result.update(status="stopped", reactivation_status="reactivated_hash_verified", process_check_error=str(e))
        try: _journal(store, {"owner": OWNER, "schema_version": VERSION, "operation": "reactivate", **result})
        except (GuardianError, OSError) as e: result["journal_error"] = str(e)
    if lock["release_error"]: result["lock_error"] = lock["release_error"]
    return result


def retention_preview(backup_root: str | Path, keep: int = 2, *, retention_profile: str | None = None) -> dict:
    _keep(keep)
    if retention_profile is not None:
        return _profile_plan(_safe_path(backup_root), _profile(retention_profile), keep)
    records = list_snapshots(backup_root)
    valid = [r["snapshot_id"] for r in records if r["status"] == "hash_verified"]
    return {"keep": valid[:keep], "older_candidates": valid[keep:], "invalid_preserved": [r["snapshot_id"] for r in records if r["status"] != "hash_verified"], "action": "preview_only_no_deletion"}


def inspect_source(save_dir: str | Path, *, _probe=_game_closed) -> dict:
    """Observe stable bytes with the game closed; this is not an engine event."""
    source = _safe_path(save_dir)
    _probe()
    started = datetime.now(timezone.utc).isoformat()
    files, directories = _scan(source)
    if not files:
        raise GuardianError("Empty source directory; select a save-slot folder")
    timestamps = {entry["path"]: _check_node(source / entry["path"]).st_mtime_ns for entry in files}
    if _scan(source) != (files, directories):
        raise GuardianError("Source changed during inspection; no stable observation available")
    if timestamps != {entry["path"]: _check_node(source / entry["path"]).st_mtime_ns for entry in files}:
        raise GuardianError("Source timestamps changed during inspection")
    _probe()
    return {"status": "stable_source_bytes_observed", "inspection_started_utc": started,
            "observed_utc": datetime.now(timezone.utc).isoformat(), "source_slot": _metadata(source.name),
            "source_fingerprint": _source_fingerprint(source),
            "files": [dict(entry, modified_ns=timestamps[entry["path"]]) for entry in files],
            "directories": directories, "bytes": sum(entry["size"] for entry in files),
            "engine_save_completion": "unknown", "guardian_request_id": "unknown",
            "loadability": "unknown", "quest_progression": "unknown", "action": "read_only_no_snapshot_created"}


def doctor(backup_root: str | Path, *, _probe=_game_closed) -> dict:
    """Read control state and capacity without repairing or creating anything."""
    root = _safe_path(backup_root)
    entries = _root_entries(root)
    result = {"status": "diagnostic_observation_only", "observed_utc": datetime.now(timezone.utc).isoformat(),
              "action": "read_only_no_repairs", "game_process_guard": "closed_at_check",
              "retention_lock": "present_manual_review_required" if LOCK in entries else "absent_at_check",
              "free_bytes": shutil.disk_usage(root).free,
              "snapshot_name_count": sum(bool(ID.fullmatch(entry.name)) for entry in entries.values()),
              "pending_stage_count": sum(entry.name.startswith(".pending-") and bool(ID.fullmatch(entry.name[9:])) for entry in entries.values()),
              "unmanaged_entry_count": sum(not ID.fullmatch(entry.name) and key not in (LOCK, RETIRED)
                                            and not (entry.name.startswith(".pending-") and ID.fullmatch(entry.name[9:]))
                                            for key, entry in entries.items()),
              "retired_store": "absent"}
    try:
        _probe()
    except (GuardianError, OSError) as e:
        result.update(game_process_guard="not_confirmed_closed", process_guard_reason=str(e))
    if RETIRED in entries:
        try:
            _retired_store(root)
            result["retired_store"] = "ownership_verified_at_check"
        except (GuardianError, OSError) as e:
            result.update(retired_store="refused", retired_store_reason=str(e))
    return result


def recovery_plan(backup_root: str | Path, *, retention_profile: str | None = None, character_id: str | None = None) -> dict:
    """Verify recovery candidates without choosing one or changing any bytes."""
    root = _safe_path(backup_root)
    if retention_profile is not None:
        retention_profile = _profile(retention_profile)
    if character_id is not None:
        character_id = _metadata(character_id)
    entries = _root_entries(root)
    if LOCK in entries:
        raise GuardianError("Retention lock present; review recovery after that operation has ended")
    locations = [("active", root)]
    if RETIRED in entries:
        locations.append(("retired", _retired_store(root)))
    candidates, invalid, excluded = [], [], 0
    for location, directory in locations:
        for entry in _root_entries(directory).values():
            if not ID.fullmatch(entry.name):
                continue
            try:
                m = verify_snapshot(entry)
            except (GuardianError, OSError):
                invalid.append({"snapshot_id": entry.name, "location": location, "status": "invalid"})
                continue
            if (retention_profile is not None and m.get("retention_profile") != retention_profile
                    or character_id is not None and m["character_id"] != character_id):
                excluded += 1
                continue
            ident = m["snapshot_id"]
            actions = ([{"command": "reactivate", "snapshot_id": ident, "confirm": ident}] if location == "retired" else [])
            actions += [{"command": "preview", "snapshot_id": ident},
                        {"command": "restore", "snapshot_id": ident, "confirm": ident,
                         "destination_requirement": "new_directory_outside_backup_root"}]
            record = {"snapshot_id": ident, "location": location,
                      "snapshot_reference": f"{RETIRED}/{ident}" if location == "retired" else ident,
                      "created_utc": m["created_utc"], "status": "hash_verified_at_inspection",
                      "source_slot": m["source_slot"], "game_build": m["game_build"], "mod_build": m["mod_build"],
                      "character_id": m["character_id"], "files": len(m["files"]), "bytes": sum(f["size"] for f in m["files"]),
                      "loadability": "unknown", "quest_progression": "unknown", "next_actions": actions}
            for key in ("retention_profile", "retention_source"):
                if key in m:
                    record[key] = m[key]
            candidates.append(record)
    if LOCK in _root_entries(root):
        raise GuardianError("Retention activity started during recovery inspection; inspect again later")
    candidates.sort(key=lambda record: (_created(record["created_utc"]), record["snapshot_id"], record["location"]), reverse=True)
    invalid.sort(key=lambda record: (record["location"], record["snapshot_id"]))
    return {"observed_utc": datetime.now(timezone.utc).isoformat(), "candidates": candidates,
            "invalid_snapshots": invalid, "excluded_by_filter": excluded,
            "identity_evidence": "user_supplied_metadata_only", "ordering": "newest_timestamp_first_not_a_loadability_rating",
            "evidence_limit": "per_snapshot_hash_observation_reverified_by_restore_not_a_locked_inventory",
            "action": "review_only_no_automatic_selection_or_restore"}


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    b = sub.add_parser("backup"); b.add_argument("--save-dir", required=True); b.add_argument("--backup-root", required=True)
    for key in ("game-build", "mod-build", "character-id"): b.add_argument("--" + key, default="unknown")
    b.add_argument("--retention-profile"); b.add_argument("--keep", type=int)
    for name in ("verify", "preview"):
        q = sub.add_parser(name); q.add_argument("--snapshot", required=True)
    q = sub.add_parser("list"); q.add_argument("--backup-root", required=True)
    q = sub.add_parser("retention-preview"); q.add_argument("--backup-root", required=True); q.add_argument("--keep", type=int, default=2)
    q.add_argument("--retention-profile")
    q = sub.add_parser("retention-apply"); q.add_argument("--backup-root", required=True); q.add_argument("--retention-profile", required=True); q.add_argument("--keep", type=int, required=True); q.add_argument("--confirm", required=True)
    q = sub.add_parser("list-retired"); q.add_argument("--backup-root", required=True)
    q = sub.add_parser("reactivate"); q.add_argument("--backup-root", required=True); q.add_argument("--snapshot-id", required=True); q.add_argument("--confirm", required=True)
    q = sub.add_parser("restore"); q.add_argument("--snapshot", required=True); q.add_argument("--destination", required=True); q.add_argument("--confirm", required=True)
    q = sub.add_parser("doctor", help="Read process, capacity and control state; never repair files"); q.add_argument("--backup-root", required=True)
    q = sub.add_parser("inspect-source", help="Observe stable closed-game source bytes; no snapshot creation"); q.add_argument("--save-dir", required=True)
    q = sub.add_parser("recovery-plan", help="Verify active and retired recovery choices without restoring"); q.add_argument("--backup-root", required=True)
    q.add_argument("--retention-profile"); q.add_argument("--character-id")
    a = p.parse_args(argv)
    try:
        if a.command == "backup": result = backup(a.save_dir, a.backup_root, game_build=a.game_build, mod_build=a.mod_build, character_id=a.character_id, retention_profile=a.retention_profile, keep=a.keep)
        elif a.command == "verify": result = {"snapshot_id": verify_snapshot(a.snapshot)["snapshot_id"], "status": "hash_verified", "loadability": "unknown"}
        elif a.command == "list": result = list_snapshots(a.backup_root)
        elif a.command == "preview": result = recovery_preview(a.snapshot)
        elif a.command == "retention-preview": result = retention_preview(a.backup_root, a.keep, retention_profile=a.retention_profile)
        elif a.command == "retention-apply": result = retention_apply(a.backup_root, a.retention_profile, a.keep, confirm=a.confirm)
        elif a.command == "list-retired": result = list_retired(a.backup_root)
        elif a.command == "reactivate": result = reactivate(a.backup_root, a.snapshot_id, confirm=a.confirm)
        elif a.command == "doctor": result = doctor(a.backup_root)
        elif a.command == "inspect-source": result = inspect_source(a.save_dir)
        elif a.command == "recovery-plan": result = recovery_plan(a.backup_root, retention_profile=a.retention_profile, character_id=a.character_id)
        else: result = restore(a.snapshot, a.destination, confirm=a.confirm)
        print(json.dumps(result, indent=2))
        return 2 if a.command in ("retention-apply", "reactivate") and result.get("status") == "stopped" else 0
    except (GuardianError, OSError) as e:
        print("Save Guardian: " + str(e), file=sys.stderr); return 1


if __name__ == "__main__":
    raise SystemExit(main())
