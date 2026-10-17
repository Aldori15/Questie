"""Audit a current snapshot against the existing AzerothCore item source reader.

Default scope checks item-start links using item_template only. --scope full
also inventories every item field, source-reader gaps, and faction overrides.
Reports/caches stay under tools/reports; addon databases are never written.
The source reader is still a delta-generator component, so differences need
review before they can become source rules or explicit Questie supplements.
"""
import argparse
from collections import Counter
import hashlib
import inspect
import json
from pathlib import Path
import subprocess

import db_snapshot as snapshot
import generate_acore_item_corrections as source_reader


ROOT = Path(__file__).resolve().parents[1]
TABLES = ("item_template", "quest_template", "gameobject_template", "creature_template", "creature", "spell_dbc",
          "reference_loot_template", "creature_loot_template", "gameobject_loot_template", "item_loot_template",
          "npc_vendor", "game_event_npc_vendor", "npc_spellclick_spells")
CACHE_VERSION = 3
ABSENT = object()


def same_value(left, right):
    """Keep booleans distinct from numbers, including inside nested Lua tables."""
    if type(left) is not type(right):
        return type(left) in (int, float) and type(right) in (int, float) and left == right
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(same_value(left[key], right[key]) for key in left)
    return left == right


def typed(value):
    if isinstance(value, list):
        return {f"n:{index}": typed(item) for index, item in enumerate(value, 1)}
    if isinstance(value, dict):
        return {("n:" if type(key) is int else "s:") + str(key): typed(item) for key, item in value.items()}
    return value


def normalized(field, value):
    if value is ABSENT:
        return () if field in source_reader.LIST_FIELDS else ("" if field == "name" else 0)
    if field in source_reader.LIST_FIELDS:
        if not isinstance(value, dict) or any(not k.startswith("n:") or type(v) is not int for k, v in value.items()):
            raise ValueError(f"Unexpected {field} value: expected a Lua list of numeric IDs")
        return tuple(sorted(set(value.values())))
    if field == "name":
        if not isinstance(value, str):
            raise ValueError("Unexpected item name type")
        return value
    if type(value) not in (int, float):
        raise ValueError(f"Unexpected numeric item field: {field}")
    return value


def local_output(root, path):
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root / "tools/reports") or resolved.suffix != ".json":
        raise ValueError("Audit outputs must be .json files inside tools/reports")
    return resolved


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with snapshot.temporary_directory(path.parent) as directory:
        candidate = directory / "candidate.json"
        candidate.write_text(json.dumps(value, indent=2, ensure_ascii=True, allow_nan=False) + "\n", encoding="utf-8")
        candidate.replace(path)


def read_static_records(path, root, kind):
    items, counts, overrides, schema = {}, Counter(), {}, None
    with snapshot.open_snapshot(path, "r") as stream:
        metadata = snapshot.read_header(stream)["metadata"]
        if metadata.get("scope") != "post-corrections-pre-localization-v1" or metadata.get("locale") != "enUS":
            raise ValueError("Use an enUS correction-pipeline snapshot")
        hashes = metadata.get("sources")
        if not hashes:
            raise ValueError("Snapshot lacks source hashes")
        for name, digest in hashes.items():
            if snapshot.file_hash(root / name) != digest:
                raise ValueError(f"Stale snapshot: {name}; capture a fresh snapshot")
        first = min(metadata["contexts"])
        for record in snapshot.read_records(stream, metadata["contexts"]):
            context, section, item_id, value = (record[k] for k in ("context", "section", "id", "value"))
            if section == kind + "Data":
                if type(item_id) is not int or not isinstance(value, dict):
                    raise ValueError(f"Invalid {kind} record")
                counts[context] += 1
                if context == first:
                    items[item_id] = value
                elif item_id not in items or not same_value(items[item_id], value):
                    raise ValueError(f"Static {kind} {item_id} differs between contexts; audit it separately")
            elif section == "schemas/" + kind and item_id == "keys":
                if schema is not None and not same_value(schema, value):
                    raise ValueError(f"{kind} schema differs between contexts")
                schema = value
            elif section.startswith("overrides/") and section.endswith("/" + kind):
                overrides.setdefault(context, {}).setdefault(section, {})[item_id] = value
    if not items or schema is None or any(counts[c] != len(items) for c in metadata["contexts"]):
        raise ValueError(f"Snapshot is missing {kind} records or schema in a context")
    if not all(isinstance(key, str) and key.startswith("s:") and type(index) is int for key, index in schema.items()) or sorted(schema.values()) != list(range(1, len(schema) + 1)):
        raise ValueError(f"Invalid {kind} schema slots")
    fields = [key[2:] for key, _ in sorted(schema.items(), key=lambda pair: pair[1])]
    return items, fields, overrides, metadata


