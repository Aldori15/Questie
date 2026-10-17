"""Generate an item-base candidate from AzerothCore and explicit compatibility data.

bootstrap reads a verified snapshot once to freeze item scope, selected source
links, representations, class exceptions and partial records. generate needs no inherited base,
correction Lua, snapshot or migration zip; --compare-snapshot is review only.
All Lua outputs stay in tools/reports until the candidate has been reviewed.
"""
import argparse
from collections import Counter
import copy
import json
from pathlib import Path

import audit_acore_item_sources as audit
import db_snapshot
from generate_acore_full_base import LuaBlobWriter, lua_quote, row_to_lua


ROOT = Path(__file__).resolve().parents[1]
FIELDS = tuple(audit.source_reader.FIELD_ORDER) + ("teachesSpell",)
KEYS = {"s:" + field: index for index, field in enumerate(FIELDS, 1)}
REQUIRED_SCALARS = {"name", "itemLevel", "requiredLevel", "ammoType", "class", "subClass"}
SOURCE_FIELDS = {"npcDrops", "objectDrops"}
DEFAULT_MANIFEST = Path("tools/data/acore_item_compatibility.json")


def positive_id(value):
    return type(value) is int and value > 0


def pack_selection(value):
    audit.normalized("npcDrops", value)  # Validate typed numeric-list data.
    if set(value) == {f"n:{i}" for i in range(1, len(value) + 1)}:
        return [value[f"n:{i}"] for i in range(1, len(value) + 1)]
    return copy.deepcopy(value)  # Preserve sparse Lua keys too.


def unpack_selection(value):
    return audit.typed(value) if isinstance(value, list) else copy.deepcopy(value)


def link_counts(records):
    counts = Counter()
    for row in records.values():
        for field in audit.source_reader.LIST_FIELDS:
            counts[field] += len(row.get("s:" + field, {}))
    return dict(sorted(counts.items()))


