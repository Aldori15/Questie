"""Translation audits retain real consumers and never delete addon sources."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from _test_paths import ADDON_ROOT
from generate_acore_full_base import lua_quote, lua_value
from acore_scripted_geometry import typed
import report_extra_objective_localization as reporter


class ExtraObjectiveLocalizationTests(unittest.TestCase):
    def test_consolidated_dictionary_is_audited_without_expansion_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            dictionary = self.dictionary(root, "Legacy", ["Flight hint"])
            dictionary.replace(root / "Localization/Translations/ExtraObjectives.lua")
            self.base(root, ["Flight hint"])
            report = reporter.audit(root)
            self.assertEqual(report["summary"]["usedKeys"], 1)
            self.assertEqual(report["summary"]["unusedCandidates"], 0)
            self.assertEqual(report["used"][0]["definitions"][0]["file"],
                             "Localization/Translations/ExtraObjectives.lua")

    def write(self, root, path, text):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return target

    def dictionary(self, root, name, keys):
        entries = [f"    [{lua_quote(key)}] = {{[\"enUS\"] = true}}," for key in keys]
        return self.write(root, f"Localization/Translations/ExtraObjectives/{name}.lua",
                          "local objectiveLocales = {\n" + "\n".join(entries) + "\n}\n")

    def base(self, root, labels, key=29):
        self.write(root, "Database/questDB.lua", f"QuestieDB.questKeys = {{['extraObjectives'] = {key}}}\n")
        row = typed({1: "Quest", key: [{2: 3, 3: label, 4: 0, 5: [["monster", 20235]]} for label in labels]})
        return self.write(root, "Database/AzerothCore/acoreQuestDB.lua",
                          f'QuestieDB.questKeys = {{["extraObjectives"] = {key}}}\n'
                          + "QuestieDB.questData = {\n[===[return {\n[10382]=" + lua_value(row)
                          + ",\n}]===],\n}\nQuestieDB.footer = {[1] = \"Footer only\"}\n")

    def test_lua_literals_decode_quotes_bytes_and_comments_without_execution(self):
        source = r'''-- "Comment only"
local first = "Say \"hello\""
--[=[ "Long comment" ]=]
local second = 'Path\\name'
local third = "caf\195\169"
local fourth = [=[
Long text]=]
'''
        tokens = list(reporter.lua_strings(source))
        self.assertEqual([token["value"] for token in tokens],
                         ['Say "hello"', "Path\\name", "café", "Long text"])
        self.assertEqual([token["line"] for token in tokens], [2, 4, 5, 6])
        with self.assertRaisesRegex(ValueError, "exceeds 255"):
            list(reporter.lua_strings(r'"\256"'))
        with self.assertRaisesRegex(ValueError, "Unterminated Lua"):
            list(reporter.lua_strings('--[=[unterminated'))

    def test_generated_guides_runtime_producers_and_shared_definitions_are_retained(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.dictionary(root, "TbcObjectives", ["Speak with Gryphoneer Windbellow", "Runtime hint", "Unused hint"])
            self.dictionary(root, "ClassicObjectives", ["Runtime hint"])
            self.base(root, ["Speak with Gryphoneer Windbellow"])
            self.write(root, "Database/Corrections/QuestRuntimeCorrections.lua",
                       'questTooltipHints[1] = "Runtime hint"\n-- "Unused hint"\n')
            report = reporter.audit(root)
            used = {entry["key"]: entry for entry in report["used"]}
            self.assertEqual(used["Speak with Gryphoneer Windbellow"]["usedByGeneratedGuides"],
                             [{"questId": 10382, "guideIndex": 1}])
            self.assertEqual(used["Runtime hint"]["usedByRuntimeLiterals"],
                             [{"file": "Database/Corrections/QuestRuntimeCorrections.lua", "line": 1}])
            self.assertEqual(len(used["Runtime hint"]["definitions"]), 2)
            self.assertEqual([entry["key"] for entry in report["unusedCandidates"]], ["Unused hint"])
            self.assertEqual(report["summary"]["translationDefinitions"], 4)
            self.assertTrue(report["reviewRequired"])
            self.assertTrue(any("dynamic" in note for note in report["limitations"]))

    def test_development_files_localized_lookups_and_footer_text_are_not_consumers(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            keys = ["Tools only", "Tests only", "Reports only", "Lookup only", "Footer only"]
            self.dictionary(root, "TbcObjectives", keys)
            self.base(root, [])
            for path, key in [("tools/script.py", keys[0]), ("tools/tests/fixture.lua", keys[1]),
                              ("tools/reports/old.lua", keys[2]), ("Localization/lookups/TBC/lookupQuests/frFR.lua", keys[3])]:
                self.write(root, path, lua_quote(key))
            report = reporter.audit(root)
            self.assertEqual({entry["key"] for entry in report["unusedCandidates"]}, set(keys))
            self.assertEqual(report["used"], [])

    def test_escaped_dictionary_keys_match_exact_decoded_runtime_literals(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            key = 'Speak to the NPC and select "Take the letter"'
            self.dictionary(root, "WotlkObjectives", [key, "Prefix"])
            self.base(root, [], key=5)
            self.write(root, "Modules/Tooltips.lua", 'local text = ' + lua_quote(key) + '\nlocal other = "Prefix with more text"\n')
            report = reporter.audit(root)
            self.assertEqual([entry["key"] for entry in report["used"]], [key])
            self.assertEqual(report["unusedCandidates"][0]["key"], "Prefix")
            self.assertEqual(report["used"][0]["definitions"][0]["line"], 2)

    def test_generated_schema_index_is_used_instead_of_legacy_schema_comments(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.dictionary(root, "TbcObjectives", ["Flight hint"])
            self.base(root, ["Flight hint"], key=5)
            self.write(root, "Database/questDB.lua",
                       "QuestieDB.questKeys = {['startedBy'] = 2, -- {{NPC IDs}}\n['extraObjectives'] = 29}\n")
            report = reporter.audit(root)
            self.assertEqual(report["summary"]["usedKeys"], 1)
            self.assertEqual(report["used"][0]["usedByGeneratedGuides"][0]["questId"], 10382)

    def test_cli_writes_only_the_requested_report_and_preserves_sources(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.dictionary(root, "TbcObjectives", ["Unused hint"])
            self.base(root, [])
            before = {p.relative_to(root): hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob("*") if p.is_file()}
            with contextlib.redirect_stdout(io.StringIO()):
                reporter.main(["--addon-root", str(root), "--report", "tools/reports/review.json"])
            result = root / "tools/reports/review.json"
            self.assertEqual(json.loads(result.read_text())["summary"]["unusedCandidates"], 1)
            self.assertEqual(set(p.relative_to(root) for p in root.rglob("*") if p.is_file()),
                             set(before) | {Path("tools/reports/review.json")})
            for path, digest in before.items():
                self.assertEqual(hashlib.sha256((root / path).read_bytes()).hexdigest(), digest)

            for output in ("Database/overwrite.json", "tools/reports/../../outside.json", "tools/reports/report.lua"):
                with self.assertRaisesRegex(ValueError, "under tools/reports"):
                    reporter.main(["--addon-root", str(root), "--report", output])

    def test_unsupported_base_expressions_fail_instead_of_executing_lua(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.dictionary(root, "TbcObjectives", ["Hint"])
            base = self.base(root, [])
            base.write_text('QuestieDB.questKeys = {["extraObjectives"] = 29}\n'
                            'QuestieDB.questData = {[===[return {[10382] = '
                            '{[29] = os.execute("do not execute")}}]===]}', encoding="utf-8")
            with self.assertRaises(ValueError):
                reporter.audit(root)


if __name__ == "__main__":
    unittest.main()