def read_items(path, root):
    return read_static_records(path, root, "item")


def source_signature(source, scope, spell_sql=None, spell_table="spell"):
    tables = TABLES if scope == "full" else ("item_template",)
    paths = {path.resolve() for table in tables for path in source_reader.source_sql_files(source, table)}
    required = {source / "data/sql/base/db_world" / f"{table}.sql" for table in tables}
    paths.update(required)
    revision = subprocess.run(["git", "-C", str(source), "rev-parse", "HEAD"], capture_output=True, text=True)
    return {"version": CACHE_VERSION, "scope": scope, "sourceRoot": str(source), "includeModules": False,
            "spellExport": {"path": str(Path(spell_sql).resolve()), "sha256": snapshot.file_hash(spell_sql),
                            "table": spell_table} if spell_sql is not None else None,
            "sourceRevision": revision.stdout.strip() if revision.returncode == 0 else None,
            "sql": {str(path.relative_to(source)): snapshot.file_hash(path) for path in sorted(paths)},
            "extractor": hashlib.sha256(inspect.getsource(load_source).encode("utf-8")).hexdigest(),
            "readers": {name: snapshot.file_hash(ROOT / "tools" / name) for name in
                        ("generate_acore_item_corrections.py", "validate_acore_quest_metadata.py")}}


def model_digest(saved):
    payload = {key: saved[key] for key in ("items", "templateIds", "tableCoverage")}
    payload["sourceDiagnostics"] = saved.get("sourceDiagnostics", {})
    payload["spellCoverage"] = saved.get("spellCoverage", {})
    return hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=True, allow_nan=False,
                                     separators=(",", ":")).encode("utf-8")).hexdigest()


def load_source(source, scope, signature, cache, refresh=False, spell_sql=None, spell_table="spell"):
    if cache.exists() and not refresh:
        saved = json.loads(cache.read_text(encoding="utf-8"))
        if saved.get("signature") == signature:
            if saved.get("modelSha256") != model_digest(saved):
                raise ValueError("Source cache checksum mismatch; rerun with --refresh-source")
            print(f"Using validated source cache: {cache}", flush=True)
            return saved
    coverage, template_ids, diagnostics, spell_coverage = {}, [], {}, {}
    original = source_reader.load_row_table

    def inventory_rows(source_root, table, keys, include_modules=False):
        nonlocal template_ids
        print(f"Reading {table}...", flush=True)
        rows, skipped = original(source_root, table, keys, include_modules)
        coverage[table] = {"rows": len(rows), "skippedMutations": skipped}
        if table == "item_template":
            template_ids = sorted(int(row["entry"]) for row in rows)
        if table.endswith("loot_template"):
            equal_chance = [row for row in rows if float(row.get("Chance") or 0) == 0 and int(row.get("GroupId") or 0) > 0]
            coverage[table].update({"zeroChanceGroupedRows": len(equal_chance),
                                   "zeroChanceGroupedItemIds": sorted({int(row["Item"]) for row in equal_chance if int(row.get("Item") or 0) > 0})})
        return rows, skipped

    source_reader.load_row_table = inventory_rows
    try:
        if scope == "full":
            items, _, context = source_reader.build_acore_items(source, spell_sql=spell_sql, spell_table=spell_table)
            diagnostics = context.get("sourceDiagnostics", {})
            spell_coverage = context.get("spellCoverage", {})
        else:
            rows, _ = source_reader.load_keyed_table(source, "item_template", "entry")
            items = {item_id: {"name": row.get("name"), "startQuest": int(row.get("startquest") or 0)}
                     for item_id, row in rows.items()}
    finally:
        source_reader.load_row_table = original
    if source_signature(source, scope, spell_sql, spell_table) != signature:
        raise ValueError("Source inputs changed during extraction; report/cache were not published")
    saved = {"signature": signature, "items": {str(key): row for key, row in sorted(items.items())},
             "templateIds": template_ids, "tableCoverage": coverage, "sourceDiagnostics": diagnostics,
             "spellCoverage": spell_coverage}
    saved["modelSha256"] = model_digest(saved)
    write_json(cache, saved)
    return saved


