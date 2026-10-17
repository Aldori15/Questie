"""Build an NPC-base candidate from AC source and explicit compatibility policy.

bootstrap reads the verified baseline once. generate does not read legacy bases,
correction Lua or a snapshot to construct records. Geometry is selected in its
existing order; unknown points, source-only NPCs and new quest links stay out.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

import audit_acore_item_sources as shared
import audit_acore_npc_sources as audit
import db_snapshot
from generate_acore_full_base import LuaBlobWriter, lua_quote, row_to_lua


ROOT = Path(__file__).resolve().parents[1]
FIELDS = tuple(audit.reader.FIELD_ORDER)
KEYS = {"s:" + field: index for index, field in enumerate(FIELDS, 1)}
DISPLAY_FIELDS = {"minLevelHealth", "maxLevelHealth", "zoneID"}
GEOMETRY_FIELDS = {"spawns", "waypoints"}
RELATION_FIELDS = {"questStarts", "questEnds"}
DEFAULT_MANIFEST = Path("tools/data/acore_npc_compatibility.json")


def value_hash(value):
    def canonical(v):
        if v is shared.ABSENT:
            return {"absent": True}
        if isinstance(v, dict):
            return {key: canonical(child) for key, child in v.items()}
        if type(v) is float and math.isfinite(v) and v.is_integer():
            return int(v)
        return v
    return hashlib.sha256(json.dumps(canonical(value), sort_keys=True, ensure_ascii=True,
                                     allow_nan=False, separators=(",", ":")).encode()).hexdigest()


def encode_geometry(current, source):
    if not isinstance(current, dict):
        return {"wholeValue": copy.deepcopy(current), "expectedSource": value_hash(source)}
    zones = {}
    for zone, units in current.items():
        if not isinstance(units, dict) or any(not key.startswith("n:") or not key[2:].isdigit() or int(key[2:]) < 1 for key in units):
            return {"wholeValue": copy.deepcopy(current), "expectedSource": value_hash(source)}
        raw = source.get(zone, shared.ABSENT) if isinstance(source, dict) else shared.ABSENT
        lookup = {value_hash(value): int(key[2:]) for key, value in (raw.items() if isinstance(raw, dict) else [])
                  if key.startswith("n:") and key[2:].isdigit() and int(key[2:]) > 0}
        keys = sorted(units, key=lambda key: int(key[2:]))
        refs, extras = [], {}
        for index, key in enumerate(keys, 1):
            ref = lookup.get(value_hash(units[key]), 0)
            refs.append(ref)
            if not ref:
                extras[str(index)] = copy.deepcopy(units[key])
        recipe = {"expectedSource": value_hash(raw), "refs": refs}
        if extras:
            recipe["extras"] = extras
        if keys != [f"n:{i}" for i in range(1, len(keys) + 1)]:
            recipe["keys"] = keys
        zones[zone] = recipe
    return {"zones": zones}


def decode_geometry(recipe, source):
    if "wholeValue" in recipe:
        if value_hash(source) != recipe["expectedSource"]:
            raise ValueError("Source geometry changed behind a full compatibility value; review it")
        return copy.deepcopy(recipe["wholeValue"])
    result = {}
    for zone, selection in recipe["zones"].items():
        raw = source.get(zone, shared.ABSENT) if isinstance(source, dict) else shared.ABSENT
        if value_hash(raw) != selection["expectedSource"]:
            raise ValueError(f"Source geometry changed in zone {zone}; review selection before regeneration")
        keys = selection.get("keys", [f"n:{i}" for i in range(1, len(selection["refs"]) + 1)])
        if len(keys) != len(selection["refs"]) or len(set(keys)) != len(keys):
            raise ValueError("Invalid geometry selection keys")
        points = {}
        for index, (key, ref) in enumerate(zip(keys, selection["refs"]), 1):
            if type(ref) is not int or ref < 0:
                raise ValueError("Invalid geometry reference")
            if ref:
                if not isinstance(raw, dict) or f"n:{ref}" not in raw:
                    raise ValueError("Selected source point/path is missing")
                value = raw[f"n:{ref}"]
            else:
                value = selection.get("extras", {}).get(str(index), shared.ABSENT)
                if value is shared.ABSENT:
                    raise ValueError("Missing explicit geometry supplement")
            points[key] = copy.deepcopy(value)
        result[zone] = points
    return result


def make_manifest(records, source, metadata, snapshot_sha, signature):
    scope, display, geometry, relations, overrides, extras = {}, {}, {}, {}, {}, {}
    for npc_id, current in sorted(records.items()):
        if not current or not set(current) <= set(KEYS):
            raise ValueError(f"Invalid baseline NPC {npc_id}")
        key = str(npc_id)
        scope[key] = sum(1 << (KEYS[field] - 1) for field in current)
        if npc_id not in source:
            extras[key] = copy.deepcopy(current)
            continue
        raw = source[npc_id]
        for field in FIELDS:
            typed_key = "s:" + field
            if typed_key not in current:
                continue
            actual, expected = current[typed_key], raw.get(typed_key, shared.ABSENT)
            if field in DISPLAY_FIELDS:
                display.setdefault(key, {})[field] = copy.deepcopy(actual)
            elif field in GEOMETRY_FIELDS:
                geometry.setdefault(key, {})[field] = encode_geometry(actual, expected)
            elif field in RELATION_FIELDS:
                if not isinstance(actual, dict) or not isinstance(expected, dict) or not set(actual.values()) <= set(expected.values()):
                    raise ValueError(f"Uncovered quest relation for NPC {npc_id}; review before bootstrap")
                relations.setdefault(key, {})[field] = copy.deepcopy(actual)
            elif not shared.same_value(actual, expected):
                overrides.setdefault(key, {})[field] = {"value": copy.deepcopy(actual), "expectedSource": value_hash(expected)}
    size = candidate_size(records)
    return {"format": "questie-acore-npc-compatibility", "version": 1,
            "provenance": {"snapshotSha256": snapshot_sha, "snapshotCommit": (metadata.get("git") or {}).get("commit"),
                           "acoreCommit": signature.get("sourceRevision")},
            "policy": "Keep existing record/field/geometry/relation scope; preserve legacy display health, display zone and explicit exceptions.",
            "limits": {"maxOutputBytes": size + max(65536, size // 20), "geometry": audit.geometry_inventory(records)},
            "scope": scope, "displayValues": display, "geometry": geometry, "relations": relations,
            "overrides": overrides, "extraRecords": extras}


def validate_manifest(manifest):
    if manifest.get("format") != "questie-acore-npc-compatibility" or manifest.get("version") != 1:
        raise ValueError("Unsupported NPC compatibility manifest")
    scope = manifest.get("scope")
    if not isinstance(scope, dict) or not scope:
        raise ValueError("Missing explicit NPC scope")
    for key, mask in scope.items():
        if not key.isdigit() or int(key) < 1 or str(int(key)) != key or type(mask) is not int or mask < 1 or mask >= 1 << len(FIELDS):
            raise ValueError("Invalid NPC scope ID or field mask")
    sections = {"displayValues": DISPLAY_FIELDS, "geometry": GEOMETRY_FIELDS, "relations": RELATION_FIELDS,
                "overrides": set(FIELDS) - DISPLAY_FIELDS - GEOMETRY_FIELDS - RELATION_FIELDS}
    for section, fields in sections.items():
        entries = manifest.get(section)
        if not isinstance(entries, dict) or not set(entries) <= set(scope):
            raise ValueError(f"Invalid {section} IDs")
        for key, values in entries.items():
            if not isinstance(values, dict) or not set(values) <= fields:
                raise ValueError(f"Invalid {section} fields for NPC {key}")
            if any(not scope[key] & (1 << (KEYS["s:" + field] - 1)) for field in values):
                raise ValueError(f"Compatibility field outside scope for NPC {key}")
    extra = manifest.get("extraRecords")
    if not isinstance(extra, dict) or not set(extra) <= set(scope):
        raise ValueError("Invalid extra NPC records")
    if any(set(extra) & set(manifest[name]) for name in sections):
        raise ValueError("Extra NPC records cannot also have source-backed recipes")
    limits = manifest.get("limits", {})
    if type(limits.get("maxOutputBytes")) is not int or limits["maxOutputBytes"] < 1 or set(limits.get("geometry", {})) != GEOMETRY_FIELDS:
        raise ValueError("Missing NPC output/geometry limits")
    return manifest


def build_records(source, manifest):
    validate_manifest(manifest)
    result = {}
    for key, mask in manifest["scope"].items():
        npc_id = int(key)
        if key in manifest["extraRecords"]:
            if npc_id in source:
                raise ValueError(f"Supplemental NPC {npc_id} now has a source template; review it")
            row = copy.deepcopy(manifest["extraRecords"][key])
        else:
            if npc_id not in source:
                raise ValueError(f"Scoped NPC {npc_id} lost its source template")
            raw, row = source[npc_id], {}
            for field in FIELDS:
                typed_key = "s:" + field
                if not mask & (1 << (KEYS[typed_key] - 1)):
                    continue
                expected = raw.get(typed_key, shared.ABSENT)
                if field in DISPLAY_FIELDS:
                    value = manifest["displayValues"].get(key, {}).get(field, shared.ABSENT)
                elif field in GEOMETRY_FIELDS:
                    recipe = manifest["geometry"].get(key, {}).get(field)
                    if recipe is None:
                        raise ValueError(f"Missing geometry selection for NPC {npc_id}")
                    value = decode_geometry(recipe, expected)
                elif field in RELATION_FIELDS:
                    value = manifest["relations"].get(key, {}).get(field, shared.ABSENT)
                    if not isinstance(value, dict) or not isinstance(expected, dict) or not set(value.values()) <= set(expected.values()):
                        raise ValueError(f"Selected quest relations changed for NPC {npc_id}")
                elif field in manifest["overrides"].get(key, {}):
                    override = manifest["overrides"][key][field]
                    if value_hash(expected) != override["expectedSource"]:
                        raise ValueError(f"Source {field} changed behind an NPC {npc_id} compatibility override")
                    value = override["value"]
                else:
                    value = expected
                if value is shared.ABSENT:
                    raise ValueError(f"Missing scoped field {field} for NPC {npc_id}")
                row[typed_key] = copy.deepcopy(value)
        actual_mask = sum(1 << (KEYS[field] - 1) for field in row)
        if actual_mask != mask:
            raise ValueError(f"NPC {npc_id} field presence changed")
        row_to_lua(row, KEYS)
        result[npc_id] = row
    geometry = audit.geometry_inventory(result)
    for field, counts in geometry.items():
        for kind, count in counts.items():
            if count > manifest["limits"]["geometry"][field].get(kind, 0):
                raise ValueError(f"NPC {field} {kind} budget exceeded")
    return result


def compare_records(before, after):
    differences = []
    for npc_id in sorted(set(before) | set(after)):
        a, b = before.get(npc_id, shared.ABSENT), after.get(npc_id, shared.ABSENT)
        if not shared.same_value(a, b):
            differences.append({"npcId": npc_id, "before": None if a is shared.ABSENT else a,
                                "after": None if b is shared.ABSENT else b})
    return {"exactParity": not differences, "differences": differences, "changedRecords": len(differences)}


def write_stream(stream, records):
    stream.write('-- Generated from AzerothCore source and explicit Questie compatibility data.\n')
    stream.write('-- Generator: tools/generate_acore_npc_base.py\n')
    stream.write('local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n\nQuestieDB.npcKeys = {\n')
    for field, index in KEYS.items():
        stream.write(f'    [{lua_quote(field[2:])}] = {index},\n')
    stream.write('}\n\n')
    writer = LuaBlobWriter(stream, "npcData")
    for npc_id, row in sorted(records.items()):
        writer.write(f'[{npc_id}]={row_to_lua(row, KEYS)},\n')
    writer.finish()


def candidate_size(records):
    class Counter:
        size = 0

        def write(self, value):
            self.size += len(value.encode("utf-8"))
    counter = Counter()
    write_stream(counter, records)
    return counter.size


def write_manifest(path, manifest):
    path.parent.mkdir(parents=True, exist_ok=True)
    with db_snapshot.temporary_directory(path.parent) as directory:
        candidate = directory / "manifest.json"
        with candidate.open("w", encoding="utf-8", newline="\n") as stream:
            stream.write('{\n')
            for i, (key, value) in enumerate(manifest.items()):
                stream.write('  ' + json.dumps(key) + ': ')
                if isinstance(value, dict):
                    stream.write('{\n')
                    for j, (child, data) in enumerate(value.items()):
                        stream.write('    ' + json.dumps(child) + ': ' + json.dumps(data, ensure_ascii=True, allow_nan=False, separators=(',', ':')))
                        stream.write(',\n' if j + 1 < len(value) else '\n')
                    stream.write('  }')
                else:
                    stream.write(json.dumps(value, ensure_ascii=True, allow_nan=False))
                stream.write(',\n' if i + 1 < len(manifest) else '\n')
            stream.write('}\n')
        candidate.replace(path)


def local_path(path, directory, suffix):
    path = (ROOT / path).resolve()
    if not path.is_relative_to(ROOT / directory) or path.suffix != suffix:
        raise ValueError(f"Output must be {suffix} under {directory}")
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("bootstrap", "generate"):
        child = commands.add_parser(command)
        child.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
        child.add_argument("--creature-sql", type=Path, required=True)
        child.add_argument("--creature-multispawn-sql", type=Path, required=True)
        child.add_argument("--wdm-root", type=Path, default=audit.reader.DEFAULT_WDM_ROOT)
        child.add_argument("--map-difficulty-dbc", type=Path)
        child.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
        child.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_npc_source_model.json"))
        child.add_argument("--force", action="store_true")
    commands.choices["bootstrap"].add_argument("--snapshot", type=Path, required=True)
    commands.choices["generate"].add_argument("--compare-snapshot", type=Path)
    commands.choices["generate"].add_argument("--output", type=Path, default=Path("tools/reports/acore-npc-candidate/acoreNpcDB.lua"))
    commands.choices["generate"].add_argument("--report", type=Path, default=Path("tools/reports/acore_npc_base_candidate.json"))
    args = parser.parse_args(argv)
    source, creature, multispawn, wdm = (p.resolve() for p in (args.acore_source, args.creature_sql, args.creature_multispawn_sql, args.wdm_root))
    difficulty = audit.reader.find_map_difficulty_dbc(source, args.map_difficulty_dbc).resolve()
    cache = shared.local_output(ROOT, args.source_cache)
    manifest_path = local_path(args.manifest, "tools/data", ".json")
    snapshot_path = args.snapshot if args.command == "bootstrap" else args.compare_snapshot
    targets = [manifest_path] if args.command == "bootstrap" else [local_path(args.output, "tools/reports", ".lua"), shared.local_output(ROOT, args.report)]
    inputs = {cache, creature, multispawn, difficulty, *([snapshot_path.resolve()] if snapshot_path else [])}
    if args.command == "generate":
        inputs.add(manifest_path)
    if len(set(targets)) != len(targets) or any(p in inputs for p in targets):
        raise ValueError("Output paths must differ from inputs and each other")
    if not args.force and any(p.exists() for p in targets):
        raise ValueError("Output already exists; review it or explicitly use --force")
    signature = audit.source_signature(source, ROOT, creature, multispawn, difficulty, wdm)
    saved = audit.load_source(source, ROOT, creature, multispawn, difficulty, wdm, signature, cache)
    if any(saved["diagnostics"].values()):
        raise ValueError("NPC source diagnostics require review before generation")
    model = {int(key): value for key, value in saved["npcs"].items()}
    baseline = metadata = snapshot_sha = None
    if snapshot_path:
        snapshot_sha = db_snapshot.file_hash(snapshot_path)
        baseline, fields, _, metadata = shared.read_static_records(snapshot_path, ROOT, "npc")
        if tuple(fields) != FIELDS:
            raise ValueError("Unexpected NPC schema")
    if args.command == "bootstrap":
        manifest = make_manifest(baseline, model, metadata, snapshot_sha, signature)
        records = build_records(model, manifest)
    else:
        manifest_sha = db_snapshot.file_hash(manifest_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        records = build_records(model, manifest)
    comparison = compare_records(baseline, records) if baseline is not None else None
    if comparison and not comparison["exactParity"]:
        if args.command == "generate":
            shared.write_json(targets[1], {"comparison": comparison})
        raise ValueError("NPC candidate differs from baseline; no candidate or manifest published")
    if candidate_size(records) > manifest["limits"]["maxOutputBytes"]:
        raise ValueError("NPC candidate exceeds its baseline size budget")
    if audit.source_signature(source, ROOT, creature, multispawn, difficulty, wdm) != signature:
        raise ValueError("NPC source inputs changed during generation")
    if snapshot_path and (db_snapshot.file_hash(snapshot_path) != snapshot_sha or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items())):
        raise ValueError("Snapshot or addon inputs changed during generation")
    summary = {"npcs": len(records), "exactParity": comparison["exactParity"] if comparison else None,
               "changedRecords": comparison["changedRecords"] if comparison else None,
               "geometry": audit.geometry_inventory(records)}
    if args.command == "bootstrap":
        write_manifest(manifest_path, manifest)
        summary.update({"manifest": str(manifest_path), "extraRecords": len(manifest["extraRecords"])})
    else:
        if db_snapshot.file_hash(manifest_path) != manifest_sha:
            raise ValueError("NPC compatibility manifest changed during generation")
        output, report = targets
        output.parent.mkdir(parents=True, exist_ok=True)
        with db_snapshot.temporary_directory(output.parent) as directory:
            candidate = directory / "acoreNpcDB.lua"
            with candidate.open("w", encoding="utf-8", newline="\n") as stream:
                write_stream(stream, records)
            if candidate.stat().st_size > manifest["limits"]["maxOutputBytes"]:
                raise ValueError("Serialized NPC candidate exceeds size budget")
            shared.write_json(report, {"sourceInputs": signature, "manifestSha256": manifest_sha,
                                      "comparisonSnapshotSha256": snapshot_sha, "comparison": comparison,
                                      "outputSha256": db_snapshot.file_hash(candidate), "outputBytes": candidate.stat().st_size,
                                      "maxOutputBytes": manifest["limits"]["maxOutputBytes"], "counts": summary,
                                      "excludedSourceNpcIds": sorted(set(model) - set(records))})
            candidate.replace(output)
        summary.update({"output": str(output), "report": str(report), "outputMiB": round(output.stat().st_size / 1048576, 2)})
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit(f"NPC base generation failed: {exc}")
