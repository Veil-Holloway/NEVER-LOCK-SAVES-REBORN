"""Reversible retention tests: real temporary files, controlled process/IO faults."""
import json
from pathlib import Path
from types import SimpleNamespace as Obj
import unittest
from unittest import mock

import save_guardian as g
import test_save_guardian as original


class RetentionTests(unittest.TestCase):
    setUp = original.GuardianTests.setUp
    make = original.GuardianTests.make
    snapshot = original.GuardianTests.snapshot
    change_manifest = original.GuardianTests.change_manifest

    def managed(self, profile="main", keep=100, *, source=None, character="unknown"):
        return g.backup(source or self.slot, self.root, retention_profile=profile, keep=keep,
                        character_id=character, _probe=self.probe)

    def seed(self, count=4, profile="main"):
        return [self.managed(profile)["snapshot_id"] for _ in range(count)]

    def plan(self, profile="main", keep=2):
        return g.retention_preview(self.root, keep, retention_profile=profile)

    def apply(self, plan=None, *, probe=None):
        plan = plan or self.plan()
        return g.retention_apply(self.root, plan["retention_profile"], plan["keep_count"],
                                 confirm=plan["plan_digest"], _probe=probe or self.probe)

    def active(self):
        return {r["snapshot_id"] for r in g.list_snapshots(self.root) if r["status"] == "hash_verified"}

    def test_profile_keep_pair_and_minimum_before_writes(self):
        for options in ({"retention_profile": "main"}, {"keep": 2}, {"retention_profile": "main", "keep": 1},
                        {"retention_profile": "../escape", "keep": 2}, {"retention_profile": "x" * 65, "keep": 2}):
            with self.subTest(options=options), self.assertRaises(g.GuardianError):
                g.backup(self.slot, self.root, _probe=self.probe, **options)
            self.assertFalse(self.root.exists())
        self.probe.assert_not_called()

    def test_automatic_rotation_keeps_two_and_preserves_every_copy(self):
        ids = [self.managed(keep=2)["snapshot_id"] for _ in range(3)]
        self.assertEqual(self.active(), set(ids[-2:]))
        retired = g.list_retired(self.root)
        self.assertEqual([r["snapshot_id"] for r in retired], ids[:1])
        m = g.verify_snapshot(self.root / g.RETIRED / ids[0])
        self.assertEqual(m["retention_profile"], "main")
        self.assertEqual(m["retention_source"], g._source_fingerprint(self.slot.resolve()))
        self.assertNotIn(str(self.slot), json.dumps(m))
        self.assertEqual({f.name for f in (self.root / g.RETIRED / ids[0]).iterdir()}, {"data", "manifest.json"})
        self.assertFalse((self.root / g.LOCK).exists())

    def test_legacy_old_profile_wrong_profile_invalid_preserved(self):
        legacy = self.make()["snapshot_id"]
        old_profile = self.make()["snapshot_id"]
        self.change_manifest(self.root / old_profile, lambda m: m.update(retention_profile="main"))
        wrong = self.managed("other")["snapshot_id"]
        bad = self.managed()["snapshot_id"]
        (self.root / bad / "data/sav.dat").write_bytes(b"corrupt")
        ids = self.seed(3)
        plan = self.plan()
        self.assertIn(legacy, plan["unmanaged_preserved"])
        self.assertIn(old_profile, plan["unmanaged_preserved"])
        self.assertIn(wrong, plan["other_profiles_preserved"])
        self.assertIn(bad, plan["invalid_preserved"])
        result = self.apply(plan)
        self.assertEqual(result["status"], "complete")
        self.assertEqual(set(result["retired_ids"]), {ids[0]})
        for ident in (legacy, old_profile, wrong, bad): self.assertTrue((self.root / ident).exists())

    def test_same_basename_distinct_directories_and_characters_are_streams(self):
        other = self.home / "elsewhere/slot"; other.mkdir(parents=True)
        (other / "sav.dat").write_bytes(b"different slot")
        a = [self.managed(source=self.slot, character="A")["snapshot_id"] for _ in range(3)]
        b = [self.managed(source=other, character="A")["snapshot_id"] for _ in range(3)]
        c = [self.managed(source=self.slot, character="B")["snapshot_id"] for _ in range(3)]
        plan = self.plan()
        self.assertEqual(len(plan["streams"]), 3)
        result = self.apply(plan)
        self.assertEqual(set(result["retired_ids"]), {a[0], b[0], c[0]})
        self.assertEqual(self.active(), set(a[1:] + b[1:] + c[1:]))

    def test_chronology_uses_utc_not_iso_lexicographic_order(self):
        ids = self.seed(3)
        times = ["2026-10-23T13:00:00-07:00", "2026-10-23T19:30:00+00:00", "2026-10-23T20:15:00+01:00"]
        for ident, time in zip(ids, times): self.change_manifest(self.root / ident, lambda m, time=time: m.update(created_utc=time))
        plan = self.plan()
        self.assertEqual(plan["streams"][0]["protected_ids"], ids[:2])
        self.assertEqual(plan["streams"][0]["candidate_ids"], ids[2:])
        self.assertEqual([r["snapshot_id"] for r in g.list_snapshots(self.root)], ids)

    def test_overflow_chronology_is_invalid_preserved(self):
        ids = self.seed(3)
        self.change_manifest(self.root / ids[0], lambda m: m.update(created_utc="0001-01-01T00:00:00+14:00"))
        plan = self.plan()
        self.assertIn(ids[0], plan["invalid_preserved"])
        result = self.apply(plan)
        self.assertEqual(result["retired_ids"], [])
        self.assertTrue((self.root / ids[0]).is_dir())

    def test_new_snapshot_is_additionally_protected_during_clock_skew(self):
        ids = self.seed(2)
        for ident in ids: self.change_manifest(self.root / ident, lambda m: m.update(created_utc="2099-01-01T00:00:00+00:00"))
        result = self.managed(keep=2)
        self.assertEqual(result["backup_status"], "published_hash_verified")
        self.assertEqual(result["rotation"]["retired_ids"], [])
        self.assertEqual(self.active(), set(ids + [result["snapshot_id"]]))

    def test_confirmation_digest_refuses_changed_plan(self):
        self.seed(3); plan = self.plan(); self.managed()
        with self.assertRaises(g.GuardianError): self.apply(plan)
        self.assertEqual(len(self.active()), 4)
        with self.assertRaises(g.GuardianError):
            g.retention_apply(self.root, "main", 2, confirm="not-a-digest", _probe=self.probe)

    def test_exclusive_lock_spans_profiled_copy_and_rejects_nested_operation(self):
        original_copy = g._copy_tree
        def copy(*args):
            self.assertTrue((self.root / g.LOCK).is_file())
            with self.assertRaises(g.GuardianError):
                g.retention_apply(self.root, "main", 2, confirm="0" * 64, _probe=self.probe)
            original_copy(*args)
        with mock.patch.object(g, "_copy_tree", side_effect=copy): result = self.managed(keep=2)
        self.assertEqual(result["backup_status"], "published_hash_verified")
        self.assertFalse((self.root / g.LOCK).exists())

    def test_existing_lock_is_not_stolen(self):
        self.seed(3); (self.root / g.LOCK).write_text("existing lock")
        with self.assertRaises(g.GuardianError): self.apply()
        with self.assertRaises(g.GuardianError): self.managed(keep=2)
        self.assertEqual((self.root / g.LOCK).read_text(), "existing lock")
        self.assertEqual(len(self.active()), 3)

    def test_second_move_failure_reports_reversible_partial(self):
        self.seed(4); plan = self.plan(); candidates = plan["streams"][0]["candidate_ids"]
        original_rename = Path.rename
        def rename(path, target):
            if path.name == candidates[1] and path.parent == self.root: raise OSError("injected second move failure")
            return original_rename(path, target)
        with mock.patch.object(Path, "rename", rename): result = self.apply(plan)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["retired_ids"], candidates[:1])
        self.assertEqual(result["remaining_ids"], candidates[1:])
        self.assertEqual(len(self.active()), 3)
        self.assertTrue((self.root / g.RETIRED / candidates[0]).is_dir())
        self.assertTrue((self.root / candidates[1]).is_dir())

    def test_automatic_rotation_failure_does_not_report_backup_failure(self):
        self.seed(2)
        with mock.patch.object(g, "_journal", side_effect=OSError("journal fault")): result = self.managed(keep=2)
        self.assertEqual(result["backup_status"], "published_hash_verified")
        self.assertEqual(result["rotation"]["status"], "stopped")
        self.assertEqual(len(self.active()), 3)
        g.verify_snapshot(self.root / result["snapshot_id"])

    def test_game_unknown_after_publication_preserves_new_snapshot(self):
        self.seed(2)
        probe = mock.Mock(side_effect=[None, None, None, None, g.GuardianError("unknown process state")])
        result = g.backup(self.slot, self.root, retention_profile="main", keep=2, _probe=probe)
        self.assertEqual(result["backup_status"], "published_hash_verified")
        self.assertEqual(result["rotation"]["status"], "stopped")
        self.assertEqual(len(self.active()), 3)

    def test_game_reopens_during_journal_stops_before_move(self):
        self.seed(3); plan = self.plan(); opened = False; original_journal = g._journal
        def journal(*args):
            nonlocal opened
            original_journal(*args); opened = True
        def probe():
            if opened: raise g.GuardianError("game reopened")
        with mock.patch.object(g, "_journal", side_effect=journal): result = self.apply(plan, probe=probe)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["retired_ids"], [])
        self.assertEqual(len(self.active()), 3)

    def test_store_symlink_swap_during_journal_never_moves_outside(self):
        self.seed(3); plan = self.plan(); original_journal = g._journal; swapped = False
        outside = self.home / "outside"; outside.mkdir()
        def journal(store, value):
            nonlocal swapped
            original_journal(store, value)
            if not swapped:
                swapped = True; store.rename(self.root / ".retired-original")
                try: store.symlink_to(outside, target_is_directory=True)
                except OSError: self.skipTest("symlink unavailable")
        with mock.patch.object(g, "_journal", side_effect=journal): result = self.apply(plan)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["retired_ids"], [])
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(len(self.active()), 3)

    def test_protected_payload_change_during_journal_stops_before_move(self):
        self.seed(3); plan = self.plan(); protected = plan["streams"][0]["protected_ids"][0]
        original_journal = g._journal; changed = False
        def journal(*args):
            nonlocal changed
            original_journal(*args)
            if not changed:
                changed = True; (self.root / protected / "data/sav.dat").write_bytes(b"corrupted during journal")
        with mock.patch.object(g, "_journal", side_effect=journal): result = self.apply(plan)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["retired_ids"], [])
        self.assertEqual(len(self.active()), 2)

    def test_post_move_game_reopen_reports_completed_move_without_rollback(self):
        self.seed(3); plan = self.plan(); candidate = plan["streams"][0]["candidate_ids"][0]
        def probe():
            if (self.root / g.RETIRED / candidate).exists(): raise g.GuardianError("game reopened after move")
        result = self.apply(plan, probe=probe)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["retired_ids"], [candidate])
        self.assertEqual(result["remaining_ids"], [])
        self.assertEqual(len(self.active()), 2)

    def test_retired_store_ownership_marker_schema_and_case_alias_refused(self):
        self.seed(3); plan = self.plan()
        store = self.root / g.RETIRED; store.mkdir()
        self.assertEqual(self.apply(plan)["status"], "stopped")
        (store / g.RETIRED_MARKER).write_text(json.dumps({"owner": g.OWNER, "schema_version": True, "purpose": "reversible_retirement"}))
        self.assertEqual(self.apply(plan)["status"], "stopped")
        (store / g.RETIRED_MARKER).write_text(json.dumps({"owner": g.OWNER, "schema_version": 1, "purpose": "reversible_retirement"}))
        store.rename(self.root / ".RETIRED")
        self.assertEqual(self.apply(plan)["status"], "stopped")
        self.assertEqual(len(self.active()), 3)

    def test_cross_filesystem_retirement_refused_without_copy_fallback(self):
        self.seed(3); plan = self.plan(); real_check = g._check_node
        def checked(path):
            value = real_check(path)
            return Obj(st_dev=value.st_dev + 1) if Path(path) == self.root / g.RETIRED else value
        with mock.patch.object(g, "_check_node", side_effect=checked): result = self.apply(plan)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["retired_ids"], [])
        self.assertEqual(len(self.active()), 3)

    def test_retired_destination_conflict_and_root_case_collision_refused(self):
        self.seed(3); plan = self.plan(); ident = plan["streams"][0]["candidate_ids"][0]
        store = g._retired_store(self.root, create=True); (store / ident.upper()).mkdir()
        self.assertEqual(self.apply(plan)["status"], "stopped")
        (self.root / ident.upper()).mkdir()
        with self.assertRaises(g.GuardianError): self.plan()

    def test_retired_copy_needs_reactivation_then_external_restore(self):
        self.seed(3); result = self.apply(); ident = result["retired_ids"][0]
        snap = self.root / g.RETIRED / ident
        self.assertEqual(g.recovery_preview(snap)["snapshot_id"], ident)
        for destination in (self.root / "NewFolder", self.home / "recovered"):
            with self.assertRaises(g.GuardianError):
                g.restore(snap, destination, confirm=ident, _probe=self.probe)
        reactivated = g.reactivate(self.root, ident, confirm=ident, _probe=self.probe)
        self.assertEqual(reactivated["status"], "reactivated_hash_verified")
        self.assertFalse(snap.exists())
        self.assertIn(ident, self.active())
        restored = self.home / "recovered"
        g.restore(self.root / ident, restored, confirm=ident, _probe=self.probe)
        self.assertEqual(g._scan(restored), g._scan(self.slot))

    def test_reactivate_rejects_corruption_collision_and_wrong_confirmation(self):
        self.seed(3); ident = self.apply()["retired_ids"][0]
        with self.assertRaises(g.GuardianError): g.reactivate(self.root, ident, confirm="wrong", _probe=self.probe)
        (self.root / ident).mkdir()
        with self.assertRaises(g.GuardianError): g.reactivate(self.root, ident, confirm=ident, _probe=self.probe)
        (self.root / ident).rmdir()
        (self.root / g.RETIRED / ident / "data/sav.dat").write_bytes(b"bad")
        with self.assertRaises(g.GuardianError): g.reactivate(self.root, ident, confirm=ident, _probe=self.probe)

    def test_reactivate_revalidates_store_after_journal(self):
        self.seed(3); ident = self.apply()["retired_ids"][0]
        original_journal = g._journal; changed = False
        def journal(store, value):
            nonlocal changed
            original_journal(store, value)
            if not changed:
                changed = True
                self.change_manifest(store / ident, lambda m: m.update(character_id="different character"))
        with mock.patch.object(g, "_journal", side_effect=journal):
            with self.assertRaises(g.GuardianError): g.reactivate(self.root, ident, confirm=ident, _probe=self.probe)
        self.assertTrue((self.root / g.RETIRED / ident).exists())
        self.assertNotIn(ident, self.active())

    def test_reactivate_post_move_game_reopen_reports_actual_result(self):
        self.seed(3); ident = self.apply()["retired_ids"][0]
        def probe():
            if (self.root / ident).exists(): raise g.GuardianError("game reopened after reactivation")
        result = g.reactivate(self.root, ident, confirm=ident, _probe=probe)
        self.assertEqual(result["status"], "stopped")
        self.assertEqual(result["reactivation_status"], "reactivated_hash_verified")
        self.assertIn(ident, self.active())

    def test_unprofiled_existing_behavior_and_source_save_bytes_unchanged(self):
        before = g._scan(self.slot)
        old = self.make()
        self.assertNotIn("retention_profile", old)
        self.assertNotIn("rotation", old)
        self.assertEqual(g.verify_snapshot(self.snapshot(old)), old)
        plan = g.retention_preview(self.root, 2)
        self.assertEqual(plan["action"], "preview_only_no_deletion")
        self.seed(3); self.apply()
        self.assertEqual(g._scan(self.slot), before)


if __name__ == "__main__":
    unittest.main()
