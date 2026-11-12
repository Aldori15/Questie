"""Trainer regeneration uses source spells and fails before replacing valid data."""
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import generate_acore_trainer_lists as generator


def fixtures():
    tables = {name: [] for name in generator.TABLES}
    npcs = {}
    return tables, npcs


def trainer(tables, npcs, entry, category, title="Unrelated title", trainer_type=2):
    skill = generator.CATEGORIES[category]
    spell = 196 if category == "WEAPON_MASTER" else 33388 if category == "RIDING" else 99999
    tables["creature_template"].append({"entry": entry, "npcflag": 80, "name": "Trainer " + str(entry)})
    tables["creature_default_trainer"].append({"CreatureId": entry, "TrainerId": entry})
    tables["trainer"].append({"Id": entry, "Type": trainer_type})
    tables["trainer_spell"].append({"TrainerId": entry, "SpellId": spell, "ReqSkillLine": skill or 0})
    npcs[entry] = {"name": "Trainer " + str(entry), "subName": title, "npcFlags": 80,
                   "spawns": {1: {1: [10, 20]}}}


class TrainerListsTests(unittest.TestCase):
    def test_source_additions_removals_and_category_changes(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 11, "MINING")
        before = generator.build_categories(tables, npcs)
        trainer(tables, npcs, 12, "FIRST_AID", "Medic")
        tables["trainer_spell"][0]["ReqSkillLine"] = 197
        after = generator.build_categories(tables, npcs)
        self.assertEqual(generator.changes(before, after, npcs), [
            {"npcId": 11, "name": "Trainer 11", "before": ["MINING"], "after": ["TAILORING"]},
            {"npcId": 12, "name": "Trainer 12", "before": [], "after": ["FIRST_AID"]},
        ])
        tables["creature_template"][0]["npcflag"] = 0
        removed = generator.build_categories(tables, npcs)
        self.assertEqual(removed["TAILORING"], [])
        self.assertEqual(generator.changes(after, removed, npcs)[0]["after"], [])

    def test_initial_ranks_riding_and_weapon_masters(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 11, "BLACKSMITHING")
        tables["trainer_spell"][0].update(SpellId=2020, ReqSkillLine=0)
        trainer(tables, npcs, 12, "RIDING", trainer_type=1)
        trainer(tables, npcs, 13, "WEAPON_MASTER")
        result = generator.build_categories(tables, npcs)
        self.assertEqual(result["BLACKSMITHING"], [11])
        self.assertEqual(result["RIDING"], [12])
        self.assertEqual(result["WEAPON_MASTER"], [13])

    def test_current_mapping_ignores_obsolete_legacy_trainer_evidence(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 11, "ENGINEERING")
        tables["npc_trainer"] = [{"ID": 11, "SpellID": -500},
                                  {"ID": 500, "SpellID": 23486, "ReqSkillLine": 186}]
        tables["trainer_spell"][0].update(SpellId=23486, ReqSkillLine=202)
        result = generator.build_categories(tables, npcs)
        self.assertEqual(result["ENGINEERING"], [11])
        self.assertEqual(result["MINING"], [])
        tables["creature_default_trainer"] = []
        self.assertFalse(any(generator.build_categories(tables, npcs).values()))

    def test_scripted_fishing_requires_current_gossip_lesson(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 10216, "FISHING")
        tables["creature_template"][0].update(npcflag=131, AIName="SmartAI", gossip_menu_id=2562)
        tables["gossip_menu_option"] = [{"MenuID": 2562, "OptionID": 1, "OptionType": 1}]
        lesson = {"entryorguid": 10216, "source_type": 0, "event_type": 62,
                  "event_param1": 2562, "event_param2": 1, "action_type": 134, "action_param1": 7733}
        tables["smart_scripts"] = [lesson]
        self.assertEqual(generator.build_categories(tables, npcs)["FISHING"], [10216])
        tables["gossip_menu_option"] = []
        self.assertEqual(generator.build_categories(tables, npcs)["FISHING"], [])
        tables["gossip_menu_option"] = [{"MenuID": 2562, "OptionID": 1, "OptionType": 1}]
        tables["smart_scripts"] = []
        self.assertEqual(generator.build_categories(tables, npcs)["FISHING"], [])
        tables["smart_scripts"] = [dict(lesson, action_param1=12345)]
        with self.assertRaisesRegex(ValueError, "unreviewed gossip lesson"):
            generator.build_categories(tables, npcs)

    def test_duplicate_spell_evidence_and_input_order_are_deterministic(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 12, "TAILORING", "Tailoring Trainer")
        trainer(tables, npcs, 11, "TAILORING", "Tailoring Trainer")
        tables["trainer_spell"].extend(copy.deepcopy(tables["trainer_spell"]))
        first = generator.build_categories(tables, npcs)
        for rows in tables.values():
            rows.reverse()
        second = generator.build_categories(tables, npcs)
        self.assertEqual(first["TAILORING"], [11, 12])
        self.assertEqual(generator.render(first), generator.render(second))

    def test_dormant_class_pet_and_unspawned_templates_are_excluded(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 11, "MINING", trainer_type=0)
        trainer(tables, npcs, 12, "MINING", trainer_type=3)
        trainer(tables, npcs, 13, "MINING")
        trainer(tables, npcs, 14, "MINING")
        tables["creature_template"][2]["npcflag"] = 4099
        npcs[14]["spawns"] = {}
        self.assertFalse(any(generator.build_categories(tables, npcs).values()))

    def test_unresolved_active_trainer_does_not_replace_output(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 11, "MINING")
        tables["trainer_spell"][0]["ReqSkillLine"] = 0
        with tempfile.TemporaryDirectory() as directory:
            output, report = Path(directory) / "trainers.lua", Path(directory) / "report.json"
            output.write_text("Existing valid data", encoding="utf-8")
            with patch.object(generator, "load_current_npcs", return_value=npcs), \
                    patch.object(generator, "load_sources", return_value=tables), \
                    contextlib.redirect_stdout(io.StringIO()):
                result = generator.main(["--acore-source", directory, "--output", str(output), "--report", str(report)])
            self.assertEqual(result, 1)
            self.assertEqual(output.read_text(encoding="utf-8"), "Existing valid data")
            self.assertIn("Unresolved active trainers", json.loads(report.read_text())["error"])

    def test_unsupported_sql_fails_closed(self):
        with patch.object(generator, "load_row_table", return_value=([], 1)):
            with self.assertRaisesRegex(ValueError, "unsupported SQL mutations"):
                generator.load_sources("unused")

    def test_unsupported_script_or_gossip_sql_fails_closed(self):
        for unsupported in ("smart_scripts", "gossip_menu_option"):
            with self.subTest(table=unsupported), \
                    patch.object(generator, "load_row_table", return_value=([], 0)), \
                    patch.object(generator, "load_filtered_row_table",
                                 side_effect=lambda source, name, keys, predicate: ([], int(name == unsupported))), \
                    contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError, unsupported + ": .*unsupported SQL"):
                    generator.load_sources("unused")

    def test_existing_serialized_npcs_and_typed_lists_are_read_without_lua(self):
        with tempfile.TemporaryDirectory() as directory:
            npc_path = Path(directory) / "npc.lua"
            npc_path.write_text('QuestieDB.npcKeys = {["name"]=1,["subName"]=2,["spawns"]=3,["npcFlags"]=4}\n'
                                'QuestieDB.npcData = {[=[return {[11]={"Named","Medic",{[1]={{10,20}}},80}}]=]}\n',
                                encoding="utf-8")
            npcs = generator.load_current_npcs(npc_path)
            self.assertTrue(generator.has_spawns(npcs[11]))
            categories = {category: [] for category in generator.CATEGORIES}
            categories["FIRST_AID"] = [11]
            path = Path(directory) / "trainers.lua"
            path.write_text(generator.render(categories), encoding="utf-8")
            self.assertEqual(generator.read_previous(path), categories)

    def test_source_trainer_promotion_does_not_depend_on_old_addon_flags(self):
        tables, npcs = fixtures()
        trainer(tables, npcs, 11, "MINING")
        npcs[11]["npcFlags"] = 0
        def read_filtered(source, name, keys, predicate):
            if name == "creature_template":
                self.assertTrue(predicate(tables[name][0]))
                return tables[name], 0
            return [], 0
        with patch.object(generator, "load_row_table", side_effect=lambda source, name, keys: (tables[name], 0)), \
                patch.object(generator, "load_filtered_row_table", side_effect=read_filtered), \
                contextlib.redirect_stdout(io.StringIO()):
            loaded = generator.load_sources("unused", npcs)
        self.assertEqual(generator.build_categories(loaded, npcs)["MINING"], [11])


if __name__ == "__main__":
    unittest.main()
