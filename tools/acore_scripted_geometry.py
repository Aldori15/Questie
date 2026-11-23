"""Generation-only evidence for fixed SmartAI summons and their waypoint paths.

Consumers opt in per entry/field. Unsupported actor context remains explicit;
it is never filled from legacy coordinates or an entry-number naming convention.
"""
from collections import defaultdict
import hashlib
from pathlib import Path
import re


NPC_SCRIPT_SOURCE_FILES = ("src/server/scripts/Outland/zone_hellfire_peninsula.cpp",)


def reviewed_npc_scripts(source_root, templates):
    """Review Aeranas's bounded combat script before using his summon position."""
    if templates.get(17085, {}).get("ScriptName") != "npc_aeranas":
        return {}
    text = (Path(source_root) / NPC_SCRIPT_SOURCE_FILES[0]).read_text(encoding="utf-8")
    # Cover the whole class and its spell constants, not only movement methods.
    import acore_cpp_geometry
    text = acore_cpp_geometry._clean(text)
    match = re.search(r"\benum Aeranas\b.*?^\};\s*class npc_aeranas\b.*?^\};", text, re.S | re.M)
    digest = hashlib.sha256(re.sub(r"\s+", "", match[0]).encode()).hexdigest() if match else None
    if digest != AERANAS_SCRIPT_SHA256:
        raise ValueError("Aeranas script changed; review fixed summon geometry before regeneration")
    return {17085: "npc_aeranas"}


AERANAS_SCRIPT_SHA256 = "0022091bb85878edfe3487ca328d39a9e1ce1f7d4b1540e49feeff46b30da663"


def rotation_only_update(statement):
    """Quaternion recalculations cannot change summon ownership or placement."""
    import generate_acore_item_corrections as sql
    assignments, _, matched = sql.split_update_statement(statement, "gameobject")
    return matched and bool(assignments) and all(re.fullmatch(
        r"\s*`?rotation[0-3]`?\s*=\s*(?:SIN|COS)\s*\(\s*`?orientation`?\s*/\s*2\s*\)\s*",
        value, re.I) for value in sql.split_sql_values(assignments))


def number(row, key):
    return int(row.get(key) or 0)


def typed(value):
    if isinstance(value, list):
        return {f"n:{i}": typed(v) for i, v in enumerate(value, 1) if v is not None}
    if isinstance(value, dict):
        return {f"n:{key}": typed(v) for key, v in value.items()}
    return value


def script_key(row):
    return ":".join(str(number(row, key)) for key in ("source_type", "entryorguid", "id", "link"))


