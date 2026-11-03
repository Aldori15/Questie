"""Offline geometry for unambiguous, single-map AC motion transports.

Deck spawns remain local data. Only reviewed, open Catmull-Rom routes supply
world placements; teleporting or unsupported routes never supply fallback pins.
"""
import math
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path


SOURCE_FILES = (
    "src/server/game/Maps/TransportMgr.cpp",
    "src/server/game/Entities/Transport/Transport.cpp",
    "src/server/game/Entities/Transport/Transport.h",
    "src/server/game/Entities/Vehicle/VehicleDefines.h",
    "src/server/game/Entities/GameObject/GameObjectData.h",
    "src/server/game/Movement/Spline/Spline.cpp",
    "src/server/shared/DataStores/DBCStructure.h",
    "src/server/game/DataStores/DBCStores.cpp",
    "src/server/game/Movement/Spline/Spline.h",
)
MAX_POINTS = 4096
SUBDIVISIONS = 8

# These client transport maps lack linked-zone metadata. Preserve their reviewed
# display zone; coordinates still come from the loaded transport path and offset.
TRANSPORT_DISPLAY_ZONES = {622: (571, 210), 623: (571, 210)}


def _compact(text):
    return re.sub(r"\s+", "", re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S))


def verify_core(source_root):
    """Reject source drift in the data join, spline and passenger transforms."""
    checks = {
        SOURCE_FILES[0]: (
            "uint32 pathId = goInfo->moTransport.taxiPathId;",
            "TaxiPathNodeList const& path = sTaxiPathNodesByPath[pathId];",
            "node_i->actionFlag & 1 || node_i->mapid != path[i + 1]->mapid",
            "orientationSpline.evaluate_derivative(i + 1, 0.0f, h);",
            "k.InitialOrientation = Position::NormalizeOrientation(std::atan2(h.y, h.x) + M_PI);",
            "splinePath.erase(splinePath.begin());", "keyFrames.erase(keyFrames.begin());",
            "splinePath.pop_back();", "keyFrames.pop_back();",
            "keyFrames.back().Teleport = true;",
            "spline->init_spline(&splinePath[start], i - start + extra, Movement::SplineBase::ModeCatmullrom);",
            "TaxiPathNodeEntry const* startNode = tInfo->keyFrames.begin()->Node;",
            "float o = tInfo->keyFrames.begin()->InitialOrientation;",
        ),
        SOURCE_FILES[1]: (
            "if (uint32 mapId = GetGOInfo()->moTransport.mapID)",
            "_currentFrame->Spline->evaluate_derivative(_currentFrame->Index, t, dir);",
            "UpdatePosition(pos.x, pos.y, pos.z, NormalizeOrientation(std::atan2(dir.y, dir.x) + M_PI));",
        ),
        SOURCE_FILES[2]: (
            "TransportBase::CalculatePassengerPosition(x, y, z, o, GetPositionX(), GetPositionY(), GetPositionZ(), GetOrientation());",
        ),
        SOURCE_FILES[3]: (
            "*o = Position::NormalizeOrientation(transO + *o);",
            "x = transX + inx * std::cos(transO) - iny * std::sin(transO);",
            "y = transY + iny * std::cos(transO) + inx * std::sin(transO);", "z = transZ + inz;",
        ),
        SOURCE_FILES[4]: (
            "struct { uint32 taxiPathId; uint32 moveSpeed; uint32 accelRate; uint32 startEventID;"
            "uint32 stopEventID; uint32 transportPhysics; uint32 mapID; uint32 worldState1;"
            "uint32 canBeStopped; } moTransport;",
        ),
        SOURCE_FILES[5]: (
            "static const Matrix4 s_catmullRomCoeffs(-0.5f, 1.5f, -1.5f, 0.5f,"
            "1.f, -2.5f, 2.f, -0.5f, -0.5f, 0.f, 0.5f, 0.f, 0.f, 1.f, 0.f, 0.f);",
            "points[0] = controls[0] - G3D::Vector3{ std::cos(initialOrientation), std::sin(initialOrientation), 0.0f };",
            "points[high_index + 1] = controls[count - 1];",
        ),
        SOURCE_FILES[6]: (
            "struct TaxiPathNodeEntry { uint32 path; uint32 index; uint32 mapid; float x; float y;"
            "float z; uint32 actionFlag; uint32 delay; uint32 arrivalEventID; uint32 departureEventID; };",
        ),
        SOURCE_FILES[7]: ("sTaxiPathNodesByPath[entry->path][entry->index] = entry;",),
        SOURCE_FILES[8]: ("EvaluationMode m, float orientation = 0)",),
    }
    for relative, snippets in checks.items():
        try:
            text = _compact((Path(source_root) / relative).read_text(encoding="utf-8"))
        except OSError as error:
            raise ValueError(f"missing transport core source: {relative}") from error
        for snippet in snippets:
            if _compact(snippet) not in text:
                raise ValueError(f"unsupported transport core source: {relative}: {snippet}")


