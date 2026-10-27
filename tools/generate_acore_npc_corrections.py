import ast
import csv
import math
import re
import struct
import sys
import acore_npc_health
from collections import defaultdict
from functools import lru_cache
from pathlib import Path


sys.dont_write_bytecode = True
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from generate_acore_item_corrections import (  # noqa: E402
    apply_multirow_delete,
    apply_multirow_insert,
    apply_multirow_update,
    apply_variable_set,
    extract_balanced_braces,
    extract_sql_columns,
    load_keyed_table,
    load_row_table,
    load_sql_statements,
    split_sql_statements,
    source_sql_files,
    statement_targets_table,
    strip_sql_comments,
    strip_lua_comments,
)


# AzerothCore stores the TBC starting zones on map 530, but the 3.3.5 client
# map rectangles used by Questie place those same zones in Eastern Kingdoms or
# Kalimdor coordinate space. These map-530 bounds let the SQL world coordinates
# resolve to the client zone coordinates Questie displays.
ACORE_WORLD_RECT_OVERRIDES = {
    (530, 3430): {"left": -4487.55, "top": 11041.64},  # Eversong Woods
    (530, 3433): {"left": -5283.35, "top": 8266.65},  # Ghostlands
    (530, 3487): {"left": -6400.74, "top": 10153.71},  # Silvermoon City
    (530, 3524): {"left": -10499.97, "top": -2793.73},  # Azuremyst Isle
    (530, 3525): {"left": -10075.01, "top": -758.34},  # Bloodmyst Isle
    (530, 3557): {"left": -11066.36, "top": -3609.69},  # The Exodar
    (530, 4080): {"left": -5301.99, "top": 13568.71},  # Isle of Quel'Danas
}

# AzerothCore uses Circle of Wills (4570) for spawns that Questie represents
# on the broader Underbelly map (4560).
ACORE_AREA_ID_OVERRIDES = {
    4570: 4560,
}

# AzerothCore's calculated areaId cannot distinguish some vertically stacked
# instance floors. Keep these spawn GUIDs on the client floor matching their
# world Z position instead of collapsing them onto the parent instance map.
ACORE_CREATURE_SPAWN_ZONE_OVERRIDES = {
    208778: 4835,  # Kor'kron Lieutenant - ICC Rampart of Skulls
    247103: 11316,  # Arugal - Shadowfang Keep floor 7
}

DEFAULT_WDM_ROOT = Path(r"E:\downloads\questie_acore_exports\WDM stuff")
WDM_INSTANCE_FLOOR_ZONE_ID_OFFSET = 11000

# Some AC creature spawns sit just outside the client zone rectangle while still
# belonging to that zone, usually near cave or map-edge locations. Keep those
# usable by clamping them onto the visible map instead of dropping the spawn.
ZONE_EDGE_TOLERANCE = 3.0
ZONE_EDGE_CLAMP_MIN = 1.0
ZONE_EDGE_CLAMP_MAX = 99.0

STATIC_FIELD_MAP = {
    "name": "name",
    "minLevel": "minlevel",
    "maxLevel": "maxlevel",
    "rank": "rank",
    "factionID": "faction",
    "subName": "subname",
    "npcFlags": "npcflag",
}

LIST_FIELDS = {"questStarts", "questEnds"}
NESTED_FIELDS = {"spawns", "waypoints"}
STRING_FIELDS = {"name", "subName", "friendlyToFaction"}

FIELD_ORDER = [
    "name",
    "minLevelHealth",
    "maxLevelHealth",
    "minLevel",
    "maxLevel",
    "rank",
    "spawns",
    "waypoints",
    "zoneID",
    "questStarts",
    "questEnds",
    "factionID",
    "friendlyToFaction",
    "subName",
    "npcFlags",
]



CREATURE_MULTISPAWN_COLUMNS = ("spawnId", "entry")
SMART_SOURCE_TYPE_CREATURE = 0
SMART_ACTION_ESCORT_START = 53
SMART_SCRIPT_KEY_COLUMNS = ("entryorguid", "source_type", "id", "link")

WINTERGRASP_PHASE_NAMES = {
    ("Alliance", "keep"): "WINTERGRASP_ALLIANCE_KEEP",
    ("Horde", "keep"): "WINTERGRASP_HORDE_KEEP",
    ("Alliance", "camp"): "WINTERGRASP_ALLIANCE_CAMP",
    ("Horde", "camp"): "WINTERGRASP_HORDE_CAMP",
}


def parse_spawn_phase_constants(repo_root):
    text = (Path(repo_root) / "Modules/Phasing.lua").read_text(encoding="utf-8")
    match = re.search(r"local\s+phases\s*=\s*\{", strip_lua_comments(text))
    if not match:
        raise ValueError("Modules/Phasing.lua: phase constants table not found")
    table = extract_balanced_braces(strip_lua_comments(text), match.end() - 1)
    return {name: int(value) for name, value in re.findall(r"(\w+)\s*=\s*(\d+)", table)}


