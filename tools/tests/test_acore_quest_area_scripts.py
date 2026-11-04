import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import acore_quest_area_scripts as area
import acore_quest_cpp_events as cpp
import db_snapshot


class QuestAreaScriptTests(unittest.TestCase):
    def smart_rows(self):
        return [{"entryorguid": 173, "source_type": 2, "id": 0, "link": 1,
                 "event_type": 46, "event_chance": 100, "action_type": 12, "target_type": 8},
                {"entryorguid": 173, "source_type": 2, "id": 1, "event_type": 61,
                 "event_chance": 100, "action_type": 15, "action_param1": 437, "target_type": 16}]

    def test_linked_smart_area_credit_keeps_player_party_provenance(self):
        packet = area.collect(pathlib.Path("unused"), [{"entry": 173, "ScriptName": "SmartTrigger"}], self.smart_rows())
        self.assertEqual([(proof["questId"], proof["triggerId"]) for proof in packet["credits"]], [(437, 173)])
        self.assertEqual(packet["credits"][0]["rule"], "linkedSmartTriggerQuestCredit")

    def test_smart_area_rejects_unproved_conditions_recipients_and_link_chains(self):
        changes = [(0, "event_type", 0), (0, "event_param1", 999), (0, "event_phase_mask", 1),
                   (0, "event_chance", 50), (0, "action_type", 62), (0, "link", 0),
                   (1, "target_type", 1), (1, "link", 1)]
        bindings = [{"entry": 173, "ScriptName": "SmartTrigger"}]
        for index, field, value in changes:
            with self.subTest(field=field, value=value):
                rows = self.smart_rows()
                rows[index][field] = value
                self.assertFalse(area.collect(pathlib.Path("unused"), bindings, rows)["credits"])
        conditions = [{"SourceTypeOrReferenceId": 22, "SourceId": 2, "SourceEntry": 173, "ScriptName": "custom_gate"}]
        self.assertFalse(area.collect(pathlib.Path("unused"), bindings, self.smart_rows(), conditions)["credits"])
        self.assertFalse(area.collect(pathlib.Path("unused"), [{"entry": 173, "ScriptName": "other"}], self.smart_rows())["credits"])

    def test_normal_condition_gates_preserve_location_without_evaluating_eligibility(self):
        bindings = [{"entry": 173, "ScriptName": "SmartTrigger"}]
        conditions = [{"SourceTypeOrReferenceId": 22, "SourceId": 2, "SourceEntry": 173,
                       "SourceGroup": 1, "ElseGroup": 0, "ConditionTypeOrReference": -4},
                      {"SourceTypeOrReferenceId": -4, "ConditionTypeOrReference": 29,
                       "ConditionValue1": 2056, "ConditionValue2": 30, "NegativeCondition": 1}]
        packet = area.collect(pathlib.Path("unused"), bindings, self.smart_rows(), conditions)
        self.assertEqual(packet["credits"][0]["conditionGates"][0]["referenceConditions"], [conditions[1]])
        self.assertEqual(packet["credits"][0]["conditionGates"][0]["SourceGroup"], 1)
        self.assertFalse(area.collect(pathlib.Path("unused"), bindings, self.smart_rows(), conditions[:1])["credits"])
        conditions[1]["ConditionTypeOrReference"] = -4
        self.assertFalse(area.collect(pathlib.Path("unused"), bindings, self.smart_rows(), conditions)["credits"])
        conditions[1].update(ConditionTypeOrReference=29, ScriptName="custom_gate")
        self.assertFalse(area.collect(pathlib.Path("unused"), bindings, self.smart_rows(), conditions)["credits"])

    def test_smart_area_does_not_publish_partial_credit_proof(self):
        bindings = [{"entry": 173, "ScriptName": "SmartTrigger"}]
        rows = self.smart_rows()
        rows.append(dict(rows[1], id=2, event_type=0))
        self.assertFalse(area.collect(pathlib.Path("unused"), bindings, rows)["credits"])
        rows = self.smart_rows()
        rows.append(dict(rows[0], id=0, link=2))
        self.assertFalse(area.collect(pathlib.Path("unused"), bindings, rows)["credits"])

    def orphan_source(self):
        return '''enum Ids { AT_DOWN_AT_THE_DOCKS=3551, QUEST_FIRST=910, AT_DARK_PORTAL=4356,
            QUEST_A=10952, QUEST_H=10951 };
            class at_bring_your_orphan_to : public AreaTriggerScript {
                at_bring_your_orphan_to() : AreaTriggerScript("at_bring_your_orphan_to") {}
                bool OnTrigger(Player* player, AreaTrigger const* trigger) override {
                    uint32 questId=0; uint32 orphanId=0;
                    switch (trigger->entry) {
                        case AT_DOWN_AT_THE_DOCKS: questId=QUEST_FIRST; orphanId=1; break;
                        case AT_DARK_PORTAL: questId=player->GetTeamId()==TEAM_ALLIANCE ? QUEST_A : QUEST_H;
                            orphanId=player->GetTeamId()==TEAM_ALLIANCE ? 2 : 3; break;
                    }
                    if (questId && orphanId && getOrphanGUID(player,orphanId)
                        && player->GetQuestStatus(questId)==QUEST_STATUS_INCOMPLETE)
                        player->AreaExploredOrEventHappens(questId);
                    return true;
                }
            };
            void AddSC() { new at_bring_your_orphan_to(); }'''

    def collect(self, source, bindings, *, reviewed=None):
        script = "at_bring_your_orphan_to"
        recipe = dict(area.RECIPES[script])
        review_source = reviewed if reviewed is not None else source
        owner = next(row for row in cpp._classes(cpp._mask(review_source)) if row["name"] == recipe["class"])
        recipe["sha256"] = area.class_digest(review_source[owner["start"]:owner["end"] + 1])
        with db_snapshot.temporary_directory(pathlib.Path(__file__).resolve().parents[1] / "reports") as root:
            path = root / recipe["file"]
            path.parent.mkdir(parents=True)
            path.write_text(source, encoding="utf-8")
            with patch.dict(area.RECIPES, {script: recipe}, clear=True):
                return area.collect(root, bindings)

    def test_bound_orphan_choices_preserve_trigger_quest_and_faction_relationships(self):
        bindings = [{"entry": entry, "ScriptName": "at_bring_your_orphan_to"} for entry in (3551, 4356)]
        packet = self.collect(self.orphan_source(), bindings)
        self.assertEqual({(proof["triggerId"], proof["questId"]) for proof in packet["credits"]},
                         {(3551, 910), (4356, 10951), (4356, 10952)})
        self.assertFalse(packet["omissions"])
        self.assertTrue(all(proof["sourceClassSha256"] and proof["line"] > 0 for proof in packet["credits"]))
        self.assertEqual({(proof["triggerId"], proof["displayMap"], proof["displayZone"]) for proof in packet["credits"]},
                         {(3551, 1, 17), (4356, 530, 3483)})

    def test_changed_behavior_is_omitted_without_falling_back_to_old_choices(self):
        original = self.orphan_source()
        changed = original.replace("getOrphanGUID(player,orphanId)", "OtherGate(player)")
        packet = self.collect(changed, [{"entry": 3551, "ScriptName": "at_bring_your_orphan_to"}], reviewed=original)
        self.assertEqual(packet["credits"], [])
        self.assertEqual(packet["omissions"][0]["reason"], "changedAreaTriggerBehavior")

    def test_enum_updates_are_resolved_from_current_source(self):
        original = self.orphan_source()
        changed = original.replace("QUEST_FIRST=910", "QUEST_FIRST=911")
        packet = self.collect(changed, [{"entry": 3551, "ScriptName": "at_bring_your_orphan_to"}], reviewed=original)
        self.assertEqual([proof["questId"] for proof in packet["credits"]], [911])

    def test_comments_do_not_change_reviewed_behavior(self):
        original = self.orphan_source()
        changed = original.replace("uint32 questId=0;", "/* entry gate */ uint32 questId = 0;")
        packet = self.collect(changed, [{"entry": 3551, "ScriptName": "at_bring_your_orphan_to"}], reviewed=original)
        self.assertEqual([proof["questId"] for proof in packet["credits"]], [910])

    def test_unregistered_unknown_and_ambiguous_bindings_are_not_authoritative(self):
        original = self.orphan_source()
        with self.subTest(kind="registration"):
            packet = self.collect(original.replace("new at_bring_your_orphan_to();", ""),
                                  [{"entry": 3551, "ScriptName": "at_bring_your_orphan_to"}], reviewed=original)
            self.assertFalse(packet["credits"])
            self.assertEqual(packet["omissions"][0]["reason"], "unregisteredAreaTriggerClass")
        with self.subTest(kind="unknown case"):
            packet = self.collect(original, [{"entry": 999, "ScriptName": "at_bring_your_orphan_to"}])
            self.assertFalse(packet["credits"])
            self.assertEqual(packet["omissions"][0]["reason"], "unprovedAreaTriggerCase")
        with self.subTest(kind="conflicting binding"):
            packet = self.collect(original, [{"entry": 3551, "ScriptName": "at_bring_your_orphan_to"},
                                             {"entry": 3551, "ScriptName": "another_script"}])
            self.assertFalse(packet["credits"])
            self.assertEqual(packet["omissions"][0]["reason"], "ambiguousAreaTriggerBinding")

    def test_planetarium_uses_both_current_raid_size_choices(self):
        script = "at_celestial_planetarium_enterance"
        recipe = dict(area.RECIPES[script])
        source = '''class AreaTrigger_at_celestial_planetarium_enterance : public AreaTriggerScript {
            AreaTrigger_at_celestial_planetarium_enterance():AreaTriggerScript("at_celestial_planetarium_enterance") {}
            bool OnTrigger(Player* player, AreaTrigger const*) override {
                if (player->IsAlive())
                    if (uint32 questId=(player->GetMap()->Is25ManRaid() ? 13816 : 13607))
                        if (player->GetQuestStatus(questId)==QUEST_STATUS_INCOMPLETE)
                            player->AreaExploredOrEventHappens(questId);
                return false;
            }
        }; void AddSC() { new AreaTrigger_at_celestial_planetarium_enterance(); }'''
        owner = cpp._classes(cpp._mask(source))[0]
        recipe["sha256"] = area.class_digest(source[owner["start"]:owner["end"] + 1])
        with db_snapshot.temporary_directory(pathlib.Path(__file__).resolve().parents[1] / "reports") as root:
            path = root / recipe["file"]
            path.parent.mkdir(parents=True)
            path.write_text(source, encoding="utf-8")
            with patch.dict(area.RECIPES, {script: recipe}, clear=True):
                packet = area.collect(root, [{"entry": 5401, "ScriptName": script}])
                self.assertEqual({proof["questId"] for proof in packet["credits"]}, {13607, 13816})
                path.write_text(source.replace("Is25ManRaid", "OtherRaid"), encoding="utf-8")
                self.assertFalse(area.collect(root, [{"entry": 5401, "ScriptName": script}])["credits"])


if __name__ == "__main__":
    unittest.main()
