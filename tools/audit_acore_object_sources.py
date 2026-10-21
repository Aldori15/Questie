"""Compare object source coverage with a verified snapshot without changing addon data."""
import argparse
from collections import Counter
from contextlib import ExitStack
import hashlib
import inspect
import json
from pathlib import Path
import subprocess
from unittest.mock import patch

import audit_acore_item_sources as shared
import audit_acore_npc_sources as geometry
import db_snapshot
import generate_acore_item_corrections as sql_reader
import generate_acore_npc_corrections as coordinate_reader
import generate_acore_object_corrections as reader
import acore_cpp_geometry


ROOT = Path(__file__).resolve().parents[1]
TABLES = ("gameobject_template", "gameobject_template_addon", "gameobject_queststarter",
          "game_event_gameobject_quest", "gameobject_questender", "reference_loot_template",
          "gameobject_loot_template")
REPO_INPUTS = ("Database/Zones/zoneTables.lua", "Compat/UiMapData.lua", "Modules/Phasing.lua",
               "Modules/Network/QuestieServer.lua", "tools/generate_acore_object_corrections.py",
               "tools/generate_acore_npc_corrections.py", "tools/generate_acore_item_corrections.py",
               "tools/validate_acore_quest_metadata.py", "tools/audit_acore_npc_sources.py",
               "tools/acore_scripted_geometry.py", "tools/acore_cpp_geometry.py")


def source_signature(source, repo, gameobject, difficulty, wdm, creature=None, multispawn=None, spell=None):
    if multispawn is not None and creature is None:
        raise ValueError("Object summon context requires --creature-sql with --creature-multispawn-sql")
    tables = TABLES + (("creature_template", "smart_scripts") if creature is not None else ()) + (("spell_dbc",) if spell is not None else ())
    paths = {p.resolve() for table in tables for p in sql_reader.source_sql_files(source, table)}
    paths.update(source / "data/sql/base/db_world" / f"{table}.sql" for table in tables)
    paths.update(source / name for name in acore_cpp_geometry.OBJECT_SOURCE_FILES)
    external = [gameobject, difficulty,
                wdm / "patch-enUS-M extracted/DBFilesClient/DungeonMap.csv",
                wdm / "patch-enUS-M extracted/DBFilesClient/DungeonMapChunk.csv"]
    external.extend(p for p in (creature, multispawn, spell) if p is not None)
    revision = subprocess.run(["git", "-C", str(source), "rev-parse", "HEAD"], capture_output=True, text=True)
    return {"version": 2, "includeModules": False, "sourceRoot": str(source), "repoRoot": str(repo),
            "sourceRevision": revision.stdout.strip() if revision.returncode == 0 else None,
            "sourceFiles": {str(p.relative_to(source)): db_snapshot.file_hash(p) for p in sorted(paths)},
            "externalFiles": {str(p): db_snapshot.file_hash(p) for p in external},
            "repoFiles": {name: db_snapshot.file_hash(repo / name) for name in REPO_INPUTS},
            "extractor": hashlib.sha256(inspect.getsource(load_source).encode()).hexdigest()}


def model_digest(saved):
    payload = {key: saved[key] for key in ("objects", "tableCoverage", "readerStats", "diagnostics", "itemSourceObjectIds")}
    if "geometryProvenance" in saved:
        payload["geometryProvenance"] = saved["geometryProvenance"]
    return hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=True, allow_nan=False,
                                     separators=(",", ":")).encode()).hexdigest()


