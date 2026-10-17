"""Exercise source semantics that can lose or invent item acquisition links."""
import contextlib
import io
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import generate_acore_item_corrections as reader


def loot(item=0, chance=100, group=0, reference=0, **fields):
    return {"Entry": 100, "Item": item, "Chance": chance, "GroupId": group, "Reference": reference, **fields}


class ItemSourceTests(unittest.TestCase):
    def test_legacy_correction_command_rejects_complete_base_before_reading_sql(self):
        errors = io.StringIO()
        with patch("sys.argv", ["generate_acore_item_corrections.py", "--repo-root", str(ADDON_ROOT)]), \
             patch.object(reader, "build_acore_items", side_effect=AssertionError("Unexpected SQL scan")), \
             contextlib.redirect_stderr(errors):
            with self.assertRaises(SystemExit) as result:
                reader.main()
        self.assertEqual(result.exception.code, 2)
        self.assertIn("generate_acore_item_base.py generate", errors.getvalue())

    def test_equal_chance_rows_share_the_remaining_group_probability(self):
        rows = [loot(1, 20, 1), loot(2, 0, 1), loot(3, 0, 1)]
        self.assertEqual(reader.resolve_loot_row_chances(rows, {}), {1: 20, 2: 40, 3: 40})

    def test_explicit_group_can_exhaust_equal_rows_and_ungrouped_zero_is_invalid(self):
        rows = [loot(1, 100, 1), loot(2, 0, 1), loot(3, 0)]
        self.assertEqual(reader.resolve_loot_rows(rows, {}), {1})

    def test_quest_filter_does_not_renormalize_nonquest_group_competitors(self):
        rows = [loot(1, 50, 1), loot(2, 0, 1, QuestRequired=1)]
        self.assertEqual(reader.resolve_loot_row_chances(rows, {}, quest_required_only=True), {2: 50})
        self.assertEqual(reader.build_object_primary_item_ids(rows, {}), set())

    def test_independent_rolls_and_exclusive_selections_combine_differently(self):
        independent = reader.resolve_loot_row_chances([loot(1, 50), loot(1, 50)], {})
        exclusive = reader.resolve_loot_row_chances([loot(1, 50, 1), loot(1, 50, 1)], {})
        self.assertAlmostEqual(independent[1], 75)
        self.assertAlmostEqual(exclusive[1], 100)

    def test_nested_references_repeat_child_rolls_before_the_parent_probability(self):
        references = {10: [loot(1, 25, QuestRequired=1)]}
        rows = [loot(chance=50, reference=10, MaxCount=2)]
        self.assertAlmostEqual(reader.resolve_loot_row_chances(rows, references)[1], 21.875)
        self.assertAlmostEqual(reader.resolve_loot_row_chances(rows, references, quest_required_only=True)[1], 21.875)
        self.assertEqual(reader.resolve_loot_rows([loot(reference=10, MaxCount=0)], references), set())

    def test_grouped_reference_selects_the_entire_nested_template(self):
        references = {10: [loot(1, 0, 7), loot(2, 0, 7)]}
        rows = [loot(3, 50, 1), loot(chance=0, group=1, reference=-10)]
        self.assertEqual(reader.resolve_loot_row_chances(rows, references), {3: 50, 1: 25, 2: 25})

    def test_loot_modes_are_separate_and_disabled_mode_stays_disabled(self):
        rows = [loot(1, 0, 1, LootMode=1), loot(2, 0, 1, LootMode=2), loot(3, LootMode=0)]
        self.assertEqual(reader.resolve_loot_row_chances(rows, {}), {1: 100, 2: 100})
        self.assertEqual(reader.resolve_loot_rows([loot(reference=10, LootMode=1)], {10: [loot(1, LootMode=2)]}), set())

    def test_reference_cycles_are_reported_without_losing_acyclic_siblings(self):
        references = {10: [loot(1), loot(reference=20)], 20: [loot(2), loot(reference=10)]}
        issues, cache = {}, {}
        first = reader.resolve_loot_row_chances([loot(reference=10)], references, reference_cache=cache, diagnostics=issues)
        second = reader.resolve_loot_row_chances([loot(reference=20)], references, reference_cache=cache, diagnostics=issues)
        self.assertEqual(set(first), {1, 2})
        self.assertEqual(set(second), {1, 2})
        self.assertTrue(issues["lootReferenceCycles"])

    def test_missing_reference_is_reported_and_tiny_positive_chances_survive(self):
        issues = {}
        self.assertEqual(reader.resolve_loot_rows([loot(reference=10)], {}), set())
        reader.resolve_loot_row_chances([loot(reference=10)], {}, diagnostics=issues)
        self.assertEqual(issues["missingLootReferences"], {10})
        result = reader.resolve_loot_row_chances([loot(chance=0.000001, reference=10)], {10: [loot(1, 0.000001)]})
        self.assertGreater(result[1], 0)

    def test_invalid_loot_items_are_removed_before_group_denominators(self):
        issues = {}
        rows = reader.validate_loot_items([loot(1, 0, 1), loot(999, 0, 1)], {1}, issues)
        self.assertEqual(reader.resolve_loot_row_chances(rows, {}), {1: 100})
        self.assertEqual(issues["unknownLootItemIds"], {999})

    def test_unmapped_loot_ids_do_not_become_fake_npc_or_object_entries(self):
        rows = [loot(1)]
        self.assertEqual(dict(reader.add_item_sources_from_loot(rows, {}, {})), {})
        self.assertEqual(reader.add_item_sources_from_loot(rows, {}, {100: {200}})[1], {200})

    def test_invalid_loot_counts_and_group_ids_are_rejected(self):
        issues = {}
        rows = [loot(1, MinCount=0), loot(1, MinCount=2, MaxCount=1), loot(1, group=128)]
        self.assertEqual(reader.validate_loot_items(rows, {1}, issues), [])
        self.assertEqual(issues["invalidLootEntryIds"], {100})

    def test_vendor_references_keep_original_sellers_and_allow_reference_only_lists(self):
        rows = [{"entry": 500, "item": 1}, {"entry": 10, "item": -500}, {"entry": 20, "item": -10}]
        sources = reader.build_item_vendor_sources(rows, {1}, {10, 20})
        self.assertEqual(dict(sources), {1: {10, 20}})

    def test_vendor_cycles_missing_references_and_unknown_items_are_reported(self):
        rows = [{"entry": 10, "item": 1}, {"entry": 10, "item": -20},
                {"entry": 20, "item": -10}, {"entry": 20, "item": -900}, {"entry": 20, "item": 999}]
        issues = {}
        self.assertEqual(dict(reader.build_item_vendor_sources(rows, {1}, {10, 20}, issues)), {1: {10, 20}})
        self.assertTrue(issues["vendorReferenceCycles"])
        self.assertEqual(issues["missingVendorReferences"], {900})
        self.assertEqual(issues["unknownVendorItemIds"], {999})

    def test_spellclick_requires_creation_effect_and_valid_templates(self):
        spells = {10: {"Effect_1": 24, "EffectItemType_1": 1},
                  20: {"Effect_1": 6, "EffectItemType_1": 5},
                  30: {"Effect_1": 157, "EffectItemType_1": 999}}
        clicks = [{"npc_entry": 100, "spell_id": spell} for spell in (10, 20, 30, 40)]
        clicks.append({"npc_entry": 999, "spell_id": 10})
        issues = {}
        result = reader.add_item_sources_from_spellclick(clicks, spells, {1, 5}, {100}, issues)
        self.assertEqual(dict(result), {1: {100}})
        self.assertEqual(issues["nonCreationSpellclickItemValues"], {5})
        self.assertEqual(issues["unknownSpellclickItemIds"], {999})
        self.assertEqual(issues["unknownSpellclickNpcIds"], {999})
        self.assertEqual(issues["missingSpellclickSpellIds"], {40})

    def test_guid_mapping_accepts_both_creature_schema_names(self):
        rows = {1: {"guid": 1, "id": 10}, 2: {"guid": 2, "id1": 20}, 3: {"guid": 3, "entry": 30}}
        self.assertEqual(reader.build_creature_guid_to_entry(rows), {1: 10, 2: 20, 3: 30})

    def test_full_model_never_creates_partial_records_from_invalid_relations(self):
        keyed = {
            "item_template": {1: {"entry": 1, "name": "Item"}, 2: {"entry": 2, "name": "Container"}},
            "quest_template": {10: {"StartItem": 888, "RewardItem1": 999, "RequiredItemId1": 1}},
            "creature_template": {10: {"entry": 10, "lootid": 100}, 20: {"entry": 20}},
            "gameobject_template": {55: {"entry": 55, "type": 3, "Data1": 900}},
            "creature": {77: {"guid": 77, "id1": 20}},
            "spell_dbc": {100: {"Effect_1": 24, "EffectItemType_1": 5}},
        }
        tables = {
            "reference_loot_template": [loot(1)],
            "creature_loot_template": [loot(chance=0.5, reference=100), loot(999)],
            "gameobject_loot_template": [loot(1, 50, Entry=900), loot(1, Entry=901, QuestRequired=1)],
            "item_loot_template": [loot(1, 0, 1, Entry=2), loot(1, Entry=999)],
            "npc_vendor": [{"entry": 500, "item": 1}, {"entry": 20, "item": -500}],
            "game_event_npc_vendor": [{"guid": 77, "item": 2}],
            "npc_spellclick_spells": [{"npc_entry": 10, "spell_id": 100}],
        }
        with patch.object(reader, "load_keyed_table", side_effect=lambda root, table, key, modules=False: (keyed.get(table, {}), 0)), \
             patch.object(reader, "load_row_table", side_effect=lambda root, table, keys, modules=False: (tables.get(table, []), 0)):
            items, _, context = reader.build_acore_items(ADDON_ROOT)
        self.assertEqual(set(items), {1, 2})
        self.assertEqual(items[1]["npcDrops"], [10])
        self.assertEqual(items[1]["objectDrops"], [55])
        self.assertEqual(items[1]["itemDrops"], [2])
        self.assertEqual(items[1]["vendors"], [20])
        self.assertEqual(items[2]["vendors"], [20])
        self.assertEqual(context["sourceDiagnostics"]["unknownQuestItemIds"], [888, 999])
        self.assertEqual(context["sourceDiagnostics"]["unknownSpellclickItemIds"], [5])
        self.assertEqual(context["sourceDiagnostics"]["unknownItemLootContainers"], [999])
        self.assertEqual(context["sourceDiagnostics"]["unmappedLootSourceEntries"], [901])


if __name__ == "__main__":
    unittest.main()
