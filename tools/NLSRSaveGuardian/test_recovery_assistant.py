"""Read-only recovery assistant tests using real disposable filesystem bytes."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import save_guardian as g


class RecoveryAssistantTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.slot = self.home / "slot"
        self.slot.mkdir()
        (self.slot / "sav.dat").write_bytes(b"disposable-test-save\x00\xff")
        self.root = self.home / "backups"
        self.root.mkdir()
        self.probe = mock.Mock()

    def make(self, **kwargs):
        return g.backup(self.slot, self.root, _probe=self.probe, **kwargs)

    def tree_bytes(self):
        return {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}

    def test_inspect_source_hashes_and_timestamps_without_writes(self):
        before = self.tree_bytes()
        r = g.inspect_source(self.slot, _probe=self.probe)
        self.assertEqual(r["status"], "stable_source_bytes_observed")
        self.assertEqual(r["files"][0]["sha256"], hashlib.sha256((self.slot / "sav.dat").read_bytes()).hexdigest())
        self.assertEqual(r["files"][0]["modified_ns"], (self.slot / "sav.dat").stat().st_mtime_ns)
        self.assertEqual(r["engine_save_completion"], "unknown")
        self.assertEqual(r["guardian_request_id"], "unknown")
        self.assertEqual(r["loadability"], "unknown")
        self.assertEqual(r["quest_progression"], "unknown")
        self.assertNotIn(str(self.home), json.dumps(r))
        self.assertEqual(self.tree_bytes(), before)

    def test_inspect_source_requires_closed_game_before_scanning(self):
        with mock.patch.object(g, "_scan") as scan:
            with self.assertRaises(g.GuardianError):
                g.inspect_source(self.slot, _probe=mock.Mock(side_effect=g.GuardianError("unknown")))
            scan.assert_not_called()

    def test_inspect_rejects_game_reopen_after_observation(self):
        with self.assertRaises(g.GuardianError):
            g.inspect_source(self.slot, _probe=mock.Mock(side_effect=[None, g.GuardianError("running")]))

    def test_inspect_rejects_source_mutation_between_observations(self):
        scan = g._scan
        count = 0
        def changing(root):
            nonlocal count
            count += 1
            if count == 2:
                (self.slot / "sav.dat").write_bytes(b"changed")
            return scan(root)
        with mock.patch.object(g, "_scan", side_effect=changing):
            with self.assertRaises(g.GuardianError): g.inspect_source(self.slot, _probe=self.probe)

    def test_inspect_rejects_empty_or_symlink_source(self):
        empty = self.home / "empty"; empty.mkdir()
        with self.assertRaises(g.GuardianError): g.inspect_source(empty, _probe=self.probe)
        link = self.home / "linked"
        try: link.symlink_to(self.slot, target_is_directory=True)
        except OSError: self.skipTest("symlinks unavailable")
        with self.assertRaises(g.GuardianError): g.inspect_source(link, _probe=self.probe)

    def test_inspect_rejects_timestamp_only_mutation_after_second_scan(self):
        scan = g._scan
        count = 0
        def retimed(root):
            nonlocal count
            count += 1
            result = scan(root)
            if count == 2:
                path = self.slot / "sav.dat"
                observed = path.stat()
                os.utime(path, ns=(observed.st_atime_ns, observed.st_mtime_ns + 1_000_000_000))
            return result
        before = (self.slot / "sav.dat").read_bytes()
        with mock.patch.object(g, "_scan", side_effect=retimed):
            with self.assertRaises(g.GuardianError): g.inspect_source(self.slot, _probe=self.probe)
        self.assertEqual((self.slot / "sav.dat").read_bytes(), before)

    def test_doctor_reports_lock_and_pending_without_changing_either(self):
        (self.root / g.LOCK).write_text("do not touch")
        (self.root / (".pending-" + "a" * 32)).mkdir()
        (self.root / "user-file.txt").write_text("keep")
        before = self.tree_bytes()
        r = g.doctor(self.root, _probe=self.probe)
        self.assertEqual(r["game_process_guard"], "closed_at_check")
        self.assertEqual(r["retention_lock"], "present_manual_review_required")
        self.assertEqual(r["pending_stage_count"], 1)
        self.assertEqual(r["unmanaged_entry_count"], 1)
        self.assertGreaterEqual(r["free_bytes"], 0)
        self.assertEqual(self.tree_bytes(), before)

    def test_doctor_unknown_game_is_reported_not_bypassed(self):
        r = g.doctor(self.root, _probe=mock.Mock(side_effect=g.GuardianError("Windows unavailable")))
        self.assertEqual(r["game_process_guard"], "not_confirmed_closed")
        self.assertIn("Windows unavailable", r["process_guard_reason"])
        self.assertEqual(r["action"], "read_only_no_repairs")

    def test_doctor_missing_root_does_not_create(self):
        missing = self.home / "missing"
        with self.assertRaises((g.GuardianError, OSError)): g.doctor(missing, _probe=self.probe)
        self.assertFalse(missing.exists())

    def test_doctor_unowned_retired_store_is_reported(self):
        (self.root / g.RETIRED).mkdir()
        before = self.tree_bytes()
        r = g.doctor(self.root, _probe=self.probe)
        self.assertEqual(r["retired_store"], "refused")
        self.assertEqual(self.tree_bytes(), before)

    def test_recovery_plan_active_retired_invalid_order_and_safe_steps(self):
        manifests = [self.make(retention_profile="Main", keep=2, character_id="V") for _ in range(3)]
        bad = self.root / ("f" * 32); bad.mkdir()
        before = self.tree_bytes()
        r = g.recovery_plan(self.root)
        self.assertEqual(len(r["candidates"]), 3)
        self.assertEqual(r["invalid_snapshots"], [{"snapshot_id": "f" * 32, "location": "active", "status": "invalid"}])
        retired = [c for c in r["candidates"] if c["location"] == "retired"]
        self.assertEqual(len(retired), 1)
        self.assertEqual(retired[0]["next_actions"][0]["command"], "reactivate")
        self.assertEqual(retired[0]["next_actions"][0]["confirm"], retired[0]["snapshot_id"])
        active = [c for c in r["candidates"] if c["location"] == "active"]
        self.assertEqual(active[0]["next_actions"][0]["command"], "preview")
        for c in r["candidates"]:
            self.assertEqual(c["loadability"], "unknown")
            self.assertEqual(c["quest_progression"], "unknown")
            self.assertEqual(c["next_actions"][-1]["destination_requirement"], "new_directory_outside_backup_root")
            self.assertEqual(c["next_actions"][-1]["confirm"], c["snapshot_id"])
        self.assertEqual(self.tree_bytes(), before)

    def test_recovery_plan_exact_metadata_filters_and_no_auto_selection(self):
        self.make(retention_profile="Main", keep=2, character_id="V")
        self.make(retention_profile="Other", keep=2, character_id="V")
        self.make(retention_profile="Main", keep=2, character_id="Other V")
        r = g.recovery_plan(self.root, retention_profile="Main", character_id="V")
        self.assertEqual(len(r["candidates"]), 1)
        self.assertEqual(r["excluded_by_filter"], 2)
        self.assertEqual(r["identity_evidence"], "user_supplied_metadata_only")
        self.assertEqual(r["action"], "review_only_no_automatic_selection_or_restore")
        self.assertEqual(r["candidates"][0]["retention_profile"], "Main")

    def test_recovery_plan_rejects_unowned_store_without_following_it(self):
        (self.root / g.RETIRED).mkdir()
        with self.assertRaises(g.GuardianError): g.recovery_plan(self.root)

    def test_recovery_plan_refuses_lock_before_or_during_inspection(self):
        self.make()
        lock = self.root / g.LOCK
        lock.write_text("held")
        before = self.tree_bytes()
        with mock.patch.object(g, "verify_snapshot") as verify:
            with self.assertRaises(g.GuardianError): g.recovery_plan(self.root)
            verify.assert_not_called()
        self.assertEqual(self.tree_bytes(), before)
        lock.unlink()
        verify = g.verify_snapshot
        def acquired(path):
            value = verify(path)
            lock.write_text("newly held")
            return value
        with mock.patch.object(g, "verify_snapshot", side_effect=acquired):
            with self.assertRaises(g.GuardianError): g.recovery_plan(self.root)
        self.assertEqual(lock.read_text(), "newly held")

    def test_recovery_plan_refuses_root_symlink_and_case_collisions(self):
        link = self.home / "linked"
        try: link.symlink_to(self.root, target_is_directory=True)
        except OSError: self.skipTest("symlinks unavailable")
        with self.assertRaises(g.GuardianError): g.recovery_plan(link)
        (self.root / "CASE").write_text("a"); (self.root / "case").write_text("b")
        if len(list(self.root.iterdir())) == 2:
            with self.assertRaises(g.GuardianError): g.recovery_plan(self.root)

    def test_recovery_plan_rejects_corrupted_retired_candidate(self):
        manifests = [self.make(retention_profile="Main", keep=2) for _ in range(3)]
        retired = next((self.root / g.RETIRED).glob("[0-9a-f]" * 32))
        (retired / "data" / "sav.dat").write_bytes(b"corrupt")
        r = g.recovery_plan(self.root)
        self.assertEqual(len(r["candidates"]), 2)
        self.assertEqual(r["invalid_snapshots"][0]["location"], "retired")

    def test_new_read_only_cli_commands(self):
        self.make()
        for argv in (["doctor", "--backup-root", str(self.root)],
                     ["recovery-plan", "--backup-root", str(self.root)]):
            with self.subTest(argv=argv), contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(g.main(argv), 0)
                self.assertIsInstance(json.loads(out.getvalue()), dict)
        with mock.patch.object(g, "inspect_source", return_value={"status": "fixture"}) as inspect:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(g.main(["inspect-source", "--save-dir", str(self.slot)]), 0)
            inspect.assert_called_once_with(str(self.slot))


if __name__ == "__main__":
    unittest.main()