def audit_starts(items, source, template_ids):
    rows, counts = [], Counter()
    for item_id, current in sorted(items.items()):
        expected = int(source.get(item_id, {}).get("startQuest") or 0) if item_id in template_ids else None
        value = current.get("s:startQuest", ABSENT)
        if expected is None:
            status = "missingSourceTemplate"
        elif normalized("startQuest", value) == expected:
            status = "matchesSource" if expected else "noStartOnEitherSide"
        else:
            status = "differsFromSource"
        counts[status] += 1
        if status != "noStartOnEitherSide":
            rows.append({"itemId": item_id, "status": status, "fieldPresent": value is not ABSENT,
                         "current": None if value is ABSENT else value, "source": expected})
    return {"counts": dict(sorted(counts.items())), "entries": rows,
            "sourceOnlyStartItemIds": sorted(item_id for item_id in template_ids - set(items)
                                              if int(source.get(item_id, {}).get("startQuest") or 0) > 0)}


def compare_fields(items, fields, source, template_ids, scope, manual):
    reports = {}
    active = set(source_reader.FIELD_ORDER if scope == "full" else ["startQuest"])
    for field in fields:
        key, stats, differences = "s:" + field, Counter(), []
        if field not in active:
            reports[field] = {"status": "unsupportedByCurrentSourceReader" if field not in source_reader.FIELD_ORDER else "outsideSelectedScope",
                              "presentItemIds": sorted(item_id for item_id, row in items.items() if key in row)}
            continue
        for item_id, current in sorted(items.items()):
            if item_id not in template_ids:
                stats["missingSourceTemplate"] += 1
                continue
            raw = source[item_id]
            if field in source_reader.STATIC_FIELD_MAP and field not in raw:
                stats["missingSourceField"] += 1
                differences.append({"itemId": item_id, "review": "missingSourceField",
                                    "snapshotPresent": key in current, "snapshot": current.get(key)})
                continue
            raw_value = raw.get(field, [] if field in source_reader.LIST_FIELDS else ("" if field == "name" else 0))
            expected = raw_value
            if field == "class" and (raw.get("isStartItem") or int(raw.get("startQuest") or 0) > 0):
                expected = 12
                stats["candidateQuestItemClassRule"] += 1
            expected = typed(expected)
            actual = current.get(key, ABSENT)
            if same_value(actual, expected):
                stats["exactMatches"] += 1
            elif normalized(field, actual) == normalized(field, expected):
                stats["representationOnly"] += 1
            else:
                stats["valueDifferences"] += 1
                references = [path for path, entries in manual.items() if field in entries.get(item_id, {})]
                differences.append({"itemId": item_id, "snapshotPresent": actual is not ABSENT,
                                    "snapshot": None if actual is ABSENT else actual,
                                    "sourceExpected": expected, "sourceRaw": typed(raw_value),
                                    "manualReferences": references,
                                    "review": "classificationRuleOrSupplement" if field == "class" else
                                              ("sourceCoverageOrDisplaySupplement" if field in source_reader.LIST_FIELDS else "sourceValueOrManualException")})
        reports[field] = {"status": "compared", "counts": dict(stats), "differences": differences}
    return reports


