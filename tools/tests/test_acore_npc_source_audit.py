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
    def test_unknown_area_projection_excludes_real_world_and_continent_rectangles(self):
        zones = audit.reader.parse_zone_maps(ADDON_ROOT)
        row = {"map": 571, "position_x": 7000, "position_y": 2000, "position_z": 600}
        zone, point = audit.reader.resolve_coordinate_zone(row, zones)
        self.assertEqual(zone, 210)
        self.assertEqual(point, audit.reader.convert_world_to_zone(2000, 7000, 210, zones, map_id=571))
        # Explicit source geography retains the same position.
        self.assertEqual(audit.reader.resolve_coordinate_zone(dict(row, zoneId=210, areaId=210), zones),
                         (zone, point))
        # Coordinates covered only by an aggregate rectangle remain unknown.
        row.update(position_x=23000, position_y=0)
        self.assertEqual(audit.reader.resolve_coordinate_zone(row, zones), (None, None))

    def test_transport_projection_preserves_historical_gunship_routes_on_icecrown(self):
        zones = audit.reader.parse_zone_maps(ADDON_ROOT)
        # Pre-PR-166 QuestieDB.waypointPresets: Orgrim's Hammer and Skybreaker.
        historical = {
            622: [
                (62.37, 30.60), (61.93, 30.93), (61.48, 31.24), (61.08, 31.55), (60.74, 31.92), (60.46, 32.44),
                (60.26, 33.11), (60.14, 33.85), (60.11, 34.63), (60.17, 35.35), (60.31, 36.01), (60.56, 36.66),
                (60.84, 37.33), (61.15, 38.00), (61.44, 38.67), (61.71, 39.28), (62.00, 39.92), (62.31, 40.55),
                (62.60, 41.20), (62.90, 41.83), (63.05, 42.20), (63.33, 42.85), (63.58, 43.53), (63.85, 44.19),
                (64.08, 44.86), (64.33, 45.50), (64.45, 45.87), (64.69, 46.56), (64.94, 47.21), (65.16, 47.87),
                (65.43, 48.51), (65.71, 49.15), (66.03, 49.77), (66.36, 50.46), (66.72, 51.10), (67.07, 51.67),
                (67.41, 52.08), (67.82, 52.37), (68.31, 52.47), (68.80, 52.38), (69.23, 51.98), (69.45, 51.56),
                (69.57, 51.13), (69.67, 50.59), (69.73, 49.96), (69.77, 49.26), (69.79, 48.48), (69.80, 47.62),
                (69.79, 46.68), (69.79, 45.68), (69.78, 44.90), (69.78, 44.25), (69.76, 43.55), (69.75, 42.80),
                (69.72, 42.01), (69.70, 41.20), (69.67, 40.38), (69.64, 39.54), (69.61, 38.71), (69.58, 37.88),
                (69.55, 37.07), (69.52, 36.28), (69.49, 35.54), (69.46, 34.83), (69.45, 34.18), (69.42, 33.50),
                (69.41, 32.46), (69.42, 31.52), (69.45, 30.67), (69.47, 29.92), (69.48, 29.25), (69.46, 28.65),
                (69.42, 28.12), (69.35, 27.83), (69.11, 27.19), (68.71, 26.77), (68.23, 26.54), (67.71, 26.51),
                (67.24, 26.55), (66.81, 26.76), (66.35, 27.09), (65.90, 27.52), (65.44, 27.95), (65.01, 28.39),
                (64.58, 28.73), (64.16, 29.10), (63.74, 29.43), (63.34, 29.79), (62.94, 30.11), (62.65, 30.37),
                (62.37, 30.60),
            ],
            623: [
                (63.59, 52.34), (63.44, 51.88), (63.30, 51.52), (63.15, 51.19), (63.01, 50.85), (62.85, 50.52),
                (62.68, 50.17), (62.50, 49.78), (62.31, 49.36), (62.09, 48.88), (61.86, 48.33), (61.81, 48.20),
                (61.67, 47.88), (61.52, 47.52), (61.37, 47.13), (61.19, 46.74), (61.02, 46.32), (60.84, 45.88),
                (60.65, 45.44), (60.46, 44.99), (60.28, 44.53), (60.09, 44.08), (59.90, 43.63), (59.72, 43.18),
                (59.54, 42.75), (59.36, 42.34), (59.20, 41.94), (59.04, 41.56), (58.89, 41.22), (58.75, 40.87),
                (58.52, 40.30), (58.32, 39.77), (58.14, 39.27), (57.97, 38.80), (57.81, 38.39), (57.65, 38.03),
                (57.49, 37.72), (57.31, 37.50), (57.12, 37.34), (56.87, 37.29), (56.57, 37.39), (56.27, 37.60),
                (55.97, 37.88), (55.72, 38.23), (55.53, 38.61), (55.43, 38.95), (55.43, 39.09), (55.46, 39.49),
                (55.52, 39.92), (55.62, 40.39), (55.76, 40.88), (55.89, 41.38), (56.02, 41.85), (56.17, 42.25),
                (56.33, 42.68), (56.51, 43.13), (56.70, 43.56), (56.88, 43.99), (57.05, 44.39), (57.22, 44.74),
                (57.42, 45.15), (57.64, 45.52), (57.83, 45.81), (58.03, 46.14), (58.23, 46.56), (58.41, 46.90),
                (58.60, 47.25), (58.80, 47.62), (59.00, 48.03), (59.19, 48.46), (59.36, 48.84), (59.53, 49.22),
                (59.69, 49.63), (59.86, 50.04), (60.03, 50.46), (60.19, 50.90), (60.36, 51.32), (60.51, 51.74),
                (60.65, 52.17), (60.79, 52.59), (60.94, 53.02), (61.07, 53.46), (61.23, 53.89), (61.39, 54.30),
                (61.55, 54.72), (61.70, 55.18), (61.88, 55.65), (62.05, 56.14), (62.23, 56.58), (62.43, 56.95),
                (62.65, 57.21), (62.87, 57.30), (62.95, 57.27), (63.22, 57.16), (63.52, 56.97), (63.81, 56.68),
                (64.07, 56.32), (64.26, 55.91), (64.33, 55.47), (64.30, 55.11), (64.25, 54.72), (64.16, 54.30),
                (64.04, 53.84), (63.91, 53.36), (63.76, 52.88), (63.59, 52.34),
            ],
        }
        data = zones["ui_map_data"][audit.reader.zone_to_ui(210, zones)]
        width, height, left, top = (data[key] for key in (1, 2, 3, 4))
        for transport_map, points in historical.items():
            with self.subTest(transport_map=transport_map):
                positions = [(top - y * height / 100, left - x * width / 100) for x, y in points]
                first, second = positions[:2]
                previous, last = positions[-2:]
                controls = [(2 * first[0] - second[0], 2 * first[1] - second[1]),
                            *positions,
                            (2 * last[0] - previous[0], 2 * last[1] - previous[1])]
                templates = [{"entry": 987654, "type": 15, "Data0": 4321, "Data6": transport_map}]
                passenger = {"guid": 765432, "id1": 654321, "map": transport_map,
                             "position_x": 0, "position_y": 0, "position_z": 0, "orientation": 0}
                nodes = [dict(id=index + 1, path=4321, index=index, map=571,
                              x=x, y=y, z=600, flags=0)
                         for index, (x, y) in enumerate(controls)]
                result = audit.acore_transport_geometry.build_geometry(
                    templates, [passenger], nodes, zones, audit.reader.resolve_transport_coordinate_zone)
                geometry = result[765432]
                self.assertEqual(geometry["zone"], 210)
                self.assertEqual(set(geometry["paths"]), {210})
                self.assertEqual(geometry["point"], list(points[0]))
                self.assertEqual(geometry["row"]["map"], 571)
                paths = geometry["paths"][210]
                self.assertEqual(len(paths), 1)
                self.assertEqual(paths[0][::audit.acore_transport_geometry.SUBDIVISIONS],
                                 [list(point) for point in points])
                self.assertTrue(all(0 <= coordinate <= 100 for point in paths[0] for coordinate in point[:2]))

    def test_transport_projection_rejects_ambiguous_unreviewed_zones(self):
        zones = audit.reader.parse_zone_maps(ADDON_ROOT)
        data = zones["ui_map_data"][audit.reader.zone_to_ui(210, zones)]
        # Koltira's historical anchor lies inside both zone-map rectangles.
        x, y = data[4] - 28.41 * data[2] / 100, data[3] - 64.78 * data[1] / 100
        row = {"map": 571, "position_x": x, "position_y": y, "position_z": 600}
        for zone in (210, 67):
            self.assertIsNotNone(audit.reader.convert_world_to_zone(y, x, zone, zones, map_id=571))
        self.assertEqual(audit.reader.resolve_transport_coordinate_zone(row, zones), (None, None))
        self.assertEqual(audit.reader.resolve_transport_coordinate_zone(dict(row, zoneId=210), zones),
                         (210, [64.78, 28.41]))
        self.assertEqual(audit.reader.resolve_transport_coordinate_zone(
            dict(row, zoneId=210, position_x=23000), zones), (None, None))
        unambiguous = dict(row, position_x=7000, position_y=2000)
        self.assertEqual(audit.reader.resolve_transport_coordinate_zone(unambiguous, zones),
                         (210, audit.reader.convert_world_to_zone(2000, 7000, 210, zones, map_id=571)))

    def test_native_outland_islands_resolve_sea_spawns_and_future_coordinates(self):
        zones = audit.reader.parse_zone_maps(ADDON_ROOT)
        # Cowlen's actual AC spawn is in The Veiled Sea (3479), which has no
        # UI map of its own. Azuremyst's client rectangle belongs to map 1.
        row = {"guid": 84415, "map": 530, "zoneId": 3479, "areaId": 3479,
               "position_x": -5357.79, "position_y": -11175.3, "position_z": 6.43216}
        self.assertEqual(audit.reader.resolve_coordinate_zone(row, zones), (3524, [16.59, 94.46]))
        # A future source relocation must use its new XYZ, without depending
        # on the reviewed spawn GUID or inheriting its previous guide point.
        row.update(guid=999999, position_x=-5347.79, position_y=-11165.3)
        self.assertEqual(audit.reader.resolve_coordinate_zone(row, zones), (3524, [16.34, 94.09]))

    def test_native_island_fallback_keeps_client_maps_and_explicit_city_priority(self):
        zones = audit.reader.parse_zone_maps(ADDON_ROOT)
        for map_id, zone_id in audit.reader.ACORE_WORLD_RECT_OVERRIDES:
            ui = audit.reader.zone_to_ui(zone_id, zones)
            self.assertIn(ui, zones["ui_by_instance"][map_id])
            self.assertEqual(zones["ui_by_instance"][map_id].count(ui), 1)
            self.assertIn(ui, zones["ui_by_instance"][zones["ui_map_data"][ui]["instance"]])
        # Native island fallback must not displace a source-backed city hint
        # with a broader outdoor rectangle that also contains its coordinates.
        perry = {"map": 530, "zoneId": 3703, "position_x": -1747.62,
                 "position_y": 5126.94, "position_z": -35.788}
        self.assertEqual(audit.reader.resolve_coordinate_zone(perry, zones), (3703, [77.19, 31.43]))

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
            for name in set(audit.acore_cpp_geometry.SOURCE_FILES) | set(audit.acore_npc_health.SOURCE_FILES):
                cpp_input = source / name
                cpp_input.parent.mkdir(parents=True, exist_ok=True)
                cpp_input.write_text("// fixture source\n", encoding="utf-8")
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

                taxi = addon.with_name("TaxiPathNode.dbc")
                taxi.write_bytes(b"fixture DBC")
                transport_core = source / audit.acore_transport_geometry.SOURCE_FILES[0]
                transport_core.parent.mkdir(parents=True, exist_ok=True)
                transport_core.write_text("// transport source\n", encoding="utf-8")
                original_transport = audit.source_signature(*args)["transport"]
                self.assertEqual(original_transport["taxiPathNodesSha256"], db_snapshot.file_hash(taxi))
                taxi.write_bytes(b"changed DBC")
                self.assertNotEqual(original_transport["taxiPathNodesSha256"],
                                    audit.source_signature(*args)["transport"]["taxiPathNodesSha256"])
                transport_core.write_text("// changed transport source\n", encoding="utf-8")
                core_key = str(transport_core.relative_to(source))
                self.assertNotEqual(original_transport["sources"][core_key],
                                    audit.source_signature(*args)["transport"]["sources"][core_key])
                transport_sql = base / "gameobject_template.sql"
                transport_sql.write_text("-- transport template\n", encoding="utf-8")
                self.assertNotEqual(original_transport["sources"][str(transport_sql.relative_to(source))],
                                    audit.source_signature(*args)["transport"]["sources"][str(transport_sql.relative_to(source))])

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

    def test_extraction_passes_only_registered_motion_transport_templates(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            signature = {"transport": {"taxiPathNodes": str(directory / "TaxiPathNode.dbc")}}
            templates = [{"entry": 11, "type": 15, "Data0": 77, "Data6": 88},
                         {"entry": 12, "type": 15, "Data0": 78, "Data6": 89},
                         {"entry": 13, "type": 2, "Data0": 79, "Data6": 90},
                         {"entry": 14, "type": 15, "Data0": 80, "Data6": 0}]
            nodes = [{"path": 77}]

            def rows(root, table, keys, include_modules=False):
                if table == "gameobject_template":
                    return templates, 0
                if table == "transports":
                    return [{"guid": i, "entry": i} for i in (11, 13, 14)], 0
                return [], 0

            def build(source, **kwargs):
                self.assertEqual(kwargs["transport_templates"], [templates[0]])
                self.assertIs(kwargs["taxi_nodes"], nodes)
                self.assertNotIn("questie_npcs", kwargs)
                return {}, {}

            with patch.object(audit.sql_reader, "load_row_table", side_effect=rows), \
                 patch.object(audit.reader, "build_acore_npcs", side_effect=build), \
                 patch.object(audit.acore_transport_geometry, "verify_core") as verify, \
                 patch.object(audit.acore_transport_geometry, "load_taxi_nodes", return_value=nodes) as load, \
                 patch.object(audit, "source_signature", return_value=signature):
                audit.load_source(*([ADDON_ROOT] * 6), signature, directory / "cache.json")
            verify.assert_called_once_with(ADDON_ROOT)
            load.assert_called_once_with(directory / "TaxiPathNode.dbc")

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
