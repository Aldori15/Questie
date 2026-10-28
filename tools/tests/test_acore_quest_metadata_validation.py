import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import validate_acore_quest_metadata as validator


class QuestMetadataValidationTests(unittest.TestCase):
    def derive(self, quest, items, spells=None, overrides=None, candidates=None):
        tables = {
            "quest_template": {quest["ID"]: quest},
            "quest_template_addon": {},
            "item_template": items,
            "spell": spells or {},
            "spell_dbc": overrides or {},
        }

        def load_table(root, table, *args, **kwargs):
            rows = tables[table]
            if kwargs.get("wanted_keys") is not None:
                rows = {key: row for key, row in rows.items() if key in kwargs["wanted_keys"]}
            return copy.deepcopy(rows)

        with patch.object(validator, "load_acore_sql_table", side_effect=load_table), \
                patch.object(validator, "load_acore_conditions", return_value=[]), \
                patch.object(validator, "load_module_created_quest_ids", return_value=set()), \
                patch.object(validator, "restore_excluded_module_metadata_rows"):
            return validator.derive_acore_metadata(
                Path("source"), spell_sql=Path("spell.sql"),
                source_tool_candidates=candidates or {})[quest["ID"]]

    def test_provided_items_and_proven_tools_survive_without_duplicating_objectives(self):
        quest = {"ID": 30, "LogTitle": "Combine the pendant", "StartItem": 100,
                 "ItemDrop1": 300, "RequiredItemId1": 300,
                 "QuestDescription": "Use the Druid's Silver Charm."}
        items = {
            100: {"entry": 100, "name": "Tool", "spellid1": 500, "spelltrigger1": 0},
            300: {"entry": 300, "name": "Pendant"},
            400: {"entry": 400, "name": "Component"},
            600: {"entry": 600, "name": "Druid's Silver Charm"},
            700: {"entry": 700, "name": "Unrelated Charm"},
        }
        spells = {500: {"ID": 500, "Effect_1": 24, "EffectItemType_1": 300, "Reagent_1": 400}}
        row = self.derive(quest, items, spells, candidates={"30": [600, 700, 999]})
        self.assertEqual(row["requiredSourceItems"], (100, 400, 600))

    def test_explicit_zero_spell_override_removes_stale_created_tool(self):
        quest = {"ID": 1, "StartItem": 100}
        items = {100: {"entry": 100, "spellid1": 500, "spelltrigger1": 0},
                 200: {"entry": 200}, 400: {"entry": 400}}
        spells = {500: {"ID": 500, "Effect1": 24, "EffectItemType1": 200, "Reagent1": 400}}
        before = self.derive(quest, items, spells)
        after = self.derive(quest, items, spells, overrides={500: {"ID": 500, "Effect_1": 0}})
        self.assertEqual(before["requiredSourceItems"], (100, 200, 400))
        self.assertEqual(after["requiredSourceItems"], (100, 400))

    def test_changed_quest_text_invalidates_candidate_tool_proof(self):
        items = {600: {"entry": 600, "name": "Druid's Silver Charm"}}
        quest = {"ID": 1, "QuestDescription": "Use the Druid's Silver Charm."}
        self.assertEqual(self.derive(quest, items, candidates={"1": [600]})["requiredSourceItems"], (600,))
        quest["QuestDescription"] = "Speak to the druid."
        self.assertEqual(self.derive(quest, items, candidates={"1": [600]})["requiredSourceItems"], ())

    def test_tool_spell_selection_includes_trigger_five_and_underscored_columns(self):
        items = {100: {"entry": 100, "spellid_1": 500, "spelltrigger_1": 5},
                 200: {"entry": 200}}
        spells = {500: {"ID": 500, "Effect1": 24, "EffectItemType1": 200}}
        row = self.derive({"ID": 1, "StartItem": 100}, items, spells)
        self.assertEqual(row["requiredSourceItems"], (100, 200))

    def test_endpoint_hints_leave_explicit_race_requirements_unchanged(self):
        metadata = {55: {"requiredRaces": 0}, 56: {"requiredRaces": 32}}
        relations = {quest: {"start": {"creature": {311}}, "end": {"creature": {311}}}
                     for quest in metadata}
        hints = validator.derive_endpoint_faction_hints(
            metadata, relations, {311: "A"}, {"ALL_ALLIANCE": 1101, "ALL_HORDE": 690})
        self.assertEqual(hints, {55: "A"})
        self.assertEqual(metadata, {55: {"requiredRaces": 0}, 56: {"requiredRaces": 32}})

    def test_strict_comparison_reports_missing_and_unproven_extra_tools(self):
        source = {field: validator.default_field_value(field) for field in validator.FIELD_ORDER}
        source["name"] = "Quest"
        source["requiredSourceItems"] = (100,)
        for items in [(), (100, 999)]:
            with self.subTest(items=items):
                current = {**source, "requiredSourceItems": items}
                result = validator.compare_metadata(
                    {1: source}, {1: current}, {}, set(), strict_source_tools=True)
                self.assertEqual([row["field"] for row in result[0]], ["requiredSourceItems"])

    def test_explicit_race_and_level_errors_still_fail_comparison(self):
        source = {field: validator.default_field_value(field) for field in validator.FIELD_ORDER}
        source.update(name="Quest", requiredRaces=32, requiredLevel=16)
        current = {**source, "requiredRaces": 0, "requiredLevel": 1}
        result = validator.compare_metadata({1: source}, {1: current}, {}, set(), strict_source_tools=True)
        self.assertEqual({row["field"] for row in result[0]}, {"requiredRaces", "requiredLevel"})


if __name__ == "__main__":
    unittest.main()
