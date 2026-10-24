"""Regenerate acoreNpcDB.lua from current AC source, exports and compatibility.

No archive, previous checkout, source cache or snapshot is required for updates.
--output can select a local report candidate instead of the live file.
bootstrap is a one-time migration helper; --compare-snapshot verifies migration.
"""
import argparse
import copy
import hashlib
import json
import math
import sys
from pathlib import Path

import audit_acore_item_sources as shared
import audit_acore_npc_sources as audit
import db_snapshot
from generate_acore_full_base import LuaBlobWriter, lua_quote, lua_value, row_to_lua


ROOT = Path(__file__).resolve().parents[1]
FIELDS = tuple(audit.reader.FIELD_ORDER)
KEYS = {"s:" + field: index for index, field in enumerate(FIELDS, 1)}
DISPLAY_FIELDS = {"minLevelHealth", "maxLevelHealth", "zoneID"}
GEOMETRY_FIELDS = {"spawns", "waypoints"}
RELATION_FIELDS = {"questStarts", "questEnds"}
DEFAULT_MANIFEST = Path("tools/data/acore_npc_compatibility.json")


def identity_key(identity):
    # Bindings live inside one NPC record, so its entry need not be repeated.
    parts = identity.split(":")
    if len(parts) == 4 and parts[0] == "creature" and parts[2] == "entry":
        return "c:" + parts[1]
    if (len(parts) == 8 or len(parts) == 10 and parts[8] == "segment") and parts[0] in {"waypoint_data", "waypoints"}:
        kind = "w:" if parts[0] == "waypoints" else "t:" if parts[2] == "template-addon" else "d:"
        key = kind + ":".join(parts[i] for i in (1, 3, 5))
        return key + ":segment:" + parts[9] if len(parts) == 10 else key
    return identity


def binding_ids(binding):
    return [binding] if isinstance(binding, str) else binding if isinstance(binding, list) else []


def geometry_units(source, origins):
    if not isinstance(source, dict):
        return []
    return [(zone, key, value, [identity_key(i) for i in origins.get(zone, {}).get(key, [])])
            for zone, units in source.items() for key, value in units.items()]


def refreshable_geometry(recipe, source, origins):
    """Store source identities and intentional omissions, not source list indices."""
    if recipe is not None and "wholeValue" in recipe:
        return {"value": copy.deepcopy(recipe["wholeValue"])}
    slots, selected = {}, set()
    if recipe is not None:
        desired = decode_geometry(recipe, source)
        for zone, selection in recipe["zones"].items():
            output = slots.setdefault(zone, {})
            keys = selection.get("keys", [f"n:{i}" for i in range(1, len(selection["refs"]) + 1)])
            for key, ref in zip(keys, selection["refs"]):
                value = desired[zone][key]
                if ref:
                    source_key = f"n:{ref}"
                    identities = [identity_key(i) for i in origins.get(zone, {}).get(source_key, [])]
                    output[key] = (identities[0] if len(identities) == 1 else identities) if identities else {"hash": value_hash(value)}
                    selected.add((zone, source_key))
                else:
                    output[key] = {"value": copy.deepcopy(value)}
    selected_ids = {identity_key(i) for zone, key in selected for i in origins.get(zone, {}).get(key, [])}
    selected_values = {(zone, value_hash(source[zone][key])) for zone, key in selected}
    excluded_ids, excluded_values = set(), set()
    for zone, key, value, identities in geometry_units(source, origins):
        if (zone, key) not in selected:
            if identities:
                excluded_ids.update(set(identities) - selected_ids)
            else:
                # Equivalent duplicate paths must not exclude selected copies.
                chosen = (zone, value_hash(value)) in selected_values
                if not chosen:
                    excluded_values.add(zone + "/" + value_hash(value))
    policy = {"slots": slots}
    if excluded_ids:
        policy["excludeIds"] = sorted(excluded_ids)
    if excluded_values:
        policy["excludeValues"] = sorted(excluded_values)
    return policy


