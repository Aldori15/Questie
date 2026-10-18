"""Quest generation preserves helpers and baseline shape while refreshing source data."""
import contextlib
import copy
import io
import json
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import db_snapshot
import generate_acore_quest_base as exporter


def quest(**fields):
    reader = exporter.audit.metadata_reader
    row = {"s:" + field: exporter.audit.typed(reader.default_field_value(field)) for field in reader.FIELD_ORDER}
    row.update({"s:name": "Quest", "s:requiredLevel": 1, "s:questLevel": 2,
                "s:objectives": {}, "s:startedBy": {}, "s:finishedBy": {}, "s:zoneOrSort": 0})
    row.update({"s:" + field: value for field, value in fields.items()})
    return row


def typed(value):
    return exporter.audit.typed(value)


def bootstrap(before, source):
    return exporter.make_manifest(before, source, {}, "snapshot-sha", {"sourceRevision": "source-sha"})


class QuestBaseTests(unittest.TestCase):
    def test_exact_parity_retains_all_schema_slots_and_unsupported_helpers(self):
        source = {1: quest()}
        before = copy.deepcopy(source)
        for field in exporter.LEGACY_FIELDS:
            before[1]["s:" + field] = typed({2: "Display helper", 5: [10, 20]})
        manifest = bootstrap(before, source)
        result = exporter.build_records(source, manifest)
        self.assertEqual(result, before)
        self.assertEqual(set(result[1]), set(exporter.KEYS))
        self.assertTrue(exporter.compare_records(before, result)["exactParity"])

    def test_absent_default_fields_stay_absent_but_fresh_nondefaults_appear(self):
        source = {1: quest()}
        before = {1: {"s:name": "Quest", "s:requiredLevel": 1, "s:questLevel": 2}}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(sourceItemId=123, requiredSpell=-456, requiredItemConditions=typed([(-10, 2)]))}
        result = exporter.build_records(fresh, manifest)
        self.assertEqual(result[1]["s:sourceItemId"], 123)
        self.assertEqual(result[1]["s:requiredSpell"], -456)
        self.assertEqual(result[1]["s:requiredItemConditions"], typed([(-10, 2)]))

    def test_false_prerequisite_clears_remain_false_until_new_source_members_appear(self):
        source = {1: quest(preQuestGroup=typed([10]), preQuestSingle=typed([20]))}
        before = {1: quest(preQuestGroup=False, preQuestSingle=False)}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(preQuestGroup=typed([10, 30]), preQuestSingle=typed([20, 40]))}
        result = exporter.build_records(fresh, manifest)
        self.assertEqual(result[1]["s:preQuestGroup"], typed([30]))
        self.assertEqual(result[1]["s:preQuestSingle"], typed([40]))

    def test_source_lists_refresh_membership_keep_supplements_and_preserve_order(self):
        source = {1: quest(requiredSourceItems=typed([10, 20, 30]))}
        before = {1: quest(requiredSourceItems=typed([20, 10, 99]))}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(requiredSourceItems=typed([20, 30, 40]))}
        self.assertEqual(exporter.build_records(fresh, manifest)[1]["s:requiredSourceItems"], typed([20, 99, 40]))

    def test_sparse_duplicate_list_slots_remain_explicit(self):
        source = {1: quest(preQuestSingle=typed([10, 20]))}
        before = {1: quest(preQuestSingle={"n:2": 20, "n:7": 10, "n:9": 20})}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(preQuestSingle=typed([20, 30]))}
        self.assertEqual(exporter.build_records(fresh, manifest)[1]["s:preQuestSingle"], {"n:2": 20, "n:9": 20, "n:10": 30})

    def test_and_prerequisites_and_or_prerequisites_keep_separate_slots(self):
        source = {1: quest(preQuestGroup=typed([10, 20]), preQuestSingle=typed([30, 40]))}
        manifest = bootstrap(source, source)
        result = exporter.build_records(source, manifest)
        self.assertEqual(result[1]["s:preQuestGroup"], typed([10, 20]))
        self.assertEqual(result[1]["s:preQuestSingle"], typed([30, 40]))
        self.assertEqual(exporter.KEYS["s:preQuestGroup"], 12)
        self.assertEqual(exporter.KEYS["s:preQuestSingle"], 13)

    def test_signed_prerequisites_are_preserved_without_becoming_positive_ids(self):
        source = {4964: quest(preQuestGroup=typed([4976]))}
        before = {4964: quest(preQuestGroup=typed([4976, -4962]))}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {4964: quest(preQuestGroup=typed([4976, 5000]))}
        self.assertEqual(exporter.build_records(fresh, manifest)[4964]["s:preQuestGroup"], typed([4976, -4962, 5000]))

    def test_scripted_starter_exceptions_preserve_source_categories_and_emptiness(self):
        source = {1: quest(startedBy=typed({1: [14871]})), 2: quest(startedBy=typed({2: [187236]}))}
        before = {1: quest(startedBy={}), 2: quest(startedBy=typed({3: [46740]}))}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = copy.deepcopy(source)
        fresh[2]["s:startedBy"] = typed({1: [100], 2: [187236]})
        result = exporter.build_records(fresh, manifest)
        self.assertEqual(result[2]["s:startedBy"], typed({1: [100], 3: [46740]}))

    def test_reputation_defaults_false_values_and_fresh_rewards_are_distinct(self):
        source = {1: quest(reputationReward=typed([(81, 250)]))}
        before = {1: quest(reputationReward=typed([(81, 250)]), requiredMinRep=False)}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(reputationReward=typed([(81, -350)]), requiredMinRep=typed([72, 3000]))}
        self.assertEqual(exporter.build_records(fresh, manifest)[1]["s:reputationReward"], typed([(81, -350)]))
        self.assertEqual(exporter.build_records(fresh, manifest)[1]["s:requiredMinRep"], typed([72, 3000]))

    def test_conditional_name_race_and_zone_exceptions_refresh_when_source_changes(self):
        source = {1: quest(name="Source name", requiredRaces=0, zoneOrSort=-81)}
        before = {1: quest(name="Legacy name", requiredRaces=690, zoneOrSort=210)}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(name="New source name", requiredRaces=1101, zoneOrSort=12)}
        self.assertEqual(exporter.build_records(fresh, manifest), fresh)

    def test_omitted_nondefault_scalar_is_conditional(self):
        source = {1: quest(zoneOrSort=209)}
        before = copy.deepcopy(source)
        del before[1]["s:zoneOrSort"]
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(zoneOrSort=210)}
        self.assertEqual(exporter.build_records(fresh, manifest), fresh)

    def test_objective_helpers_retain_sparse_slots_and_block_changed_source_assumptions(self):
        source = {1: quest(objectives=typed({1: [[6]]}))}
        before = {1: quest(objectives=typed({1: [[6, "Creature helper", 3]], 5: [[[6, 7], 6, "Credit helper"]]}))}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = copy.deepcopy(source)
        fresh[1]["s:requiredLevel"] = 20
        self.assertEqual(exporter.build_records(fresh, manifest)[1]["s:objectives"], before[1]["s:objectives"])
        fresh[1]["s:objectives"] = typed({1: [[7]]})
        with self.assertRaisesRegex(ValueError, "Quest 1 objectives:.*source targets changed"):
            exporter.build_records(fresh, manifest)

    def test_source_objectives_without_compatibility_changes_refresh_directly(self):
        source = {1: quest(objectives=typed({1: [[6]]}))}
        manifest = bootstrap(source, source)
        fresh = {1: quest(objectives=typed({2: [[19017]], 3: [[182]]}))}
        self.assertEqual(exporter.build_records(fresh, manifest), fresh)

    def test_empty_objective_representation_can_refresh_to_new_objectives(self):
        source = {1: quest()}
        before = {1: quest(objectives=typed({1: {}}))}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        fresh = {1: quest(objectives=typed({3: [[182]]}))}
        self.assertEqual(exporter.build_records(fresh, manifest), fresh)

    def test_known_exclusions_new_templates_and_missing_template_supplement(self):
        source = {1: quest(), 2: quest(name="Excluded")}
        before = {1: quest(), 14330: {"s:name": "Supplemental quest", "s:triggerEnd": typed(["Helper"])}}
        manifest = bootstrap(before, source)
        fresh = {**source, 3: quest(name="New quest")}
        result = exporter.build_records(fresh, manifest)
        self.assertNotIn(2, result)
        self.assertEqual(result[3], fresh[3])
        self.assertEqual(result[14330], before[14330])
        with self.assertRaisesRegex(ValueError, "ID collision"):
            exporter.build_records({**source, 14330: quest()}, manifest)
        with self.assertRaisesRegex(ValueError, "removal"):
            exporter.build_records({}, manifest)

    def test_bad_scope_list_policies_and_output_paths_are_rejected(self):
        source = {1: quest()}
        manifest = bootstrap(source, source)
        invalid = copy.deepcopy(manifest)
        invalid["scope"]["1"] = True
        with self.assertRaisesRegex(ValueError, "field mask"):
            exporter.build_records(source, invalid)
        invalid = copy.deepcopy(manifest)
        invalid["lists"]["1"] = {"preQuestGroup": {"selected": {}, "supplements": [], "excluded": [False]}}
        with self.assertRaisesRegex(ValueError, "list policy"):
            exporter.build_records(source, invalid)
        for name in ("Database/AzerothCore/acoreObjectDB.lua", "tools/reports/../../Questie.lua"):
            with self.assertRaises(ValueError):
                exporter.local_path(name, "tools/reports", ".lua")

    def test_direct_generation_repeats_without_archive_snapshot_or_force(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            (directory / "tools/data").mkdir(parents=True)
            source = {1: quest()}
            manifest = bootstrap(source, source)
            (directory / "tools/data/acore_quest_compatibility.json").write_text(json.dumps(manifest), encoding="utf-8")
            saved = {"quests": {str(k): v for k, v in source.items()}, "diagnostics": {}, "tableCoverage": {}}
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit, "source_signature", return_value={}), \
                 patch.object(exporter.audit, "load_source", return_value=saved), \
                 contextlib.redirect_stdout(io.StringIO()):
                for _ in range(2):
                    self.assertEqual(exporter.main(["--spell-sql", str(directory / "spell.sql")]), 0)
            output = (directory / "Database/AzerothCore/acoreQuestDB.lua").read_text()
            self.assertIn('QuestieDB.questKeys', output)
            self.assertIn('QuestieDB.questData', output)
            self.assertIn('requiredItemConditions', output)
            report = json.loads((directory / "tools/reports/acore_quest_base_candidate.json").read_text())
            self.assertIsNone(report["comparison"])

    def test_diagnostics_stop_generation_before_replacing_existing_output(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            output = directory / "Database/AzerothCore/acoreQuestDB.lua"
            output.parent.mkdir(parents=True)
            output.write_text("unchanged", encoding="utf-8")
            saved = {"diagnostics": {"missingRequiredSourceItemSpellIds": [128]}, "tableCoverage": {}}
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit, "source_signature", return_value={}), \
                 patch.object(exporter.audit, "load_source", return_value=saved):
                with self.assertRaisesRegex(ValueError, "diagnostics"):
                    exporter.main(["--spell-sql", str(directory / "spell.sql")])
            self.assertEqual(output.read_text(), "unchanged")


if __name__ == "__main__":
    unittest.main()
