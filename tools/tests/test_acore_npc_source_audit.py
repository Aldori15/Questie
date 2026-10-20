"""NPC audit must expose missing source coverage and retain full geometry."""
import copy
import json
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_item_sources as shared
import audit_acore_npc_sources as audit
import db_snapshot


class NpcSourceAuditTests(unittest.TestCase):
    def test_source_typing_preserves_sparse_phase_and_visibility_slots(self):
        value = {210: [[12.123456, 34.5, None, 3, 571, 100, 200, 1]]}
        result = audit.typed(value)["n:210"]["n:1"]
        self.assertNotIn("n:3", result)
        self.assertEqual(result["n:1"], 12.123456)
        self.assertEqual(result["n:8"], 1)
        self.assertEqual(audit.typed([False, 0, None, {}]), {"n:1": False, "n:2": 0, "n:4": {}})

    def test_geometry_differences_keep_phase_identity_precision_and_path_order(self):
        spawn = audit.typed({210: [[10.123456, 20, 3, 1, 571, 100, 200, 1]]})
        path = audit.typed({210: [[[10, 20], [30, 40]]]})
        baseline = {1: {"s:spawns": spawn, "s:waypoints": path}}
        changes = []
        for slot, value in [("n:1", 10.123457), ("n:3", 4), ("n:7", 201)]:
            source = copy.deepcopy(baseline)
            source[1]["s:spawns"]["n:210"]["n:1"][slot] = value
            changes.append(audit.compare_fields(baseline, source, ["spawns"], {}))
        for result in changes:
            self.assertEqual(result["spawns"]["counts"], {"valueDifferences": 1})
        source = copy.deepcopy(baseline)
        points = source[1]["s:waypoints"]["n:210"]["n:1"]
        points["n:1"], points["n:2"] = points["n:2"], points["n:1"]
        self.assertEqual(audit.compare_fields(baseline, source, ["waypoints"], {})["waypoints"]["counts"],
                         {"valueDifferences": 1})

    def test_missing_health_is_unavailable_rather_than_an_expected_zero(self):
        result = audit.compare_fields({1: {"s:minLevelHealth": 100}}, {1: {}}, ["minLevelHealth"], {})
        row = result["minLevelHealth"]
        self.assertEqual(row["counts"], {"unavailableInSource": 1})
        self.assertFalse(row["differences"][0]["sourcePresent"])
        self.assertEqual(row["differences"][0]["snapshot"], 100)

    def test_missing_faction_inputs_make_friendliness_unreliable(self):
        baseline = {1: {"s:friendlyToFaction": ""}}
        source = {1: {"s:friendlyToFaction": "", "s:factionID": 100}}
        for diagnostics in [{"missingFactionTemplateIds": [100]}, {"missingFriendlinessAnchorIds": [1]}]:
            result = audit.compare_fields(baseline, source, ["friendlyToFaction"], diagnostics)
            self.assertEqual(result["friendlyToFaction"]["counts"], {"unreliableSourceCoverage": 1})

    def test_representation_differences_do_not_hide_false_values_or_nested_empty_zones(self):
        baseline = {1: {}, 2: {"s:npcFlags": False}, 3: {"s:spawns": {"n:210": {}}}}
        source = {1: {"s:npcFlags": 0}, 2: {"s:npcFlags": 0}, 3: {"s:spawns": {}}}
        fields = audit.compare_fields(baseline, source, ["npcFlags", "spawns"], {})
        self.assertEqual(fields["npcFlags"]["counts"]["representationOnly"], 1)
        self.assertEqual(fields["npcFlags"]["counts"]["valueDifferences"], 1)
        self.assertEqual(fields["spawns"]["counts"]["valueDifferences"], 1)

    def test_relation_order_is_separate_from_missing_relations_and_templates(self):
        baseline = {1: {"s:questStarts": {"n:1": 20, "n:2": 10}}, 2: {"s:questStarts": {"n:1": 30}}, 3: {}}
        source = {1: {"s:questStarts": {"n:1": 10, "n:2": 20}}, 2: {"s:questStarts": {}}}
        result = audit.compare_fields(baseline, source, ["questStarts"], {})["questStarts"]
        self.assertEqual(result["counts"], {"relationOrderOrDuplicates": 1, "valueDifferences": 1, "missingSourceTemplate": 1})

    def test_geometry_inventory_counts_metadata_without_flattening_waypoints(self):
        records = {1: {"s:spawns": audit.typed({210: [[10, 20, 3, 1, 571, 100, 200, 1], [30, 40]]}),
                       "s:waypoints": audit.typed({210: [[[10, 20], [30, 40]]]})}}
        inventory = audit.geometry_inventory(records)
        self.assertEqual(inventory["spawns"], {"points": 2, "pointsWithPhaseSlot": 1, "pointsWithVisibilityOrIdentitySlots": 1})
        self.assertEqual(inventory["waypoints"], {"points": 2})

    def test_spawn_order_classification_keeps_metadata_precision_and_duplicate_counts(self):
        before = audit.typed({210: [[10, 20, 3, 1, 571], [30, 40]]})
        reordered = audit.typed({210: [[30.0, 40.0], [10.0, 20.0, 3, 1, 571]]})
        self.assertEqual(audit.spawn_difference_kind(before, reordered), "pointOrderOnly")
        changed = audit.typed({210: [[10, 20, 4, 1, 571], [30, 40]]})
        self.assertEqual(audit.spawn_difference_kind(before, changed), "phaseVisibilityOrIdentityChanges")
        changed = audit.typed({210: [[10.000001, 20, 3, 1, 571], [30, 40]]})
        self.assertEqual(audit.spawn_difference_kind(before, changed), "coordinateOrCoverageChanges")
        changed = audit.typed({210: [[10, 20, 3, 1, 571], [30, 40], [30, 40]]})
        self.assertEqual(audit.spawn_difference_kind(before, changed), "coordinateOrCoverageChanges")

    def test_spawn_classification_does_not_approve_reordering_or_discard_sparse_fields(self):
        before = audit.typed({210: [[10, 20], [30, 40]]})
        after = audit.typed({210: [[30, 40], [10, 20]]})
        fields = audit.compare_fields({1: {"s:spawns": before}}, {1: {"s:spawns": after}}, ["spawns"], {})
        self.assertEqual(fields["spawns"]["counts"], {"valueDifferences": 1})
        self.assertEqual(fields["spawns"]["differences"][0]["differenceKind"], "pointOrderOnly")
        after["n:210"]["n:1"]["n:8"] = 1
        self.assertEqual(audit.spawn_difference_kind(before, after), "phaseVisibilityOrIdentityChanges")

    def test_npc_snapshot_reader_checks_every_context_and_footer(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "snapshot.jsonl"
            metadata = {"contexts": ["Alliance/isle-1", "Horde/isle-1"], "locale": "enUS",
                        "scope": "post-corrections-pre-localization-v1",
                        "sources": {"Questie.lua": db_snapshot.file_hash(ADDON_ROOT / "Questie.lua")}}

            def write(different=False):
                with db_snapshot.open_snapshot(path, "w") as stream:
                    writer = db_snapshot.SnapshotWriter(stream, metadata)
                    for context in metadata["contexts"]:
                        writer.add({"context": context, "section": "npcData", "id": 1,
                                    "value": {"s:name": "Other" if different and context.startswith("Horde") else "NPC"}})
                        writer.add({"context": context, "section": "schemas/npc", "id": "keys", "value": {"s:name": 1}})
                    writer.finish()

            write()
            self.assertEqual(shared.read_static_records(path, ADDON_ROOT, "npc")[0], {1: {"s:name": "NPC"}})
            write(different=True)
            with self.assertRaisesRegex(ValueError, "differs between contexts"):
                shared.read_static_records(path, ADDON_ROOT, "npc")
            write()
            path.write_text(''.join(path.read_text().splitlines(keepends=True)[:-1]), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "missing footer"):
                shared.read_static_records(path, ADDON_ROOT, "npc")

    def test_template_addon_base_and_update_changes_invalidate_source_cache(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            source = directory / "source"
            base = source / "data/sql/base/db_world"
            base.mkdir(parents=True)
            for table in audit.TABLES:
                (base / (table + ".sql")).write_text("-- fixture\n", encoding="utf-8")
            addon = base / "creature_template_addon.sql"
            addon.write_text("-- path_id 77\n", encoding="utf-8")
            update = source / "addon-update.sql"
            update.write_text("-- path_id 88\n", encoding="utf-8")
            header = source / "src/server/game/Battlefield/Zones/BattlefieldWG.h"
            header.parent.mkdir(parents=True)
            header.write_text("// fixture\n", encoding="utf-8")
            wdm = directory / "patch-enUS-M extracted/DBFilesClient"
            wdm.mkdir(parents=True)
            for name in ["DungeonMap.csv", "DungeonMapChunk.csv"]:
                (wdm / name).write_text("fixture\n", encoding="utf-8")

            def files(root, table):
                return [base / (table + ".sql")] + ([update] if table == "creature_template_addon" else [])

            with patch.object(audit.sql_reader, "source_sql_files", side_effect=files):
                args = source, ADDON_ROOT, addon, addon, addon, directory
                original = audit.source_signature(*args)
                relative = str(addon.relative_to(source))
                self.assertIn(relative, original["sourceFiles"])
                addon.write_text("-- path_id 99\n", encoding="utf-8")
                changed_base = audit.source_signature(*args)
                self.assertNotEqual(original["sourceFiles"][relative], changed_base["sourceFiles"][relative])
                update.write_text("-- path_id 100\n", encoding="utf-8")
                changed_update = audit.source_signature(*args)
                self.assertNotEqual(changed_base["sourceFiles"]["addon-update.sql"],
                                    changed_update["sourceFiles"]["addon-update.sql"])

    def test_source_cache_requires_intact_geometry_and_metadata(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            cache = directory / "cache.json"
            saved = {"signature": {"version": "fixture"}, "npcs": {"1": {"s:spawns": {}}},
                     "tableCoverage": {}, "diagnostics": {}, "readerStats": {}}
            saved["modelSha256"] = audit.model_digest(saved)
            shared.write_json(cache, saved)
            args = [ADDON_ROOT] * 6 + [saved["signature"], cache]
            with patch.object(audit.reader, "build_acore_npcs", side_effect=AssertionError("Unexpected SQL scan")):
                self.assertEqual(audit.load_source(*args), saved)
            saved["npcs"]["1"]["s:spawns"] = {"n:210": {"n:1": {"n:1": 10, "n:2": 20}}}
            cache.write_text(json.dumps(saved), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                audit.load_source(*args)

    def test_extraction_never_receives_baseline_fallback_and_restores_reader_hooks(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            before_sql, before_npc = audit.sql_reader.load_row_table, audit.reader.load_row_table
            before_statements, before_update = audit.reader.load_sql_statements, audit.reader.apply_multirow_update
            signature = {"fixture": True}
            statement = "UPDATE waypoint_data w JOIN creature c ON c.guid=w.id SET w.move_type=0"
            sql_file = directory / "skipped.sql"
            sql_file.write_text(statement + ";", encoding="utf-8")

            def build(source, **kwargs):
                self.assertNotIn("questie_npcs", kwargs)
                audit.reader.load_row_table(source, "creature_template", ("entry",))
                audit.reader.load_row_table(source, "factiontemplate_dbc", ("ID",))
                audit.reader.load_sql_statements(str(sql_file))
                self.assertEqual(audit.reader.apply_multirow_update(statement, "waypoint_data", {}), 1)
                return {1: {"name": "NPC", "spawns": {210: [[10, 20, None, 1, 571]]}}}, {}

            def rows(root, table, keys, include_modules=False):
                return ([{"entry": 1, "faction": 100}] if table == "creature_template" else [{"ID": 100}]), 0

            with patch.object(audit.sql_reader, "load_row_table", side_effect=rows), \
                 patch.object(audit.reader, "build_acore_npcs", side_effect=build), \
                 patch.object(audit, "source_signature", return_value=signature):
                saved = audit.load_source(*([ADDON_ROOT] * 6), signature, directory / "cache.json")
            self.assertIs(audit.sql_reader.load_row_table, before_sql)
            self.assertIs(audit.reader.load_row_table, before_npc)
            self.assertIs(audit.reader.load_sql_statements, before_statements)
            self.assertIs(audit.reader.apply_multirow_update, before_update)
            self.assertEqual(saved["diagnostics"]["missingFactionTemplateIds"], [])
            self.assertNotIn("n:3", saved["npcs"]["1"]["s:spawns"]["n:210"]["n:1"])
            skipped = saved["diagnostics"]["skippedSqlMutations"]
            self.assertEqual(len(skipped), 1)
            self.assertEqual(skipped[0]["statement"], statement)
            self.assertTrue(skipped[0]["file"].endswith("skipped.sql"))
            self.assertEqual(skipped[0]["operation"], "update")


if __name__ == "__main__":
    unittest.main()