def upgrade_manifest(manifest, source, provenance):
    """One-time conversion while the frozen source still matches the migration."""
    if manifest["version"] == 2:
        result = copy.deepcopy(manifest)
        result.setdefault("excludedNpcIds", sorted(set(source) - {int(key) for key in result["scope"]}))
        return result
    validate_manifest(manifest)
    manifest = copy.deepcopy(manifest)
    geometry, relation_exclusions, zones = {}, {}, {}
    for key in manifest["scope"]:
        if key in manifest["extraRecords"]:
            continue
        raw = source[int(key)]
        for field in sorted(GEOMETRY_FIELDS):
            policy = refreshable_geometry(
                manifest["geometry"].get(key, {}).get(field), raw.get("s:" + field, shared.ABSENT),
                provenance.get(key, {}).get(field, {}))
            if policy != {"slots": {}}:
                geometry.setdefault(key, {})[field] = policy
        for field in sorted(RELATION_FIELDS):
            selected = manifest["relations"].get(key, {}).get(field, {})
            excluded = sorted(set(raw.get("s:" + field, {}).values()) - set(selected.values()))
            if excluded:
                relation_exclusions.setdefault(key, {})[field] = excluded
        display = manifest["displayValues"].get(key, {})
        zone = raw.get("s:zoneID", shared.ABSENT)
        if "zoneID" in display and not shared.same_value(display["zoneID"], zone):
            zones[key] = {"value": display["zoneID"], "expectedSource": value_hash(zone)}
    manifest.update(version=2, geometry=geometry, relationExclusions=relation_exclusions, zoneOverrides=zones,
                    excludedNpcIds=sorted(set(source) - {int(key) for key in manifest["scope"]}))
    manifest["policy"] = "Refresh scoped NPCs from current source; preserve explicit geometry exclusions and legacy display values."
    return manifest


def validate_spawn_review(policy):
    if "reviewedUnmappedGuids" not in policy:
        return
    guids = policy["reviewedUnmappedGuids"]
    if (set(policy) != {"slots", "reviewedUnmappedGuids"} or policy["slots"] != {}
            or not isinstance(guids, list) or not guids
            or any(type(guid) is not int or guid <= 0 for guid in guids)
            or guids != sorted(set(guids))):
        raise ValueError("Invalid reviewed unmapped spawn GUIDs; use source geometry without supplements")


def validate_waypoint_review(policy):
    paths = policy.get("reviewedUnmappedPaths")
    if (set(policy) != {"slots", "reviewedUnmappedPaths"} or policy["slots"] != {}
            or not isinstance(paths, list) or not paths
            or any(not isinstance(path, str) or not path for path in paths)
            or paths != sorted(set(paths))):
        raise ValueError("Invalid reviewed unmapped waypoint paths; use source geometry without supplements")


def validate_source_geometry_policy(manifest, kind="npc"):
    """A completed accuracy audit must not silently regain inherited markers."""
    policy = manifest.get("geometryPolicy")
    if policy is None:
        return
    if policy != "verified-source-only-v1":
        raise ValueError("Unknown geometry accuracy policy")
    review = manifest.get("geometryAudit", {})
    if (not isinstance(review, dict) or review.get("version") != 1
            or not isinstance(review.get("reviewedFields"), dict)):
        raise ValueError("Missing geometry accuracy review inventory")
    allowed_fields = {"spawns", "waypoints"} if kind == "npc" else {"spawns"}
    for entry, fields in review["reviewedFields"].items():
        if (entry not in manifest["scope"] or not isinstance(fields, list) or not fields
                or any(field not in allowed_fields for field in fields) or len(fields) != len(set(fields))):
            raise ValueError("Invalid geometry accuracy review inventory")
    for entry, record in manifest["geometry"].items():
        policies = record.values() if kind == "npc" else (record,)
        for recipe in policies:
            if "value" in recipe or any(isinstance(binding, dict) and "value" in binding
                    for slots in recipe.get("slots", {}).values() for binding in slots.values()):
                raise ValueError(f"Inherited {kind} geometry is prohibited after the accuracy audit: {entry}")
    for entry, row in manifest["extraRecords"].items():
        if any(row.get("s:" + field) for field in ("spawns", "waypoints")):
            raise ValueError(f"Unverified supplemental {kind} geometry is prohibited: {entry}")


