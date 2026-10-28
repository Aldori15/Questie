"""Regenerate acoreObjectDB.lua from current AC source and explicit compatibility.

Normal updates require no archive or baseline snapshot. bootstrap is a one-time
migration helper; --compare-snapshot optionally verifies exact migration parity.
"""
import argparse
import copy
import json
import sys
from pathlib import Path

import audit_acore_item_sources as shared
import audit_acore_object_sources as audit
import db_snapshot
import generate_acore_npc_base as geometry
from generate_acore_full_base import LuaBlobWriter, lua_quote, lua_value, row_to_lua


ROOT = Path(__file__).resolve().parents[1]
FIELDS = tuple(audit.reader.FIELD_ORDER)
KEYS = {"s:" + field: index for index, field in enumerate(FIELDS, 1)}
RELATIONS = {"questStarts", "questEnds"}
DEFAULT_MANIFEST = Path("tools/data/acore_object_compatibility.json")


def make_manifest(records, source, provenance, metadata, snapshot_sha, signature):
    scope, extras, policies, relations, exclusions, overrides = {}, {}, {}, {}, {}, {}
    for object_id, row in sorted(records.items()):
        if not row or not set(row) <= set(KEYS):
            raise ValueError(f"Invalid baseline object {object_id}")
        row_to_lua(row, KEYS)
        key = str(object_id)
        scope[key] = sum(1 << (KEYS[field] - 1) for field in row)
        if object_id not in source:
            extras[key] = copy.deepcopy(row)
            continue
        raw = source[object_id]
        actual = row.get("s:spawns", shared.ABSENT)
        expected = raw.get("s:spawns", shared.ABSENT)
        recipe = geometry.encode_geometry(actual, expected) if actual is not shared.ABSENT else None
        policy = geometry.refreshable_geometry(recipe, expected, provenance.get(key, {}).get("spawns", {}))
        if policy != {"slots": {}}:
            policies[key] = policy
        for field in RELATIONS:
            actual, expected = row.get("s:" + field, {}), raw.get("s:" + field, shared.ABSENT)
            if not isinstance(actual, dict) or not isinstance(expected, dict) or not set(actual.values()) <= set(expected.values()):
                raise ValueError(f"Uncovered {field} for object {object_id}")
            if actual:
                relations.setdefault(key, {})[field] = copy.deepcopy(actual)
            excluded = sorted(set(expected.values()) - set(actual.values()))
            if excluded:
                exclusions.setdefault(key, {})[field] = excluded
        for field in ("name", "zoneID", "factionID"):
            typed_key = "s:" + field
            expected = raw.get(typed_key, shared.ABSENT)
            if typed_key in row and not shared.same_value(row[typed_key], expected):
                overrides.setdefault(key, {})[field] = {"value": copy.deepcopy(row[typed_key]),
                                                       "expectedSource": geometry.value_hash(expected)}
            elif typed_key not in row and expected is not shared.ABSENT and expected not in (0, "", {}):
                overrides.setdefault(key, {})[field] = {"omit": True, "expectedSource": geometry.value_hash(expected)}
    size = candidate_size(records)
    points = audit.geometry.geometry_inventory(records)["spawns"].get("points", 0)
    return {"format": "questie-acore-object-compatibility", "version": 1,
            "provenance": {"snapshotSha256": snapshot_sha, "snapshotCommit": (metadata.get("git") or {}).get("commit"),
                           "acoreCommit": signature.get("sourceRevision")},
            "policy": "Read current source; preserve explicit exclusions, supplements, ordering and conditional scalar exceptions.",
            "limits": {"maxOutputBytes": size + max(65536, size // 20), "maxSpawnPoints": points + max(64, points // 20)},
            "scope": scope, "excludedObjectIds": sorted(set(source) - set(records)), "extraRecords": extras,
            "geometry": policies, "relations": relations, "relationExclusions": exclusions, "overrides": overrides}


def validate_manifest(manifest):
    if "accuracyPolicy" in manifest:
        if manifest["accuracyPolicy"] != "verified-source-fields-v1" or manifest.get("extraRecords") or manifest.get("overrides"):
            raise ValueError("Verified object fields cannot contain inherited records or scalar overrides")
        if manifest.get("zonePolicy") != "verified-geometry-v1":
            raise ValueError("Verified object fields require a current source zone policy")
    if manifest.get("format") != "questie-acore-object-compatibility" or manifest.get("version") != 1:
        raise ValueError("Unsupported object compatibility manifest")
    scope = manifest.get("scope")
    if not isinstance(scope, dict) or not scope:
        raise ValueError("Missing object scope")
    for key, mask in scope.items():
        if not key.isdigit() or int(key) < 1 or str(int(key)) != key or type(mask) is not int or not 0 < mask < 1 << len(FIELDS):
            raise ValueError("Invalid object scope ID or field mask")
    excluded = manifest.get("excludedObjectIds")
    if not isinstance(excluded, list) or not all(type(i) is int and i > 0 for i in excluded) or excluded != sorted(set(excluded)) or set(excluded) & {int(k) for k in scope}:
        raise ValueError("Invalid excluded object IDs")
    for section in ("extraRecords", "geometry", "relations", "relationExclusions", "overrides"):
        values = manifest.get(section)
        if not isinstance(values, dict) or not set(values) <= set(scope):
            raise ValueError(f"Invalid {section} IDs")
    extras = manifest["extraRecords"]
    if any(set(extras) & set(manifest[s]) for s in ("geometry", "relations", "relationExclusions", "overrides")):
        raise ValueError("Extra object records cannot have source-backed policies")
    for key, row in extras.items():
        if not isinstance(row, dict) or not set(row) <= set(KEYS) or sum(1 << (KEYS[k] - 1) for k in row) != scope[key]:
            raise ValueError("Invalid extra object record")
        row_to_lua(row, KEYS)
    for section in ("relations", "relationExclusions", "overrides"):
        for fields in manifest[section].values():
            if not isinstance(fields, dict) or not set(fields) <= (RELATIONS if section != "overrides" else {"name", "zoneID", "factionID"}):
                raise ValueError(f"Invalid {section} fields")
            for value in fields.values():
                if section == "overrides":
                    if (not isinstance(value, dict) or set(value) not in ({"value", "expectedSource"}, {"omit", "expectedSource"})
                            or not isinstance(value["expectedSource"], str) or "omit" in value and value["omit"] is not True):
                        raise ValueError("Invalid conditional object override")
                else:
                    ids = value.values() if isinstance(value, dict) else value if isinstance(value, list) else None
                    if ids is None or any(type(i) is not int or i <= 0 for i in ids):
                        raise ValueError("Invalid object quest relation")
                    if section == "relations" and (not isinstance(value, dict) or any(not k.startswith("n:") or not k[2:].isdigit() or int(k[2:]) < 1 for k in value)):
                        raise ValueError("Invalid object relation slots")
    for policy in manifest["geometry"].values():
        if not isinstance(policy, dict):
            raise ValueError("Invalid object geometry policy")
        geometry.validate_spawn_review(policy)
        if "sourceScripted" in policy and (set(policy) != {"slots", "sourceScripted"}
                or policy["slots"] != {} or policy["sourceScripted"] is not True):
            raise ValueError("Scripted object geometry requires a pure source policy")
        if "sourceCpp" in policy and (set(policy) != {"slots", "sourceCpp"}
                or policy["slots"] != {} or policy["sourceCpp"] is not True):
            raise ValueError("C++ object geometry requires a pure source policy")
        if "value" in policy:
            continue
        if not isinstance(policy.get("slots"), dict):
            raise ValueError("Missing object geometry slots")
        for zone, slots in policy["slots"].items():
            if not zone.startswith("n:") or not zone[2:].isdigit() or not isinstance(slots, dict):
                raise ValueError("Invalid object geometry zone")
            for key, binding in slots.items():
                if not key.startswith("n:") or not key[2:].isdigit() or int(key[2:]) < 1:
                    raise ValueError("Invalid object geometry slot")
                if not (isinstance(binding, str) or isinstance(binding, list) and all(isinstance(i, str) for i in binding)
                        or isinstance(binding, dict) and (set(binding) == {"value"} or set(binding) == {"hash"} and isinstance(binding["hash"], str))):
                    raise ValueError("Invalid object geometry binding")
    limits = manifest.get("limits", {})
    if any(type(limits.get(key)) is not int or limits[key] < 1 for key in ("maxOutputBytes", "maxSpawnPoints")):
        raise ValueError("Missing object output limits")
    geometry.validate_source_geometry_policy(manifest, "object")
    return manifest


def build_records(source, manifest, provenance=None):
    validate_manifest(manifest)
    if "zonePolicy" in manifest:
        if manifest["zonePolicy"] != "verified-geometry-v1" or any("zoneID" in row for row in manifest["overrides"].values()):
            raise ValueError("Source-derived object zones cannot retain legacy zone overrides")
    if provenance is None and any(geometry.binding_ids(binding) for policy in manifest["geometry"].values()
                                 for slots in policy.get("slots", {}).values() for binding in slots.values()):
        raise ValueError("Fresh object source identities are required")
    provenance = provenance or {}
    result = {}
    scope = {int(key) for key in manifest["scope"]} | (set(source) - set(manifest["excludedObjectIds"]))
    for object_id in sorted(scope):
        key = str(object_id)
        if key in manifest["extraRecords"]:
            if object_id in source:
                raise ValueError(f"Supplemental object {object_id} now has a source template; resolve this ID collision")
            result[object_id] = copy.deepcopy(manifest["extraRecords"][key])
            continue
        if object_id not in source:
            continue
        raw, row = source[object_id], {}
        mask = manifest["scope"].get(key, sum(1 << (KEYS[k] - 1) for k in raw if k in KEYS))
        for field in FIELDS:
            typed_key = "s:" + field
            present = bool(mask & (1 << (KEYS[typed_key] - 1)))
            value = raw.get(typed_key, shared.ABSENT)
            if field == "spawns":
                try:
                    policy = manifest["geometry"].get(key, {"slots": {}})
                    if policy.get("sourceScripted") and provenance.get("scriptedGeometry", {}).get("actorContextAvailable") is not True:
                        raise ValueError("Scripted object actor context is unavailable; supply creature exports and refresh the source model")
                    if manifest.get("geometryPolicy") and value is shared.ABSENT and "reviewedUnmappedGuids" not in policy:
                        raise ValueError("Unmapped source geometry requires explicit coverage review")
                    value, origins = geometry.add_scripted_geometry(policy, value, provenance.get(key, {}).get(field, {}),
                                                                   provenance.get("scriptedGeometry"), object_id, field)
                    if policy.get("sourceCpp"):
                        value, origins = geometry.add_scripted_geometry({"slots": {}, "sourceScripted": True}, value, origins,
                                                                       provenance.get("cppGeometry"), object_id, field)
                    value = geometry.current_geometry(policy, value, origins,
                                                      provenance.get(key, {}).get("spawnCoverage"))
                except ValueError as exc:
                    raise ValueError(f"Object {object_id} spawns: {str(exc).replace('NPC', 'object')}") from exc
            elif field in RELATIONS:
                if not isinstance(value, dict):
                    raise ValueError(f"Object {object_id} has unavailable {field} source data")
                allowed = set(value.values()) - set(manifest["relationExclusions"].get(key, {}).get(field, []))
                selected = manifest["relations"].get(key, {}).get(field, {})
                value = {i: quest for i, quest in selected.items() if quest in allowed}
                index = max((int(i[2:]) for i in selected), default=0)
                for quest in sorted(allowed - set(value.values())):
                    index += 1
                    value[f"n:{index}"] = quest
                if set(selected) == {f"n:{i}" for i in range(1, len(selected) + 1)}:
                    value = {f"n:{i}": quest for i, (_, quest) in enumerate(sorted(value.items(), key=lambda pair: int(pair[0][2:])), 1)}
            elif field == "zoneID" and manifest.get("zonePolicy"):
                value = geometry.source_display_zone(value, row.get("s:spawns"), source_zones=
                                                     provenance.get("sourceZones", {}).get("entries", {}).get(key))
            else:
                override = manifest["overrides"].get(key, {}).get(field)
                if override and geometry.value_hash(value) == override["expectedSource"]:
                    value = shared.ABSENT if override.get("omit") else override["value"]
            if value is shared.ABSENT:
                if present:
                    raise ValueError(f"Missing source or explicit compatibility field {field} for object {object_id}")
                continue
            if present or value not in (0, "", {}):
                row[typed_key] = copy.deepcopy(value)
        row_to_lua(row, KEYS)
        result[object_id] = row
    if len(result) < len(manifest["scope"]) * 0.95:
        raise ValueError("Unexpected removal of more than 5% of object records; check source completeness")
    points = audit.geometry.geometry_inventory(result)["spawns"].get("points", 0)
    if points > manifest["limits"]["maxSpawnPoints"]:
        raise ValueError("Object spawn count exceeds its size budget; review expansion")
    return result


def compare_records(before, after):
    differences = []
    for object_id in sorted(set(before) | set(after)):
        a, b = before.get(object_id, shared.ABSENT), after.get(object_id, shared.ABSENT)
        if not shared.same_value(a, b):
            differences.append({"objectId": object_id, "before": None if a is shared.ABSENT else a,
                                "after": None if b is shared.ABSENT else b})
    return {"exactParity": not differences, "changedRecords": len(differences), "differences": differences}


def faction_geometry(provenance, records):
    if len(records) < 1000:
        return None
    data = provenance.get("cppGeometry", {}).get("entries", {}).get("186887")
    if not data or data["failures"]["spawns"]:
        raise ValueError("Missing verified Lantern source geometry; refresh the source model")
    points = data["spawns"]
    zones = {"Alliance": (12, 1, 3524), "Horde": (14, 85, 3430)}
    if set(points) != {"n:" + str(zone) for values in zones.values() for zone in values}:
        raise ValueError("Lantern faction map coverage changed; review the source")
    return {team: {"n:186887": {"n:" + str(KEYS["s:spawns"]): {
                "n:" + str(zone): points["n:" + str(zone)] for zone in values}}}
            for team, values in zones.items()}


def write_stream(stream, records, faction_sources=None):
    stream.write('-- Generated from AzerothCore source and explicit Questie compatibility data.\n')
    stream.write('-- Generator: tools/generate_acore_object_base.py\n')
    stream.write('local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n\nQuestieDB.objectKeys = {\n')
    for field, index in KEYS.items():
        stream.write(f'    [{lua_quote(field[2:])}] = {index},\n')
    stream.write('}\n\n')
    writer = LuaBlobWriter(stream, "objectData")
    for object_id, row in sorted(records.items()):
        writer.write(f'[{object_id}]={row_to_lua(row, KEYS)},\n')
    writer.finish()
    if faction_sources is not None:
        stream.write('\n-- Fixed Lantern spell destinations selected for the player faction.\n')
        stream.write('QuestieDB.objectFactionGeometry = (UnitFactionGroup("player") == "Horde") and '
                     + lua_value(faction_sources["Horde"]) + ' or ' + lua_value(faction_sources["Alliance"]) + '\n')


def candidate_size(records, faction_sources=None):
    class ByteCounter:
        size = 0

        def write(self, value):
            self.size += len(value.encode("utf-8"))
    counter = ByteCounter()
    write_stream(counter, records, faction_sources)
    return counter.size


def local_path(path, directory, suffix):
    path = (ROOT / path).resolve()
    production = (ROOT / "Database/AzerothCore/acoreObjectDB.lua").resolve()
    if (not path.is_relative_to(ROOT / directory) and not (directory == "tools/reports" and path == production)) or path.suffix != suffix:
        raise ValueError(f"Output must be {suffix} under {directory}")
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("bootstrap", "generate"):
        child = commands.add_parser(name)
        child.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
        child.add_argument("--gameobject-sql", type=Path, required=True)
        child.add_argument("--creature-sql", type=Path, help="Creature export for scripted object actor context")
        child.add_argument("--creature-multispawn-sql", type=Path)
        child.add_argument("--spell-sql", type=Path, help="Exported spell table for scripted object identity checks")
        child.add_argument("--map-difficulty-dbc", type=Path)
        child.add_argument("--wdm-root", type=Path, default=audit.coordinate_reader.DEFAULT_WDM_ROOT)
        child.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
        child.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_object_source_model.json"))
        child.add_argument("--force", action="store_true", help="Overwrite a one-time migration manifest")
    commands.choices["bootstrap"].add_argument("--snapshot", type=Path, required=True)
    commands.choices["generate"].add_argument("--compare-snapshot", type=Path)
    commands.choices["generate"].add_argument("--output", type=Path, default=Path("Database/AzerothCore/acoreObjectDB.lua"))
    commands.choices["generate"].add_argument("--report", type=Path, default=Path("tools/reports/acore_object_base_candidate.json"))
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments and arguments[0].startswith("-"):
        arguments.insert(0, "generate")
    args = parser.parse_args(arguments)
    source, gameobject, wdm = (p.resolve() for p in (args.acore_source, args.gameobject_sql, args.wdm_root))
    context_inputs = {}
    if args.spell_sql:
        context_inputs["spell"] = args.spell_sql.resolve()
    if args.creature_multispawn_sql and not args.creature_sql:
        raise ValueError("Creature multispawn context requires --creature-sql")
    if args.creature_sql:
        context_inputs["creature"] = args.creature_sql.resolve()
        context_inputs["multispawn"] = (args.creature_multispawn_sql.resolve() if args.creature_multispawn_sql
                                         else audit.coordinate_reader.find_sibling_creature_multispawn_sql(args.creature_sql))
        if not context_inputs["multispawn"]:
            raise ValueError("Scripted object context requires a creature multispawn export")
    difficulty = audit.coordinate_reader.find_map_difficulty_dbc(source, args.map_difficulty_dbc).resolve()
    cache = shared.local_output(ROOT, args.source_cache)
    manifest_path = local_path(args.manifest, "tools/data", ".json")
    if args.command == "generate":
        planned = json.loads(manifest_path.read_text(encoding="utf-8"))
        if planned.get("geometry", {}).get("186887", {}).get("sourceCpp") and (
                not args.creature_sql or not args.spell_sql):
            raise ValueError("Verified Lantern geometry requires --creature-sql, --creature-multispawn-sql and --spell-sql")
    snapshot_path = args.snapshot if args.command == "bootstrap" else args.compare_snapshot
    targets = [manifest_path] if args.command == "bootstrap" else [local_path(args.output, "tools/reports", ".lua"), shared.local_output(ROOT, args.report)]
    inputs = {cache, gameobject, difficulty, *([snapshot_path.resolve()] if snapshot_path else [])}
    inputs.update(context_inputs.values())
    if args.command == "generate":
        inputs.add(manifest_path)
    if len(set(targets)) != len(targets) or any(p in inputs for p in targets):
        raise ValueError("Output paths must differ from inputs and each other")
    if args.command == "bootstrap" and manifest_path.exists() and not args.force:
        raise ValueError("Manifest already exists; review it or explicitly use --force")
    signature = audit.source_signature(source, ROOT, gameobject, difficulty, wdm, **context_inputs)
    saved = audit.load_source(source, ROOT, gameobject, difficulty, wdm, signature, cache, **context_inputs)
    if any(saved["diagnostics"].values()) or any(row["skippedMutations"] for row in saved["tableCoverage"].values()):
        raise ValueError("Object SQL diagnostics require review before generation")
    model = {int(key): row for key, row in saved["objects"].items()}
    baseline = metadata = snapshot_sha = None
    if snapshot_path:
        snapshot_sha = db_snapshot.file_hash(snapshot_path)
        baseline, fields, _, metadata = shared.read_static_records(snapshot_path, ROOT, "object")
        if tuple(fields) != FIELDS:
            raise ValueError("Unexpected object schema")
    provenance = saved.get("geometryProvenance")
    if provenance is None:
        raise ValueError("Object source cache lacks spawn identities; refresh the object audit")
    if args.command == "bootstrap":
        manifest = make_manifest(baseline, model, provenance, metadata, snapshot_sha, signature)
    else:
        manifest_sha = db_snapshot.file_hash(manifest_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = build_records(model, manifest, provenance)
    faction_sources = faction_geometry(provenance, records)
    comparison = compare_records(baseline, records) if baseline is not None else None
    if comparison and not comparison["exactParity"]:
        if args.command == "generate":
            shared.write_json(targets[1], {"comparison": comparison})
        ids = [row["objectId"] for row in comparison["differences"][:20]]
        raise ValueError(f"Object candidate differs from baseline ({comparison['changedRecords']} records; IDs {ids}); no candidate or manifest published")
    if candidate_size(records, faction_sources) > manifest["limits"]["maxOutputBytes"]:
        raise ValueError("Object candidate exceeds its baseline size budget")
    if audit.source_signature(source, ROOT, gameobject, difficulty, wdm, **context_inputs) != signature:
        raise ValueError("Object source inputs changed during generation")
    if snapshot_path and (db_snapshot.file_hash(snapshot_path) != snapshot_sha or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items())):
        raise ValueError("Snapshot or addon changed during generation")
    reviewed_gaps = {key: provenance.get(key, {}).get("spawnCoverage", {}).get("unmappedGuids", [])
                     for key, policy in manifest["geometry"].items() if "reviewedUnmappedGuids" in policy}
    geometry_review = geometry.geometry_audit_report(records, manifest, provenance, "object")
    summary = {"objects": len(records), "exactParity": comparison["exactParity"] if comparison else None,
               "changedRecords": comparison["changedRecords"] if comparison else None,
               "geometry": audit.geometry.geometry_inventory(records)["spawns"],
               "reviewedUnmappedSpawnPlacements": sum(map(len, reviewed_gaps.values())),
               "geometryCoverageGaps": geometry_review["coverageGapRecords"],
               "scriptedGeometryIds": sorted(int(key) for key, policy in manifest["geometry"].items() if policy.get("sourceScripted")),
               "cppGeometryIds": sorted(int(key) for key, policy in manifest["geometry"].items() if policy.get("sourceCpp"))}
    if args.command == "bootstrap":
        geometry.write_manifest(manifest_path, manifest)
        summary.update({"manifest": str(manifest_path), "extraRecords": len(manifest["extraRecords"]),
                        "conditionalNameOverrides": sum("name" in row for row in manifest["overrides"].values())})
    else:
        if db_snapshot.file_hash(manifest_path) != manifest_sha:
            raise ValueError("Object compatibility manifest changed during generation")
        output, report = targets
        output.parent.mkdir(parents=True, exist_ok=True)
        with db_snapshot.temporary_directory(output.parent) as directory:
            candidate = directory / "acoreObjectDB.lua"
            with candidate.open("w", encoding="utf-8", newline="\n") as stream:
                write_stream(stream, records, faction_sources)
            if candidate.stat().st_size > manifest["limits"]["maxOutputBytes"]:
                raise ValueError("Serialized object candidate exceeds size budget")
            shared.write_json(report, {"sourceInputs": signature, "manifestSha256": manifest_sha,
                                      "comparisonSnapshotSha256": snapshot_sha, "comparison": comparison,
                                      "outputSha256": db_snapshot.file_hash(candidate), "outputBytes": candidate.stat().st_size,
                                      "maxOutputBytes": manifest["limits"]["maxOutputBytes"], "counts": summary,
                                      "reviewedUnmappedSpawns": reviewed_gaps,
                                      "geometryAudit": geometry_review,
                                      "excludedSourceObjectIds": sorted(set(model) - set(records))})
            candidate.replace(output)
        summary.update({"output": str(output), "report": str(report), "outputMiB": round(output.stat().st_size / 1048576, 2)})
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit(f"Object base generation failed: {exc}")