def make_manifest(items, source, metadata, snapshot_sha, signature):
    entries, partial, selections = {}, {}, {}
    for item_id, current in sorted(items.items()):
        if item_id not in source:
            raise ValueError(f"Baseline item {item_id} has no source template")
        raw, entry = source[item_id], {}
        if any("s:" + field not in current for field in ("name", "class", "itemLevel")):
            # Keep these deliberately incomplete baseline rows intact for now.
            partial[str(item_id)] = copy.deepcopy(current)
            continue
        added = {}
        for field in sorted(SOURCE_FIELDS):
            existing = set(audit.normalized(field, current.get("s:" + field, audit.ABSENT)))
            missing = sorted(existing - set(raw.get(field, [])))
            if missing:
                added[field] = missing
        if added:
            entry["addSources"] = added
        if current["s:class"] != raw.get("class"):
            if type(raw.get("class")) is not int:
                raise ValueError(f"Missing source class for item {item_id}")
            entry["classOverride"] = {"value": current["s:class"], "expectedSource": raw["class"]}
        if "s:teachesSpell" in current:
            raise ValueError(f"Item {item_id} has teachesSpell data; define its generation rule before proceeding")
        selected = {field: pack_selection(current["s:" + field])
                    for field in sorted(audit.source_reader.LIST_FIELDS) if "s:" + field in current}
        if selected:
            selections[str(item_id)] = selected
        representations = {}
        canonical = source_record(raw, include_lists=False)
        if "classOverride" in entry:
            canonical["s:class"] = entry["classOverride"]["value"]
        for field in FIELDS:
            if field in audit.source_reader.LIST_FIELDS:
                continue
            actual, generated = current.get("s:" + field, audit.ABSENT), canonical.get("s:" + field, audit.ABSENT)
            if not audit.same_value(actual, generated):
                if audit.normalized(field, actual) != audit.normalized(field, generated):
                    raise ValueError(f"Uncovered baseline scalar difference: item {item_id}, {field}")
                representations[field] = {"present": actual is not audit.ABSENT}
                if actual is not audit.ABSENT:
                    representations[field]["value"] = actual
        if representations:
            entry["representations"] = representations
        if entry:
            entry["reason"] = "Preserve existing Questie behavior during source migration; not proof of direct server loot."
            entries[str(item_id)] = entry
    size = candidate_size(items)
    return {"format": "questie-acore-item-compatibility", "version": 2,
            "provenance": {"snapshotSha256": snapshot_sha, "snapshotCommit": (metadata.get("git") or {}).get("commit"),
                           "acoreCommit": signature.get("sourceRevision"),
                           "spellExportSha256": signature["spellExport"]["sha256"]},
            "scopePolicy": "Preserve existing item and relationship scope, field presence, order and sparse keys; new sources require explicit review.",
            "limits": {"maxOutputBytes": size + max(65536, size // 20), "sourceLinks": link_counts(items)},
            "itemIds": sorted(items), "sourceSelections": selections, "entries": entries, "partialRecords": partial}


def validate_manifest(manifest):
    if manifest.get("format") != "questie-acore-item-compatibility" or manifest.get("version") != 2:
        raise ValueError("Unsupported item compatibility manifest; rebuild it once with bootstrap --force for exact parity")
    ids = manifest.get("itemIds")
    if not isinstance(ids, list) or not ids or not all(positive_id(i) for i in ids) or ids != sorted(set(ids)):
        raise ValueError("Manifest itemIds must be sorted unique positive integers")
    scope = set(ids)
    for section in ("entries", "partialRecords", "sourceSelections"):
        if not isinstance(manifest.get(section), dict):
            raise ValueError(f"Missing manifest {section}")
        for key, entry in manifest[section].items():
            if not key.isdecimal() or str(int(key)) != key or int(key) not in scope or not isinstance(entry, dict):
                raise ValueError(f"Invalid {section} item ID or entry: {key}")
    if set(manifest["entries"]) & set(manifest["partialRecords"]):
        raise ValueError("Partial records must not also have compatibility entries")
    if set(manifest["sourceSelections"]) & set(manifest["partialRecords"]):
        raise ValueError("Partial records must not also have source selections")
    for key, fields in manifest["sourceSelections"].items():
        if not set(fields) <= audit.source_reader.LIST_FIELDS:
            raise ValueError(f"Unknown selected source field for item {key}")
        for value in fields.values():
            if not isinstance(value, (list, dict)):
                raise ValueError(f"Invalid source selection for item {key}")
            typed = unpack_selection(value)
            audit.normalized("npcDrops", typed)
            if not all(positive_id(v) for v in typed.values()):
                raise ValueError(f"Invalid selected source ID for item {key}")
    limits = manifest.get("limits", {})
    if not positive_id(limits.get("maxOutputBytes")) or set(limits.get("sourceLinks", {})) != audit.source_reader.LIST_FIELDS:
        raise ValueError("Manifest lacks output size and source-link limits")
    if any(type(n) is not int or n < 0 for n in limits["sourceLinks"].values()):
        raise ValueError("Invalid source-link limits")
    for key, entry in manifest["entries"].items():
        if set(entry) - {"reason", "addSources", "classOverride", "representations"} or not entry.get("reason"):
            raise ValueError(f"Invalid compatibility entry: {key}")
        for field, values in entry.get("addSources", {}).items():
            if field not in SOURCE_FIELDS or not isinstance(values, list) or not values or not all(positive_id(i) for i in values) or values != sorted(set(values)):
                raise ValueError(f"Invalid additive source list for item {key}")
        if "classOverride" in entry:
            override = entry["classOverride"]
            if set(override) != {"value", "expectedSource"} or any(type(v) is not int or v < 0 for v in override.values()):
                raise ValueError(f"Invalid class override for item {key}")
        for field, representation in entry.get("representations", {}).items():
            if field not in FIELDS or field in audit.source_reader.LIST_FIELDS or not isinstance(representation, dict):
                raise ValueError(f"Invalid scalar representation for item {key}")
            if type(representation.get("present")) is not bool or set(representation) != ({"present", "value"} if representation["present"] else {"present"}):
                raise ValueError(f"Invalid field presence for item {key}")
            if representation["present"]:
                audit.normalized(field, representation["value"])
    for key, row in manifest["partialRecords"].items():
        if not row or not set(row) <= set(KEYS):
            raise ValueError(f"Invalid partial record for item {key}")
        row_to_lua(row, KEYS)  # Also reject invalid typed Lua values.
    return manifest


def source_record(raw, include_lists=True):
    row = {}
    for field in FIELDS:
        if field == "teachesSpell":
            continue  # Explicitly checked during bootstrap; reader has no rule yet.
        if field in REQUIRED_SCALARS and field not in raw:
            raise ValueError(f"Source item lacks required field {field}")
        value = raw.get(field)
        if field in audit.source_reader.LIST_FIELDS:
            if include_lists and value:
                row["s:" + field] = audit.typed(sorted(set(value)))
        elif field in REQUIRED_SCALARS or value not in (None, 0, ""):
            row["s:" + field] = audit.typed(value)
    return row


def build_records(source, manifest):
    validate_manifest(manifest)
    records, redundant = {}, []
    for item_id in manifest["itemIds"]:
        if item_id not in source:
            raise ValueError(f"Scoped item {item_id} has no AzerothCore template; review scope")
        key, raw = str(item_id), source[item_id]
        if key in manifest["partialRecords"]:
            records[item_id] = copy.deepcopy(manifest["partialRecords"][key])
            continue
        row = source_record(raw, include_lists=False)
        entry = manifest["entries"].get(key, {})
        for field, values in entry.get("addSources", {}).items():
            direct = set(raw.get(field, []))
            overlap = sorted(direct & set(values))
            if overlap:
                redundant.append({"itemId": item_id, "field": field, "sourceIds": overlap})
        # Each relationship must be selected explicitly. New SQL relationships
        # remain audit findings; they must never expand addon tables implicitly.
        for field, selection in manifest["sourceSelections"].get(key, {}).items():
            selected = unpack_selection(selection)
            supported = set(raw.get(field, [])) | set(entry.get("addSources", {}).get(field, []))
            missing = set(selected.values()) - supported
            if missing:
                raise ValueError(f"Selected {field} sources changed for item {item_id}: {sorted(missing)}; review scope")
            row["s:" + field] = selected
        if "classOverride" in entry:
            override = entry["classOverride"]
            if raw["class"] != override["expectedSource"]:
                raise ValueError(f"Source class changed for item {item_id}; review its explicit compatibility override")
            row["s:class"] = override["value"]
        for field, representation in entry.get("representations", {}).items():
            expected = representation.get("value", audit.ABSENT)
            current = row.get("s:" + field, audit.ABSENT)
            if audit.normalized(field, expected) != audit.normalized(field, current):
                raise ValueError(f"Source value changed for represented field {field}, item {item_id}; review representation")
            if representation["present"]:
                row["s:" + field] = copy.deepcopy(expected)
            else:
                row.pop("s:" + field, None)
        records[item_id] = row
    for field, count in link_counts(records).items():
        if count > manifest["limits"]["sourceLinks"][field]:
            raise ValueError(f"Source-link budget exceeded for {field}; review scope before increasing the limit")
    return records, redundant


def compare_candidate(before, after):
    if before.keys() != after.keys():
        raise ValueError("Candidate scope differs from comparison snapshot")
    counts, differences, unexpected = Counter(), [], []
    for item_id, old in sorted(before.items()):
        for field in FIELDS:
            a, b = old.get("s:" + field, audit.ABSENT), after[item_id].get("s:" + field, audit.ABSENT)
            if audit.same_value(a, b):
                continue
            if audit.normalized(field, a) == audit.normalized(field, b):
                kind = "representationOnly"
            elif field in audit.source_reader.LIST_FIELDS:
                previous, current = set(audit.normalized(field, a)), set(audit.normalized(field, b))
                kind = "sourceAdditions" if previous <= current else "sourceRemovals"
            else:
                kind = "valueChange"
            counts[kind] += 1
            row = {"itemId": item_id, "field": field, "kind": kind,
                   "before": None if a is audit.ABSENT else a, "after": None if b is audit.ABSENT else b,
                   "beforePresent": a is not audit.ABSENT, "afterPresent": b is not audit.ABSENT}
            differences.append(row)
            unexpected.append(row)
    return {"counts": dict(counts), "differences": differences, "unexpectedChanges": unexpected,
            "exactParity": not counts, "normalizedParity": not any(row["kind"] != "representationOnly" for row in differences)}


def write_candidate(path, records):
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        write_candidate_stream(stream, records)


def write_candidate_stream(stream, records):
    stream.write('-- Generated from AzerothCore source and explicit Questie compatibility data.\n')
    stream.write('-- Generator: tools/generate_acore_item_base.py\n')
    stream.write('local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n\nQuestieDB.itemKeys = {\n')
    for field, index in KEYS.items():
        stream.write(f'    [{lua_quote(field[2:])}] = {index},\n')
    stream.write('}\n\n')
    writer = LuaBlobWriter(stream, "itemData")
    for item_id, row in sorted(records.items()):
        writer.write(f'[{item_id}]={row_to_lua(row, KEYS)},\n')
    writer.finish()


def candidate_size(records):
    class ByteCounter:
        size = 0

        def write(self, text):
            self.size += len(text.encode("utf-8"))

    counter = ByteCounter()
    write_candidate_stream(counter, records)
    return counter.size


def enforce_size(size, manifest):
    if size > manifest["limits"]["maxOutputBytes"]:
        raise ValueError(f"Candidate is {size} bytes, exceeding the baseline size budget; review expansion")


def write_manifest(path, manifest):
    # Keep numeric lists compact and one item entry per line for reviewable diffs.
    path.parent.mkdir(parents=True, exist_ok=True)
    with db_snapshot.temporary_directory(path.parent) as directory:
        candidate = directory / "manifest.json"
        with candidate.open("w", encoding="utf-8", newline="\n") as stream:
            stream.write('{\n')
            sections = list(manifest.items())
            for index, (key, value) in enumerate(sections):
                stream.write('  ' + json.dumps(key) + ': ')
                if key in {"entries", "partialRecords", "sourceSelections"}:
                    stream.write('{\n')
                    rows = list(value.items())
                    for offset, (item_id, row) in enumerate(rows):
                        stream.write('    ' + json.dumps(item_id) + ': ' + json.dumps(row, ensure_ascii=True, separators=(',', ':')))
                        stream.write(',\n' if offset + 1 < len(rows) else '\n')
                    stream.write('  }')
                else:
                    stream.write(json.dumps(value, ensure_ascii=True, separators=(',', ':')))
                stream.write(',\n' if index + 1 < len(sections) else '\n')
            stream.write('}\n')
        candidate.replace(path)


def output_path(path, directory, suffix):
    path = (ROOT / path).resolve()
    if not path.is_relative_to(ROOT / directory) or path.suffix != suffix:
        raise ValueError(f"Output must be a {suffix} file under {directory}")
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("bootstrap", "generate"):
        command = commands.add_parser(name)
        command.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
        command.add_argument("--spell-sql", type=Path, required=True)
        command.add_argument("--spell-table", default="spell")
        command.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_item_source_model_full.json"))
        command.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
        command.add_argument("--force", action="store_true", help="Replace an existing output")
    commands.choices["bootstrap"].add_argument("--snapshot", type=Path, required=True)
    generate = commands.choices["generate"]
    generate.add_argument("--compare-snapshot", type=Path, help="Review only; never used to construct candidate records")
    generate.add_argument("--output", type=Path, default=Path("tools/reports/acore-item-candidate/acoreItemDB.lua"))
    generate.add_argument("--report", type=Path, default=Path("tools/reports/acore_item_base_candidate.json"))
    args = parser.parse_args(argv)
    root, spell = args.acore_source.resolve(), args.spell_sql.resolve()
    cache = audit.local_output(ROOT, args.source_cache)
    manifest_path = output_path(args.manifest, "tools/data", ".json")
    if args.command == "bootstrap":
        targets = [manifest_path]
    else:
        output = output_path(args.output, "tools/reports", ".lua")
        report = output_path(args.report, "tools/reports", ".json")
        targets = [output, report]
    snapshot_path = args.snapshot if args.command == "bootstrap" else args.compare_snapshot
    inputs = {cache, spell, *([snapshot_path.resolve()] if snapshot_path else [])}
    if args.command == "generate":
        inputs.add(manifest_path)
    if len(set(targets)) != len(targets) or any(path in inputs for path in targets):
        raise ValueError("Outputs must use different paths from inputs and the source cache")
    if any(path.exists() for path in targets) and not args.force:
        raise ValueError("Output already exists; review it or explicitly use --force")
    signature = audit.source_signature(root, "full", spell, args.spell_table)
    saved = audit.load_source(root, "full", signature, cache, spell_sql=spell, spell_table=args.spell_table)
    source = {int(key): row for key, row in saved["items"].items()}
    if set(source) != set(saved["templateIds"]):
        raise ValueError("Source model must contain exactly the valid item templates")
    reference, metadata, baseline_digest = None, None, None
    if snapshot_path:
        baseline_digest = db_snapshot.file_hash(snapshot_path)
        reference, fields, _, metadata = audit.read_items(snapshot_path, ROOT)
        if tuple(fields) != FIELDS:
            raise ValueError("Snapshot item schema does not match the exporter")
    if args.command == "bootstrap":
        manifest = validate_manifest(make_manifest(reference, source, metadata, baseline_digest, signature))
        records, _ = build_records(source, manifest)
        comparison = compare_candidate(reference, records)
        if comparison["unexpectedChanges"]:
            raise ValueError("Uncovered baseline changes; compatibility manifest was not written")
        payload = manifest
        summary = {"manifest": str(manifest_path), "items": len(records), "compatibilityEntries": len(manifest["entries"]),
                   "classOverrides": sum("classOverride" in row for row in manifest["entries"].values()),
                   "partialRecords": len(manifest["partialRecords"]), "candidateDifferences": comparison["counts"],
                   "exactParity": comparison["exactParity"]}
    else:
        manifest_digest = db_snapshot.file_hash(manifest_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        records, redundant = build_records(source, manifest)
        comparison = compare_candidate(reference, records) if reference is not None else None
        payload = {"sourceInputs": signature, "manifestSha256": manifest_digest, "items": len(records),
                   "excludedSourceItemIds": sorted(set(source) - set(records)), "redundantSupplements": redundant,
                   "comparisonSnapshotSha256": baseline_digest, "comparison": comparison,
                   "sourceLinks": link_counts(records), "maxOutputBytes": manifest["limits"]["maxOutputBytes"],
                   "filteredSourceLinks": {field: sum(len(set(source[item_id].get(field, [])) -
                                                              set(records[item_id].get("s:" + field, {}).values()))
                                                       for item_id in records)
                                           for field in sorted(audit.source_reader.LIST_FIELDS)}}
        if comparison and comparison["unexpectedChanges"]:
            audit.write_json(report, payload)
            raise ValueError(f"Unexpected changes detected; review {report}. Lua candidate was not written")
        summary = {"output": str(output), "report": str(report), "items": len(records),
                   "excludedSourceItems": len(payload["excludedSourceItemIds"]),
                   "differences": comparison["counts"] if comparison else "not compared",
                   "exactParity": comparison["exactParity"] if comparison else None}
        if db_snapshot.file_hash(manifest_path) != manifest_digest:
            raise ValueError("Compatibility manifest changed during generation")
    if audit.source_signature(root, "full", spell, args.spell_table) != signature:
        raise ValueError("Source inputs changed during generation")
    if snapshot_path and (db_snapshot.file_hash(snapshot_path) != baseline_digest or
                          any(db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items())):
        raise ValueError("Comparison snapshot or addon inputs changed during generation")
    if args.command == "bootstrap":
        write_manifest(manifest_path, payload)
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        with db_snapshot.temporary_directory(output.parent) as directory:
            candidate = directory / "acoreItemDB.lua"
            write_candidate(candidate, records)
            enforce_size(candidate.stat().st_size, manifest)
            payload["outputBytes"] = candidate.stat().st_size
            summary["outputMiB"] = round(candidate.stat().st_size / (1024 * 1024), 2)
            payload["outputSha256"] = db_snapshot.file_hash(candidate)
            audit.write_json(report, payload)
            candidate.replace(output)
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit(f"Item base generation failed: {exc}")
