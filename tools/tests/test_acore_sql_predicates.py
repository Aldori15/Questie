"""Replay the SQL forms that the NPC audit found were being skipped."""
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot
import generate_acore_item_corrections as reader
import generate_acore_npc_corrections as npc_reader


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

    def test_tuple_in_preserves_pairs_and_outer_source_type_filter(self):
        entries = [(4, 11524, 11614), (4, 11525, 11615), (4, 11524, 11615), (1, 11524, 11614)]
        rows = {key: dict(zip(("SourceTypeOrReferenceId", "SourceGroup", "SourceEntry"), key)) for key in entries}
        statement = "DELETE FROM conditions WHERE SourceTypeOrReferenceId=4 AND (`SourceGroup`,`SourceEntry`) IN ((11524,11614),(11525,11615))"
        self.assertEqual(reader.apply_multirow_delete(statement, "conditions", rows), 0)
        self.assertEqual(set(rows), {(4, 11524, 11615), (1, 11524, 11614)})
        constraints = reader.parse_where_constraints("(SourceGroup,SourceEntry) IN ((@base+01,2)) OR SourceEntry=99", {"@base": 100})
        self.assertTrue(reader.row_matches_constraints({"SourceGroup": 101, "SourceEntry": 2}, constraints))
        self.assertTrue(reader.row_matches_constraints({"SourceGroup": 0, "SourceEntry": 99}, constraints))

    def test_invalid_tuple_predicates_are_reported_without_deleting_rows(self):
        for clause in ("(a,b) IN ((1))", "(a,b) IN ((1,2,3))", "(a,b) IN ((1,NULL))",
                       "(a,b) IN (SELECT a,b FROM other)", "(a,b) IN ()", "(a,b) IN ((@missing,2))"):
            self.assertIsNone(reader.parse_where_constraints(clause), clause)

    def test_condition_insert_defaults_fill_omitted_keys_but_not_explicit_null(self):
        columns = ["SourceTypeOrReferenceId", "SourceGroup", "SourceEntry", "SourceId", "ElseGroup",
                   "ConditionTypeOrReference", "ConditionTarget", "ConditionValue1", "ConditionValue2", "ConditionValue3"]
        defaults = dict.fromkeys(columns, 0)
        rows = {}
        statement = "INSERT INTO conditions (`SourceTypeOrReferenceId`,`SourceGroup`,`SourceEntry`,`ConditionTypeOrReference`,`ConditionValue1`,`Comment`) VALUES (4,13970,11514,2,11511,'Arthas\\\' Tears - requires Cenarion Beacon')"
        self.assertEqual(reader.apply_multirow_insert(statement, "conditions", columns, rows, tuple(columns), column_defaults=defaults), 0)
        key = (4, 13970, 11514, 0, 0, 2, 0, 11511, 0, 0)
        self.assertIn(key, rows)
        self.assertEqual(rows[key]["Comment"], "Arthas' Tears - requires Cenarion Beacon")
        null_statement = "INSERT INTO conditions (`SourceTypeOrReferenceId`,`SourceId`) VALUES (4,NULL)"
        self.assertEqual(reader.apply_multirow_insert(null_statement, "conditions", columns, rows, tuple(columns), column_defaults=defaults), 1)
        self.assertEqual(len(rows), 1)
        self.assertTrue(all(value == 0 for value in defaults.values()))

    def test_table_replay_uses_opt_in_defaults_and_replaces_the_same_condition_key(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            base = directory / "data/sql/base/db_world"
            updates = directory / "data/sql/updates/db_world"
            base.mkdir(parents=True)
            updates.mkdir(parents=True)
            (base / "conditions.sql").write_text(
                "CREATE TABLE `conditions` (\n`SourceEntry` INT,\n`SourceId` INT,\n`ElseGroup` INT,\n`Comment` TEXT\n) ENGINE=InnoDB;\n"
                "INSERT INTO conditions VALUES (100,0,0,'old');", encoding="utf-8")
            (updates / "update.sql").write_text(
                "INSERT INTO conditions (`SourceEntry`,`ElseGroup`,`Comment`) VALUES (100,0,'replacement'),(100,1,'alternative');",
                encoding="utf-8")
            rows, skipped = reader.load_row_table(directory, "conditions", ("SourceEntry", "SourceId", "ElseGroup"),
                                                  column_defaults={"SourceId": 0})
            self.assertEqual(skipped, 0)
            self.assertEqual({(r["SourceId"], r["ElseGroup"], r["Comment"]) for r in rows},
                             {(0, 0, "replacement"), (0, 1, "alternative")})

    def test_partial_smartai_insert_uses_schema_key_defaults_in_both_replayers(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            base = directory / "data/sql/base/db_world"
            updates = directory / "data/sql/updates/db_world"
            base.mkdir(parents=True)
            updates.mkdir(parents=True)
            (base / "smart_scripts.sql").write_text(
                "CREATE TABLE `smart_scripts` (\n"
                "`entryorguid` int NOT NULL,\n"
                "`source_type` tinyint unsigned NOT NULL DEFAULT '0',\n"
                "`id` smallint unsigned NOT NULL DEFAULT '0',\n"
                "`link` smallint unsigned NOT NULL DEFAULT '0',\n"
                "`action_type` tinyint unsigned NOT NULL DEFAULT '0'\n) ENGINE=InnoDB;\n"
                "INSERT INTO smart_scripts VALUES (24484,0,0,0,53);", encoding="utf-8")
            (updates / "update.sql").write_text(
                "DELETE FROM smart_scripts WHERE entryorguid=24484 AND source_type=0;\n"
                "INSERT INTO smart_scripts (`entryorguid`,`source_type`,`id`,`action_type`) "
                "VALUES (24484,0,0,80),(24484,0,1,41);\n"
                "INSERT INTO smart_scripts (`entryorguid`,`id`,`link`,`action_type`) "
                "VALUES (24484,2,7,80),(24484,3,NULL,80);\n"
                "INSERT INTO smart_scripts (`id`,`action_type`) VALUES (4,80);", encoding="utf-8")
            keys = ("entryorguid", "source_type", "id", "link")
            for filtered in (False, True):
                with self.subTest(filtered=filtered):
                    if filtered:
                        rows, skipped = npc_reader.load_filtered_row_table(
                            directory, "smart_scripts", keys, lambda row: row["action_type"] == 80)
                    else:
                        rows, skipped = reader.load_row_table(directory, "smart_scripts", keys)
                    self.assertEqual(skipped, 2)  # Explicit NULL and missing entry remain invalid.
                    actual = {(r["entryorguid"], r["source_type"], r["id"], r["link"]): r["action_type"]
                              for r in rows}
                    expected = {(24484, 0, 0, 0): 80, (24484, 0, 2, 7): 80}
                    if not filtered:
                        expected[(24484, 0, 1, 0)] = 41
                    self.assertEqual(actual, expected)

    def test_key_defaults_follow_schema_values_and_ignore_comments_and_expressions(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "example.sql"
            path.write_text(
                "CREATE TABLE `example` (\n"
                "`id` int NOT NULL COMMENT 'DEFAULT 99',\n"
                "`source` tinyint unsigned NOT NULL DEFAULT 9,\n"
                "`offset` bigint NOT NULL DEFAULT '-12',\n"
                "`unknown` int DEFAULT NULL,\n"
                "`computed` int DEFAULT (1 + 2),\n"
                "`label` text DEFAULT '0'\n) ENGINE=InnoDB;", encoding="utf-8")
            defaults = reader.extract_sql_key_defaults(
                path, "example", ("id", "source", "offset", "unknown", "computed", "label"))
            self.assertEqual(defaults, {"source": 9, "offset": -12})


if __name__ == "__main__":
    unittest.main()
