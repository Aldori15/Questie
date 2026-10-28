"""Relation audits distinguish questgiver capabilities from orphan references."""
from contextlib import ExitStack, contextmanager, redirect_stdout
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import validate_acore_quest_relations as validator


def relation_state(**tables):
    state = {table: set() for table in validator.TARGET_TABLES}
    state.update(tables)
    return state


@contextmanager
def source_fixture(quests, items=(), state=None, module_ids=(), disabled_ids=()):
    def load_table(root, table, override=None, **kwargs):
        if table == "quest_template":
            return {quest_id: {"ID": quest_id} for quest_id in quests}
        if table == "item_template":
            return {row["entry"]: row for row in items}
        raise AssertionError(f"Unexpected source table: {table}")

    with ExitStack() as stack:
        stack.enter_context(patch.object(validator, "load_module_created_quest_ids", return_value=set(module_ids)))
        stack.enter_context(patch.object(validator, "load_disabled_quest_ids", return_value=set(disabled_ids)))
        stack.enter_context(patch.object(validator, "load_core_relation_state",
                                        return_value=copy.deepcopy(state or relation_state())))
        stack.enter_context(patch.object(validator, "remove_excluded_module_relations"))
        loader = stack.enter_context(patch.object(validator, "load_acore_sql_table", side_effect=load_table))
        yield loader


class QuestRelationValidationTests(unittest.TestCase):
    def test_source_givers_survive_script_and_reward_item_assumptions(self):
        state = relation_state(creature_queststarter={(14871, 7946)},
                               creature_questender={(14871, 7946)},
                               gameobject_queststarter={(187236, 13966)},
                               gameobject_questender={(187236, 13966)})
        with source_fixture({7946, 13966}, [{"entry": 46740, "startquest": 0}], state):
            result = validator.load_acore_relations(Path("source"))
        self.assertEqual(result[7946]["start"]["creature"], {14871})
        self.assertEqual(result[13966]["start"]["object"], {187236})
        self.assertEqual(result[13966]["end"]["object"], {187236})
        self.assertEqual(result[13966]["start"]["item"], set())

    def test_orphan_item_and_entity_references_are_reported_without_inventing_quests(self):
        state = relation_state(creature_queststarter={(7, 999)}, gameobject_questender={(8, 999)})
        diagnostics = {}
        with source_fixture({1}, [{"entry": 38567, "startquest": 14330}], state):
            result = validator.load_acore_relations(Path("source"), diagnostics=diagnostics)
        self.assertEqual(result, {})
        self.assertEqual(diagnostics["orphanRelations"], [
            {"table": "creature_queststarter", "sourceId": 7, "questId": 999,
             "reason": "missingQuestTemplate"},
            {"table": "gameobject_questender", "sourceId": 8, "questId": 999,
             "reason": "missingQuestTemplate"},
            {"table": "item_template", "sourceId": 38567, "questId": 14330,
             "reason": "missingQuestTemplate"},
        ])

    def test_disabled_and_module_quests_remain_excluded_without_orphan_warnings(self):
        state = relation_state(creature_queststarter={(7, 2), (8, 3), (9, 1)})
        diagnostics = {}
        with source_fixture({1}, [{"entry": 10, "startquest": 2}], state,
                            module_ids={2}, disabled_ids={3}):
            result = validator.load_acore_relations(Path("source"), diagnostics=diagnostics)
        self.assertEqual(set(result), {1})
        self.assertEqual(diagnostics["orphanRelations"], [])

    def test_new_valid_item_starter_still_produces_a_missing_link(self):
        with source_fixture({20}, [{"entry": 10, "startquest": 20}]):
            expected = validator.load_acore_relations(Path("source"))
        self.assertEqual(validator.compare_relations(expected, {}), [{
            "questId": 20, "relationType": "start", "sourceType": "item",
            "missingInQuestie": [10], "extraInQuestie": [],
        }])

    def test_quest_export_selects_template_scope_and_preserves_sibling_item_input(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            quest_export = root / "quest_template.sql"
            quest_export.touch()
            item_export = root / "item_template.sql"
            item_export.touch()
            diagnostics = {}
            with source_fixture({20}, [{"entry": 10, "startquest": 20},
                                       {"entry": 11, "startquest": 1}]) as loader:
                result = validator.load_acore_relations(Path("source"), quest_export, diagnostics)
            self.assertEqual(set(result), {20})
            self.assertEqual(loader.call_args_list[0].args,
                             (Path("source"), "quest_template", quest_export))
            self.assertEqual(loader.call_args_list[1].args,
                             (Path("source"), "item_template", item_export))
            self.assertEqual(diagnostics["orphanRelations"][0]["questId"], 1)

    def test_complete_relation_exports_are_used_with_the_exported_quest_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            quest_export = root / "quest_template.sql"
            quest_export.touch()
            for table in validator.RELATION_EXPORT_FILES:
                (root / f"{table}.sql").touch()

            def apply_export(path, state):
                if path.stem == "creature_queststarter":
                    state[path.stem].add((7, 20))

            with source_fixture({20}), patch.object(validator, "apply_sql_file", side_effect=apply_export) as apply:
                result = validator.load_acore_relations(Path("source"), quest_export)
            self.assertEqual(result[20]["start"]["creature"], {7})
            self.assertEqual(apply.call_count, len(validator.RELATION_EXPORT_FILES))

    def test_cli_reports_orphans_and_returns_zero_when_base_links_match(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            arguments = ["validator", "--acore-source", "source", "--report", str(report)]
            with source_fixture({1}, [{"entry": 38567, "startquest": 14330}]), \
                    patch.object(validator, "load_questie_relations", return_value={}), \
                    patch("sys.argv", arguments), redirect_stdout(io.StringIO()):
                result = validator.main()
            payload = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual(result, 0)
        self.assertEqual(payload["summary"]["total"], 0)
        self.assertEqual(payload["sourceDiagnostics"]["orphanRelations"][0]["questId"], 14330)

    def test_cli_returns_one_for_real_missing_links(self):
        with source_fixture({20}, [{"entry": 10, "startquest": 20}]), \
                patch.object(validator, "load_questie_relations", return_value={}), \
                patch("sys.argv", ["validator", "--acore-source", "source"]), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(validator.main(), 1)


if __name__ == "__main__":
    unittest.main()
