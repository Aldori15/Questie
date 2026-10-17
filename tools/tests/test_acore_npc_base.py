"""NPC generation preserves the baseline without depending on legacy databases."""
import contextlib
import copy
import io
import json
import subprocess
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_npc_sources as audit
import db_snapshot
import generate_acore_npc_base as exporter


def npc(**fields):
    return {"s:name": "NPC", "s:minLevel": 1, **{"s:" + key: value for key, value in fields.items()}}


def bootstrap(before, source):
    return exporter.make_manifest(before, source, {"git": None}, "snapshot-sha", {"sourceRevision": "source-sha"})


class NpcBaseTests(unittest.TestCase):
    def test_source_backed_geometry_reorders_points_and_preserves_sparse_metadata(self):
        raw = audit.typed({210: [[10, 20, None, 3, 571, 100, 200, 1], [30, 40]]})
        desired = {"n:210": {"n:2": raw["n:210"]["n:2"], "n:7": raw["n:210"]["n:1"]}}
        recipe = exporter.encode_geometry(desired, raw)
        self.assertEqual(recipe["zones"]["n:210"]["refs"], [2, 1])
        self.assertEqual(exporter.decode_geometry(recipe, raw), desired)
        self.assertNotIn("n:3", exporter.decode_geometry(recipe, raw)["n:210"]["n:7"])

    def test_waypoint_order_and_legacy_points_are_retained(self):
        raw = audit.typed({210: [[[10, 20], [30, 40]], [[50, 60], [70, 80]]]})
        desired = audit.typed({210: [[[50, 60], [70, 80]], [[10, 20], [30, 40]], [[90, 95]]]})
        recipe = exporter.encode_geometry(desired, raw)
        self.assertEqual(recipe["zones"]["n:210"]["refs"], [2, 1, 0])
        self.assertEqual(exporter.decode_geometry(recipe, raw), desired)
        altered = copy.deepcopy(raw)
        altered["n:210"]["n:1"]["n:1"]["n:1"] = 11
        with self.assertRaisesRegex(ValueError, "Source geometry changed"):
            exporter.decode_geometry(recipe, altered)

    def test_new_npcs_zones_and_relations_do_not_expand_existing_scope(self):
        source = {1: npc(spawns=audit.typed({210: [[10, 20]]}), questStarts=audit.typed([10]))}
        before = copy.deepcopy(source)
        manifest = bootstrap(before, source)
        changed = copy.deepcopy(source)
        changed[2] = npc()
        changed[1]["s:spawns"]["n:4197"] = audit.typed([[30, 40]])
        changed[1]["s:questStarts"] = audit.typed([10, 20])
        self.assertEqual(exporter.build_records(changed, manifest), before)
        changed[1]["s:spawns"]["n:210"]["n:2"] = audit.typed([30, 40])
        with self.assertRaisesRegex(ValueError, "Source geometry changed"):
            exporter.build_records(changed, manifest)

    def test_display_health_zone_and_field_presence_are_explicit(self):
        source = {1: npc(minLevelHealth=500, maxLevelHealth=900, zoneID=210, npcFlags=0)}
        before = {1: npc(minLevelHealth=100, maxLevelHealth=200, zoneID=12, spawns={})}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        source[1]["s:minLevelHealth"] = 600
        source[1]["s:maxLevelHealth"] = 1000
        self.assertEqual(exporter.build_records(source, manifest), before)
        self.assertNotIn("s:npcFlags", exporter.build_records(source, manifest)[1])

    def test_missing_template_placeholders_are_preserved_but_id_collisions_fail(self):
        source = {1: npc()}
        before = {1: npc(), 80000: {"s:name": "Objective", "s:zoneID": 67}}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        with self.assertRaisesRegex(ValueError, "now has a source template"):
            exporter.build_records({**source, 80000: npc()}, manifest)
        with self.assertRaisesRegex(ValueError, "lost its source template"):
            exporter.build_records({}, manifest)

    def test_name_exception_guards_against_future_source_changes(self):
        source = {1: npc(name="Placeholder 05")}
        before = {1: npc(name="Placeholder 5")}
        manifest = bootstrap(before, source)
        self.assertEqual(exporter.build_records(source, manifest), before)
        with self.assertRaisesRegex(ValueError, "Source name changed"):
            exporter.build_records({1: npc(name="Renamed NPC")}, manifest)

    def test_missing_selected_quest_relation_stops_regeneration(self):
        source = {1: npc(questStarts=audit.typed([10]))}
        manifest = bootstrap(copy.deepcopy(source), source)
        with self.assertRaisesRegex(ValueError, "Selected quest relations changed"):
            exporter.build_records({1: npc(questStarts={})}, manifest)

    def test_invalid_masks_and_expanded_geometry_budgets_are_rejected(self):
        source = {1: npc(spawns=audit.typed({210: [[10, 20]]}))}
        manifest = bootstrap(source, source)
        invalid = copy.deepcopy(manifest)
        invalid["scope"]["1"] = True
        with self.assertRaisesRegex(ValueError, "field mask"):
            exporter.validate_manifest(invalid)
        manifest["limits"]["geometry"]["spawns"]["points"] = 0
        with self.assertRaisesRegex(ValueError, "budget exceeded"):
            exporter.build_records(source, manifest)

    def test_numeric_hashing_matches_lua_numbers_and_distinguishes_absence(self):
        self.assertEqual(exporter.value_hash({"n:1": 10}), exporter.value_hash({"n:1": 10.0}))
        self.assertNotEqual(exporter.value_hash(False), exporter.value_hash(0))
        self.assertNotEqual(exporter.value_hash(exporter.shared.ABSENT), exporter.value_hash({}))

    def test_exact_comparison_catches_order_presence_and_record_scope(self):
        before = {1: npc(spawns=audit.typed({210: [[10, 20], [30, 40]]}))}
        for after in ({}, {1: npc()}, {1: npc(spawns=audit.typed({210: [[30, 40], [10, 20]]}))}):
            self.assertFalse(exporter.compare_records(before, after)["exactParity"])

    def test_cli_generation_is_independent_of_snapshot_and_enforces_size_limit(self):
        source = {1: npc(spawns=audit.typed({210: [[10, 20]]})), 2: npc()}
        before = {1: npc(spawns=audit.typed({210: [[10, 20], [30, 40]]}))}
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            snapshot = directory / "snapshot.jsonl"
            snapshot.write_text("fixture", encoding="utf-8")
            signature = {"sourceRevision": "source"}
            saved = {"npcs": {str(k): v for k, v in source.items()}, "diagnostics": {}}
            args = ["--acore-source", str(directory), "--creature-sql", str(directory / "creature.sql"),
                    "--creature-multispawn-sql", str(directory / "multi.sql")]
            with patch.object(exporter, "ROOT", directory), \
                 patch.object(exporter.audit, "source_signature", return_value=signature), \
                 patch.object(exporter.audit, "load_source", return_value=saved), \
                 patch.object(exporter.audit.reader, "find_map_difficulty_dbc", return_value=directory / "difficulty.dbc"), \
                 contextlib.redirect_stdout(io.StringIO()):
                with patch.object(exporter.shared, "read_static_records", return_value=(before, list(exporter.FIELDS), {}, {"sources": {}})):
                    self.assertEqual(exporter.main(["bootstrap", "--snapshot", str(snapshot), *args]), 0)
                with patch.object(exporter.shared, "read_static_records", side_effect=AssertionError("Snapshot dependency")):
                    self.assertEqual(exporter.main(["generate", *args]), 0)
                manifest_path = directory / exporter.DEFAULT_MANIFEST
                manifest = json.loads(manifest_path.read_text())
                self.assertEqual(exporter.build_records(source, manifest), before)
                output = directory / "tools/reports/acore-npc-candidate/acoreNpcDB.lua"
                existing = output.read_bytes()
                manifest["limits"]["maxOutputBytes"] = 1
                exporter.write_manifest(manifest_path, manifest)
                with self.assertRaisesRegex(ValueError, "size budget"):
                    exporter.main(["generate", "--force", *args])
                self.assertEqual(output.read_bytes(), existing)
                saved["diagnostics"] = {"skippedSqlMutations": [{"statement": "unsupported"}]}
                with self.assertRaisesRegex(ValueError, "source diagnostics"):
                    exporter.main(["generate", "--force", *args])

    def test_generated_candidate_loads_in_the_production_loader(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        source = {1: npc(spawns=audit.typed({210: [[10, 20, None, 3, 571]]}))}
        before = {1: {**source[1], "s:minLevelHealth": 123}}
        records = exporter.build_records(source, bootstrap(before, source))
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            candidate = directory / "candidate.lua"
            with candidate.open("w", encoding="utf-8") as stream:
                exporter.write_stream(stream, records)
            init = (ADDON_ROOT / "Modules/QuestieInit.lua").read_text(encoding="utf-8")
            loader = init[init.index("function QuestieInit:LoadDatabase(key)"):init.index("function _QuestieInit.StartStageCoroutine()")]
            path = directory / "test.lua"
            path.write_text('QuestieDB={}; QuestieInit={}; loadstring=loadstring or load; coYield=coroutine.yield\n'
                            'QuestieLoader={ImportModule=function() return QuestieDB end}\n' + loader +
                            '\ndofile(' + json.dumps(candidate.as_posix()) + ')\n'
                            'local thread=coroutine.create(function() QuestieInit:LoadDatabase("npcData") end)\n'
                            'repeat local ok,err=coroutine.resume(thread); assert(ok,err) until coroutine.status(thread)=="dead"\n'
                            'assert(QuestieDB.npcKeys.spawns==7 and QuestieDB.npcData[1][2]==123)\n'
                            'local point=QuestieDB.npcData[1][7][210][1]\n'
                            'assert(point[1]==10 and point[2]==20 and point[3]==nil and point[4]==3 and point[5]==571)\n', encoding="utf-8")
            result = subprocess.run([lua, str(path)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