def geometry_audit_report(records, manifest, provenance, kind="npc"):
    """Report omissions separately from the source data shipped to the addon."""
    review = manifest.get("geometryAudit", {})
    gaps = {}
    for entry, fields in review.get("reviewedFields", {}).items():
        record = records.get(int(entry), {})
        for field in fields:
            coverage = provenance.get(entry, {}).get("spawnCoverage" if field == "spawns" else "waypointCoverage", {})
            absent = not geometry_units(record.get("s:" + field, {}), {})
            missing = coverage.get("unmappedGuids") if field == "spawns" else coverage.get("unmappedPaths")
            if absent or missing:
                detail = {"reason": "No verified mapped source geometry" if absent else "Some source placements remain unmappable"}
                if missing:
                    detail["unmappedGuids" if field == "spawns" else "unmappedPaths"] = missing
                if entry in manifest["extraRecords"]:
                    detail["reason"] = "Client helper or supplemental record without verified AC coordinates"
                gaps.setdefault(entry, {"name": record.get("s:name"), "fields": {}})["fields"][field] = detail
    return {"policy": manifest.get("geometryPolicy"), "reviewedRecords": len(review.get("reviewedFields", {})),
            "coverageGapRecords": len(gaps), "coverageGaps": gaps}


def add_scripted_geometry(policy, source, origins, packet, entry, field):
    if "sourceScripted" not in policy:
        return source, origins
    if set(policy) != {"slots", "sourceScripted"} or policy["slots"] != {} or policy["sourceScripted"] is not True:
        raise ValueError("Scripted geometry requires a pure source policy")
    if not isinstance(packet, dict) or packet.get("version") != 1 or not isinstance(packet.get("entries"), dict):
        raise ValueError("Missing scripted geometry coverage; refresh the source model")
    if packet.get("failures"):
        raise ValueError(f"Scripted geometry source extraction requires review: {packet['failures']}")
    if not isinstance(source, dict):
        raise ValueError("Static geometry has an unresolved mapping gap; review it separately")
    extra = packet["entries"].get(str(entry), {"spawns": {}, "waypoints": {}, "origins": {},
                                             "failures": {"spawns": [], "waypoints": []}})
    failures = extra["failures"]["spawns"] + (extra["failures"]["waypoints"] if field == "waypoints" else [])
    if failures:
        raise ValueError(f"Scripted geometry requires review: {failures[:3]}")
    result, result_origins = copy.deepcopy(source), copy.deepcopy(origins)
    for zone, units in extra[field].items():
        target = result.setdefault(zone, {})
        target_origins = result_origins.setdefault(zone, {})
        for key, value in units.items():
            identities = extra["origins"].get(field, {}).get(zone, {}).get(key)
            if not identities:
                raise ValueError("Scripted geometry lacks source identities")
            selected = next((k for k, v in target.items() if shared.same_value(value, v)), None)
            if selected is None:
                selected = f"n:{max((int(k[2:]) for k in target), default=0) + 1}"
                target[selected] = copy.deepcopy(value)
            target_origins[selected] = sorted(set(target_origins.get(selected, [])) | set(identities))
    return result, result_origins


