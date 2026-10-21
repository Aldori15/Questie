"""Generation-only evidence for fixed SmartAI summons and their waypoint paths.

Consumers opt in per entry/field. Unsupported actor context remains explicit;
it is never filled from legacy coordinates or an entry-number naming convention.
"""
from collections import defaultdict


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


def collect(scripts, creatures_by_entry, guid_to_creature, templates, zone_maps, escort_paths):
    import generate_acore_npc_corrections as reader

    groups, callers = defaultdict(list), defaultdict(list)
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

    memo = {}

    def actors(node, visiting=frozenset()):
        if node in visiting:
            return set(), {"cyclic timed-list ownership"}
        if node[0] == 0:
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

    def entry_data(entry):
        return entries.setdefault(entry, {"spawns": defaultdict(list), "waypoints": defaultdict(list),
                                          "spawnOrigins": defaultdict(list), "pathOrigins": defaultdict(list),
                                          "failures": {"spawns": [], "waypoints": []}})

    placements = defaultdict(list)
    for row in scripts:
        if number(row, "action_type") != 12:
            continue
        entry, identity = number(row, "action_param1"), "smart-summon:" + script_key(row)
        if not entry or entry not in templates:
            continue
        data = entry_data(entry)
        roots, errors = actors((number(row, "source_type"), number(row, "entryorguid")))
        errors = set(errors)
        if number(row, "target_type") != 8 or number(row, "action_param6"):
            errors.add("summon is not an absolute position with ordinary ownership")
        if any(row.get("target_" + axis) is None for axis in ("x", "y", "z")):
            errors.add("missing summon XYZ")
        if (0, entry) in context_mutators or templates[entry].get("ScriptName"):
            errors.add("summoned template has a phase/map mutator or custom script")
        maps, zones = set(), set()
        for actor in roots:
            owner = actor[1]
            candidates = creatures_by_entry.get(owner, ()) if owner > 0 else [guid_to_creature.get(-owner)]
            candidates = [spawn for spawn in candidates if spawn is not None]
            owner_entries = {owner} if owner > 0 else {reader.get_primary_creature_entry(spawn) for spawn in candidates}
            if any(templates.get(i, {}).get("AIName") != "SmartAI" or templates.get(i, {}).get("ScriptName")
                   for i in owner_entries):
                errors.add(f"unsupported actor AI: {actor}")
            if not candidates:
                errors.add(f"no static actor placement for {actor}")
            if actor in context_mutators:
                errors.add(f"actor changes phase/map: {actor}")
            for spawn in candidates:
                if spawn.get("map") is None or number(spawn, "phaseMask") != 1:
                    errors.add("actor map/ordinary phase is unavailable")
                else:
                    maps.add(number(spawn, "map"))
                if number(spawn, "zoneId") <= 0:
                    errors.add("actor zone context is unavailable")
                else:
                    zones.add(number(spawn, "zoneId"))
        if len(maps) != 1:
            errors.add("summon map is unavailable or ambiguous")
        if len(zones) != 1:
            errors.add("summon zone context is unavailable or ambiguous")
        if errors:
            data["failures"]["spawns"].append({"source": identity, "reasons": sorted(errors)})
            continue
        map_id = next(iter(maps))
        point_source = {"map": map_id, "zoneId": next(iter(zones)),
                        "position_x": row["target_x"], "position_y": row["target_y"],
                        "position_z": row["target_z"], "phaseMask": 1}
        zone, point = reader.resolve_coordinate_zone(point_source, zone_maps)
        if zone is None or point is None:
            data["failures"]["spawns"].append({"source": identity, "reasons": ["unmappable summon position"]})
            continue
        point_source["zoneId"] = zone
        data["spawns"][zone].append(point)
        data["spawnOrigins"][zone].append((point, identity + f":map:{map_id}"))
        placements[entry].append((point_source, identity))

    for row in scripts:
        if number(row, "action_type") != 53:
            continue
        owners, ownership_errors = actors((number(row, "source_type"), number(row, "entryorguid")))
        for _, entry in owners:
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
