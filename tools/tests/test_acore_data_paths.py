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
    "AzerothCoreQuestCorrections.lua",
    "AzerothCoreItemCorrections.lua",
    "AzerothCoreNPCCorrections.lua",
    "AzerothCoreObjectCorrections.lua",
]


class ParserCaptured(Exception):
    pass


def parser_defaults(module_name):
    module = importlib.import_module(module_name)
    defaults = {}

    # Inspect defaults without running SQL readers or writing generated data.
    # get_default avoids validating required arguments such as --acore-source.
    def capture_defaults(parser, *args, **kwargs):
        for name in ("output", "item_corrections"):
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
        self.assertEqual(scripts, DATA_FILES)
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
            ("quest_corrections", DATA_FILES[2]),
            ("item_corrections", DATA_FILES[3]),
            ("npc_corrections", DATA_FILES[4]),
            ("object_corrections", DATA_FILES[5]),
        ):
            with self.subTest(generator=generator):
                self.assertEqual(Path(parser_defaults("generate_acore_" + generator)["output"]),
                                 DATA_DIR / filename)

    def test_maintenance_readers_follow_the_move(self):
        for module_name in ("convert_required_races", "convert_special_flags"):
            self.assertEqual(importlib.import_module(module_name).DEFAULT_SOURCE,
                             ADDON_ROOT / DATA_DIR / DATA_FILES[2])
        report = importlib.import_module("report_acore_custom_ids")
        for path in report.DEFAULT_ACORE_CORRECTIONS.values():
            self.assertEqual(path.parent, ADDON_ROOT / DATA_DIR)
            self.assertTrue(path.is_file())
        reverse_links = importlib.import_module("validate_reverse_quest_links")
        for path in reverse_links.ACORE_QUEST_FIXES + reverse_links.ACORE_NPC_FIXES + reverse_links.ACORE_OBJECT_FIXES:
            self.assertEqual(Path(path).parent, DATA_DIR)
            self.assertTrue((ADDON_ROOT / path).is_file())
        self.assertEqual(Path(parser_defaults("generate_acore_object_identity_corrections")["item_corrections"]),
                         DATA_DIR / DATA_FILES[3])


if __name__ == "__main__":
    unittest.main()
