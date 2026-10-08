"""Generator regression checks; never run generation or write correction files."""
import unittest
from unittest.mock import patch

import generate_acore_npc_corrections as npc


class PatrolSpawnMetadataTests(unittest.TestCase):
    def test_identity_preserves_visibility_and_unrestricted_locations(self):
        ordinary = npc.add_acore_spawn_identity([51.3, 27.27], {"guid": 133649, "map": 571})
        self.assertEqual(ordinary, [51.3, 27.27, 0, 0, 571, 0, 0, 133649])
        phased = [10, 20, 1034, 2, 571, 4294967295, 4477]
        self.assertEqual(npc.add_acore_spawn_identity(phased, {"guid": 123, "map": 571}), phased + [123])
        self.assertEqual(npc.add_acore_spawn_identity([-1, -1], {"guid": 123, "map": 631}), [-1, -1])
        self.assertEqual(npc.add_acore_spawn_identity([10, 20], {"guid": 0}), [10, 20])
        self.assertEqual(phased, [10, 20, 1034, 2, 571, 4294967295, 4477], "input stays unmodified")

    def test_deduplication_cannot_merge_different_spawns(self):
        first = [10, 20, 0, 1, 571, 2, 4477, 123]
        second = [10, 20, 0, 1, 571, 2, 4477, 124]
        self.assertCountEqual(npc.unique_coordinate_points([first, second, first]), [first, second])
        alternate = [10, 20, 0, 2, 571, 2, 4477, 123]
        self.assertEqual(npc.unique_coordinate_points([first, alternate]),
                         [[10, 20, 0, 3, 571, 2, 4477, 123]])

    def test_identity_survives_correction_comparison_and_serialization(self):
        point = [10, 20, 0, 0, 622, 0, 0, 142849]
        old = {29795: {"spawns": {210: [[10, 20]]}}}
        new = {29795: {"spawns": {210: [point]}}}
        changes = npc.find_differences(old, new, ["spawns"])
        self.assertEqual(changes[29795]["spawns"][210], [point])
        fragment = npc.format_lua_value(changes[29795]["spawns"])
        self.assertEqual(npc.LuaParser(fragment).parse(), {210: [point]})
        changed_guid = [*point[:7], 142850]
        self.assertNotEqual(npc.normalize_coordinate_table({210: [point]}),
                            npc.normalize_coordinate_table({210: [changed_guid]}))

    def test_gunship_uses_outdoor_fallback_without_moving_icc_copy(self):
        original = {210: [[42, 32]], 4812: [[10, 20]]}
        ship = {"guid": 142904, "map": 623, "position_x": 15, "position_y": 30}
        result = npc.annotate_gunship_fallback(original, ship)
        self.assertEqual(result[210], [[42, 32, 0, 0, 623, 0, 0, 142904]])
        self.assertEqual(result[4812], [[10, 20]])
        self.assertEqual(original, {210: [[42, 32]], 4812: [[10, 20]]})

    def test_build_attaches_only_unique_ship_identity_to_existing_fallback(self):
        templates = {30344: {}, 29795: {}, 31261: {}, 99999: {}}
        creatures = [
            {"id": 30344, "guid": 142904, "map": 623},
            {"id": 30344, "guid": 247300, "map": 712},
            {"id": 29795, "guid": 142849, "map": 622},
            {"id": 29795, "guid": 142850, "map": 622},
            {"id": 31261, "guid": 142901, "map": 622},
            {"id": 99999, "guid": 100, "map": 622},
        ]
        baseline = {30344: {"spawns": {210: [[42, 32]], 4812: [[10, 20]]}},
                    29795: {"spawns": {210: [[30, 40]]}},
                    99999: {"spawns": {210: [[30, 40]]}}}
        def keyed(_root, table, *_args):
            return (templates if table == "creature_template" else {}), 0
        def rows(_root, table, *_args):
            tables = {"creature": creatures,
                      "creature_queststarter": [{"id": 30344, "quest": 1}, {"id": 29795, "quest": 2}],
                      "creature_questender": [{"id": 31261, "quest": 3}]}
            return tables.get(table, []), 0
        with patch.object(npc, "load_keyed_table", side_effect=keyed), \
             patch.object(npc, "load_row_table", side_effect=rows), \
             patch.object(npc, "load_filtered_row_table", return_value=([], 0)), \
             patch.object(npc, "load_creature_multispawn_rows", return_value=([], 0)), \
             patch.object(npc, "find_map_difficulty_dbc", return_value=None), \
             patch.object(npc, "load_map_difficulty_masks", return_value={}), \
             patch.object(npc, "parse_zone_maps", return_value={}), \
             patch.object(npc, "resolve_coordinate_zone", return_value=(None, None)), \
             patch.object(npc, "load_wintergrasp_scripted_spawns", return_value={}):
            generated, _ = npc.build_acore_npcs(".", questie_npcs=baseline)
        self.assertEqual(generated[30344]["spawns"][210][0][7], 142904)
        self.assertEqual(generated[30344]["spawns"][4812], [[10, 20]])
        self.assertNotIn("spawns", generated[29795], "ambiguous ship copies retain baseline")
        self.assertNotIn("spawns", generated[31261], "no fallback must never become an empty correction")
        self.assertNotIn("spawns", generated[99999], "non-quest ship passengers keep their baseline")

    def test_build_limits_identity_to_quest_relations_without_losing_visibility(self):
        templates = {entry: {} for entry in range(1, 6)}
        creatures = [{"id": entry, "guid": 100 + entry, "map": 571,
                      "zoneId": 210, "areaId": 4477, "phaseMask": 2, "movementType": 0}
                     for entry in templates]
        creatures.append({"id": 5, "guid": 106, "map": 571})
        tables = {"creature": creatures,
                  "creature_queststarter": [{"id": 1, "quest": 10}, {"id": 4, "quest": 0}],
                  "creature_questender": [{"id": 2, "quest": 20}],
                  "game_event_creature_quest": [{"id": 3, "quest": 30, "eventEntry": 61}]}
        with patch.object(npc, "load_keyed_table", side_effect=lambda _r, table, *_a:
                          (templates if table == "creature_template" else {}, 0)), \
             patch.object(npc, "load_row_table", side_effect=lambda _r, table, *_a:
                          (tables.get(table, []), 0)), \
             patch.object(npc, "load_filtered_row_table", return_value=([], 0)), \
             patch.object(npc, "load_creature_multispawn_rows", return_value=([], 0)), \
             patch.object(npc, "find_map_difficulty_dbc", return_value=None), \
             patch.object(npc, "load_map_difficulty_masks", return_value={}), \
             patch.object(npc, "parse_zone_maps", return_value={}), \
             patch.object(npc, "resolve_coordinate_zone", return_value=(210, [10, 20])), \
             patch.object(npc, "load_wintergrasp_scripted_spawns", return_value={}):
            generated, _ = npc.build_acore_npcs(".")
        for entry in (1, 2, 3):
            self.assertEqual(generated[entry]["spawns"][210],
                             [[10, 20, 0, 1, 571, 2, 4477, 100 + entry]],
                             "idle and event questgivers still need exact identities")
        self.assertEqual(generated[4]["spawns"][210], [[10, 20, 0, 1, 571, 2, 4477]],
                         "non-quest NPCs retain their phase metadata")
        self.assertCountEqual(generated[5]["spawns"][210],
                              [[10, 20, 0, 1, 571, 2, 4477], [10, 20]],
                              "coincident locations with different visibility stay separate")


if __name__ == "__main__":
    unittest.main()
