"""Flight guidance follows executable quest-conditioned taxi actions, not labels."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_quest_flight_guides as flights
import acore_quest_guides as guides


class FlightGuideTests(unittest.TestCase):
    def args(self):
        quests = {10163: {}, 10346: {}, 10382: {}}
        creatures = {20235: {"name": "Gryphoneer Windbellow", "AIName": "SmartAI",
                             "ScriptName": "", "gossip_menu_id": 8096, "npcflag": 1}}
        spells = {33899: {"Effect1": 123, "EffectMiscValue1": 589, "EffectImplicitTargetA1": 25},
                  35065: {"Effect1": 123, "EffectMiscValue1": 607, "EffectImplicitTargetA1": 25}}
        conditions = [{"SourceTypeOrReferenceId": 15, "SourceGroup": 8096,
                       "SourceEntry": option, "ElseGroup": group, "ConditionTypeOrReference": kind,
                       "ConditionTarget": 0, "ConditionValue1": quest}
                      for option, group, kind, quest in ((0, 0, 9, 10163), (0, 1, 9, 10346), (1, 0, 28, 10382))]
        scripts = [{"entryorguid": 20235, "source_type": 0, "id": option, "event_type": 62,
                    "event_param1": 8096, "event_param2": option, "event_chance": 100,
                    "action_type": 11, "action_param1": spell, "target_type": 7}
                   for option, spell in ((0, 33899), (1, 35065))]
        options = [{"MenuID": 8096, "OptionID": option, "OptionType": 1, "OptionNpcFlag": 1,
                    "OptionText": label} for option, label in ((0, "Wrong destination"), (1, "Other destination"))]
        return [quests, creatures, spells, conditions, scripts, options, []]

    def test_windbellow_or_groups_and_complete_quest_use_actual_spells(self):
        packet = flights.derive(*self.args())
        self.assertEqual(set(packet["guides"]), {10163, 10346, 10382})
        self.assertEqual(packet["guides"][10382], [{2: 5, 3: "Speak with Gryphoneer Windbellow",
                                                   4: 0, 5: [["monster", 20235]]}])
        proofs = {row["questId"]: row for row in packet["evidence"]}
        self.assertEqual(proofs[10382]["conditionType"], 28)
        self.assertEqual(proofs[10382]["taxiPathId"], 607)
        self.assertEqual(proofs[10163]["taxiPathId"], 589)
        self.assertEqual(proofs[10346]["elseGroup"], 1)
        self.assertEqual(packet["omissions"], [])

    def test_source_changes_refresh_hint_name_target_and_path(self):
        args = self.args()
        actor = args[1].pop(20235)
        actor["name"] = "Replacement pilot"
        args[1][999] = actor
        for row in args[4]:
            row["entryorguid"] = 999
        args[2][35065]["EffectMiscValue1"] = 777
        packet = flights.derive(*args)
        self.assertEqual(packet["guides"][10382][0][3], "Speak with Replacement pilot")
        self.assertEqual(packet["guides"][10382][0][5], [["monster", 999]])
        self.assertEqual(next(row for row in packet["evidence"] if row["questId"] == 10382)["taxiPathId"], 777)

    def test_quest_state_mask_recovers_windbellow_hint_for_active_quests(self):
        for mask in (2, 8, 10, 74):
            with self.subTest(mask=mask):
                args = self.args()
                args[3] = [dict(args[3][2], ConditionTypeOrReference=47, ConditionValue2=mask)]
                packet = flights.derive(*args)
                self.assertEqual(packet["guides"][10382][0][3], "Speak with Gryphoneer Windbellow")
                self.assertEqual(packet["evidence"][0]["conditionType"], 47)
                self.assertEqual(packet["evidence"][0]["allowedQuestStateMask"], mask)
                self.assertEqual(packet["evidence"][0]["taxiPathId"], 607)

    def test_rewarded_only_invalid_and_negated_masks_do_not_prove_flight(self):
        for change in ({"ConditionValue2": 64}, {"ConditionValue2": 1}, {"ConditionValue2": 32},
                       {"ConditionValue2": 0}, {"ConditionValue2": -1}, {"ConditionValue2": 4},
                       {"ConditionValue2": 78}, {"ConditionValue3": 1}, {"NegativeCondition": 1}):
            with self.subTest(change=change):
                args = self.args()
                condition = dict(args[3][2], ConditionTypeOrReference=47, ConditionValue2=74)
                condition.update(change)
                args[3] = [condition]
                self.assertEqual(flights.derive(*args)["guides"], {})

    def test_same_group_quest_masks_intersect_and_negative_masks_restrict_states(self):
        args = self.args()
        complete = args[3][2]
        mask = dict(complete, ConditionTypeOrReference=47, ConditionValue2=8)
        args[3] = [complete, mask]
        self.assertEqual(flights.derive(*args)["guides"], {})
        args[3] = [complete, dict(mask, ConditionValue2=74)]
        self.assertIn(10382, flights.derive(*args)["guides"])
        args[3] = [complete, dict(mask, ConditionValue2=2, NegativeCondition=1)]
        self.assertEqual(flights.derive(*args)["guides"], {})
        args[3] = [complete, dict(mask, ConditionValue2=8, NegativeCondition=1)]
        self.assertIn(10382, flights.derive(*args)["guides"])

    def test_negative_rewarded_reference_and_wrong_target_conditions_do_not_prove_hint(self):
        for change in ({"NegativeCondition": 1}, {"ConditionTypeOrReference": 8},
                       {"ConditionTypeOrReference": -123}, {"ConditionTarget": 1},
                       {"ConditionValue1": 999}, {"ConditionValue2": 1}, {"ScriptName": "custom"}):
            with self.subTest(change=change):
                args = self.args()
                args[3] = [dict(args[3][2], **change)]
                self.assertEqual(flights.derive(*args)["guides"], {})
        args = self.args()
        args[3] = [args[3][2], dict(args[3][2], ConditionTypeOrReference=9)]
        self.assertEqual(flights.derive(*args)["guides"], {})

    def test_real_binding_and_supported_menu_option_required(self):
        for change in ({"AIName": ""}, {"ScriptName": "npc_taxi"},
                       {"gossip_menu_id": 999}, {"npcflag": 2}):
            args = self.args()
            args[1][20235].update(change)
            self.assertEqual(flights.derive(*args)["guides"], {}, change)
        for change in ({"OptionType": 2}, {"OptionNpcFlag": 0}, {"OptionNpcFlag": 2},
                       {"ActionMenuID": 123}, {"BoxCoded": 1}, {"BoxMoney": 10}):
            args = self.args()
            args[5][1].update(change)
            self.assertNotIn(10382, flights.derive(*args)["guides"], change)
        args = self.args()
        args[5] = []
        self.assertEqual(flights.derive(*args)["guides"], {})

    def test_actions_require_player_taxi_effect_without_custom_spell_binding(self):
        for change in ({"Effect1": 6}, {"EffectMiscValue1": 0},
                       {"EffectImplicitTargetA1": 1}, {"EffectImplicitTargetB1": 25}):
            args = self.args()
            args[2][35065].update(change)
            self.assertNotIn(10382, flights.derive(*args)["guides"], change)
        for spell in (35065, -35065):
            args = self.args()
            args[6] = [{"spell_id": spell, "ScriptName": "custom_taxi"}]
            self.assertNotIn(10382, flights.derive(*args)["guides"])
        for change in ({"target_type": 1}, {"event_chance": 50}, {"event_phase_mask": 1},
                       {"event_flags": 8}, {"event_param1": 999}, {"action_param1": 999}):
            args = self.args()
            args[4][1].update(change)
            self.assertNotIn(10382, flights.derive(*args)["guides"], change)

    def test_direct_taxi_action_and_simple_links_but_no_handoffs(self):
        args = self.args()
        args[4][1].update(action_type=52, action_param1=607)
        self.assertIn(10382, flights.derive(*args)["guides"])
        linked = dict(args[4][1], id=2, event_type=61)
        args[4][1].update(action_type=72, link=2)
        args[4].append(linked)
        self.assertIn(10382, flights.derive(*args)["guides"])
        linked["link"] = 2
        self.assertNotIn(10382, flights.derive(*args)["guides"])
        linked["link"] = 999
        self.assertNotIn(10382, flights.derive(*args)["guides"])
        linked["link"] = 0
        args[4][1].update(action_type=80)
        self.assertNotIn(10382, flights.derive(*args)["guides"])

    def test_smart_action_conditions_need_separate_proof(self):
        args = self.args()
        args[3].append({"SourceTypeOrReferenceId": 22, "SourceEntry": 20235,
                        "SourceId": 0, "SourceGroup": 2, "ConditionTypeOrReference": 1})
        packet = flights.derive(*args)
        self.assertNotIn(10382, packet["guides"])
        self.assertTrue(any(row["reason"] == "conditionalFlightAction" for row in packet["omissions"]))

    def test_uninterpreted_condition_reports_known_quest_instead_of_silent_omission(self):
        args = self.args()
        args[3].append(dict(args[3][2], ConditionTypeOrReference=-900, ConditionValue1=0))
        packet = flights.derive(*args)
        self.assertNotIn(10382, packet["guides"])
        self.assertTrue(any(row["reason"] == "unsupportedFlightCondition" and row["questIds"] == [10382]
                            for row in packet["omissions"]))

    def test_optional_indices_follow_final_sorted_guides_and_keep_other_helpers_required(self):
        quests, npcs, spells, conditions, scripts, options, bindings = self.args()
        quests[10382] = {"StartItem": 7}
        spells[8] = {"RequiresSpellFocus": 9}
        packet = guides.derive_extra_guide_packet(
            quests, {7: {"name": "Tool", "spellid1": 8}},
            {10: {"name": "Focus", "type": 8, "Data0": 9}}, spells, conditions,
            scripts, {}, npcs, gossip_options=options, spell_scripts=bindings)
        self.assertEqual(packet["guides"][10382]["n:1"]["n:3"], "Use Tool at Focus")
        self.assertEqual(packet["optional"]["10382"], [2])
        self.assertEqual(packet["guides"][10382]["n:2"]["n:3"], "Speak with Gryphoneer Windbellow")


if __name__ == "__main__":
    unittest.main()
