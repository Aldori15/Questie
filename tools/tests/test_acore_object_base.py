"""Object regeneration preserves migration parity and follows fresh source data."""
import contextlib
import copy
import io
import json
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_object_sources as audit
import db_snapshot
import generate_acore_object_base as exporter


def obj(**fields):
    return {"s:name": "Chest", "s:questStarts": {}, "s:questEnds": {}, "s:spawns": {},
            "s:zoneID": 0, "s:factionID": 0, **{"s:" + key: value for key, value in fields.items()}}


def typed(value):
    return audit.geometry.typed(value)


def origins(zone=210, identities=("gameobject:100", "gameobject:200")):
    return {"1": {"spawns": {f"n:{zone}": {f"n:{i}": [identity] for i, identity in enumerate(identities, 1)}}}}


def bootstrap(before, source, provenance=None):
    return exporter.make_manifest(before, source, provenance or {}, {}, "snapshot-sha", {"sourceRevision": "source-sha"})


class ObjectBaseTests(unittest.TestCase):
    def test_exact_parity_keeps_presence_sparse_slots_order_and_supplements(self):
        source = {1: obj(spawns=typed({210: [[10, 20, None, 3, 571], [30, 40]]}))}
        before = {1: {"s:name": "Chest", "s:spawns": {"n:210": {
            "n:2": typed([30, 40]), "n:7": typed([10, 20, None, 3, 571]), "n:9": typed([50, 60])}}}}
        manifest = bootstrap(before, source, origins())
        result = exporter.build_records(source, manifest, origins())
        self.assertEqual(result, before)
        self.assertNotIn("n:3", result[1]["s:spawns"]["n:210"]["n:7"])
        self.assertTrue(exporter.compare_records(before, result)["exactParity"])

    def test_spawn_guid_follows_coordinate_zone_and_phase_changes(self):
        source = {1: obj(spawns=typed({210: [[10, 20, None, 3, 571]]}), zoneID=210)}
        manifest = bootstrap(source, source, origins(identities=("gameobject:100",)))
        fresh = {1: obj(spawns=typed({12: [[11, 22, 4, 1, 0]]}), zoneID=12)}
        result = exporter.build_records(fresh, manifest, origins(12, ("gameobject:100",)))
        self.assertEqual(result, fresh)

    def test_removed_spawns_disappear_new_spawns_append_and_exclusions_remain(self):
        source = {1: obj(spawns=typed({210: [[10, 20], [30, 40]]}))}
        before = {1: obj(spawns=typed({210: [[10, 20]]}))}
        manifest = bootstrap(before, source, origins())
        fresh = {1: obj(spawns=typed({210: [[31, 41], [50, 60]]}))}
        result = exporter.build_records(fresh, manifest, origins(identities=("gameobject:200", "gameobject:300")))
        self.assertEqual(result[1]["s:spawns"], typed({210: [[50, 60]]}))

    def test_coincident_spawn_guids_can_split_after_source_update(self):
        source = {1: obj(spawns=typed({210: [[10, 20]]}))}
        merged = {"1": {"spawns": {"n:210": {"n:1": ["gameobject:100", "gameobject:200"]}}}}
        manifest = bootstrap(source, source, merged)
        fresh = {1: obj(spawns=typed({210: [[10, 20], [11, 21]]}))}
        self.assertEqual(exporter.build_records(fresh, manifest, origins()), fresh)

    def test_missing_coordinate_coverage_blocks_previously_mapped_spawns(self):
        source = {1: obj(spawns=typed({210: [[10, 20]]}))}
        manifest = bootstrap(source, source, origins(identities=("gameobject:100",)))
        missing = copy.deepcopy(source)
        del missing[1]["s:spawns"]
        with self.assertRaisesRegex(ValueError, "Object 1 spawns:.*unavailable"):
            exporter.build_records(missing, manifest, {})
        self.assertEqual(exporter.build_records({1: obj()}, manifest, {})[1]["s:spawns"], {})

    def test_legacy_unmapped_geometry_is_preserved_and_new_mapping_can_be_used(self):
        source = {1: obj()}
        del source[1]["s:spawns"]
        before = {1: obj(spawns=typed({210: [[50, 60]]}), zoneID=210)}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest, {}), before)
        fresh = {1: obj(spawns=typed({210: [[50, 60], [70, 80]]}), zoneID=210)}
        self.assertEqual(exporter.build_records(fresh, manifest, origins()), fresh)

    def test_template_exclusions_new_templates_and_placeholder_collisions(self):
        source = {1: obj(), 2: obj(name="Excluded")}
        before = {1: obj(), 400001: {"s:name": "Unlit Torch"}}
        manifest = bootstrap(before, source)
        self.assertEqual(manifest["excludedObjectIds"], [2])
        fresh = {**source, 3: obj(name="New object")}
        result = exporter.build_records(fresh, manifest, {})
        self.assertNotIn(2, result)
        self.assertEqual(result[3], fresh[3])
        self.assertEqual(result[400001], before[400001])
        with self.assertRaisesRegex(ValueError, "ID collision"):
            exporter.build_records({**source, 400001: obj()}, manifest, {})

    def test_name_and_zone_exceptions_are_conditional_on_original_source(self):
        source = {1: obj(name="Barrel 01", zoneID=0)}
        before = {1: obj(name="Barrel 1", zoneID=210)}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest, {}), before)
        fresh = {1: obj(name="Renamed Barrel 02", zoneID=12)}
        self.assertEqual(exporter.build_records(fresh, manifest, {}), fresh)

    def test_quest_relations_refresh_while_preserving_known_exclusions(self):
        source = {1: obj(questStarts=typed([10, 20, 30]))}
        before = {1: obj(questStarts=typed([20, 10]))}
        manifest = bootstrap(before, source)
        fresh = {1: obj(questStarts=typed([20, 30, 40]), questEnds=typed([50]))}
        result = exporter.build_records(fresh, manifest, {})
        self.assertEqual(result[1]["s:questStarts"], typed([20, 40]))
        self.assertEqual(result[1]["s:questEnds"], typed([50]))

    def test_omitted_nondefault_scalar_stays_absent_until_its_source_changes(self):
        source = {1: obj(zoneID=209, factionID=35)}
        before = copy.deepcopy(source)
        del before[1]["s:zoneID"]
        del before[1]["s:factionID"]
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest, {}), before)
        fresh = {1: obj(zoneID=210, factionID=36)}
        self.assertEqual(exporter.build_records(fresh, manifest, {}), fresh)
        self.assertTrue(manifest["overrides"]["1"]["zoneID"]["omit"])

    def test_geometry_identity_metadata_is_required_and_ambiguity_blocks(self):
        source = {1: obj(spawns=typed({210: [[10, 20]]}))}
        manifest = bootstrap(source, source, origins(identities=("gameobject:100",)))
        with self.assertRaisesRegex(ValueError, "identities are required"):
            exporter.build_records(source, manifest)
        fresh = {1: obj(spawns=typed({210: [[10, 20], [30, 40]]}))}
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            exporter.build_records(fresh, manifest, origins(identities=("gameobject:100", "gameobject:100")))

    def test_invalid_scope_and_unexpected_growth_or_removal_block(self):
        source = {1: obj()}
        manifest = bootstrap(source, source)
        invalid = copy.deepcopy(manifest)
        invalid["scope"]["1"] = True
        with self.assertRaisesRegex(ValueError, "field mask"):
            exporter.build_records(source, invalid, {})
        with self.assertRaisesRegex(ValueError, "removal"):
            exporter.build_records({}, manifest, {})
        manifest["limits"]["maxSpawnPoints"] = 1
        with self.assertRaisesRegex(ValueError, "spawn count"):
            exporter.build_records({1: obj(spawns=typed({210: [[10, 20], [30, 40]]}))}, manifest, {})

    def test_output_paths_allow_only_intended_base_or_local_candidates(self):
        self.assertEqual(exporter.local_path("Database/AzerothCore/acoreObjectDB.lua", "tools/reports", ".lua"),
                         ADDON_ROOT / "Database/AzerothCore/acoreObjectDB.lua")
        for path in ("Database/AzerothCore/acoreNpcDB.lua", "tools/reports/../../Questie.lua"):
            with self.assertRaises(ValueError):
                exporter.local_path(path, "tools/reports", ".lua")

    def test_reader_provenance_does_not_change_rows_or_invent_spawn_identity(self):
        reader = audit.reader
        templates = {1: {"name": "Chest"}}
        rows = [{"id": 1, "guid": 100}, {"id": 1, "guid": 200}]
        with patch.object(reader, "find_map_difficulty_dbc", return_value=None), \
             patch.object(reader, "load_map_difficulty_masks", return_value={}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda source, table, *a: (templates if table == "gameobject_template" else {}, 0)), \
             patch.object(reader, "load_rows_from_optional_sql_file", return_value=(rows, 0)), \
             patch.object(reader, "load_row_table", return_value=([], 0)), \
             patch.object(reader, "collect_item_object_source_ids", return_value=(set(), {})), \
             patch.object(reader, "parse_zone_maps", return_value={}), \
             patch.object(reader, "resolve_coordinate_zone", return_value=(210, [10, 20])), \
             patch.object(reader, "add_acore_spawn_visibility", side_effect=lambda point, *a: point):
            before = reader.build_acore_objects(ADDON_ROOT)
            provenance = {}
            after = reader.build_acore_objects(ADDON_ROOT, provenance=provenance)
        self.assertEqual(before, after)
        self.assertEqual(provenance["1"]["spawns"]["n:210"]["n:1"], ["gameobject:100", "gameobject:200"])

    def test_direct_generation_repeats_without_snapshot_archive_or_force(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            (directory / "tools/data").mkdir(parents=True)
            source = {1: obj(name="Barrel 01")}
            manifest = bootstrap(source, source)
            (directory / "tools/data/acore_object_compatibility.json").write_text(json.dumps(manifest), encoding="utf-8")
            saved = {"objects": {str(k): v for k, v in source.items()}, "geometryProvenance": {},
                     "diagnostics": {}, "tableCoverage": {}}
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit.coordinate_reader, "find_map_difficulty_dbc", return_value=directory / "MapDifficulty.dbc"), \
                 patch.object(exporter.audit, "source_signature", return_value={}), \
                 patch.object(exporter.audit, "load_source", return_value=saved), \
                 contextlib.redirect_stdout(io.StringIO()):
                for _ in range(2):
                    self.assertEqual(exporter.main(["--gameobject-sql", str(directory / "gameobject.sql")]), 0)
            output = (directory / "Database/AzerothCore/acoreObjectDB.lua").read_text()
            self.assertIn('QuestieDB.objectKeys', output)
            self.assertIn('QuestieDB.objectData', output)
            self.assertIn('Barrel 01', output)


if __name__ == "__main__":
    unittest.main()
