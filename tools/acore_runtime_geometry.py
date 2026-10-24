"""Source-derived runtime selections; SQL replay and file I/O belong to callers."""
import math
import re
import copy

from acore_scripted_geometry import typed


DARKMOON_NPCS = frozenset({10445, 14828, 14829, 14832, 14833, 14841,
                          14844, 14845, 14846, 14847, 14849, 14871})
# Questie location -> AC main fair event and actual map zone. Setup events23/77
# have their own carnie placements and are not active-fair spawn selections.
DARKMOON_LOCATIONS = {1: (5, 215), 2: (4, 12), 3: (3, 3519)}
# Frozen spell-event bindings reviewed against event_scripts. An unknown event
# summoning one of these NPCs needs a new map-context review, never an XY guess.
SUMMON_EVENTS = {
    1131: (5676, 0, 1519, "Alliance"),
    1134: (5677, 0, 1519, "Alliance"),
    1785: (5676, 0, 1497, "Horde"),
    1786: (5677, 0, 1497, "Horde"),
    1787: (5676, 1, 1637, "Horde"),
    1788: (5677, 1, 1637, "Horde"),
    10608: (5676, 530, 3433, "Horde"),
    5991: (12138, 1, 148, "Alliance"),
    6028: (12138, 1, 17, "Horde"),
}


def review_membership_skips(statements):
    """Accept only disjoint event51 mutations whose literal NPC sets are known."""
    accepted = []
    patterns = (
        r"DELETEFROMGAME_EVENT_CREATUREWHERE\(EVENTENTRY=51\)AND\(GUIDIN\(SELECTGUIDFROMCREATUREWHEREID1IN\(([0-9,]+)\)\)\)",
        r"INSERTINTOGAME_EVENT_CREATURE(?:\(EVENTENTRY,GUID\))?\(SELECT51,GUIDFROMCREATUREWHEREID1IN\(([0-9,]+)\)\)",
    )
    for statement in statements:
        if not isinstance(statement, str):
            raise ValueError("Unsupported game_event_creature mutation diagnostics")
        normalized = re.sub(r"\s+", "", statement.replace("`", "")).upper().rstrip(";")
        match = next((m for pattern in patterns if (m := re.fullmatch(pattern, normalized))), None)
        if match is None:
            raise ValueError("Unreviewed game_event_creature mutation")
        values = match.group(1).split(",")
        if any(not value for value in values) or set(map(int, values)) & DARKMOON_NPCS:
            raise ValueError("Skipped game_event_creature mutation can affect Darkmoon NPCs")
        accepted.append(statement)
    return accepted


def ignore_unrelated_membership_statement(statement):
    """SQL reader predicate: ignore only the reviewed disjoint event51 forms."""
    try:
        review_membership_skips([statement])
    except ValueError:
        return False
    return True


