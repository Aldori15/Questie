import unittest

import generate_acore_item_corrections as item_generator
import generate_acore_npc_corrections as npc_generator
import generate_acore_object_corrections as object_generator
import validate_acore_quest_metadata as quest_validator


class AcoreCorrectionRegressionTests(unittest.TestCase):
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
