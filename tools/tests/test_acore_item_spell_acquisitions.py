import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_item_spell_acquisitions as acquisition


def target(spell, entry, slot=1, source=13):
    return {"SourceTypeOrReferenceId": source, "SourceEntry": spell,
            "SourceGroup": (1 << (slot - 1)) if source == 13 else 0,
            "ConditionTarget": 0 if source == 13 else 1,
            "ConditionTypeOrReference": 31, "ConditionValue1": 3, "ConditionValue2": entry}


class ItemSpellAcquisitionTests(unittest.TestCase):
    def collect(self, spells, conditions=(), scripts=(), npcs=None):
        return acquisition.collect({1: {"spellid_1": 100, "spelltrigger_1": 0}, 2: {}},
                                   npcs or {10: {}, 11: {}, 12: {}}, {}, scripts, spells, conditions)

    def test_trigger_creation_intersects_parent_and_child_entry_conditions(self):
        spells = {100: {"Effect1": 64, "EffectTriggerSpell1": 101, "EffectImplicitTargetA1": 38},
                  101: {"Effect1": 24, "EffectItemType1": 2,
                        "EffectImplicitTargetA1": 38, "EffectImplicitTargetB1": 1}}
        conditions = [target(100, entry) for entry in (10, 11, 12)] + [target(101, entry) for entry in (10, 12)]
        result = self.collect(spells, conditions)
        self.assertEqual(result["sources"], {"2": {"npcDrops": [10, 12]}})
        self.assertTrue(all(row["spellPath"] == [100, 101] for row in result["evidence"]))

    def test_npc_targeted_creation_does_not_become_a_player_item(self):
        spells = {100: {"Effect1": 64, "EffectTriggerSpell1": 101, "EffectImplicitTargetA1": 38},
                  101: {"Effect1": 24, "EffectItemType1": 2, "EffectImplicitTargetA1": 25}}
        self.assertEqual(self.collect(spells, [target(100, 10)])["sources"], {})

    def periodic_spells(self):
        return {100: {"Effect1": 6, "EffectApplyAuraName1": 4, "EffectImplicitTargetA1": 38,
                      "Effect2": 6, "EffectApplyAuraName2": 23, "EffectImplicitTargetA2": 1,
                      "EffectTriggerSpell2": 101},
                101: {"Effect1": 24, "EffectItemType1": 2, "EffectImplicitTargetA1": 1}}

    def test_player_self_periodic_aura_retains_its_bound_npc_interaction(self):
        self.assertEqual(self.collect(self.periodic_spells(), [target(100, 10)])["sources"],
                         {"2": {"npcDrops": [10]}})

    def test_npc_periodic_aura_requires_proven_original_player_caster(self):
        spells = {100: {"AttributesEx": 4, "Effect1": 6, "EffectApplyAuraName1": 23,
                        "EffectImplicitTargetA1": 38, "EffectTriggerSpell1": 101},
                  101: {"Effect1": 24, "EffectItemType1": 2, "EffectImplicitTargetA1": 1,
                        "Effect2": 3, "EffectImplicitTargetA2": 77}}
        self.assertEqual(self.collect(spells, [target(100, 10)])["sources"], {"2": {"npcDrops": [10]}})
        for change in ("no_channel", "no_unit_target"):
            with self.subTest(change=change):
                wrong = copy.deepcopy(spells)
                if change == "no_channel":
                    wrong[100]["AttributesEx"] = 0
                else:
                    wrong[101]["Effect2"] = 0
                result = self.collect(wrong, [target(100, 10)])
                self.assertEqual(result["sources"], {})
                self.assertEqual(result["omissions"][0]["reason"], "periodicCasterIsNotProvenPlayer")

    def test_channel_death_item_requires_entry_binding_and_positive_amount(self):
        spells = {100: {"Effect1": 6, "EffectApplyAuraName1": 86, "EffectItemType1": 2,
                        "EffectImplicitTargetA1": 6, "EffectDieSides1": 1, "EffectBasePoints1": 0}}
        conditions = [target(100, 10, source=17)]
        self.assertEqual(self.collect(spells, conditions)["sources"], {"2": {"npcDrops": [10]}})
        unbound = self.collect(spells)
        self.assertEqual(unbound["sources"], {})
        self.assertEqual(unbound["omissions"][0]["reason"], "channelDeathItemHasNoSpecificActorBinding")
        for key, value in (("EffectApplyAuraName1", 3), ("EffectDieSides1", 0), ("EffectBasePoints1", -1)):
            wrong = copy.deepcopy(spells)
            wrong[100][key] = value
            self.assertEqual(self.collect(wrong, conditions)["sources"], {})

    def test_caster_aura_requirement_tracks_the_actual_combat_provider(self):
        spells = {100: {"Effect1": 24, "EffectItemType1": 2, "EffectImplicitTargetA1": 1},
                  200: {"Effect2": 6, "EffectApplyAuraName2": 3, "EffectImplicitTargetA2": 6}}
        conditions = [{"SourceTypeOrReferenceId": 17, "SourceEntry": 100, "ConditionTarget": 0,
                       "ConditionTypeOrReference": 1, "ConditionValue1": 200, "ConditionValue2": 1}]
        scripts = [{"source_type": 0, "entryorguid": 10, "id": 0, "event_type": 0,
                    "event_chance": 100, "action_type": 11, "action_param1": 200, "target_type": 2}]
        npcs = {10: {"AIName": "SmartAI"}}
        self.assertEqual(self.collect(spells, conditions, scripts, npcs)["sources"], {"2": {"npcDrops": [10]}})
        for key, value in (("target_type", 1), ("event_phase_mask", 1), ("action_param1", 999)):
            wrong = [dict(scripts[0], **{key: value})]
            self.assertEqual(self.collect(spells, conditions, wrong, npcs)["sources"], {})
        self.assertEqual(self.collect(spells, conditions, scripts, {10: {"AIName": "SmartAI", "ScriptName": "custom"}})["sources"], {})
        conditions[0]["ConditionValue2"] = 0
        self.assertEqual(self.collect(spells, conditions, scripts, npcs)["sources"], {})

    def test_cycles_and_unsupported_condition_references_do_not_invent_sources(self):
        spells = {100: {"Effect1": 64, "EffectTriggerSpell1": 101},
                  101: {"Effect1": 64, "EffectTriggerSpell1": 100}}
        result = self.collect(spells, [target(100, 10)])
        self.assertEqual(result["sources"], {})
        self.assertEqual(result["omissions"][0]["reason"], "cyclicOrDeepTriggerChain")
        spells[101] = {"Effect1": 24, "EffectItemType1": 2, "EffectImplicitTargetA1": 1}
        condition = target(100, 10)
        condition["ConditionTypeOrReference"] = -200
        self.assertEqual(self.collect(spells, [condition])["sources"], {})

    def test_source_contract_rejects_changed_core_delivery(self):
        with patch.object(Path, "read_text", return_value="changed source"):
            with self.assertRaisesRegex(ValueError, "Unsupported triggered-item"):
                acquisition.validate_source(Path("fixture"))

    def test_inactive_feature_does_not_require_an_ac_source_tree(self):
        self.assertEqual(acquisition.collect({1: {}}, {}, {}, [], {}, [], source_root=Path("missing")),
                         {"sources": {}, "evidence": [], "omissions": []})
        self.assertEqual(acquisition.collect({1: {"spellid_1": 100, "ScriptName": "custom"}}, {}, {}, [], {}, [],
                                             source_root=Path("missing")),
                         {"sources": {}, "evidence": [], "omissions": []})


if __name__ == "__main__":
    unittest.main()
