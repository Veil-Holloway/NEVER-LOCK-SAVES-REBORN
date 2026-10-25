"""Real filesystem regression tests; process status is a controlled OS boundary.

No game, actual Windows tasklist, save loadability or quest progress is tested.
"""
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
from types import SimpleNamespace as Obj
import unittest
from unittest import mock

import save_guardian as g


class GuardianTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.slot = self.home / "slot"
        self.slot.mkdir()
        (self.slot / "sav.dat").write_bytes(b"disposable fixture save\x00\xff")
        (self.slot / "metadata.json").write_text('{"fixture":true}')
        (self.slot / "empty").mkdir()
        self.root = self.home / "backups"
        self.probe = mock.Mock()

    def make(self, **kwargs):
        return g.backup(self.slot, self.root, _probe=self.probe, **kwargs)

    def snapshot(self, m):
        return self.root / m["snapshot_id"]

    def change_manifest(self, path, mutate):
        file = path / "manifest.json"
        m = json.loads(file.read_text()); mutate(m); file.write_text(json.dumps(m))

    def assert_unpublished(self):
        self.assertTrue(not self.root.exists() or not list(self.root.iterdir()))

    def test_backup_matches_source_and_preserves_original(self):
        before = g._scan(self.slot)
        m = self.make()
        self.assertEqual(g._scan(self.snapshot(m) / "data"), before)
        self.assertEqual(g._scan(self.slot), before)
        self.assertEqual(g.verify_snapshot(self.snapshot(m)), m)
        self.assertEqual(self.probe.call_count, 4)
        self.assertEqual(m["loadability"], "unknown")
        self.assertEqual(m["quest_progression"], "unknown")
        self.assertEqual(m["game_build"], "unknown")

    def test_metadata_is_explicit_not_inferred(self):
        m = self.make(game_build="fixture-build", mod_build="0.11-preview", character_id="fixture-character")
        self.assertEqual(m["character_id"], "fixture-character")
        self.assertEqual(m["mod_build"], "0.11-preview")
        self.assertNotIn(str(self.home), json.dumps(m))

    def test_no_cli_game_guard_bypass(self):
        with mock.patch.object(g, "backup") as call:
            with self.assertRaises(SystemExit):
                g.main(["backup", "--save-dir", str(self.slot), "--backup-root", str(self.root), "--ignore-game"])
            call.assert_not_called()

    def test_game_status_unknown_does_not_write(self):
        with self.assertRaises(g.GuardianError):
            g.backup(self.slot, self.root, _probe=mock.Mock(side_effect=g.GuardianError("unknown")))
        self.assert_unpublished()

    def test_game_reopens_after_copy_no_publish(self):
        for fail_at in (2, 3):
            with self.subTest(fail_at=fail_at):
                calls = [None] * (fail_at - 1) + [g.GuardianError("game running")]
                with self.assertRaises(g.GuardianError):
                    g.backup(self.slot, self.root, _probe=mock.Mock(side_effect=calls))
                self.assert_unpublished()

    def test_overlap_both_directions_and_same(self):
        for root in (self.slot, self.slot / "backups", self.home):
            with self.subTest(root=root), self.assertRaises(g.GuardianError):
                g.backup(self.slot, root, _probe=self.probe)
        self.probe.assert_not_called()

    def test_empty_slot_refused(self):
        empty = self.home / "empty-slot"; empty.mkdir()
        with self.assertRaises(g.GuardianError):
            g.backup(empty, self.root, _probe=self.probe)
        self.assert_unpublished()

    def test_source_symlink_file_refused(self):
        try:
            (self.slot / "linked").symlink_to(self.slot / "sav.dat")
        except OSError:
            self.skipTest("symlinks unavailable")
        with self.assertRaises(g.GuardianError): self.make()
        self.assert_unpublished()

    def test_source_symlink_directory_refused(self):
        try:
            (self.slot / "linked").symlink_to(self.slot / "empty", target_is_directory=True)
        except OSError:
            self.skipTest("symlinks unavailable")
        with self.assertRaises(g.GuardianError): self.make()

    def test_symlink_ancestor_refused(self):
        link = self.home / "link"
        try: link.symlink_to(self.slot, target_is_directory=True)
        except OSError: self.skipTest("symlinks unavailable")
        with self.assertRaises(g.GuardianError):
            g.backup(link, self.root, _probe=self.probe)

    def test_reparse_attribute_refused(self):
        with mock.patch.object(Path, "lstat", return_value=Obj(st_mode=stat.S_IFDIR, st_file_attributes=0x400)):
            with self.assertRaises(g.GuardianError): g._check_node(self.slot)

    def test_source_change_during_copy_aborts(self):
        original = g._copy_tree
        def changing(*args):
            original(*args)
            (self.slot / "sav.dat").write_bytes(b"changed after copy")
        with mock.patch.object(g, "_copy_tree", side_effect=changing):
            with self.assertRaises(g.GuardianError): self.make()
        self.assert_unpublished()

    def test_source_inventory_change_aborts(self):
        original = g._copy_tree
        def changing(*args):
            original(*args); (self.slot / "new.dat").write_bytes(b"new")
        with mock.patch.object(g, "_copy_tree", side_effect=changing):
            with self.assertRaises(g.GuardianError): self.make()
        self.assert_unpublished()

    def test_copy_fault_cleans_unpublished_stage(self):
        with mock.patch.object(g, "_copy_tree", side_effect=OSError("injected copy failure")):
            with self.assertRaises(OSError): self.make()
        self.assert_unpublished()
        self.assertTrue((self.slot / "sav.dat").is_file())

    def test_low_capacity_refused(self):
        with mock.patch.object(g.shutil, "disk_usage", return_value=Obj(free=0)):
            with self.assertRaises(g.GuardianError): self.make()
        self.assert_unpublished()

    def test_file_directory_size_depth_bounds(self):
        for name, value in (("MAX_FILES", 1), ("MAX_DIRS", 0), ("MAX_BYTES", 1)):
            with self.subTest(limit=name), mock.patch.object(g, name, value):
                with self.assertRaises(g.GuardianError): self.make()
        (self.slot / "empty" / "deep").mkdir()
        with mock.patch.object(g, "MAX_DEPTH", 1):
            with self.assertRaises(g.GuardianError): self.make()

    def test_case_collision_refused(self):
        (self.slot / "CASE").write_bytes(b"a")
        (self.slot / "case").write_bytes(b"b")
        if len([x for x in self.slot.iterdir() if x.name.casefold() == "case"]) < 2:
            self.skipTest("case-insensitive filesystem")
        with self.assertRaises(g.GuardianError): self.make()

    def test_hash_corruption_detected(self):
        m = self.make(); snap = self.snapshot(m)
        (snap / "data" / "sav.dat").write_bytes(b"corrupt")
        with self.assertRaises(g.GuardianError): g.verify_snapshot(snap)
        self.assertEqual(g.list_snapshots(self.root)[0]["status"], "invalid")

    def test_manifest_traversal_and_windows_names_rejected(self):
        m = self.make(); snap = self.snapshot(m)
        original = (snap / "manifest.json").read_text()
        for value in ("../sav.dat", "/outside", "a/../outside", "a\\outside", "C:outside", "NUL", "folder./sav.dat", "a//b"):
            with self.subTest(path=value):
                (snap / "manifest.json").write_text(original)
                self.change_manifest(snap, lambda data: data["files"][0].update(path=value))
                with self.assertRaises(g.GuardianError): g.verify_snapshot(snap)

    def test_manifest_ownership_schema_id_rejected(self):
        m = self.make(); snap = self.snapshot(m)
        original = (snap / "manifest.json").read_text()
        for key, value in (("owner", "different"), ("schema_version", 999), ("snapshot_id", "0" * 32), ("created_utc", "not-a-date")):
            with self.subTest(field=key):
                (snap / "manifest.json").write_text(original)
                self.change_manifest(snap, lambda data: data.update({key: value}))
                with self.assertRaises(g.GuardianError): g.verify_snapshot(snap)

    def test_manifest_duplicate_path_rejected(self):
        m = self.make(); snap = self.snapshot(m)
        self.change_manifest(snap, lambda data: data["files"].append(data["files"][0]))
        with self.assertRaises(g.GuardianError): g.verify_snapshot(snap)

    def test_extra_snapshot_content_rejected(self):
        m = self.make(); snap = self.snapshot(m)
        (snap / "extra").write_bytes(b"unexpected")
        with self.assertRaises(g.GuardianError): g.verify_snapshot(snap)

    def test_manifest_capacity_rejected(self):
        m = self.make(); snap = self.snapshot(m)
        with mock.patch.object(g, "MAX_MANIFEST", 10):
            with self.assertRaises(g.GuardianError): g.verify_snapshot(snap)

    def test_preview_and_restore_match_without_touching_source(self):
        m = self.make(); snap = self.snapshot(m); before = g._scan(self.slot)
        view = g.recovery_preview(snap)
        self.assertEqual(view["snapshot_id"], m["snapshot_id"])
        self.assertEqual(view["loadability"], "unknown")
        self.probe.reset_mock()
        dest = self.home / "recovered-slot"
        result = g.restore(snap, dest, confirm=m["snapshot_id"], _probe=self.probe)
        self.assertEqual(g._scan(dest), before)
        self.assertEqual(g._scan(self.slot), before)
        self.assertEqual(self.probe.call_count, 3)
        self.assertEqual(result["loadability"], "unknown")

    def test_restore_requires_confirmation_and_new_directory(self):
        m = self.make(); snap = self.snapshot(m)
        for destination, confirm in ((self.home / "new", "wrong"), (self.slot, m["snapshot_id"]), (self.root / "new", m["snapshot_id"])):
            with self.subTest(destination=destination), self.assertRaises(g.GuardianError):
                g.restore(snap, destination, confirm=confirm, _probe=self.probe)

    def test_restore_game_reopens_no_publish(self):
        m = self.make(); snap = self.snapshot(m); dest = self.home / "recovered"
        with self.assertRaises(g.GuardianError):
            g.restore(snap, dest, confirm=m["snapshot_id"], _probe=mock.Mock(side_effect=[None, g.GuardianError("game reopened")]))
        self.assertFalse(dest.exists())
        self.assertFalse(list(self.home.glob(".guardian-restore-*")))

    def test_restore_source_changes_aborts(self):
        m = self.make(); snap = self.snapshot(m); dest = self.home / "recovered"
        original = g._copy_tree
        def changing(*args):
            original(*args); (snap / "data" / "sav.dat").write_bytes(b"changed")
        with mock.patch.object(g, "_copy_tree", side_effect=changing):
            with self.assertRaises(g.GuardianError):
                g.restore(snap, dest, confirm=m["snapshot_id"], _probe=self.probe)
        self.assertFalse(dest.exists())

    def test_retention_preview_preserves_every_copy(self):
        ids = [self.make()["snapshot_id"] for _ in range(3)]
        plan = g.retention_preview(self.root, keep=2)
        self.assertEqual(len(plan["keep"]), 2)
        self.assertEqual(len(plan["older_candidates"]), 1)
        self.assertEqual(plan["action"], "preview_only_no_deletion")
        self.assertEqual({p.name for p in self.root.iterdir()}, set(ids))
        with self.assertRaises(g.GuardianError): g.retention_preview(self.root, keep=1)

    def test_parent_traversal_refused(self):
        with self.assertRaises(g.GuardianError):
            g.backup(self.slot / ".." / "slot", self.root, _probe=self.probe)

    def test_metadata_controls_and_capacity_refused(self):
        for value in ("bad\nvalue", "x" * 129):
            with self.subTest(value=value), self.assertRaises(g.GuardianError):
                self.make(character_id=value)


