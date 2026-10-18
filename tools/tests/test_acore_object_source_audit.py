"""Object audits must expose coverage gaps without masking geometry changes."""
import copy
import json
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_object_sources as audit
import db_snapshot


class ObjectSourceAuditTests(unittest.TestCase):
    def test_geometry_preserves_precision_sparse_metadata_and_duplicate_points(self):
        spawn = audit.geometry.typed({210: [[10.123456, 20, None, 3, 571, 100, 200, 1], [30, 40]]})
        baseline = {1: {"s:spawns": spawn}}
        for slot, value in [("n:1", 10.123457), ("n:3", 1), ("n:4", 4), ("n:7", 201)]:
            source = copy.deepcopy(baseline)
            source[1]["s:spawns"]["n:210"]["n:1"][slot] = value
            row = audit.compare_fields(baseline, source, ["spawns"])["spawns"]
            self.assertEqual(row["counts"], {"valueDifferences": 1})
            self.assertEqual(row["differences"][0]["objectId"], 1)
            self.assertNotIn("npcId", row["differences"][0])
        source = copy.deepcopy(baseline)
        source[1]["s:spawns"]["n:210"]["n:3"] = copy.deepcopy(spawn["n:210"]["n:2"])
        row = audit.compare_fields(baseline, source, ["spawns"])["spawns"]
        self.assertEqual(row["differences"][0]["differenceKind"], "coordinateOrCoverageChanges")
        self.assertNotIn("n:3", spawn["n:210"]["n:1"])

    def test_point_reordering_remains_a_reported_difference(self):
        baseline = {1: {"s:spawns": audit.geometry.typed({210: [[10, 20], [30, 40]]})}}
        source = {1: {"s:spawns": audit.geometry.typed({210: [[30, 40], [10, 20]]})}}
        row = audit.compare_fields(baseline, source, ["spawns"])["spawns"]
        self.assertEqual(row["counts"], {"valueDifferences": 1})
        self.assertEqual(row["differences"][0]["differenceKind"], "pointOrderOnly")

    def test_unmapped_source_is_not_an_empty_spawn_list(self):
        baseline = {1: {"s:spawns": {"n:210": {"n:1": {"n:1": 10, "n:2": 20}}}}}
        row = audit.compare_fields(baseline, {1: {}}, ["spawns"])["spawns"]
        self.assertEqual(row["counts"], {"unavailableInSource": 1})
        self.assertFalse(row["differences"][0]["sourcePresent"])
        row = audit.compare_fields(baseline, {1: {"s:spawns": {}}}, ["spawns"])["spawns"]
        self.assertEqual(row["counts"], {"valueDifferences": 1})

    def test_relation_membership_and_representation_are_separate(self):
        baseline = {1: {"s:questStarts": {"n:1": 20, "n:2": 10}},
                    2: {"s:questStarts": {"n:1": 30}}, 3: {}}
        source = {1: {"s:questStarts": {"n:1": 10, "n:2": 20}}, 2: {"s:questStarts": {}}}
        result = audit.compare_fields(baseline, source, ["questStarts"])["questStarts"]
        self.assertEqual(result["counts"], {"relationOrderOrDuplicates": 1, "valueDifferences": 1, "missingSourceTemplate": 1})
        result = audit.compare_fields({1: {}, 2: {"s:factionID": False}},
                                      {1: {"s:factionID": 0}, 2: {"s:factionID": 0}}, ["factionID"])
        self.assertEqual(result["factionID"]["counts"], {"representationOnly": 1, "valueDifferences": 1})

    def test_cache_validates_geometry_and_source_item_coverage(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            cache = directory / "cache.json"
            saved = {"signature": {"fixture": True}, "objects": {"1": {"s:spawns": {}}},
                     "tableCoverage": {}, "diagnostics": {}, "readerStats": {}, "itemSourceObjectIds": [1]}
            saved["modelSha256"] = audit.model_digest(saved)
            audit.shared.write_json(cache, saved)
            args = [ADDON_ROOT] * 5 + [saved["signature"], cache]
            with patch.object(audit.reader, "build_acore_objects", side_effect=AssertionError("Unexpected SQL scan")):
                self.assertEqual(audit.load_source(*args), saved)
            saved["itemSourceObjectIds"].append(2)
            cache.write_text(json.dumps(saved), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                audit.load_source(*args)

    def test_extraction_tracks_skipped_sql_and_restores_shared_readers(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            signature = {"fixture": True}
            sql_file = directory / "unsupported.sql"
            statement = "UPDATE gameobject_template t JOIN other o ON o.id=t.entry SET t.size=1"
            sql_file.write_text(statement + ";", encoding="utf-8")
            original_rows = audit.reader.load_row_table
            original_statements = audit.sql_reader.load_sql_statements
            original_update = audit.sql_reader.apply_multirow_update

            def build(source, **kwargs):
                self.assertEqual(set(kwargs), {"repo_root", "gameobject_sql", "map_difficulty_dbc", "wdm_root", "provenance"})
                kwargs["provenance"].update({"1": {"spawns": {"n:210": {"n:1": ["gameobject:100"]}}}})
                audit.reader.load_keyed_table(source, "gameobject_template", "entry")
                audit.sql_reader.load_sql_statements(str(sql_file))
                self.assertEqual(audit.sql_reader.apply_multirow_update(statement, "gameobject_template", {}), 1)
                return {1: {"name": "Chest", "spawns": {210: [[10, 20, None, 1, 571]]}}}, {}, {1}

            with patch.object(audit.sql_reader, "load_row_table", return_value=([{"entry": 1}], 0)), \
                 patch.object(audit.reader, "build_acore_objects", side_effect=build), \
                 patch.object(audit, "source_signature", return_value=signature):
                saved = audit.load_source(*([ADDON_ROOT] * 5), signature, directory / "cache.json")
            self.assertIs(audit.reader.load_row_table, original_rows)
            self.assertIs(audit.sql_reader.load_sql_statements, original_statements)
            self.assertIs(audit.sql_reader.apply_multirow_update, original_update)
            self.assertEqual(saved["tableCoverage"]["gameobject_template"]["rows"], 1)
            self.assertEqual(saved["itemSourceObjectIds"], [1])
            self.assertEqual(saved["geometryProvenance"]["1"]["spawns"]["n:210"]["n:1"], ["gameobject:100"])
            self.assertNotIn("n:3", saved["objects"]["1"]["s:spawns"]["n:210"]["n:1"])
            skipped = saved["diagnostics"]["skippedSqlMutations"]
            self.assertEqual(len(skipped), 1)
            self.assertEqual(skipped[0]["statement"], statement)
            self.assertEqual(skipped[0]["operation"], "update")

    def test_failed_extraction_restores_hooks_and_leaves_no_cache(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            original_rows = audit.reader.load_row_table
            original_insert = audit.coordinate_reader.apply_multirow_insert
            cache = directory / "cache.json"
            with patch.object(audit.reader, "build_acore_objects", side_effect=ValueError("fixture failure")):
                with self.assertRaisesRegex(ValueError, "fixture failure"):
                    audit.load_source(*([ADDON_ROOT] * 5), {}, cache)
            self.assertIs(audit.reader.load_row_table, original_rows)
            self.assertIs(audit.coordinate_reader.apply_multirow_insert, original_insert)
            self.assertFalse(cache.exists())


if __name__ == "__main__":
    unittest.main()
