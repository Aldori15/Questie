import unittest
from pathlib import Path

import generate_acore_item_corrections as item_generator
import generate_acore_npc_corrections as npc_generator
import generate_acore_object_corrections as object_generator
import validate_acore_quest_metadata as quest_validator
import validate_wdm_map_data as wdm_validator


class AcoreCorrectionRegressionTests(unittest.TestCase):
    def test_shared_map_parser_loads_all_wdm_geometry(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)

        self.assertEqual(1176, zone_maps["instance_to_zone"][209])
        self.assertEqual("wdmWorld", zone_maps["ui_map_sources"][98])
        self.assertEqual("wdmInstance", zone_maps["ui_map_sources"][219])
        self.assertTrue(zone_maps["wdm_instance_map_data"][219]["wdmInstanceMap"])

    def test_resolves_zulfarrak_spawn_to_wdm_instance_map(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)
        row = {
            "guid": 0,
            "areaId": 1176,
            "zoneId": 1176,
            "map": 209,
            "position_x": 1882.89,
            "position_y": 1299.27,
        }

        self.assertEqual((1176, [23.55, 18.33]), npc_generator.resolve_coordinate_zone(row, zone_maps))

    def test_wdm_floor_zone_ids_resolve_to_exact_ui_maps(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)

        self.assertEqual(11292, zone_maps["ui_to_zone"][292])
        self.assertEqual(292, zone_maps["wdm_floor_zone_to_ui"][11292])
        self.assertEqual(52, len(zone_maps["wdm_floor_zone_to_ui"]))
        self.assertEqual(292, npc_generator.zone_to_ui(11292, zone_maps))
        self.assertEqual(291, npc_generator.zone_to_ui(1581, zone_maps))
        self.assertTrue(all(zone_id <= 65535 for zone_id in zone_maps["wdm_floor_zone_to_ui"]))
        self.assertTrue(all(
            zone_maps["wdm_instance_map_data"][ui_id]["instance"] in zone_maps["instance_to_zone"]
            for ui_id in zone_maps["floor_threshold_by_ui"]
        ))

        zone_names = npc_generator.parse_zone_id_names(addon_root, zone_maps)
        self.assertEqual("WDM_THE_DEADMINES_FLOOR_2", zone_names[11292])
        self.assertEqual("zoneIDs.WDM_BLACKROCK_SPIRE_FLOOR_7", npc_generator.format_zone_ref(22003, zone_names))

    def test_world_spawn_does_not_enter_wdm_instance_floor_fallback(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)
        row = {
            "map": 0,
            "areaId": 12,
            "zoneId": 12,
            "position_x": -9465.58,
            "position_y": 16.8472,
            "position_z": 65.921,
        }

        self.assertEqual(12, npc_generator.resolve_coordinate_zone(row, zone_maps)[0])

    def test_resolves_deadmines_spawn_below_cutoff_to_floor_two(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)
        zone_maps["floor_threshold_by_ui"].update({291: 27.0, 292: None})
        row = {
            "guid": 79210,
            "map": 36,
            "position_x": -139.828,
            "position_y": -569.442,
            "position_z": 19.79,
        }

        self.assertEqual((11292, [10.43, 61.64]), npc_generator.resolve_coordinate_zone(row, zone_maps))

    def test_resolves_overlapping_boss_floors(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)
        zone_maps["floor_threshold_by_ui"].update({
            250: None,
            251: 20.0,
            252: 44.0,
            253: None,
            254: 77.0,
            255: None,
            11003: 98.0,
            256: None,
            257: 12.0,
            348: None,
            349: -3.0,
        })

        cases = (
            ({"map": 229, "position_x": -40.8713, "position_y": -433.589, "position_z": 111.918}, 22003),
            ({"map": 558, "position_x": 68.131, "position_y": -387.821, "position_z": 26}, 11257),
            ({"map": 585, "position_x": 148.549, "position_y": 186.981, "position_z": -16}, 4131),
        )
        for row, expected_zone_id in cases:
            with self.subTest(map_id=row["map"]):
                self.assertEqual(expected_zone_id, npc_generator.resolve_coordinate_zone(row, zone_maps)[0])

    def test_resolves_missing_classic_boss_icons(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)

        cases = (
            ({"guid": 247103, "map": 33, "position_x": -218.958, "position_y": 2152.83, "position_z": 81.1}, 11316),
            ({"guid": 27424, "map": 48, "position_x": -818.832, "position_y": -155.576, "position_z": -25.7923}, 11222),
            ({"guid": 30139, "map": 90, "position_x": -531.324, "position_y": 670.159, "position_z": -325.185}, 11229),
            ({"map": 429, "position_x": 132.626, "position_y": 625.913, "position_z": -48.38}, 11237),
        )
        for row, expected_zone_id in cases:
            with self.subTest(map_id=row["map"]):
                self.assertEqual(expected_zone_id, npc_generator.resolve_coordinate_zone(row, zone_maps)[0])

    def test_generated_corrections_use_wdm_floor_constants(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)
        zone_names = npc_generator.parse_zone_id_names(addon_root, zone_maps)

        self.assertEqual(
            "{[zoneIDs.WDM_THE_DEADMINES_FLOOR_2] = {{10,20}}}",
            npc_generator.format_lua_field_value("spawns", {11292: [[10.0, 20.0]]}, zone_names),
        )
        self.assertEqual(
            "zoneIDs.WDM_THE_DEADMINES_FLOOR_2",
            npc_generator.format_lua_field_value("zoneID", 11292, zone_names),
        )

    def test_reported_boss_floor_coordinates_round_trip(self):
        addon_root = Path(__file__).resolve().parents[1]
        zone_maps = npc_generator.parse_zone_maps(addon_root)
        cases = (
            (22003, 11003, [33.44, 45.32]),
            (11237, 237, [59.88, 23.47]),
            (11237, 237, [35.01, 57.62]),
            (11257, 257, [73.74, 48.96]),
        )

        for zone_id, ui_map_id, point in cases:
            with self.subTest(zone_id=zone_id, point=point):
                self.assertEqual(ui_map_id, npc_generator.zone_to_ui(zone_id, zone_maps))
                data = zone_maps["ui_map_data"][ui_map_id]
                world_x = data[3] - data[1] * point[0] / 100
                world_y = data[4] - data[2] * point[1] / 100
                self.assertEqual(point, npc_generator.convert_world_to_zone(world_x, world_y, zone_id, zone_maps))

    def test_preserves_dungeon_entrance_beside_npc_interior_spawn(self):
        corrections = npc_generator.find_differences(
            {7604: {"spawns": {1176: [[-1, -1]]}}},
            {7604: {"spawns": {1176: [[23.55, 18.33]]}}},
            ["spawns"],
            entrance_marker_zone_ids={1176},
        )

        self.assertEqual(
            {7604: {"spawns": {1176: [[-1.0, -1.0], [23.55, 18.33]]}}},
            corrections,
        )

    def test_preserves_dungeon_entrance_beside_object_interior_spawn(self):
        corrections = object_generator.find_differences(
            {141832: {"spawns": {1176: [[-1, -1]]}}},
            {141832: {"spawns": {1176: [[40.0, 40.0]]}}},
            ["spawns"],
            entrance_marker_zone_ids={1176},
        )

        self.assertEqual(
            {141832: {"spawns": {1176: [[-1.0, -1.0], [40.0, 40.0]]}}},
            corrections,
        )

    def test_does_not_preserve_entrance_marker_outside_wdm_instances(self):
        corrections = npc_generator.find_differences(
            {1: {"spawns": {9999: [[-1, -1]]}}},
            {1: {"spawns": {9999: [[50.0, 50.0]]}}},
            ["spawns"],
            entrance_marker_zone_ids={1176},
        )

        self.assertEqual({1: {"spawns": {9999: [[50.0, 50.0]]}}}, corrections)

    def test_wdm_validator_loads_world_and_instance_tables(self):
        ui_map_data = Path(__file__).resolve().parents[1] / "Compat/UiMapData.lua"

        self.assertIn(98, wdm_validator.load_wdm_rows(ui_map_data, "wdmWorldMapData"))
        self.assertEqual(
            1176,
            wdm_validator.load_wdm_rows(ui_map_data, "wdmInstanceMapData")[219]["areaID"],
        )

    def test_preserves_spawned_object_when_ac_npc_dropper_is_unspawned(self):
        questie = {"objectDrops": [181616], "relatedQuests": [9452]}
        acore = {"objectDrops": [], "npcDrops": [17102], "relatedQuests": [9452]}
        source_context = {
            "spawnedCreatureIds": set(),
            "spawnedGameObjectIds": {181616},
            "gameObjectTemplateIds": {181616},
        }

        self.assertTrue(
            item_generator.should_preserve_indirect_quest_item_object_sources(
                "objectDrops",
                questie,
                acore,
                source_context,
            )
        )

    def test_static_npc_dropper_remains_authoritative(self):
        questie = {"objectDrops": [181616], "relatedQuests": [9452]}
        acore = {"objectDrops": [], "npcDrops": [17102], "relatedQuests": [9452]}
        source_context = {
            "spawnedCreatureIds": {17102},
            "spawnedGameObjectIds": {181616},
            "gameObjectTemplateIds": {181616},
        }

        self.assertFalse(
            item_generator.should_preserve_indirect_quest_item_object_sources(
                "objectDrops",
                questie,
                acore,
                source_context,
            )
        )

    def test_does_not_preserve_unknown_gameobject_source(self):
        questie = {"objectDrops": [181616], "relatedQuests": [9452]}
        acore = {"objectDrops": [], "npcDrops": [17102], "relatedQuests": [9452]}

        self.assertFalse(
            item_generator.should_preserve_indirect_quest_item_object_sources(
                "objectDrops",
                questie,
                acore,
                {
                    "spawnedCreatureIds": set(),
                    "gameObjectTemplateIds": set(),
                },
            )
        )

    def test_preserves_smartai_gameobject_display_replacement(self):
        acore = (((17243,),), (), ())
        questie = ((), ((181694,),), ())

        self.assertTrue(
            quest_validator.objective_values_have_smartai_object_display_replacement(
                acore,
                questie,
                {17243: {181694}},
                {181694},
            )
        )

    def test_detects_icon_helper_inside_creature_objectives(self):
        raw_objectives = [[[17701], [17701, None, "Questie.ICON_TYPE_INTERACT"]]]
        self.assertTrue(quest_validator.raw_objectives_have_display_helpers(raw_objectives))

    def test_does_not_preserve_waypoints_without_ac_path_evidence(self):
        questie = {17528: {"waypoints": {3525: [[[38.43, 82.02], [36.51, 71.61]]]}}}
        acore = {17528: {"waypoints": {}}}

        corrections = npc_generator.find_differences(
            questie,
            acore,
            ["waypoints"],
        )

        self.assertEqual({17528: {"waypoints": {}}}, corrections)

    def test_preserves_object_spawn_for_ac_required_quest_item(self):
        questie_items = {23880: {"objectDrops": [181781]}}
        preserve_spawn_ids = object_generator.collect_indirect_quest_item_object_source_ids(
            questie_items,
            {23880},
            {181781},
        )

        corrections = object_generator.find_differences(
            {181781: {"spawns": {3525: [[41, 30]]}, "zoneID": 3525}},
            {181781: {"spawns": {}, "zoneID": 0}},
            ["spawns", "zoneID"],
            preserve_spawn_ids=preserve_spawn_ids,
        )

        self.assertEqual({181781}, preserve_spawn_ids)
        self.assertEqual({}, corrections)

    def test_does_not_preserve_object_spawn_for_non_quest_item(self):
        preserve_spawn_ids = object_generator.collect_indirect_quest_item_object_source_ids(
            {23880: {"objectDrops": [181781]}},
            set(),
            {181781},
        )

        self.assertEqual(set(), preserve_spawn_ids)


if __name__ == "__main__":
    unittest.main()
