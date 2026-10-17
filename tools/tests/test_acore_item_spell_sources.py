"""Spell exports fill DBC coverage without undoing AzerothCore SQL overrides."""
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_item_sources as audit
import db_snapshot
import generate_acore_item_corrections as reader


def export_fixture(path, underscored=False, table="spell"):
    columns = ["ID"] + [f"{prefix}{'_' if underscored else ''}{i}"
                          for prefix in ("Effect", "EffectItemType") for i in range(1, 4)]
    definitions = ",\n".join(f"`{column}` INT NOT NULL DEFAULT '0'" for column in columns)
    path.write_text(f"CREATE TABLE IF NOT EXISTS `{table}` (\n{definitions}\n) ENGINE=InnoDB;\n"
                    f"INSERT INTO `{table}` VALUES (10,24,0,0,1,0,0),(20,24,0,0,2,0,0),"
                    "(30,157,0,0,3,0,0);\n", encoding="utf-8")


class ItemSpellSourceTests(unittest.TestCase):
    def test_real_export_parser_normalizes_columns_and_selects_requested_spells(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "spell.sql"
            export_fixture(path)
            spells, coverage = reader.load_item_source_spells(ADDON_ROOT, {}, {10, 30, 99}, path)
            self.assertEqual(set(spells), {10, 30})
            self.assertEqual(spells[30]["Effect_1"], 157)
            self.assertEqual(spells[30]["EffectItemType_1"], 3)
            self.assertEqual(coverage["exportRowsLoaded"], 2)
            self.assertEqual(coverage["missingRequestedSpellIds"], 1)
            clicks = [{"npc_entry": 100, "spell_id": spell} for spell in (10, 30, 99)]
            issues = {}
            self.assertEqual(dict(reader.add_item_sources_from_spellclick(clicks, spells, {1, 3}, {100}, issues)),
                             {1: {100}, 3: {100}})
            self.assertEqual(issues["missingSpellclickSpellIds"], {99})

    def test_sql_record_replaces_export_values_including_zero(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "spell.sql"
            export_fixture(path)
            sql = {10: {"Effect_1": 0, "EffectItemType_1": 0},
                   20: {"Effect_1": 24, "EffectItemType_1": 9},
                   40: {"Effect_1": 24, "EffectItemType_1": 4}}
            spells, coverage = reader.load_item_source_spells(ADDON_ROOT, sql, {10, 20, 30, 40}, path)
            self.assertEqual(spells[10]["Effect_1"], 0)
            self.assertEqual(spells[10]["EffectItemType_1"], 0)
            self.assertEqual(spells[20]["EffectItemType_1"], 9)
            self.assertEqual(spells[30]["EffectItemType_1"], 3)
            self.assertEqual(spells[40]["EffectItemType_1"], 4)
            self.assertEqual(coverage["exportIdsOverriddenBySql"], 2)
            self.assertEqual(coverage["missingRequestedSpellIds"], 0)

    def test_underscored_columns_and_alternate_table_are_supported(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "spell.sql"
            export_fixture(path, underscored=True, table="exported_spells")
            spells, _ = reader.load_item_source_spells(ADDON_ROOT, {}, {10}, path, "exported_spells")
            self.assertEqual(spells[10]["EffectItemType_1"], 1)

    def test_without_export_sql_only_behavior_is_preserved(self):
        spells, coverage = reader.load_item_source_spells(ADDON_ROOT,
            {10: {"Effect_1": 24, "EffectItemType_1": 1}}, {10, 20})
        self.assertEqual(spells[10]["EffectItemType_1"], 1)
        self.assertFalse(coverage["exportProvided"])
        self.assertEqual(coverage["missingRequestedSpellIds"], 1)

    def test_missing_export_or_incomplete_schema_fails_instead_of_silent_sql_fallback(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "spell.sql"
            with self.assertRaisesRegex(ValueError, "not found"):
                reader.load_item_source_spells(ADDON_ROOT, {}, {10}, path)
            path.write_text("CREATE TABLE `spell` (\n`ID` INT,\n`Effect1` INT\n) ENGINE=InnoDB;", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "must contain"):
                reader.load_item_source_spells(ADDON_ROOT, {}, {10}, path)

    def test_missing_fields_in_exported_row_fail(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "spell.sql"
            export_fixture(path)
            with patch.object(reader, "load_acore_sql_table", return_value={10: {"Effect1": 24}}):
                with self.assertRaisesRegex(ValueError, "Incomplete"):
                    reader.load_item_source_spells(ADDON_ROOT, {}, {10}, path)

    def test_source_signature_tracks_export_bytes_path_and_table(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            (directory / "data/sql/base/db_world").mkdir(parents=True)
            (directory / "data/sql/base/db_world/item_template.sql").write_text("", encoding="utf-8")
            path = directory / "spell.sql"
            export_fixture(path)
            with patch.object(audit.source_reader, "source_sql_files", return_value=[]):
                first = audit.source_signature(directory, "starts", path)
                alternate_table = audit.source_signature(directory, "starts", path, "other")
                path.write_text(path.read_text(encoding="utf-8") + "\n-- changed\n", encoding="utf-8")
                changed = audit.source_signature(directory, "starts", path)
            self.assertNotEqual(first, alternate_table)
            self.assertNotEqual(first, changed)
            self.assertEqual(first["spellExport"]["path"], str(path.resolve()))

    def test_source_cache_digest_covers_spell_coverage(self):
        saved = {"items": {}, "templateIds": [], "tableCoverage": {}, "spellCoverage": {"exportRowsLoaded": 1}}
        digest = audit.model_digest(saved)
        saved["spellCoverage"]["exportRowsLoaded"] = 2
        self.assertNotEqual(digest, audit.model_digest(saved))


if __name__ == "__main__":
    unittest.main()