def _group_nodes(nodes):
    routes = defaultdict(list)
    identities = set()
    for node in nodes:
        try:
            identity, path, index = (int(node[key]) for key in ("id", "path", "index"))
            coords = tuple(float(node[key]) for key in ("x", "y", "z"))
            if identity in identities or min(identity, path, index) < 0 or not all(map(math.isfinite, coords)):
                raise ValueError("duplicate ID, negative identity or non-finite XYZ")
            identities.add(identity)
            routes[path].append(dict(node, id=identity, path=path, index=index,
                                     map=int(node["map"]), flags=int(node["flags"]),
                                     x=coords[0], y=coords[1], z=coords[2]))
        except (KeyError, TypeError, OverflowError, ValueError) as error:
            raise ValueError(f"invalid TaxiPathNode record: {error}") from error
    for path, route in routes.items():
        route.sort(key=lambda node: node["index"])
        if [node["index"] for node in route] != list(range(len(route))):
            raise ValueError(f"TaxiPathNode path {path} has duplicate indexes or gaps (expected contiguous indexes from zero)")
    return routes


def load_taxi_nodes(path):
    """Read the exact WotLK TaxiPathNode.dbc eleven-field WDBC layout."""
    path = Path(path)
    try:
        data = path.read_bytes()
    except OSError as error:
        raise ValueError(f"missing or unreadable TaxiPathNode.dbc: {path}") from error
    if len(data) < 20 or data[:4] != b"WDBC":
        raise ValueError("TaxiPathNode.dbc requires a complete WDBC header")
    count, fields, size, strings = struct.unpack_from("<4I", data, 4)
    if fields != 11 or size != 44:
        raise ValueError("TaxiPathNode.dbc requires exactly 11 fields and 44 bytes per record")
    if len(data) != 20 + count * size + strings:
        raise ValueError("TaxiPathNode.dbc record/string block length does not match its header")
    keys = ("id", "path", "index", "map", "x", "y", "z", "flags", "delay", "arrival_event", "departure_event")
    nodes = [dict(zip(keys, struct.unpack_from("<4I3f4I", data, 20 + index * size))) for index in range(count)]
    _group_nodes(nodes)
    return nodes


def _heading(derivative):
    if not all(map(math.isfinite, derivative)) or derivative[0] == derivative[1] == 0:
        raise ValueError("transport route has a zero XY derivative or non-finite tangent")
    return (math.atan2(derivative[1], derivative[0]) + math.pi) % math.tau


def _catmull(controls, fraction):
    position, derivative = [], []
    for axis in range(3):
        a, b, c, d = (point[axis] for point in controls)
        cubic = -0.5 * a + 1.5 * b - 1.5 * c + 0.5 * d
        quadratic = a - 2.5 * b + 2 * c - 0.5 * d
        linear = -0.5 * a + 0.5 * c
        position.append(((cubic * fraction + quadratic) * fraction + linear) * fraction + b)
        derivative.append((3 * cubic * fraction + 2 * quadratic) * fraction + linear)
    if not all(map(math.isfinite, position)):
        raise ValueError("transport route has a non-finite spline position")
    return (*position, _heading(derivative))


def _route_geometry(route):
    if len(route) < 4 or len({node["map"] for node in route}) != 1 or any(node["flags"] & 1 for node in route):
        raise ValueError("transport route requires four controls, one world map and no teleport flags")
    original = [tuple(node[axis] for axis in ("x", "y", "z")) for node in route]
    retained = original[1:-1]
    count = (len(retained) - 1) * SUBDIVISIONS + 1
    if count > MAX_POINTS:
        raise ValueError("transport route exceeds the 4096 sample bound")
    first = retained[0]
    controls = [(first[0] - 1, first[1], first[2]), *retained, retained[-1]]
    samples = []
    for segment in range(len(retained) - 1):
        for step in range(SUBDIVISIONS + 1):
            if segment and step == 0:
                continue
            samples.append(_catmull(controls[segment:segment + 4], step / SUBDIVISIONS))
    initial = _heading(tuple(0.5 * (original[2][axis] - original[0][axis]) for axis in range(3)))
    return route[0]["map"], (*retained[0], initial), samples