def load_source(source, repo, gameobject, difficulty, wdm, signature, cache, refresh=False,
                creature=None, multispawn=None, spell=None):
    if cache.exists() and not refresh:
        saved = json.loads(cache.read_text(encoding="utf-8"))
        if saved.get("signature") == signature:
            if saved.get("modelSha256") != model_digest(saved):
                raise ValueError("Object cache checksum mismatch; use --refresh-source")
            print(f"Using validated object source cache: {cache}", flush=True)
            return saved
    coverage, skipped_statements = {}, []
    current_file = {"path": None}
    original_rows = sql_reader.load_row_table
    original_statements = sql_reader.load_sql_statements
    original_external = reader.load_rows_from_sql_file
    original_filtered = reader.load_filtered_row_table

    def statements(path):
        current_file["path"] = Path(path).resolve()
        return original_statements(path)

    def trace_mutation(name, original):
        def replay(statement, table, *args, **kwargs):
            skipped = original(statement, table, *args, **kwargs)
            if skipped:
                path = current_file["path"]
                skipped_statements.append({"table": table, "operation": name.removeprefix("apply_multirow_"),
                                           "file": str(path.relative_to(source)) if path and path.is_relative_to(source) else str(path),
                                           "skippedCount": skipped, "statement": statement[:4000],
                                           "statementTruncated": len(statement) > 4000,
                                           "statementSha256": hashlib.sha256(statement.encode()).hexdigest()})
            return skipped
        return replay

    def rows(root, table, keys, include_modules=False):
        print(f"Reading {table}...", flush=True)
        values, skipped = original_rows(root, table, keys, include_modules)
        coverage[table] = {"rows": len(values), "skippedMutations": skipped, "origin": "AzerothCore SQL"}
        return values, skipped

    def external(path, table, keys, default_columns=None, **kwargs):
        print(f"Reading exported {table}...", flush=True)
        current_file["path"] = Path(path).resolve()
        values, skipped = original_external(path, table, keys, default_columns, **kwargs)
        coverage[table] = {"rows": len(values), "skippedMutations": skipped, "origin": "Explicit SQL export"}
        return values, skipped

    def filtered(root, table, keys, row_filter, include_modules=False):
        print(f"Reading {table}...", flush=True)
        values, skipped = original_filtered(root, table, keys, row_filter, include_modules)
        coverage[table] = {"rows": len(values), "skippedMutations": skipped,
                           "origin": "AzerothCore SQL; SmartAI geometry and caller context"}
        return values, skipped

    provenance = {}
    with ExitStack() as stack:
        for module in (sql_reader, reader):
            stack.enter_context(patch.object(module, "load_row_table", rows))
        stack.enter_context(patch.object(sql_reader, "load_sql_statements", statements))
        stack.enter_context(patch.object(reader, "load_rows_from_sql_file", external))
        stack.enter_context(patch.object(reader, "load_filtered_row_table", filtered))
        stack.enter_context(patch.object(coordinate_reader, "load_sql_statements", statements))
        for name in ("apply_multirow_insert", "apply_multirow_delete", "apply_multirow_update"):
            stack.enter_context(patch.object(sql_reader, name, trace_mutation(name, getattr(sql_reader, name))))
        for name in ("apply_multirow_insert", "apply_multirow_delete", "apply_multirow_update"):
            stack.enter_context(patch.object(coordinate_reader, name,
                                           trace_mutation(name, getattr(coordinate_reader, name))))
        # No corrected Questie data is passed to the source reader as a fallback.
        context_inputs = ({"creature_sql": creature, "creature_multispawn_sql": multispawn}
                          if creature is not None or multispawn is not None else {})
        if spell is not None:
            context_inputs["spell_sql"] = spell
        objects, stats, item_sources = reader.build_acore_objects(
            source, repo_root=repo, gameobject_sql=gameobject, map_difficulty_dbc=difficulty, wdm_root=wdm,
            provenance=provenance, **context_inputs)
    if source_signature(source, repo, gameobject, difficulty, wdm, creature, multispawn, spell) != signature:
        raise ValueError("Object source inputs changed during extraction")
    saved = {"signature": signature,
             "geometryProvenance": provenance,
             "objects": {str(i): {"s:" + field: geometry.typed(v) for field, v in row.items() if v is not None}
                         for i, row in sorted(objects.items())},
             "tableCoverage": coverage, "readerStats": stats,
             "itemSourceObjectIds": sorted(item_sources),
             "diagnostics": {"skippedSqlMutations": skipped_statements}}
    saved["modelSha256"] = model_digest(saved)
    shared.write_json(cache, saved)
    return saved


