"""Temporary classic actors must guide players to current interaction targets."""
from pathlib import Path
import hashlib
import re
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import acore_quest_classic_guides as guides
import db_snapshot


class ClassicGuidesTests(unittest.TestCase):
    def fixture(self):
        quests = {identity: {"ID": identity, "RequiredNpcOrGo1": target, "RequiredNpcOrGoCount1": 3}
                  for identity, target in ((3520, 8612), (5561, 11627), (6481, 11920))}
        quests[3520]["StartItem"] = 10699
        quests[5561]["StartItem"] = 13892
        items = {item: {"entry": item, "spellid_1": spell, "spelltrigger_1": 0}
                 for item, spell in ((10699, 12699), (13892, 18153))}
        spells = {12699: {"Effect1": 28, "EffectMiscValue1": 8612,
                          "EffectImplicitTargetA1": 6, "EffectImplicitTargetB1": 46},
                  18153: {"Effect1": 3, "EffectImplicitTargetA1": 6}}
        scripts = [{"source_type": 0, "entryorguid": 8612, "event_type": 64,
                    "action_type": 33, "action_param1": 8612, "target_type": 7}]
        creatures = {identity: {"entry": identity} for identity in
                     (8612, 5307, 5308, 4700, 4701, 4702, 11627, 11596, 11920)}
        creatures[8612]["AIName"] = "SmartAI"
        for identity in (4700, 4701, 4702, 11627):
            creatures[identity]["ScriptName"] = "npc_aged_dying_ancient_kodo"
        objects = {178145: {"entry": 178145, "type": 10, "ScriptName": "go_resonite_cask"}}
        bindings = [{"spell_id": spell, "ScriptName": name} for spell, name in
                    ((12699, "spell_gen_yehkinya_bramble"),
                     (18153, "spell_q5561_kodo_roundup_kodo_kombobulator"))]
        return [quests, items, spells, scripts, [], creatures, objects, bindings]

    def derive(self, args):
        with patch.object(guides, "_review_cpp") as reviewed:
            packet = guides.derive(*args, source_root=Path("reviewed-source"))
        return packet, reviewed

    def test_helpers_keep_real_credit_and_reference_interaction_actors_without_coordinates(self):
        packet, reviewed = self.derive(self.fixture())
        self.assertEqual(set(packet["guides"]), {3520, 5561, 6481})
        self.assertEqual(reviewed.call_count, 4)
        for quest, helpers in packet["guides"].items():
            for helper in helpers.values():
                self.assertNotIn("n:1", helper)
                self.assertEqual(helper["n:4"], 1)
        references = packet["guides"][5561]
        self.assertEqual(references["n:1"]["n:5"]["n:1"], {"n:1": "monster", "n:2": 4700})
        self.assertEqual(references["n:2"]["n:5"]["n:1"], {"n:1": "monster", "n:2": 11596})
        self.assertEqual(packet["guides"][6481]["n:1"]["n:5"]["n:1"], {"n:1": "object", "n:2": 178145})

    def test_native_item_columns_and_normalized_aliases_are_equivalent(self):
        args = self.fixture()
        native, _ = self.derive(args)
        for row in args[1].values():
            row["spellid1"] = row.pop("spellid_1")
            row["spelltrigger1"] = row.pop("spelltrigger_1")
        normalized, _ = self.derive(args)
        self.assertEqual(normalized, native)

    def test_changed_relationships_fail_closed_instead_of_reusing_legacy_helpers(self):
        mutations = [lambda a: a[0][3520].update(RequiredNpcOrGo1=1),
                     lambda a: a[1][10699].update(spellid_1=1),
                     lambda a: a[2][12699].update(EffectMiscValue1=1),
                     lambda a: a[3][0].update(target_type=1),
                     lambda a: a[3][0].update(event_phase_mask=1),
                     lambda a: a[4].append({"SourceTypeOrReferenceId": 13, "SourceEntry": 12699}),
                     lambda a: a[5][4700].update(ScriptName="different_actor"),
                     lambda a: a[5].pop(11596),
                     lambda a: a[6][178145].update(ScriptName="different_object"),
                     lambda a: a[7][0].update(ScriptName="different_spell"),
                     lambda a: a[7].append({"spell_id": 18153, "ScriptName": "extra_script"})]
        for mutate in mutations:
            args = self.fixture()
            mutate(args)
            with self.subTest(mutation=mutate), self.assertRaisesRegex(ValueError, "requires source review"):
                self.derive(args)

    def test_complete_cpp_block_and_numeric_bindings_require_review(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as root:
            relative, pattern, _ = guides.CPP_REVIEWS["cask"]
            path = root / relative
            path.parent.mkdir(parents=True)
            code = 'enum ResoniteCask { NPC_GOGGEROC = 11920\n};\nclass go_resonite_cask { void Use() { Summon(NPC_GOGGEROC); }\n};'
            path.write_text(code, encoding="utf-8")
            digest = hashlib.sha256(re.sub(r"\s+", "", code).encode()).hexdigest()
            with patch.dict(guides.CPP_REVIEWS, {"cask": (relative, pattern, digest)}):
                guides._review_cpp(root, "cask", 6481)
                for changed in (code.replace("11920", "99999"), code.replace("Summon", "Teleport")):
                    path.write_text(changed, encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "changed cask"):
                        guides._review_cpp(root, "cask", 6481)

    def test_unrelated_quests_do_not_require_classic_script_files(self):
        self.assertEqual(guides.derive({}, {}, {}, [], [], {}, {}, []),
                         {"guides": {}, "evidence": [], "omissions": []})


if __name__ == "__main__":
    unittest.main()
