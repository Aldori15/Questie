import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_quest_guides as guides


class QuestGuideTests(unittest.TestCase):
    def test_area_trigger_25_uses_current_projected_source_point(self):
        quests = {25: {"LogTitle": "Stonetalon Standstill", "AreaDescription": "Explore the gazebo."}}
        relations = [{"id": 77, "quest": 25}, {"id": 77, "quest": 25}]
        triggers = {77: {"ID": 77, "x": 123, "y": 456}}
        project = lambda trigger, quest: (331, [48.9, 69.5])
        result = guides.derive_area_guides(quests, relations, triggers, project)
        self.assertEqual(result[25]["n:1"], "Explore the gazebo.")
        self.assertEqual(result[25]["n:2"]["n:331"], {"n:1": {"n:1": 48.9, "n:2": 69.5}})
        quests[25]["AreaDescription"] = ""
        self.assertEqual(guides.derive_area_guides(quests, relations, triggers, project)[25]["n:1"],
                         "Explore Stonetalon Standstill")

    def test_area_missing_geometry_or_script_is_reported_without_legacy_fallback(self):
        quests, relations = {25: {"LogTitle": "Explore"}}, [{"id": 77, "quest": 25}]
        packet = guides.derive_area_guide_packet(quests, relations, {77: {}}, lambda *_: (331, [-1, -1]))
        self.assertEqual(packet["guides"], {})
        self.assertEqual(packet["omissions"][0]["reason"], "unmappedAreaTrigger")
        packet = guides.derive_area_guide_packet(quests, relations, {77: {}}, lambda *_: (331, [1, 2]),
                                                 [{"entry": 77, "ScriptName": "custom_trigger"}])
        self.assertEqual(packet["guides"], {})
        self.assertEqual(packet["omissions"][0]["reason"], "unprovedAreaTriggerScript")

    def test_bound_smart_trigger_credits_11652_without_default_relation(self):
        quests = {11652: {"LogTitle": "The Plains of Nasam", "AreaDescription": "Scout the landing."}}
        row = {"entryorguid": 4963, "source_type": 2, "id": 1, "event_type": 46,
               "event_param1": 4963, "event_chance": 100, "action_type": 15,
               "action_param1": 11652, "target_type": 7}
        bindings = [{"entry": 4963, "ScriptName": "SmartTrigger"}]
        result = guides.derive_area_guide_packet(quests, [], {4963: {}}, lambda *_: (3537, [10, 20]),
                                                bindings, smart_scripts=[row])
        self.assertIn(11652, result["guides"])
        self.assertEqual(result["evidence"][0]["rule"], "smartTriggerQuestCredit")
        self.assertEqual(guides.derive_area_guides(quests, [], {4963: {}}, lambda *_: (3537, [10, 20]),
                                                  [], smart_scripts=[row]), {})
        for key, value in [("action_param1", 999), ("target_type", 1), ("event_param1", 999),
                           ("source_type", 0), ("event_type", 0), ("event_phase_mask", 1)]:
            changed = dict(row, **{key: value})
            self.assertEqual(guides.derive_area_guides(quests, [], {4963: {}}, lambda *_: (3537, [10, 20]),
                                                      bindings, smart_scripts=[changed]), {}, key)
        other = [{"entry": 4963, "ScriptName": "custom_trigger"}]
        self.assertEqual(guides.derive_area_guides(quests, [{"id": 4963, "quest": 11652}], {4963: {}},
                                                  lambda *_: (3537, [10, 20]), other, smart_scripts=[row]), {})

    def test_1471_style_provided_item_focus_uses_source_names_and_bindings(self):
        quests = {1471: {"StartItem": 6284}}
        items = {6284: {"name": "Runes of Summoning", "spellid_1": 100, "spelltrigger_1": 0}}
        objects = {37097: {"name": "Summoning Circle", "type": 8, "Data0": 9}}
        spells = {100: {"RequiresSpellFocus": 9}}
        args = [quests, items, objects, spells, [], [], {}, {}]
        result = guides.derive_extra_guides(*args)[1471]["n:1"]
        self.assertEqual(result["n:2"], 3)
        self.assertEqual(result["n:3"], "Use Runes of Summoning at Summoning Circle")
        self.assertEqual(result["n:5"]["n:1"], {"n:1": "object", "n:2": 37097})
        objects[37097]["Data0"] = 10
        self.assertEqual(guides.derive_extra_guides(*args), {})
        objects[37097]["Data0"] = 9
        items[6284]["spelltrigger_1"] = 1
        self.assertEqual(guides.derive_extra_guides(*args), {})

    def container_args(self):
        return [{1027: {"RequiredItemId1": 5519}}, {5519: {"name": "Iron Pommel"}},
                {19021: {"name": "Rusty Chest", "type": 3}},
                {6464: {"Effect1": 76, "EffectMiscValue1": 19021, "EffectImplicitTargetA1": 18}},
                [], [{"entryorguid": 3928, "source_type": 0, "id": 1, "event_type": 6,
                      "event_chance": 75, "action_type": 11, "action_param1": 6464,
                      "action_param2": 7, "target_type": 1}],
                {5519: {"objectDrops": [19021]}},
                {3928: {"name": "Rotting Slime", "AIName": "SmartAI", "ScriptName": ""}}]

    def test_shared_focus_reports_requirement_without_expanding_global_map_targets(self):
        quests = {11377: {"StartItem": 33837}}
        items = {33837: {"name": "Cooking Pot", "spellid_1": 43718}}
        objects = {entry: {"name": "Cooking Fire", "type": 8, "Data0": 4}
                   for entry in range(1, 101)}
        spells = {43718: {"RequiresSpellFocus": 4}}
        packet = guides.derive_extra_guide_packet(quests, items, objects, spells, [], [], {}, {})
        self.assertEqual(packet["guides"], {})
        self.assertEqual(packet["evidence"], [])
        self.assertEqual(len(packet["omissions"]), 1)
        self.assertEqual(packet["omissions"][0]["reason"], "sharedSpellFocusDoesNotProveQuestLocation")
        self.assertEqual(packet["omissions"][0]["candidateObjectIds"], list(range(1, 101)))

    def test_explicit_target_condition_remains_valid_when_focus_identity_is_shared(self):
        quests = {1: {"StartItem": 2}}
        items = {2: {"name": "Tool", "spellid_1": 3}}
        objects = {4: {"name": "Chosen Object", "type": 8, "Data0": 10},
                   5: {"name": "Other Object", "type": 8, "Data0": 10}}
        spells = {3: {"RequiresSpellFocus": 10, "Effect1": 3}}
        conditions = [{"SourceTypeOrReferenceId": 17, "SourceEntry": 3, "ConditionTarget": 1,
                       "ConditionTypeOrReference": 31, "ConditionValue1": 5, "ConditionValue2": 4}]
        packet = guides.derive_extra_guide_packet(quests, items, objects, spells, conditions, [], {}, {})
        self.assertEqual(len(packet["guides"][1]), 1)
        self.assertEqual(packet["guides"][1]["n:1"]["n:5"]["n:1"], {"n:1": "object", "n:2": 4})
        self.assertEqual(packet["evidence"][0]["rule"], "questItemSpellTargetCondition")

    def test_1027_style_death_container_follows_actual_required_item_loot(self):
        args = self.container_args()
        result = guides.derive_extra_guides(*args)[1027]["n:1"]
        self.assertEqual(result["n:2"], 1)
        self.assertEqual(result["n:3"], "Defeat Rotting Slime to find Rusty Chest")
        self.assertEqual(result["n:5"]["n:1"], {"n:1": "monster", "n:2": 3928})
        args[6][5519]["objectDrops"] = []
        self.assertEqual(guides.derive_extra_guides(*args), {})

    def test_container_requires_actual_smart_binding_death_self_and_triggered_cast(self):
        for field, value in [("event_type", 0), ("target_type", 7), ("action_param2", 0),
                             ("event_chance", 0), ("event_phase_mask", 1)]:
            args = self.container_args()
            args[5][0][field] = value
            self.assertEqual(guides.derive_extra_guides(*args), {}, (field, value))
        args = self.container_args()
        args[7][3928]["ScriptName"] = "custom_cpp"
        self.assertEqual(guides.derive_extra_guides(*args), {})
        args = self.container_args()
        args[3][6464]["EffectImplicitTargetA1"] = 25
        self.assertEqual(guides.derive_extra_guides(*args), {})

    def test_self_timed_death_list_keeps_actor_and_rejects_handoff(self):
        args = self.container_args()
        cast = args[5][0]
        args[5] = [{"entryorguid": 3928, "source_type": 0, "id": 0, "event_type": 6,
                    "action_type": 80, "action_param1": 392800, "target_type": 1},
                   dict(cast, entryorguid=392800, source_type=9, event_type=0)]
        self.assertIn(1027, guides.derive_extra_guides(*args))
        args[5][0]["target_type"] = 19
        self.assertEqual(guides.derive_extra_guides(*args), {})
        args[5][0]["target_type"] = 1
        args[5].append({"entryorguid": 392800, "source_type": 9, "id": 0,
                        "event_type": 0, "action_type": 41, "target_type": 1})
        self.assertEqual(guides.derive_extra_guides(*args), {})

    def target_args(self):
        return [{9849: {"StartItem": 24501}},
                {24501: {"name": "Gordawg's Boulder", "spellid1": 32001, "spelltrigger1": 0}},
                {}, {32001: {"Effect1": 6}},
                [{"SourceTypeOrReferenceId": 17, "SourceEntry": 32001,
                  "ConditionTypeOrReference": 31, "ConditionTarget": 1,
                  "ConditionValue1": 3, "ConditionValue2": 17157}],
                [], {}, {17157: {"name": "Shattered Rumbler"}}]

    def test_quest_item_target_condition_recovers_source_instruction(self):
        args = self.target_args()
        hint = guides.derive_extra_guides(*args)[9849]["n:1"]
        self.assertEqual(hint["n:3"], "Use Gordawg's Boulder on Shattered Rumbler")
        self.assertEqual(hint["n:5"]["n:1"], {"n:1": "monster", "n:2": 17157})
        args[4][0].update(SourceTypeOrReferenceId=13, ConditionTarget=0, SourceGroup=1)
        self.assertIn(9849, guides.derive_extra_guides(*args))
        args[4][0]["SourceGroup"] = 2
        self.assertFalse(guides.derive_extra_guides(*args))

    def test_quest_item_conditions_exclude_caster_negative_guid_and_unrelated_item(self):
        for change in [{"ConditionTarget": 0}, {"NegativeCondition": 1},
                       {"ConditionValue3": 99}, {"ScriptName": "custom"},
                       {"SourceTypeOrReferenceId": 22}, {"SourceGroup": 1},
                       {"SourceEntry": 999}, {"ConditionValue2": 999}]:
            with self.subTest(change=change):
                args = self.target_args()
                args[4][0].update(change)
                self.assertFalse(guides.derive_extra_guides(*args))
        args = self.target_args()
        args[0][9849] = {}
        self.assertFalse(guides.derive_extra_guides(*args))
        args = self.target_args()
        args[4][0].update(SourceTypeOrReferenceId=13, ConditionTarget=1, SourceGroup=1)
        self.assertFalse(guides.derive_extra_guides(*args))

    def test_goober_interaction_requires_source_quest_and_default_handler(self):
        quests = {2381: {}}
        obj = {123462: {"name": "The Jewel of the Southsea", "type": 10, "Data1": 2381}}
        args = [quests, {}, obj, {}, [], [], {}, {}]
        hint = guides.derive_extra_guides(*args)[2381]["n:1"]
        self.assertEqual(hint["n:3"], "Interact with The Jewel of the Southsea")
        for change in [{"type": 3}, {"Data1": -1}, {"Data1": 999},
                       {"ScriptName": "custom"}, {"AIName": "other"}]:
            with self.subTest(change=change):
                original = dict(obj[123462])
                obj[123462].update(change)
                self.assertFalse(guides.derive_extra_guides(*args))
                obj[123462] = original

    def vehicle_args(self):
        return [{11390: {}}, {}, {},
                {43768: {"Effect2": 6, "EffectApplyAuraName2": 236,
                         "EffectImplicitTargetA2": 38}},
                [{"SourceTypeOrReferenceId": 18, "SourceGroup": 24418, "SourceEntry": 43768,
                  "ConditionTypeOrReference": 9, "ConditionTarget": 0, "ConditionValue1": 11390},
                 {"SourceTypeOrReferenceId": 13, "SourceGroup": 2, "SourceEntry": 43768,
                  "ConditionTypeOrReference": 31, "ConditionTarget": 0,
                  "ConditionValue1": 3, "ConditionValue2": 24418}],
                [], {}, {24418: {"name": "Steel Gate Flying Machine", "VehicleId": 8}},
                [{"npc_entry": 24418, "spell_id": 43768, "cast_flags": 3}]]

    def test_spellclick_vehicle_uses_actual_quest_aura_caster_and_delivery(self):
        args = self.vehicle_args()
        hint = guides.derive_extra_guides(*args)[11390]["n:1"]
        self.assertEqual(hint["n:3"], "Mount Steel Gate Flying Machine")
        self.assertEqual(hint["n:5"]["n:1"], {"n:1": "monster", "n:2": 24418})
        args[4].pop()
        args[3][43768]["EffectImplicitTargetA2"] = 25
        args[8][0]["cast_flags"] = 1
        self.assertIn(11390, guides.derive_extra_guides(*args))
        args[8][0]["cast_flags"] = 3
        self.assertFalse(guides.derive_extra_guides(*args))

    def test_spellclick_conditions_and_aura_alone_do_not_prove_mount(self):
        changes = [(4, 0, "ConditionTarget", 1), (4, 0, "NegativeCondition", 1),
                   (4, 1, "ConditionValue2", 999), (4, 1, "SourceGroup", 1),
                   (8, 0, "cast_flags", 0), (8, 0, "spell_id", 999)]
        for index, row, field, value in changes:
            with self.subTest(field=field, value=value):
                args = self.vehicle_args()
                args[index][row][field] = value
                self.assertFalse(guides.derive_extra_guides(*args))
        for field, value in [("EffectApplyAuraName2", 4), ("Effect2", 0),
                             ("EffectImplicitTargetA2", 1), ("EffectImplicitTargetB2", 25)]:
            args = self.vehicle_args()
            args[3][43768][field] = value
            self.assertFalse(guides.derive_extra_guides(*args))
        args = self.vehicle_args()
        args[7][24418]["VehicleId"] = 0
        self.assertFalse(guides.derive_extra_guides(*args))

    def summoned_finisher_args(self):
        quests = {10339: {}, 10384: {}, 999: {}}
        objects = {184383: {"name": "Ethereum Transponder Zeta", "type": 1,
                             "AIName": "SmartGameObjectAI"}}
        npcs = {20482: {"name": "Image of Commander Ameer", "npcflag": 2}}
        scripts = [{"entryorguid": 184383, "source_type": 1, "id": 0,
                    "event_type": 70, "event_param1": 2, "event_chance": 100,
                    "action_type": 12, "action_param1": 20482, "target_type": 8,
                    "target_x": 4017.97, "target_y": 2315.8, "target_z": 114.946}]
        relations = {10339: {"start": {"creature": {20448}}, "end": {"creature": {20482}}},
                     10384: {"start": {"creature": {20482}}, "end": {"creature": {20482}}},
                     999: {"start": {"creature": {20482}}}}
        return [quests, {}, objects, {}, [], scripts, {}, npcs, [], relations]

    def test_activated_button_summon_preserves_actual_quest_finisher_guidance(self):
        args = self.summoned_finisher_args()
        packet = guides.derive_extra_guide_packet(*args)
        self.assertEqual(set(packet["guides"]), {10339, 10384})
        hint = packet["guides"][10339]["n:1"]
        self.assertEqual(hint["n:3"], "Use Ethereum Transponder Zeta to summon Image of Commander Ameer")
        self.assertEqual(hint["n:5"]["n:1"], {"n:1": "object", "n:2": 184383})
        self.assertNotIn("n:1", hint, "Do not manufacture or copy a coordinate")
        self.assertTrue(all(row["rule"] == "activatedObjectSummonsQuestFinisher" for row in packet["evidence"]))
        args[9] = {}
        self.assertFalse(guides.derive_extra_guides(*args))

    def test_summoned_finisher_requires_bound_direct_activation_and_fixed_target(self):
        changes = [(5, "source_type", 9), (5, "event_type", 0), (5, "event_param1", 0),
                   (5, "event_param1", 1), (5, "action_type", 11), (5, "target_type", 1),
                   (5, "action_param1", 999), (5, "event_phase_mask", 1),
                   (5, "event_flags", 128), (5, "event_chance", 0), (5, "target_x", float("nan")),
                   (2, "AIName", ""), (2, "ScriptName", "custom_handler"), (2, "type", 5),
                   (7, "npcflag", 0)]
        for index, field, value in changes:
            with self.subTest(field=field, value=value):
                args = self.summoned_finisher_args()
                row = args[index][0] if index == 5 else args[index][184383 if index == 2 else 20482]
                row[field] = value
                self.assertFalse(guides.derive_extra_guides(*args))
        args = self.summoned_finisher_args()
        args[4] = [{"SourceTypeOrReferenceId": 22, "SourceEntry": 184383, "SourceId": 1}]
        self.assertFalse(guides.derive_extra_guides(*args))

    def test_goober_summon_does_not_cross_its_quest_use_gate(self):
        args = self.summoned_finisher_args()
        args[2][184383].update(type=10, Data1=10339)
        packet = guides.derive_extra_guide_packet(*args)
        self.assertIn(10339, packet["guides"])
        self.assertNotIn(10384, packet["guides"])
        summons = [row for row in packet["evidence"] if row["rule"] == "activatedObjectSummonsQuestFinisher"]
        self.assertEqual(len(summons), 1)


if __name__ == "__main__":
    unittest.main()
