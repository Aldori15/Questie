"""Coverage audits distinguish missing targets, guides and source-cache leads."""
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot
import report_quest_location_gaps as audit


POINTS = {3483: [[44.25, 75.9]]}


class QuestLocationGapTests(unittest.TestCase):
    def test_relic_guide_covers_unlocated_spirit_but_not_unlocated_finisher(self):
        quests = {10909: {"name": "Fel Spirits", "objectives": {1: [[22454]]},
                          "finishedBy": {1: [22430]},
                          "extraObjectives": [{1: POINTS, 2: 3, 3: "Use relic", 4: 1}]}}
        result = audit.analyze(quests, {22454: {"name": "Spirit"}, 22430: {"name": "Klatu"}}, {}, {})
        self.assertEqual(len(result["unlocatedObjectivesWithMappedGuide"]), 1)
        self.assertEqual([row["category"] for row in result["potentialGaps"]], ["finisher"])

    def test_ref_guides_trigger_points_and_waypoints_are_usable(self):
        quests = {1: {"objectives": {1: [[10]]}, "extraObjectives": [{4: 1, 5: [["object", 20]]}]},
                  2: {"objectives": {1: [[10]]}, "triggerEnd": ["Event", POINTS]},
                  3: {"objectives": {1: [[30]]}}}
        result = audit.analyze(quests, {10: {}, 30: {"waypoints": {3483: [[[44, 75], [45, 76]]]}}},
                               {20: {"spawns": POINTS}}, {})
        self.assertFalse(result["potentialGaps"])
        self.assertEqual(len(result["unlocatedObjectivesWithMappedGuide"]), 2)

    def test_guide_objective_index_does_not_hide_another_missing_objective(self):
        quests = {1: {"objectives": {1: [[10], [11]]}, "extraObjectives": [{1: POINTS, 4: 1}]}}
        result = audit.analyze(quests, {}, {}, {})
        self.assertEqual([row["objectiveIndex"] for row in result["potentialGaps"]], [2])

    def test_items_follow_container_sources_vendors_and_cycles(self):
        quests = {1: {"objectives": {3: [[100]]}}, 2: {"objectives": {3: [[200]]}},
                  3: {"objectives": {3: [[300]]}}}
        items = {100: {"itemDrops": [101]}, 101: {"objectDrops": [20]},
                 200: {"vendors": [30]}, 300: {"itemDrops": [301]}, 301: {"itemDrops": [300]}}
        result = audit.analyze(quests, {30: {"spawns": POINTS}}, {20: {"spawns": POINTS}}, items)
        self.assertEqual([row["questId"] for row in result["potentialGaps"]], [3])

    def test_partial_relation_does_not_claim_quest_has_no_usable_actor(self):
        quests = {1: {"startedBy": {1: [10, 20]}, "finishedBy": {1: [10, 20]}}}
        result = audit.analyze(quests, {10: {}, 20: {"spawns": POINTS}}, {}, {})
        self.assertEqual(len(result["potentialGaps"]), 2)
        self.assertTrue(all(row["hasMappedAlternativeActor"] for row in result["potentialGaps"]))

    def test_complete_blacklist_excludes_unused_quests(self):
        quests = {1: {"objectives": {1: [[10]]}}, 2: {"objectives": {1: [[10]]}}}
        result = audit.analyze(quests, {}, {}, {}, blacklist={1: True, 2: "true"})
        self.assertFalse(result["potentialGaps"])
        self.assertEqual(result["summary"]["blacklistedQuestsSkipped"], 2)

    def test_cached_evidence_is_only_a_lead_and_cannot_erase_gaps(self):
        quests = {1: {"objectives": {1: [[10]]}}}
        npc_cache = {"geometryProvenance": {"scriptedGeometry": {"entries": {
            "10": {"spawns": {"n:3483": {"n:1": {"n:1": 44, "n:2": 75}}}, "failures": {"spawns": []}}
        }}}}
        quest_cache = {"objectiveCreditSources": {"10": [["monster", 20]]}}
        result = audit.analyze(quests, {20: {"spawns": POINTS}}, {}, {},
                               npc_source_cache=npc_cache, quest_source_cache=quest_cache)
        self.assertEqual(len(result["potentialGaps"]), 1)
        gap = result["potentialGaps"][0]
        self.assertTrue(gap["requiresFreshSourceReview"])
        self.assertFalse(gap["targets"][0]["hasBaseLocation"])
        self.assertEqual(len(gap["unvalidatedCacheLeads"]), 2)

    def test_load_base_reads_native_sparse_rows_and_cli_does_not_overwrite_input(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            fixture = directory / "acoreNpcDB.lua"
            fixture.write_text('QuestieDB.npcKeys = {["name"]=1,["spawns"]=2}\n'
                               'QuestieDB.npcData = [==[return {\n[10]={"NPC",{[3483]={{44,75}}}},\n}]==]',
                               encoding="utf-8")
            rows = audit.load_base(fixture)
            self.assertEqual(rows[10]["name"], "NPC")
            self.assertTrue(audit._points(rows[10]["spawns"]))
            with self.assertRaisesRegex(ValueError, "overwrite an input"):
                audit.main(["--npc-db", str(fixture), "--report", str(fixture.with_suffix('.json')),
                            "--npc-source-cache", str(fixture.with_suffix('.json'))])


if __name__ == "__main__":
    unittest.main()
