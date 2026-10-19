"""Source item export must preserve explicit compatibility without legacy inputs."""
import copy
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import db_snapshot
import generate_acore_item_base as exporter


def item(**fields):
    return {"name": "Item", "itemLevel": 1, "requiredLevel": 0, "ammoType": 0,
            "class": 0, "subClass": 0, **fields}


def bootstrap(items, source):
    return exporter.make_manifest(items, source, {"git": None}, "baseline-sha",
                                  {"sourceRevision": "source-commit", "spellExport": {"sha256": "spell-sha"}})


class ItemBaseTests(unittest.TestCase):
    def test_salvage_selections_refresh_from_source_including_new_neutral_objects(self):
        source = {25911: item(objectDrops=[182799, 182936])}
        records = {key: exporter.source_record(value) for key, value in source.items()}
        teams = {"182799": 1, "182936": 2}
        result = exporter.build_faction_selections(source, records, teams)
        self.assertEqual(result["Alliance"][25911]["s:objectDrops"], {"n:1": 182799})
        self.assertEqual(result["Horde"][25911]["s:objectDrops"], {"n:1": 182936})
        source[25911]["objectDrops"] = [182936, 900001]
        teams["900001"] = 3
        result = exporter.build_faction_selections(source, records, teams)
        self.assertEqual(result["Alliance"][25911]["s:objectDrops"], {"n:1": 900001})
        self.assertEqual(result["Horde"][25911]["s:objectDrops"], {"n:1": 182936, "n:2": 900001})
        output = io.StringIO()
        exporter.write_candidate_stream(output, records, result)
        self.assertIn("QuestieDB.itemFactionSelections", output.getvalue())
        self.assertEqual(len(output.getvalue().encode()), exporter.candidate_size(records, result))
        with self.assertRaisesRegex(ValueError, "missing faction access"):
            exporter.build_faction_selections(source, records, {})

    def test_name_compatibility_preserves_spelling_and_guards_future_source_changes(self):
        source = {1: item(name="Prototype 01")}
        before = {1: exporter.source_record(item(name="Prototype 1"))}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest)[0], before)
        with self.assertRaisesRegex(ValueError, "Source name changed"):
            exporter.build_records({1: item(name="Renamed Prototype")}, manifest)

    def test_bootstrap_keeps_only_compatibility_data_and_explicit_scope(self):
        source = {1: item(npcDrops=[100], startQuest=10), 2: item(npcDrops=[300]), 3: item()}
        before = {1: exporter.source_record(source[1]), 2: {"s:npcDrops": {"n:1": 999}}}
        before[1]["s:class"] = 12
        before[1]["s:npcDrops"] = {"n:1": 100, "n:2": 200}
        manifest = bootstrap(before, source)
        self.assertEqual(manifest["itemIds"], [1, 2])
        self.assertEqual(manifest["entries"]["1"]["addSources"], {"npcDrops": [200]})
        self.assertEqual(manifest["entries"]["1"]["classOverride"], {"value": 12, "expectedSource": 0})
        self.assertEqual(manifest["partialRecords"]["2"], before[2])
        after, _ = exporter.build_records(source, manifest)
        self.assertEqual(exporter.compare_candidate(before, after)["unexpectedChanges"], [])
        self.assertEqual(after[2], before[2])

    def test_new_source_relationships_are_filtered_while_compatibility_links_are_retained(self):
        source = {1: item(npcDrops=[100])}
        before = {1: exporter.source_record(item(npcDrops=[200]))}
        manifest = bootstrap(before, source)
        after, _ = exporter.build_records(source, manifest)
        comparison = exporter.compare_candidate(before, after)
        self.assertEqual(set(after[1]["s:npcDrops"].values()), {200})
        self.assertEqual(comparison["counts"], {})
        self.assertTrue(comparison["exactParity"])
        self.assertEqual(comparison["unexpectedChanges"], [])

    def test_missing_template_and_changed_source_class_require_review(self):
        source = {1: item()}
        before = {1: exporter.source_record(item(**{"class": 12}))}
        manifest = bootstrap(before, source)
        with self.assertRaisesRegex(ValueError, "no AzerothCore template"):
            exporter.build_records({}, manifest)
        with self.assertRaisesRegex(ValueError, "Source class changed"):
            exporter.build_records({1: item(**{"class": 4})}, manifest)

    def test_newly_direct_compatibility_links_are_deduplicated_and_reported(self):
        before = {1: exporter.source_record(item(npcDrops=[200]))}
        manifest = bootstrap(before, {1: item()})
        after, redundant = exporter.build_records({1: item(npcDrops=[200])}, manifest)
        self.assertEqual(after[1]["s:npcDrops"], {"n:1": 200})
        self.assertEqual(redundant, [{"itemId": 1, "field": "npcDrops", "sourceIds": [200]}])

    def test_manifest_rejects_ambiguous_ids_and_unsupported_source_fields(self):
        manifest = bootstrap({1: exporter.source_record(item())}, {1: item()})
        invalid = copy.deepcopy(manifest)
        invalid["itemIds"] = [True]
        with self.assertRaises(ValueError):
            exporter.validate_manifest(invalid)
        invalid = copy.deepcopy(manifest)
        invalid["entries"]["1"] = {"reason": "fixture", "addSources": {"vendors": [100]}}
        with self.assertRaisesRegex(ValueError, "Invalid additive"):
            exporter.validate_manifest(invalid)
        invalid["entries"] = {"2": {"reason": "outside scope"}}
        with self.assertRaises(ValueError):
            exporter.validate_manifest(invalid)

    def test_bootstrap_refuses_unsupported_spell_values_and_source_scalar_gaps(self):
        before = {1: exporter.source_record(item())}
        before[1]["s:teachesSpell"] = 123
        with self.assertRaisesRegex(ValueError, "teachesSpell"):
            bootstrap(before, {1: item()})
        raw = item()
        del raw["class"]
        with self.assertRaisesRegex(ValueError, "required field class"):
            exporter.source_record(raw)

    def test_candidate_comparison_distinguishes_additions_removals_and_scalar_changes(self):
        before = {1: {"s:class": 12, "s:npcDrops": {"n:1": 100}, "s:objectDrops": {}}}
        after = {1: {"s:class": 0, "s:npcDrops": {"n:1": 200}}}
        result = exporter.compare_candidate(before, after)
        self.assertEqual(result["counts"], {"sourceRemovals": 1, "representationOnly": 1, "valueChange": 1})
        self.assertEqual(len(result["unexpectedChanges"]), 3)
        self.assertFalse(result["exactParity"])
        with self.assertRaisesRegex(ValueError, "scope differs"):
            exporter.compare_candidate(before, {})

    def test_cli_bootstraps_once_then_generates_without_reading_a_snapshot(self):
        source = {1: item(npcDrops=[100]), 2: item()}
        before = {1: exporter.source_record(item(npcDrops=[200]))}
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            snapshot = directory / "baseline.jsonl"
            snapshot.write_text("fixture snapshot", encoding="utf-8")
            spell = directory / "spell.sql"
            spell.write_text("fixture spell", encoding="utf-8")
            signature = {"sourceRevision": "commit", "spellExport": {"sha256": "spell-sha"}}
            saved = {"items": {str(k): v for k, v in source.items()}, "templateIds": list(source)}
            arguments = ["--acore-source", str(directory), "--spell-sql", str(spell)]
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit, "source_signature", return_value=signature), \
                 patch.object(exporter.audit, "load_source", return_value=saved), \
                 patch.object(exporter.audit, "local_output", return_value=directory / "cache.json"):
                with patch.object(exporter.audit, "read_items", return_value=(before, list(exporter.FIELDS), {}, {"sources": {}})):
                    self.assertEqual(exporter.main(["bootstrap", "--snapshot", str(snapshot), *arguments]), 0)
                with patch.object(exporter.audit, "read_items", side_effect=AssertionError("Snapshot dependency")):
                    self.assertEqual(exporter.main(["generate", *arguments]), 0)
                report = json.loads((directory / "tools/reports/acore_item_base_candidate.json").read_text())
                self.assertEqual(report["items"], 1)
                self.assertEqual(report["excludedSourceItemIds"], [2])
                self.assertIsNone(report["comparison"])
                # Normal generation writes production directly and can be rerun.
                output = directory / "Database/AzerothCore/acoreItemDB.lua"
                self.assertTrue(output.exists())
                self.assertEqual(exporter.main(arguments), 0)

    def test_only_the_intended_production_database_path_is_allowed(self):
        self.assertEqual(exporter.output_path(Path("Database/AzerothCore/acoreItemDB.lua"), "tools/reports", ".lua"),
                         (ADDON_ROOT / "Database/AzerothCore/acoreItemDB.lua").resolve())
        with self.assertRaises(ValueError):
            exporter.output_path(Path("Database/AzerothCore/acoreNpcDB.lua"), "tools/reports", ".lua")

    def test_parity_keeps_field_presence_order_duplicates_and_sparse_source_keys(self):
        source = {1: item(npcDrops=[100, 200, 300], vendors=[400])}
        before = {1: exporter.source_record(source[1])}
        before[1]["s:npcDrops"] = {"n:1": 200, "n:3": 100, "n:7": 200}
        before[1]["s:vendors"] = {}
        before[1]["s:flags"] = 0
        before[1].pop("s:ammoType")
        manifest = bootstrap(before, source)
        after, _ = exporter.build_records(source, manifest)
        self.assertEqual(after, before)
        self.assertTrue(exporter.compare_candidate(before, after)["exactParity"])

    def test_new_sources_do_not_populate_fields_absent_from_the_baseline(self):
        source = {1: item()}
        before = {1: exporter.source_record(source[1])}
        manifest = bootstrap(before, source)
        changed = {1: item(npcDrops=list(range(1, 10001)), objectDrops=[100], itemDrops=[200], vendors=[300])}
        after, _ = exporter.build_records(changed, manifest)
        self.assertEqual(after, before)
        self.assertEqual(exporter.candidate_size(after), exporter.candidate_size(before))

    def test_removed_selected_source_requires_review_instead_of_silent_loss(self):
        source = {1: item(npcDrops=[100])}
        manifest = bootstrap({1: exporter.source_record(source[1])}, source)
        with self.assertRaisesRegex(ValueError, "Selected npcDrops sources changed"):
            exporter.build_records({1: item()}, manifest)

    def test_changed_value_cannot_be_hidden_by_a_representation_override(self):
        source = {1: item()}
        before = {1: exporter.source_record(source[1])}
        before[1]["s:flags"] = 0
        manifest = bootstrap(before, source)
        with self.assertRaisesRegex(ValueError, "Source value changed"):
            exporter.build_records({1: item(flags=16)}, manifest)

    def test_version_one_expansion_manifest_is_rejected(self):
        manifest = bootstrap({1: exporter.source_record(item())}, {1: item()})
        manifest["version"] = 1
        with self.assertRaisesRegex(ValueError, "Unsupported item compatibility"):
            exporter.build_records({1: item()}, manifest)

    def test_source_link_and_serialized_size_budgets_reject_expansion(self):
        source = {1: item(npcDrops=[100, 200])}
        before = {1: exporter.source_record(item(npcDrops=[100]))}
        manifest = bootstrap(before, source)
        manifest["sourceSelections"]["1"]["npcDrops"] = [100, 200]
        with self.assertRaisesRegex(ValueError, "Source-link budget exceeded"):
            exporter.build_records(source, manifest)
        with self.assertRaisesRegex(ValueError, "baseline size budget"):
            exporter.enforce_size(manifest["limits"]["maxOutputBytes"] + 1, manifest)

    def test_current_source_updates_without_old_models_or_archives(self):
        old = {1: item(npcDrops=[10, 20], vendors=[30], itemLevel=1)}
        before = {1: exporter.source_record(item(npcDrops=[10], vendors=[30], itemLevel=1))}
        manifest = exporter.upgrade_manifest(bootstrap(before, old), old)
        self.assertEqual(exporter.build_records(old, manifest)[0], before)
        # 20 was deliberately excluded; new source 40 is a genuine addition.
        fresh = {1: item(npcDrops=[20, 40], vendors=[50], itemLevel=2)}
        records, _ = exporter.build_records(fresh, manifest)
        self.assertEqual(set(records[1]["s:npcDrops"].values()), {40})
        self.assertEqual(set(records[1]["s:vendors"].values()), {50})
        self.assertEqual(records[1]["s:itemLevel"], 2)
        self.assertEqual(manifest["sourceSelections"]["1"]["npcDrops"], [10])

    def test_current_source_supersedes_conditional_scalar_compatibility(self):
        source = {1: item(name="Prototype 01", flags=0, **{"class": 0})}
        before = {1: exporter.source_record(item(name="Prototype 1", flags=0, **{"class": 12}))}
        before[1].pop("s:flags", None)
        manifest = exporter.upgrade_manifest(bootstrap(before, source), source)
        self.assertEqual(exporter.build_records(source, manifest)[0], before)
        fresh = {1: item(name="Renamed", flags=1, **{"class": 4})}
        result = exporter.build_records(fresh, manifest)[0][1]
        self.assertEqual((result["s:name"], result["s:flags"], result["s:class"]), ("Renamed", 1, 4))

    def test_exclusion_sets_are_shared_and_new_relationship_fields_are_generated(self):
        raw = {1: item(npcDrops=[10, 20]), 2: item(npcDrops=[10, 20])}
        before = {key: exporter.source_record(item(npcDrops=[10])) for key in raw}
        manifest = exporter.upgrade_manifest(bootstrap(before, raw), raw)
        self.assertEqual(len(manifest["excludedSourceSets"]), 1)
        fresh = copy.deepcopy(raw)
        fresh[1]["questRewards"] = [99]
        result = exporter.build_records(fresh, manifest)[0]
        self.assertEqual(result[1]["s:questRewards"], {"n:1": 99})

    def test_new_templates_are_generated_while_known_omissions_stay_excluded(self):
        original = {1: item(), 2: item()}
        manifest = exporter.upgrade_manifest(bootstrap({1: exporter.source_record(original[1])}, original), original)
        fresh = {**original, 3: item(name="New item")}
        self.assertEqual(set(exporter.build_records(fresh, manifest)[0]), {1, 3})

    def test_compact_manifest_roundtrips_all_selection_types(self):
        source = {1: item(npcDrops=[100, 200])}
        before = {1: exporter.source_record(source[1])}
        before[1]["s:npcDrops"] = {"n:2": 200, "n:5": 100}
        manifest = bootstrap(before, source)
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "manifest.json"
            exporter.write_manifest(path, manifest)
            loaded = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(loaded, manifest)
            self.assertEqual(exporter.build_records(source, loaded)[0], before)

    def test_generated_candidate_loads_through_the_production_loader(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        source = {1: item(name='Quoted "name"\nnext', npcDrops=[100])}
        before = exporter.source_record(source[1])
        before["s:class"] = 12
        manifest = bootstrap({1: before}, source)
        records, _ = exporter.build_records(source, manifest)
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            candidate = directory / "candidate.lua"
            exporter.write_candidate(candidate, records)
            init = (ADDON_ROOT / "Modules/QuestieInit.lua").read_text(encoding="utf-8")
            loader = init[init.index("function QuestieInit:LoadDatabase(key)"):init.index("function _QuestieInit.StartStageCoroutine()")]
            script = directory / "load.lua"
            script.write_text('QuestieDB={}; QuestieInit={}; loadstring=loadstring or load; coYield=coroutine.yield\n'
                              'QuestieLoader={ImportModule=function() return QuestieDB end}\n'
                              + loader + '\ndofile(' + json.dumps(candidate.as_posix()) + ')\n'
                              'local thread=coroutine.create(function() QuestieInit:LoadDatabase("itemData") end)\n'
                              'repeat local ok,err=coroutine.resume(thread); assert(ok,err) until coroutine.status(thread)=="dead"\n'
                              'assert(QuestieDB.itemKeys.class==12 and QuestieDB.itemData[1][12]==12)\n'
                              'assert(QuestieDB.itemData[1][1]==\'Quoted "name"\\nnext\')\n'
                              'assert(QuestieDB.itemData[1][2][1]==100 and QuestieDB.itemData[1][5]==nil)\n',
                              encoding="utf-8")
            result = subprocess.run([lua, str(script)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