def current_geometry(policy, source, origins, coverage=None):
    if "reviewedUnmappedPaths" in policy:
        validate_waypoint_review(policy)
        if source is shared.ABSENT:
            if (not isinstance(coverage, dict) or not coverage.get("unmappedPaths")
                    or not isinstance(coverage.get("mapped"), dict)
                    or not isinstance(coverage.get("origins"), dict)):
                raise ValueError("Missing partial waypoint coverage; refresh the source model")
            paths = coverage["unmappedPaths"]
            if any(not isinstance(path, str) or not path for path in paths):
                raise ValueError("Unmapped waypoint assignment lacks a source identity")
            unreviewed = set(paths) - set(policy["reviewedUnmappedPaths"])
            if unreviewed:
                raise ValueError(f"New unmapped waypoint paths require review: {sorted(unreviewed)}")
            source, origins = coverage["mapped"], coverage["origins"]
            if any(not identities for _, _, _, identities in geometry_units(source, origins)):
                raise ValueError("Partial waypoint coverage lacks source identities")
    if "reviewedUnmappedGuids" in policy:
        validate_spawn_review(policy)
        if source is shared.ABSENT:
            if (not isinstance(coverage, dict) or not coverage.get("unmappedGuids")
                    or not isinstance(coverage.get("mapped"), dict)
                    or not isinstance(coverage.get("origins"), dict)):
                raise ValueError("Missing partial spawn coverage; refresh the source model")
            guids = coverage["unmappedGuids"]
            if any(type(guid) is not int or guid <= 0 for guid in guids):
                raise ValueError("Unmapped source placement lacks a valid GUID")
            unreviewed = set(guids) - set(policy["reviewedUnmappedGuids"])
            if unreviewed:
                raise ValueError(f"New unmapped spawn GUIDs require review: {sorted(unreviewed)}")
            source, origins = coverage["mapped"], coverage["origins"]
            if any(not identities for _, _, _, identities in geometry_units(source, origins)):
                raise ValueError("Partial spawn coverage lacks source identities")
    if "value" in policy:
        return copy.deepcopy(policy["value"])
    if source is shared.ABSENT and any(binding_ids(binding) or "hash" in binding
            for slots in policy["slots"].values() for binding in slots.values()):
        raise ValueError("Previously mapped NPC geometry is unavailable; check coordinate/export coverage")
    excluded_ids, excluded_values = set(policy.get("excludeIds", [])), set(policy.get("excludeValues", []))
    units = [unit for unit in geometry_units(source, origins)
             if (not unit[3] or not all(identity in excluded_ids or identity.split(":segment:")[0] in excluded_ids
                                        for identity in unit[3]))
             and unit[0] + "/" + value_hash(unit[2]) not in excluded_values]
    by_id, by_hash = {}, {}
    for index, (zone, _, value, identities) in enumerate(units):
        for identity in identities:
            by_id.setdefault(identity, []).append(index)
        by_hash.setdefault((zone, value_hash(value)), []).append(index)
    result, used = {}, set()
    binding_counts = {}
    for slots in policy["slots"].values():
        for binding in slots.values():
            ids = tuple(binding_ids(binding))
            if ids:
                binding_counts[ids] = binding_counts.get(ids, 0) + 1

    def put(zone, key, value):
        target = result.setdefault(zone, {})
        if key is None or key in target:
            key = f"n:{max((int(i[2:]) for i in target), default=0) + 1}"
        target[key] = copy.deepcopy(value)

    for zone, slots in policy["slots"].items():
        if not slots:
            result.setdefault(zone, {})
        for key, binding in slots.items():
            if isinstance(binding, dict) and "value" in binding:
                put(zone, key, binding["value"])
                used.update(by_hash.get((zone, value_hash(binding["value"])), []))
                continue
            candidates = []
            identities = binding_ids(binding)
            if identities:
                for identity in identities:
                    matches = by_id.get(identity, [])
                    if len({(units[i][0], value_hash(units[i][2])) for i in matches}) > 1:
                        raise ValueError(f"Ambiguous NPC geometry identity: {identity}")
                    candidates.extend(matches)
            else:
                candidates = by_hash.get((zone, binding["hash"]), [])
            # Identical duplicate paths retain their original selected copies.
            distinct = {}
            for index in candidates:
                target_zone, _, value, _ = units[index]
                distinct.setdefault((target_zone, value_hash(value)), index)
            if len(distinct) > 1 and binding_counts.get(tuple(identities), 0) > 1:
                raise ValueError("Previously identical paths split across a shared source identity; resolve their bindings")
            for number, index in enumerate(distinct.values()):
                target_zone, _, value, _ = units[index]
                put(target_zone, key if number == 0 else None, value)
            used.update(candidates)
    for index, (zone, _, value, _) in enumerate(units):
        if index not in used:
            put(zone, None, value)
    for zone, points in list(result.items()):
        original = policy["slots"].get(zone, {})
        if set(original) == {f"n:{i}" for i in range(1, len(original) + 1)}:
            result[zone] = {f"n:{i}": value for i, (_, value) in enumerate(
                sorted(points.items(), key=lambda pair: int(pair[0][2:])), 1)}
    return result


