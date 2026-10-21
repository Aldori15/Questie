"""NPC generation preserves the baseline without depending on legacy databases."""
import contextlib
import copy
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_npc_sources as audit
import db_snapshot
import generate_acore_npc_base as exporter


def npc(**fields):
    return {"s:name": "NPC", "s:minLevel": 1, **{"s:" + key: value for key, value in fields.items()}}


def bootstrap(before, source):
    return exporter.make_manifest(before, source, {"git": None}, "snapshot-sha", {"sourceRevision": "source-sha"})


class NpcBaseTests(unittest.TestCase):
    def test_direct_generation_reports_reviewed_mapping_gaps_and_publishes_deterministically(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            (directory / "tools/data").mkdir(parents=True)
            source = {1: npc(name="NPC 01", waypoints={})}
            before = {1: npc(name="NPC 01", waypoints={}, spawns=audit.typed({12: [[10, 20]]}))}
            provenance = {"1": {"spawnCoverage": {
                "unmappedGuids": [99], "mapped": audit.typed({12: [[31, 41]]}),
                "origins": {"n:12": {"n:1": ["creature:100:entry:1"]}},
            }}}
            manifest = exporter.upgrade_manifest(bootstrap(before, source), source, provenance)
            manifest["geometry"]["1"]["spawns"] = {"slots": {}, "reviewedUnmappedGuids": [99]}
            manifest["geometry"]["1"]["waypoints"] = {"slots": {}, "sourceScripted": True}
            provenance["scriptedGeometry"] = {"version": 1, "entries": {"1": {
                "spawns": {}, "waypoints": audit.typed({12: [[[31, 41]]]}),
                "origins": {"waypoints": {"n:12": {"n:1": ["smart-path:fixture"]}}},
                "failures": {"spawns": [], "waypoints": []},
            }}}
            (directory / "tools/data/acore_npc_compatibility.json").write_text(json.dumps(manifest), encoding="utf-8")
            saved = {"npcs": {str(k): v for k, v in source.items()},
                     "geometryProvenance": provenance, "diagnostics": {}}
            arguments = ["--creature-sql", str(directory / "creature.sql"),
                         "--creature-multispawn-sql", str(directory / "creature_multispawn.sql")]
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(audit.reader, "find_map_difficulty_dbc", return_value=directory / "MapDifficulty.dbc"), \
                 patch.object(audit, "source_signature", return_value={}), \
                 patch.object(audit, "load_source", return_value=saved), \
                 contextlib.redirect_stdout(io.StringIO()):
                previous = None
                for _ in range(2):
                    self.assertEqual(exporter.main(arguments), 0)
                    output = directory / "Database/AzerothCore/acoreNpcDB.lua"
                    report = directory / "tools/reports/acore_npc_base_candidate.json"
                    contents = output.read_bytes()
                    summary = json.loads(report.read_text(encoding="utf-8"))
                    self.assertEqual(summary["counts"]["reviewedUnmappedSpawnPlacements"], 1)
                    self.assertEqual(summary["counts"]["scriptedGeometryIds"], [1])
                    self.assertEqual(summary["reviewedUnmappedSpawns"], {"1": [99]})
                    self.assertEqual(summary["outputSha256"], db_snapshot.file_hash(output))
                    self.assertEqual(summary["outputBytes"], len(contents))
                    self.assertIn(b'NPC 01', contents)
                    self.assertIn(b'31', contents)
                    self.assertNotIn(b'spawnCoverage', contents)
                    if previous is not None:
                        self.assertEqual(contents, previous)
                    previous = contents
                previous_report = report.read_bytes()
                provenance["1"]["spawnCoverage"]["unmappedGuids"].append(101)
                with self.assertRaisesRegex(ValueError, "New unmapped spawn GUIDs.*101"):
                    exporter.main(arguments)
                self.assertEqual(output.read_bytes(), previous)
                self.assertEqual(report.read_bytes(), previous_report)

    def test_partial_spawn_review_keeps_multispawn_identity_and_visibility(self):
        reader = audit.reader
        placements = [{"guid": guid, "id1": 1, "map": 571, "position_x": x,
                       "position_y": 20, "phaseMask": 4, "spawnMask": 3, "zoneId": 210, "areaId": 4500}
                      for guid, x in ((99, 10), (100, -1))]
        keyed = {"creature_template": {i: {"name": "NPC", "minlevel": 1, "maxlevel": 1} for i in (1, 2)}}
        rows = {"creature": placements, "creature_queststarter": [{"id": 1, "quest": 1000}]}
        with patch.object(reader, "find_map_difficulty_dbc", return_value=Path("unused.dbc")), \
             patch.object(reader, "load_map_difficulty_masks", return_value={571: 1}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda root, table, *args: (keyed.get(table, {}), 0)), \
             patch.object(reader, "load_row_table", side_effect=lambda root, table, *args: (rows.get(table, []), 0)), \
             patch.object(reader, "load_creature_multispawn_rows", return_value=([
                 {"spawnId": guid, "entry": 2} for guid in (99, 100)], 0)), \
             patch.object(reader, "load_filtered_row_table", return_value=([], 0)), \
             patch.object(reader, "load_server_phase_profiles", return_value=({571: {210: True}}, {}, {})), \
             patch.object(reader, "parse_zone_maps", return_value={}), \
             patch.object(reader, "resolve_coordinate_zone", side_effect=lambda row, maps:
                          (210, [row["position_x"], row["position_y"]]) if row["position_x"] >= 0 else (None, None)), \
             patch.object(reader, "load_wintergrasp_scripted_spawns", return_value={}):
            provenance = {}
            records, _ = reader.build_acore_npcs(ADDON_ROOT, provenance=provenance)
        source = {i: {"s:" + field: audit.typed(value) for field, value in row.items()} for i, row in records.items()}
        before = {i: {**row, "s:spawns": audit.typed({210: [[50, 60]]})} for i, row in source.items()}
        manifest = exporter.upgrade_manifest(bootstrap(before, source), source, provenance)
        for entry in (1, 2):
            self.assertNotIn("s:spawns", source[entry])
            coverage = provenance[str(entry)]["spawnCoverage"]
            self.assertEqual(coverage["unmappedGuids"], [100])
            self.assertEqual(coverage["origins"]["n:210"]["n:1"], [f"creature:99:entry:{entry}"])
            point = coverage["mapped"]["n:210"]["n:1"]
            self.assertEqual(point["n:6"], 4)
            self.assertEqual(point["n:4"], 3)
            if entry == 1:
                self.assertEqual(point["n:8"], 99)
            manifest["geometry"][str(entry)]["spawns"] = {"slots": {}, "reviewedUnmappedGuids": [100]}
        result = exporter.build_records(source, manifest, provenance)
        for entry in (1, 2):
            self.assertEqual(result[entry]["s:spawns"], provenance[str(entry)]["spawnCoverage"]["mapped"])
        provenance["1"]["spawnCoverage"]["unmappedGuids"].append(101)
        with self.assertRaisesRegex(ValueError, "NPC 1 spawns: New unmapped.*101"):
            exporter.build_records(source, manifest, provenance)

    def test_scripted_placements_refresh_preserve_phase_and_drop_parent_identity(self):
        points = audit.typed({12: [[1, 2, 0, 1, 0, 4, 12, 98765]]})
        source = {6492: npc(spawns=points), 32823: npc(spawns=points)}
        selected = exporter.scripted_spawn_sources(source, source)
        self.assertEqual(selected[6492]["n:12"]["n:1"]["n:6"], 4)
        self.assertNotIn("n:8", selected[6492]["n:12"]["n:1"])
        self.assertEqual(points["n:12"]["n:1"]["n:8"], 98765)
        source[6492]["s:spawns"] = audit.typed({12: [[3, 4], [5, 6]]})
        self.assertEqual(len(exporter.scripted_spawn_sources(source, source)[6492]["n:12"]), 2)
        output = io.StringIO()
        exporter.write_stream(output, source, selected)
        self.assertIn("QuestieDB.scriptedSpawnSources", output.getvalue())
        self.assertEqual(len(output.getvalue().encode()), exporter.candidate_size(source, selected))
        source[6492]["s:spawns"] = {}
        with self.assertRaisesRegex(ValueError, "Missing scripted spawn source geometry"):
            exporter.scripted_spawn_sources(source, source)

    def test_source_backed_geometry_reorders_points_and_preserves_sparse_metadata(self):
        raw = audit.typed({210: [[10, 20, None, 3, 571, 100, 200, 1], [30, 40]]})
        desired = {"n:210": {"n:2": raw["n:210"]["n:2"], "n:7": raw["n:210"]["n:1"]}}
        recipe = exporter.encode_geometry(desired, raw)
        self.assertEqual(recipe["zones"]["n:210"]["refs"], [2, 1])
        self.assertEqual(exporter.decode_geometry(recipe, raw), desired)
        self.assertNotIn("n:3", exporter.decode_geometry(recipe, raw)["n:210"]["n:7"])

    def test_waypoint_order_and_legacy_points_are_retained(self):
        raw = audit.typed({210: [[[10, 20], [30, 40]], [[50, 60], [70, 80]]]})
        desired = audit.typed({210: [[[50, 60], [70, 80]], [[10, 20], [30, 40]], [[90, 95]]]})
        recipe = exporter.encode_geometry(desired, raw)
        self.assertEqual(recipe["zones"]["n:210"]["refs"], [2, 1, 0])
        self.assertEqual(exporter.decode_geometry(recipe, raw), desired)
        altered = copy.deepcopy(raw)
        altered["n:210"]["n:1"]["n:1"]["n:1"] = 11
        with self.assertRaisesRegex(ValueError, "Source geometry changed"):
            exporter.decode_geometry(recipe, altered)

    def test_new_npcs_zones_and_relations_do_not_expand_existing_scope(self):
        source = {1: npc(spawns=audit.typed({210: [[10, 20]]}), questStarts=audit.typed([10]))}
        before = copy.deepcopy(source)
        manifest = bootstrap(before, source)
        changed = copy.deepcopy(source)
        changed[2] = npc()
        changed[1]["s:spawns"]["n:4197"] = audit.typed([[30, 40]])
        changed[1]["s:questStarts"] = audit.typed([10, 20])
        self.assertEqual(exporter.build_records(changed, manifest), before)
        changed[1]["s:spawns"]["n:210"]["n:2"] = audit.typed([30, 40])
        with self.assertRaisesRegex(ValueError, "Source geometry changed"):
            exporter.build_records(changed, manifest)

    def test_display_health_zone_and_field_presence_are_explicit(self):
        source = {1: npc(minLevelHealth=500, maxLevelHealth=900, zoneID=210, npcFlags=0)}
        before = {1: npc(minLevelHealth=100, maxLevelHealth=200, zoneID=12, spawns={})}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        source[1]["s:minLevelHealth"] = 600
        source[1]["s:maxLevelHealth"] = 1000
        self.assertEqual(exporter.build_records(source, manifest), before)
        self.assertNotIn("s:npcFlags", exporter.build_records(source, manifest)[1])

    def test_missing_template_placeholders_are_preserved_but_id_collisions_fail(self):
        source = {1: npc()}
        before = {1: npc(), 80000: {"s:name": "Objective", "s:zoneID": 67}}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        with self.assertRaisesRegex(ValueError, "now has a source template"):
            exporter.build_records({**source, 80000: npc()}, manifest)
        with self.assertRaisesRegex(ValueError, "lost its source template"):
            exporter.build_records({}, manifest)

    def test_name_exception_guards_against_future_source_changes(self):
        source = {1: npc(name="Placeholder 05")}
        before = {1: npc(name="Placeholder 5")}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        with self.assertRaisesRegex(ValueError, "Source name changed"):
            exporter.build_records({1: npc(name="Renamed NPC")}, manifest)

    def test_missing_selected_quest_relation_stops_regeneration(self):
        source = {1: npc(questStarts=audit.typed([10]))}
        manifest = bootstrap(copy.deepcopy(source), source)
        with self.assertRaisesRegex(ValueError, "Selected quest relations changed"):
            exporter.build_records({1: npc(questStarts={})}, manifest)

    def test_invalid_masks_and_expanded_geometry_budgets_are_rejected(self):
        source = {1: npc(spawns=audit.typed({210: [[10, 20]]}))}
        manifest = bootstrap(source, source)
        invalid = copy.deepcopy(manifest)
        invalid["scope"]["1"] = True
        with self.assertRaisesRegex(ValueError, "field mask"):
            exporter.validate_manifest(invalid)
        manifest["limits"]["geometry"]["spawns"]["points"] = 0
        with self.assertRaisesRegex(ValueError, "budget exceeded"):
            exporter.build_records(source, manifest)

    def test_numeric_hashing_matches_lua_numbers_and_distinguishes_absence(self):
        self.assertEqual(exporter.value_hash({"n:1": 10}), exporter.value_hash({"n:1": 10.0}))
        self.assertNotEqual(exporter.value_hash(False), exporter.value_hash(0))
        self.assertNotEqual(exporter.value_hash(exporter.shared.ABSENT), exporter.value_hash({}))

    def test_exact_comparison_catches_order_presence_and_record_scope(self):
        before = {1: npc(spawns=audit.typed({210: [[10, 20], [30, 40]]}))}
        for after in ({}, {1: npc()}, {1: npc(spawns=audit.typed({210: [[30, 40], [10, 20]]}))}):
            self.assertFalse(exporter.compare_records(before, after)["exactParity"])

    def test_cli_generation_is_independent_of_snapshot_and_enforces_size_limit(self):
        source = {1: npc(spawns=audit.typed({210: [[10, 20]]})), 2: npc()}
        before = {1: npc(spawns=audit.typed({210: [[10, 20], [30, 40]]}))}
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            snapshot = directory / "snapshot.jsonl"
            snapshot.write_text("fixture", encoding="utf-8")
            signature = {"sourceRevision": "source"}
            saved = {"npcs": {str(k): v for k, v in source.items()}, "diagnostics": {}}
            args = ["--acore-source", str(directory), "--creature-sql", str(directory / "creature.sql"),
                    "--creature-multispawn-sql", str(directory / "multi.sql")]
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit, "source_signature", return_value=signature), \
                 patch.object(exporter.audit, "load_source", return_value=saved), \
                 patch.object(exporter.audit.reader, "find_map_difficulty_dbc", return_value=directory / "difficulty.dbc"), \
                 contextlib.redirect_stdout(io.StringIO()):
                with patch.object(exporter.shared, "read_static_records", return_value=(before, list(exporter.FIELDS), {}, {"sources": {}})):
                    self.assertEqual(exporter.main(["bootstrap", "--snapshot", str(snapshot), *args]), 0)
                with patch.object(exporter.shared, "read_static_records", side_effect=AssertionError("Snapshot dependency")):
                    self.assertEqual(exporter.main(["generate", *args]), 0)
                manifest_path = directory / exporter.DEFAULT_MANIFEST
                manifest = json.loads(manifest_path.read_text())
                self.assertEqual(exporter.build_records(source, manifest), before)
                output = directory / "Database/AzerothCore/acoreNpcDB.lua"
                existing = output.read_bytes()
                self.assertEqual(exporter.main(args), 0)
                manifest["limits"]["maxOutputBytes"] = 1
                exporter.write_manifest(manifest_path, manifest)
                with self.assertRaisesRegex(ValueError, "size budget"):
                    exporter.main(["generate", "--force", *args])
                self.assertEqual(output.read_bytes(), existing)
                saved["diagnostics"] = {"skippedSqlMutations": [{"statement": "unsupported"}]}
                with self.assertRaisesRegex(ValueError, "source diagnostics"):
                    exporter.main(["generate", "--force", *args])

    def test_current_geometry_follows_moves_additions_removals_and_source_reordering(self):
        old = {1: npc(spawns=audit.typed({210: [[10, 20, None, 3, 571], [30, 40], [50, 60]]}))}
        before = {1: npc(spawns=audit.typed({210: [[10, 20, None, 3, 571], [30, 40], [70, 80]]}))}
        origins = {"1": {"spawns": {"n:210": {"n:1": ["guid:1"], "n:2": ["guid:2"], "n:3": ["guid:3"]}}}}
        manifest = exporter.upgrade_manifest(bootstrap(before, old), old, origins)
        self.assertEqual(exporter.build_records(old, manifest, origins), before)
        fresh = {1: npc(spawns=audit.typed({210: [[50, 60], [90, 95]], 12: [[11, 21, None, 1, 571]]}))}
        new_origins = {"1": {"spawns": {"n:210": {"n:1": ["guid:3"], "n:2": ["guid:4"]}, "n:12": {"n:1": ["guid:1"]}}}}
        result = exporter.build_records(fresh, manifest, new_origins)[1]["s:spawns"]
        self.assertEqual(result["n:12"]["n:1"], audit.typed([11, 21, None, 1, 571]))
        self.assertNotIn("n:3", result["n:12"]["n:1"])
        self.assertEqual(list(result["n:210"].values()), [audit.typed([70, 80]), audit.typed([90, 95])])
        # The removed GUID 2 disappears; deliberately excluded GUID 3 stays out.
        with self.assertRaisesRegex(ValueError, "identities"):
            exporter.build_records(fresh, manifest)

    def test_current_relations_and_previously_absent_fields_follow_fresh_source(self):
        old = {1: npc(questStarts=audit.typed([10, 20]), questEnds={}, npcFlags=0)}
        before = {1: npc(questStarts=audit.typed([10]))}
        manifest = exporter.upgrade_manifest(bootstrap(before, old), old, {})
        self.assertEqual(exporter.build_records(old, manifest, {}), before)
        fresh = {1: npc(questStarts=audit.typed([20, 30]), questEnds=audit.typed([40]), npcFlags=2)}
        result = exporter.build_records(fresh, manifest, {})[1]
        self.assertEqual(result["s:questStarts"], {"n:1": 30})
        self.assertEqual(result["s:questEnds"], {"n:1": 40})
        self.assertEqual(result["s:npcFlags"], 2)

    def test_current_source_zone_and_name_update_but_display_health_remains_explicit(self):
        old = {1: npc(name="Prototype 01", zoneID=210, minLevelHealth=70)}
        before = {1: npc(name="Prototype 1", zoneID=777, minLevelHealth=100)}
        manifest = exporter.upgrade_manifest(bootstrap(before, old), old, {})
        self.assertEqual(exporter.build_records(old, manifest, {}), before)
        fresh = {1: npc(name="Renamed", zoneID=12, minLevelHealth=5)}
        result = exporter.build_records(fresh, manifest, {})[1]
        self.assertEqual((result["s:name"], result["s:zoneID"], result["s:minLevelHealth"]), ("Renamed", 12, 100))

    def test_current_path_identity_uses_fresh_point_order_without_an_old_cache(self):
        old = {1: npc(waypoints=audit.typed({210: [[[10, 20], [30, 40]]]}))}
        origins = {"1": {"waypoints": {"n:210": {"n:1": ["path:1"]}}}}
        manifest = exporter.upgrade_manifest(bootstrap(old, old), old, origins)
        fresh = {1: npc(waypoints=audit.typed({210: [[[11, 21], [25, 35], [30, 40]]]}))}
        self.assertEqual(exporter.build_records(fresh, manifest, origins), fresh)

    def test_new_npcs_are_generated_while_known_omissions_stay_excluded(self):
        original = {1: npc(), 2: npc()}
        manifest = exporter.upgrade_manifest(bootstrap({1: original[1]}, original), original, {})
        fresh = {**original, 3: npc(name="New NPC", minLevelHealth=100)}
        result = exporter.build_records(fresh, manifest, {})
        self.assertEqual(set(result), {1, 3})
        self.assertEqual(result[3]["s:name"], "New NPC")
        self.assertNotIn("s:minLevelHealth", result[3])

    def test_coincident_spawns_can_split_without_losing_either_source(self):
        old = {1: npc(spawns=audit.typed({210: [[10, 20]]}))}
        origins = {"1": {"spawns": {"n:210": {"n:1": ["guid:1", "guid:2"]}}}}
        manifest = exporter.upgrade_manifest(bootstrap(old, old), old, origins)
        fresh = {1: npc(spawns=audit.typed({210: [[11, 21], [10, 20]]}))}
        new_origins = {"1": {"spawns": {"n:210": {"n:1": ["guid:1"], "n:2": ["guid:2"]}}}}
        self.assertEqual(exporter.build_records(fresh, manifest, new_origins), fresh)

    def test_identity_collection_does_not_change_reader_output(self):
        reader = audit.reader
        creature = {"guid": 99, "id1": 1, "map": 571, "position_x": 10, "position_y": 20}
        keyed = {"creature_template": {1: {"name": "NPC", "minlevel": 1, "maxlevel": 1}},
                 "factiontemplate_dbc": {}, "creature_addon": {99: {"path_id": 88}}}
        rows = {"creature": [creature], "creature_queststarter": [{"id": 1, "quest": 100}],
                "waypoint_data": [{"id": 88, "point": 1, "position_x": 10, "position_y": 20},
                                  {"id": 88, "point": 2, "position_x": 30, "position_y": 40}]}
        with patch.object(reader, "find_map_difficulty_dbc", return_value=Path("unused.dbc")), \
             patch.object(reader, "load_map_difficulty_masks", return_value={571: 1}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda root, table, *args: (keyed.get(table, {}), 0)), \
             patch.object(reader, "load_row_table", side_effect=lambda root, table, *args: (rows.get(table, []), 0)), \
             patch.object(reader, "load_creature_multispawn_rows", return_value=([], 0)), \
             patch.object(reader, "load_filtered_row_table", return_value=([], 0)), \
             patch.object(reader, "parse_zone_maps", return_value={}), \
             patch.object(reader, "resolve_coordinate_zone", side_effect=lambda row, maps:
                          (210, [row["position_x"], row["position_y"]])), \
             patch.object(reader, "load_wintergrasp_scripted_spawns", return_value={}):
            before = reader.build_acore_npcs(ADDON_ROOT)
            provenance = {}
            after = reader.build_acore_npcs(ADDON_ROOT, provenance=provenance)
        self.assertEqual(before, after)
        self.assertEqual(provenance["1"]["spawns"]["n:210"]["n:1"], ["creature:99:entry:1"])
        self.assertEqual(provenance["1"]["waypoints"]["n:210"]["n:1"],
                         ["waypoint_data:88:addon:99:map-spawn:99:entry:1"])

    def test_single_waypoint_destinations_keep_source_identity_and_refresh(self):
        reader = audit.reader
        creature = {"guid": 99, "id1": 1, "map": 571, "position_x": 10, "position_y": 20}
        destination = {"id": 88, "point": 1, "position_x": 30, "position_y": 40}
        keyed = {"creature_template": {1: {"name": "NPC", "minlevel": 1, "maxlevel": 1}},
                 "factiontemplate_dbc": {}, "creature_addon": {99: {"path_id": 88}}}
        rows = {"creature": [creature], "waypoint_data": [destination],
                "waypoints": [{"entry": 77, "pointid": 1, "position_x": 50, "position_y": 60}]}
        smart = [{"source_type": 0, "entryorguid": 1, "action_type": 53, "action_param2": 77}]
        with patch.object(reader, "find_map_difficulty_dbc", return_value=Path("unused.dbc")), \
             patch.object(reader, "load_map_difficulty_masks", return_value={571: 1}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda root, table, *args: (keyed.get(table, {}), 0)), \
             patch.object(reader, "load_row_table", side_effect=lambda root, table, *args: (rows.get(table, []), 0)), \
             patch.object(reader, "load_creature_multispawn_rows", return_value=([], 0)), \
             patch.object(reader, "load_filtered_row_table", return_value=(smart, 0)), \
             patch.object(reader, "parse_zone_maps", return_value={}), \
             patch.object(reader, "resolve_coordinate_zone", side_effect=lambda row, maps:
                          (210, [row["position_x"], row["position_y"]])), \
             patch.object(reader, "load_wintergrasp_scripted_spawns", return_value={}):
            origins = {}
            actual, _ = reader.build_acore_npcs(ADDON_ROOT, provenance=origins)
            self.assertEqual(actual[1]["waypoints"], {210: [[[30, 40]], [[50, 60]]]})
            self.assertEqual(origins["1"]["waypoints"]["n:210"]["n:1"],
                             ["waypoint_data:88:addon:99:map-spawn:99:entry:1"])
            self.assertEqual(origins["1"]["waypoints"]["n:210"]["n:2"],
                             ["waypoints:77:smart:1:map-spawn:99:entry:1"])
            # An action point at the spawn is still one point, not a fake patrol.
            destination.update(position_x=10, position_y=20)
            stationary, _ = reader.build_acore_npcs(ADDON_ROOT)
            self.assertEqual(stationary[1]["waypoints"][210][0], [[10, 20]])

        source = {1: npc(waypoints=audit.typed(actual[1]["waypoints"]))}
        manifest = exporter.upgrade_manifest(bootstrap(source, source), source, origins)
        moved = copy.deepcopy(source)
        moved[1]["s:waypoints"]["n:210"]["n:1"] = audit.typed([[35, 45]])
        self.assertEqual(exporter.build_records(moved, manifest, origins), moved)
        removed = {1: npc(waypoints={})}
        self.assertEqual(exporter.build_records(removed, manifest, {}), removed)
        # Once inherited routes are removed, future paths need no replacement
        # compatibility data: their destinations come straight from AC.
        del manifest["geometry"]["1"]["waypoints"]
        self.assertEqual(exporter.build_records(moved, manifest, origins), moved)
        self.assertEqual(exporter.build_records(removed, manifest, {}), removed)

    def test_template_paths_obey_guid_precedence_and_each_multispawn_template(self):
        reader = audit.reader
        creature = {"guid": 99, "id1": 1, "id2": 2, "map": 571, "position_x": 10, "position_y": 20}
        keyed = {"creature_template": {i: {"name": "NPC", "minlevel": 1, "maxlevel": 1} for i in range(1, 5)},
                 "factiontemplate_dbc": {}, "creature_addon": {},
                 "creature_template_addon": {1: {"path_id": 77}, 2: {"path_id": 66}, 3: {"path_id": 55}}}
        destination = {"id": 77, "point": 1, "position_x": 30, "position_y": 40}
        rows = {"creature": [creature], "waypoint_data": [destination,
                {"id": 66, "point": 1, "position_x": 50, "position_y": 60},
                {"id": 55, "point": 1, "position_x": 70, "position_y": 80},
                {"id": 88, "point": 1, "position_x": 90, "position_y": 95}]}

        def build():
            origins = {}
            actual, stats = reader.build_acore_npcs(ADDON_ROOT, provenance=origins)
            return actual, origins, stats

        with patch.object(reader, "find_map_difficulty_dbc", return_value=Path("unused.dbc")), \
             patch.object(reader, "load_map_difficulty_masks", return_value={571: 1}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda root, table, *args: (keyed.get(table, {}), 0)), \
             patch.object(reader, "load_row_table", side_effect=lambda root, table, *args: (rows.get(table, []), 0)), \
             patch.object(reader, "load_creature_multispawn_rows", return_value=(
                 [{"spawnId": 99, "entry": 3}, {"spawnId": 99, "entry": 4}], 0)), \
             patch.object(reader, "load_filtered_row_table", return_value=([], 0)), \
             patch.object(reader, "parse_zone_maps", return_value={}), \
             patch.object(reader, "resolve_coordinate_zone", side_effect=lambda row, maps:
                          (210, [row["position_x"], row["position_y"]])), \
             patch.object(reader, "load_wintergrasp_scripted_spawns", return_value={}):
            actual, origins, stats = build()
            self.assertEqual(stats["creature_template_addon"], 0)
            for entry, point in [(1, [30, 40]), (2, [50, 60]), (3, [70, 80])]:
                self.assertEqual(actual[entry]["waypoints"], {210: [[point]]})
            self.assertEqual(actual[4]["waypoints"], {})
            origin = "waypoint_data:77:template-addon:1:map-spawn:99:entry:1"
            self.assertEqual(origins["1"]["waypoints"]["n:210"]["n:1"], [origin])
            # A template entry can numerically equal a GUID. Keep its binding
            # distinct from a real GUID addon instead of aliasing identities.
            self.assertNotEqual(exporter.identity_key(origin), exporter.identity_key(
                "waypoint_data:77:addon:1:map-spawn:99:entry:1"))

            source = {i: {"s:" + field: audit.typed(value) for field, value in record.items()}
                      for i, record in actual.items()}
            manifest = exporter.upgrade_manifest(bootstrap(source, source), source, origins)
            # Routine generation follows future path moves and deletions; it
            # needs neither a new bootstrap nor an archived source checkout.
            destination.update(position_x=35, position_y=45)
            del keyed["creature_template_addon"][2]
            fresh, fresh_origins, _ = build()
            fresh = {i: {"s:" + field: audit.typed(value) for field, value in record.items()}
                     for i, record in fresh.items()}
            self.assertEqual(exporter.build_records(fresh, manifest, fresh_origins), fresh)
            self.assertEqual(fresh[1]["s:waypoints"], audit.typed({210: [[[35, 45]]]}))
            self.assertEqual(fresh[2]["s:waypoints"], {})

            # GUID addons apply to all possible entries at that spawn and
            # override template paths, including an explicitly absent path.
            for addon, expected in [({"path_id": 88}, {210: [[[90, 95]]]}),
                                    ({"path_id": 0}, {}), ({}, {}), ({"path_id": 999}, {})]:
                with self.subTest(guidAddon=addon):
                    keyed["creature_addon"][99] = addon
                    actual, _, _ = build()
                    for entry in range(1, 5):
                        self.assertEqual(actual[entry]["waypoints"], expected)

    def _read_waypoint_fixture(self, points, resolve, creature=None, maps=None):
        reader = audit.reader
        creature = creature or {"guid": 99, "id1": 1, "map": 571, "position_x": 0, "position_y": 0}
        keyed = {"creature_template": {1: {"name": "NPC", "minlevel": 1, "maxlevel": 1}},
                 "factiontemplate_dbc": {}, "creature_addon": {99: {"path_id": 88}}}
        rows = {"creature": [creature], "waypoint_data": [dict(point, id=88) for point in points]}
        with patch.object(reader, "find_map_difficulty_dbc", return_value=Path("unused.dbc")), \
             patch.object(reader, "load_map_difficulty_masks", return_value={571: 1}), \
             patch.object(reader, "load_keyed_table", side_effect=lambda root, table, *args: (keyed.get(table, {}), 0)), \
             patch.object(reader, "load_row_table", side_effect=lambda root, table, *args: (rows.get(table, []), 0)), \
             patch.object(reader, "load_creature_multispawn_rows", return_value=([], 0)), \
             patch.object(reader, "load_filtered_row_table", return_value=([], 0)), \
             patch.object(reader, "parse_zone_maps", return_value=maps or {}), \
             patch.object(reader, "resolve_coordinate_zone", side_effect=resolve), \
             patch.object(reader, "load_wintergrasp_scripted_spawns", return_value={}):
            origins = {}
            records, stats = reader.build_acore_npcs(ADDON_ROOT, provenance=origins)
        return records, origins, stats

    def test_cross_zone_paths_keep_separate_visits_and_refresh_existing_bindings(self):
        points = [{"point": i * 10, "position_x": i, "position_y": i} for i in range(1, 8)]

        def resolve(row, maps):
            return (85 if row["position_x"] in (3, 4, 7) else 12), [row["position_x"], row["position_y"]]

        actual, origins, stats = self._read_waypoint_fixture(points, resolve)
        expected = {12: [[[1, 1], [2, 2]], [[5, 5], [6, 6]]],
                    85: [[[3, 3], [4, 4]], [[7, 7]]]}
        self.assertEqual(actual[1]["waypoints"], expected)
        self.assertNotIn("mapping:unmapped_waypoints", stats)
        path_id = "waypoint_data:88:addon:99:map-spawn:99:entry:1"
        self.assertEqual(origins["1"]["waypoints"]["n:12"]["n:2"], [path_id + ":segment:50"])
        self.assertEqual(origins["1"]["waypoints"]["n:85"]["n:2"], [path_id + ":segment:70"])
        self.assertEqual(exporter.identity_key(path_id + ":segment:50"), "d:88:99:99:segment:50")
        source = {1: npc(waypoints=audit.typed(expected))}
        old = {1: npc(waypoints=audit.typed({12: [[[i, i] for i in range(1, 8)]]}))}
        old_origins = {"1": {"waypoints": {"n:12": {"n:1": [path_id]}}}}
        manifest = exporter.upgrade_manifest(bootstrap(old, old), old, old_origins)
        self.assertEqual(exporter.build_records(source, manifest, origins), source)
        # Explicit whole-path exclusions apply to all of its future sections.
        hidden = {1: npc(waypoints={})}
        excluded = exporter.upgrade_manifest(bootstrap(hidden, old), old, old_origins)
        self.assertEqual(exporter.build_records(source, excluded, origins), hidden)
        # The reverse transition and source deletion must not leave old pieces.
        segmented = exporter.upgrade_manifest(bootstrap(source, source), source, origins)
        self.assertEqual(exporter.build_records(old, segmented, old_origins), old)
        self.assertEqual(exporter.build_records(hidden, segmented, {}), hidden)
        points[0]["position_y"] = 1.5
        moved, moved_origins, _ = self._read_waypoint_fixture(points, resolve)
        moved = {1: npc(waypoints=audit.typed(moved[1]["waypoints"]))}
        self.assertEqual(exporter.build_records(moved, segmented, moved_origins), moved)

    def test_waypoint_heights_select_real_floors_without_reusing_spawn_guid_overrides(self):
        reader = audit.reader
        maps = reader.parse_zone_maps(ADDON_ROOT)
        maps["floor_threshold_by_ui"].update({291: 27.0, 292: None})
        creature = {"guid": 99, "id1": 1, "map": 36, "position_x": -139.828,
                    "position_y": -569.442, "position_z": 40}
        points = [{"point": i, "position_x": creature["position_x"],
                   "position_y": creature["position_y"], "position_z": z}
                  for i, z in enumerate([0, 0, 40, 40, 0], 1)]
        original = copy.deepcopy(creature)
        with patch.dict(reader.ACORE_CREATURE_SPAWN_ZONE_OVERRIDES, {99: 1581}):
            actual, origins, _ = self._read_waypoint_fixture(points, reader.resolve_coordinate_zone, creature, maps)
        self.assertEqual(creature, original)
        self.assertEqual(actual[1]["zoneID"], 1581)
        self.assertEqual(set(actual[1]["spawns"]), {1581})
        # Deadmines lower/upper/lower visits keep their own coordinate transforms.
        self.assertEqual(actual[1]["waypoints"], {11292: [[[10.43, 61.64]], [[10.43, 61.64]]],
                                               1581: [[[59.38, 46.98]]]})
        self.assertTrue(any(identity.endswith(":segment:5")
                            for identity in origins["1"]["waypoints"]["n:11292"]["n:2"]))
        # SmartAI's pointid rows use exactly the same XYZ projection.
        escort = [dict(pointid=p["point"], position_x=p["position_x"], position_y=p["position_y"],
                       position_z=p["position_z"]) for p in points]
        with patch.dict(reader.ACORE_CREATURE_SPAWN_ZONE_OVERRIDES, {99: 1581}):
            sections = reader.project_waypoint_path(creature, escort, maps)
        self.assertEqual([(zone, first) for zone, first, _ in sections], [(11292, 1), (1581, 3), (11292, 5)])

    def test_cross_zone_projection_keeps_the_current_map_in_overlapping_rectangles(self):
        reader = audit.reader
        maps = reader.parse_zone_maps(ADDON_ROOT)
        # Three actual Forsaken Courier world positions: leave the Arathi map,
        # then remain on Hillsbrad even where Silverpine's rectangle overlaps.
        creature = {"guid": 99, "id1": 1, "map": 0, "zoneId": 45, "areaId": 45,
                    "position_x": -1552.43, "position_y": -3029.31, "position_z": 13.6448}
        points = [{"point": 129, "position_x": -452.089, "position_y": -875.795},
                  {"point": 130, "position_x": -436.879, "position_y": -856.588},
                  {"point": 138, "position_x": -301.818, "position_y": -747.177}]
        sections = reader.project_waypoint_path(creature, points, maps)
        self.assertEqual([(zone, len(path)) for zone, _, path in sections], [(45, 1), (267, 2)])

    def test_remote_world_paths_need_a_matching_spawn_context(self):
        points = [{"point": i, "position_x": i, "position_y": i} for i in (1, 2)]

        def resolve(row, maps):
            return (12 if row["position_x"] == 0 else 85), [row["position_x"], row["position_y"]]

        actual, origins, stats = self._read_waypoint_fixture(points, resolve)
        self.assertNotIn("waypoints", actual[1])
        self.assertNotIn("waypoints", origins.get("1", {}))
        self.assertEqual(stats["mapping:unmapped_waypoints"], 1)
        # Starting on the adjacent map is fine when the path actually enters
        # the spawn's map; a whole route need not fit its initial map.
        points.append({"point": 3, "position_x": 0, "position_y": 1})
        actual, _, _ = self._read_waypoint_fixture(points, resolve)
        self.assertEqual(actual[1]["waypoints"], {85: [[[1, 1], [2, 2]]], 12: [[[0, 1]]]})

    def test_an_unmappable_or_missing_waypoint_never_connects_the_positions_around_it(self):
        points = [{"point": i, "position_x": i, "position_y": i} for i in range(1, 4)]

        def resolve(row, maps):
            return (None, None) if row["position_x"] == 2 else (12, [row["position_x"], row["position_y"]])

        actual, origins, stats = self._read_waypoint_fixture(points, resolve)
        self.assertNotIn("waypoints", actual[1])
        self.assertNotIn("waypoints", origins.get("1", {}))
        self.assertEqual(stats["mapping:unmapped_waypoints"], 1)
        del points[1]["position_x"]
        with patch.object(audit.reader, "resolve_coordinate_zone", side_effect=resolve):
            self.assertIsNone(audit.reader.project_waypoint_path(
                {"guid": 99, "position_x": 0, "position_y": 0}, points, {}))

    def test_compilation_and_drawing_never_join_separate_visits_to_a_zone(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        pool = (ADDON_ROOT / "Modules/FramePool/QuestieFramePool.lua").read_text(encoding="utf-8")
        start = pool.index("function QuestieFramePool:CreateWaypoints(")
        draw = pool[start:pool.index("\nend", start) + len("\nend")]
        setup = '''
local modules = {ZoneDB={zoneIDs={STORMWIND_CITY=1519,IRONFORGE=1537,TELDRASSIL=141,
                                ORGRIMMAR=1637,THUNDER_BLUFF=1638,UNDERCITY=1497}}}
QuestieLoader={CreateModule=function(_, key) modules[key]={}; return modules[key] end,
               ImportModule=function(_, key) return modules[key] or {} end}
local lines = {}
tinsert = table.insert
QuestieFramePool={CreateLine=function(_, icon, x1, y1, x2, y2, width, color, zone)
    lines[#lines+1]={zone,x1,y1,x2,y2}
    return {}
end}
'''
        cases = '''
local routes = {[12]={{{1,1},{2,2}},{{5,5},{6,6}}},[85]={{{3,3},{4,4}},{{7,7}}}}
local compiled = modules.QuestieCorrections:OptimizeWaypoints(routes)
assert(#compiled[12]==2 and #compiled[85]==2 and #compiled[85][2]==1)
for zone, paths in pairs(compiled) do QuestieFramePool:CreateWaypoints({},paths,nil,nil,zone) end
assert(#lines==3, "separate visits and a singleton must produce exactly three lines")
local expected = {[12]={[1]=2,[5]=6},[85]={[3]=4}}
for _, line in ipairs(lines) do
    assert(expected[line[1]][line[2]]==line[4], "line must stay inside its original section")
    assert(line[2]==line[3] and line[4]==line[5])
end
'''
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "test.lua"
            path.write_text(setup + "\ndofile(" + json.dumps((ADDON_ROOT / "Modules/Libs/RamerDouglasPeucker.lua").as_posix()) + ")\n"
                            + "dofile(" + json.dumps((ADDON_ROOT / "Database/Corrections/QuestieCorrections.lua").as_posix()) + ")\n"
                            + draw + "\n" + cases, encoding="utf-8")
            result = subprocess.run([lua, str(path)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_generated_candidate_loads_in_the_production_loader(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        source = {1: npc(spawns=audit.typed({210: [[10, 20, None, 3, 571]]}),
                         waypoints=audit.typed({210: [[[30, 40]]]}))}
        before = {1: {**source[1], "s:minLevelHealth": 123}}
        records = exporter.build_records(source, bootstrap(before, source))
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            candidate = directory / "candidate.lua"
            with candidate.open("w", encoding="utf-8") as stream:
                exporter.write_stream(stream, records)
            init = (ADDON_ROOT / "Modules/QuestieInit.lua").read_text(encoding="utf-8")
            loader = init[init.index("function QuestieInit:LoadDatabase(key)"):init.index("function _QuestieInit.StartStageCoroutine()")]
            pool = (ADDON_ROOT / "Modules/FramePool/QuestieFramePool.lua").read_text(encoding="utf-8")
            start = pool.index("function QuestieFramePool:CreateWaypoints(")
            draw_waypoints = pool[start:pool.index("\nend", start) + len("\nend")]
            path = directory / "test.lua"
            path.write_text('QuestieDB={}; QuestieInit={}; loadstring=loadstring or load; coYield=coroutine.yield\n'
                            'QuestieLoader={ImportModule=function() return QuestieDB end}\n' + loader +
                            '\ndofile(' + json.dumps(candidate.as_posix()) + ')\n'
                            'local thread=coroutine.create(function() QuestieInit:LoadDatabase("npcData") end)\n'
                            'repeat local ok,err=coroutine.resume(thread); assert(ok,err) until coroutine.status(thread)=="dead"\n'
                            'assert(QuestieDB.npcKeys.spawns==7 and QuestieDB.npcData[1][2]==123)\n'
                            'local point=QuestieDB.npcData[1][7][210][1]\n'
                            'assert(point[1]==10 and point[2]==20 and point[3]==nil and point[4]==3 and point[5]==571)\n'
                            'local paths=QuestieDB.npcData[1][QuestieDB.npcKeys.waypoints][210]\n'
                            'assert(#paths==1 and #paths[1]==1 and paths[1][1][1]==30 and paths[1][1][2]==40)\n'
                            'QuestieFramePool={CreateLine=function() error("A destination must not create a patrol line") end}\n'
                            'tinsert=table.insert\n' + draw_waypoints +
                            '\nassert(#QuestieFramePool:CreateWaypoints({},paths)==0)\n', encoding="utf-8")
            result = subprocess.run([lua, str(path)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_single_destinations_do_not_hide_a_real_hostile_patrol(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        source = (ADDON_ROOT / "Modules/Quest/QuestieQuest.lua").read_text(encoding="utf-8")
        start = source.index("_DrawObjectiveWaypoints = function(")
        draw = source[start:source.index("\nend", start) + len("\nend")]
        source = (ADDON_ROOT / "Modules/FramePool/QuestieFramePool.lua").read_text(encoding="utf-8")
        start = source.index("function QuestieFramePool:CreateWaypoints(")
        create_lines = source[start:source.index("\nend", start) + len("\nend")]
        setup = '''
local lineCount = 0
tinsert = table.insert
TICKS_PER_YIELD = 100
Questie = {Debug = function() end}
QuestieFramePool = {CreateLine = function()
    lineCount = lineCount + 1
    return {}
end}
QuestieMap = {DrawWaypoints = function(_, icon, paths, zone)
    QuestieFramePool:CreateWaypoints(icon, paths, nil, nil, zone)
end}
_IsCurrentObjectiveDraw = function() return true end
_HasEarlierObjectiveForNPC = function() return false end
_HasVisibleSpawnInZone = function(points) return points and #points > 0 end
'''
        cases = '''
local patrol, destination = {{10,20},{30,40}}, {{50,60}}
local function npc(paths, hostile)
    return {Id=1, Hostile=hostile, Spawns={[12]={{10,20}}}, Waypoints={[12]=paths}}
end
local function check(sources, expected, label)
    lineCount = 0
    local objective = {spawnList=sources, AlreadySpawned={}}
    _DrawObjectiveWaypoints({}, objective, {}, {[12]={{}}})
    assert(lineCount == expected, label .. ": expected " .. expected .. ", got " .. lineCount)
end
check({npc({patrol},true)},1,"one hostile patrol")
check({npc({patrol,destination},true)},1,"same-NPC destination must not hide patrol")
check({npc({patrol},true),npc({destination},true)},1,"other-NPC destination must not hide patrol")
check({npc({destination},true)},0,"single destination draws no line")
check({npc({patrol,patrol,destination},true)},0,"multiple hostile patrols remain suppressed")
check({npc({patrol},true),npc({patrol,destination},true)},0,"hostile population filter remains")
check({npc({patrol,patrol,destination},false)},2,"friendly patrol behavior is unchanged")
'''
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "test.lua"
            path.write_text(setup + create_lines + "\n" + draw + "\n" + cases, encoding="utf-8")
            result = subprocess.run([lua, str(path)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
