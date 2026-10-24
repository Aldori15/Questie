import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_quest_compatibility as compat


def objective(entity, category="n:1"):
    return {category: {"n:1": {"n:1": entity}}}


class QuestCompatibilityTests(unittest.TestCase):
    def test_negative_groups_follow_source_membership_and_scope(self):
        rows = [{"ID": i, "ExclusiveGroup": -20 if i < 4 else 20} for i in range(1, 5)]
        result = compat.derive_in_group_with({1, 2, 4}, rows)
        self.assertEqual(result, {"1": {"n:1": 2}, "2": {"n:1": 1}, "4": {}})

    def test_reputation_completion_and_opposite_eligibility_are_distinct(self):
        template = {"RequiredFactionId1": 87, "RequiredFactionValue1": 3000,
                    "RequiredFactionId2": 21, "RequiredFactionValue2": -6001}
        self.assertEqual(compat.derive_reputation_objective(template), {"n:1": 87, "n:2": 3000})

    def test_available_until_uses_conjunctive_negative_rewarded_gate(self):
        rows = [{"SourceTypeOrReferenceId": 19, "SourceEntry": 1462,
                 "ConditionTypeOrReference": 8, "ConditionValue1": 1521, "NegativeCondition": 1},
                {"SourceTypeOrReferenceId": 19, "SourceEntry": 1462,
                 "ConditionTypeOrReference": 28, "ConditionValue1": 1521, "NegativeCondition": 1}]
        self.assertEqual(compat.source_available_until_completed(rows), {"1462": 1521})
        rows[0]["ElseGroup"] = 1
        self.assertEqual(compat.source_available_until_completed(rows), {})

    def test_available_until_rejects_reference_and_multiple_completion_gates(self):
        rows = [{"SourceTypeOrReferenceId": 19, "SourceEntry": 20,
                 "ConditionTypeOrReference": 8, "ConditionValue1": value, "NegativeCondition": 1}
                for value in (21, 22)]
        self.assertEqual(compat.source_available_until_completed(rows), {})
        rows[1]["ConditionTypeOrReference"] = -123
        self.assertEqual(compat.source_available_until_completed(rows), {})

    def test_same_targets_can_keep_display_text_and_icons(self):
        display = {"n:1": {"n:1": {"n:1": 20, "n:2": "Speak to this NPC", "n:3": 3}}}
        self.assertTrue(compat.verify_objective_display(objective(20), display, {})[0])
        self.assertFalse(compat.verify_objective_display(objective(21), display, {})[0])

    def test_credit_expansion_requires_every_member_to_emit_the_source_credit(self):
        display = {"n:5": {"n:1": {"n:1": {"n:1": 20, "n:2": 21}, "n:2": 20}}}
        self.assertFalse(compat.verify_objective_display(objective(20), display, {})[0])
        self.assertTrue(compat.verify_objective_display(objective(20), display, {"20": [["monster", 21]]})[0])
        display["n:5"]["n:1"]["n:2"] = 22
        self.assertFalse(compat.verify_objective_display(objective(20), display, {"20": [["monster", 21]]})[0])

    def test_object_credit_source_is_a_verified_replacement(self):
        self.assertTrue(compat.verify_objective_display(objective(20), objective(300, "n:2"),
                                                       {"20": [["object", 300]]})[0])
        self.assertFalse(compat.verify_objective_display(objective(20), objective(300, "n:2"),
                                                        {"21": [["object", 300]]})[0])

    def test_source_objectives_cannot_be_dropped_or_duplicated(self):
        self.assertFalse(compat.verify_objective_display(objective(20), {}, {})[0])
        source = {"n:1": {"n:1": {"n:1": 20}, "n:2": {"n:1": 21}}}
        self.assertFalse(compat.verify_objective_display(source, objective(20), {})[0])

    def test_quest_event_helper_requires_its_specific_executing_actor(self):
        self.assertTrue(compat.verify_objective_display({}, objective(6090), {}, [["monster", 6090]])[0])
        self.assertFalse(compat.verify_objective_display({}, objective(6091), {}, [["monster", 6090]])[0])
        duplicated = {"n:1": {"n:1": {"n:1": 6090}, "n:2": {"n:1": 6090}}}
        self.assertFalse(compat.verify_objective_display({}, duplicated, {}, [["monster", 6090]])[0])

    def test_event_and_transformation_proofs_follow_bound_actors(self):
        templates = {1200: {"AIName": "SmartAI"}, 24782: {}}
        scripts = [{"source_type": 0, "entryorguid": 1200, "action_type": 15, "action_param1": 55, "target_type": 7},
                   {"source_type": 0, "entryorguid": 1200, "action_type": 36, "action_param1": 24782}]
        self.assertEqual(compat.build_event_sources(templates, {}, scripts), {"55": [["monster", 1200]]})
        credits = compat.build_credit_sources(templates, {}, scripts, {})
        self.assertTrue(compat.verify_objective_display(objective(24782), objective(1200), credits)[0])

    def test_sparse_and_unknown_objective_categories_are_not_approved(self):
        self.assertFalse(compat.verify_objective_display({}, {"n:6": {"n:1": {"n:1": 123}}}, {})[0])
        self.assertFalse(compat.verify_objective_display(objective(20), {"n:1": {"n:2": {"n:1": 20}}}, {})[0])

    def test_bound_self_action_lists_and_credit_spells(self):
        creatures = {1: {"AIName": "SmartAI"}, 2: {"KillCredit1": 20},
                     3: {"AIName": "SmartAI", "ScriptName": "custom"}}
        scripts = [
            {"source_type": 0, "entryorguid": 1, "action_type": 80, "action_param1": 100, "target_type": 1},
            {"source_type": 9, "entryorguid": 100, "action_type": 11, "action_param1": 500, "target_type": 7},
            {"source_type": 0, "entryorguid": 3, "action_type": 33, "action_param1": 99},
        ]
        spells = {500: {"Effect1": 64, "EffectTriggerSpell1": 501, "EffectImplicitTargetA1": 25},
                  501: {"Effect1": 90, "EffectMiscValue1": 20, "EffectImplicitTargetA1": 25}}
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, spells),
                         {"20": [["monster", 1], ["monster", 2]]})

    def test_cross_actor_or_unbound_action_lists_do_not_prove_credit(self):
        scripts = [
            {"source_type": 0, "entryorguid": 1, "action_type": 80, "action_param1": 100, "target_type": 19},
            {"source_type": 9, "entryorguid": 100, "action_type": 33, "action_param1": 20},
            {"source_type": 0, "entryorguid": 2, "action_type": 33, "action_param1": 21},
        ]
        self.assertEqual(compat.build_credit_sources({1: {"AIName": "SmartAI"}, 2: {}}, {}, scripts, {}), {})

    def test_gameobject_credits_require_its_actual_smart_ai_binding(self):
        scripts = [{"source_type": 1, "entryorguid": 100, "action_type": 33,
                    "action_param1": 20, "target_type": 7}]
        self.assertEqual(compat.build_credit_sources({}, {100: {"AIName": "SmartGameObjectAI"}}, scripts, {}),
                         {"20": [["object", 100]]})
        self.assertEqual(compat.build_credit_sources({}, {100: {"AIName": "SmartAI"}}, scripts, {}), {})

    def test_credit_spell_cast_on_self_is_not_a_player_credit_proof(self):
        scripts = [{"source_type": 0, "entryorguid": 1, "action_type": 11,
                    "action_param1": 500, "target_type": 1}]
        self.assertEqual(compat.build_credit_sources({1: {"AIName": "SmartAI"}}, {}, scripts,
                                                    {500: {"Effect1": 90, "EffectMiscValue1": 20}}), {})

    def test_implicit_caster_target_is_not_a_player_credit_even_when_cast_on_player(self):
        scripts = [{"source_type": 0, "entryorguid": 1, "action_type": 11,
                    "action_param1": 500, "target_type": 7}]
        self.assertEqual(compat.build_credit_sources({1: {"AIName": "SmartAI"}}, {}, scripts,
                                                    {500: {"Effect1": 90, "EffectMiscValue1": 20,
                                                           "EffectImplicitTargetA1": 1}}), {})

    def test_stored_recipient_requires_proven_player_storage(self):
        templates = {1: {"AIName": "SmartAI"}}
        credit = {"source_type": 0, "entryorguid": 1, "action_type": 33,
                  "action_param1": 20, "target_type": 12, "target_param1": 1}
        self.assertEqual(compat.build_credit_sources(templates, {}, [credit], {}), {})
        storage = {"source_type": 0, "entryorguid": 1, "action_type": 64,
                   "action_param1": 1, "target_type": 7}
        self.assertEqual(compat.build_credit_sources(templates, {}, [storage, credit], {}),
                         {"20": [["monster", 1]]})
        storage["target_type"] = 19
        self.assertEqual(compat.build_credit_sources(templates, {}, [storage, credit], {}), {})

    def test_npc_only_recipient_does_not_prove_player_event_or_kill_credit(self):
        templates = {1: {"AIName": "SmartAI"}}
        scripts = [{"source_type": 0, "entryorguid": 1, "action_type": action,
                    "action_param1": 20, "target_type": 19, "target_param1": 2} for action in (15, 26, 33)]
        self.assertEqual(compat.build_credit_sources(templates, {}, scripts, {}), {})
        self.assertEqual(compat.build_event_sources(templates, {}, scripts), {})

    def test_gameobject_self_has_no_creature_loot_recipient(self):
        scripts = [{"source_type": 1, "entryorguid": 1, "action_type": 33,
                    "action_param1": 20, "target_type": 1}]
        self.assertEqual(compat.build_credit_sources({}, {1: {"AIName": "SmartGameObjectAI"}}, scripts, {}), {})

    def test_corki_credit_propagates_the_prisons_player_party_list(self):
        creatures = {18445: {"AIName": "SmartAI"}}
        objects = {182521: {"AIName": "SmartGameObjectAI"}}
        scripts = [
            {"source_type": 1, "entryorguid": 182521, "id": 0, "action_type": 64, "action_param1": 1, "target_type": 16},
            {"source_type": 1, "entryorguid": 182521, "id": 1, "action_type": 100, "action_param1": 1, "target_type": 19, "target_param1": 18445},
            {"source_type": 0, "entryorguid": 18445, "action_type": 80, "action_param1": 1844500, "target_type": 1},
            {"source_type": 9, "entryorguid": 1844500, "action_type": 33, "action_param1": 18444, "target_type": 12, "target_param1": 1},
            {"source_type": 9, "entryorguid": 1844500, "id": 1, "action_type": 15, "action_param1": 9955, "target_type": 12, "target_param1": 1},
        ]
        self.assertEqual(compat.build_credit_sources(creatures, objects, scripts, {}), {"18444": [["monster", 18445]]})
        self.assertEqual(compat.build_event_sources(creatures, objects, scripts), {"9955": [["monster", 18445]]})
        objects[182521]["AIName"] = ""
        self.assertEqual(compat.build_credit_sources(creatures, objects, scripts, {}), {})
        objects[182521]["AIName"] = "SmartGameObjectAI"
        scripts[1]["target_param1"] = 99999
        self.assertEqual(compat.build_credit_sources(creatures, objects, scripts, {}), {})

    def test_all_external_list_writers_must_be_proven_players(self):
        creatures = {1: {"AIName": "SmartAI"}, 2: {"AIName": "SmartAI"}, 3: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": 1, "action_type": 64, "action_param1": 5, "target_type": 7},
            {"source_type": 0, "entryorguid": 1, "id": 1, "action_type": 100, "action_param1": 5, "target_type": 19, "target_param1": 3},
            {"source_type": 0, "entryorguid": 2, "action_type": 64, "action_param1": 5, "target_type": 19, "target_param1": 1},
            {"source_type": 0, "entryorguid": 2, "id": 1, "action_type": 100, "action_param1": 5, "target_type": 19, "target_param1": 3},
            {"source_type": 0, "entryorguid": 3, "action_type": 33, "action_param1": 20, "target_type": 12, "target_param1": 5},
        ]
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}), {})

    def test_external_guid_receiver_requires_actual_spawn_identity(self):
        creatures = {1: {"AIName": "SmartAI"}, 2: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": 1, "action_type": 64, "action_param1": 5, "target_type": 7},
            {"source_type": 0, "entryorguid": 1, "id": 1, "action_type": 100, "action_param1": 5, "target_type": 10, "target_param1": 777, "target_param2": 2},
            {"source_type": 0, "entryorguid": 2, "action_type": 33, "action_param1": 20, "target_type": 12, "target_param1": 5},
        ]
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}), {})
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}, {777: 2}), {"20": [["monster", 2]]})
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}, {777: 1}), {})

    def test_spell_objective_requires_bound_quest_completion_effect(self):
        view = {"n:6": {"n:1": {"n:1": 71539}}}
        spells = {71539: {"Effect1": 16, "EffectMiscValue1": 24541, "EffectImplicitTargetA1": 25}}
        self.assertTrue(compat.verify_objective_display({}, view, {}, quest_id=24541, spells=spells)[0])
        self.assertFalse(compat.verify_objective_display({}, view, {}, quest_id=24656, spells=spells)[0])
        self.assertFalse(compat.verify_objective_display({}, view, {})[0])
        spells[71539]["EffectImplicitTargetA1"] = 1
        self.assertFalse(compat.verify_objective_display({}, view, {}, quest_id=24541, spells=spells)[0])

    def test_guid_scripts_require_actual_spawn_identity_and_smart_ai_binding(self):
        scripts = [{"source_type": 0, "entryorguid": -777, "action_type": 15,
                    "action_param1": 55, "target_type": 7}]
        creatures = {1: {"AIName": "SmartAI"}, 2: {}}
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, {777: 1}), {"55": [["monster", 1]]})
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts), {})
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, {778: 1}), {})
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, {777: 2}), {})
        creatures[1]["ScriptName"] = "custom"
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, {777: 1}), {})

    def test_guid_and_template_events_merge_without_overwriting_another_spawn(self):
        creatures = {1: {"AIName": "SmartAI"}}
        scripts = [{"source_type": 0, "entryorguid": binding, "action_type": 15,
                    "action_param1": quest, "target_type": 7}
                   for binding, quest in ((1, 55), (-777, 56), (-778, 57))]
        spawns = [{"guid": 777, "id1": 1}, {"guid": 778, "id1": 1}]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, spawns),
                         {str(quest): [["monster", 1]] for quest in (55, 56, 57)})

    def test_guid_stored_players_cannot_be_borrowed_by_another_spawn(self):
        creatures = {1: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": -777, "action_type": 64, "action_param1": 5, "target_type": 7},
            {"source_type": 0, "entryorguid": -778, "action_type": 15, "action_param1": 55,
             "target_type": 12, "target_param1": 5},
        ]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, {777: 1, 778: 1}), {})
        scripts[1]["entryorguid"] = -777
        scripts[1]["id"] = 1
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, {777: 1, 778: 1}), {"55": [["monster", 1]]})

    def test_proven_guid_sender_and_receiver_transfer_player_lists(self):
        creatures = {1: {"AIName": "SmartAI"}, 2: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": -777, "action_type": 64, "action_param1": 5, "target_type": 7},
            {"source_type": 0, "entryorguid": -777, "id": 1, "action_type": 100, "action_param1": 5,
             "target_type": 10, "target_param1": 778, "target_param2": 2},
            {"source_type": 0, "entryorguid": -778, "action_type": 33, "action_param1": 20,
             "target_type": 12, "target_param1": 5},
        ]
        spawns = {777: 1, 778: 2}
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}, spawns), {"20": [["monster", 2]]})
        scripts.append({"source_type": 0, "entryorguid": -999, "action_type": 100, "action_param1": 5,
                        "target_type": 19, "target_param1": 2})
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}, spawns), {})

    def test_empty_list_reset_preserves_player_proof_without_proving_players_alone(self):
        creatures = {6784: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": 6784, "action_type": 64, "action_param1": 0, "target_type": 7},
            {"source_type": 0, "entryorguid": 6784, "id": 1, "action_type": 80, "action_param1": 678400, "target_type": 1},
            {"source_type": 0, "entryorguid": 6784, "id": 2, "action_type": 15, "action_param1": 590,
             "target_type": 12, "target_param1": 0},
            {"source_type": 9, "entryorguid": 678400, "action_type": 64, "action_param1": 0, "target_type": 0},
        ]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts), {"590": [["monster", 6784]]})
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts[1:]), {})
        scripts[-1]["target_type"] = 1
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts), {})

    def test_escort_end_uses_the_quest_parameter_and_proven_player_path(self):
        creatures = {1379: {"AIName": "SmartAI"}}
        scripts = [{"source_type": 0, "entryorguid": 1379, "action_type": 53,
                    "action_param1": 1, "action_param2": 1379, "action_param4": 309, "target_type": 7}]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={1379}),
                         {"309": [["monster", 1379]]})
        for paths in (None, set(), {999}):
            self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths=paths), {})
        for path in (0, -1):
            scripts[0]["action_param2"] = path
            self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={path}), {})

    def test_escort_start_requires_actual_creature_smart_ai_and_player_recipient(self):
        start = {"source_type": 0, "entryorguid": 1379, "action_type": 53,
                 "action_param2": 1379, "action_param4": 309, "target_type": 19, "target_param1": 1}
        self.assertEqual(compat.build_event_sources({1379: {"AIName": "SmartAI"}}, {}, [start], escort_paths={1379}), {})
        start["target_type"] = 7
        for template in ({}, {"AIName": "SmartAI", "ScriptName": "custom"}):
            self.assertEqual(compat.build_event_sources({1379: template}, {}, [start], escort_paths={1379}), {})
        start["source_type"] = 1
        self.assertEqual(compat.build_event_sources({}, {1379: {"AIName": "SmartGameObjectAI"}}, [start], escort_paths={1379}), {})

    def test_escort_reserved_list_proves_later_timed_event_and_kill_credit(self):
        creatures = {9598: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": 9598, "action_type": 53, "action_param2": 9598, "target_type": 7},
            {"source_type": 0, "entryorguid": 9598, "id": 1, "action_type": 80, "action_param1": 959800, "target_type": 1},
            {"source_type": 9, "entryorguid": 959800, "action_type": 15, "action_param1": 4261,
             "target_type": 12, "target_param1": 0xFFFFFF},
            {"source_type": 9, "entryorguid": 959800, "id": 1, "action_type": 33, "action_param1": 999,
             "target_type": 12, "target_param1": 0xFFFFFF},
        ]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={9598}), {"4261": [["monster", 9598]]})
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}, escort_paths={9598}), {"999": [["monster", 9598]]})
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts), {})
        self.assertEqual(compat.build_credit_sources(creatures, {}, scripts, {}), {})

    def test_nonplayer_escort_start_keeps_existing_list_but_unknown_writer_blocks_proof(self):
        creatures = {1: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": 1, "action_type": 53, "action_param2": 100, "target_type": 7},
            {"source_type": 0, "entryorguid": 1, "id": 1, "action_type": 53, "action_param2": 100,
             "action_param4": 55, "target_type": 1},
        ]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={100}), {"55": [["monster", 1]]})
        scripts[1]["target_type"] = 2
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={100}), {})

    def test_escort_can_store_a_proven_external_player_list(self):
        creatures = {1: {"AIName": "SmartAI"}}
        scripts = [
            {"source_type": 0, "entryorguid": 1, "action_type": 64, "action_param1": 5, "target_type": 7},
            {"source_type": 0, "entryorguid": 1, "id": 1, "action_type": 53, "action_param2": 100,
             "action_param4": 55, "target_type": 12, "target_param1": 5},
        ]
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={100}), {"55": [["monster", 1]]})
        scripts[0]["target_type"] = 19
        self.assertEqual(compat.build_event_sources(creatures, {}, scripts, escort_paths={100}), {})

    def test_khan_gems_are_reagents_of_the_required_objective_item(self):
        items = {17757: {"name": "Amulet of Spirits"}}
        items.update({item: {"name": f"Gem {item}", "spellid_1": 21957, "spelltrigger_1": 0}
                      for item in range(17761, 17766)})
        spells = {21957: {"Effect1": 24, "EffectItemType1": 17758,
                          **{f"Reagent{i}": 17760 + i for i in range(1, 6)}}}
        quest = {"ItemDrop1": 17757, "RequiredItemId1": 17758}
        packet = compat.derive_required_tool_items(quest, items, spells, range(17761, 17766), with_reasons=True)
        self.assertEqual(packet["items"], [17757, 17761, 17762, 17763, 17764, 17765])
        self.assertEqual(packet["reasons"]["17761"][0]["rule"], "questObjectiveCreationReagent")

    def test_dertroks_named_wand_set_is_backed_by_source_text_and_crystal_reagents(self):
        names = ("First", "Second", "Third", "Fourth")
        items = {30655: {"name": "Infused Vekh'nir Crystal"}}
        items.update({30651 + i: {"name": f"Dertrok's {name} Wand", "spellid_1": 37221 + i, "spelltrigger_1": 0}
                      for i, name in enumerate(names)})
        spells = {37221 + i: {"Reagent1": 30655} for i in range(4)}
        quest = {"ItemDrop1": 30655, "LogDescription": "Try out each of Dertrok’s wands. Each requires an Infused Vekh'nir Crystal."}
        self.assertEqual(compat.derive_required_tool_items(quest, items, spells, range(30651, 30655)),
                         [30651, 30652, 30653, 30654, 30655])

    def test_explicit_drakuru_elixir_name_and_item_drop_mojo_are_retained(self):
        quest = {"ItemDrop1": 38303, "LogDescription": "Use Drakuru’s Elixir. It requires 5 Enduring Mojo."}
        items = {35797: {"name": "Drakuru's Elixir"}, 38303: {"name": "Enduring Mojo"}}
        self.assertEqual(compat.derive_required_tool_items(quest, items, {}, [35797]), [35797, 38303])

    def test_generic_short_names_and_partial_word_matches_do_not_approve_candidates(self):
        quest = {"LogDescription": "Bait the hook and examine the giant keyhole, then drink an elixir."}
        items = {1: {"name": "Bait"}, 2: {"name": "Giant Key"}, 3: {"name": "Drakuru's Elixir"}}
        self.assertEqual(compat.derive_required_tool_items(quest, items, {}, [1, 2, 3]), [])

    def test_created_main_objectives_do_not_become_auxiliary_source_items(self):
        quest = {"ItemDrop1": 15882, "ItemDrop2": 15883, "RequiredItemId1": 15885}
        items = {15882: {"spellid_1": 25001}, 15883: {}, 15885: {}}
        spells = {25001: {"Effect1": 24, "EffectItemType1": 15885, "Reagent1": 15882, "Reagent2": 15883}}
        index = compat.build_required_tool_index(items, spells)
        self.assertEqual(compat.derive_required_tool_items(quest, items, spells, index=index), [15882, 15883])


if __name__ == "__main__":
    unittest.main()