def build_current_records(source, manifest, provenance):
    result = {}
    scope = {int(key) for key in manifest["scope"]} | (set(source) - set(manifest["excludedNpcIds"]))
    for npc_id in sorted(scope):
        key = str(npc_id)
        if key in manifest["extraRecords"]:
            if npc_id in source:
                raise ValueError(f"Supplemental NPC {npc_id} now has a source template; resolve this ID collision")
            result[npc_id] = copy.deepcopy(manifest["extraRecords"][key])
            continue
        if npc_id not in source:
            continue
        raw, row = source[npc_id], {}
        mask = manifest["scope"].get(key)
        if mask is None:
            mask = sum(1 << (KEYS["s:" + field] - 1) for field in FIELDS
                       if "s:" + field in raw and (manifest.get("healthPolicy") or field not in {"minLevelHealth", "maxLevelHealth"}))
        for field in FIELDS:
            typed_key = "s:" + field
            present = bool(mask & (1 << (KEYS[typed_key] - 1)))
            value = raw.get(typed_key, shared.ABSENT)
            if field in GEOMETRY_FIELDS:
                policy = manifest["geometry"].get(key, {}).get(field, {"slots": {}})
                try:
                    if manifest.get("geometryPolicy") and value is shared.ABSENT:
                        review_key = "reviewedUnmappedGuids" if field == "spawns" else "reviewedUnmappedPaths"
                        if review_key not in policy:
                            raise ValueError("Unmapped source geometry requires explicit coverage review")
                    value, origins = add_scripted_geometry(policy, value, provenance.get(key, {}).get(field, {}),
                                                          provenance.get("scriptedGeometry"), npc_id, field)
                    if "sourceCpp" in policy:
                        if set(policy) != {"slots", "sourceCpp"} or policy["slots"] != {} or policy["sourceCpp"] is not True:
                            raise ValueError("C++ geometry requires a pure source policy")
                        value, origins = add_scripted_geometry({"slots": {}, "sourceScripted": True}, value, origins,
                                                              provenance.get("cppGeometry"), npc_id, field)
                    value = current_geometry(policy, value, origins,
                                             provenance.get(key, {}).get("spawnCoverage" if field == "spawns" else "waypointCoverage"))
                except ValueError as exc:
                    raise ValueError(f"NPC {npc_id} {field}: {exc}") from exc
            elif field in RELATION_FIELDS:
                if value is shared.ABSENT:
                    if present:
                        raise ValueError(f"NPC {npc_id} has unavailable {field} source data")
                    continue
                allowed = set(value.values()) - set(manifest["relationExclusions"].get(key, {}).get(field, []))
                selected = manifest["relations"].get(key, {}).get(field, {})
                value = {i: quest for i, quest in selected.items() if quest in allowed}
                index = max((int(i[2:]) for i in selected), default=0)
                for quest in sorted(allowed - set(value.values())):
                    index += 1
                    value[f"n:{index}"] = quest
                if set(selected) == {f"n:{i}" for i in range(1, len(selected) + 1)}:
                    value = {f"n:{i}": quest for i, (_, quest) in enumerate(
                        sorted(value.items(), key=lambda pair: int(pair[0][2:])), 1)}
            elif field in {"minLevelHealth", "maxLevelHealth"}:
                if manifest.get("healthPolicy"):
                    if provenance.get("defaultHealth", {}).get("policy") != manifest["healthPolicy"]:
                        raise ValueError("Source-derived NPC health requires a fresh validated source model")
                    value = raw.get(typed_key, shared.ABSENT)
                else:
                    value = manifest["displayValues"].get(key, {}).get(field, shared.ABSENT)
            elif field == "zoneID":
                if manifest.get("zonePolicy"):
                    value = source_display_zone(value, row.get("s:spawns"), row.get("s:waypoints"),
                                                provenance.get("sourceZones", {}).get("entries", {}).get(key))
                else:
                    override = manifest["zoneOverrides"].get(key)
                    if override and value_hash(value) == override["expectedSource"]:
                        value = override["value"]
            else:
                override = manifest["overrides"].get(key, {}).get(field)
                if override and value_hash(value) == override["expectedSource"]:
                    value = override["value"]
            if value is shared.ABSENT:
                if present:
                    raise ValueError(f"Missing source or explicit compatibility field {field} for NPC {npc_id}")
                continue
            if present or value not in (0, "", {}):
                row[typed_key] = copy.deepcopy(value)
        row_to_lua(row, KEYS)
        result[npc_id] = row
    if len(result) < len(manifest["scope"]) * 0.95:
        raise ValueError("Unexpected removal of more than 5% of NPC records; check source completeness")
    return result