def collect(event_rows, creature_rows, memberships, zone_maps, project_point):
    """Return typed selections; project_point(row, zone_maps) keeps source metadata."""
    membership = {}
    for row in memberships:
        membership.setdefault(int(row.get("guid") or 0), set()).add(int(row.get("eventEntry") or 0))
    darkmoon, selected_guids = {}, {}
    creatures = list(creature_rows)

    def project(row, expected_zone):
        zone, point = project_point(row, zone_maps)
        if zone != expected_zone or not isinstance(point, list) or len(point) < 2:
            raise ValueError("Runtime geometry source placement requires map review")
        if any(not isinstance(value, (int, float)) or not math.isfinite(value) for value in point[:2]):
            raise ValueError("Runtime geometry has invalid source coordinates")
        return point

    for location, (event, active_zone) in DARKMOON_LOCATIONS.items():
        points = {entry: [] for entry in DARKMOON_NPCS}
        selected_guids[str(location)] = {str(entry): [] for entry in sorted(DARKMOON_NPCS)}
        for row in creatures:
            entry = int(row.get("id1") or row.get("id") or row.get("entry") or 0)
            if entry not in points or event not in membership.get(int(row.get("guid") or 0), set()):
                continue
            point = project(row, active_zone)
            selected_guids[str(location)][str(entry)].append(int(row["guid"]))
            if point not in points[entry]:
                points[entry].append(point)
        missing = sorted(entry for entry, values in points.items() if not values)
        if missing:
            raise ValueError(f"Missing Darkmoon event {event} source placements: {missing}")
        darkmoon[str(location)] = {
            str(entry): {"s:spawns": typed({active_zone: sorted(values, key=lambda p: tuple(-1 if v is None else v for v in p))}),
                         "s:waypoints": {}, "s:zoneID": active_zone}
            for entry, values in sorted(points.items())
        }

    faction = {"Alliance": {}, "Horde": {}}
    seen = set()
    summon_ids = {record[0] for record in SUMMON_EVENTS.values()}
    for row in event_rows:
        entry = int(row.get("datalong") or 0)
        if int(row.get("command") or 0) != 10 or entry not in summon_ids:
            continue
        event = int(row.get("id") or 0)
        binding = SUMMON_EVENTS.get(event)
        if binding is None or binding[0] != entry:
            raise ValueError("Unreviewed fixed summon event map binding")
        _, map_id, zone, team = binding
        seen.add(event)
        coordinates = [row.get(axis) for axis in ("x", "y", "z")]
        if any(not isinstance(v, (int, float)) or not math.isfinite(v) for v in coordinates):
            raise ValueError("Fixed summon event lacks absolute source coordinates")
        placement = {"map": map_id, "zoneId": zone, "areaId": zone,
                     "position_x": coordinates[0], "position_y": coordinates[1],
                     "position_z": coordinates[2]}
        point = project(placement, zone)
        record = faction[team].setdefault(str(entry), {"s:spawns": {}, "s:zoneID": zone})
        points = record["s:spawns"].setdefault(f"n:{zone}", {})
        if point not in points.values():
            points[f"n:{len(points) + 1}"] = point
    if seen != set(SUMMON_EVENTS):
        raise ValueError(f"Missing reviewed summon events: {sorted(set(SUMMON_EVENTS) - seen)}")
    for team, records in faction.items():
        for entry, record in records.items():
            if entry in ("5676", "5677"):
                record["s:zoneID"] = 1637 if team == "Horde" else 1519
            record["s:spawns"] = {zone: typed(list(points.values())) for zone, points in sorted(record["s:spawns"].items())}
    for records in selected_guids.values():
        for entry, guids in records.items():
            records[entry] = sorted(set(guids))
    return {"version": 1, "darkmoon": darkmoon, "faction": faction, "selectedGuids": selected_guids}


def select_darkmoon_waypoints(packet, source_records, provenance):
    """Select complete source paths by active DB placement, including zone segments."""
    if (not isinstance(packet, dict) or packet.get("version") != 1
            or not isinstance(packet.get("selectedGuids"), dict)):
        raise ValueError("Missing Darkmoon source placement identities")
    result = copy.deepcopy(packet)
    omissions = result.setdefault("runtimeOmissions", [])
    identity_pattern = re.compile(r":map-spawn:(\d+):entry:(\d+)(?::segment:\d+)?$")
    for location, records in result["darkmoon"].items():
        for entry, record in records.items():
            guids = set(result["selectedGuids"].get(location, {}).get(entry, []))
            if not guids or any(type(guid) is not int or guid <= 0 for guid in guids):
                raise ValueError("Darkmoon path selection lacks active source GUIDs")
            source = source_records.get(entry, source_records.get(int(entry)))
            meta = provenance.get(entry, provenance.get(int(entry), {}))
            if not isinstance(source, dict):
                raise ValueError("Missing Darkmoon source NPC record")
            paths = source.get("s:waypoints")
            origins = meta.get("waypoints", {})
            if paths is None:
                coverage = meta.get("waypointCoverage", {})
                paths, origins = coverage.get("mapped"), coverage.get("origins", {})
            selected = {}
            if not isinstance(paths, dict):
                omissions.append({"location": location, "npc": int(entry),
                                  "reason": "missing source waypoint coverage"})
                record["s:waypoints"] = selected
                continue
            for zone, units in paths.items():
                for slot, points in units.items():
                    identities = origins.get(zone, {}).get(slot, [])
                    matches = [identity_pattern.search(identity) for identity in identities if isinstance(identity, str)]
                    placed = {int(match.group(1)) for match in matches
                              if match and int(match.group(2)) == int(entry) and int(match.group(1)) > 0}
                    if placed & guids:
                        target = selected.setdefault(zone, {})
                        target[f"n:{len(target) + 1}"] = copy.deepcopy(points)
                    elif not placed:
                        omissions.append({"location": location, "npc": int(entry), "zone": zone,
                                          "slot": slot, "reason": "path lacks an unambiguous source placement"})
            record["s:waypoints"] = selected
    return result