def compare_fields(baseline, source, fields):
    # The object fields share the NPC reader's types and exact spawn format.
    reports = geometry.compare_fields(baseline, source, fields, {})
    for report in reports.values():
        for row in report["differences"]:
            row["objectId"] = row.pop("npcId")
    return reports


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
    parser.add_argument("--gameobject-sql", type=Path, required=True)
    parser.add_argument("--creature-sql", type=Path)
    parser.add_argument("--creature-multispawn-sql", type=Path)
    parser.add_argument("--spell-sql", type=Path)
    parser.add_argument("--map-difficulty-dbc", type=Path)
    parser.add_argument("--wdm-root", type=Path, default=coordinate_reader.DEFAULT_WDM_ROOT)
    parser.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_object_source_model.json"))
    parser.add_argument("--report", type=Path, default=Path("tools/reports/acore_object_source_audit.json"))
    parser.add_argument("--refresh-source", action="store_true")
    args = parser.parse_args(argv)
    source, gameobject, wdm = (p.resolve() for p in (args.acore_source, args.gameobject_sql, args.wdm_root))
    difficulty = coordinate_reader.find_map_difficulty_dbc(source, args.map_difficulty_dbc).resolve()
    creature = args.creature_sql.resolve() if args.creature_sql else None
    multispawn = args.creature_multispawn_sql.resolve() if args.creature_multispawn_sql else None
    spell = args.spell_sql.resolve() if args.spell_sql else None
    report, cache = (shared.local_output(ROOT, p) for p in (args.report, args.source_cache))
    if report == cache or args.snapshot.resolve() in (report, cache):
        raise ValueError("Report, cache and snapshot must use different paths")
    snapshot_digest = db_snapshot.file_hash(args.snapshot)
    print("Validating snapshot and object contexts...", flush=True)
    baseline, fields, overrides, metadata = shared.read_static_records(args.snapshot, ROOT, "object")
    if fields != reader.FIELD_ORDER:
        raise ValueError("Unexpected object schema; review reader field coverage")
    signature = source_signature(source, ROOT, gameobject, difficulty, wdm, creature, multispawn, spell)
    saved = load_source(source, ROOT, gameobject, difficulty, wdm, signature, cache, args.refresh_source,
                        creature, multispawn, spell)
    model = {int(key): row for key, row in saved["objects"].items()}
    data = {"snapshotSha256": snapshot_digest, "sourceInputs": signature,
            "counts": {"snapshotObjects": len(baseline), "sourceObjects": len(model), "schemaFields": len(fields)},
            "fields": compare_fields(baseline, model, fields),
            "snapshotOnlyIds": sorted(set(baseline) - set(model)), "sourceOnlyIds": sorted(set(model) - set(baseline)),
            "geometry": {"snapshot": geometry.geometry_inventory(baseline)["spawns"],
                         "sourceWithinExistingScope": geometry.geometry_inventory({i: model[i] for i in baseline if i in model})["spawns"]},
            "tableCoverage": saved["tableCoverage"], "readerStats": saved["readerStats"],
            "diagnostics": saved["diagnostics"], "itemSourceObjectIds": saved["itemSourceObjectIds"],
            "runtimeOverrides": overrides,
            "limitations": ["Audit only; differences do not authorize data additions or removals.",
                            "Questie entrance placeholders and manual corrections are not source inputs.",
                            "The explicit gameobject export supplies current spawn rows; source SQL is not replayed over that export.",
                            "Coordinates and phase, difficulty, visibility and identity slots are retained without rounding.",
                            "Unmapped spawns leave geometry unavailable, rather than asserting an empty spawn list.",
                            "Arbitrary scripts, player conditions, modules and pending SQL updates are outside this model."]}
    if source_signature(source, ROOT, gameobject, difficulty, wdm, creature, multispawn, spell) != signature:
        raise ValueError("Object source inputs changed during audit")
    if db_snapshot.file_hash(args.snapshot) != snapshot_digest or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items()):
        raise ValueError("Snapshot or addon changed during audit")
    shared.write_json(report, data)
    summary = {key: data[key] for key in ("counts", "geometry", "tableCoverage", "readerStats")}
    summary["fields"] = {field: row["counts"] for field, row in data["fields"].items()}
    summary["diagnostics"] = {key: len(values) for key, values in saved["diagnostics"].items()}
    summary["spawnDifferenceKinds"] = dict(Counter(row["differenceKind"] for row in data["fields"]["spawns"]["differences"]
                                                  if "differenceKind" in row))
    summary["snapshotOnlyObjects"], summary["sourceOnlyObjects"] = len(data["snapshotOnlyIds"]), len(data["sourceOnlyIds"])
    print(json.dumps(summary, indent=2))
    print(f"Report: {report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, EOFError, KeyError, TypeError) as exc:
        raise SystemExit(f"Object source audit failed: {exc}")
