import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_quest_guides as guides


class QuestGuideTests(unittest.TestCase):
    def fishing_args(self):
        quests, items, fishing = {}, {}, []
        for (quest_id, item), (catch, locations) in guides.FISHING_GUIDES.items():
            quest = quests.setdefault(quest_id, {"ID": quest_id})
            if quest_id == 13830:
                quest.update(ItemDrop1=item, ItemDropQuantity1=1)
            else:
                slot = 1 + sum(key.startswith("RequiredItemId") for key in quest)
                quest["RequiredItemId" + str(slot)] = item
                quest["RequiredItemCount" + str(slot)] = 1
            items[item] = {"entry": item, "name": "Quest fish " + str(item)}
            items[catch] = {"entry": catch, "name": "Catch " + str(catch)}
            for area, _, _ in locations:
                fishing.append({"Entry": area, "Item": 11012 if catch == 35313 else catch,
                                "Reference": 11012 if catch == 35313 else 0,
                                "Chance": 100, "MinCount": 1, "MaxCount": 1})
        references = [{"Entry": 11012, "Item": 35313, "Chance": 100, "MinCount": 1, "MaxCount": 1}]
        containers = [{"Entry": 35313, "Item": 34866, "Chance": 100, "MinCount": 1, "MaxCount": 2},
                      {"Entry": 45328, "Item": 45323, "Chance": 100, "MinCount": 1, "MaxCount": 1}]
        quests[9205].update(RequiredItemId1=22623, RequiredItemCount1=1,
                           RequiredItemId2=13890, RequiredItemCount2=30)
        return [quests, items, fishing, references, containers]

    def fishing_packet(self, args):
        packet = {"guides": {}, "evidence": []}
        guides.append_fishing_hints(packet, *args)
        return packet

    def test_reviewed_fishing_guides_follow_source_loot_and_link_real_or_source_item(self):
        args = self.fishing_args()
        packet = self.fishing_packet(args)
        self.assertEqual(set(packet["guides"]), {quest for quest, _ in guides.FISHING_GUIDES})
        indices = {}
        for (quest_id, item), (_, locations) in guides.FISHING_GUIDES.items():
            with self.subTest(quest=quest_id):
                indices[quest_id] = indices.get(quest_id, 0) + 1
                hint = packet["guides"][quest_id]["n:" + str(indices[quest_id])]
                self.assertEqual(hint["n:2"], 20)
                if quest_id == 13830:
                    self.assertEqual(hint["n:4"], 0)
                    self.assertEqual(hint["n:5"], guides.typed([["item", item]]))
                else:
                    required = [args[0][quest_id].get("RequiredItemId" + str(slot)) for slot in range(1, 7)]
                    self.assertEqual(hint["n:4"], required.index(item) + 1)
                    self.assertNotIn("n:5", hint, "Fishing water is not a fabricated NPC or object")
                self.assertEqual(set(hint["n:1"]), {"n:" + str(zone) for _, zone, _ in locations})
        self.assertIn("open it for", packet["guides"][11668]["n:1"]["n:3"])
        self.assertIn("open it for", packet["guides"][13836]["n:1"]["n:3"])
        self.assertEqual(len(packet["evidence"]), len(guides.FISHING_GUIDES))

    def test_fishing_guides_disappear_when_source_relationships_or_objectives_change(self):
        for mutate, missing in (
                (lambda a: a[2].clear(), {quest for quest, _ in guides.FISHING_GUIDES}),
                (lambda a: a[3].clear(), {11668}),
                (lambda a: a[4].clear(), {11668, 13836}),
                (lambda a: a[0][11667].update(RequiredItemId1=999), {11667}),
                (lambda a: a[0][11667].update(RequiredItemCount1=0), {11667}),
                (lambda a: a[0][11667].update(RequiredNpcOrGo1=999), {11667}),
                (lambda a: a[0][13830].update(ItemDrop1=999), {13830}),
                (lambda a: a[0][13830].update(ItemDropQuantity1=0), {13830}),
                (lambda a: a[1].pop(34868), {11667})):
            args = self.fishing_args()
            mutate(args)
            with self.subTest(missing=missing):
                self.assertEqual(set(self.fishing_packet(args)["guides"]), {quest for quest, _ in guides.FISHING_GUIDES} - missing)

    def test_fishing_guides_follow_current_item_order_without_adding_native_objectives(self):
        args = self.fishing_args()
        quest = args[0][6607]
        quest["RequiredItemId1"], quest["RequiredItemId4"] = quest["RequiredItemId4"], quest["RequiredItemId1"]
        packet = self.fishing_packet(args)
        self.assertEqual([hint["n:4"] for hint in packet["guides"][6607].values()], [4, 2, 3, 1])
        self.assertEqual(args[0][13830].get("RequiredItemId1"), None)

    def test_fishing_guides_keep_valid_areas_and_existing_optional_indices(self):
        args = self.fishing_args()
        args[2] = [row for row in args[2] if row["Entry"] != 1637]
        packet = {"guides": {11667: {"n:1": guides.typed({2: 3, 3: "Existing guide"})}},
                  "optional": {"11667": [1]}, "evidence": []}
        before = copy.deepcopy(packet["optional"])
        guides.append_fishing_hints(packet, *args)
        self.assertEqual(set(packet["guides"][11665]["n:1"]["n:1"]), {"n:1519"})
        self.assertEqual(packet["optional"], before)
        self.assertEqual(packet["guides"][11667]["n:2"]["n:4"], 1)

    def test_scripted_fishing_pool_requires_current_type_loot_and_quest_item(self):
        args = [{13833: {"ID": 13833, "RequiredItemId1": 45905, "RequiredItemCount1": 5}},
                {45905: {"entry": 45905, "name": "Bloodtooth Frenzy"}}, [], [], [],
                {194479: {"entry": 194479, "name": "Pool of Blood", "type": 25, "Data1": 27003}},
                [{"Entry": 27003, "Item": 45905, "Chance": 100, "MinCount": 2, "MaxCount": 3}]]
        packet = self.fishing_packet(args)
        self.assertEqual(packet["guides"][13833]["n:1"]["n:4"], 1)
        self.assertIn("Create a Pool of Blood", packet["guides"][13833]["n:1"]["n:3"])
        self.assertEqual(packet["evidence"][0]["fishingObjectIds"], [194479])
        for mutate in (lambda a: a[5][194479].update(type=3), lambda a: a[5][194479].update(Data1=999),
                       lambda a: a[6].clear(), lambda a: a[0][13833].update(RequiredItemId1=999)):
            changed = copy.deepcopy(args)
            mutate(changed)
            self.assertEqual(self.fishing_packet(changed)["guides"], {})

    def linked_escort_args(self):
        quests = {660: {"LogTitle": "Hints of a New Plague?", "SpecialFlags": 2}}
        creatures = {2713: {"entry": 2713, "name": "Kinelory", "AIName": "SmartAI", "ScriptName": ""}}
        scripts = [
            {"id": 2, "link": 3, "event_type": 19, "event_param1": 660, "action_type": 1, "target_type": 7},
            {"id": 3, "link": 4, "event_type": 61, "action_type": 53, "action_param2": 2713,
             "action_param4": 660, "target_type": 1},
            {"id": 4, "event_type": 61, "action_type": 64, "action_param1": 0, "target_type": 7},
            {"id": 20, "link": 21, "event_type": 40, "event_param1": 35, "event_param2": 2713,
             "action_type": 15, "action_param1": 660, "target_type": 12, "target_param1": 0},
            {"id": 21, "event_type": 61, "action_type": 41, "target_type": 1},
        ]
        for row in scripts:
            row.update(entryorguid=2713, source_type=0, event_chance=100)
        nodes = [{"entry": 2713, "pointid": point, "position_x": point,
                  "position_y": 50, "position_z": 1} for point in range(1, 38)]
        return [quests, creatures, scripts, nodes, [{"guid": 1, "id1": 2713, "map": 0}],
                lambda node, *_: (45, [node["position_x"], node["position_y"]])]

    def test_linked_quest_accept_uses_explicit_credit_waypoint_before_path_end(self):
        args = self.linked_escort_args()
        packet = guides.derive_escort_guide_packet(*args)
        self.assertEqual(packet["guides"][660], guides.typed(["Escort Kinelory to safety", {45: [[35, 50]]}]))
        self.assertEqual(packet["evidence"][0]["pointId"], 35)
        self.assertEqual(packet["evidence"][0]["rule"], "smartEscortWaypointCredit")
        args[2][3]["event_param1"] = 34
        self.assertEqual(guides.derive_escort_guide_packet(*args)["evidence"][0]["pointId"], 34)

    def test_linked_escort_rejects_unproved_player_credit_and_activation(self):
        changes = [(0, "event_param1", 661), (1, "link", 0), (1, "event_type", 0),
                   (2, "target_type", 1), (2, "event_type", 11), (3, "target_param1", 7),
                   (2, "event_phase_mask", 1), (2, "event_chance", 50),
                   (3, "target_type", 1), (3, "event_type", 0), (3, "event_param1", 99),
                   (3, "event_param2", 999), (3, "event_phase_mask", 1), (3, "event_chance", 50)]
        for index, field, value in changes:
            with self.subTest(index=index, field=field):
                args = self.linked_escort_args()
                args[2][index][field] = value
                self.assertNotIn(660, guides.derive_escort_guide_packet(*args)["guides"])

    def test_linked_escort_rejects_cycles_multiple_parents_and_multiple_credit_points(self):
        for extra in [
            {"id": 8, "link": 3, "event_type": 19, "event_param1": 660},
            {"id": 8, "link": 3, "event_type": 61},
            {"id": 3, "event_type": 19, "event_param1": 660},
            {"id": 8, "event_type": 40, "event_param1": 30, "event_param2": 2713,
             "action_type": 15, "action_param1": 660, "target_type": 12},
        ]:
            args = self.linked_escort_args()
            args[2].append(dict(entryorguid=2713, source_type=0, event_chance=100, **extra))
            self.assertNotIn(660, guides.derive_escort_guide_packet(*args)["guides"])

    def cpp_escort_args(self):
        proof = {"questId": 435, "npcId": 1978, "pointId": 13, "script": "escort",
                 "file": "event.cpp", "line": 20}
        packet = {"escortWaypoints": [proof], "events": {"435": [["monster", 1978]]},
                  "evidence": {"435": [dict(proof, actor=["monster", 1978])]}}
        return [{435: {"SpecialFlags": 2}}, {1978: {"entry": 1978, "ScriptName": "escort", "name": "Erland"}},
                packet, [{"entry": 1978, "pointid": point, "location_x": point,
                          "location_y": 50, "location_z": 1} for point in range(16)],
                [{"id1": 1978, "map": 0}], lambda node, *_: (130, [node["position_x"], node["position_y"]])]

    def test_cpp_escort_projects_credited_waypoint_not_last_point(self):
        args = self.cpp_escort_args()
        packet = guides.derive_cpp_escort_guide_packet(*args)
        self.assertEqual(packet["guides"][435], guides.typed(["Escort Erland to safety", {130: [[13, 50]]}]))
        self.assertEqual(packet["evidence"][0]["rule"], "cppEscortWaypointCredit")
        args[3][13]["location_x"] = 14
        self.assertEqual(guides.derive_cpp_escort_guide_packet(*args)["guides"][435]["n:2"],
                         guides.typed({130: [[14, 50]]}))

    def test_cpp_escort_rejects_changed_binding_bad_geometry_and_partial_alternatives(self):
        for change in ("template", "spawn", "point", "duplicate", "nan", "map", "alternative", "event", "unmapped",
                       "same_actor_credit", "missing_evidence"):
            with self.subTest(change=change):
                args = self.cpp_escort_args()
                if change == "template": args[1][1978]["ScriptName"] = "other"
                elif change == "spawn": args[4][0]["ScriptName"] = "other"
                elif change == "point": args[3].pop(13)
                elif change == "duplicate": args[3].append(dict(args[3][13]))
                elif change == "nan": args[3][13]["location_x"] = float("nan")
                elif change == "map": args[4].append({"id1": 1978, "map": 1})
                elif change == "alternative": args[2]["events"]["435"].append(["monster", 999])
                elif change == "event": args[0][435]["SpecialFlags"] = 0
                elif change == "unmapped": args[5] = lambda *_: (None, None)
                elif change == "same_actor_credit": args[2]["evidence"]["435"].append(dict(args[2]["evidence"]["435"][0]))
                elif change == "missing_evidence": args[2]["evidence"] = {}
                self.assertNotIn(435, guides.derive_cpp_escort_guide_packet(*args)["guides"])

    def test_cpp_escort_reviewed_wait_final_point_and_display_zone_are_enforced(self):
        args = self.cpp_escort_args()
        proof = args[2]["escortWaypoints"][0]
        proof["minimumWaitMs"] = 5000
        args[3][13]["waittime"] = 4999
        self.assertNotIn(435, guides.derive_cpp_escort_guide_packet(*args)["guides"])
        args[3][13]["waittime"] = 5000
        self.assertIn(435, guides.derive_cpp_escort_guide_packet(*args)["guides"])
        proof["requireLastPoint"] = True
        self.assertNotIn(435, guides.derive_cpp_escort_guide_packet(*args)["guides"])
        proof["pointId"] = 15
        args[3][15]["waittime"] = 5000
        proof["displayZone"] = 40
        args[0][435]["QuestSortID"] = -141
        args[5] = lambda node, _spawn, quest: (quest["QuestSortID"], [node["position_x"], node["position_y"]])
        packet = guides.derive_cpp_escort_guide_packet(*args)
        self.assertEqual(packet["guides"][435]["n:2"], guides.typed({40: [[15, 50]]}))
        self.assertEqual(args[0][435]["QuestSortID"], -141)

    def cpp_destination_args(self, kind="followerDestinations"):
        proof = {"questId": 1560, "actor": ["monster", 5955], "destinationNpcId": 6015,
                 "script": "npc_tooga", "file": "event.cpp", "line": 10,
                 "class": "ToogaAI", "call": "GroupEventHappens"}
        if kind != "followerDestinations":
            proof.pop("destinationNpcId")
        if kind == "coordinateCredits":
            proof.update(position_x=70, position_y=80, position_z=0)
        packet = {kind: [proof], "evidence": {"1560": [dict(proof)]}}
        creatures = {5955: {"entry": 5955, "name": "Tooga", "ScriptName": "npc_tooga"},
                     6015: {"entry": 6015, "name": "Torta", "ScriptName": "", "AIName": ""}}
        spawns = [{"guid": 1, "id1": 5955, "map": 1, "position_x": 30, "position_y": 40, "position_z": 0},
                  {"guid": 2, "id1": 6015, "map": 1, "position_x": 66, "position_y": 44, "position_z": 0}]
        return [{1560: {"SpecialFlags": 2, "AreaDescription": "Lead Tooga to Torta"}}, creatures, packet, spawns,
                lambda node, *_: (440, [node["position_x"], node["position_y"]])]

    def test_cpp_destination_projects_follower_target_proximity_actor_and_fixed_coordinate(self):
        for kind, expected in (("followerDestinations", [66, 44]), ("proximityCredits", [30, 40]),
                               ("coordinateCredits", [70, 80])):
            with self.subTest(kind=kind):
                packet = guides.derive_cpp_destination_guide_packet(*self.cpp_destination_args(kind))
                self.assertEqual(packet["guides"][1560]["n:2"], guides.typed({440: [expected]}))
                self.assertEqual(packet["evidence"][0]["actor"], ["monster", 5955])

    def test_cpp_destination_rejects_overrides_missing_targets_movement_and_unproved_calls(self):
        for change in ("source_script", "spawn_script", "missing_target", "no_target_spawns", "target_map",
                       "target_script", "target_ai", "moving", "wandering", "nan", "unmapped", "extra_call", "event"):
            with self.subTest(change=change):
                args = self.cpp_destination_args()
                if change == "source_script": args[1][5955]["ScriptName"] = "other"
                elif change == "spawn_script": args[3][0]["ScriptName"] = "other"
                elif change == "missing_target": args[1].pop(6015)
                elif change == "no_target_spawns": args[3].pop()
                elif change == "target_map": args[3][1]["map"] = 0
                elif change == "target_script": args[1][6015]["ScriptName"] = "moving"
                elif change == "target_ai": args[1][6015]["AIName"] = "SmartAI"
                elif change == "moving": args[3][1]["MovementType"] = 2
                elif change == "wandering": args[3][1].update(MovementType=1, wander_distance=5)
                elif change == "nan": args[3][1]["position_x"] = float("nan")
                elif change == "unmapped": args[4] = lambda *_: (None, None)
                elif change == "extra_call": args[2]["evidence"]["1560"].append(dict(args[2]["evidence"]["1560"][0]))
                elif change == "event": args[0][1560]["SpecialFlags"] = 0
                self.assertNotIn(1560, guides.derive_cpp_destination_guide_packet(*args)["guides"])

    def test_spawn_movement_overrides_template_defaults(self):
        args = self.cpp_destination_args()
        args[1][6015]["MovementType"] = 1
        args[3][1].update(MovementType=0, wander_distance=5)
        self.assertIn(1560, guides.derive_cpp_destination_guide_packet(*args)["guides"])
        args[3][1].pop("MovementType")
        self.assertNotIn(1560, guides.derive_cpp_destination_guide_packet(*args)["guides"])

    def test_reviewed_proximity_display_zone_requires_matching_world_map(self):
        args = self.cpp_destination_args("proximityCredits")
        args[2]["proximityCredits"][0].update(displayMap=1, displayZone=3557)
        args[4] = lambda node, _spawn, quest: (quest["QuestSortID"], [20, 30])
        packet = guides.derive_cpp_destination_guide_packet(*args)
        self.assertEqual(packet["guides"][1560]["n:2"], guides.typed({3557: [[20, 30]]}))
        args[2]["proximityCredits"][0]["displayMap"] = 530
        self.assertNotIn(1560, guides.derive_cpp_destination_guide_packet(*args)["guides"])

    def test_cpp_destination_does_not_publish_a_partial_set_of_follow_targets(self):
        args = self.cpp_destination_args()
        alternative = dict(args[2]["followerDestinations"][0], destinationNpcId=999)
        args[2]["followerDestinations"].append(alternative)
        args[2]["evidence"]["1560"].append(dict(alternative))
        self.assertNotIn(1560, guides.derive_cpp_destination_guide_packet(*args)["guides"])

    def test_interactions_keep_npc_entity_hints_and_project_all_object_spawns(self):
        quests = {2954: {"SpecialFlags": 2}, 4285: {"SpecialFlags": 2}}
        npcs = {7918: {"entry": 7918, "name": "Stone Watcher"}}
        objects = {164955: {"entry": 164955, "name": "Northern Pylon"}}
        proofs = [{"questId": 2954, "actor": ["monster", 7918]},
                  {"questId": 4285, "actor": ["object", 164955]}]
        spawns = [{"id1": 7918, "map": 1}]
        object_spawns = [{"id": 164955, "map": 1, "position_x": 10, "position_y": 20},
                         {"id": 164955, "map": 1, "position_x": 30, "position_y": 40}]
        project = lambda node, *_: (490, [node["position_x"], node["position_y"]])
        packet = guides.derive_interaction_guide_packet(quests, npcs, objects, proofs, spawns, object_spawns, project)
        self.assertNotIn(2954, packet["guides"])
        self.assertEqual(packet["guides"][4285]["n:2"], guides.typed({490: [[10, 20], [30, 40]]}))
        self.assertEqual({proof["questId"] for proof in packet["interactions"]}, {2954, 4285})
        object_spawns[1]["ScriptName"] = "overridden"
        rejected = guides.derive_interaction_guide_packet(quests, npcs, objects, proofs, spawns, object_spawns, project)
        self.assertNotIn(4285, rejected["guides"])
        self.assertEqual([proof["questId"] for proof in rejected["interactions"]], [2954])

    def test_follower_interaction_fallback_keeps_credit_source_binding_and_spawn_overrides(self):
        for change in (None, "source_script", "source_spawn_script", "missing_source", "missing_target", "target_map"):
            with self.subTest(change=change):
                args = self.cpp_destination_args()
                proof = dict(args[2]["followerDestinations"][0], creditActor=["monster", 5955], actor=["monster", 6015])
                if change == "source_script": args[1][5955]["ScriptName"] = "other"
                elif change == "source_spawn_script": args[3][0]["ScriptName"] = "other"
                elif change == "missing_source": args[3].pop(0)
                elif change == "missing_target": args[1].pop(6015)
                elif change == "target_map": args[3][1]["map"] = 0
                packet = guides.derive_interaction_guide_packet(args[0], args[1], {}, [proof], args[3], [], args[4])
                self.assertEqual(packet["guides"], {})
                if change is None:
                    self.assertEqual(packet["interactions"][0]["actor"], ["monster", 6015])
                    self.assertEqual(packet["interactions"][0]["creditActor"], ["monster", 5955])
                else:
                    self.assertEqual(packet["interactions"], [])

    def test_interaction_append_preserves_sparse_optional_indices_and_deduplicates_targets(self):
        packet = {"guides": {1: {"n:1": guides.typed({2: 3, 3: "Take the flight", 4: 0, 5: [["monster", 100]]}),
                                "n:3": guides.typed({2: 3, 3: "Other guide", 4: 0, 5: [["object", 200]]})}},
                  "optional": {"1": [1]}, "evidence": []}
        original = dict(packet["guides"][1])
        hints = [{"questId": 1, "actor": ["monster", 100], "label": "Duplicate"},
                 {"questId": 1, "actor": ["monster", 300], "label": "Talk"},
                 {"questId": 2, "actor": ["monster", 400], "label": "Skip"}]
        guides.append_interaction_hints(packet, hints, skip_quests={2})
        self.assertEqual(packet["optional"], {"1": [1]})
        self.assertEqual(packet["guides"][1]["n:1"], original["n:1"])
        self.assertEqual(packet["guides"][1]["n:3"], original["n:3"])
        self.assertEqual(packet["guides"][1]["n:4"]["n:5"], guides.typed([["monster", 300]]))
        self.assertEqual(len(packet["evidence"]), 1)
        self.assertNotIn(2, packet["guides"])
        guides.append_interaction_hints(packet, hints, skip_quests={2})
        self.assertEqual(len(packet["evidence"]), 1)

    def test_location_packet_combination_requires_all_known_actors_and_merges_duplicate_points(self):
        def packet(actor, points):
            return {"guides": {1: guides.typed(["Destination", {40: points}])},
                    "evidence": [{"questId": 1, "actor": ["monster", actor]}], "omissions": []}
        first, second = packet(100, [[10, 20]]), packet(200, [[10, 20], [30, 40]])
        sources = {"1": [["monster", 100], ["monster", 200]]}
        self.assertNotIn(1, guides.combine_location_guide_packets([first], sources)["guides"])
        combined = guides.combine_location_guide_packets([first, second], sources)
        self.assertEqual(combined["guides"][1]["n:2"], guides.typed({40: [[10, 20], [30, 40]]}))
        self.assertEqual(len(combined["evidence"]), 2)

    def test_new_complete_proof_supersedes_conservative_omissions_without_losing_other_faction(self):
        args = self.escort_args()
        old = guides.derive_escort_guide_packet(*args)
        old["guides"].pop(13229)
        old["evidence"] = [proof for proof in old["evidence"] if proof["questId"] != 13229]
        old["omissions"].append({"questId": 13229, "npcId": 31279, "pathId": 31279,
                                 "scriptEntry": 31279, "rowId": 1, "reason": "unsupportedEscortActivation"})
        self.assertEqual(set(old["guides"]), {13221})
        new = {"guides": {13229: guides.typed(["Explicit credit", {210: [[31.98, 57.06]]}])},
               "evidence": [{"questId": 13229, "actor": ["monster", 31279], "rule": "smartExplicitWaypointCredit",
                             "sourceType": 0, "scriptEntry": 31279, "pathIds": [31279]}],
               "omissions": []}
        sources = {str(q): [["monster", 31279]] for q in (13221, 13229)}
        combined = guides.combine_location_guide_packets([old, new], sources)
        self.assertEqual(set(combined["guides"]), {13221, 13229})
        self.assertEqual([(proof["questId"], proof["reason"]) for proof in combined["supersededOmissions"]],
                         [(13229, "unsupportedEscortActivation")])
        sources["13229"].append(["monster", 999])
        rejected = guides.combine_location_guide_packets([old, new], sources)
        self.assertEqual(set(rejected["guides"]), {13221})
        self.assertEqual(rejected["supersededOmissions"], [])

    def test_combiner_does_not_supersede_unmatched_same_actor_or_repeat_omissions(self):
        args = self.escort_args()
        args[2][1]["action_param3"] = 1
        old = guides.derive_escort_guide_packet(*args)
        new = {"guides": {13229: guides.typed(["Explicit credit", {210: [[31.98, 57.06]]}])},
               "evidence": [{"questId": 13229, "actor": ["monster", 31279], "rule": "smartExplicitWaypointCredit",
                             "sourceType": 0, "scriptEntry": 31279, "pathIds": [31279]}], "omissions": []}
        sources = {str(q): [["monster", 31279]] for q in (13221, 13229)}
        for change in ("repeat", "same_actor_unknown_call", "owner", "actor", "path", "source_type"):
            with self.subTest(change=change):
                omission = dict(old["omissions"][0])
                if change == "same_actor_unknown_call": omission["reason"] = "unprovedAlternativeDestinationCredit"
                elif change != "repeat":
                    omission["reason"] = "unsupportedEscortActivation"
                    if change == "owner": omission["scriptEntry"] = -121631
                    elif change == "actor": omission["npcId"] = 999
                    elif change == "path": omission["pathId"] = 999
                selected = dict(old, omissions=[omission])
                replacement = new
                if change == "source_type":
                    replacement = dict(new, evidence=[dict(new["evidence"][0], sourceType=9)])
                packet = guides.combine_location_guide_packets([selected, replacement], sources)
                self.assertEqual(set(packet["guides"]), {13221})
                self.assertEqual(packet["supersededOmissions"], [])

    def escort_args(self):
        quests = {quest: {"LogTitle": "I'm Not Dead Yet!", "QuestSortID": 210, "SpecialFlags": 2}
                  for quest in (13221, 13229)}
        creatures = {31279: {"entry": 31279, "name": "Father Kamaros", "AIName": "SmartAI", "ScriptName": ""}}
        starts = [{"entryorguid": 31279, "source_type": 0, "id": index, "event_type": 19,
                   "event_param1": quest, "event_chance": 100, "action_type": 53,
                   "action_param2": 31279, "action_param4": quest, "target_type": 7}
                  for index, quest in enumerate(quests)]
        starts += [{"entryorguid": 31279, "source_type": 0, "id": 8, "link": 9,
                    "event_type": 40, "event_param1": 24, "action_type": 1, "target_type": 12},
                   {"entryorguid": 31279, "source_type": 0, "id": 9, "event_type": 61,
                    "action_type": 41, "action_param1": 12000, "target_type": 1}]
        nodes = [{"entry": 31279, "pointid": index, "position_x": index,
                  "position_y": index, "position_z": 600} for index in range(1, 25)]
        nodes[-1].update(position_x=7041.24, position_y=3438.29, position_z=695.568)
        spawns = [{"guid": 121631, "id1": 31279, "map": 571}]
        return [quests, creatures, starts, nodes, spawns, lambda *_: (210, [31.98, 57.06])]

    def test_escort_endpoint_is_derived_for_both_factions_and_follows_source_changes(self):
        args = self.escort_args()
        calls = []

        def project(node, spawn, quest):
            calls.append((node["pointid"], spawn["map"], quest["QuestSortID"]))
            return 210, [node["position_x"] / 1000, node["position_y"] / 1000]

        args[-1] = project
        packet = guides.derive_escort_guide_packet(*args)
        self.assertEqual(set(packet["guides"]), {13221, 13229})
        self.assertEqual(calls, [(24, 571, 210), (24, 571, 210)])
        self.assertEqual(packet["omissions"], [])
        before = packet["guides"][13229]
        self.assertEqual(before["n:1"], "Escort Father Kamaros to safety")
        args[3][-1]["position_x"] += 100
        self.assertNotEqual(guides.derive_escort_guide_packet(*args)["guides"][13229], before)
        args[0][13229]["AreaDescription"] = "Escort the priest."
        self.assertEqual(guides.derive_escort_guide_packet(*args)["guides"][13229]["n:1"], "Escort the priest.")

    def test_escort_rejects_unsupported_activation_repeat_phase_and_script_binding(self):
        for field, value in (("event_type", 62), ("event_param1", 999), ("target_type", 1),
                             ("action_param4", 0), ("action_param3", 1), ("event_phase_mask", 1),
                             ("event_chance", 50)):
            with self.subTest(field=field):
                args = self.escort_args()
                for row in args[2][:2]:
                    row[field] = value
                self.assertEqual(guides.derive_escort_guide_packet(*args)["guides"], {})
        for field, value in (("AIName", ""), ("ScriptName", "custom_script")):
            args = self.escort_args()
            args[1][31279][field] = value
            self.assertEqual(guides.derive_escort_guide_packet(*args)["guides"], {})
        args = self.escort_args()
        conditions = [{"SourceTypeOrReferenceId": 22, "SourceId": 0, "SourceEntry": 31279, "SourceGroup": 1}]
        self.assertEqual(guides.derive_escort_guide_packet(*args, conditions=conditions)["guides"], {})

    def test_escort_does_not_add_a_required_event_to_an_ordinary_quest(self):
        args = self.escort_args()
        args[0][13229]["SpecialFlags"] = 0
        packet = guides.derive_escort_guide_packet(*args)
        self.assertNotIn(13229, packet["guides"])
        self.assertIn(13221, packet["guides"])
        self.assertIn(13229, guides.derive_escort_guide_packet(*args, quest_special_flags={13229: 2})["guides"])

    def test_repeating_escort_invalidates_only_its_quest_and_restores_after_refresh(self):
        for index, quest_id in enumerate((13221, 13229)):
            with self.subTest(quest_id=quest_id):
                args = self.escort_args()
                args[2][index]["action_param3"] = 1
                packet = guides.derive_escort_guide_packet(*args)
                self.assertEqual(set(packet["guides"]), {13221, 13229} - {quest_id})
                self.assertEqual([(proof["questId"], proof["reason"]) for proof in packet["omissions"]],
                                 [(quest_id, "conditionalOrRepeatingEscort")])
                args[2][index]["action_param3"] = 0
                self.assertEqual(set(guides.derive_escort_guide_packet(*args)["guides"]), {13221, 13229})

        args = self.escort_args()
        args[2].append(dict(args[2][0], id=10, action_param3=1))
        self.assertEqual(set(guides.derive_escort_guide_packet(*args)["guides"]), {13229})

    def test_escort_rejects_early_credit_successful_stops_reroutes_and_action_lists(self):
        for action, parameters in ((15, {"action_param1": 13229}), (26, {"action_param1": 13229}),
                                   (55, {}), (62, {}), (69, {}), (80, {"action_param1": 3127900}),
                                   (87, {}), (88, {}), (53, {"action_param2": 999})):
            with self.subTest(action=action):
                args = self.escort_args()
                args[2].append({"entryorguid": 31279, "source_type": 0, "id": 10, "event_type": 0,
                                "action_type": action, "target_type": 1, **parameters})
                self.assertNotIn(13229, guides.derive_escort_guide_packet(*args)["guides"])
        args = self.escort_args()
        args[2].append({"entryorguid": 31279, "source_type": 0, "id": 10, "event_type": 0,
                        "action_type": 55, "action_param3": 1, "target_type": 1})
        self.assertIn(13229, guides.derive_escort_guide_packet(*args)["guides"])

    def test_escort_allows_pauses_and_terminal_despawn_but_rejects_early_despawn(self):
        args = self.escort_args()
        args[2].append({"entryorguid": 31279, "source_type": 0, "id": 10, "event_type": 40,
                        "event_param1": 10, "action_type": 54, "action_param1": 5000, "target_type": 1})
        self.assertIn(13229, guides.derive_escort_guide_packet(*args)["guides"])
        args[2][2]["event_param1"] = 23
        packet = guides.derive_escort_guide_packet(*args)
        self.assertEqual(packet["guides"], {})
        self.assertEqual({row["reason"] for row in packet["omissions"]}, {"unprovedEarlyEscortDespawn"})

    def test_escort_rejects_missing_gapped_nonfinite_or_unmapped_geometry(self):
        for change in (lambda args: args[3].clear(), lambda args: args[3].pop(5),
                       lambda args: args[3][0].update(pointid=2),
                       lambda args: args[3][-1].update(position_x=float("nan")),
                       lambda args: args[4].clear(),
                       lambda args: args[4].append({"guid": 2, "id1": 31279, "map": 0}),
                       lambda args: args.__setitem__(-1, lambda *_: (None, None))):
            args = self.escort_args()
            change(args)
            self.assertEqual(guides.derive_escort_guide_packet(*args)["guides"], {})

    def test_escort_guid_scripts_and_duplicate_placements_preserve_correct_actor(self):
        args = self.escort_args()
        for row in args[2]:
            row["entryorguid"] = -121631
        packet = guides.derive_escort_guide_packet(*args)
        self.assertEqual(set(packet["guides"]), {13221, 13229})
        self.assertTrue(all(row["npcId"] == 31279 for row in packet["evidence"]))
        args = self.escort_args()
        args[4].append({"guid": 2, "id1": 31279, "map": 571})
        guide = guides.derive_escort_guide_packet(*args)["guides"][13229]
        self.assertEqual(len(guide["n:2"]["n:210"]), 1)

    def test_escort_does_not_publish_a_partial_set_of_alternatives(self):
        args = self.escort_args()
        args[2].append(dict(args[2][0], id=10, event_chance=50))
        packet = guides.derive_escort_guide_packet(*args)
        self.assertNotIn(13221, packet["guides"])
        self.assertIn(13229, packet["guides"])

    def test_escort_rejects_guid_overrides_and_merged_entry_scripts(self):
        args = self.escort_args()
        args[2].append({"entryorguid": -121631, "source_type": 0, "id": 0, "event_type": 11,
                        "action_type": 1, "target_type": 1})
        packet = guides.derive_escort_guide_packet(*args)
        self.assertEqual(packet["guides"], {})
        self.assertEqual({row["reason"] for row in packet["omissions"]}, {"overriddenOrMergedEscortScript"})
        args = self.escort_args()
        for row in args[2]:
            row["entryorguid"] = -121631
        args[2].append({"entryorguid": 31279, "source_type": 0, "id": 10, "event_type": 0,
                        "action_type": 55, "target_type": 1})
        self.assertIn(13229, guides.derive_escort_guide_packet(*args)["guides"])
        args[1][31279]["flags_extra"] = 0x08000000
        self.assertEqual(guides.derive_escort_guide_packet(*args)["guides"], {})

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

    def test_boiling_blood_keeps_both_instructions_at_the_visible_quest_cauldron(self):
        quests = {10538: {"RequiredItemId1": 30430, "ItemDrop1": 30425}}
        items = {30425: {"name": "Bleeding Hollow Blood", "spellid_1": 36546}}
        objects = {184722: {"name": "Cauldron Bug Summoner", "type": 6},
                   184715: {"name": "Cursed Cauldron", "type": 10, "Data1": 10538}}
        spells = {36546: {"Effect2": 77}}
        conditions = [{"SourceTypeOrReferenceId": 13, "SourceGroup": 2, "SourceEntry": 36546,
                       "ConditionTypeOrReference": 31, "ConditionValue1": 5, "ConditionValue2": 184722}]
        packet = guides.derive_extra_guide_packet(quests, items, objects, spells, conditions, [], {}, {})
        hints = list(packet["guides"][10538].values())
        self.assertEqual({hint["n:3"] for hint in hints},
                         {"Interact with Cursed Cauldron", "Use Bleeding Hollow Blood on Cursed Cauldron"})
        self.assertTrue(all(hint["n:5"] == guides.typed([["object", 184715]]) for hint in hints))
        self.assertIn({"questId": 10538, "rule": "questItemSpellTargetCondition", "itemId": 30425,
                       "spellId": 36546, "kind": "object", "entry": 184715, "sourceEntry": 184722}, packet["evidence"])

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
