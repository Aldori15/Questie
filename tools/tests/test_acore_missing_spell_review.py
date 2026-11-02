"""Missing-spell reviews follow effective usage instead of global source hashes."""
import copy
import unittest

from _test_paths import ADDON_ROOT
import acore_missing_spell_review as review


class MissingSpellReviewTests(unittest.TestCase):
    def setUp(self):
        self.spells = {10: {"Effect_1": 64, "EffectTriggerSpell_1": 20},
                       20: {"Effect_1": 6, "EffectApplyAuraName_1": 23, "EffectTriggerSpell_1": 30}}
        self.tables = {"item_template": {1: {"entry": 1, "spellid_1": 10, "spelltrigger_1": 0}},
                       "quest_template": {100: {"ID": 100, "RequiredItemId1": 1}}}

    def usage(self, missing=(30,), **kwargs):
        return review.build_usage(missing, self.spells, self.tables, **kwargs)

    def test_review_records_item_quest_and_effective_trigger_ancestors(self):
        usage = self.usage()["30"]
        self.assertEqual(usage["references"][0]["itemId"], 1)
        self.assertEqual(usage["references"][0]["spellId"], 10)
        self.assertEqual(usage["spells"], {str(key): value for key, value in self.spells.items()})
        self.assertEqual(usage["quests"], [{"questId": 100, "field": "RequiredItemId1", "itemId": 1, "disabled": False}])

    def test_unrelated_source_changes_do_not_invalidate_a_review(self):
        before = self.usage()
        self.spells[90] = {"Effect_1": 24, "EffectItemType_1": 9}
        self.tables["item_template"][2] = {"entry": 2, "spellid_1": 90}
        self.tables["item_template"][1]["BuyPrice"] = 999
        self.tables["quest_template"][100]["LogTitle"] = "New spelling"
        self.tables["quest_template"][200] = {"ID": 200, "StartItem": 2}
        self.tables["smart_scripts"] = [{"action_type": 11, "action_param1": 90}]
        self.assertEqual(self.usage(), before)

    def test_new_item_using_the_same_missing_spell_changes_review_evidence(self):
        before = self.usage()
        self.tables["item_template"][2] = {"entry": 2, "spellid_1": 30}
        self.assertNotEqual(self.usage(), before)

    def test_item_trigger_class_and_charges_changes_require_review(self):
        for field in ("spelltrigger_1", "spellcharges_1", "class", "bonding", "startquest"):
            with self.subTest(field=field):
                before = self.usage()
                self.tables["item_template"][1][field] = 4
                self.assertNotEqual(self.usage(), before)
                self.tables["item_template"][1].pop(field)

    def test_effect_changes_in_a_parent_require_review(self):
        before = self.usage()
        self.spells[20]["EffectBasePoints_1"] = 4
        self.assertNotEqual(self.usage(), before)
        # A SQL override removing a trigger also removes its old usage path.
        self.spells[20]["Effect_1"] = 0
        self.assertEqual(self.usage()["30"]["references"], [])

    def test_quest_relationship_and_disabled_state_changes_require_review(self):
        before = self.usage()
        self.tables["quest_template"][200] = {"ID": 200, "StartItem": 1}
        self.assertNotEqual(self.usage(), before)
        before = self.usage()
        self.tables["disables"] = [{"sourceType": 1, "entry": 100}]
        self.assertNotEqual(self.usage(), before)

    def test_spellclick_smart_script_and_bound_cpp_users_are_recorded(self):
        self.tables.update({"npc_spellclick_spells": [{"npc_entry": 1, "spell_id": 30}],
                            "smart_scripts": [{"entryorguid": 1, "action_type": 11, "action_param1": 10}],
                            "spell_scripts": [{"id": 1, "command": 15, "datalong": 30}],
                            "gameobject_template": {1: {"entry": 1, "type": 10, "Data10": 30}},
                            "spell_script_names": [{"spell_id": 10, "ScriptName": "bound_script"}]})
        usage = self.usage(cpp_spell_ids={30})["30"]
        self.assertEqual({row["table"] for row in usage["references"]},
                         {"item_template", "npc_spellclick_spells", "smart_scripts", "spell_scripts",
                          "gameobject_template", "spell_script_names", "bound_cpp"})

    def test_linked_casts_are_traced_and_unrelated_link_types_are_ignored(self):
        self.spells[10] = {"Effect_1": 0}
        self.tables["spell_linked_spell"] = [{"spell_trigger": -10, "spell_effect": 30, "type": 0}]
        usage = self.usage()["30"]
        self.assertEqual(usage["references"][0]["spellId"], 10)
        self.assertEqual(len(usage["links"]), 1)
        self.tables["spell_linked_spell"][0]["type"] = 1
        self.assertEqual(self.usage()["30"]["references"], [])

    def test_cycles_input_order_and_unreferenced_sql_ancestors_are_stable(self):
        self.spells[20].update(Effect_2=64, EffectTriggerSpell_2=10)
        before = self.usage()
        self.spells[90] = {"Effect_1": 64, "EffectTriggerSpell_1": 30}
        self.assertEqual(self.usage(), before)
        self.spells = dict(reversed(list(self.spells.items())))
        self.assertEqual(self.usage(), before)
        self.assertEqual(review.digest(before), review.digest(copy.deepcopy(before)))

    def test_created_quest_item_relationships_are_included(self):
        self.spells[10].update(Effect_2=24, EffectItemType_2=2)
        self.tables["quest_template"][200] = {"ID": 200, "RequiredItemId1": 2}
        self.assertEqual([row["questId"] for row in self.usage()["30"]["quests"]], [100, 200])

    def test_no_missing_spells_requires_no_usage_evidence(self):
        self.assertEqual(review.build_usage([], {}, {}), {})


if __name__ == "__main__":
    unittest.main()