class ProcessGuardTests(unittest.TestCase):
    def inventory(self, text, code=0):
        return mock.patch.object(g.subprocess, "run", return_value=Obj(returncode=code, stdout=text))

    def test_non_windows_fails_closed(self):
        with mock.patch.object(g.os, "name", "posix"):
            with self.assertRaises(g.GuardianError): g._game_closed()

    def test_game_running_refused(self):
        with mock.patch.object(g.os, "name", "nt"), self.inventory('"Cyberpunk2077.exe","123","Console","1","10,000 K"\n'):
            with self.assertRaises(g.GuardianError): g._game_closed()

    def test_verified_standard_inventory_allows_absent_game(self):
        with mock.patch.object(g.os, "name", "nt"), self.inventory('"explorer.exe","123","Console","1","10,000 K"\n'):
            g._game_closed()

    def test_empty_malformed_error_inventories_fail_closed(self):
        for text, code in (("", 0), ("ERROR: denied", 0), ('"explorer.exe","not-pid","x","x","x"', 0), ('"explorer.exe","123","x","x","x"', 1)):
            with self.subTest(text=text), mock.patch.object(g.os, "name", "nt"), self.inventory(text, code):
                with self.assertRaises(g.GuardianError): g._game_closed()

    def test_timeout_fails_closed(self):
        with mock.patch.object(g.os, "name", "nt"), mock.patch.object(g.subprocess, "run", side_effect=subprocess.TimeoutExpired("tasklist", 15)):
            with self.assertRaises(g.GuardianError): g._game_closed()


if __name__ == "__main__":
    unittest.main()
