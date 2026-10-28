"""Maintenance readers must not confuse faction metadata with shared records."""
from pathlib import Path
import unittest

from _test_paths import ADDON_ROOT
from db_snapshot import temporary_directory
from questie_base import base_text, parse_keys, return_table
from validate_item_start_links import load_base_item_starts
from validate_reverse_quest_links import load_questie_relations
from validate_acore_quest_metadata import parse_lua_value


class SharedBaseReaderTests(unittest.TestCase):
    def test_all_chunks_are_read_and_faction_metadata_is_excluded(self):
        source = '''QuestieDB.itemData = {
[===[return { [10]={"First",nil,nil,nil,100}, } ]===],
[===[return { [20]={"Second",nil,nil,nil,200}, } ]===],
}
QuestieDB.itemFactionSelections = {
[10] = {nil,nil,nil,nil,999},
[30] = {nil,nil,nil,nil,300},
}
'''
        with temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = Path(directory) / "base.lua"
            path.write_text(source, encoding="utf-8")
            self.assertEqual(load_base_item_starts(path), {10: 100, 20: 200})
            self.assertNotIn("999", base_text(path))

    def test_duplicate_records_across_chunks_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate database record 10"):
            return_table('QuestieDB.itemData = {[[return {[10]={},}]], [[return {[10]={},}]]}',
                         "QuestieDB.itemData")

    def test_key_maps_accept_generated_and_inherited_quotes(self):
        with temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = Path(directory) / "keys.lua"
            path.write_text('QuestieDB.itemKeys = {["name"]=1, [\'startQuest\']=5}', encoding="utf-8")
            self.assertEqual(parse_keys(path, "item"), {"name": 1, "startQuest": 5})

    def test_explicit_array_indices_preserve_nil_slots(self):
        self.assertEqual(parse_lua_value('{[1]=100,[3]={[1]=200,[3]=false}}', {}),
                         [100, None, [200, None, False]])

    def test_partial_quest_records_are_not_dropped(self):
        with temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = Path(directory) / "quest.lua"
            path.write_text('[99]={"Partial"},\n', encoding="utf-8")
            rows = load_questie_relations(path)
            self.assertEqual(set(rows), {99})
            self.assertFalse(any(rows[99]["start"].values()))
            self.assertFalse(any(rows[99]["end"].values()))


if __name__ == "__main__":
    unittest.main()
