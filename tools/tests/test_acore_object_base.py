"""Object regeneration preserves migration parity and follows fresh source data."""
import contextlib
import copy
import io
import json
from pathlib import Path
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
    def test_reviewed_mapping_gap_uses_actual_source_and_requires_review_of_new_gaps(self):
        reader = audit.reader
        # A real Tirisfal placement plus deliberately synthetic coordinates far
        # outside every map. Native-map recovery now maps the former Azuremyst
        # example, so it is no longer a valid negative mapping fixture.
        placements = [
            {"guid": 201640, "id": 1731, "map": 0, "zoneId": 85, "areaId": 152,
             "position_x": 1572.09, "position_y": -687.518, "position_z": 57.2998,
             "spawnMask": 1, "phaseMask": 1},
            {"guid": 210259, "id": 1731, "map": 530, "zoneId": 3479, "areaId": 3479,
             "position_x": 1e9, "position_y": -1e9, "position_z": -12.0711,
             "spawnMask": 1, "phaseMask": 1},
        ]
        with patch.object(reader, "find_map_difficulty_dbc", return_value=Path("unused.dbc")), \
             patch.object(reader, "load_map_difficulty_masks", return_value={0: 1, 530: 1}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda root, table, *args:
                          ({1731: {"name": "Copper Vein"}} if table == "gameobject_template" else {}, 0)), \
             patch.object(reader, "load_rows_from_optional_sql_file", return_value=(placements, 0)), \
             patch.object(reader, "load_row_table", return_value=([], 0)), \
             patch.object(reader, "collect_item_object_source_ids", return_value=(set(), {})):
            provenance = {}
            records, _, _ = reader.build_acore_objects(ADDON_ROOT, repo_root=ADDON_ROOT, provenance=provenance)
        self.assertNotIn("spawns", records[1731])
        raw = {i: {"s:" + field: typed(value) for field, value in row.items()} for i, row in records.items()}
        # JSON round trip exercises the exact cache representation too.
        provenance = json.loads(json.dumps(provenance))
        coverage = provenance["1731"]["spawnCoverage"]
        self.assertEqual(coverage["unmappedGuids"], [210259])
        self.assertEqual(coverage["origins"]["n:85"]["n:1"], ["gameobject:201640"])
        self.assertEqual(coverage["mapped"]["n:85"]["n:1"]["n:6"], 1)
        self.assertEqual(coverage["mapped"]["n:85"]["n:1"]["n:7"], 152)
        before = {1731: {**raw[1731], "s:spawns": typed({85: [[10, 20]]})}}
        manifest = bootstrap(before, raw, provenance)
        self.assertEqual(exporter.build_records(raw, manifest, provenance), before)
        manifest["geometry"]["1731"] = {"slots": {}, "reviewedUnmappedGuids": [210259]}
        self.assertEqual(exporter.build_records(raw, manifest, provenance)[1731]["s:spawns"], coverage["mapped"])

        # Mapped placements move, disappear or arrive without an old baseline.
        coverage["mapped"] = typed({12: [[31, 41, 4], [50, 60]]})
        coverage["origins"] = {"n:12": {"n:1": ["gameobject:201640"], "n:2": ["gameobject:300000"]}}
        self.assertEqual(exporter.build_records(raw, manifest, provenance)[1731]["s:spawns"], coverage["mapped"])
        coverage["unmappedGuids"].append(400000)
        with self.assertRaisesRegex(ValueError, "New unmapped spawn GUIDs.*400000"):
            exporter.build_records(raw, manifest, provenance)
        coverage["unmappedGuids"] = [210259]
        with self.assertRaisesRegex(ValueError, "refresh the source model"):
            exporter.build_records(raw, manifest, {})
        coverage["origins"] = {}
        with self.assertRaisesRegex(ValueError, "lacks source identities"):
            exporter.build_records(raw, manifest, provenance)
        # If AC or client mapping fixes the previously unmapped point, it flows
        # in automatically; this is not a permanent source-GUID exclusion.
        resolved = {1731: {**raw[1731], "s:spawns": typed({12: [[10, 20], [30, 40]]})}}
        self.assertEqual(exporter.build_records(resolved, manifest, {})[1731]["s:spawns"], resolved[1731]["s:spawns"])

    def test_reviewed_mapping_policy_rejects_hidden_supplements_and_invalid_guids(self):
        source = {1: obj()}
        manifest = bootstrap(source, source)
        for guids in ([], [True], [0], [-1], [2, 1], [1, 1], "1"):
            with self.subTest(guids=guids):
                manifest["geometry"]["1"] = {"slots": {}, "reviewedUnmappedGuids": guids}
                with self.assertRaisesRegex(ValueError, "Invalid reviewed"):
                    exporter.build_records(source, manifest, {})
        manifest["geometry"]["1"] = {"slots": {"n:12": {"n:1": {"value": typed([10, 20])}}},
                                      "reviewedUnmappedGuids": [1]}
        with self.assertRaisesRegex(ValueError, "without supplements"):
            exporter.build_records(source, manifest, {})

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

    def test_scripted_object_cli_forwards_context_reports_gaps_and_rejects_missing_context_atomically(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            manifest_path = directory / "tools/data/acore_object_compatibility.json"
            manifest_path.parent.mkdir(parents=True)
            source = {1: obj(name="Source summon"), 2: obj(name="Unmapped helper")}
            manifest = bootstrap(source, source)
            manifest["geometry"]["1"] = {"slots": {}, "sourceScripted": True}
            manifest["geometryPolicy"] = "verified-source-only-v1"
            manifest["geometryAudit"] = {"version": 1, "reviewedFields": {"1": ["spawns"], "2": ["spawns"]}}
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            packet = {"version": 1, "actorContextAvailable": True, "entries": {
                "1": {"spawns": typed({12: [[30, 40]]}), "waypoints": {},
                      "origins": {"spawns": {"n:12": {"n:1": ["smart-summon:0:10:1:0:map:0"]}}},
                      "failures": {"spawns": [], "waypoints": []}}}}
            saved = {"objects": {str(k): v for k, v in source.items()},
                     "geometryProvenance": {"scriptedGeometry": packet}, "diagnostics": {}, "tableCoverage": {}}
            creature, multispawn = directory / "creature.sql", directory / "creature_multispawn.sql"
            spell = directory / "spell.sql"
            output = directory / "Database/AzerothCore/acoreObjectDB.lua"
            report = directory / "tools/reports/acore_object_base_candidate.json"
            args = ["--gameobject-sql", str(directory / "gameobject.sql"),
                    "--creature-sql", str(creature), "--creature-multispawn-sql", str(multispawn), "--spell-sql", str(spell)]
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit.coordinate_reader, "find_map_difficulty_dbc", return_value=directory / "MapDifficulty.dbc"), \
                 patch.object(exporter.audit, "source_signature", return_value={}) as signature, \
                 patch.object(exporter.audit, "load_source", return_value=saved) as load, \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(exporter.main(args), 0)
                self.assertEqual(load.call_args.kwargs, {"creature": creature.resolve(), "multispawn": multispawn.resolve(), "spell": spell.resolve()})
                self.assertTrue(all(call.kwargs == load.call_args.kwargs for call in signature.call_args_list))
                generated, review = output.read_bytes(), json.loads(report.read_text(encoding="utf-8"))
                self.assertEqual(review["geometryAudit"]["coverageGapRecords"], 1)
                self.assertEqual(set(review["geometryAudit"]["coverageGaps"]), {"2"})
                self.assertNotIn(b"coverageGaps", generated)
                self.assertNotIn(b"reviewedFields", generated)
                self.assertIn(b"[1]=30", generated)
                packet["actorContextAvailable"] = False
                for invocation in (args, ["--gameobject-sql", str(directory / "gameobject.sql")]):
                    with self.subTest(invocation=invocation), self.assertRaisesRegex(ValueError, "actor context is unavailable"):
                        exporter.main(invocation)
                    self.assertEqual(output.read_bytes(), generated)
                    self.assertEqual(json.loads(report.read_text(encoding="utf-8")), review)

    def test_object_cache_extraction_tracks_supplied_actor_exports_and_smart_rows(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            creature, multispawn = directory / "creature.sql", directory / "creature_multispawn.sql"
            exports = {"creature": [{"guid": 100, "id": 10}],
                       "creature_multispawn": [{"spawnId": 100, "entry": 20}]}
            def build(source, **kwargs):
                self.assertEqual(kwargs["creature_sql"], creature)
                self.assertEqual(kwargs["creature_multispawn_sql"], multispawn)
                audit.reader.load_rows_from_sql_file(creature, "creature", ("guid",))
                audit.reader.load_rows_from_sql_file(multispawn, "creature_multispawn", ("spawnId", "entry"))
                audit.reader.load_filtered_row_table(source, "smart_scripts", ("entryorguid",), lambda row: True)
                kwargs["provenance"]["scriptedGeometry"] = {"version": 1, "entries": {}, "actorContextAvailable": True}
                return {1: {"name": "Object"}}, {}, set()
            with patch.object(audit, "source_signature", return_value={}), \
                 patch.object(audit.reader, "build_acore_objects", side_effect=build), \
                 patch.object(audit.reader, "load_rows_from_sql_file", side_effect=lambda path, table, keys, *a: (exports[table], 0)), \
                 patch.object(audit.reader, "load_filtered_row_table", return_value=([{"entryorguid": 10}], 0)), \
                 contextlib.redirect_stdout(io.StringIO()):
                saved = audit.load_source(directory, directory, directory / "gameobject.sql", directory / "MapDifficulty.dbc",
                                          directory, {}, directory / "cache.json", creature=creature, multispawn=multispawn)
            self.assertEqual(set(saved["tableCoverage"]), {"creature", "creature_multispawn", "smart_scripts"})
            self.assertTrue(all(row["rows"] == 1 and row["skippedMutations"] == 0 for row in saved["tableCoverage"].values()))
            self.assertTrue(saved["geometryProvenance"]["scriptedGeometry"]["actorContextAvailable"])
            self.assertEqual(saved["modelSha256"], audit.model_digest(saved))


if __name__ == "__main__":
    unittest.main()
