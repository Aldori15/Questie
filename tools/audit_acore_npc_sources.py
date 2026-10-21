"""Audit NPC source coverage without modifying addon databases.

Compare a fresh correction-pipeline snapshot against the existing NPC SQL and
coordinate reader. Retain exact coordinates, path order, phases, visibility and
identity slots. This is an inventory, not permission to adopt source changes.
"""
import argparse
from collections import Counter
import hashlib
import inspect
import json
from pathlib import Path
import subprocess

import audit_acore_item_sources as shared
import db_snapshot
import generate_acore_item_corrections as sql_reader
import generate_acore_npc_corrections as reader
import acore_cpp_geometry


ROOT = Path(__file__).resolve().parents[1]
TABLES = ("creature_template", "creature_queststarter", "game_event_creature_quest", "creature_questender",
          "factiontemplate_dbc", "creature_addon", "creature_template_addon", "waypoint_data", "waypoints", "smart_scripts",
          "event_scripts", "game_event_creature")
ANCHORS = {1, 3, 4, 115, 1629, 2, 5, 6, 116, 1610}
REPO_INPUTS = ("Database/Zones/zoneTables.lua", "Compat/UiMapData.lua", "Modules/Phasing.lua",
               "Modules/Network/QuestieServer.lua", "tools/generate_acore_npc_corrections.py",
               "tools/generate_acore_item_corrections.py", "tools/validate_acore_quest_metadata.py",
               "tools/acore_scripted_geometry.py", "tools/acore_cpp_geometry.py", "tools/acore_runtime_geometry.py")


def typed(value):
    """Lua nil slots are absent; retain every other value, including false/zero."""
    if isinstance(value, list):
        return {f"n:{i}": typed(v) for i, v in enumerate(value, 1) if v is not None}
    if isinstance(value, dict):
        return {("n:" if type(k) is int else "s:") + str(k): typed(v) for k, v in value.items() if v is not None}
    return value


def source_signature(source, repo, creature, multispawn, difficulty, wdm):
    paths = {p.resolve() for table in TABLES for p in sql_reader.source_sql_files(source, table)}
    paths.update(source / "data/sql/base/db_world" / f"{table}.sql" for table in TABLES)
    paths.add(source / "src/server/game/Battlefield/Zones/BattlefieldWG.h")
    paths.update(source / name for name in acore_cpp_geometry.SOURCE_FILES)
    external = [creature, multispawn, difficulty,
                wdm / "patch-enUS-M extracted/DBFilesClient/DungeonMap.csv",
                wdm / "patch-enUS-M extracted/DBFilesClient/DungeonMapChunk.csv"]
    revision = subprocess.run(["git", "-C", str(source), "rev-parse", "HEAD"], capture_output=True, text=True)
    return {"version": 2, "includeModules": False, "sourceRoot": str(source), "repoRoot": str(repo),
            "sourceRevision": revision.stdout.strip() if revision.returncode == 0 else None,
            "sourceFiles": {str(p.relative_to(source)): db_snapshot.file_hash(p) for p in sorted(paths)},
            "externalFiles": {str(p): db_snapshot.file_hash(p) for p in external},
            "repoFiles": {name: db_snapshot.file_hash(repo / name) for name in REPO_INPUTS},
            "extractor": hashlib.sha256((inspect.getsource(load_source) + inspect.getsource(typed)).encode()).hexdigest()}


def model_digest(saved):
    payload = {key: saved[key] for key in ("npcs", "tableCoverage", "diagnostics", "readerStats")}
    if "geometryProvenance" in saved:
        payload["geometryProvenance"] = saved["geometryProvenance"]
    return hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=True, allow_nan=False,
                                     separators=(",", ":")).encode()).hexdigest()


