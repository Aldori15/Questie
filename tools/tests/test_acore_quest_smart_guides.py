import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_quest_smart_guides as smart


class SmartQuestGuideTests(unittest.TestCase):
    def args(self):
        scripts = [
            {"id": 0, "event_type": 19, "event_param1": 10887, "action_type": 53,
             "action_param2": 22377, "action_param4": 0, "target_type": 7},
            {"id": 11, "link": 12, "event_type": 40, "event_param1": 35,
             "action_type": 15, "action_param1": 10887, "target_type": 18, "target_param1": 40},
            {"id": 12, "event_type": 61, "action_type": 41, "target_type": 1},
        ]
        for row in scripts:
            row.update(entryorguid=22377, source_type=0, event_chance=100)
        return [
            {10887: {"SpecialFlags": 2, "AreaDescription": "Escort Akuno"}},
            {22377: {"entry": 22377, "AIName": "SmartAI", "ScriptName": "", "name": "Akuno"}}, {}, scripts,
            [{"entry": 22377, "pointid": 35, "position_x": 28, "position_y": 52, "position_z": -9.7}],
            [{"guid": 1, "id1": 22377, "map": 530}],
            lambda node, *_: (3519, [node["position_x"], node["position_y"]]),
        ]

    def test_explicit_waypoint_credit_does_not_require_endpath_quest_parameter(self):
        packet = smart.derive(*self.args())
        self.assertEqual(packet["guides"][10887], smart.common.typed(["Escort Akuno", {3519: [[28, 52]]}]))
        self.assertEqual(packet["omissions"], [])
        self.assertEqual(packet["evidence"][0]["pointId"], 35)
        self.assertEqual(packet["evidence"][0]["actor"], ["monster", 22377])

    def test_post_credit_return_path_does_not_replace_completion_point(self):
        args = self.args()
        args[3][1].update(event_param2=22377, target_type=17, target_param1=0, target_param2=30)
        args[3][2].update(action_type=53, action_param2=22378, action_param4=0)
        args[4].append({"entry": 22378, "pointid": 35, "position_x": 70, "position_y": 80, "position_z": 0})
        self.assertEqual(smart.derive(*args)["guides"][10887]["n:2"], smart.common.typed({3519: [[28, 52]]}))
        args[3].append({"entryorguid": 22377, "source_type": 0, "id": 20, "event_type": 40,
                        "event_param1": 34, "action_type": 80, "action_param1": 2237700, "target_type": 1})
        args[3].append({"entryorguid": 2237700, "source_type": 9, "id": 0, "event_type": 0,
                        "action_type": 1, "target_type": 1})
        self.assertIn(10887, smart.derive(*args)["guides"])

    def test_wildcard_credit_includes_each_known_matching_escort_path(self):
        args = self.args()
        args[3].append(dict(args[3][0], id=20, action_param2=22378))
        args[4].append({"entry": 22378, "pointid": 35, "position_x": 70, "position_y": 80, "position_z": 0})
        self.assertEqual(smart.derive(*args)["guides"][10887]["n:2"],
                         smart.common.typed({3519: [[28, 52], [70, 80]]}))

    def test_wildcard_credit_requires_the_point_on_every_possible_path(self):
        args = self.args()
        args[3].append(dict(args[3][0], id=20, action_param2=22378))
        args[4].append({"entry": 22378, "pointid": 34, "position_x": 70, "position_y": 80, "position_z": 0})
        self.assertNotIn(10887, smart.derive(*args)["guides"])
        args[4].append(dict(args[4][1], pointid=35))
        self.assertIn(10887, smart.derive(*args)["guides"])

    def test_teleport_before_linked_credit_is_rejected_but_after_credit_is_safe(self):
        args = self.args()
        args[3][2].update(action_type=62)
        self.assertIn(10887, smart.derive(*args)["guides"])
        args[3][1].update(action_type=62)
        args[3][2].update(action_type=15, action_param1=10887, target_type=18)
        self.assertNotIn(10887, smart.derive(*args)["guides"])

    def test_independent_movement_for_same_waypoint_cannot_precede_the_credit(self):
        for action in (62, 69, 80):
            with self.subTest(action=action):
                args = self.args()
                args[3].insert(1, {"entryorguid": 22377, "source_type": 0, "id": 10,
                                   "event_type": 40, "event_param1": 35, "event_chance": 100,
                                   "action_type": action, "target_type": 1})
                self.assertNotIn(10887, smart.derive(*args)["guides"])

    def test_successful_stop_cannot_supply_credit_elsewhere_but_failure_or_post_credit_stop_is_safe(self):
        for point_id in (34, 35):
            with self.subTest(point_id=point_id):
                args = self.args()
                stop = {"entryorguid": 22377, "source_type": 0, "id": 10, "event_type": 40,
                        "event_param1": point_id, "event_chance": 100, "action_type": 55,
                        "action_param2": 10887, "action_param3": 0, "target_type": 1}
                args[3].append(stop)
                self.assertNotIn(10887, smart.derive(*args)["guides"])
                stop["action_param3"] = 1
                self.assertIn(10887, smart.derive(*args)["guides"])
        args = self.args()
        args[3][2].update(action_type=55, action_param2=10887, action_param3=0)
        self.assertIn(10887, smart.derive(*args)["guides"])

    def test_waypoint_credit_rejects_conditional_missing_ambiguous_and_wrong_recipient_proofs(self):
        for change in ("phase", "chance", "path", "point", "duplicate_point", "ordinary_path", "recipient", "script", "spawn_script", "guid_override", "nonfinite", "unmapped"):
            with self.subTest(change=change):
                args = self.args()
                if change == "phase": args[3][1]["event_phase_mask"] = 1
                elif change == "chance": args[3][1]["event_chance"] = 50
                elif change == "path": args[3][1]["event_param2"] = 999
                elif change == "point": args[4].clear()
                elif change == "duplicate_point": args[4].append(dict(args[4][0]))
                elif change == "ordinary_path": args[5][0]["MovementType"] = 2
                elif change == "recipient": args[3][1]["target_type"] = 1
                elif change == "script": args[1][22377]["ScriptName"] = "other"
                elif change == "spawn_script": args[5][0]["ScriptName"] = "other"
                elif change == "guid_override": args[3].append(dict(args[3][0], entryorguid=-1))
                elif change == "nonfinite": args[4][0]["position_x"] = float("nan")
                elif change == "unmapped": args[6] = lambda *_: (None, None)
                self.assertNotIn(10887, smart.derive(*args)["guides"])
        args = self.args()
        conditions = [{"SourceTypeOrReferenceId": 22, "SourceId": 0, "SourceEntry": 22377}]
        self.assertNotIn(10887, smart.derive(*args, conditions=conditions)["guides"])

    def test_unknown_credit_alternative_drops_entire_quest_and_recovers_on_refresh(self):
        args = self.args()
        args[3].append(dict(args[3][1], id=20, link=0, event_type=0))
        self.assertNotIn(10887, smart.derive(*args)["guides"])
        args[3].pop()
        self.assertIn(10887, smart.derive(*args)["guides"])

    def test_unique_linked_presentation_is_accepted_cycles_and_multiple_parents_are_not(self):
        args = self.args()
        args[3][1].update(action_type=1)
        args[3][2].update(action_type=15, action_param1=10887, target_type=18)
        self.assertIn(10887, smart.derive(*args)["guides"])
        args[3].append(dict(args[3][1], id=20))
        self.assertNotIn(10887, smart.derive(*args)["guides"])

    def test_gossip_credit_returns_actor_interaction_without_fabricated_coordinates(self):
        args = self.args()
        args[3][1].update(event_type=62, event_param1=1, target_type=7)
        packet = smart.derive(*args)
        self.assertEqual(packet["guides"], {})
        self.assertEqual(packet["interactions"], [{"questId": 10887, "actor": ["monster", 22377], "label": "Speak with Akuno"}])

    def test_gameobject_gossip_requires_verified_spawn_scripts(self):
        args = self.args()
        args[2] = {22377: {"entry": 22377, "name": "Pylon", "AIName": "SmartGameObjectAI", "ScriptName": ""}}
        args[1] = {}
        args[3] = [dict(args[3][1], source_type=1, event_type=64, target_type=7, link=0)]
        self.assertEqual(smart.derive(*args)["interactions"], [])
        placements = [{"guid": 2, "id": 22377, "map": 530}]
        packet = smart.derive(*args, gameobject_spawns=placements)
        self.assertEqual(packet["interactions"][0]["actor"], ["object", 22377])
        placements[0]["ScriptName"] = "other"
        self.assertEqual(smart.derive(*args, gameobject_spawns=placements)["interactions"], [])

    def follow_args(self):
        args = self.args()
        args[3] = [dict(args[3][0], action_type=29, action_param3=200, action_param4=10887, action_param5=1)]
        args[1][200] = {"entry": 200, "name": "Destination", "ScriptName": "", "AIName": ""}
        args[5].append({"guid": 2, "id1": 200, "map": 530, "position_x": 40, "position_y": 50, "position_z": 0})
        return args

    def test_follow_event_uses_destination_creature_not_follower_start(self):
        packet = smart.derive(*self.follow_args())
        self.assertEqual(packet["guides"][10887]["n:2"], smart.common.typed({3519: [[40, 50]]}))
        self.assertEqual(packet["evidence"][0]["actor"], ["monster", 22377])
        self.assertEqual(packet["evidence"][0]["destinationNpcId"], 200)

    def test_moving_follow_destination_uses_entity_guidance(self):
        args = self.follow_args()
        args[1][200]["ScriptName"] = "moving_destination"
        packet = smart.derive(*args)
        self.assertEqual(packet["guides"], {})
        self.assertEqual(packet["interactions"][0]["actor"], ["monster", 200])
        args = self.follow_args()
        args[6] = lambda *_: (None, None)
        self.assertEqual(smart.derive(*args)["interactions"][0]["actor"], ["monster", 200])

    def test_follow_does_not_turn_kill_credit_or_wrong_invoker_into_quest_event(self):
        for field, value in (("action_param5", 0), ("target_type", 1), ("event_param1", 99)):
            args = self.follow_args()
            args[3][0][field] = value
            packet = smart.derive(*args)
            self.assertEqual(packet["guides"], {})
            self.assertEqual(packet["interactions"], [])

    def test_follow_rejects_destination_on_another_world_map_without_entity_fallback(self):
        args = self.follow_args()
        args[5][-1]["map"] = 0
        packet = smart.derive(*args)
        self.assertEqual(packet["guides"], {})
        self.assertEqual(packet["interactions"], [])
        self.assertEqual(packet["omissions"][0]["reason"], "ambiguousFollowDestinationMap")

    def region_args(self):
        args = self.args()
        args[0] = {12578: {"SpecialFlags": 2, "AreaDescription": "Travel to Mosswalker Village"}}
        args[3] = [dict(args[3][0], event_type=10, event_param1=1, event_param2=200,
                        action_type=134, action_param1=54057, target_type=7)]
        args[5][0].update(position_x=28, position_y=52, position_z=0)
        spell = {"Effect1": 16, "EffectMiscValue1": 12578, "EffectImplicitTargetA1": 1}
        gate = {"SourceTypeOrReferenceId": 22, "SourceId": 0, "SourceEntry": 22377,
                "SourceGroup": 1, "ConditionTypeOrReference": 1, "ConditionValue1": 51623}
        return args, {54057: spell}, [gate]

    def test_los_invoker_self_quest_spell_derives_region_and_retains_aura_gate_evidence(self):
        args, spells, conditions = self.region_args()
        packet = smart.derive(*args, conditions=conditions, spells=spells)
        self.assertEqual(packet["guides"][12578]["n:2"], smart.common.typed({3519: [[28, 52]]}))
        self.assertEqual(packet["evidence"][0]["spellId"], 54057)
        self.assertEqual(packet["evidence"][0]["conditionGates"][0]["ConditionValue1"], 51623)
        conditions[0]["NegativeCondition"] = 1
        self.assertIn(12578, smart.derive(*args, conditions=conditions, spells=spells)["guides"])

    def test_los_wandering_actor_keeps_entity_guidance_instead_of_fixed_endpoint(self):
        args, spells, conditions = self.region_args()
        args[5][0].update(MovementType=1, wander_distance=5)
        packet = smart.derive(*args, conditions=conditions, spells=spells)
        self.assertNotIn(12578, packet["guides"])
        self.assertEqual(packet["interactions"][0]["questId"], 12578)
        self.assertEqual(packet["interactions"][0]["actor"], ["monster", 22377])

    def test_los_region_rejects_unknown_spell_target_moving_actor_and_unknown_conditions(self):
        for change in ("target", "effect", "mixed_effects", "moving", "gate", "custom_gate", "unknown_reference"):
            with self.subTest(change=change):
                args, spells, conditions = self.region_args()
                if change == "target": spells[54057]["EffectImplicitTargetA1"] = 6
                elif change == "effect": spells[54057]["Effect1"] = 33
                elif change == "mixed_effects": spells[54057]["Effect2"] = 3
                elif change == "moving": args[5][0]["MovementType"] = 2
                elif change == "gate": conditions[0]["ConditionTypeOrReference"] = 22
                elif change == "custom_gate": conditions[0]["ScriptName"] = "custom"
                elif change == "unknown_reference": conditions[0]["ConditionTypeOrReference"] = -100
                self.assertNotIn(12578, smart.derive(*args, conditions=conditions, spells=spells)["guides"])

    def test_location_preserving_aura_references_are_classified_without_flattening_boolean_gates(self):
        args, spells, conditions = self.region_args()
        leaf = dict(conditions[0], SourceTypeOrReferenceId=-100, ElseGroup=1, NegativeCondition=1)
        conditions[0]["ConditionTypeOrReference"] = -100
        conditions.append(leaf)
        packet = smart.derive(*args, conditions=conditions, spells=spells)
        self.assertIn(12578, packet["guides"])
        self.assertEqual(len(packet["evidence"][0]["conditionGates"]), 2)
        conditions[1]["ConditionTypeOrReference"] = -100
        self.assertNotIn(12578, smart.derive(*args, conditions=conditions, spells=spells)["guides"])


if __name__ == "__main__":
    unittest.main()
