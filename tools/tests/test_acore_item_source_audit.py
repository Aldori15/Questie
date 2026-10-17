"""Source-audit classifications must not silently normalize away missing data."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_item_sources as audit
import db_snapshot


class ItemSourceAuditTests(unittest.TestCase):
    def snapshot_fixture(self, path, different_horde=False):
        metadata = {"contexts": ["Alliance/isle-1", "Horde/isle-1"], "locale": "enUS",
                    "scope": "post-corrections-pre-localization-v1",
                    "sources": {"Questie.lua": db_snapshot.file_hash(ADDON_ROOT / "Questie.lua")}}
        with db_snapshot.open_snapshot(path, "w") as stream:
            writer = db_snapshot.SnapshotWriter(stream, metadata)
            for context in metadata["contexts"]:
                value = 124 if different_horde and context.startswith("Horde") else 123
                writer.add({"context": context, "section": "itemData", "id": 1, "value": {"s:startQuest": value}})
                writer.add({"context": context, "section": "schemas/item", "id": "keys", "value": {"s:startQuest": 1}})
            writer.finish()

    def test_snapshot_reader_checks_all_contexts_and_consumes_footer(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "input.jsonl"
            self.snapshot_fixture(path)
            items, fields, _, _ = audit.read_items(path, ADDON_ROOT)
            self.assertEqual(items[1], {"s:startQuest": 123})
            self.assertEqual(fields, ["startQuest"])
            self.snapshot_fixture(path, different_horde=True)
            with self.assertRaisesRegex(ValueError, "differs between contexts"):
                audit.read_items(path, ADDON_ROOT)
            self.snapshot_fixture(path)
            path.write_text(''.join(path.read_text(encoding="utf-8").splitlines(keepends=True)[:-1]), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "missing footer"):
                audit.read_items(path, ADDON_ROOT)

    def test_nested_false_is_not_zero(self):
        self.assertFalse(audit.same_value({"n:1": False}, {"n:1": 0}))
        self.assertTrue(audit.same_value({"n:1": 12}, {"n:1": 12.0}))

    def test_missing_empty_and_zero_have_explicit_normalization(self):
        self.assertFalse(audit.same_value(audit.ABSENT, {}))
        self.assertFalse(audit.same_value(audit.ABSENT, 0))
        self.assertEqual(audit.normalized("startQuest", audit.ABSENT), 0)
        self.assertEqual(audit.normalized("npcDrops", {}), ())
        self.assertEqual(audit.normalized("npcDrops", {"n:2": 3, "n:4": 3}), (3,))
        with self.assertRaises(ValueError):
            audit.normalized("npcDrops", {"n:1": False})

    def test_starts_compare_all_current_items_without_automatic_fix_file(self):
        current = {1: {"s:startQuest": 123}, 2: {"s:startQuest": 0}, 4: {}, 5: {}}
        source = {1: {"startQuest": 123}, 2: {"startQuest": 123}, 3: {"startQuest": 123}, 5: {}}
        result = audit.audit_starts(current, source, {1, 2, 3, 5})
        self.assertEqual([r["status"] for r in result["entries"]],
                         ["matchesSource", "differsFromSource", "missingSourceTemplate"])
        self.assertEqual(result["entries"][1]["current"], 0)
        self.assertFalse(result["entries"][2]["fieldPresent"])
        self.assertEqual(result["counts"]["noStartOnEitherSide"], 1)
        self.assertEqual(result["sourceOnlyStartItemIds"], [3])

    def test_field_audit_separates_representation_from_values_and_unsupported_fields(self):
        items = {1: {}, 2: {"s:startQuest": 123}, 3: {"s:startQuest": 0}, 4: {"s:teachesSpell": 42}}
        source = {1: {}, 2: {"startQuest": 123}, 3: {"startQuest": 124}}
        fields = audit.compare_fields(items, ["startQuest", "teachesSpell"], source, {1, 2, 3}, "full", {})
        self.assertEqual(fields["startQuest"]["counts"],
                         {"representationOnly": 1, "exactMatches": 1, "valueDifferences": 1, "missingSourceTemplate": 1})
        self.assertEqual(fields["teachesSpell"]["status"], "unsupportedByCurrentSourceReader")
        self.assertEqual(fields["teachesSpell"]["presentItemIds"], [4])

    def test_class_policy_does_not_disguise_raw_source_and_manual_exceptions(self):
        items = {1: {"s:class": 12}, 2: {"s:class": 12}}
        source = {1: {"class": 0, "isStartItem": True}, 2: {"class": 0}}
        manual = {"manual.lua": {2: {"class": 12}}}
        row = audit.compare_fields(items, ["class"], source, {1, 2}, "full", manual)["class"]
        self.assertEqual(row["counts"]["candidateQuestItemClassRule"], 1)
        self.assertEqual(row["differences"][0]["itemId"], 2)
        self.assertEqual(row["differences"][0]["sourceRaw"], 0)
        self.assertEqual(row["differences"][0]["manualReferences"], ["manual.lua"])

    def test_list_order_and_duplicates_are_counted_as_representation_differences(self):
        items = {1: {"s:npcDrops": {"n:1": 5, "n:2": 3, "n:3": 5}}}
        source = {1: {"npcDrops": [3, 5]}}
        row = audit.compare_fields(items, ["npcDrops"], source, {1}, "full", {})["npcDrops"]
        self.assertEqual(row["counts"], {"representationOnly": 1})

    def test_missing_direct_source_column_is_not_assumed_to_be_zero(self):
        row = audit.compare_fields({1: {"s:flags": 0}}, ["flags"], {1: {}}, {1}, "full", {})["flags"]
        self.assertEqual(row["counts"], {"missingSourceField": 1})
        self.assertEqual(row["differences"][0]["review"], "missingSourceField")

    def test_outputs_cannot_target_addon_databases(self):
        with self.assertRaises(ValueError):
            audit.local_output(ADDON_ROOT, Path("Database/AzerothCore/acoreItemDB.json"))

    def test_cache_requires_matching_inputs_and_an_intact_payload(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            cache = directory / "source.json"
            saved = {"signature": {"scope": "starts"}, "items": {"1": {"startQuest": 123}},
                     "templateIds": [1], "tableCoverage": {}}
            saved["modelSha256"] = audit.model_digest(saved)
            audit.write_json(cache, saved)
            with patch.object(audit.source_reader, "load_row_table", side_effect=AssertionError("unexpected SQL scan")):
                self.assertEqual(audit.load_source(ADDON_ROOT, "starts", saved["signature"], cache), saved)
            saved["items"]["1"]["startQuest"] = 456
            cache.write_text(json.dumps(saved), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "checksum"):
                audit.load_source(ADDON_ROOT, "starts", saved["signature"], cache)

    def test_supplement_review_proves_vendor_and_nested_container_paths_per_link(self):
        items = {1: {"s:name": "Item", "s:class": 12, "s:itemLevel": 1,
                     "s:npcDrops": {"n:1": 100, "n:2": 200, "n:3": 300, "n:4": 400},
                     "s:objectDrops": {"n:1": 500}}}
        source = {1: {"name": "Item", "class": 12, "vendors": [100], "npcDrops": [400], "itemDrops": [2]},
                  2: {"itemDrops": [3]}, 3: {"npcDrops": [200], "objectDrops": [500]}}
        result = audit.review_supplements(items, source, {1, 2, 3}, {})
        npc, obj = result["sourceEntries"]
        self.assertEqual(npc["missingSourceIds"], [100, 200, 300])
        self.assertEqual(npc["links"][0]["evidence"], [{"kind": "alsoVendor"}])
        self.assertEqual(npc["links"][1]["evidence"], [{"kind": "containerSource", "containerPath": [2, 3]}])
        self.assertEqual(npc["links"][2]["status"], "needsSourceInvestigation")
        self.assertEqual(obj["links"][0]["evidence"][0]["containerPath"], [2, 3])
        self.assertEqual(result["counts"]["sourceLinks"], 4)
        self.assertEqual(result["counts"]["linkStatuses"], {"alternatePathFound": 3, "needsSourceInvestigation": 1})
        self.assertTrue(all(row["decision"] == "retainPendingReview" for row in result["sourceEntries"]))

    def test_supplement_review_handles_container_cycles_without_inventing_paths(self):
        source = {1: {"itemDrops": [2]}, 2: {"itemDrops": [1, 2], "npcDrops": [200]}}
        result = audit.review_supplements({1: {"s:npcDrops": {"n:1": 200, "n:2": 300}}}, source, {1, 2}, {})
        links = result["sourceEntries"][0]["links"]
        self.assertEqual(links[0]["evidence"], [{"kind": "containerSource", "containerPath": [2]}])
        self.assertEqual(links[1]["evidence"], [])

    def test_supplement_review_uses_raw_class_and_keeps_partial_records_separate(self):
        items = {1: {"s:class": 13}, 2: {"s:class": 12}, 3: {}, 4: {"s:class": 12}}
        source = {1: {"class": 13, "startQuest": 10}, 2: {"class": 0}, 3: {"class": 0},
                  4: {"class": 0, "startQuest": 20}}
        manual = {"manual.lua": {2: {"class": 12}, 4: {"class": 12}}}
        result = audit.review_supplements(items, source, {1, 2, 3, 4}, manual)
        # The legacy proposed class-12 rule treats item 4 as an exact match,
        # but raw source regeneration still needs its explicit class override.
        legacy = audit.compare_fields({4: items[4]}, ["class"], source, {4}, "full", manual)
        self.assertEqual(legacy["class"]["counts"]["exactMatches"], 1)
        self.assertEqual([row["itemId"] for row in result["classOverrides"]], [2, 4])
        self.assertEqual(result["classOverrides"][0]["manualReferences"], ["manual.lua"])
        partial = next(row for row in result["partialRecords"] if row["itemId"] == 3)
        self.assertIn("class", partial["missingFields"])

    def test_supplement_review_does_not_mark_new_direct_sources_as_losses(self):
        result = audit.review_supplements({1: {"s:npcDrops": {"n:1": 100}}},
                                         {1: {"npcDrops": [100, 200]}}, {1}, {})
        self.assertEqual(result["sourceEntries"], [])
        self.assertEqual(result["counts"]["sourceLinks"], 0)


if __name__ == "__main__":
    unittest.main()
