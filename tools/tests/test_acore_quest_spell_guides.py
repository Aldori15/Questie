"""Unlocated objectives need proven interaction sites, not invented spawns."""
import copy
import unittest

from _test_paths import ADDON_ROOT
import acore_quest_spell_guides as guides
from acore_scripted_geometry import typed
import db_snapshot


def action(owner, index, typ, first=0, *, kind=0, target=1, event=0, **fields):
    return dict(source_type=kind, entryorguid=owner, id=index, link=0,
                action_type=typ, action_param1=first, target_type=target,
                event_type=event, event_chance=100, **fields)


class QuestSpellGuideTests(unittest.TestCase):
    def fixture(self):
        quests = {10: {"ID": 10, "RequiredNpcOrGo1": 100, "RequiredNpcOrGoCount1": 3}}
        templates = {entry: {"entry": entry, "name": "NPC" + str(entry), "AIName": "SmartAI", "ScriptName": ""}
                     for entry in (20, 21, 100, 21241)}
        spawn = {"id": 20, "guid": 1, "phaseMask": 1, "position_x": 30, "position_y": 40}
        spells = {30: {"Effect_1": 28, "EffectMiscValue_1": 100}}
        scripts = [action(20, 0, 11, 30, event=6, action_param2=2)]
        return [quests, {}, spells, scripts, [], templates, {}, [spawn], [], [], {},
                lambda spawn, quest: (12, [spawn["position_x"], spawn["position_y"]])]

    def test_self_summoning_parent_gives_guidance_without_creating_child_coordinates(self):
        args = self.fixture()
        before = copy.deepcopy(args[5])
        result = guides.derive(*args)
        hint = result["guides"][10]["n:1"]
        self.assertEqual(hint["n:1"], typed({12: [[30, 40]]}))
        self.assertEqual(hint["n:4"], 1)
        self.assertNotIn("n:5", hint)
        self.assertEqual(result["evidence"][0]["actor"], ["monster", 20])
        self.assertEqual(args[5], before)

    def test_source_moves_refresh_and_remote_destinations_or_custom_actors_do_not_guess(self):
        args = self.fixture()
        before = guides.derive(*args)
        args[7][0]["position_x"] = 35
        self.assertNotEqual(before["guides"], guides.derive(*args)["guides"])
        for mutation in (lambda a: a[2][30].update(EffectImplicitTargetA_1=46),
                         lambda a: a[3][0].update(target_type=2),
                         lambda a: a[5][20].update(ScriptName="unknown"),
                         lambda a: a[7][0].update(phaseMask=2),
                         lambda a: a[3].append(action(20, 1, 62))):
            args = self.fixture()
            mutation(args)
            with self.subTest(mutation=mutation):
                self.assertFalse(guides.derive(*args)["guides"])

    def test_self_proc_aura_follows_item_spell_to_restricted_npc_targets(self):
        args = self.fixture()
        args[0][10]["StartItem"] = 50
        args[1][50] = {"entry": 50, "name": "Quest potion", "spellid_1": 60, "spelltrigger_1": 0}
        args[2].update({60: {"Effect1": 6, "EffectApplyAuraName1": 42,
                              "EffectImplicitTargetA1": 1, "EffectTriggerSpell1": 61},
                       61: {"Effect1": 3, "EffectImplicitTargetA1": 6}})
        args[4].append({"SourceTypeOrReferenceId": 17, "SourceEntry": 61,
                        "ConditionTypeOrReference": 31, "ConditionTarget": 1,
                        "ConditionValue1": 3, "ConditionValue2": 20})
        result = guides.derive(*args)
        self.assertEqual(result["evidence"][0]["rule"], "questItemTriggeredSpellTarget")
        self.assertEqual(result["evidence"][0]["spellPath"], [60, 61])
        args[2][60]["EffectImplicitTargetA1"] = 6
        self.assertFalse(any(p["rule"] == "questItemTriggeredSpellTarget" for p in guides.derive(*args)["evidence"]))

    def test_spell_hit_guide_requires_matching_item_chain_and_area(self):
        args = self.fixture()
        args[0][10]["StartItem"] = 50
        args[1][50] = {"entry": 50, "spellid_1": 60}
        args[2][60] = {"Effect1": 6, "EffectApplyAuraName1": 42, "EffectImplicitTargetA1": 1,
                       "EffectTriggerSpell1": 61, "AreaGroupId": 7}
        args[2][61] = {"Effect1": 3, "EffectImplicitTargetA1": 6}
        args[3][0].update(event_type=8, event_param1=61)
        args[4].append({"SourceTypeOrReferenceId": 17, "SourceEntry": 61,
                        "ConditionTypeOrReference": 31, "ConditionTarget": 1,
                        "ConditionValue1": 3, "ConditionValue2": 20})
        args[7][0]["areaId"] = 99
        args[7].append(dict(args[7][0], guid=2, areaId=98, position_x=70))
        result = guides.derive(*args, area_groups={7: [99]})
        self.assertEqual(result["evidence"][0]["sourceGuids"], [1])
        self.assertFalse(guides.derive(*args)["guides"])
        args[3][0]["event_param1"] = 62
        self.assertFalse(guides.derive(*args, area_groups={7: [99]})["guides"])

    def test_goober_event_summon_uses_actual_interaction_object(self):
        args = self.fixture()
        args[3] = []
        args[6][70] = {"entry": 70, "type": 10, "name": "Summoning pyre", "Data2": 80}
        args[8] = [{"id": 70, "guid": 2, "phaseMask": 1, "position_x": 31, "position_y": 41}]
        args[9] = [{"id": 80, "command": 10, "datalong": 100, "x": 99999, "y": 99999}]
        result = guides.derive(*args)
        self.assertEqual(result["evidence"][0]["actor"], ["object", 70])
        self.assertEqual(result["guides"][10]["n:1"]["n:1"], typed({12: [[31, 41]]}))
        args[6][70]["Data1"] = 999
        self.assertFalse(guides.derive(*args)["guides"])

    def test_existing_located_objective_does_not_get_redundant_parent_guidance(self):
        args = self.fixture()
        args[7].append(dict(args[7][0], id=100, guid=2))
        self.assertFalse(guides.derive(*args)["guides"])

    def test_existing_source_actor_guide_is_not_duplicated(self):
        previous = {10: typed([{2: 3, 3: "Existing hint", 4: 0, 5: [["monster", 20]]}])}
        result = guides.derive(*self.fixture(), existing_guides=previous)
        self.assertFalse(result["guides"])
        self.assertFalse(result["omissions"])

    def test_proven_credit_emitter_maps_real_objective_index(self):
        args = self.fixture()
        args[3] = []
        args[10] = {"100": [["monster", 20]]}
        result = guides.derive(*args)
        self.assertEqual(result["evidence"][0]["rule"], "sourceCreditProvider")
        self.assertEqual(result["guides"][10]["n:1"]["n:4"], 1)

    def test_template_credit_reuses_npc_geometry_but_guid_credit_keeps_coordinates(self):
        args = self.fixture()
        args[3] = []
        args[5][20]["KillCredit1"] = 100
        args[10] = {"100": [["monster", 20]]}
        hint = guides.derive(*args)["guides"][10]["n:1"]
        self.assertNotIn("n:1", hint)
        self.assertEqual(hint["n:5"], typed([["monster", 20]]))
        args[10] = {"100": [["monster", 20, 1]]}
        hint = guides.derive(*args)["guides"][10]["n:1"]
        self.assertIn("n:1", hint)
        self.assertNotIn("n:5", hint)

    def drinking_fixture(self):
        args = self.fixture()
        args[0] = {10512: {"ID": 10512, "StartItem": 30353,
                           "RequiredNpcOrGo1": 21241, "RequiredNpcOrGoCount1": 5}}
        args[1] = {30353: {"entry": 30353, "name": "Quest keg", "spellid_1": 35129}}
        args[2] = {35129: {"Effect1": 28, "EffectMiscValue1": 21241, "EffectImplicitTargetA1": 41},
                   36421: {"Effect1": 134, "EffectMiscValue1": 21241}}
        args[3] = [action(21241, 0, 64, 1, target=7, event=54),
                   action(21241, 1, 100, 1, target=19, event=61, target_param1=20),
                   action(21241, 2, 45, 1, target=19, event=61, target_param1=20, action_param2=1),
                   action(20, 0, 80, 20000, event=38, event_param1=1, event_param2=1),
                   action(20000, 0, 11, 36421, kind=9, target=12, target_param1=1)]
        args[3][0]["link"] = 1
        args[3][1]["link"] = 2
        return args

    def test_item_trigger_stored_player_list_proves_drinking_credit_site(self):
        args = self.drinking_fixture()
        result = guides.derive(*args)
        self.assertEqual(result["evidence"][0]["rule"], "storedPlayerSpellCredit")
        self.assertEqual(result["evidence"][0]["objectiveNpcId"], 21241)
        args[3][0]["target_type"] = 1
        self.assertFalse(guides.derive(*args)["guides"])

    def test_drinking_guide_requires_matching_data_event_and_credit_recipient(self):
        for row, field in ((2, "action_param2"), (3, "event_param2"), (4, "target_param1")):
            with self.subTest(row=row, field=field):
                args = self.drinking_fixture()
                args[3][row][field] = 2
                self.assertFalse(guides.derive(*args)["guides"])

    def test_source_semantics_review_rejects_changed_event_ownership(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as root:
            for relative, fragments in guides.CORE_REQUIREMENTS.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("\n".join(fragments), encoding="utf-8")
            guides.validate_source(root)
            path = root / guides.CORE_SOURCE_FILES[2]
            path.write_text(path.read_text().replace("player, this", "this, player"), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "core source review"):
                guides.validate_source(root)


if __name__ == "__main__":
    unittest.main()