def load_source(source, repo, creature, multispawn, difficulty, wdm, signature, cache, refresh=False):
    if cache.exists() and not refresh:
        saved = json.loads(cache.read_text(encoding="utf-8"))
        if saved.get("signature") == signature:
            if saved.get("modelSha256") != model_digest(saved):
                raise ValueError("NPC cache checksum mismatch; use --refresh-source")
            print(f"Using validated NPC source cache: {cache}", flush=True)
            return saved
    coverage, factions, referenced_factions = {}, set(), set()
    skipped_statements, current_file = [], {"path": None}
    original_rows, original_external, original_filtered = sql_reader.load_row_table, reader.load_rows_from_sql_file, reader.load_filtered_row_table
    npc_rows = reader.load_row_table
    statement_loaders = (sql_reader.load_sql_statements, reader.load_sql_statements)
    mutation_functions = {name: (getattr(sql_reader, name), getattr(reader, name))
                          for name in ("apply_multirow_insert", "apply_multirow_delete", "apply_multirow_update")}

    def statements(path):
        current_file["path"] = Path(path).resolve()
        return statement_loaders[0](path)

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

    def inventory(table, rows, skipped, origin):
        nonlocal factions, referenced_factions
        coverage[table] = {"rows": len(rows), "skippedMutations": skipped, "origin": origin}
        if table == "factiontemplate_dbc":
            factions = {int(row["ID"]) for row in rows}
        if table == "creature_template":
            referenced_factions = {int(row.get("faction") or 0) for row in rows}
        return rows, skipped

    def rows(root, table, keys, include_modules=False):
        print(f"Reading {table}...", flush=True)
        values, skipped = original_rows(root, table, keys, include_modules)
        return inventory(table, values, skipped, "AzerothCore SQL")

    def external(path, table, keys, default_columns=None):
        print(f"Reading exported {table}...", flush=True)
        current_file["path"] = Path(path).resolve()
        values, skipped = original_external(path, table, keys, default_columns)
        return inventory(table, values, skipped, "Explicit SQL export")

    def filtered(root, table, keys, row_filter, include_modules=False, **kwargs):
        print(f"Reading filtered {table}...", flush=True)
        values, skipped = original_filtered(root, table, keys, row_filter, include_modules, **kwargs)
        return inventory(table, values, skipped, "AzerothCore SQL; SmartAI geometry and caller context")

    sql_reader.load_row_table = reader.load_row_table = rows
    reader.load_rows_from_sql_file, reader.load_filtered_row_table = external, filtered
    sql_reader.load_sql_statements = reader.load_sql_statements = statements
    for name, (original, _) in mutation_functions.items():
        setattr(sql_reader, name, trace_mutation(name, original))
        setattr(reader, name, getattr(sql_reader, name))
    provenance = {}
    try:
        # Baseline NPCs are deliberately NOT passed as the reader's fallback.
        # Missing transport/scripted coverage must remain visible in the audit.
        npcs, stats = reader.build_acore_npcs(source, repo_root=repo, creature_sql=creature,
                                             creature_multispawn_sql=multispawn, map_difficulty_dbc=difficulty,
                                             wdm_root=wdm, provenance=provenance)
    finally:
        sql_reader.load_row_table, reader.load_row_table = original_rows, npc_rows
        reader.load_rows_from_sql_file, reader.load_filtered_row_table = original_external, original_filtered
        sql_reader.load_sql_statements, reader.load_sql_statements = statement_loaders
        for name, (sql_function, npc_function) in mutation_functions.items():
            setattr(sql_reader, name, sql_function)
            setattr(reader, name, npc_function)
    if source_signature(source, repo, creature, multispawn, difficulty, wdm) != signature:
        raise ValueError("NPC source inputs changed during extraction")
    saved = {"signature": signature,
             "geometryProvenance": provenance,
             "npcs": {str(i): {"s:" + field: typed(v) for field, v in row.items() if v is not None}
                      for i, row in sorted(npcs.items())},
             "tableCoverage": coverage, "readerStats": stats,
             "diagnostics": {"missingFactionTemplateIds": sorted(referenced_factions - factions),
                             "missingFriendlinessAnchorIds": sorted(ANCHORS - factions),
                             "skippedSqlMutations": skipped_statements}}
    saved["modelSha256"] = model_digest(saved)
    shared.write_json(cache, saved)
    return saved


