"""Quest auditing retains exact structure and exposes unsupported source coverage."""
import copy
import json
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_quest_sources as audit
import db_snapshot


class QuestSourceAuditTests(unittest.TestCase):
    def test_all_schema_fields_are_accounted_for_without_claiming_helper_coverage(self):
        self.assertEqual(len(audit.FIELDS), 37)
        self.assertEqual(len(audit.SOURCE_FIELDS), 28)
        self.assertEqual(set(audit.FIELDS) - audit.SOURCE_FIELDS,
                         {"triggerEnd", "childQuests", "inGroupWith", "extraObjectives", "requiredSpecialization",
                          "availableUntilCompleted", "availableStartingWith", "requiredRanks", "disabledByQuest"})

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