def source_display_zone(raw_zone, spawns, waypoints=None, source_zones=None):
    """Prefer verified geometry, then independently proved source zone identity."""
    counts = {int(zone[2:]): len(points) for zone, points in (spawns or {}).items() if points}
    if not counts:
        counts = {int(zone[2:]): sum(len(path) for path in paths.values())
                  for zone, paths in (waypoints or {}).items() if paths}
    if not counts:
        zones = (source_zones or {}).get("zones", [])
        if any(type(zone) is not int or zone <= 0 for zone in zones):
            raise ValueError("Invalid source zone provenance")
        zones = set(zones)
        if raw_zone in zones:
            return raw_zone
        return next(iter(zones)) if len(zones) == 1 else 0
    if raw_zone in counts:
        return raw_zone
    return max(counts, key=lambda zone: (counts[zone], -zone))


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
    if "accuracyPolicy" in manifest:
        if manifest["accuracyPolicy"] != "verified-source-fields-v1" or manifest.get("extraRecords") or manifest.get("overrides"):
            raise ValueError("Verified NPC fields cannot contain inherited records or scalar overrides")
        if (manifest.get("healthPolicy") != "acore-template-default-rates-v1" or manifest.get("displayValues")
                or manifest.get("zonePolicy") != "verified-geometry-v1" or manifest.get("zoneOverrides")):
            raise ValueError("Verified NPC fields require current source health and zone policies")
    if manifest.get("format") != "questie-acore-npc-compatibility" or manifest.get("version") not in (1, 2):
        raise ValueError("Unsupported NPC compatibility manifest")
    scope = manifest.get("scope")
    if "healthPolicy" in manifest:
        if manifest["healthPolicy"] != "acore-template-default-rates-v1" or manifest.get("displayValues"):
            raise ValueError("Source-derived NPC health cannot retain legacy display values")
    if "zonePolicy" in manifest:
        if manifest["zonePolicy"] != "verified-geometry-v1" or manifest.get("zoneOverrides"):
            raise ValueError("Source-derived NPC zones cannot retain legacy zone overrides")
    if not isinstance(scope, dict) or not scope:
        raise ValueError("Missing explicit NPC scope")
    if manifest["version"] == 2:
        excluded = manifest.get("excludedNpcIds")
        if not isinstance(excluded, list) or not all(type(i) is int and i > 0 for i in excluded) or excluded != sorted(set(excluded)) or set(excluded) & {int(k) for k in scope}:
            raise ValueError("Invalid excluded NPC IDs")
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
            if any(not scope[key] & (1 << (KEYS["s:" + field] - 1)) for field in values) and not (manifest["version"] == 2 and section == "geometry"):
                raise ValueError(f"Compatibility field outside scope for NPC {key}")
            if section == "geometry":
                for field, policy in values.items():
                    if "sourceScripted" in policy:
                        if (manifest["version"] != 2 or set(policy) != {"slots", "sourceScripted"}
                                or policy["slots"] != {} or policy["sourceScripted"] is not True):
                            raise ValueError("Scripted geometry requires a current pure source policy")
                    if "sourceCpp" in policy:
                        if (manifest["version"] != 2 or set(policy) != {"slots", "sourceCpp"}
                                or policy["slots"] != {} or policy["sourceCpp"] is not True):
                            raise ValueError("C++ geometry requires a current pure source policy")
                    if "reviewedUnmappedGuids" in policy:
                        if manifest["version"] != 2 or field != "spawns":
                            raise ValueError("Unmapped spawn review requires current spawn geometry")
                        validate_spawn_review(policy)
                    if "reviewedUnmappedPaths" in policy:
                        if manifest["version"] != 2 or field != "waypoints":
                            raise ValueError("Unmapped path review requires current waypoint geometry")
                        validate_waypoint_review(policy)
    extra = manifest.get("extraRecords")
    if not isinstance(extra, dict) or not set(extra) <= set(scope):
        raise ValueError("Invalid extra NPC records")
    if any(set(extra) & set(manifest[name]) for name in sections):
        raise ValueError("Extra NPC records cannot also have source-backed recipes")
    limits = manifest.get("limits", {})
    if type(limits.get("maxOutputBytes")) is not int or limits["maxOutputBytes"] < 1 or set(limits.get("geometry", {})) != GEOMETRY_FIELDS:
        raise ValueError("Missing NPC output/geometry limits")
    validate_source_geometry_policy(manifest)
    return manifest


def build_records(source, manifest, provenance=None):
    validate_manifest(manifest)
    if manifest["version"] == 2:
        if provenance is None and any(binding_ids(binding) for row in manifest["geometry"].values()
                for policy in row.values() for slots in policy.get("slots", {}).values() for binding in slots.values()):
            raise ValueError("Fresh NPC source identities are required; refresh the source model")
        return build_current_records(source, manifest, provenance or {})
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