def empty_equivalent(field, value):
    if value is shared.ABSENT:
        return True
    if field in reader.LIST_FIELDS | reader.NESTED_FIELDS:
        return isinstance(value, dict) and not value
    if field in reader.STRING_FIELDS:
        return type(value) is str and value == ""
    return type(value) in (int, float) and value == 0


def spawn_difference_kind(actual, expected):
    def freeze(value):
        if isinstance(value, dict):
            return tuple((key, freeze(v)) for key, v in sorted(value.items()))
        return ("number" if type(value) in (int, float) else type(value).__name__, value)

    def points(table, coordinates_only=False):
        result = Counter()
        for zone, entries in table.items():
            if not isinstance(entries, dict) or not entries:
                result[(zone, "emptyOrMalformed", freeze(entries))] += 1
                continue
            for point in entries.values():
                value = point
                if coordinates_only and isinstance(point, dict):
                    value = {key: point[key] for key in ("n:1", "n:2") if key in point}
                result[(zone, freeze(value))] += 1
        return result

    if not isinstance(actual, dict) or not isinstance(expected, dict):
        return "coordinateOrCoverageChanges"
    if points(actual) == points(expected):
        return "pointOrderOnly"
    if points(actual, True) == points(expected, True):
        return "phaseVisibilityOrIdentityChanges"
    return "coordinateOrCoverageChanges"


def compare_fields(baseline, source, fields, diagnostics):
    reports = {}
    missing_factions = set(diagnostics.get("missingFactionTemplateIds", []))
    missing_anchors = diagnostics.get("missingFriendlinessAnchorIds", [])
    for field in fields:
        counts, differences = Counter(), []
        key = "s:" + field
        for npc_id, current in sorted(baseline.items()):
            if npc_id not in source:
                counts["missingSourceTemplate"] += 1
                continue
            raw = source[npc_id]
            actual, expected = current.get(key, shared.ABSENT), raw.get(key, shared.ABSENT)
            if field == "friendlyToFaction" and (missing_anchors or raw.get("s:factionID") in missing_factions):
                status = "unreliableSourceCoverage"
            elif expected is shared.ABSENT:
                status = "unavailableInSource"
            elif shared.same_value(actual, expected):
                counts["exactMatches"] += 1
                continue
            elif empty_equivalent(field, actual) and empty_equivalent(field, expected):
                counts["representationOnly"] += 1
                continue
            elif field in reader.LIST_FIELDS and isinstance(actual, dict) and isinstance(expected, dict) and set(actual.values()) == set(expected.values()):
                counts["relationOrderOrDuplicates"] += 1
                continue
            else:
                status = "valueDifferences"
            counts[status] += 1
            row = {"npcId": npc_id, "name": raw.get("s:name"), "status": status,
                                "snapshotPresent": actual is not shared.ABSENT,
                                "sourcePresent": expected is not shared.ABSENT,
                                "snapshot": None if actual is shared.ABSENT else actual,
                                "source": None if expected is shared.ABSENT else expected}
            if field == "spawns" and status == "valueDifferences":
                row["differenceKind"] = spawn_difference_kind(actual, expected)
            differences.append(row)
        reports[field] = {"counts": dict(counts), "differences": differences}
    return reports


def point_counts(value):
    counts = Counter()
    if not isinstance(value, dict):
        return counts
    if all(type(value.get("n:" + str(i))) in (int, float) for i in (1, 2)):
        counts["points"] += 1
        if "n:3" in value:
            counts["pointsWithPhaseSlot"] += 1
        if any("n:" + str(i) in value for i in range(4, 9)):
            counts["pointsWithVisibilityOrIdentitySlots"] += 1
    else:
        for child in value.values():
            counts.update(point_counts(child))
    return counts


