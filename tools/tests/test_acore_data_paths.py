"""Keep generated server data discoverable by both the addon and maintenance tools."""
import argparse
import importlib
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

from _test_paths import ADDON_ROOT


DATA_DIR = Path("Database/AzerothCore")
DATA_FILES = [
    "AzerothCoreReputationRates.lua",
    "AzerothCoreQuestAvailabilityConditions.lua",
]


class ParserCaptured(Exception):
    pass


def parser_defaults(module_name):
    module = importlib.import_module(module_name)
    defaults = {}

    # Inspect defaults without running SQL readers or writing generated data.
    # get_default avoids validating required arguments such as --acore-source.
    def capture_defaults(parser, *args, **kwargs):
        for name in ("output", "quest_db", "npc_db", "object_db", "item_db", "quest_fixes", "npc_fixes", "object_fixes", "item_fixes"):
            defaults[name] = parser.get_default(name)
        raise ParserCaptured

    with patch.object(argparse.ArgumentParser, "parse_args", capture_defaults):
        try:
            module.main()
        except ParserCaptured:
            return defaults
    raise AssertionError(f"{module_name} did not parse its command line")


class AcoreDataPathTests(unittest.TestCase):
    def test_manifest_preserves_early_registration_order(self):
        entries = [line.strip().replace("\\", "/")
                   for line in (ADDON_ROOT / "Questie-335.toc").read_text(encoding="utf-8-sig").splitlines()
                   if line.strip() and not line.lstrip().startswith("#")]
        manifest = (DATA_DIR / "AzerothCore.xml").as_posix()
        self.assertEqual(entries.count(manifest), 1)
        self.assertEqual(entries.index(manifest), entries.index("Compat/Compat.xml") + 1)
        self.assertLess(entries.index(manifest), entries.index("Database/QuestieDB.lua"))
        self.assertLess(entries.index(manifest), entries.index("Database/Corrections/QuestieCorrections.lua"))
        scripts = [node.attrib["file"] for node in ET.parse(ADDON_ROOT / manifest).getroot()
                   if "file" in node.attrib]
        self.assertEqual(scripts, DATA_FILES[:2])
        # Complete bases are the only shared database sources.
        for kind in ("Item", "Npc", "Object", "Quest"):
            base = f"Database/AzerothCore/acore{kind}DB.lua"
            self.assertIn(base, entries)
            self.assertTrue((ADDON_ROOT / base).is_file())
        for original in ("Item", "Npc", "Object", "Quest"):
            self.assertNotIn(f"Database/AzerothCore/AzerothCore{original}Corrections.lua",
                             [f"Database/AzerothCore/{name}" for name in scripts])
        compat_files = [node.attrib["file"] for node in ET.parse(ADDON_ROOT / "Compat/Compat.xml").getroot()
                        if "file" in node.attrib]
        self.assertFalse(set(DATA_FILES).intersection(compat_files))
        for name in DATA_FILES:
            self.assertTrue((ADDON_ROOT / DATA_DIR / name).is_file(), name)
            self.assertFalse((ADDON_ROOT / "Compat" / name).exists(), name)

    def test_generator_defaults_write_the_loaded_files(self):
        for generator, filename in (
            ("reputation_rates", DATA_FILES[0]),
            ("quest_availability_conditions", DATA_FILES[1]),
        ):
            with self.subTest(generator=generator):
                self.assertEqual(Path(parser_defaults("generate_acore_" + generator)["output"]),
                                 DATA_DIR / filename)

    def test_maintenance_readers_use_complete_bases_without_correction_layers(self):
        for module_name, kinds in (
            ("validate_acore_quest_metadata", ("quest",)),
            ("validate_acore_quest_relations", ("quest",)),
            ("validate_item_start_links", ("quest", "item")),
            ("validate_reverse_quest_links", ("quest", "npc", "object")),
            ("generate_acore_creature_drops", ("item",)),
        ):
            defaults = parser_defaults(module_name)
            for kind in kinds:
                filename = {"quest": "Quest", "npc": "Npc", "object": "Object", "item": "Item"}[kind]
                self.assertEqual(Path(defaults[kind + "_db"]), DATA_DIR / ("acore" + filename + "DB.lua"))
                if defaults.get(kind + "_fixes") is not None:
                    self.assertEqual(defaults[kind + "_fixes"], [])

    def test_retired_database_files_are_absent(self):
        self.assertFalse((ADDON_ROOT / "Database/Wotlk").exists())
        for expansion in ("classic", "tbc", "wotlk"):
            for kind in ("Quest", "NPC", "Object", "Item"):
                self.assertFalse((ADDON_ROOT / "Database/Corrections" / (expansion + kind + "Fixes.lua")).exists())
        for kind in ("Quest", "NPC", "Object", "Item"):
            self.assertFalse((ADDON_ROOT / DATA_DIR / ("AzerothCore" + kind + "Corrections.lua")).exists())

    def test_shared_source_helpers_cannot_write_retired_correction_outputs(self):
        for kind in ("item", "npc", "object"):
            with self.subTest(kind=kind), self.assertRaisesRegex(SystemExit, "generate_acore_" + kind + "_base.py"):
                importlib.import_module("generate_acore_" + kind + "_corrections").main()


if __name__ == "__main__":
    unittest.main()