def scripted_spawn_sources(source, records):
    """Small source-backed proxies needed even when source chunks stay unloaded.

    Rift Spawn creates the coffer at itself (SmartAI/spell9010); Bountiful Tables
    award Spirit of Sharing credit (C++/spell61849). Store source geometry once
    for these helpers instead of maintaining independent coordinate lists.
    """
    result = {}
    for npc in (6492, 32823):
        if npc not in source or npc not in records:
            if len(records) > 1000:
                raise ValueError(f"Missing scripted spawn source NPC {npc}")
            continue
        points = source[npc].get("s:spawns")
        if not isinstance(points, dict) or not points:
            raise ValueError(f"Missing scripted spawn source geometry for NPC {npc}")
        result[npc] = copy.deepcopy(points)
        for zone in result[npc].values():
            for point in zone.values():
                if any(not key.startswith("n:") or not key[2:].isdigit() or int(key[2:]) > 8 for key in point):
                    raise ValueError(f"Unknown scripted spawn source coordinate schema for NPC {npc}")
                # A child/credit helper shares placement/phase, not its parent's
                # DB spawn GUID. Preserve slots1-7; never impersonate that NPC.
                point.pop("n:8", None)
    return result


def write_stream(stream, records, scripted_spawns=None, runtime_geometry=None):
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
    if scripted_spawns is not None:
        stream.write('\n-- Source geometry for scripted map helpers on fresh and cached startup.\n')
        stream.write('QuestieDB.scriptedSpawnSources = ' + lua_value({"n:" + str(k): v for k, v in scripted_spawns.items()}) + '\n')
    if runtime_geometry is not None:
        if runtime_geometry.get("version") != 1:
            raise ValueError("Unknown runtime geometry source packet")
        def fields(rows):
            return {"n:" + key: {"n:" + str(KEYS[field]): value for field, value in row.items()}
                    for key, row in rows.items()}
        stream.write('\n-- Source event summons and active-fair placements; also loaded on cached startup.\n')
        factions = runtime_geometry["faction"]
        stream.write('QuestieDB.npcFactionGeometry = (UnitFactionGroup("player") == "Horde") and '
                     + lua_value(fields(factions["Horde"])) + ' or ' + lua_value(fields(factions["Alliance"])) + '\n')
        stream.write('QuestieDB.darkmoonGeometry = ' + lua_value({"n:" + k: fields(v)
                     for k, v in runtime_geometry["darkmoon"].items()}) + '\n')


