"""Replay the SQL forms that the NPC audit found were being skipped."""
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot
import generate_acore_item_corrections as reader


class SqlPredicateTests(unittest.TestCase):
    def test_at_signs_and_numeric_text_in_quoted_values_are_literals(self):
        text = "Morganth - hp@50 - @GUID 001 remains literal"
        for context in (None, {"@guid": 100}):
            self.assertEqual(reader.parse_insert_sql_value(repr(text), context), text)
        rows = {}
        statement = "INSERT INTO `smart_scripts` VALUES (397,0,2,53,'Morganth - hp@50 - Start path 001')"
        skipped = reader.apply_multirow_insert(statement, "smart_scripts",
            ["entryorguid", "source_type", "id", "action_type", "comment"], rows,
            ("entryorguid", "source_type", "id"), row_filter=lambda row: row["action_type"] == 53)
        self.assertEqual(skipped, 0)
        self.assertEqual(rows[(397, 0, 2)]["comment"], "Morganth - hp@50 - Start path 001")

    def test_in_list_supports_nested_arithmetic_and_mysql_leading_zero_integers(self):
        rows = {(i,): {"guid": i} for i in (100, 106, 108, 109)}
        statement = "DELETE FROM `creature_addon` WHERE `guid` IN (@GUID+06,@GUID+08)"
        self.assertEqual(reader.apply_multirow_delete(statement, "creature_addon", rows, {"@guid": 100}), 0)
        self.assertEqual(set(rows), {(100,), (109,)})
        rows = {(i,): {"id": i} for i in (1000, 1010, 1020, 1030, 1040)}
        statement = "DELETE FROM `waypoint_data` WHERE `id` IN ((@GUID)*10, (@GUID+1)*10, (@GUID+2)*10, (@GUID+3)*10)"
        self.assertEqual(reader.apply_multirow_delete(statement, "waypoint_data", rows, {"@guid": 100}), 0)
        self.assertEqual(set(rows), {(1040,)})

    def test_or_between_predicates_keep_gap_rows(self):
        rows = {(i,): {"id": i} for i in (3414400, 3414401, 3414406, 3414407, 3414501, 3414506, 3414507)}
        statement = "DELETE FROM `waypoint_data` WHERE `id` BETWEEN 3414401 AND 3414406 OR `id` BETWEEN 3414501 AND 3414506"
        self.assertEqual(reader.apply_multirow_delete(statement, "waypoint_data", rows), 0)
        self.assertEqual(set(rows), {(3414400,), (3414407,), (3414507,)})

    def test_grouped_or_and_smart_script_deletion_matches_each_source_type(self):
        pairs = [(29196, 0), (29196, 9), (2919600, 0), (2919600, 9), (99, 0)]
        rows = {pair: {"entryorguid": pair[0], "source_type": pair[1]} for pair in pairs}
        statement = "DELETE FROM `smart_scripts` WHERE (`entryorguid`=29196 AND `source_type`=0) OR (`entryorguid`=2919600 AND `source_type`=9)"
        self.assertEqual(reader.apply_multirow_delete(statement, "smart_scripts", rows), 0)
        self.assertEqual(set(rows), {(29196, 9), (2919600, 0), (99, 0)})

    def test_and_binds_tighter_than_or_and_parentheses_override_precedence(self):
        constraints = reader.parse_where_constraints("id=1 OR id=2 AND flag=1")
        self.assertTrue(reader.row_matches_constraints({"id": 1, "flag": 0}, constraints))
        self.assertFalse(reader.row_matches_constraints({"id": 2, "flag": 0}, constraints))
        self.assertTrue(reader.row_matches_constraints({"id": 2, "flag": 1}, constraints))
        constraints = reader.parse_where_constraints("(id=1 OR id=2) AND flag=1")
        self.assertFalse(reader.row_matches_constraints({"id": 1, "flag": 0}, constraints))
        self.assertTrue(reader.row_matches_constraints({"id": 2, "flag": 1}, constraints))
        constraints = reader.parse_where_constraints("id=1 AND id=2")
        self.assertFalse(reader.row_matches_constraints({"id": 2}, constraints))

    def test_keywords_inside_literals_and_column_names_are_not_boolean_splits(self):
        constraints = reader.parse_where_constraints("floor=1 AND command=2 AND comment='A OR B @GUID 001'")
        self.assertIsNotNone(constraints)
        self.assertTrue(reader.row_matches_constraints({"floor": 1, "command": 2, "comment": "A OR B @GUID 001"}, constraints))
        constraints = reader.parse_where_constraints("comment IN ('a@b', '001')")
        self.assertTrue(reader.row_matches_constraints({"comment": "a@b"}, constraints))

    def test_unresolved_variables_subqueries_and_trailing_sql_remain_unsupported(self):
        for predicate in ("id IN (@missing)", "id IN (SELECT id FROM creature)", "id IN (1) trailing"):
            self.assertIsNone(reader.parse_where_constraints(predicate), predicate)
        rows = {(1,): {"id": 1}}
        statement = "DELETE FROM creature_addon WHERE id=1 OR id IN (SELECT id FROM creature)"
        self.assertEqual(reader.apply_multirow_delete(statement, "creature_addon", rows), 1)
        self.assertEqual(set(rows), {(1,)})

    def test_real_table_replay_applies_variable_arithmetic_and_or_deletions(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            base = directory / "data/sql/base/db_world"
            updates = directory / "data/sql/updates/db_world"
            base.mkdir(parents=True)
            updates.mkdir(parents=True)
            (base / "waypoint_data.sql").write_text(
                "CREATE TABLE `waypoint_data` (\n`id` INT,\n`point` INT\n) ENGINE=InnoDB;\n"
                "INSERT INTO waypoint_data VALUES (1000,1),(1010,1),(1020,1),(2000,1);", encoding="utf-8")
            (updates / "update.sql").write_text(
                "SET @GUID=100; DELETE FROM waypoint_data WHERE id IN ((@GUID)*10,(@GUID+01)*10) OR id=2000;",
                encoding="utf-8")
            rows, skipped = reader.load_row_table(directory, "waypoint_data", ("id", "point"))
            self.assertEqual(skipped, 0)
            self.assertEqual(rows, [{"id": 1020, "point": 1}])


if __name__ == "__main__":
    unittest.main()