def _world_row(row, map_id, transform):
    x, y, z, orientation = transform
    dx, dy, dz = (float(row[key]) for key in ("position_x", "position_y", "position_z"))
    facing = float(row["orientation"])
    if not all(map(math.isfinite, (dx, dy, dz, facing))):
        raise ValueError("transport passenger has non-finite deck coordinates")
    cosine, sine = math.cos(orientation), math.sin(orientation)
    world = dict(row, map=map_id, position_x=x + dx * cosine - dy * sine,
                 position_y=y + dy * cosine + dx * sine, position_z=z + dz,
                 orientation=(orientation + facing) % math.tau, zoneId=0, areaId=0)
    for key in ("zoneid", "areaid"):
        if key in world:
            world[key] = 0
    display = TRANSPORT_DISPLAY_ZONES.get(int(row.get("map") or 0))
    if display:
        if map_id != display[0]:
            raise ValueError("transport display zone belongs to a different world map")
        world["zoneId"] = display[1]
    if not all(math.isfinite(world[key]) for key in ("position_x", "position_y", "position_z", "orientation")):
        raise ValueError("transport passenger world transform is non-finite")
    return world


def _rows(rows):
    return rows.values() if isinstance(rows, dict) else rows


def build_geometry(templates, creature_rows, taxi_nodes, zone_maps, project_point):
    """Return GUID-keyed world anchors/routes; unsupported associations are omitted.

    Every zone transition starts an independent polyline, including singleton
    runs. The final route point is never connected back to its first point.
    """
    try:
        routes = _group_nodes(taxi_nodes)
    except ValueError:
        return {}
    associations = defaultdict(set)
    entry_associations = defaultdict(set)
    for template in _rows(templates):
        try:
            if int(template["type"]) != 15:
                continue
            entry = int(template["entry"])
            path = int(template.get("Data0", template.get("data0")))
            passenger_map = int(template.get("Data6", template.get("data6")))
            if min(entry, path, passenger_map) <= 0:
                continue
        except (KeyError, TypeError, ValueError, OverflowError):
            continue
        associations[passenger_map].add((entry, path))
        entry_associations[entry].add((passenger_map, path))
    supported = {}
    for passenger_map, candidates in associations.items():
        if len(candidates) != 1:
            continue
        entry, path = next(iter(candidates))
        if len(entry_associations[entry]) != 1 or path not in routes:
            continue
        try:
            supported[passenger_map] = (entry, path, _route_geometry(routes[path]))
        except (TypeError, ValueError, OverflowError):
            continue
    creatures = list(_rows(creature_rows))
    def identity(row):
        try:
            return int(row["guid"])
        except (KeyError, TypeError, ValueError, OverflowError):
            return None

    counts = Counter(identity(row) for row in creatures)
    result = {}
    for row in creatures:
        try:
            guid = int(row["guid"])
            if guid <= 0 or counts[guid] != 1:
                continue
            association = supported.get(int(row["map"]))
            if association is None:
                continue
            entry, path, (world_map, anchor, samples) = association
            world_anchor = _world_row(row, world_map, anchor)
            zone, point = project_point(world_anchor, zone_maps)
            if not zone or not point or (world_anchor["zoneId"] and zone != world_anchor["zoneId"]):
                continue
            paths = defaultdict(list)
            previous_zone = None
            route_row = dict(row, position_x=0, position_y=0, position_z=0, orientation=0)
            for sample in samples:
                world_sample = _world_row(route_row, world_map, sample)
                sample_zone, sample_point = project_point(world_sample, zone_maps)
                if (not sample_zone or not sample_point
                        or (world_sample["zoneId"] and sample_zone != world_sample["zoneId"])):
                    raise ValueError("transport route projection is unknown")
                if sample_zone != previous_zone:
                    paths[sample_zone].append([])
                paths[sample_zone][-1].append(sample_point)
                previous_zone = sample_zone
            result[guid] = {"row": world_anchor, "zone": zone, "point": point, "paths": dict(paths),
                            "origin": f"transport:{entry}:path:{path}:creature:{guid}"}
        except (KeyError, TypeError, ValueError, OverflowError):
            continue
    return result
