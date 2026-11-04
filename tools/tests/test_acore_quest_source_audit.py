"""Quest auditing retains exact structure and exposes unsupported source coverage."""
import copy
import json
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_quest_sources as audit
import db_snapshot


class QuestSourceAuditTests(unittest.TestCase):
    def test_rotation_only_updates_cannot_hide_identity_script_or_coordinate_changes(self):
        neutral = "UPDATE `gameobject` SET `rotation2` = SIN(`orientation` / 2), `rotation3` = COS(`orientation` / 2) WHERE `VerifiedBuild` IS NULL OR `VerifiedBuild` = 0"
        self.assertTrue(audit.rotation_only_update(neutral, "gameobject"))
        self.assertFalse(audit.rotation_only_update(neutral, "creature"))
        for assignment in ("`position_x` = 1", "`ScriptName` = 'override'", "`id` = 1", "`orientation` = 1"):
            self.assertFalse(audit.rotation_only_update(neutral.replace("`rotation2` = SIN(`orientation` / 2)", assignment),
                                                       "gameobject"))

    def test_escort_resolves_existing_subzone_parent_mapping_and_rejects_cycles(self):
        maps = audit.coordinates.parse_zone_maps(ADDON_ROOT)
        node = {"position_x": -4175.07, "position_y": 3094.67, "position_z": 323.426}
        projected = audit.project_escort_endpoint(node, {"map": 530}, {"QuestSortID": 3679}, maps)
        self.assertEqual(projected[0], 3519)
        self.assertTrue(all(0 <= value <= 100 for value in projected[1]))
        broken = copy.deepcopy(maps)
        broken["subzone_parents"][3679] = 999999
        broken["subzone_parents"][999999] = 3679
        self.assertEqual(audit.project_escort_endpoint(node, {"map": 530}, {"QuestSortID": 3679}, broken),
                         (None, None))

    def test_source_escort_guide_survives_old_export_scope_and_disappears_without_proof(self):
        import generate_acore_quest_base as exporter

        row = {"s:" + field: audit.typed(audit.metadata_reader.default_field_value(field))
               for field in audit.metadata_reader.FIELD_ORDER}
        row.update({"s:name": "Quest", "s:requiredLevel": 77, "s:questLevel": 80,
                    "s:objectives": audit.typed({1: [[31279]]}), "s:startedBy": {}, "s:finishedBy": {},
                    "s:zoneOrSort": 210, "s:childQuests": {}, "s:inGroupWith": {},
                    "s:availableUntilCompleted": 0})
        row.pop("s:triggerEnd", None)
        source = {13221: row}
        before = copy.deepcopy(source)
        manifest = exporter.make_manifest(before, source, {}, "snapshot-sha", {"sourceRevision": "source-sha"})
        trigger_bit = 1 << (exporter.KEYS["s:triggerEnd"] - 1)
        self.assertFalse(manifest["scope"]["13221"] & trigger_bit)
        self.assertNotIn("triggerEnd", manifest["legacyFields"].get("13221", {}))
        guide = audit.typed(["Escort Father Kamaros to safety", {210: [[31.98, 57.06]]}])
        proven = copy.deepcopy(source)
        proven[13221]["s:triggerEnd"] = guide
        result = exporter.build_records(proven, manifest)
        self.assertEqual(result[13221]["s:triggerEnd"], guide)
        self.assertEqual({key: value for key, value in result[13221].items() if key != "s:triggerEnd"}, before[13221])
        removed = exporter.build_records(source, manifest)
        self.assertNotIn("s:triggerEnd", removed[13221])
        self.assertEqual(removed, before)

    def test_escort_endpoint_projects_real_icecrown_geometry_without_rectangle_fallback(self):
        maps = audit.coordinates.parse_zone_maps(ADDON_ROOT)
        node = {"position_x": 7041.24, "position_y": 3438.29, "position_z": 695.568}
        self.assertEqual(audit.project_escort_endpoint(node, {"map": 571}, {"QuestSortID": 210}, maps),
                         (210, [31.98, 57.06]))
        for placement, quest, endpoint in (
                ({"map": 0}, {"QuestSortID": 210}, node),
                ({"map": 571}, {"QuestSortID": 999999}, node),
                ({"map": 571}, {"QuestSortID": 210}, dict(node, position_x=1e9))):
            with self.subTest(placement=placement, quest=quest, endpoint=endpoint):
                self.assertEqual(audit.project_escort_endpoint(endpoint, placement, quest, maps), (None, None))
        self.assertEqual(audit.project_escort_endpoint(node, {"map": 571, "zoneId": 210},
                                                      {"QuestSortID": 0}, maps), (210, [31.98, 57.06]))

        # An overlapping rectangle is not proof that an unknown quest belongs there.
        overlapping = copy.deepcopy(maps)
        original_ui = audit.coordinates.zone_to_ui(210, overlapping)
        overlapping["area_to_ui"][999998] = 999997
        overlapping["ui_map_data"][999997] = copy.deepcopy(overlapping["ui_map_data"][original_ui])
        overlapping["ui_to_zone"][999997] = 999998
        with patch.object(audit.coordinates, "resolve_coordinate_zone", return_value=(999998, [31.98, 57.06])) as generic:
            self.assertEqual(audit.project_escort_endpoint(node, {"map": 571}, {"QuestSortID": 999999}, overlapping),
                             (None, None))
            generic.assert_not_called()

    def test_escort_uses_unique_zone_when_quest_category_differs_or_is_a_class(self):
        maps = audit.coordinates.parse_zone_maps(ADDON_ROOT)
        kinelory = {"position_x": -1427.4, "position_y": -3035.17, "position_z": 32.26}
        self.assertEqual(audit.project_escort_endpoint(kinelory, {"map": 0}, {"QuestSortID": 267}, maps),
                         (45, [60.24, 53.92]))
        self.assertEqual(audit.project_escort_endpoint(kinelory, {"map": 0}, {"QuestSortID": -141}, maps),
                         (45, [60.24, 53.92]))
        daphne = {"position_x": -11475.6, "position_y": 1548.68, "position_z": 50.1844}
        self.assertEqual(audit.project_escort_endpoint(daphne, {"map": 0}, {"QuestSortID": -141}, maps),
                         (None, None))
        ambiguous = copy.deepcopy(maps)
        ui = audit.coordinates.zone_to_ui(45, maps)
        ambiguous["ui_map_data"][999997] = copy.deepcopy(maps["ui_map_data"][ui])
        ambiguous["ui_to_zone"][999997] = 999998
        ambiguous["area_to_ui"][999998] = 999997
        ambiguous["ui_by_instance"][0].append(999997)
        self.assertEqual(audit.project_escort_endpoint(kinelory, {"map": 0}, {"QuestSortID": 267}, ambiguous),
                         (None, None))

    def test_load_source_publishes_real_escort_guides_evidence_and_refresh_omissions(self):
        fixtures = {table: [] for table in audit.TABLE_KEYS}
        fixtures.update({
            "quest_template": [{"ID": quest, "QuestSortID": 210, "LogTitle": "I'm Not Dead Yet!"}
                               for quest in (13221, 13229)],
            "creature_template": [{"entry": 31279, "name": "Father Kamaros", "AIName": "SmartAI", "ScriptName": ""}],
            "creature": [{"guid": 121631, "id1": 31279, "map": 571}],
            "smart_scripts": [{"entryorguid": 31279, "source_type": 0, "id": index,
                               "event_type": 19, "event_param1": quest, "event_chance": 100,
                               "action_type": 53, "action_param2": 31279, "action_param3": 0,
                               "action_param4": quest, "target_type": 7}
                              for index, quest in enumerate((13221, 13229))],
            "waypoints": [{"entry": 31279, "pointid": 1, "position_x": 7000,
                           "position_y": 3400, "position_z": 690},
                          {"entry": 31279, "pointid": 2, "position_x": 7041.24,
                           "position_y": 3438.29, "position_z": 695.568}],
        })

        def derive(_root, **_kwargs):
            audit.sql_reader.apply_multirow_update(
                "UPDATE `gameobject` SET `rotation2` = SIN(`orientation` / 2) WHERE `VerifiedBuild` IS NULL OR `VerifiedBuild` = 0",
                "gameobject", {})
            result = {}
            for quest in fixtures["quest_template"]:
                fields = {field: audit.metadata_reader.default_field_value(field)
                          for field in audit.metadata_reader.FIELD_ORDER}
                fields["name"] = quest["LogTitle"]
                fields["specialFlags"] = 2
                result[quest["ID"]] = fields
            return result

        expected = audit.typed(["Escort Father Kamaros to safety", {210: [[31.98, 57.06]]}])
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            spell = (directory / "spell.sql").resolve()
            cache = directory / "cache.json"
            with patch.object(audit.sql_reader, "load_row_table",
                              side_effect=lambda _root, table, *args, **kwargs: (fixtures[table], 0)), \
                 patch.object(audit.metadata_reader, "derive_acore_metadata", side_effect=derive), \
                 patch.object(audit.metadata_reader, "load_acore_sql_table", return_value={}), \
                 patch.object(audit.metadata_reader, "load_module_created_quest_ids", return_value=set()), \
                 patch.object(audit, "source_signature", return_value={}):
                saved = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache)
                self.assertFalse(any(saved["diagnostics"].values()))
                self.assertEqual(len(saved["tableCoverage"]["gameobject"]["ignoredRotationOnlyUpdates"]), 1)
                self.assertEqual(saved["quests"]["13221"]["s:triggerEnd"], expected)
                self.assertEqual(saved["quests"]["13229"]["s:triggerEnd"], expected)
                escort = saved["questGuides"]["escort"]
                self.assertEqual(set(escort["guides"]), {13221, 13229})
                self.assertEqual(escort["omissions"], [])
                self.assertEqual({proof["questId"] for proof in escort["evidence"]}, {13221, 13229})
                self.assertTrue(all(proof["npcId"] == 31279 and proof["pathId"] == 31279
                                    and proof["pointId"] == 2 and proof["rule"] == "smartEscortEndPathCredit"
                                    for proof in escort["evidence"]))
                persisted = json.loads(cache.read_text(encoding="utf-8"))
                self.assertEqual(persisted["questGuides"]["escort"]["guides"]["13221"], expected)

                fixtures["smart_scripts"][1]["action_param3"] = 1
                refreshed = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                self.assertEqual(refreshed["quests"]["13221"]["s:triggerEnd"], expected)
                self.assertNotIn("s:triggerEnd", refreshed["quests"]["13229"])
                self.assertIn({"questId": 13229, "npcId": 31279, "pathId": 31279, "scriptEntry": 31279,
                               "rowId": 1, "reason": "conditionalOrRepeatingEscort"},
                              refreshed["questGuides"]["escort"]["omissions"])

                fixtures["smart_scripts"][1]["action_param3"] = 0
                area_guide = audit.typed(["Explore the proven area", {210: [[30, 50]]}])
                with patch.object(audit.guides, "derive_area_guide_packet",
                                  return_value={"guides": {13221: area_guide}, "evidence": [], "omissions": []}):
                    area_first = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                self.assertEqual(area_first["quests"]["13221"]["s:triggerEnd"], area_guide)
                self.assertEqual(area_first["quests"]["13229"]["s:triggerEnd"], expected)
                self.assertNotIn(13221, area_first["questGuides"]["escort"]["guides"])
                self.assertIn({"questId": 13221, "reason": "existingAreaTriggerGuide"},
                              area_first["questGuides"]["escort"]["omissions"])

                fixtures["quest_template"].append({"ID": 435, "QuestSortID": 130, "LogTitle": "Escorting Erland"})
                fixtures["creature_template"].append({"entry": 1978, "name": "Erland", "ScriptName": "escort"})
                fixtures["creature"].append({"guid": 2, "id1": 1978, "map": 0})
                fixtures["script_waypoint"] = [{"entry": 1978, "pointid": 13, "location_x": 1290.75,
                                                "location_y": 1168.67, "location_z": 52.56}]
                cpp = {"events": {"435": [["monster", 1978]]},
                       "evidence": {"435": [{"actor": ["monster", 1978], "script": "escort", "file": "event.cpp", "line": 20}]},
                       "unsupported": [],
                       "escortWaypoints": [{"questId": 435, "npcId": 1978, "pointId": 13,
                                            "script": "escort", "file": "event.cpp", "line": 20}]}
                with patch.object(audit.cpp_events, "collect", return_value=cpp), \
                     patch.object(audit.cpp_credits, "collect", return_value={"credits": {}}):
                    expanded = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                    self.assertIn("s:triggerEnd", expanded["quests"]["435"])
                    self.assertEqual({proof["rule"] for proof in expanded["questGuides"]["escort"]["evidence"]},
                                     {"smartEscortEndPathCredit", "cppEscortWaypointCredit"})
                    with patch.object(audit.compatibility, "build_event_sources",
                                      return_value={"435": [["monster", 999]]}):
                        mixed = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                    self.assertNotIn("s:triggerEnd", mixed["quests"]["435"])
                    fixtures["script_waypoint"] = []
                    removed = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                    self.assertNotIn("s:triggerEnd", removed["quests"]["435"])
                    self.assertIn("s:triggerEnd", removed["quests"]["13229"])

                    fixtures["quest_template"].append({"ID": 4285, "QuestSortID": 490, "LogTitle": "The Northern Pylon"})
                    fixtures["gameobject_template"].append({"entry": 164955, "name": "Northern Pylon",
                                                          "AIName": "SmartGameObjectAI", "ScriptName": ""})
                    fixtures["gameobject"].append({"guid": 3, "id": 164955, "map": 1,
                                                  "position_x": -6276.06, "position_y": -1557.95, "position_z": -231.97})
                    fixtures["smart_scripts"].append({"entryorguid": 164955, "source_type": 1, "id": 0,
                                                     "event_type": 62, "event_chance": 100, "action_type": 15,
                                                     "action_param1": 4285, "target_type": 7})
                    object_guide = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                    self.assertEqual(object_guide["quests"]["4285"]["s:triggerEnd"]["n:2"],
                                     audit.typed({490: [[56.52, 12.54]]}))
                    fixtures["gameobject"][0]["ScriptName"] = "overridden"
                    object_removed = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                    self.assertNotIn("s:triggerEnd", object_removed["quests"]["4285"])
                    self.assertIn("s:triggerEnd", object_removed["quests"]["13229"])

    def test_proof_digest_survives_json_roundtrip_for_mixed_length_quest_ids(self):
        saved = {"quests": {}, "tableCoverage": {}, "diagnostics": {}, "disabledQuestIds": [],
                 "moduleQuestIds": [], "spellCoverage": {},
                 "questGuides": {"extra": {"flights": {"guides": {20: ["Pilot A"], 100: ["Pilot B"]}}}}}
        digest = audit.model_digest(saved)
        self.assertEqual(audit.model_digest(json.loads(json.dumps(saved))), digest)
        saved["questGuides"]["extra"]["flights"]["guides"][20] = ["Changed pilot"]
        self.assertNotEqual(audit.model_digest(saved), digest)

    def test_guide_spell_fields_keep_focus_items_and_reagents_with_sql_zero_overrides(self):
        row = {"Effect_1": 24, "EffectItemType_1": 17758, "RequiresSpellFocus": 43,
               "Reagent_1": 17761, "Reagent1": 999, "Reagent_2": 0, "Reagent2": 888}
        fields = audit.guide_spell_fields(row)
        self.assertEqual(fields["RequiresSpellFocus"], 43)
        self.assertEqual(fields["EffectItemType1"], 17758)
        self.assertEqual(fields["Reagent1"], 17761)
        self.assertEqual(fields["Reagent2"], 0)

    def test_children_reverse_only_active_parent_links(self):
        quests = {"1": {"s:parentQuest": 0}, "2": {"s:parentQuest": 1},
                  "3": {"s:preQuestSingle": audit.typed([1])},
                  "4": {"s:nextQuestInChain": 1}, "5": {"s:parentQuest": 99}}
        self.assertEqual(audit.derive_child_quests(quests),
                         {"1": audit.typed([2]), "2": {}, "3": {}, "4": {}, "5": {}})
        quests["1"]["s:parentQuest"] = 1
        with self.assertRaisesRegex(ValueError, "invalid active parent"):
            audit.derive_child_quests(quests)

    def test_preserved_inventory_distinguishes_empty_and_absent_fields(self):
        rows = {1: {"s:childQuests": {}, "s:requiredSpecialization": 0},
                2: {"s:childQuests": audit.typed([3]), "s:triggerEnd": audit.typed(["Explore"])}}
        report = audit.preserved_field_inventory(rows)
        self.assertEqual(report["childQuests"], {"presentRecords": 2, "populatedRecords": 1,
                                              "questIds": [2], "sourceDerived": True})
        self.assertEqual(report["requiredRanks"]["presentRecords"], 0)
        self.assertEqual(report["requiredSpecialization"]["populatedRecords"], 0)

    def test_faction_reputation_matches_first_template_and_refreshes_rewards(self):
        rows = [{"ID": 12, "Faction": 72, "EnemyGroup": 0}, {"ID": 11, "Faction": 72, "EnemyGroup": 4}]
        quests = {3741: {"reputationReward": ((72, 250), (999, 50))}}
        result = audit.faction_reputation_rewards(quests, lambda table: rows, set())["3741"]
        self.assertEqual(result["Alliance"], audit.typed([(72, 250), (999, 50)]))
        self.assertEqual(result["Horde"], audit.typed([(999, 50)]))
        rows[1]["EnemyGroup"] = 0
        result = audit.faction_reputation_rewards(quests, lambda table: rows, set())["3741"]
        self.assertEqual(result["Horde"], audit.typed([(72, 250), (999, 50)]))
        self.assertEqual(audit.faction_reputation_rewards(quests, lambda table: rows, {3741}), {})

    def test_letter_extraction_verifies_spell_item_and_sql_overrides(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            spell = (directory / "spell.sql").resolve()
            fixtures = {table: [] for table in audit.TABLE_KEYS}
            fixtures.update({"quest_template": [{"ID": 6681}],
                             "creature_template": [{"entry": 918, "faction": 1}],
                             "factiontemplate_dbc": [
                                 {"ID": i, "Faction": i, "FactionGroup": group, "EnemyGroup": enemy}
                                 for group, enemy, ids in ((3, 4, (1, 3, 4, 115, 1629)),
                                                          (5, 2, (2, 5, 6, 116, 1610))) for i in ids],
                             "conditions": [{"SourceTypeOrReferenceId": 15, "SourceGroup": 100, "SourceEntry": 4,
                                             "ConditionTypeOrReference": 9, "ConditionValue1": 6681}],
                             "smart_scripts": [{"entryorguid": 918, "source_type": 0, "id": 0, "event_type": 62,
                                                "event_param1": 100, "event_param2": 4, "action_type": 11,
                                                "action_param1": 21100, "target_type": 7}]})

            def derive(root, **kwargs):
                audit.metadata_reader.load_acore_sql_table(root, "spell", spell, wanted_keys=set())
                return {6681: {field: audit.metadata_reader.default_field_value(field)
                               for field in audit.metadata_reader.FIELD_ORDER}}

            with patch.object(audit.sql_reader, "load_row_table", side_effect=lambda root, table, *args, **kwargs: (fixtures[table], 0)), \
                 patch.object(audit.metadata_reader, "derive_acore_metadata", side_effect=derive), \
                 patch.object(audit.metadata_reader, "load_acore_sql_table", return_value={21100: {"ID": 21100, "Effect1": 24, "EffectItemType1": 17126}}), \
                 patch.object(audit.metadata_reader, "load_module_created_quest_ids", return_value=set()), \
                 patch.object(audit, "source_signature", return_value={}):
                cache = directory / "cache.json"
                saved = audit.load_source(ADDON_ROOT, spell, "spell", {}, cache)
                self.assertEqual(saved["scriptQuestStarters"], {"6681": [918]})
                self.assertEqual(saved["starterTeams"]["918"], 1)
                fixtures["spell_dbc"] = [{"ID": 21100, "EffectItemType1": 0}]
                before = cache.read_bytes()
                with self.assertRaisesRegex(ValueError, "no longer creates item17126"):
                    audit.load_source(ADDON_ROOT, spell, "spell", {}, cache, refresh=True)
                self.assertEqual(cache.read_bytes(), before)

    def test_letter_helpers_require_gossip_condition_and_follow_linked_actions(self):
        tables = {"conditions": [{"SourceTypeOrReferenceId": 15, "SourceGroup": 100,
                                  "SourceEntry": 4, "ConditionTypeOrReference": 9, "ConditionValue1": 6681}],
                  "smart_scripts": [
                      {"entryorguid": 918, "source_type": 0, "id": 0, "event_type": 62,
                       "event_param1": 100, "event_param2": 4, "link": 1},
                      {"entryorguid": 918, "source_type": 0, "id": 1, "event_type": 61,
                       "action_type": 11, "action_param1": 21100, "target_type": 7},
                      {"entryorguid": 332, "source_type": 0, "id": 0, "event_type": 0,
                       "action_type": 11, "action_param1": 21100, "target_type": 7}]}
        self.assertEqual(audit.script_quest_starters(lambda table: tables[table], {6681: {}}), {"6681": [918]})
        tables["smart_scripts"][0]["link"] = 99
        with self.assertRaisesRegex(ValueError, "missing linked"):
            audit.script_quest_starters(lambda table: tables[table], {6681: {}})
        tables["smart_scripts"][0]["link"] = 1
        tables["smart_scripts"][1]["link"] = 1
        with self.assertRaisesRegex(ValueError, "cyclic"):
            audit.script_quest_starters(lambda table: tables[table], {6681: {}})
        tables["conditions"] = []
        with self.assertRaisesRegex(ValueError, "unavailable"):
            audit.script_quest_starters(lambda table: tables[table], {6681: {}})

    def test_starter_teams_use_hostility_and_keep_neutral_sources(self):
        relations = {1947: {"start": {"creature": {11, 12, 13}}},
                     6681: {"start": {"creature": {99}}}}
        tables = {"creature_template": [{"entry": n, "faction": n} for n in (11, 12, 13)],
                  "factiontemplate_dbc": [{"ID": 11, "EnemyGroup": 4},
                                         {"ID": 12, "EnemyGroup": 2},
                                         {"ID": 13, "EnemyGroup": 0}]}
        players = [{"ID": n, "Faction": n, "FactionGroup": group}
                   for group, ids in ((3, (1, 3, 4, 115, 1629)), (5, (2, 5, 6, 116, 1610))) for n in ids]
        tables["factiontemplate_dbc"] = players + tables["factiontemplate_dbc"]
        self.assertEqual(audit.starter_teams(relations, lambda table: tables[table]),
                         {"11": 1, "12": 2, "13": 3})
        tables["factiontemplate_dbc"].pop()
        with self.assertRaisesRegex(ValueError, "NPC 13: missing"):
            audit.starter_teams(relations, lambda table: tables[table])
        tables["factiontemplate_dbc"].append({"ID": 13, "EnemyGroup": 6})
        with self.assertRaisesRegex(ValueError, "NPC 13: hostile to both"):
            audit.starter_teams(relations, lambda table: tables[table])
        tables["factiontemplate_dbc"][-1]["EnemyGroup"] = 1
        with self.assertRaisesRegex(ValueError, "NPC 13: hostile to both"):
            audit.starter_teams(relations, lambda table: tables[table])
        tables["factiontemplate_dbc"][-1].update(EnemyGroup=0, Enemies_1=1)
        with self.assertRaisesRegex(ValueError, "NPC 13: race-specific hostility within Alliance"):
            audit.starter_teams(relations, lambda table: tables[table])

    def test_starter_cache_checksum_covers_faction_access(self):
        saved = {"quests": {}, "tableCoverage": {}, "diagnostics": {}, "disabledQuestIds": [],
                 "moduleQuestIds": [], "spellCoverage": {}, "starterTeams": {"5497": 1}}
        digest = audit.model_digest(saved)
        saved["starterTeams"]["5497"] = 2
        self.assertNotEqual(audit.model_digest(saved), digest)

    def test_schema_accounts_for_supported_guides_and_unimplemented_fields(self):
        self.assertEqual(len(audit.FIELDS), 37)
        self.assertEqual(len(audit.SOURCE_FIELDS), 33)
        self.assertEqual(set(audit.FIELDS) - audit.SOURCE_FIELDS,
                         {"requiredSpecialization",
                          "availableStartingWith", "requiredRanks", "disabledByQuest"})

    def test_tuple_typing_preserves_objective_slots_and_zero_false_values(self):
        value = (None, ((19017,),), ((182,),))
        result = audit.typed(value)
        self.assertNotIn("n:1", result)
        self.assertEqual(result["n:2"]["n:1"]["n:1"], 19017)
        self.assertEqual(audit.typed((False, 0, None, ())), {"n:1": False, "n:2": 0, "n:4": {}})

    def test_objective_helpers_counts_text_and_sparse_slots_are_not_normalized_away(self):
        raw = audit.typed({1: [[6]]})
        source = {7: {"s:objectives": raw}}
        for slot, value in (("n:2", "Display helper"), ("n:3", 8)):
            baseline = copy.deepcopy(source)
            baseline[7]["s:objectives"]["n:1"]["n:1"][slot] = value
            row = audit.compare_fields(baseline, source, ["objectives"])["objectives"]
            self.assertEqual(row["counts"], {"valueDifferences": 1})
            self.assertEqual(row["differences"][0]["questId"], 7)
        baseline = {7: {"s:objectives": audit.typed({5: [[[6, 7], 6, "Event helper"]]})}}
        self.assertEqual(audit.compare_fields(baseline, source, ["objectives"])["objectives"]["counts"], {"valueDifferences": 1})

    def test_missing_templates_and_unavailable_fields_are_explicit(self):
        baseline = {1: {"s:extraObjectives": audit.typed(["Helper"])}, 2: {}}
        source = {1: {"s:name": "Quest"}}
        row = audit.compare_fields(baseline, source, ["extraObjectives"])["extraObjectives"]
        self.assertEqual(row["counts"], {"unavailableInSource": 1, "missingSourceTemplate": 1})
        self.assertFalse(row["differences"][0]["sourcePresent"])
        self.assertTrue(row["differences"][0]["snapshotPresent"])

    def test_default_representation_does_not_hide_nonempty_tables_or_false_numbers(self):
        baseline = {1: {}, 2: {"s:requiredLevel": False}}
        source = {1: {"s:requiredLevel": 0}, 2: {"s:requiredLevel": 0}}
        result = audit.compare_fields(baseline, source, ["requiredLevel"])["requiredLevel"]
        self.assertEqual(result["counts"], {"representationOnly": 1, "valueDifferences": 1})
        self.assertTrue(audit.representation_only("objectives", audit.shared.ABSENT, {"n:1": {}}))
        self.assertFalse(audit.representation_only("objectives", audit.shared.ABSENT, audit.typed({1: [[6]]})))

    def test_reputation_sign_and_amount_changes_remain_visible(self):
        baseline = {2: {"s:reputationReward": audit.typed([(81, 250)])}}
        for reward in (100, -250):
            source = {2: {"s:reputationReward": audit.typed([(81, reward)])}}
            self.assertEqual(audit.compare_fields(baseline, source, ["reputationReward"])["reputationReward"]["counts"],
                             {"valueDifferences": 1})

    def test_starter_sources_keep_categories_aliases_and_disabled_module_exclusions(self):
        tables = {table: [] for table in audit.relation_reader.TARGET_TABLES}
        tables.update({"creature_queststarter": [{"id": 102055, "quest": 1}, {"id": 2, "quest": 2}],
                       "gameobject_questender": [{"id": 3, "quest": 1}],
                       "game_event_creature_quest": [{"id": 4, "quest": 3}],
                       "item_template": [{"entry": 5, "startquest": 1}, {"entry": 6, "startquest": 2}]})
        result = audit.build_relations(lambda table: tables[table], {3}, {2})
        self.assertEqual(set(result), {1})
        self.assertEqual(result[1]["start"]["creature"], {2055})
        self.assertEqual(result[1]["start"]["item"], {5})
        self.assertEqual(result[1]["end"]["object"], {3})

    def test_missing_spells_are_traced_to_source_start_and_required_items_separately(self):
        items = [{"entry": 1, "name": "Source item", "spellid_1": 128, "spelltrigger_1": 0},
                 {"entry": 2, "name": "Unused item", "spellid_1": 20318, "spelltrigger_1": 0},
                 {"entry": 3, "name": "Equip effect", "spellid_1": 128, "spelltrigger_1": 1}]
        quests = [{"ID": 10, "ItemDrop1": 1}, {"ID": 11, "StartItem": 1}, {"ID": 12, "RequiredItemId1": 1}]
        refs = audit.missing_spell_references([128, 20318], items, quests)
        self.assertEqual(refs[0]["items"], [{"itemId": 1, "name": "Source item"}])
        self.assertEqual(refs[0]["requiredSourceItemQuestIds"], [10])
        self.assertEqual(refs[0]["startItemQuestIds"], [11])
        self.assertEqual(refs[0]["requiredItemQuestIds"], [12])
        self.assertEqual(refs[1]["requiredSourceItemQuestIds"], [])

    def test_cache_checksum_covers_disabled_ids_and_spell_coverage(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            cache = directory / "cache.json"
            saved = {"signature": {}, "quests": {"1": {"s:name": "Quest"}}, "tableCoverage": {}, "diagnostics": {},
                     "disabledQuestIds": [2], "moduleQuestIds": [], "spellCoverage": {}}
            saved["modelSha256"] = audit.model_digest(saved)
            audit.shared.write_json(cache, saved)
            with patch.object(audit.metadata_reader, "derive_acore_metadata", side_effect=AssertionError("Unexpected extraction")):
                self.assertEqual(audit.load_source(ADDON_ROOT, directory / "spell.sql", "spell", {}, cache), saved)
            saved["disabledQuestIds"] = []
            cache.write_text(json.dumps(saved), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                audit.load_source(ADDON_ROOT, directory / "spell.sql", "spell", {}, cache)

    def test_extraction_uses_shared_sql_replay_reports_skips_and_applies_zero_spell_overrides(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            spell = (directory / "spell.sql").resolve()
            statement = "UPDATE quest_template t JOIN other o ON o.id=t.ID SET t.QuestLevel=80"
            sql_file = directory / "unsupported.sql"
            sql_file.write_text(statement + ";", encoding="utf-8")
            before_table = audit.metadata_reader.load_acore_sql_table
            before_statements = audit.sql_reader.load_sql_statements
            fixtures = {table: [] for table in audit.TABLE_KEYS}
            fixtures.update({"quest_template": [{"ID": 1, "QuestSortID": -81}],
                             "spell_dbc": [{"ID": 10, "Effect_1": 0, "EffectItemType_1": 0, "Reagent_1": 0}],
                             "disables": [{"sourceType": 1, "entry": 2}]})

            def derive(root, **kwargs):
                self.assertEqual(kwargs, {"spell_sql": spell, "spell_table": "spell"})
                audit.metadata_reader.load_acore_conditions(root)
                audit.metadata_reader.load_acore_sql_table(root, "quest_template")
                rows = audit.metadata_reader.load_acore_sql_table(root, "spell", spell, wanted_keys={10, 11})
                self.assertEqual(audit.metadata_reader.get_numbered_spell_field(rows[10], "Effect", 1), 0)
                self.assertEqual(audit.metadata_reader.get_numbered_spell_field(rows[10], "Reagent", 1), 0)
                audit.sql_reader.load_sql_statements(str(sql_file))
                self.assertEqual(audit.sql_reader.apply_multirow_update(statement, "quest_template", {}), 1)
                fields = {field: audit.metadata_reader.default_field_value(field) for field in audit.metadata_reader.FIELD_ORDER}
                fields.update(name="Quest", reputationReward=((81, 250),))
                return {1: fields}

            with patch.object(audit.sql_reader, "load_row_table", side_effect=lambda root, table, *args, **kwargs: (fixtures[table], 0)), \
                 patch.object(audit.metadata_reader, "derive_acore_metadata", side_effect=derive), \
                 patch.object(audit.metadata_reader, "load_acore_sql_table", return_value={10: {"ID": 10, "Effect1": 24, "Reagent1": 50}}), \
                 patch.object(audit.metadata_reader, "load_module_created_quest_ids", return_value=set()), \
                 patch.object(audit, "source_signature", return_value={}):
                saved = audit.load_source(ADDON_ROOT, spell, "spell", {}, directory / "cache.json")
            self.assertIs(audit.metadata_reader.load_acore_sql_table, before_table)
            self.assertIs(audit.sql_reader.load_sql_statements, before_statements)
            self.assertEqual(saved["quests"]["1"]["s:zoneOrSort"], -81)
            self.assertEqual(saved["quests"]["1"]["s:reputationReward"], audit.typed([(81, 250)]))
            self.assertEqual(saved["spellCoverage"]["missingRequestedSpellIds"], [11])
            self.assertEqual(saved["diagnostics"]["skippedSqlMutations"][0]["statement"], statement)

    def test_failed_extraction_restores_functions_and_publishes_nothing(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            original_table = audit.metadata_reader.load_acore_sql_table
            original_update = audit.sql_reader.apply_multirow_update
            cache = directory / "cache.json"
            with patch.object(audit.metadata_reader, "derive_acore_metadata", side_effect=ValueError("fixture failure")):
                with self.assertRaisesRegex(ValueError, "fixture failure"):
                    audit.load_source(ADDON_ROOT, directory / "spell.sql", "spell", {}, cache)
            self.assertIs(audit.metadata_reader.load_acore_sql_table, original_table)
            self.assertIs(audit.sql_reader.apply_multirow_update, original_update)
            self.assertFalse(cache.exists())


if __name__ == "__main__":
    unittest.main()