def review_supplements(items, source, template_ids, manual):
    """Inventory baseline behavior to retain or investigate, without approving removals.

    Vendor/container evidence proves an alternate acquisition path in this model;
    it does not prove that removing the old Questie field is behavior-neutral.
    """
    source_rows, classes, partial = [], [], []

    def container_paths(item_id, field, active=frozenset()):
        if item_id in active:
            return {}
        paths = {}
        for container in source.get(item_id, {}).get("itemDrops", []):
            if container in active or container == item_id:
                continue
            for source_id in source.get(container, {}).get(field, []):
                paths.setdefault(source_id, [container])
            for source_id, path in container_paths(container, field, active | {item_id}).items():
                paths.setdefault(source_id, [container, *path])
        return paths

    for item_id, current in sorted(items.items()):
        if item_id not in template_ids:
            continue
        raw = source[item_id]
        absent = [field for field in ("name", "class", "itemLevel") if "s:" + field not in current]
        if absent:
            partial.append({"itemId": item_id, "name": raw.get("name"), "missingFields": absent})
        if "s:class" in current and "class" in raw and current["s:class"] != raw["class"]:
            classes.append({"itemId": item_id, "name": raw.get("name"), "current": current["s:class"],
                            "source": raw["class"], "decision": "retainExistingClassOverride",
                            "manualReferences": [path for path, entries in manual.items()
                                                 if "class" in entries.get(item_id, {})]})
        for field in ("npcDrops", "objectDrops"):
            existing = set(normalized(field, current.get("s:" + field, ABSENT)))
            direct = set(raw.get(field, []))
            removed = existing - direct
            if not removed:
                continue
            containers = container_paths(item_id, field)
            vendors = set(raw.get("vendors", [])) if field == "npcDrops" else set()
            links = []
            for source_id in sorted(removed):
                evidence = []
                if source_id in vendors:
                    evidence.append({"kind": "alsoVendor"})
                if source_id in containers:
                    evidence.append({"kind": "containerSource", "containerPath": containers[source_id]})
                links.append({"sourceId": source_id, "evidence": evidence,
                              "status": "alternatePathFound" if evidence else "needsSourceInvestigation"})
            source_rows.append({"itemId": item_id, "name": raw.get("name"), "field": field,
                                "decision": "retainPendingReview", "missingSourceIds": sorted(removed),
                                "sourceIds": sorted(direct), "links": links,
                                "relatedQuests": raw.get("relatedQuests", []),
                                "manualReferences": [path for path, entries in manual.items()
                                                     if field in entries.get(item_id, {})]})
    return {
        "policy": {"class": "Use raw AzerothCore class plus explicit existing overrides; do not force class 12 for all start items.",
                   "sourceLinks": "Retain unmatched existing links until reviewed; evidence is not permission to remove them.",
                   "partialRecords": "Review incomplete existing records separately; do not fill them silently during parity migration."},
        "counts": {"sourceFieldEntries": len(source_rows),
                   "sourceLinks": sum(len(row["links"]) for row in source_rows),
                   "sourceFields": dict(Counter(row["field"] for row in source_rows)),
                   "linkStatuses": dict(Counter(link["status"] for row in source_rows for link in row["links"])),
                   "classOverrides": len(classes), "partialRecords": len(partial)},
        "sourceEntries": source_rows, "classOverrides": classes, "partialRecords": partial,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True, help="Fresh capture from the current checkout")
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
    parser.add_argument("--scope", choices=("starts", "full"), default="starts")
    parser.add_argument("--spell-sql", type=Path, help="Full Spell.dbc SQL export; requires --scope full")
    parser.add_argument("--spell-table", default="spell", help="Table in --spell-sql (default: spell)")
    parser.add_argument("--report", type=Path, default=Path("tools/reports/acore_item_source_audit.json"))
    parser.add_argument("--source-cache", type=Path, help="Validated local source-model cache; defaults to a file per scope")
    parser.add_argument("--refresh-source", action="store_true", help="Rebuild even when the cached inputs match")
    args = parser.parse_args(argv)
    if args.spell_sql is not None and args.scope != "full":
        parser.error("--spell-sql requires --scope full")
    if args.spell_sql is not None:
        args.spell_sql = args.spell_sql.resolve()
        if not args.spell_sql.is_file():
            parser.error(f"Spell SQL export not found: {args.spell_sql}")
    root, source_root = args.repo.resolve(), args.acore_source.resolve()
    report_path = local_output(root, args.report)
    cache = local_output(root, args.source_cache or Path(f"tools/reports/acore_item_source_model_{args.scope}.json"))
    if report_path == cache or report_path == args.snapshot.resolve() or cache == args.snapshot.resolve():
        raise ValueError("Snapshot, report, and cache must use different paths")
    print("Validating snapshot and item contexts...", flush=True)
    reference_digest = snapshot.file_hash(args.snapshot)
    items, fields, overrides, metadata = read_items(args.snapshot, root)
    signature = source_signature(source_root, args.scope, args.spell_sql, args.spell_table)
    saved = load_source(source_root, args.scope, signature, cache, args.refresh_source, args.spell_sql, args.spell_table)
    source = {int(key): row for key, row in saved["items"].items()}
    template_ids = set(saved["templateIds"])
    keys = source_reader.parse_item_keys(root / "Database/itemDB.lua")
    manual = {path: source_reader.load_lua_item_corrections(root / path, keys)
              for path in source_reader.ITEM_CORRECTION_FILES if (root / path).is_file()}
    report = {
        "scope": args.scope, "snapshot": str(args.snapshot.resolve()), "snapshotSha256": reference_digest,
        "snapshotGit": metadata.get("git"), "sourceInputs": signature,
        "counts": {"snapshotItems": len(items), "sourceModelItems": len(source), "sourceTemplates": len(template_ids),
                   "itemSchemaFields": len(fields)},
        "itemStarts": audit_starts(items, source, template_ids),
        "fields": compare_fields(items, fields, source, template_ids, args.scope, manual),
        "fieldSources": {
            **{field: ["item_template." + column] for field, column in source_reader.STATIC_FIELD_MAP.items()},
            "npcDrops": ["creature_loot_template", "reference_loot_template", "creature_template.lootid", "npc_spellclick_spells",
                         *(["Spell.dbc SQL export"] if args.spell_sql else []), "spell_dbc (SQL numeric overrides)"],
            "objectDrops": ["gameobject_loot_template", "reference_loot_template", "gameobject_template (types 3/25)"],
            "itemDrops": ["item_loot_template", "reference_loot_template"], "startQuest": ["item_template.startquest"],
            "questRewards": ["quest_template.RewardItem*", "quest_template.RewardChoiceItemID*"],
            "vendors": ["npc_vendor", "game_event_npc_vendor", "creature.guid -> entry"],
            "relatedQuests": ["quest_template.StartItem", "quest_template.ItemDrop*", "quest_template.RequiredItemId*"],
            "teachesSpell": ["No rule in current source reader; requires explicit coverage decision"],
        },
        "snapshotOnlyIds": sorted(set(items) - template_ids), "sourceOnlyIds": sorted(template_ids - set(items)),
        "relationOnlySourceIds": sorted(set(source) - template_ids), "tableCoverage": saved["tableCoverage"],
        "sourceDiagnostics": saved.get("sourceDiagnostics", {}),
        "spellCoverage": saved.get("spellCoverage", {}),
        "supplementReview": review_supplements(items, source, template_ids, manual) if args.scope == "full" else None,
        "factionOverrides": overrides,
        "limitations": ["Loot probabilities describe base SQL rules, without player conditions, script hooks, or server rates.",
                        "Spell-click sources cover direct item creation; arbitrary scripts and spell-loot crafting need separate coverage.",
                        "teachesSpell is outside the existing source reader's field set.",
                        "Class comparison uses the existing generator's proposed quest-item rule; mismatches require review.",
                        "List comparison ignores order/duplicates; representation-only counts are separate from value differences.",
                        "Modules, pending updates, live custom SQL, and other client DBC tables are outside this scan.",
                        "Without --spell-sql, spell coverage is limited to the AzerothCore SQL spell_dbc table.",
                        "Manual references identify old definitions, not proof that their values are correct.",
                        "Source-only records are candidates for scope review, not instructions to import every item."],
    }
    # Reject addon changes made while the source scan was running.
    for name, digest in metadata["sources"].items():
        if snapshot.file_hash(root / name) != digest:
            raise ValueError(f"Addon changed during audit: {name}")
    if snapshot.file_hash(args.snapshot) != reference_digest or source_signature(source_root, args.scope, args.spell_sql, args.spell_table) != signature:
        raise ValueError("Snapshot or source inputs changed during audit")
    write_json(report_path, report)
    summary = {"scope": args.scope, "counts": report["counts"], "itemStarts": report["itemStarts"]["counts"],
               "fields": {field: row.get("counts", {"status": row["status"]}) for field, row in report["fields"].items()},
               "snapshotOnlyItems": len(report["snapshotOnlyIds"]), "sourceOnlyItems": len(report["sourceOnlyIds"]),
               "relationOnlySourceItems": len(report["relationOnlySourceIds"]), "tableCoverage": {
                   table: {key: value for key, value in row.items() if key != "zeroChanceGroupedItemIds"}
                   for table, row in report["tableCoverage"].items()},
               "sourceDiagnostics": {kind: len(values) for kind, values in report["sourceDiagnostics"].items()},
               "spellCoverage": report["spellCoverage"],
               "supplementReview": report["supplementReview"]["counts"] if report["supplementReview"] else None}
    print(json.dumps(summary, indent=2))
    print(f"Report: {report_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, EOFError, KeyError) as exc:
        raise SystemExit(f"Item source audit failed: {exc}")