def geometry_inventory(records):
    result = {}
    for field in ("spawns", "waypoints"):
        counts = Counter()
        for row in records.values():
            counts.update(point_counts(row.get("s:" + field)))
        result[field] = dict(counts)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
    parser.add_argument("--creature-sql", type=Path, required=True)
    parser.add_argument("--creature-multispawn-sql", type=Path, required=True)
    parser.add_argument("--map-difficulty-dbc", type=Path)
    parser.add_argument("--wdm-root", type=Path, default=reader.DEFAULT_WDM_ROOT)
    parser.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_npc_source_model.json"))
    parser.add_argument("--report", type=Path, default=Path("tools/reports/acore_npc_source_audit.json"))
    parser.add_argument("--refresh-source", action="store_true")
    args = parser.parse_args(argv)
    source, creature, multispawn, wdm = (p.resolve() for p in (args.acore_source, args.creature_sql,
                                                            args.creature_multispawn_sql, args.wdm_root))
    difficulty = reader.find_map_difficulty_dbc(source, args.map_difficulty_dbc).resolve()
    report, cache = (shared.local_output(ROOT, p) for p in (args.report, args.source_cache))
    if report == cache or args.snapshot.resolve() in (report, cache):
        raise ValueError("Report, cache and snapshot must use different paths")
    snapshot_digest = db_snapshot.file_hash(args.snapshot)
    print("Validating snapshot and NPC contexts...", flush=True)
    baseline, fields, overrides, metadata = shared.read_static_records(args.snapshot, ROOT, "npc")
    if fields != reader.FIELD_ORDER:
        raise ValueError("Unexpected NPC schema; review reader field coverage")
    signature = source_signature(source, ROOT, creature, multispawn, difficulty, wdm)
    saved = load_source(source, ROOT, creature, multispawn, difficulty, wdm, signature, cache, args.refresh_source)
    model = {int(key): row for key, row in saved["npcs"].items()}
    report_data = {"snapshotSha256": snapshot_digest, "sourceInputs": signature,
                   "counts": {"snapshotNpcs": len(baseline), "sourceNpcs": len(model), "schemaFields": len(fields)},
                   "fields": compare_fields(baseline, model, fields, saved["diagnostics"]),
                   "snapshotOnlyIds": sorted(set(baseline) - set(model)), "sourceOnlyIds": sorted(set(model) - set(baseline)),
                   "geometry": {"snapshot": geometry_inventory(baseline),
                                "sourceWithinExistingScope": geometry_inventory({i: model[i] for i in baseline if i in model})},
                   "tableCoverage": saved["tableCoverage"], "readerStats": saved["readerStats"],
                   "diagnostics": saved["diagnostics"], "runtimeOverrides": overrides,
                   "limitations": ["Audit only: no records, spawns or waypoints are approved additions/removals.",
                                   "Existing gunship/entrance/display fallbacks are not source inputs; omissions need explicit supplements.",
                                   "Health reflects exported curhealth where available, not a complete server health calculation.",
                                   "Friendliness currently uses SQL factiontemplate_dbc, not the full client FactionTemplate.dbc.",
                                   "Coordinates, path order, phases, difficulty masks and identity slots are compared without rounding or dropping metadata.",
                                   "Player conditions, arbitrary scripts, modules and pending SQL updates are outside this source model."]}
    if source_signature(source, ROOT, creature, multispawn, difficulty, wdm) != signature:
        raise ValueError("NPC source inputs changed during audit")
    if db_snapshot.file_hash(args.snapshot) != snapshot_digest or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items()):
        raise ValueError("Snapshot or addon changed during audit")
    shared.write_json(report, report_data)
    summary = {key: report_data[key] for key in ("counts", "geometry", "tableCoverage", "readerStats")}
    summary["fields"] = {field: row["counts"] for field, row in report_data["fields"].items()}
    summary["diagnostics"] = {key: len(values) for key, values in saved["diagnostics"].items()}
    summary["spawnDifferenceKinds"] = dict(Counter(row["differenceKind"] for row in report_data["fields"]["spawns"]["differences"]
                                                  if "differenceKind" in row))
    summary["snapshotOnlyNpcs"], summary["sourceOnlyNpcs"] = len(report_data["snapshotOnlyIds"]), len(report_data["sourceOnlyIds"])
    print(json.dumps(summary, indent=2))
    print(f"Report: {report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, EOFError, KeyError, TypeError) as exc:
        raise SystemExit(f"NPC source audit failed: {exc}")
