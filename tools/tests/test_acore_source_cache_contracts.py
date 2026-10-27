"""All four source caches must reject stale inputs and honor explicit refresh."""
import copy
from contextlib import ExitStack, redirect_stdout
import hashlib
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import audit_acore_item_sources as item
import audit_acore_npc_sources as npc
import audit_acore_object_sources as obj
import audit_acore_quest_sources as quest
import db_snapshot


class ExtractionRequested(Exception):
    pass


class SourceCacheContractTests(unittest.TestCase):
    def variants(self, directory):
        common = {"tableCoverage": {}, "diagnostics": {}, "readerStats": {}}
        yield item, {"items": {}, "templateIds": [], "tableCoverage": {}}, \
            item.source_reader, "build_acore_items", \
            lambda signature, cache, **options: item.load_source(
                directory, "full", signature, cache, **options)
        yield npc, {**common, "npcs": {}}, npc.reader, "build_acore_npcs", \
            lambda signature, cache, **options: npc.load_source(
                *([directory] * 6), signature, cache, **options)
        yield obj, {**common, "objects": {}, "itemSourceObjectIds": []}, \
            obj.reader, "build_acore_objects", \
            lambda signature, cache, **options: obj.load_source(
                *([directory] * 5), signature, cache, **options)
        yield quest, {**common, "quests": {}, "disabledQuestIds": [],
                      "moduleQuestIds": [], "spellCoverage": {}}, \
            quest.metadata_reader, "derive_acore_metadata", \
            lambda signature, cache, **options: quest.load_source(
                directory, directory / "spell.sql", "spell", signature, cache, **options)

    def check_contract(self, mode):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            for audit, payload, owner, builder, load in self.variants(directory):
                with self.subTest(audit=audit.__name__, mode=mode), redirect_stdout(io.StringIO()):
                    signature = {"sourceRevision": "revision-a", "inputs": {"world.sql": "hash-a"}}
                    saved = {**copy.deepcopy(payload), "signature": signature}
                    saved["modelSha256"] = audit.model_digest(saved)
                    cache = directory / (audit.__name__ + ".json")
                    cache.write_text(json.dumps(saved), encoding="utf-8")
                    before = cache.read_bytes()
                    with patch.object(owner, builder, side_effect=ExtractionRequested) as extract:
                        if mode == "reuse":
                            self.assertEqual(load(signature, cache), saved)
                            extract.assert_not_called()
                        else:
                            requested = copy.deepcopy(signature)
                            if mode == "changed-input":
                                requested["inputs"]["world.sql"] = "hash-b"
                            elif mode == "changed-revision":
                                requested["sourceRevision"] = "revision-b"
                            with self.assertRaises(ExtractionRequested):
                                load(requested, cache, refresh=(mode == "refresh"))
                            extract.assert_called_once()
                    self.assertEqual(cache.read_bytes(), before)

    def test_unchanged_inputs_reuse_cache_without_extraction(self):
        self.check_contract("reuse")

    def test_changed_input_hash_requests_extraction_without_overwriting_old_cache(self):
        self.check_contract("changed-input")

    def test_changed_revision_requests_extraction_without_overwriting_old_cache(self):
        self.check_contract("changed-revision")

    def test_explicit_refresh_bypasses_matching_cache(self):
        self.check_contract("refresh")

    def test_signatures_cover_audit_rules_source_sql_and_external_inputs(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            source = directory / "source"
            repo = directory / "repo"
            spell = directory / "spell.sql"
            creature = directory / "creature.sql"
            multispawn = directory / "creature_multispawn.sql"
            gameobject = directory / "gameobject.sql"
            difficulty = directory / "MapDifficulty.dbc"
            wdm = directory / "wdm"

            def file_hash(path):
                path = Path(path)
                return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "unused-fixture-input"

            variants = [
                (item, lambda: item.source_signature(source, "full", spell), "item_template", [spell]),
                (npc, lambda: npc.source_signature(source, repo, creature, multispawn, difficulty, wdm),
                 "creature_template", [creature, multispawn, difficulty]),
                (obj, lambda: obj.source_signature(source, repo, gameobject, difficulty, wdm,
                                                  creature, multispawn, spell),
                 "gameobject_template", [gameobject, difficulty, creature, multispawn, spell]),
                (quest, lambda: quest.source_signature(source, spell, "spell", {"1": [100]}),
                 "quest_template", [spell]),
            ]
            for audit, signature, table, exports in variants:
                with self.subTest(audit=audit.__name__), ExitStack() as stack:
                    stack.enter_context(patch.object(audit, "ROOT", repo))
                    stack.enter_context(patch.object(db_snapshot, "file_hash", side_effect=file_hash))
                    stack.enter_context(patch.object(audit.subprocess, "run",
                                                    return_value=SimpleNamespace(returncode=0, stdout="revision-a")))
                    reader = audit.source_reader if audit is item else audit.sql_reader
                    stack.enter_context(patch.object(reader, "source_sql_files", return_value=[]))
                    if audit is quest:
                        stack.enter_context(patch.object(quest.cpp_events, "source_files", return_value=[]))
                        stack.enter_context(patch.object(quest.metadata_reader, "get_excluded_module_sql_roots", return_value=[]))
                    inputs = [repo / "tools" / (audit.__name__ + ".py"),
                              source / "data/sql/base/db_world" / (table + ".sql"), *exports]
                    if audit in (npc, obj):
                        inputs.extend(wdm / "patch-enUS-M extracted/DBFilesClient" / name
                                      for name in ("DungeonMap.csv", "DungeonMapChunk.csv"))
                        inputs.append(repo / "Compat/UiMapData.lua")
                    elif audit is quest:
                        inputs.append(repo / "Compat/UiMapData.lua")
                    for path in inputs:
                        path.parent.mkdir(parents=True, exist_ok=True)
                        path.write_bytes(b"original fixture")
                    baseline = signature()
                    self.assertEqual(signature(), baseline)
                    for path in inputs:
                        with self.subTest(changed=path.name):
                            path.write_bytes(b"changed fixture")
                            self.assertNotEqual(signature(), baseline)
                            path.write_bytes(b"original fixture")
                            self.assertEqual(signature(), baseline)


if __name__ == "__main__":
    unittest.main()
