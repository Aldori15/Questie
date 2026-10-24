import copy
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import acore_quest_script_events as events


class QuestScriptEventTests(unittest.TestCase):
    def setUp(self):
        self.creatures = {
            27409: {"entry": 27409, "AIName": "SmartAI", "ScriptName": "", "VehicleId": 51},
            27924: {"entry": 27924, "AIName": "SmartAI", "ScriptName": "", "VehicleId": 89},
            28019: {"entry": 28019},
        }
        self.crosscast = {"source_type": 0, "entryorguid": 27409, "id": 2,
                          "event_chance": 100, "action_type": 86,
                          "action_param1": 50473, "action_param3": 21, "target_type": 1}
        self.spell = {50473: {"entry": 50473, "Effect1": 90, "EffectMiscValue1": 28019,
                             "EffectImplicitTargetA1": 1, "EffectImplicitTargetB1": 0}}

    def test_player_crosscaster_receives_caster_credit_and_links_actual_quest_objective(self):
        result = events.collect(self.creatures, [self.crosscast], self.spell,
                                quest_templates={12308: {"entry": 12308, "RequiredNpcOrGo1": 28019}})
        self.assertEqual(result["credits"], {"28019": [["monster", 27409]]})
        self.assertEqual(result["events"], {"12308": [["monster", 27409]]})
        self.assertEqual(result["evidence"][0]["rule"], "closestPlayerCrossCastCredit")
        spell_rows = [{"ID": 50473, **self.spell[50473]}]
        quest_rows = [{"ID": 12308, "RequiredNpcOrGo1": 28019}]
        self.assertEqual(events.collect(self.creatures, [self.crosscast], spell_rows,
                                        quest_templates=quest_rows)["events"], result["events"])

    def test_wrong_caster_target_effect_and_unbound_ai_do_not_prove_credit(self):
        changes = [("action_param3", 19), ("target_type", 19), ("event_chance", 0)]
        for field, value in changes:
            with self.subTest(field=field):
                row = {**self.crosscast, field: value}
                self.assertFalse(events.collect(self.creatures, [row], self.spell)["credits"])
        for field, value in [("EffectImplicitTargetA1", 6), ("EffectImplicitTargetB1", 25),
                             ("Effect1", 134), ("EffectMiscValue1", 99999)]:
            with self.subTest(field=field):
                spell = {50473: {**self.spell[50473], field: value}}
                self.assertFalse(events.collect(self.creatures, [self.crosscast], spell)["credits"])
        for changes in [{"AIName": ""}, {"ScriptName": "other"}]:
            creatures = copy.deepcopy(self.creatures)
            creatures[27409].update(changes)
            self.assertFalse(events.collect(creatures, [self.crosscast], self.spell)["credits"])

    def test_spell_field_underscore_layout_and_direct_completion(self):
        spell = {50473: {"entry": 50473, "Effect_1": 16, "EffectMiscValue_1": 12308,
                         "EffectImplicitTargetA_1": 1, "EffectImplicitTargetB_1": 0}}
        result = events.collect(self.creatures, [self.crosscast], spell)
        self.assertEqual(result["events"], {"12308": [["monster", 27409]]})
        self.assertFalse(result["credits"])

    def test_self_vehicle_event_credits_player_passengers(self):
        row = {"source_type": 0, "entryorguid": 27924, "id": 2, "event_chance": 100,
               "action_type": 15, "action_param1": 11436, "target_type": 1}
        result = events.collect(self.creatures, [row], {})
        self.assertEqual(result["events"], {"11436": [["monster", 27924]]})
        self.assertEqual(result["evidence"][0]["vehicleId"], 89)
        for change in [{"target_type": 19}, {"event_chance": 0}, {"action_param1": 0}]:
            self.assertFalse(events.collect(self.creatures, [{**row, **change}], {})["events"])
        creatures = copy.deepcopy(self.creatures)
        creatures[27924]["VehicleId"] = 0
        self.assertFalse(events.collect(creatures, [row], {})["events"])

    def test_self_timed_list_retains_actor_and_cross_actor_list_does_not(self):
        call = {"source_type": 0, "entryorguid": 27409, "id": 0, "event_chance": 100,
                "action_type": 80, "action_param1": 123, "target_type": 1}
        cast = {**self.crosscast, "source_type": 9, "entryorguid": 123}
        self.assertEqual(events.collect(self.creatures, [call, cast], self.spell)["credits"],
                         {"28019": [["monster", 27409]]})
        call["target_type"] = 19
        self.assertFalse(events.collect(self.creatures, [call, cast], self.spell)["credits"])


if __name__ == "__main__":
    unittest.main()