def collect(scripts, creatures_by_entry, guid_to_creature, templates, zone_maps, escort_paths,
            object_templates=None, summon_action=12, objects_by_entry=None, guid_to_object=None,
            reviewed_child_scripts=None):
    import generate_acore_npc_corrections as reader

    if summon_action not in (12, 50):
        raise ValueError("Unsupported summon action")
    children = templates if summon_action == 12 else (object_templates or {})
    objects_by_entry, guid_to_object = objects_by_entry or {}, guid_to_object or {}
    reviewed_child_scripts = reviewed_child_scripts or {}

    groups, callers, self_calls = defaultdict(list), defaultdict(list), defaultdict(set)
    for row in scripts:
        groups[number(row, "source_type"), number(row, "entryorguid")].append(row)
    timed = {owner for kind, owner in groups if kind == 9}
    for node, rows in groups.items():
        for row in rows:
            action = number(row, "action_type")
            lists = ({number(row, "action_param1")} if action == 80 else
                     {number(row, f"action_param{i}") for i in range(1, 7)} if action == 87 else
                     {i for i in timed if number(row, "action_param1") <= i <= number(row, "action_param2")}
                     if action == 88 else set())
            for target in lists & timed:
                callers[9, target].append((node, number(row, "target_type")))
                if number(row, "target_type") == 1:
                    self_calls[node].add((9, target))

    memo = {}

    def actors(node, visiting=frozenset()):
        if node in visiting:
            return set(), {"cyclic timed-list ownership"}
        if node[0] == 0 or node[0] == 1 and objects_by_entry:
            return {node}, set()
        if node in memo:
            return memo[node]
        if node[0] != 9 or not callers[node]:
            return set(), {f"no supported creature caller for {node}"}
        roots, failures = set(), set()
        for parent, target in callers[node]:
            if target != 1:
                failures.add(f"non-self timed-list caller {parent}")
                continue
            owners, errors = actors(parent, visiting | {node})
            roots.update(owners)
            failures.update(errors)
        memo[node] = roots, failures
        return roots, failures

    # A phase change or teleport can invalidate the static actor's map/phase.
    # Check self-targeted timed lists too, including lists not owning a summon.
    context_mutators = set()
    for node, rows in groups.items():
        if any(number(row, "action_type") in (44, 62) and number(row, "target_type") == 1 for row in rows):
            owners, _ = actors(node)
            context_mutators.update(owners)
    entries = {}

    def child_changes_context(node, visiting=frozenset()):
        if node in visiting:
            return True  # A cyclic child list also needs explicit review.
        if any(number(row, "action_type") in (44, 62) and number(row, "target_type") == 1
               for row in groups.get(node, ())):
            return True
        return any(child_changes_context(target, visiting | {node}) for target in self_calls[node])

    def entry_data(entry):
        return entries.setdefault(entry, {"spawns": defaultdict(list), "waypoints": defaultdict(list),
                                          "spawnOrigins": defaultdict(list), "pathOrigins": defaultdict(list),
                                          "failures": {"spawns": [], "waypoints": []}})

    placements = defaultdict(list)
    for row in scripts:
        if number(row, "action_type") != summon_action:
            continue
        entry, identity = number(row, "action_param1"), "smart-summon:" + script_key(row)
        if not entry or entry not in children:
            continue
        data = entry_data(entry)
        roots, errors = actors((number(row, "source_type"), number(row, "entryorguid")))
        errors = set(errors)
        if number(row, "target_type") != 8 or (summon_action == 12 and number(row, "action_param6")):
            errors.add("summon is not an absolute position with ordinary ownership")
        if any(row.get("target_" + axis) is None for axis in ("x", "y", "z")):
            errors.add("missing summon XYZ")
        child_kind = 0 if summon_action == 12 else 1
        child_mutates = child_changes_context((child_kind, entry))
        script = children[entry].get("ScriptName")
        if child_mutates or (summon_action == 12 and (0, entry) in context_mutators) or (
                script and reviewed_child_scripts.get(entry) != script):
            errors.add("summoned template has a phase/map mutator or custom script")
        maps, zones = set(), set()
        for actor in roots:
            owner = actor[1]
            is_object = actor[0] == 1
            by_entry, by_guid = (objects_by_entry, guid_to_object) if is_object else (creatures_by_entry, guid_to_creature)
            actor_templates = (object_templates or {}) if is_object else templates
            expected_ai = "SmartGameObjectAI" if is_object else "SmartAI"
            candidates = by_entry.get(owner, ()) if owner > 0 else [by_guid.get(-owner)]
            candidates = [spawn for spawn in candidates if spawn is not None]
            owner_entries = {owner} if owner > 0 else {
                number(spawn, "id") if is_object else reader.get_primary_creature_entry(spawn) for spawn in candidates}
            if any(actor_templates.get(i, {}).get("AIName") != expected_ai or actor_templates.get(i, {}).get("ScriptName")
                   for i in owner_entries):
                errors.add(f"unsupported actor AI: {actor}")
            if not candidates:
                errors.add(f"no static actor placement for {actor}")
            if actor in context_mutators:
                errors.add(f"actor changes phase/map: {actor}")
            for spawn in candidates:
                if spawn.get("ScriptName"):
                    errors.add("actor placement has a custom script")
                if spawn.get("map") is None or number(spawn, "phaseMask") != 1:
                    errors.add("actor map/ordinary phase is unavailable")
                else:
                    maps.add(number(spawn, "map"))
                if number(spawn, "zoneId") <= 0:
                    errors.add("actor zone context is unavailable")
                elif number(spawn, "zoneId") > 0:
                    zones.add(number(spawn, "zoneId"))
        if len(maps) != 1:
            errors.add("summon map is unavailable or ambiguous")
        if len(zones) != 1:
            errors.add("summon zone context is unavailable or ambiguous")
        if errors:
            data["failures"]["spawns"].append({"source": identity, "reasons": sorted(errors)})
            continue
        map_id = next(iter(maps))
        point_source = {"map": map_id, "zoneId": next(iter(zones), 0),
                        "position_x": row["target_x"], "position_y": row["target_y"],
                        "position_z": row["target_z"], "phaseMask": 1}
        if any(actor[0] == 1 for actor in roots):
            point_source["require_zone_context"] = True
        zone, point = reader.resolve_coordinate_zone(point_source, zone_maps)
        if zone is None or point is None:
            data["failures"]["spawns"].append({"source": identity, "reasons": ["unmappable summon position"]})
            continue
        point_source["zoneId"] = zone
        data["spawns"][zone].append(point)
        data["spawnOrigins"][zone].append((point, identity + f":map:{map_id}"))
        placements[entry].append((point_source, identity))

    for row in scripts:
        if summon_action != 12 or number(row, "action_type") != 53:
            continue
        owners, ownership_errors = actors((number(row, "source_type"), number(row, "entryorguid")))
        for kind, entry in owners:
            if kind != 0:
                continue
            if entry <= 0 or entry not in placements:
                continue
            data = entry_data(entry)
            rows = escort_paths.get(number(row, "action_param2"))
            if (ownership_errors or number(row, "target_type") != 1 or not rows
                    or templates[entry].get("AIName") != "SmartAI"):
                data["failures"]["waypoints"].append({"source": script_key(row),
                    "reasons": sorted(ownership_errors | {"unsupported waypoint activation or missing path"})})
                continue
            for placement, summon_id in placements[entry]:
                sections = reader.project_waypoint_path(placement, rows, zone_maps)
                if not sections:
                    data["failures"]["waypoints"].append({"source": script_key(row),
                                                          "reasons": ["path does not map to this summoned copy"]})
                    continue
                for zone, first, points in sections:
                    points = reader.unique_consecutive_points(points)
                    identity = f"smart-path:{script_key(row)}:summon:{summon_id}:segment:{first}"
                    data["waypoints"][zone].append(points)
                    data["pathOrigins"][zone].append((points, identity))

    result = {}
    for entry, data in sorted(entries.items()):
        raw = {entry: {"spawns": reader.sort_coordinate_table(data["spawns"], {}),
                       "waypoints": reader.sort_waypoint_table(data["waypoints"])}}
        origins = reader.index_geometry_origins(raw, {entry: data["spawnOrigins"]}, {entry: data["pathOrigins"]}, {})
        result[str(entry)] = {"spawns": typed(raw[entry]["spawns"]), "waypoints": typed(raw[entry]["waypoints"]),
                              "origins": origins.get(str(entry), {}), "failures": data["failures"]}
    return {"version": 1, "entries": result}