def load_wintergrasp_scripted_spawns(source_root, repo_root, zone_maps):
    """Read the two stock tables used by BattlefieldWG::SetupBattlefield.

    This intentionally parses literal table data, not arbitrary C++ expressions.
    A changed source format must fail visibly instead of silently dropping spawns.
    """
    path = Path(source_root) / "src/server/game/Battlefield/Zones/BattlefieldWG.h"
    text = re.sub(r"//[^\n]*|/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.S)
    enum = re.search(r"enum\s+WintergraspNpcs\s*\{([^}]+)\}", text, re.S)
    if not enum:
        raise ValueError(f"{path}: WintergraspNpcs table not found")
    entries = {}
    for declaration in enum.group(1).split(","):
        if not declaration.strip():
            continue
        match = re.fullmatch(r"\s*(\w+)\s*=\s*(\d+)\s*", declaration)
        if not match:
            raise ValueError(f"{path}: unsupported NPC enum declaration: {declaration.strip()}")
        entries[match.group(1)] = int(match.group(2))

    phases = parse_spawn_phase_constants(repo_root)
    required = set(WINTERGRASP_PHASE_NAMES.values())
    if not required <= phases.keys() or len({phases[name] for name in required}) != 4:
        raise ValueError("Missing or duplicate Wintergrasp phase constants in Modules/Phasing.lua")
    spawns = defaultdict(lambda: defaultdict(list))
    for table_name, count_name, location in (
        ("WGKeepNPC", "WG_MAX_KEEP_NPC", "keep"),
        ("WGOutsideNPC", "WG_MAX_OUTSIDE_NPC", "camp"),
    ):
        count = re.search(rf"\b{count_name}\s*=\s*(\d+)\s*;", text)
        table = re.search(rf"\b{table_name}\s*\[[^]]+\]\s*=\s*\{{", text)
        if not count or not table:
            raise ValueError(f"{path}: {table_name} or its count not found")
        body = extract_balanced_braces(text, table.end() - 1)[1:-1]
        rows = re.findall(r"\{([^{}]+)\}", body)
        remainder = re.sub(r"\{[^{}]+\}", "", body).replace(",", "").strip()
        if remainder or len(rows) != int(count.group(1)):
            raise ValueError(f"{path}: unsupported or incomplete {table_name} table")
        for row in rows:
            fields = [field.strip() for field in row.split(",")]
            if len(fields) != 6:
                raise ValueError(f"{path}: expected six fields in {table_name}: {row}")
            try:
                x, y, z, orientation = (float(field.rstrip("fF")) for field in fields[:4])
            except ValueError as error:
                raise ValueError(f"{path}: unsupported coordinate expression: {row}") from error
            if not all(math.isfinite(value) for value in (x, y, z, orientation)):
                raise ValueError(f"{path}: non-finite coordinate in {table_name}")
            point = convert_world_to_zone(y, x, 4197, zone_maps, map_id=571)
            if not point:
                raise ValueError(f"{path}: Wintergrasp coordinate outside its map: {row}")
            for name, team in zip(fields[4:], ("Horde", "Alliance")):
                if name == "0":
                    continue
                if name not in entries or not entries[name]:
                    raise ValueError(f"{path}: unknown NPC entry {name}")
                phase = phases[WINTERGRASP_PHASE_NAMES[(team, location)]]
                spawns[entries[name]][4197].append([*point, phase])
    return {entry: dict(zones) for entry, zones in spawns.items()}


def merge_scripted_spawn_locations(spawns_by_entry, scripted_spawns):
    for entry, zones in scripted_spawns.items():
        for zone, points in zones.items():
            coordinates = {tuple(point[:2]) for point in points}
            # Replace the SQL copy's visibility condition at matching locations,
            # retaining any difficulty restriction. Other SQL locations stay intact.
            existing = spawns_by_entry[entry][zone]
            replacements = []
            for point in points:
                matching = [old for old in existing if tuple(old[:2]) == tuple(point[:2])]
                if matching and all(len(old) >= 5 for old in matching):
                    replacements.extend([*point, *old[3:5]] for old in matching)
                else:
                    replacements.append(point)
            existing[:] = [point for point in existing if tuple(point[:2]) not in coordinates]
            existing.extend(replacements)


def find_map_difficulty_dbc(source_root, explicit_path=None):
    if explicit_path:
        path = Path(explicit_path)
        if not path.exists():
            raise FileNotFoundError(f"MapDifficulty.dbc not found: {path}")
        return path

    acore_root = Path(source_root).resolve().parent
    candidates = (
        acore_root / "build/bin/RelWithDebInfo/Data/dbc/MapDifficulty.dbc",
        acore_root / "build/bin/Release/Data/dbc/MapDifficulty.dbc",
        acore_root / "build/bin/Debug/Data/dbc/MapDifficulty.dbc",
    )
    for path in candidates:
        if path.exists():
            return path

    raise FileNotFoundError(
        "MapDifficulty.dbc was not found in the AzerothCore build. "
        "Pass --map-difficulty-dbc with the DBC used by the server."
    )


def load_map_difficulty_masks(dbc_path):
    data = Path(dbc_path).read_bytes()
    if len(data) < 20 or data[:4] != b"WDBC":
        raise ValueError(f"Invalid MapDifficulty.dbc header: {dbc_path}")

    record_count, field_count, record_size, _ = struct.unpack_from("<4I", data, 4)
    if field_count < 3 or record_size < 12 or len(data) < 20 + record_count * record_size:
        raise ValueError(f"Invalid MapDifficulty.dbc layout: {dbc_path}")

    masks = defaultdict(int)
    for record_index in range(record_count):
        record_offset = 20 + record_index * record_size
        _, map_id, difficulty = struct.unpack_from("<3I", data, record_offset)
        if difficulty < 32:
            masks[map_id] |= 1 << difficulty
    return dict(masks)


@lru_cache(maxsize=1)
def load_server_phase_profiles():
    """Read the client's supported regions so NPC and object generation agree."""
    text = strip_lua_comments((TOOLS_DIR.parent / "Modules/Network/QuestieServer.lua").read_text(encoding="utf-8"))
    tables = []
    for name in ("phaseZones", "phaseAreas", "phaseMasks"):
        match = re.search(rf"local\s+{name}\s*=\s*\{{", text)
        if not match:
            raise ValueError(f"QuestieServer.lua: missing {name} profile table")
        tables.append(LuaParser(extract_balanced_braces(text, match.end() - 1)).parse())
    return tables


def add_acore_spawn_visibility(point, row, map_difficulty_masks):
    map_id = int(row.get("map") or 0)
    spawn_mask = int(row.get("spawnMask") or row.get("spawnmask") or 1)
    supported_mask = int(map_difficulty_masks.get(map_id) or 1)

    # World and transport maps have no selectable instance difficulty. For an
    # instance, only store metadata when this row is restricted compared with
    # the difficulties supported by the server's MapDifficulty.dbc.
    # Only audited phase regions are enabled. SQL exports must retain areaId;
    # an unknown area must not be guessed from a coarse zone rectangle.
    area_id = int(row.get("areaId") or row.get("areaid") or 0)
    zone_id = int(row.get("zoneId") or row.get("zoneid") or 0)
    phase_zones, phase_areas, _ = load_server_phase_profiles()
    if area_id and (area_id in phase_areas.get(map_id, {}) or zone_id in phase_zones.get(map_id, {})):
        phase_mask = int(row.get("phaseMask", row.get("phasemask", 1)))
        return [point[0], point[1], point[2] if len(point) >= 3 else 0,
                spawn_mask, map_id, phase_mask, area_id]
    if supported_mask == 1 or spawn_mask == supported_mask:
        return point

    return [point[0], point[1], 0, spawn_mask, map_id]


def add_acore_spawn_identity(point, row):
    """Attach a DB spawn identity without inventing phase or difficulty restrictions."""
    guid = int(row.get("guid") or 0)
    if not guid or point[:2] == [-1, -1]:
        return list(point)
    identified = list(point) + [0] * (8 - len(point))
    identified[4] = int(row.get("map") or 0)
    identified[7] = guid
    return identified


class LuaParser:
    def __init__(self, text, constants=None):
        self.text = text
        self.length = len(text)
        self.index = 0
        self.constants = constants or {}

    def parse(self):
        value = self.parse_value()
        self.skip_ws()
        return value

    def skip_ws(self):
        while self.index < self.length and self.text[self.index] in " \t\r\n":
            self.index += 1

    def peek(self):
        return self.text[self.index] if self.index < self.length else ""

    def parse_value(self):
        self.skip_ws()
        char = self.peek()
        if char == "{":
            return self.parse_table()
        if char in ("'", '"'):
            return self.parse_string()
        if char == "-" or char.isdigit():
            return self.parse_number()
        ident = self.parse_identifier()
        if ident == "nil":
            return None
        if ident == "true":
            return True
        if ident == "false":
            return False
        if ident in self.constants:
            return self.constants[ident]
        raise ValueError(f"Unsupported Lua token near {self.text[self.index:self.index + 48]!r}")

    def parse_table(self):
        self.expect("{")
        array_items = []
        keyed_items = {}
        has_keyed_items = False

        while True:
            self.skip_ws()
            if self.peek() == "}":
                self.index += 1
                if has_keyed_items:
                    for offset, value in enumerate(array_items, start=1):
                        keyed_items[offset] = value
                    return keyed_items
                return array_items

            if self.peek() == "[":
                has_keyed_items = True
                self.index += 1
                key = self.parse_value()
                self.skip_ws()
                self.expect("]")
                self.skip_ws()
                self.expect("=")
                value = self.parse_value()
                keyed_items[key] = value
            else:
                save_index = self.index
                ident = self.try_parse_identifier()
                if ident:
                    self.skip_ws()
                    if self.peek() == "=":
                        has_keyed_items = True
                        self.index += 1
                        keyed_items[ident] = self.parse_value()
                    else:
                        self.index = save_index
                        array_items.append(self.parse_value())
                else:
                    array_items.append(self.parse_value())

            self.skip_ws()
            if self.peek() in {",", ";"}:
                self.index += 1
                continue
            if self.peek() == "}":
                continue
            raise ValueError(f"Unexpected character in Lua table: {self.peek()!r}")

    def parse_string(self):
        quote = self.peek()
        self.index += 1
        chars = []

        while self.index < self.length:
            char = self.text[self.index]
            self.index += 1
            if char == "\\":
                if self.index >= self.length:
                    break
                escaped = self.text[self.index]
                self.index += 1
                chars.append({
                    "n": "\n",
                    "r": "\r",
                    "t": "\t",
                    "'": "'",
                    '"': '"',
                    "\\": "\\",
                }.get(escaped, escaped))
                continue
            if char == quote:
                return "".join(chars)
            chars.append(char)

        raise ValueError("Unterminated Lua string")

    def parse_number(self):
        start = self.index
        if self.peek() == "-":
            self.index += 1
        while self.index < self.length and self.text[self.index].isdigit():
            self.index += 1
        if self.index < self.length and self.text[self.index] == ".":
            self.index += 1
            while self.index < self.length and self.text[self.index].isdigit():
                self.index += 1
            return float(self.text[start:self.index])
        return int(self.text[start:self.index])

    def parse_identifier(self):
        ident = self.try_parse_identifier()
        if not ident:
            raise ValueError(f"Expected identifier near {self.text[self.index:self.index + 48]!r}")
        return ident

    def try_parse_identifier(self):
        self.skip_ws()
        match = re.match(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*", self.text[self.index :])
        if not match:
            return None
        self.index += len(match.group(0))
        return match.group(0)

    def expect(self, char):
        self.skip_ws()
        if self.peek() != char:
            raise ValueError(f"Expected {char!r}, got {self.peek()!r}")
        self.index += 1


def parse_zone_ids(repo_root):
    text = strip_lua_comments((repo_root / "Database/Zones/zoneTables.lua").read_text(encoding="utf-8"))
    start = text.find("ZoneDB.private.zoneIDs")
    if start == -1:
        return {}
    table_text = extract_balanced_braces(text, text.find("{", start))
    assignments = {}
    for name, raw_value in re.findall(r"(?m)^\s*([A-Z][A-Z0-9_]*)\s*=\s*(-?\d+)\s*,", table_text):
        value = int(raw_value)
        previous = assignments.get(name)
        if previous is not None and previous != value:
            raise ValueError(f"Conflicting zone ID constant {name}: {previous} and {value}")
        assignments[name] = value
    return assignments


def parse_zone_id_constants(repo_root):
    parsed = parse_zone_ids(repo_root)
    constants = {}
    for name, value in parsed.items():
        if isinstance(value, int):
            constants[f"zoneIDs.{name}"] = value
            constants[f"ZoneDB.private.zoneIDs.{name}"] = value
    return constants


def wdm_floor_zone_constant_name(data):
    source_map_id = float(data.get("mapID") or 0)
    floor = int(round((source_map_id - int(source_map_id)) * 10))
    instance_name = re.sub(r"([a-z])([A-Z])", r"\1_\2", str(data.get("name") or "INSTANCE"))
    instance_name = re.sub(r"[^A-Za-z0-9_]", "_", instance_name).upper()
    return f"WDM_{instance_name}_FLOOR_{floor}"


def parse_zone_id_names(repo_root, zone_maps=None):
    parsed = parse_zone_ids(repo_root)
    zone_names = {}
    for name, value in parsed.items():
        if isinstance(value, int) and value not in zone_names:
            zone_names[value] = name
    if zone_maps:
        for ui_id in zone_maps["floor_threshold_by_ui"]:
            zone_id = zone_maps["ui_to_zone"].get(ui_id)
            if zone_id and zone_id >= zone_maps["wdm_floor_zone_id_offset"]:
                zone_names[zone_id] = wdm_floor_zone_constant_name(zone_maps["wdm_instance_map_data"][ui_id])
    return zone_names


def extract_lua_assigned_tables(text, assignment_pattern):
    tables = []
    for match in re.finditer(assignment_pattern, text):
        open_brace = text.find("{", match.start())
        if open_brace != -1:
            tables.append(extract_balanced_braces(text, open_brace))
    return tables


def parse_ui_map_tables(text, assignment_pattern):
    rows = {}
    for table_text in extract_lua_assigned_tables(text, assignment_pattern):
        parsed = LuaParser(table_text).parse()
        if not isinstance(parsed, dict):
            continue
        for ui_id, row in parsed.items():
            if isinstance(ui_id, int) and isinstance(row, dict):
                rows[int(ui_id)] = row
    return rows


def load_wdm_floor_thresholds(wdm_root):
    if not wdm_root:
        return {}

    db2_root = Path(wdm_root) / "patch-enUS-M extracted/DBFilesClient"
    dungeon_map_path = db2_root / "DungeonMap.csv"
    chunk_path = db2_root / "DungeonMapChunk.csv"
    if not dungeon_map_path.exists() or not chunk_path.exists():
        return {}

    dungeon_maps = {}
    with dungeon_map_path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            dungeon_maps[int(row["ID"])] = (int(row["MapID"]), int(row["FloorIndex"]))

    thresholds_by_dungeon_map = {}
    with chunk_path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            minimum_z = float(row["MinZ"])
            if minimum_z <= -9999:
                continue
            dungeon_map_id = int(row["DungeonMapID"])
            thresholds_by_dungeon_map[dungeon_map_id] = max(
                minimum_z,
                thresholds_by_dungeon_map.get(dungeon_map_id, minimum_z),
            )

    return {
        instance_floor: thresholds_by_dungeon_map.get(dungeon_map_id)
        for dungeon_map_id, instance_floor in dungeon_maps.items()
    }


def parse_zone_maps(repo_root, wdm_root=None):
    text = strip_lua_comments((repo_root / "Database/Zones/zoneTables.lua").read_text(encoding="utf-8"))
    constants = parse_zone_id_constants(repo_root)
    constants.setdefault("ZoneDB.private.zoneIDs.BLACKROCK_SPIRE", constants.get("ZoneDB.private.zoneIDs.LOWER_BLACKROCK_SPIRE", 1583))
    constants.setdefault("zoneIDs.BLACKROCK_SPIRE", constants.get("zoneIDs.LOWER_BLACKROCK_SPIRE", 1583))

    area_to_ui = {}
    start = text.find("ZoneDB.private.areaIdToUiMapId")
    if start != -1:
        parsed = LuaParser(extract_balanced_braces(text, text.find("{", start)), constants).parse()
        area_to_ui.update({int(k): int(v) for k, v in parsed.items() if isinstance(k, int) and isinstance(v, int)})

    special_to_ui = {}
    start = text.find("ZoneDB.private.specialZoneIdToUiMapId")
    if start != -1:
        parsed = LuaParser(extract_balanced_braces(text, text.find("{", start)), constants).parse()
        special_to_ui.update({int(k): int(v) for k, v in parsed.items() if isinstance(k, int) and isinstance(v, int)})

    wdm_floor_zone_to_ui = {}
    start = text.find("ZoneDB.private.wdmInstanceFloorZoneIdToUiMapId")
    if start != -1:
        parsed = LuaParser(extract_balanced_braces(text, text.find("{", start)), constants).parse()
        wdm_floor_zone_to_ui.update({int(k): int(v) for k, v in parsed.items() if isinstance(k, int) and isinstance(v, int)})

    instance_to_zone = {}
    start = text.find("ZoneDB.instanceIdToAreaId")
    if start != -1:
        table_text = extract_balanced_braces(text, text.find("{", start))
        for instance, value in re.findall(r"\[(\d+)\]\s*=\s*([^,\n]+)", table_text):
            value = value.strip()
            if value in constants:
                instance_to_zone[int(instance)] = int(constants[value])
            elif re.fullmatch(r"\d+", value):
                instance_to_zone[int(instance)] = int(value)

    dungeon_parent_by_area = {}
    start = text.find("ZoneDB.private.dungeons")
    if start != -1:
        parsed = LuaParser(extract_balanced_braces(text, text.find("{", start)), constants).parse()
        for area_id, row in parsed.items():
            if isinstance(area_id, int) and isinstance(row, list) and len(row) >= 3 and isinstance(row[2], int):
                dungeon_parent_by_area[int(area_id)] = int(row[2])

    ui_text = strip_lua_comments((repo_root / "Compat/UiMapData.lua").read_text(encoding="utf-8"))
    base_ui_map_data = parse_ui_map_tables(ui_text, r"(?:QuestieCompat\.)?UiMapData\s*=\s*\{")
    wdm_world_map_data = parse_ui_map_tables(ui_text, r"local\s+wdmWorldMapData\s*=\s*\{")
    wdm_instance_map_data = parse_ui_map_tables(ui_text, r"local\s+wdmInstanceMapData\s*=\s*\{")

    offset_match = re.search(r"wdmInstanceFloorZoneIdOffset\s*=\s*(\d+)", text)
    wdm_floor_zone_id_offset = int(offset_match.group(1)) if offset_match else WDM_INSTANCE_FLOOR_ZONE_ID_OFFSET

    # Match Compat/UiMapData.lua's runtime load order while retaining each
    # source table so callers can distinguish optional WDM geometry.
    ui_map_data = dict(base_ui_map_data)
    ui_map_data.update(wdm_world_map_data)
    ui_map_data.update(wdm_instance_map_data)
    ui_map_sources = {ui_id: "base" for ui_id in base_ui_map_data}
    ui_map_sources.update({ui_id: "wdmWorld" for ui_id in wdm_world_map_data})
    ui_map_sources.update({ui_id: "wdmInstance" for ui_id in wdm_instance_map_data})

    ui_to_zone = {}
    for zone_id, ui_id in area_to_ui.items():
        ui_to_zone.setdefault(ui_id, zone_id)
    for zone_id, ui_id in special_to_ui.items():
        ui_to_zone.setdefault(ui_id, zone_id)
    for zone_id, ui_id in wdm_floor_zone_to_ui.items():
        ui_to_zone.setdefault(ui_id, zone_id)

    source_floor_thresholds = load_wdm_floor_thresholds(wdm_root)
    floor_threshold_by_ui = {}
    for ui_id, data in wdm_instance_map_data.items():
        source_map_id = data.get("mapID")
        instance = data.get("instance")
        if not isinstance(source_map_id, (int, float)) or not isinstance(instance, int):
            continue
        floor = int(round((float(source_map_id) - int(float(source_map_id))) * 10))
        if floor and instance in instance_to_zone and ui_id in ui_to_zone:
            floor_threshold_by_ui[ui_id] = source_floor_thresholds.get((instance, floor))

    ui_by_instance = defaultdict(list)
    for ui_id, data in ui_map_data.items():
        instance = data.get("instance")
        if isinstance(instance, int):
            ui_by_instance[instance].append(ui_id)

    # The client packs the blood elf and draenei zones onto maps 0/1, while
    # AzerothCore stores their world positions on map 530. Their native AC
    # rectangles already supply the required transform; include those zones
    # in map 530's fallback search as well as their client map search. This
    # also covers sea/subzone IDs without a directly mapped UI rectangle.
    for map_id, zone_id in ACORE_WORLD_RECT_OVERRIDES:
        ui_id = special_to_ui.get(zone_id) or area_to_ui.get(zone_id) or wdm_floor_zone_to_ui.get(zone_id)
        if ui_id in ui_map_data and ui_id not in ui_by_instance[map_id]:
            ui_by_instance[map_id].append(ui_id)

    return {
        "area_to_ui": area_to_ui,
        "special_to_ui": special_to_ui,
        "wdm_floor_zone_to_ui": wdm_floor_zone_to_ui,
        "instance_to_zone": instance_to_zone,
        "dungeon_parent_by_area": dungeon_parent_by_area,
        "ui_to_zone": ui_to_zone,
        "ui_map_data": ui_map_data,
        "base_ui_map_data": base_ui_map_data,
        "wdm_world_map_data": wdm_world_map_data,
        "wdm_instance_map_data": wdm_instance_map_data,
        "ui_map_sources": ui_map_sources,
        "ui_by_instance": ui_by_instance,
        "wdm_floor_zone_id_offset": wdm_floor_zone_id_offset,
        "floor_threshold_by_ui": floor_threshold_by_ui,
        "world_rect_overrides": ACORE_WORLD_RECT_OVERRIDES,
    }


def zone_to_ui(zone_id, zone_maps):
    if not zone_id:
        return None
    ui_id = (
        zone_maps["special_to_ui"].get(zone_id)
        or zone_maps["area_to_ui"].get(zone_id)
        or zone_maps["wdm_floor_zone_to_ui"].get(zone_id)
    )
    if ui_id:
        return ui_id
    return None


def convert_world_to_zone(x, y, zone_id, zone_maps, allow_out_of_bounds=False, map_id=None):
    ui_id = zone_to_ui(zone_id, zone_maps)
    if not ui_id:
        return None
    data = zone_maps["ui_map_data"].get(ui_id)
    if not data:
        return None
    width, height, left, top = data.get(1), data.get(2), data.get(3), data.get(4)
    if not width or not height:
        return None
    override = zone_maps.get("world_rect_overrides", {}).get((map_id, zone_id))
    if override:
        left = override["left"]
        top = override["top"]
    local_x = (left - x) / width
    local_y = (top - y) / height
    if not allow_out_of_bounds and (local_x < 0 or local_x > 1 or local_y < 0 or local_y > 1):
        return None
    return [round(local_x * 100, 2), round(local_y * 100, 2)]


def out_of_bounds_distance(point):
    return max(0, -point[0], point[0] - 100, -point[1], point[1] - 100)


def clamp_zone_edge_point(point):
    return [
        round(min(max(point[0], ZONE_EDGE_CLAMP_MIN), ZONE_EDGE_CLAMP_MAX), 2),
        round(min(max(point[1], ZONE_EDGE_CLAMP_MIN), ZONE_EDGE_CLAMP_MAX), 2),
    ]


def convert_near_world_to_zone(x, y, zone_id, zone_maps, map_id=None):
    point = convert_world_to_zone(x, y, zone_id, zone_maps, allow_out_of_bounds=True, map_id=map_id)
    if not point or out_of_bounds_distance(point) > ZONE_EDGE_TOLERANCE:
        return None
    return clamp_zone_edge_point(point)


def resolve_wdm_instance_floor(x, y, z, map_id, zone_maps):
    if map_id not in zone_maps["instance_to_zone"]:
        return None, None

    matches = []
    for ui_id in zone_maps["ui_by_instance"].get(map_id, []):
        data = zone_maps["wdm_instance_map_data"].get(ui_id)
        if not data:
            continue
        zone_id = zone_maps["ui_to_zone"].get(ui_id)
        point = convert_world_to_zone(x, y, zone_id, zone_maps, map_id=map_id)
        if not point:
            continue
        area = abs(float(data.get(1) or 0) * float(data.get(2) or 0))
        threshold = zone_maps.get("floor_threshold_by_ui", {}).get(ui_id)
        matches.append((threshold, area, zone_id, point))

    if not matches:
        return None, None

    eligible = [match for match in matches if match[0] is not None and match[0] <= z]
    if eligible:
        _, _, zone_id, point = max(eligible, key=lambda match: (match[0], match[1], -match[2]))
        return zone_id, point

    baseline = [match for match in matches if match[0] is None]
    _, _, zone_id, point = max(baseline or matches, key=lambda match: (match[1], -match[2]))
    return zone_id, point


def source_zone_candidates(row, zone_maps):
    """Read geographic source metadata without requiring a map transform."""
    for field in ("zoneId", "areaId"):
        value = int(row.get(field) or row.get(field.lower()) or 0)
        if field == "areaId":
            value = ACORE_AREA_ID_OVERRIDES.get(value, value)
        ui = (zone_maps.get("special_to_ui", {}).get(value)
              or zone_maps.get("area_to_ui", {}).get(value)
              or zone_maps.get("wdm_floor_zone_to_ui", {}).get(value))
        if ui is not None:
            return [int(zone_maps.get("ui_to_zone", {}).get(ui, value))]
    map_id = int(row.get("map") or 0)
    zone = zone_maps.get("instance_to_zone", {}).get(map_id)
    if zone:
        return [int(zone)]
    # A continent is not itself a preferred geographic zone. Other source maps
    # can identify a single instance zone even when its XY transform is absent.
    if map_id not in (0, 1, 530, 571):
        zones = {int(zone_maps["ui_to_zone"][ui])
                 for ui in zone_maps.get("ui_by_instance", {}).get(map_id, [])
                 if ui in zone_maps.get("ui_to_zone", {})}
        if len(zones) == 1:
            return sorted(zones)
    return []


def resolve_coordinate_zone(row, zone_maps):
    candidates = []
    guid = int(row.get("guid") or 0)
    area_id = int(row.get("areaId") or row.get("areaid") or 0)
    area_id = ACORE_AREA_ID_OVERRIDES.get(area_id, area_id)
    zone_id = int(row.get("zoneId") or row.get("zoneid") or 0)
    map_id = int(row.get("map") or 0)
    position_x = float(row.get("position_x") or 0)
    position_y = float(row.get("position_y") or 0)
    position_z = float(row.get("position_z") or 0)
    axis_pairs = (
        # Classic continent coordinates need this client-world axis order.
        (position_y, position_x),
        # Outland/Northrend/instance map transforms commonly match AC order.
        (position_x, position_y),
    )

    # Prefer the more-specific area when AzerothCore provides both fields.
    # For example, Dalaran's Circle of Wills uses zoneId 4395 (Dalaran) and
    # areaId 4570 (Circle of Wills) in the AC creature export.
    spawn_zone_override = ACORE_CREATURE_SPAWN_ZONE_OVERRIDES.get(guid)
    if spawn_zone_override:
        for x, y in axis_pairs:
            point = convert_world_to_zone(x, y, spawn_zone_override, zone_maps, map_id=map_id)
            if point:
                return spawn_zone_override, point
    if area_id:
        candidates.append(area_id)
    if zone_id and zone_id not in candidates:
        candidates.append(zone_id)
    instance_zone = zone_maps["instance_to_zone"].get(map_id)
    if instance_zone and instance_zone not in candidates:
        candidates.append(instance_zone)

    for x, y in axis_pairs:
        floor_zone_id, floor_point = resolve_wdm_instance_floor(
            x,
            y,
            position_z,
            map_id,
            zone_maps,
        )
        if floor_zone_id:
            return floor_zone_id, floor_point

        for zone_id in candidates:
            point = convert_world_to_zone(x, y, zone_id, zone_maps, map_id=map_id)
            if point:
                return zone_id, point

        fallback_candidates = []
        for ui_id in zone_maps["ui_by_instance"].get(map_id, []):
            data = zone_maps["ui_map_data"].get(ui_id)
            if data and data.get("worldMapOnly"):
                continue
            zone_id = zone_maps["ui_to_zone"].get(ui_id)
            if not zone_id:
                continue
            point = convert_world_to_zone(x, y, zone_id, zone_maps, map_id=map_id)
            if point:
                area = abs(float(data.get(1) or 0) * float(data.get(2) or 0)) if data else 0
                fallback_candidates.append((area, zone_id, point))
        if fallback_candidates:
            _, zone_id, point = max(fallback_candidates, key=lambda item: (item[0], -item[1]))
            return zone_id, point

        near_candidates = []
        for zone_id in candidates:
            point = convert_near_world_to_zone(x, y, zone_id, zone_maps, map_id=map_id)
            if point:
                data = zone_maps["ui_map_data"].get(zone_to_ui(zone_id, zone_maps))
                area = abs(float(data.get(1) or 0) * float(data.get(2) or 0)) if data else 0
                near_candidates.append((area, zone_id, point))
        for ui_id in zone_maps["ui_by_instance"].get(map_id, []):
            data = zone_maps["ui_map_data"].get(ui_id)
            if data and data.get("worldMapOnly"):
                continue
            zone_id = zone_maps["ui_to_zone"].get(ui_id)
            if not zone_id:
                continue
            point = convert_near_world_to_zone(x, y, zone_id, zone_maps, map_id=map_id)
            if point:
                area = abs(float(data.get(1) or 0) * float(data.get(2) or 0)) if data else 0
                near_candidates.append((area, zone_id, point))
        if near_candidates:
            _, zone_id, point = max(near_candidates, key=lambda item: (item[0], -item[1]))
            return zone_id, point

    return None, None


def load_rows_from_sql_file(sql_path, table_name, key_columns, default_columns=None, row_filter=None):
    columns = list(default_columns or extract_sql_columns(sql_path, table_name))
    rows = {}
    skipped_mutations = 0
    sql_context = {}
    raw_text = sql_path.read_text(encoding="utf-8")
    text = strip_sql_comments(raw_text)

    for statement in split_sql_statements(text):
        upper = statement.upper()
        if upper.startswith("SET "):
            apply_variable_set(statement, sql_context)
            continue
        if not statement_targets_table(statement, table_name):
            continue
        if upper.startswith(("INSERT", "REPLACE")):
            skipped_mutations += apply_multirow_insert(statement, table_name, columns, rows, key_columns, sql_context,
                                                       row_filter=row_filter)

    return list(rows.values()), skipped_mutations


def load_filtered_row_table(source_root, table_name, key_columns, row_filter, include_modules=False, ignore_statement=None):
    """Replay one AC table while retaining only rows used by this generator."""
    source_root = Path(source_root)
    base_file = source_root / "data/sql/base/db_world" / f"{table_name}.sql"
    columns = extract_sql_columns(base_file, table_name)
    rows = {}
    skipped_mutations = 0
    sql_context = {}

    for path in source_sql_files(source_root, table_name, include_modules):
        raw_text, statements = load_sql_statements(str(path.resolve()))
        if not re.search(rf"\b{re.escape(table_name)}\b|@\w+", raw_text, re.IGNORECASE):
            continue
        for statement in statements:
            upper = statement.upper()
            if re.match(r"\s*SET\b", statement, re.IGNORECASE):
                apply_variable_set(statement, sql_context)
                continue
            if not statement_targets_table(statement, table_name):
                continue
            if ignore_statement is not None and ignore_statement(statement):
                continue
            if upper.startswith(("INSERT", "REPLACE")):
                skipped_mutations += apply_multirow_insert(
                    statement,
                    table_name,
                    columns,
                    rows,
                    key_columns,
                    sql_context,
                    row_filter=row_filter,
                )
            elif upper.startswith("DELETE"):
                skipped_mutations += apply_multirow_delete(statement, table_name, rows, sql_context)
            elif upper.startswith("UPDATE"):
                skipped_mutations += apply_multirow_update(statement, table_name, rows, sql_context)

    return [row for row in rows.values() if row_filter(row)], skipped_mutations


def find_sibling_creature_multispawn_sql(creature_sql):
    if not creature_sql:
        return None

    creature_sql = Path(creature_sql)
    candidates = (
        creature_sql.with_name("table-creature_multispawn.sql"),
        creature_sql.with_name("creature_multispawn.sql"),
        creature_sql.with_name("table_creature_multispawn.sql"),
    )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def load_creature_multispawn_rows(source_root, include_modules=False, creature_multispawn_sql=None, creature_sql=None):
    if creature_multispawn_sql:
        return load_rows_from_sql_file(
            Path(creature_multispawn_sql),
            "creature_multispawn",
            ("spawnId", "entry"),
            CREATURE_MULTISPAWN_COLUMNS,
        )

    sibling_sql = find_sibling_creature_multispawn_sql(creature_sql)
    if sibling_sql:
        return load_rows_from_sql_file(
            sibling_sql,
            "creature_multispawn",
            ("spawnId", "entry"),
            CREATURE_MULTISPAWN_COLUMNS,
        )

    base_file = Path(source_root) / "data/sql/base/db_world/creature_multispawn.sql"
    if base_file.exists():
        return load_row_table(source_root, "creature_multispawn", ("spawnId", "entry"), include_modules)

    return [], 0


def get_primary_creature_entry(row):
    return int(row.get("id1") or row.get("id") or row.get("entry") or 0)


def get_creature_entries(row, multispawns_by_guid):
    guid = int(row.get("guid") or 0)
    entries = []
    seen = set()
    for column in ("id1", "id", "entry", "id2", "id3"):
        entry = int(row.get(column) or 0)
        if entry and entry not in seen:
            entries.append(entry)
            seen.add(entry)
    for entry in sorted(multispawns_by_guid.get(guid, ())):
        if entry and entry not in seen:
            entries.append(entry)
            seen.add(entry)
    return entries


def parse_friendly_to_faction(faction_id, faction_templates):
    template = faction_templates.get(int(faction_id or 0))
    if not template:
        return ""

    alliance_templates = [1, 3, 4, 115, 1629]
    horde_templates = [2, 5, 6, 116, 1610]
    friendly_a = any(is_friendly_to(template, faction_templates.get(other_id)) for other_id in alliance_templates)
    friendly_h = any(is_friendly_to(template, faction_templates.get(other_id)) for other_id in horde_templates)
    if friendly_a and friendly_h:
        return "AH"
    if friendly_a:
        return "A"
    if friendly_h:
        return "H"
    return ""


def is_friendly_to(template, other):
    if not template or not other:
        return False
    faction = int(template.get("Faction") or 0)
    other_faction = int(other.get("Faction") or 0)
    other_group = int(other.get("FactionGroup") or 0)
    own_group = int(template.get("FactionGroup") or 0)
    other_friend_group = int(other.get("FriendGroup") or 0)

    if faction and other_faction:
        for column in ("Enemies_1", "Enemies_2", "Enemies_3", "Enemies_4"):
            if int(template.get(column) or 0) == other_faction:
                return False
        for column in ("Friend_1", "Friend_2", "Friend_3", "Friend_4"):
            if int(template.get(column) or 0) == other_faction:
                return True

    if int(template.get("EnemyGroup") or 0) & other_group:
        return False
    if int(template.get("FriendGroup") or 0) & other_group:
        return True
    if own_group & other_friend_group:
        return True
    return False


def spawn_origin_matches(point, result, difficulty_masks):
    """Match only the reader's explicit deduplication rules, never proximity."""
    coordinate = [round(float(point[0]), 2), round(float(point[1]), 2)]
    if coordinate != result[:2]:
        return False
    phase = lambda value: int(value[2] or 0) if len(value) >= 3 else 0
    if phase(point) != phase(result):
        return False
    if len(result) >= 7:
        return (len(point) == len(result) and point[4:] == result[4:]
                and int(point[3]) & int(result[3]) == int(point[3]))
    if len(result) >= 5:
        return (len(point) == 5 and point[4] == result[4]
                and int(point[3]) & int(result[3]) == int(point[3]))
    return len(point) < 5 or (len(point) == 5 and
        int(point[3]) & int(difficulty_masks.get(int(point[4]), 0)) == int(point[3]))


def index_geometry_origins(npcs, spawn_origins, path_origins, difficulty_masks):
    result = {}
    for npc_id, npc in npcs.items():
        fields = {}
        for field, origins in (("spawns", spawn_origins), ("waypoints", path_origins)):
            zones = {}
            for zone, values in npc.get(field, {}).items():
                candidates = origins.get(npc_id, {}).get(zone, [])
                indexed = {}
                # Bucket by coordinate to avoid a quadratic scan over large zones.
                buckets = defaultdict(list)
                for value, identity in candidates:
                    key = tuple(round(float(v), 2) for v in value[:2]) if field == "spawns" else tuple(value[0])
                    buckets[key].append((value, identity))
                for index, value in enumerate(values, 1):
                    key = tuple(value[:2]) if field == "spawns" else tuple(value[0])
                    matches = {identity for original, identity in buckets.get(key, [])
                               if (spawn_origin_matches(original, value, difficulty_masks)
                                   if field == "spawns" else original == value)}
                    if matches:
                        indexed[f"n:{index}"] = sorted(matches)
                if indexed:
                    zones[f"n:{zone}"] = indexed
            if zones:
                fields[field] = zones
        if fields:
            result[str(npc_id)] = fields
    return result


def index_partial_spawn_coverage(provenance, spawns, origins, unmapped_guids, difficulty_masks):
    """Expose incomplete mapping for explicit review, without declaring it complete."""
    def typed(value):
        if isinstance(value, list):
            return {f"n:{i}": typed(v) for i, v in enumerate(value, 1) if v is not None}
        if isinstance(value, dict):
            return {f"n:{key}": typed(v) for key, v in value.items()}
        return value

    partial = {entry: {"spawns": sort_coordinate_table(spawns.get(entry, {}), difficulty_masks)}
               for entry in unmapped_guids}
    indexed = index_geometry_origins(partial, origins, {}, difficulty_masks)
    for entry, row in partial.items():
        provenance.setdefault(str(entry), {})["spawnCoverage"] = {
            "unmappedGuids": sorted(unmapped_guids[entry]),
            "mapped": typed(row["spawns"]),
            "origins": indexed.get(str(entry), {}).get("spawns", {}),
        }


def index_partial_waypoint_coverage(provenance, waypoints, origins, unmapped_paths):
    """Keep verified paths available for an explicit review of failed links."""
    def typed(value):
        if isinstance(value, list):
            return {f"n:{i}": typed(v) for i, v in enumerate(value, 1) if v is not None}
        if isinstance(value, dict):
            return {f"n:{key}": typed(v) for key, v in value.items()}
        return value

    partial = {entry: {"waypoints": sort_waypoint_table(waypoints.get(entry, {}))}
               for entry in unmapped_paths}
    indexed = index_geometry_origins(partial, {}, origins, {})
    for entry, row in partial.items():
        provenance.setdefault(str(entry), {})["waypointCoverage"] = {
            "unmappedPaths": sorted(unmapped_paths[entry]),
            "mapped": typed(row["waypoints"]),
            "origins": indexed.get(str(entry), {}).get("waypoints", {}),
        }


def project_waypoint_path(creature, path_rows, zone_maps):
    """Project consecutive map/floor sections without bridging separate visits."""
    base_zone, _ = resolve_coordinate_zone(creature, zone_maps)
    preferred_zone = base_zone
    sections = []
    for index, point_row in enumerate(path_rows, 1):
        if point_row.get("position_x") is None or point_row.get("position_y") is None:
            return None
        point_source = dict(creature)
        # GUID-specific floor overrides describe the static spawn, not a moving
        # waypoint. Resolve each waypoint using its own height, including zero.
        point_source.pop("guid", None)
        for column in ("position_x", "position_y", "position_z"):
            if point_row.get(column) is not None:
                point_source[column] = point_row[column]
        if preferred_zone and preferred_zone != base_zone:
            # Map rectangles overlap. Keep the current map while it still fits
            # instead of jumping between overlapping maps at each waypoint.
            point_source.update(areaId=0, areaid=0, zoneId=preferred_zone, zoneid=0)
        zone, point = resolve_coordinate_zone(point_source, zone_maps)
        if not zone or not point:
            # Do not skip an unknown point and connect the positions around it.
            return None
        if not sections or sections[-1][0] != zone:
            first_point = int(point_row.get("point") or point_row.get("pointid") or index)
            sections.append((zone, first_point, []))
        sections[-1][2].append(point)
        preferred_zone = zone
    # Addon tables can contain dormant/stale path links, and SmartAI can use a
    # path only for a summoned copy located elsewhere. A static spawn's map is
    # not evidence for those remote placements. Keep that coverage unavailable
    # until a matching placement is known, rather than importing an unrelated
    # route merely because its coordinates fit some other map rectangle.
    # Floors of the same mapped dungeon remain valid regardless of spawn floor.
    if int(creature.get("map") or 0) not in zone_maps.get("instance_to_zone", {}):
        if base_zone is None or not any(zone == base_zone for zone, _, _ in sections):
            return None
    return sections


def build_acore_npcs(
    source_root,
    include_modules=False,
    repo_root=None,
    creature_sql=None,
    creature_multispawn_sql=None,
    map_difficulty_dbc=None,
    wdm_root=None,
    questie_npcs=None,
    provenance=None,
):
    source_root = Path(source_root)
    map_difficulty_dbc = find_map_difficulty_dbc(source_root, map_difficulty_dbc)
    map_difficulty_masks = load_map_difficulty_masks(map_difficulty_dbc)
    template_rows, skipped_creature_template = load_keyed_table(source_root, "creature_template", "entry", include_modules)
    acore_npc_health.validate_source(source_root)
    health_rows, skipped_health = load_row_table(source_root, "creature_classlevelstats", ("level", "class"), include_modules)
    template_health, health_diagnostics = acore_npc_health.collect(
        ({"entry": entry, **row} for entry, row in template_rows.items()), health_rows)
    if provenance is not None:
        provenance["defaultHealth"] = {"policy": "acore-template-default-rates-v1", "diagnostics": health_diagnostics}
    if creature_sql:
        creature_rows, skipped_creature = load_rows_from_sql_file(Path(creature_sql), "creature", ("guid",))
    else:
        creature_rows, skipped_creature = load_row_table(source_root, "creature", ("guid",), include_modules)
    creature_multispawn_rows, skipped_creature_multispawn = load_creature_multispawn_rows(
        source_root,
        include_modules,
        creature_multispawn_sql,
        creature_sql,
    )
    starter_rows, skipped_starter = load_row_table(source_root, "creature_queststarter", ("id", "quest"), include_modules)
    event_starter_rows, skipped_event_starter = load_row_table(
        source_root,
        "game_event_creature_quest",
        ("eventEntry", "id", "quest"),
        include_modules,
    )
    ender_rows, skipped_ender = load_row_table(source_root, "creature_questender", ("id", "quest"), include_modules)
    starts_by_entry = defaultdict(set)
    for row in starter_rows + event_starter_rows:
        entry = int(row.get("id") or 0)
        quest = int(row.get("quest") or 0)
        if entry and quest:
            starts_by_entry[entry].add(quest)

    ends_by_entry = defaultdict(set)
    for row in ender_rows:
        entry = int(row.get("id") or 0)
        quest = int(row.get("quest") or 0)
        if entry and quest:
            ends_by_entry[entry].add(quest)

    # The bridge only reports entries with quest relations. Keep identity metadata
    # for those entries, including event questgivers, rather than every creature.
    # Do not restrict by DB movement type: scripts can move an otherwise idle NPC.
    questgiver_entries = starts_by_entry.keys() | ends_by_entry.keys()
    faction_template_rows, skipped_faction_template = load_keyed_table(source_root, "factiontemplate_dbc", "ID", include_modules)
    creature_addon_rows, skipped_creature_addon = load_keyed_table(source_root, "creature_addon", "guid", include_modules)
    template_addon_rows, skipped_template_addon = load_keyed_table(source_root, "creature_template_addon", "entry", include_modules)
    waypoint_rows, skipped_waypoint = load_row_table(source_root, "waypoint_data", ("id", "point"), include_modules)
    escort_waypoint_rows, skipped_escort_waypoint = load_row_table(
        source_root,
        "waypoints",
        ("entry", "pointid"),
        include_modules,
    )
    smart_script_rows, skipped_smart_scripts = load_filtered_row_table(
        source_root,
        "smart_scripts",
        SMART_SCRIPT_KEY_COLUMNS,
        # Summoned copies need their real caller/map context. Keep all actions
        # so timed-list callers and phase/map mutations can be checked too.
        lambda row: True,
        include_modules,
    )

    spawns_by_entry = defaultdict(lambda: defaultdict(list))
    spawn_zone_counts = defaultdict(lambda: defaultdict(int))
    unmapped_spawn_entries = set()
    unmapped_spawn_guids = defaultdict(set)
    seen_spawn_entries = set()
    guid_to_creature = {}
    creatures_by_entry = defaultdict(list)
    spawn_origins = defaultdict(lambda: defaultdict(list))
    source_zone_origins = defaultdict(lambda: defaultdict(set))
    path_origins = defaultdict(lambda: defaultdict(list))
    map_stats = defaultdict(int)
    zone_maps = parse_zone_maps(Path(repo_root or ".").resolve(), wdm_root)
    multispawns_by_guid = defaultdict(set)

    for row in creature_multispawn_rows:
        guid = int(row.get("spawnId") or 0)
        entry = int(row.get("entry") or 0)
        if guid and entry:
            multispawns_by_guid[guid].add(entry)

    for row in creature_rows:
        primary_entry = get_primary_creature_entry(row)
        entries = get_creature_entries(row, multispawns_by_guid)
        guid = int(row.get("guid") or 0)
        source_zones = source_zone_candidates(row, zone_maps)
        if guid:
            guid_to_creature[guid] = row
        if entries:
            zone_id, point = resolve_coordinate_zone(row, zone_maps)
        for entry in entries:
            creatures_by_entry[entry].append(row)
            seen_spawn_entries.add(entry)
            for source_zone in source_zones:
                source_zone_origins[entry][source_zone].add(
                    f"creature:{guid}:map:{int(row.get('map') or 0)}:"
                    f"zone:{int(row.get('zoneId') or row.get('zoneid') or 0)}:"
                    f"area:{int(row.get('areaId') or row.get('areaid') or 0)}")
            if zone_id and point:
                visible_point = add_acore_spawn_visibility(point, row, map_difficulty_masks)
                if entry in questgiver_entries:
                    visible_point = add_acore_spawn_identity(visible_point, row)
                spawns_by_entry[entry][zone_id].append(visible_point)
                if provenance is not None and guid:
                    spawn_origins[entry][zone_id].append((visible_point, f"creature:{guid}:entry:{entry}"))
                spawn_zone_counts[entry][zone_id] += 1
            else:
                unmapped_spawn_entries.add(entry)
                unmapped_spawn_guids[entry].add(guid)
                map_stats["unmapped_spawns"] += 1

    scripted_spawns = load_wintergrasp_scripted_spawns(source_root, repo_root or ".", zone_maps)
    if provenance is not None:
        # Script visibility can replace coincident SQL rows. Until script table
        # identities are exposed, do not misattribute those markers to a GUID.
        for entry, zones in scripted_spawns.items():
            for zone, points in zones.items():
                replaced = {tuple(point[:2]) for point in points}
                spawn_origins[entry][zone] = [(point, identity) for point, identity in spawn_origins[entry][zone]
                                              if tuple(point[:2]) not in replaced]
    merge_scripted_spawn_locations(spawns_by_entry, scripted_spawns)
    for entry, zones in scripted_spawns.items():
        seen_spawn_entries.add(entry)
        for zone, points in zones.items():
            spawn_zone_counts[entry][zone] += len(points)

    waypoint_by_path = defaultdict(list)
    for row in waypoint_rows:
        path_id = int(row.get("id") or 0)
        if path_id:
            waypoint_by_path[path_id].append(row)
    for rows in waypoint_by_path.values():
        rows.sort(key=lambda row: int(row.get("point") or 0))

    escort_waypoint_by_path = defaultdict(list)
    for row in escort_waypoint_rows:
        path_id = int(row.get("entry") or 0)
        if path_id:
            escort_waypoint_by_path[path_id].append(row)
    for rows in escort_waypoint_by_path.values():
        rows.sort(key=lambda row: int(row.get("pointid") or 0))

    waypoints_by_entry = defaultdict(lambda: defaultdict(list))
    seen_waypoint_entries = set()
    bad_waypoint_entries = set()
    unmapped_waypoint_paths = defaultdict(set)

    def add_waypoint_path(entries, creature_candidates, path_rows, identity):
        entries = tuple(sorted(set(entries)))
        if not entries or not creature_candidates or not path_rows:
            return False

        seen_waypoint_entries.update(entries)
        for creature in creature_candidates:
            sections = project_waypoint_path(creature, path_rows, zone_maps)
            if not sections:
                continue
            for zone, first_point, points in sections:
                for entry in entries:
                    # Keep single destinations too; separate visits to a zone
                    # must remain separate paths, even if a visit has one point.
                    waypoints_by_entry[entry][zone].append(points)
                    if provenance is not None:
                        origin = f"{identity}:map-spawn:{int(creature.get('guid') or 0)}:entry:{entry}"
                        if len(sections) > 1:
                            origin += f":segment:{first_point}"
                        path_origins[entry][zone].append((unique_consecutive_points(points), origin))
            return True

        map_stats["unmapped_waypoints"] += 1
        bad_waypoint_entries.update(entries)
        for entry in entries:
            unmapped_waypoint_paths[entry].add(f"{identity}:entry:{entry}")
        return False

    for guid, creature in guid_to_creature.items():
        entries = get_creature_entries(creature, multispawns_by_guid)
        addon = creature_addon_rows.get(guid)
        if addon is not None:
            # Creature::GetCreatureAddon returns the entire GUID addon first,
            # even when its path_id is zero. Do not fall back field by field.
            assignments = [(entries, addon, f"addon:{guid}")]
        else:
            # A multispawn can choose different templates at the same GUID.
            # Each alternative inherits only its own template's addon path.
            assignments = [((entry,), template_addon_rows[entry], f"template-addon:{entry}")
                           for entry in entries if entry in template_addon_rows]
        for path_entries, path_addon, origin in assignments:
            path_id = int(path_addon.get("path_id") or 0)
            path_rows = waypoint_by_path.get(path_id)
            if path_id and path_rows:
                add_waypoint_path(path_entries, (creature,), path_rows, f"waypoint_data:{path_id}:{origin}")

    seen_smart_waypoint_assignments = set()
    for script_row in smart_script_rows:
        if int(script_row.get("source_type") or 0) != SMART_SOURCE_TYPE_CREATURE:
            continue
        if int(script_row.get("action_type") or 0) != SMART_ACTION_ESCORT_START:
            continue

        path_id = int(script_row.get("action_param2") or 0)
        path_rows = escort_waypoint_by_path.get(path_id)
        source_entry_or_guid = int(script_row.get("entryorguid") or 0)
        if not path_id or not path_rows or not source_entry_or_guid:
            continue

        if source_entry_or_guid > 0:
            entries = (source_entry_or_guid,)
            creature_candidates = creatures_by_entry.get(source_entry_or_guid, ())
        else:
            creature = guid_to_creature.get(abs(source_entry_or_guid))
            entries = get_creature_entries(creature, multispawns_by_guid) if creature else ()
            creature_candidates = (creature,) if creature else ()

        assignment_key = (tuple(sorted(entries)), path_id)
        if assignment_key in seen_smart_waypoint_assignments:
            continue
        seen_smart_waypoint_assignments.add(assignment_key)
        add_waypoint_path(entries, creature_candidates, path_rows, f"waypoints:{path_id}:smart:{source_entry_or_guid}")

    acore_npcs = {}
    for npc_id, row in template_rows.items():
        npc = {}
        for field, column in STATIC_FIELD_MAP.items():
            value = row.get(column)
            if value is None and field != "subName":
                continue
            if field == "subName":
                npc[field] = value or ""
            elif field == "name":
                npc[field] = value or ""
            else:
                npc[field] = int(value or 0)

        npc.update(template_health[int(npc_id)])

        if int(npc_id) in unmapped_spawn_entries:
            transport_spawns = [spawn for spawn in creatures_by_entry.get(int(npc_id), [])
                                if int(spawn.get("map") or 0) in (622, 623)]
            # Some captains also have ICC encounter spawns. Only annotate the
            # outdoor Icecrown fallback for its uniquely identified gunship copy.
            fallback = (questie_npcs or {}).get(int(npc_id), {}).get("spawns")
            if int(npc_id) in questgiver_entries and len(transport_spawns) == 1 and fallback and fallback.get(210):
                npc["spawns"] = annotate_gunship_fallback(fallback, transport_spawns[0])
        elif spawns_by_entry.get(int(npc_id)):
            npc["spawns"] = sort_coordinate_table(
                spawns_by_entry[int(npc_id)],
                map_difficulty_masks,
            )
            npc["zoneID"] = max(spawn_zone_counts[int(npc_id)].items(), key=lambda item: (item[1], -item[0]))[0]
        elif int(npc_id) not in seen_spawn_entries:
            npc["spawns"] = {}
            npc["zoneID"] = 0

        if int(npc_id) in bad_waypoint_entries:
            pass
        elif waypoints_by_entry.get(int(npc_id)):
            npc["waypoints"] = sort_waypoint_table(waypoints_by_entry[int(npc_id)])
        elif int(npc_id) not in seen_waypoint_entries:
            npc["waypoints"] = {}

        if starts_by_entry.get(int(npc_id)):
            npc["questStarts"] = sorted(starts_by_entry[int(npc_id)])
        else:
            npc["questStarts"] = []

        if ends_by_entry.get(int(npc_id)):
            npc["questEnds"] = sorted(ends_by_entry[int(npc_id)])
        else:
            npc["questEnds"] = []

        npc["friendlyToFaction"] = parse_friendly_to_faction(row.get("faction"), faction_template_rows)

        acore_npcs[int(npc_id)] = npc

    if provenance is not None:
        # Generation-only information. Never add it to an addon row or Lua output.
        provenance.update(index_geometry_origins(acore_npcs, spawn_origins, path_origins, map_difficulty_masks))
        index_partial_spawn_coverage(provenance, spawns_by_entry, spawn_origins,
                                     unmapped_spawn_guids, map_difficulty_masks)
        index_partial_waypoint_coverage(provenance, waypoints_by_entry, path_origins,
                                        unmapped_waypoint_paths)
        import acore_scripted_geometry
        provenance["scriptedGeometry"] = acore_scripted_geometry.collect(
            smart_script_rows, creatures_by_entry, guid_to_creature, template_rows,
            zone_maps, escort_waypoint_by_path)
        import acore_cpp_geometry
        provenance["cppGeometry"] = acore_cpp_geometry.collect(source_root, zone_maps)
        cpp_zones = acore_cpp_geometry.collect_source_zones(source_root)
        for key, data in cpp_zones["entries"].items():
            if int(key) not in acore_npcs:
                continue
            for zone in data["zones"]:
                source_zone_origins[int(key)][zone].update(data["origins"][str(zone)])
        provenance["sourceZones"] = {"version": 1, "entries": {
            str(entry): {"zones": sorted(zones), "origins": {
                str(zone): sorted(origins) for zone, origins in sorted(zones.items())}}
            for entry, zones in sorted(source_zone_origins.items())},
            "failures": cpp_zones["failures"]}
        if any(template_rows.get(entry, {}).get("ScriptName") != "npc_hor_leader_second" for entry in (37554, 36955)):
            data = provenance["cppGeometry"]["entries"]["36955"]
            for field in ("spawns", "waypoints"):
                data["failures"][field].append({"source": "creature_template:37554",
                                              "reasons": ["HoR leader script binding changed"]})

        # Runtime selectors must use the same source as the static rows. In
        # particular, Darkmoon setup spawns are not active-fair placements.
        import acore_runtime_geometry
        if len(template_rows) > 1000:
            event_rows, event_skips = load_filtered_row_table(
                source_root, "event_scripts",
                ("id", "delay", "command", "datalong", "datalong2", "dataint", "x", "y", "z", "o"),
                lambda row: int(row.get("command") or 0) == 10
                and int(row.get("datalong") or 0) in (5676, 5677, 12138), include_modules)
            selected = [row for row in creature_rows
                        if get_primary_creature_entry(row) in acore_runtime_geometry.DARKMOON_NPCS]
            guids = {int(row["guid"]) for row in selected}
            memberships, membership_skips = load_filtered_row_table(
                source_root, "game_event_creature", ("eventEntry", "guid"),
                lambda row: int(row.get("guid") or 0) in guids, include_modules,
                ignore_statement=acore_runtime_geometry.ignore_unrelated_membership_statement)
            if event_skips or membership_skips:
                raise ValueError("Runtime event geometry has unsupported SQL mutations")

            def project_runtime_point(row, maps):
                zone, point = resolve_coordinate_zone(row, maps)
                if zone is None or point is None:
                    return None, None
                point = add_acore_spawn_visibility(point, row, map_difficulty_masks)
                if get_primary_creature_entry(row) in questgiver_entries:
                    point = add_acore_spawn_identity(point, row)
                return zone, point

            provenance["runtimeGeometry"] = acore_runtime_geometry.collect(
                event_rows, selected, memberships, zone_maps, project_runtime_point)

    skipped_mutations = {
        "creature_template": skipped_creature_template,
        "creature_classlevelstats": skipped_health,
        "creature": skipped_creature,
        "creature_multispawn": skipped_creature_multispawn,
        "creature_queststarter": skipped_starter,
        "game_event_creature_quest": skipped_event_starter,
        "creature_questender": skipped_ender,
        "factiontemplate_dbc": skipped_faction_template,
        "creature_addon": skipped_creature_addon,
        "creature_template_addon": skipped_template_addon,
        "waypoint_data": skipped_waypoint,
        "waypoints": skipped_escort_waypoint,
        "smart_scripts": skipped_smart_scripts,
        **{f"mapping:{key}": value for key, value in map_stats.items()},
    }
    return acore_npcs, skipped_mutations


def annotate_gunship_fallback(spawns, row):
    """Keep outdoor marker coordinates; ship database positions are deck-local."""
    return {
        zone: [add_acore_spawn_identity(point, row) for point in points]
              if int(zone) == 210 else [list(point) for point in points]
        for zone, points in spawns.items()
    }


def sort_coordinate_table(zone_points, map_difficulty_masks=None):
    return {
        int(zone_id): sorted(
            unique_coordinate_points(points, map_difficulty_masks),
            key=lambda point: tuple(point),
        )
        for zone_id, points in sorted(zone_points.items())
    }


def merge_entrance_spawn_placeholders(acore_spawns, questie_spawns, eligible_zone_ids):
    """Keep Questie's dungeon-entrance marker beside generated interior coordinates."""
    if not isinstance(acore_spawns, dict) or not isinstance(questie_spawns, dict):
        return acore_spawns

    eligible_zone_ids = set(eligible_zone_ids or ())
    merged = {
        int(zone_id): [list(point) for point in points]
        for zone_id, points in acore_spawns.items()
    }
    for zone_id, questie_points in questie_spawns.items():
        zone_id = int(zone_id)
        if zone_id not in eligible_zone_ids or zone_id not in merged:
            continue
        for point in questie_points or ():
            if (
                isinstance(point, list)
                and len(point) >= 2
                and float(point[0]) == -1
                and float(point[1]) == -1
            ):
                merged[zone_id].append([-1, -1])

    return sort_coordinate_table(merged)


def sort_waypoint_table(zone_paths):
    return {
        int(zone_id): sorted(
            [unique_consecutive_points(path) for path in paths if path],
            key=lambda path: (path[0][0], path[0][1], len(path)),
        )
        for zone_id, paths in sorted(zone_paths.items())
    }


def unique_coordinate_points(points, map_difficulty_masks=None):
    map_difficulty_masks = map_difficulty_masks or {}
    unrestricted = set()
    restricted = defaultdict(int)
    phased = defaultdict(int)
    identified = defaultdict(int)

    for point in points:
        phase = int(point[2]) if len(point) >= 3 and point[2] else 0
        coordinate = (round(float(point[0]), 2), round(float(point[1]), 2), phase)
        if len(point) >= 8 and point[7]:
            identified[(*coordinate, int(point[4]), int(point[5]), int(point[6]), int(point[7]))] |= int(point[3])
            continue
        if len(point) >= 7:
            # Combine difficulty alternatives only when all phase conditions match.
            # Combining masks across phases would introduce nonexistent spawns.
            phased[(*coordinate, int(point[4]), int(point[5]), int(point[6]))] |= int(point[3])
            continue
        if len(point) < 5:
            unrestricted.add(coordinate)
            continue
        restricted[(*coordinate, int(point[4]))] |= int(point[3])

    result = []
    for coordinate in unrestricted:
        result.append(list(coordinate) if coordinate[2] else list(coordinate[:2]))

    restricted_coordinates = defaultdict(list)
    for (x, y, phase, map_id), spawn_mask in restricted.items():
        if (x, y, phase) in unrestricted:
            continue
        restricted_coordinates[(x, y, phase)].append((map_id, spawn_mask))

    for (x, y, phase), map_masks in restricted_coordinates.items():
        if len(map_masks) == 1:
            map_id, spawn_mask = map_masks[0]
            if spawn_mask == map_difficulty_masks.get(map_id):
                result.append([x, y, phase] if phase else [x, y])
                continue
        for map_id, spawn_mask in map_masks:
            result.append([x, y, phase, spawn_mask, map_id])

    for (x, y, phase, map_id, phase_mask, region), spawn_mask in phased.items():
        result.append([x, y, phase, spawn_mask, map_id, phase_mask, region])
    for (x, y, phase, map_id, phase_mask, region, guid), spawn_mask in identified.items():
        result.append([x, y, phase, spawn_mask, map_id, phase_mask, region, guid])
    return result


def unique_consecutive_points(points):
    result = []
    previous = None
    for point in points:
        key = [round(float(point[0]), 2), round(float(point[1]), 2)]
        if key == previous:
            continue
        result.append(key)
        previous = key
    return result


def normalize_list(value):
    if not value:
        return ()
    if isinstance(value, dict):
        value = value.values()
    return tuple(sorted({int(v) for v in value if v is not None}))


def normalize_coordinate_table(value, waypoint=False, include_phases=False):
    if not value:
        return ()
    zones = []
    if not isinstance(value, dict):
        return ()
    for zone_id, points in value.items():
        if not points:
            zones.append((int(zone_id), ()))
            continue
        if waypoint:
            paths = []
            for path in points:
                if not path:
                    continue
                # Questie corrections sometimes use { {x,y}, ... } instead of { {{x,y}, ...}, ... }.
                if isinstance(path, list) and path and isinstance(path[0], (int, float)):
                    path_points = points
                    paths = [tuple((round(float(p[0]), 2), round(float(p[1]), 2)) for p in path_points if isinstance(p, list) and len(p) >= 2)]
                    break
                paths.append(tuple((round(float(p[0]), 2), round(float(p[1]), 2)) for p in path if isinstance(p, list) and len(p) >= 2))
            zones.append((int(zone_id), tuple(sorted(paths))))
        else:
            normalized_points = []
            for point in points:
                if not isinstance(point, list) or len(point) < 2:
                    continue
                normalized_point = (round(float(point[0]), 2), round(float(point[1]), 2))
                # SQL phaseMask is separate from Questie's logical phase IDs.
                if include_phases:
                    normalized_point += (int(point[2]) if len(point) >= 3 and point[2] else 0,)
                if len(point) >= 5:
                    normalized_point += (int(point[3]), int(point[4]))
                if len(point) >= 7:
                    normalized_point += (int(point[5]), int(point[6]))
                if len(point) >= 8:
                    normalized_point += (int(point[7]),)
                normalized_points.append(normalized_point)
            zones.append((int(zone_id), tuple(sorted(normalized_points))))
    return tuple(sorted(zones))


def normalize_value(field, value, include_spawn_phases=False):
    if field in LIST_FIELDS:
        return normalize_list(value)
    if field in NESTED_FIELDS:
        return normalize_coordinate_table(value, waypoint=(field == "waypoints"), include_phases=include_spawn_phases)
    if field in STRING_FIELDS:
        return value or ""
    return int(value or 0)


def correction_value(field, acore_value):
    if field in LIST_FIELDS:
        return list(normalize_list(acore_value))
    if field in NESTED_FIELDS:
        return acore_value or {}
    if field in STRING_FIELDS:
        return acore_value or ""
    return int(acore_value or 0)


def find_differences(
    questie_npcs,
    acore_npcs,
    fields,
    include_missing_npcs=False,
    preserve_spawn_ids=None,
    entrance_marker_zone_ids=None,
):
    corrections = {}
    preserve_spawn_ids = preserve_spawn_ids or set()
    ids = set(questie_npcs)
    if include_missing_npcs:
        ids |= set(acore_npcs)

    for npc_id in sorted(ids):
        acore = acore_npcs.get(npc_id)
        if not acore:
            continue
        questie = questie_npcs.get(npc_id, {})
        for field in fields:
            if field not in acore:
                continue
            acore_value = acore.get(field)
            if field == "spawns":
                acore_value = merge_entrance_spawn_placeholders(
                    acore_value,
                    questie.get(field),
                    entrance_marker_zone_ids,
                )
            compare_phases = field == "spawns" and any(
                len(point) >= 3 and point[2]
                for points in (acore_value or {}).values() for point in points
            )
            expected = normalize_value(field, acore_value, compare_phases)
            actual = normalize_value(field, questie.get(field), compare_phases)
            if (
                npc_id in preserve_spawn_ids
                and field in {"spawns", "waypoints", "zoneID"}
                and field in acore
                and normalize_value("spawns", acore.get("spawns")) == ()
                and (field != "waypoints" or normalize_value("waypoints", acore.get("waypoints")) == ())
                and normalize_value("spawns", questie.get("spawns")) != ()
            ):
                continue
            if expected != actual:
                corrections.setdefault(npc_id, {})[field] = correction_value(field, acore_value)
    return corrections


def lua_quote(value):
    return ast.literal_eval(repr(value)).replace("\\", "\\\\").replace('"', '\\"')


def format_zone_ref(value, zone_names):
    if isinstance(value, int) or float(value).is_integer():
        zone_id = int(value)
        zone_name = zone_names.get(zone_id)
        if zone_name:
            return f"zoneIDs.{zone_name}"
        return str(zone_id)
    return format_lua_number(value)


def format_lua_value(value, zone_names=None, zone_keyed_table=False):
    zone_names = zone_names or {}
    if isinstance(value, str):
        return f'"{lua_quote(value)}"'
    if isinstance(value, list):
        if value and isinstance(value[0], list):
            return "{" + ",".join(format_lua_value(item, zone_names) for item in value) + "}"
        return "{" + ",".join(format_lua_number(item) for item in value) + "}"
    if isinstance(value, dict):
        return "{" + ", ".join(
            f"[{format_zone_ref(key, zone_names) if zone_keyed_table else int(key)}] = "
            f"{format_lua_value(value[key], zone_names)}"
            for key in sorted(value)
        ) + "}"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return format_lua_number(value)
    raise TypeError(f"Unsupported Lua value: {value!r}")


def format_lua_number(value):
    if isinstance(value, int) or float(value).is_integer():
        return str(int(value))
    return f"{float(value):.2f}".rstrip("0").rstrip(".")


def format_lua_field_value(field, value, zone_names):
    if field == "zoneID":
        return format_zone_ref(value, zone_names)
    return format_lua_value(value, zone_names, zone_keyed_table=(field in NESTED_FIELDS))


def main():
    raise SystemExit("Correction layers are retired. Use tools/generate_acore_npc_base.py; "
                     "this module retains shared source-reading helpers.")


if __name__ == "__main__":
    main()