def candidate_size(records, scripted_spawns=None, runtime_geometry=None):
    class Counter:
        size = 0

        def write(self, value):
            self.size += len(value.encode("utf-8"))
    counter = Counter()
    write_stream(counter, records, scripted_spawns, runtime_geometry)
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
    production = (ROOT / "Database/AzerothCore/acoreNpcDB.lua").resolve()
    if (not path.is_relative_to(ROOT / directory) and not (directory == "tools/reports" and path == production)) or path.suffix != suffix:
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
        child.add_argument("--force", action="store_true", help="Overwrite a migration manifest; normal generation overwrites its output")
    commands.choices["bootstrap"].add_argument("--snapshot", type=Path, required=True)
    commands.choices["generate"].add_argument("--compare-snapshot", type=Path, help="Optional migration parity check")
    commands.choices["generate"].add_argument("--output", type=Path, default=Path("Database/AzerothCore/acoreNpcDB.lua"), help="Default: Database/AzerothCore/acoreNpcDB.lua")
    commands.choices["generate"].add_argument("--report", type=Path, default=Path("tools/reports/acore_npc_base_candidate.json"))
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments and arguments[0].startswith("-"):
        arguments.insert(0, "generate")
    args = parser.parse_args(arguments)
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
    if args.command == "bootstrap" and not args.force and any(p.exists() for p in targets):
        raise ValueError("Output already exists; review it or explicitly use --force")
    signature = audit.source_signature(source, ROOT, creature, multispawn, difficulty, wdm)
    saved = audit.load_source(source, ROOT, creature, multispawn, difficulty, wdm, signature, cache)
    if any(saved["diagnostics"].values()):
        raise ValueError("NPC source diagnostics require review before generation")
    model = {int(key): value for key, value in saved["npcs"].items()}
    provenance = saved.get("geometryProvenance")
    baseline = metadata = snapshot_sha = None
    if snapshot_path:
        snapshot_sha = db_snapshot.file_hash(snapshot_path)
        baseline, fields, _, metadata = shared.read_static_records(snapshot_path, ROOT, "npc")
        if tuple(fields) != FIELDS:
            raise ValueError("Unexpected NPC schema")
    if args.command == "bootstrap":
        manifest = upgrade_manifest(make_manifest(baseline, model, metadata, snapshot_sha, signature), model, provenance or {})
        records = build_records(model, manifest, provenance)
    else:
        manifest_sha = db_snapshot.file_hash(manifest_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        records = build_records(model, manifest, provenance)
    scripted_spawns = scripted_spawn_sources(model, records)
    runtime_geometry = (provenance or {}).get("runtimeGeometry")
    if len(records) > 1000 and runtime_geometry is None:
        raise ValueError("Missing runtime geometry source coverage; refresh the source model")
    if runtime_geometry is not None:
        import acore_runtime_geometry
        runtime_geometry = acore_runtime_geometry.select_darkmoon_waypoints(runtime_geometry, model, provenance)
    comparison = compare_records(baseline, records) if baseline is not None else None
    if comparison and not comparison["exactParity"]:
        if args.command == "generate":
            shared.write_json(targets[1], {"comparison": comparison})
        raise ValueError("NPC candidate differs from baseline; no candidate or manifest published")
    if candidate_size(records, scripted_spawns, runtime_geometry) > manifest["limits"]["maxOutputBytes"]:
        raise ValueError("NPC candidate exceeds its baseline size budget")
    if audit.source_signature(source, ROOT, creature, multispawn, difficulty, wdm) != signature:
        raise ValueError("NPC source inputs changed during generation")
    if snapshot_path and (db_snapshot.file_hash(snapshot_path) != snapshot_sha or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items())):
        raise ValueError("Snapshot or addon inputs changed during generation")
    reviewed_gaps = {key: provenance.get(key, {}).get("spawnCoverage", {}).get("unmappedGuids", [])
                     for key, fields in manifest["geometry"].items()
                     if "reviewedUnmappedGuids" in fields.get("spawns", {})}
    reviewed_paths = {key: provenance.get(key, {}).get("waypointCoverage", {}).get("unmappedPaths", [])
                      for key, fields in manifest["geometry"].items()
                      if "reviewedUnmappedPaths" in fields.get("waypoints", {})}
    geometry_review = geometry_audit_report(records, manifest, provenance)
    summary = {"npcs": len(records), "exactParity": comparison["exactParity"] if comparison else None,
               "changedRecords": comparison["changedRecords"] if comparison else None,
               "parityScope": "shared NPC rows; scripted map helpers require runtime snapshot review",
               "scriptedSpawnSourceIds": sorted(scripted_spawns),
               "scriptedGeometryIds": sorted(int(key) for key, fields in manifest["geometry"].items()
                                             if any(policy.get("sourceScripted") for policy in fields.values())),
               "reviewedUnmappedSpawnPlacements": sum(map(len, reviewed_gaps.values())),
               "reviewedUnmappedWaypointPaths": sum(map(len, reviewed_paths.values())),
               "geometryCoverageGaps": geometry_review["coverageGapRecords"],
               "cppGeometryIds": sorted(int(key) for key, fields in manifest["geometry"].items()
                                        if any(policy.get("sourceCpp") for policy in fields.values())),
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
                write_stream(stream, records, scripted_spawns, runtime_geometry)
            if candidate.stat().st_size > manifest["limits"]["maxOutputBytes"]:
                raise ValueError("Serialized NPC candidate exceeds size budget")
            shared.write_json(report, {"sourceInputs": signature, "manifestSha256": manifest_sha,
                                      "comparisonSnapshotSha256": snapshot_sha, "comparison": comparison,
                                      "outputSha256": db_snapshot.file_hash(candidate), "outputBytes": candidate.stat().st_size,
                                      "maxOutputBytes": manifest["limits"]["maxOutputBytes"], "counts": summary,
                                      "reviewedUnmappedSpawns": reviewed_gaps,
                                      "reviewedUnmappedWaypoints": reviewed_paths,
                                      "geometryAudit": geometry_review,
                                      "runtimeGeometryOmissions": runtime_geometry.get("runtimeOmissions", []) if runtime_geometry else [],
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
