"""Snapshot comparison must preserve Lua semantics and reject incomplete captures."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot as snapshot


METADATA = {"contexts": ["Alliance/isle-1"], "locale": "enUS", "scope": "post-corrections-pre-localization-v1"}


def record(value, section="questData", entity_id=2):
    return {"context": "Alliance/isle-1", "section": section, "id": entity_id, "value": value}


def encoded(records, metadata=None):
    stream = io.StringIO()
    writer = snapshot.SnapshotWriter(stream, metadata or METADATA)
    for row in records:
        writer.add(row)
    writer.finish()
    return stream.getvalue()


class SnapshotComparisonTests(unittest.TestCase):
    def compare(self, before, after, **kwargs):
        with snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            before_path, after_path = Path(directory) / "before.jsonl.gz", Path(directory) / "after.jsonl.gz"
            for path, text in ((before_path, before), (after_path, after)):
                with snapshot.open_snapshot(path, "w") as stream:
                    stream.write(text)
            report = Path(directory) / "changes.jsonl"
            args = argparse.Namespace(before=before_path, after=after_path, report=report, limit=kwargs.get("limit", 20))
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                result = snapshot.compare(args)
            return result, [json.loads(line) for line in report.read_text(encoding="utf-8").splitlines()], output.getvalue()

    def test_equal_data_can_have_different_source_metadata(self):
        rows = [record({"s:reputationReward": {"n:1": {"n:1": 81, "n:2": 250}}})]
        result, changes, _ = self.compare(encoded(rows, {**METADATA, "git": {"commit": "before"}}),
                                          encoded(rows, {**METADATA, "git": {"commit": "after"}}))
        self.assertEqual(result, 0)
        self.assertEqual(changes, [])

    def test_reputation_and_item_start_loss_have_readable_paths(self):
        before = [record({"s:startQuest": 123}, "itemData", 1307),
                  record({"s:reputationReward": {"n:1": {"n:1": 81, "n:2": 250}}})]
        after = [record({}, "itemData", 1307),
                 record({"s:reputationReward": {"n:1": {"n:1": 81, "n:2": 100}}})]
        result, changes, output = self.compare(encoded(before), encoded(after), limit=1)
        self.assertEqual(result, 1)
        self.assertEqual([(row["path"], row["change"]) for row in changes],
                         [(".startQuest", "removed"), (".reputationReward[1][2]", "changed")])
        self.assertIn("Differences: 2", output)
        self.assertNotIn("250 -> 100", output)  # --limit does not limit the report/check.

    def test_missing_false_zero_empty_and_typed_keys_remain_distinct(self):
        pairs = [({}, {"s:x": False}), ({"s:x": False}, {"s:x": 0}),
                 ({"s:x": 0}, {"s:x": {}}), ({}, {"s:x": {}}),
                 ({"n:1": "value"}, {"s:1": "value"}),
                 ({"n:1": "one", "n:3": "three"}, {"n:1": "one", "n:2": "three"})]
        for before, after in pairs:
            with self.subTest(before=before, after=after):
                result, changes, _ = self.compare(encoded([record(before)]), encoded([record(after)]))
                self.assertEqual(result, 1)
                self.assertTrue(changes)

    def test_lua_numbers_compare_equally_across_integer_float_serialization(self):
        result, changes, _ = self.compare(encoded([record({"n:1": 250})]), encoded([record({"n:1": 250.0})]))
        self.assertEqual(result, 0)
        self.assertEqual(changes, [])

    def test_added_removed_records_and_runtime_override_changes(self):
        before = [record({"n:1": True}, "auxiliary/fresh", "hiddenQuests"),
                  record({"s:npcDrops": {"n:1": 36670}}, "overrides/fresh/item", 49698),
                  record({"s:name": "removed"})]
        after = [record({"n:1": False}, "auxiliary/fresh", "hiddenQuests"),
                 record({"s:npcDrops": {"n:1": 36669}}, "overrides/fresh/item", 49698),
                 record({"s:name": "added"}, entity_id=3)]
        _, changes, _ = self.compare(encoded(before), encoded(after))
        self.assertEqual([row["change"] for row in changes], ["changed", "changed", "removed", "added"])

    def test_truncated_and_corrupt_snapshots_never_pass(self):
        valid = encoded([record({"s:name": "original"})])
        cases = ["\n".join(valid.splitlines()[:-1]) + "\n", valid.replace("original", "corrupted"), valid + "{}\n"]
        for invalid in cases:
            with self.subTest(invalid=invalid[-100:]), self.assertRaises(ValueError):
                self.compare(valid, invalid)

    def test_writer_rejects_duplicate_and_unsorted_records(self):
        for rows in ([record({}), record({})], [record({}, entity_id=3), record({}, entity_id=2)]):
            with self.assertRaises(ValueError):
                encoded(rows)

    def test_incompatible_contexts_and_scope_are_errors(self):
        valid = encoded([record({})])
        horde_record = {**record({}), "context": "Horde/isle-1"}
        other = encoded([horde_record], {**METADATA, "contexts": ["Horde/isle-1"]})
        for invalid in (other, encoded([record({})], {**METADATA, "scope": "different"})):
            with self.assertRaises(ValueError):
                self.compare(valid, invalid)

    def test_failed_comparison_preserves_an_existing_report(self):
        with snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            before, after, report = (directory / name for name in ("before.jsonl", "after.jsonl", "report.jsonl"))
            text = encoded([record({"s:name": "original"})])
            before.write_text(text, encoding="utf-8")
            after.write_text(text.replace("original", "changed"), encoding="utf-8")
            report.write_text("previous report", encoding="utf-8")
            args = argparse.Namespace(before=before, after=after, report=report, limit=0)
            with self.assertRaises(ValueError):
                snapshot.compare(args)
            self.assertEqual(report.read_text(encoding="utf-8"), "previous report")

    def test_missing_context_is_rejected(self):
        with self.assertRaises(ValueError):
            encoded([record({})], {**METADATA, "contexts": ["Alliance/isle-1", "Horde/isle-1"]})

    def test_non_object_headers_and_records_are_errors(self):
        valid = encoded([record({})])
        for invalid in ("[]\n", valid.splitlines()[0] + "\n42\n"):
            with self.assertRaises(ValueError):
                self.compare(valid, invalid)

    def test_capture_plan_follows_active_manifest_registration_order(self):
        paths, dependencies = snapshot.source_files(ADDON_ROOT)
        self.assertLess(paths.index("Compat/Corrections.lua"), paths.index("Database/AzerothCore/acoreQuestDB.lua"))
        self.assertLess(paths.index("Database/AzerothCore/acoreQuestDB.lua"), paths.index("Database/QuestieDB.lua"))
        for kind in ("Item", "Npc", "Object", "Quest"):
            self.assertIn(f"Database/AzerothCore/acore{kind}DB.lua", paths)
        self.assertNotIn("Database/AzerothCore/AzerothCoreQuestCorrections.lua", paths)
        self.assertIn("Database/Corrections/Automatic/itemStartFixes.lua", paths)
        self.assertIn("Database/Corrections/QuestieEvent.lua", paths)
        self.assertIn("Modules/QuestieInit.lua", dependencies)
        self.assertNotIn("Database/compiler.lua", paths)

    def test_actual_lua_pipeline_preserves_rewards_starts_and_runtime_overrides(self):
        try:
            lua = snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua is not installed; set QUESTIE_TEST_LUA to run the pipeline integration test")
        with snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            output = directory / "pipeline.jsonl.gz"
            args = argparse.Namespace(repo=ADDON_ROOT, output=output, force=False, lua=lua,
                                      factions=["Alliance", "Horde"], isle_phases=[1], input=[])
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(snapshot.capture(args), 0)
            selected = {}
            states = {}
            counts = {}
            with snapshot.open_snapshot(output, "r") as stream:
                header = snapshot.read_header(stream)
                for row in snapshot.read_records(stream, header["metadata"]["contexts"]):
                    context, section, entity_id = row["context"], row["section"], row["id"]
                    counts[context] = counts.get(context, 0) + 1
                    if (section == "questData" and entity_id in (2, 6, 7, 11390, 13836)) or (section == "itemData" and entity_id == 1307):
                        selected[context, section, entity_id] = row["value"]
                    if section.startswith(("overrides/", "auxiliary/")):
                        states.setdefault((context, section), {})[entity_id] = row["value"]
            for faction, dropper in (("Alliance", 36670), ("Horde", 36669)):
                context = faction + "/isle-1"
                self.assertGreater(counts[context], 50000)
                for quest_id, amount in ((2, 250), (6, 150), (7, 250)):
                    self.assertEqual(selected[context, "questData", quest_id]["s:reputationReward"]["n:1"]["n:2"], amount)
                self.assertEqual(selected[context, "itemData", 1307]["s:startQuest"], 123)
                self.assertEqual(selected[context, "questData", 11390]["s:extraObjectives"]["n:1"]["n:2"], 19)
                self.assertEqual(selected[context, "questData", 13836]["s:extraObjectives"]["n:1"]["n:2"], 20)
                self.assertEqual(states[context, "overrides/fresh/item"][49698]["s:npcDrops"]["n:1"], dropper)
                for kind in ("quest", "npc", "object", "item"):
                    self.assertEqual(states.get((context, "overrides/fresh/" + kind), {}),
                                     states.get((context, "overrides/cached/" + kind), {}))
                self.assertEqual(states[context, "auxiliary/fresh"], states[context, "auxiliary/cached"])
                self.assertEqual(states[context, "overrides/darkmoon-reset/npc"], states[context, "overrides/fresh/npc"])
                self.assertNotEqual(states[context, "overrides/darkmoon-1/npc"], states[context, "overrides/darkmoon-2/npc"])


if __name__ == "__main__":
    unittest.main()
