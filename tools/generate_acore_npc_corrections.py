import argparse
import ast
import csv
import re
import struct
import sys
from collections import defaultdict
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
    extract_function_return_tables,
    extract_lua_long_return_table,
    load_effective_questie_items,
    load_keyed_table,
    load_row_table,
    load_sql_statements,
    parse_item_keys,
    split_sql_statements,
    source_sql_files,
    statement_targets_table,
    strip_sql_comments,
    strip_lua_comments,
    validate_lua_fragment,
)


NPC_CORRECTION_FILES = [
    ("Database/Corrections/classicNPCFixes.lua", ("QuestieNPCFixes:Load",)),
    ("Database/Corrections/tbcNPCFixes.lua", ("QuestieTBCNpcFixes:Load",)),
    (
        "Database/Corrections/wotlkNPCFixes.lua",
        (
            "QuestieWotlkNpcFixes:LoadAutomatics",
            "QuestieWotlkNpcFixes:Load",
            "QuestieWotlkNpcFixes:LoadReverseLinkFixes",
        ),
    ),
]

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

DEFAULT_WDM_ROOT = Path(r"E:\downloads\WDM stuff")
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
SCALAR_FIELDS = {
    "minLevelHealth",
    "maxLevelHealth",
    "minLevel",
    "maxLevel",
    "rank",
    "factionID",
    "npcFlags",
}

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

DEFAULT_FIELD_ORDER = [
    field
    for field in FIELD_ORDER
    if field not in {
        "minLevelHealth",
        "maxLevelHealth",
    }
]

SKIPPED_FIELDS = {
    "minLevelHealth": "Omitted by default to reduce addon memory; used only for display in map/search UI.",
    "maxLevelHealth": "Omitted by default to reduce addon memory; used only for display in map/search UI.",
}

CREATURE_MULTISPAWN_COLUMNS = ("spawnId", "entry")
SMART_SOURCE_TYPE_CREATURE = 0
SMART_ACTION_ESCORT_START = 53
SMART_SCRIPT_KEY_COLUMNS = ("entryorguid", "source_type", "id", "link")


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


def add_acore_spawn_visibility(point, row, map_difficulty_masks):
    map_id = int(row.get("map") or 0)
    spawn_mask = int(row.get("spawnMask") or row.get("spawnmask") or 1)
    supported_mask = int(map_difficulty_masks.get(map_id) or 1)

    # World and transport maps have no selectable instance difficulty. For an
    # instance, only store metadata when this row is restricted compared with
    # the difficulties supported by the server's MapDifficulty.dbc.
    if supported_mask == 1 or spawn_mask == supported_mask:
        return point

    return [point[0], point[1], 0, spawn_mask, map_id]


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


def parse_npc_keys(npc_db_path):
    text = npc_db_path.read_text(encoding="utf-8")
    key_block = extract_balanced_braces(text, text.find("{", text.find("QuestieDB.npcKeys")))
    return {name: int(value) for name, value in re.findall(r"\['([^']+)'\]\s*=\s*(\d+)", key_block)}


def load_questie_npcs(npc_db_path, npc_keys):
    text = npc_db_path.read_text(encoding="utf-8")
    table_text = extract_lua_long_return_table(text, "QuestieDB.npcData")
    parsed = LuaParser(table_text).parse()
    reverse_keys = {index: name for name, index in npc_keys.items()}
    npcs = {}
    for npc_id, values in parsed.items():
        row = {}
        for index, value in enumerate(values, start=1):
            if value is not None and index in reverse_keys:
                row[reverse_keys[index]] = value
        npcs[int(npc_id)] = row
    return npcs


def npc_flag_constants():
    return {
        "QuestieDB.npcFlags.NONE": 0,
        "QuestieDB.npcFlags.GOSSIP": 1,
        "QuestieDB.npcFlags.QUEST_GIVER": 2,
        "QuestieDB.npcFlags.TRAINER": 16,
        "QuestieDB.npcFlags.VENDOR": 128,
        "QuestieDB.npcFlags.REPAIR": 4096,
        "QuestieDB.npcFlags.FLIGHT_MASTER": 8192,
        "QuestieDB.npcFlags.SPIRIT_HEALER": 16384,
        "QuestieDB.npcFlags.SPIRIT_GUIDE": 32768,
        "QuestieDB.npcFlags.INNKEEPER": 65536,
        "QuestieDB.npcFlags.BANKER": 131072,
        "QuestieDB.npcFlags.PETITIONER": 262144,
        "QuestieDB.npcFlags.TABARD_DESIGNER": 524288,
        "QuestieDB.npcFlags.BATTLEMASTER": 1048576,
        "QuestieDB.npcFlags.AUCTIONEER": 2097152,
        "QuestieDB.npcFlags.STABLEMASTER": 4194304,
        "npcFlags.NONE": 0,
        "npcFlags.GOSSIP": 1,
        "npcFlags.QUEST_GIVER": 2,
        "npcFlags.TRAINER": 16,
        "npcFlags.VENDOR": 128,
        "npcFlags.REPAIR": 4096,
        "npcFlags.FLIGHT_MASTER": 8192,
        "npcFlags.SPIRIT_HEALER": 16384,
        "npcFlags.SPIRIT_GUIDE": 32768,
        "npcFlags.INNKEEPER": 65536,
        "npcFlags.BANKER": 131072,
        "npcFlags.PETITIONER": 262144,
        "npcFlags.TABARD_DESIGNER": 524288,
        "npcFlags.BATTLEMASTER": 1048576,
        "npcFlags.AUCTIONEER": 2097152,
        "npcFlags.STABLEMASTER": 4194304,
    }


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


def iter_lua_keyed_entries(table_text):
    inner = table_text.strip()
    if not inner.startswith("{") or not inner.endswith("}"):
        return
    index = 1
    end = len(inner) - 1
    while index < end:
        while index < end and inner[index] in " \t\r\n,;":
            index += 1
        if index >= end:
            break
        if inner[index] != "[":
            index += 1
            continue
        close_bracket = inner.find("]", index + 1)
        if close_bracket == -1:
            break
        raw_key = inner[index + 1 : close_bracket].strip()
        if not re.fullmatch(r"\d+", raw_key):
            index = close_bracket + 1
            continue
        equals = inner.find("=", close_bracket + 1)
        if equals == -1:
            break
        value_start = equals + 1
        while value_start < end and inner[value_start].isspace():
            value_start += 1
        if value_start >= end or inner[value_start] != "{":
            index = value_start + 1
            continue
        value_text = extract_balanced_braces(inner, value_start)
        yield int(raw_key), value_text
        index = value_start + len(value_text)


def extract_lua_value_expression(text, start):
    index = start
    depth = 0
    in_string = None
    escaped = False
    while index < len(text):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == in_string:
                in_string = None
            index += 1
            continue
        if char in ("'", '"'):
            in_string = char
        elif char == "{":
            depth += 1
        elif char == "}":
            if depth == 0:
                return text[start:index].strip()
            depth -= 1
        elif char == "," and depth == 0:
            return text[start:index].strip()
        index += 1
    return text[start:index].strip()


def parse_targeted_correction_table(table_text, npc_keys, fields):
    constants = npc_flag_constants()
    for name in npc_keys:
        constants[f"npcKeys.{name}"] = name

    corrections = {}
    pattern = re.compile(r"\[npcKeys\.([A-Za-z0-9_]+)\]\s*=")
    for npc_id, entry_text in iter_lua_keyed_entries(table_text):
        for match in pattern.finditer(entry_text):
            field = match.group(1)
            if field not in fields:
                continue
            expression = extract_lua_value_expression(entry_text, match.end())
            try:
                value = LuaParser(expression, constants).parse()
            except Exception:
                continue
            corrections.setdefault(npc_id, {})[field] = value
    return corrections


def merge_corrections(target, source):
    for npc_id, fields in source.items():
        target.setdefault(npc_id, {}).update(fields)


def load_lua_npc_corrections(path, function_names, npc_keys, fields, extra_constants=None):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    corrections = {}
    for function_name in function_names:
        for table_text in extract_function_return_tables(text, function_name):
            merge_corrections(corrections, parse_targeted_correction_table_with_constants(table_text, npc_keys, fields, extra_constants))
    return corrections


def parse_targeted_correction_table_with_constants(table_text, npc_keys, fields, extra_constants=None):
    constants = npc_flag_constants()
    constants.update(extra_constants or {})
    for name in npc_keys:
        constants[f"npcKeys.{name}"] = name

    corrections = {}
    pattern = re.compile(r"\[npcKeys\.([A-Za-z0-9_]+)\]\s*=")
    for npc_id, entry_text in iter_lua_keyed_entries(table_text):
        for match in pattern.finditer(entry_text):
            field = match.group(1)
            if field not in fields:
                continue
            expression = extract_lua_value_expression(entry_text, match.end())
            try:
                value = LuaParser(expression, constants).parse()
            except Exception:
                continue
            corrections.setdefault(npc_id, {})[field] = value
    return corrections


def apply_corrections(npcs, corrections):
    for npc_id, fields in corrections.items():
        npcs.setdefault(npc_id, {}).update(fields)


def load_effective_questie_npcs(repo_root, npc_keys, fields):
    npcs = load_questie_npcs(repo_root / "Database/Wotlk/wotlkNpcDB.lua", npc_keys)
    zone_constants = parse_zone_id_constants(repo_root)
    for relative_path, function_names in NPC_CORRECTION_FILES:
        path = repo_root / relative_path
        if not path.exists():
            continue
        corrections = load_lua_npc_corrections(path, function_names, npc_keys, fields, zone_constants)
        apply_corrections(npcs, corrections)
    return npcs


def int_value(value):
    return int(value or 0)


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


def load_rows_from_sql_file(sql_path, table_name, key_columns, default_columns=None):
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
            skipped_mutations += apply_multirow_insert(statement, table_name, columns, rows, key_columns, sql_context)

    return list(rows.values()), skipped_mutations


def load_filtered_row_table(source_root, table_name, key_columns, row_filter, include_modules=False):
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


def build_acore_npcs(
    source_root,
    include_modules=False,
    repo_root=None,
    creature_sql=None,
    creature_multispawn_sql=None,
    map_difficulty_dbc=None,
    wdm_root=None,
):
    source_root = Path(source_root)
    map_difficulty_dbc = find_map_difficulty_dbc(source_root, map_difficulty_dbc)
    map_difficulty_masks = load_map_difficulty_masks(map_difficulty_dbc)
    template_rows, skipped_creature_template = load_keyed_table(source_root, "creature_template", "entry", include_modules)
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
    faction_template_rows, skipped_faction_template = load_keyed_table(source_root, "factiontemplate_dbc", "ID", include_modules)
    creature_addon_rows, skipped_creature_addon = load_keyed_table(source_root, "creature_addon", "guid", include_modules)
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
        lambda row: (
            int(row.get("source_type") or 0) == SMART_SOURCE_TYPE_CREATURE
            and int(row.get("action_type") or 0) == SMART_ACTION_ESCORT_START
        ),
        include_modules,
    )

    health_by_entry = defaultdict(list)
    spawns_by_entry = defaultdict(lambda: defaultdict(list))
    spawn_zone_counts = defaultdict(lambda: defaultdict(int))
    unmapped_spawn_entries = set()
    seen_spawn_entries = set()
    guid_to_creature = {}
    creatures_by_entry = defaultdict(list)
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
        if guid:
            guid_to_creature[guid] = row
        health = int(row.get("curhealth") or 0)
        if primary_entry and health:
            health_by_entry[primary_entry].append(health)
        if entries:
            zone_id, point = resolve_coordinate_zone(row, zone_maps)
        for entry in entries:
            creatures_by_entry[entry].append(row)
            seen_spawn_entries.add(entry)
            if zone_id and point:
                spawns_by_entry[entry][zone_id].append(
                    add_acore_spawn_visibility(point, row, map_difficulty_masks)
                )
                spawn_zone_counts[entry][zone_id] += 1
            else:
                unmapped_spawn_entries.add(entry)
                map_stats["unmapped_spawns"] += 1

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

    def add_waypoint_path(entries, creature_candidates, path_rows):
        entries = tuple(sorted(set(entries)))
        if not entries or not creature_candidates or not path_rows:
            return False

        seen_waypoint_entries.update(entries)
        for creature in creature_candidates:
            base_zone_id, _ = resolve_coordinate_zone(creature, zone_maps)
            path_points = []
            path_zone_id = base_zone_id
            for point_row in path_rows:
                point_source = dict(creature)
                point_source["position_x"] = point_row.get("position_x")
                point_source["position_y"] = point_row.get("position_y")
                zone_id, point = resolve_coordinate_zone(point_source, zone_maps)
                if not zone_id or not point:
                    path_points = []
                    break
                if path_zone_id is None:
                    path_zone_id = zone_id
                if zone_id != path_zone_id:
                    path_points = []
                    break
                path_points.append(point)

            if path_zone_id and len(path_points) >= 2:
                for entry in entries:
                    waypoints_by_entry[entry][path_zone_id].append(path_points)
                return True

        map_stats["unmapped_waypoints"] += 1
        bad_waypoint_entries.update(entries)
        return False

    for guid, addon in creature_addon_rows.items():
        creature = guid_to_creature.get(int(guid))
        path_id = int(addon.get("path_id") or 0)
        path_rows = waypoint_by_path.get(path_id)
        if not creature or not path_id or not path_rows:
            continue
        entries = get_creature_entries(creature, multispawns_by_guid)
        if not entries:
            continue
        add_waypoint_path(entries, (creature,), path_rows)

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
        add_waypoint_path(entries, creature_candidates, path_rows)

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

        health_values = health_by_entry.get(int(npc_id))
        if health_values:
            npc["minLevelHealth"] = min(health_values)
            npc["maxLevelHealth"] = max(health_values)

        if int(npc_id) in unmapped_spawn_entries:
            pass
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

    skipped_mutations = {
        "creature_template": skipped_creature_template,
        "creature": skipped_creature,
        "creature_multispawn": skipped_creature_multispawn,
        "creature_queststarter": skipped_starter,
        "game_event_creature_quest": skipped_event_starter,
        "creature_questender": skipped_ender,
        "factiontemplate_dbc": skipped_faction_template,
        "creature_addon": skipped_creature_addon,
        "waypoint_data": skipped_waypoint,
        "waypoints": skipped_escort_waypoint,
        "smart_scripts": skipped_smart_scripts,
        **{f"mapping:{key}": value for key, value in map_stats.items()},
    }
    return acore_npcs, skipped_mutations


def sort_coordinate_table(zone_points, map_difficulty_masks=None):
    return {
        int(zone_id): sorted(
            unique_coordinate_points(points, map_difficulty_masks),
            key=lambda point: tuple(point),
        )
        for zone_id, points in sorted(zone_points.items())
    }


def wdm_instance_zone_ids(zone_maps):
    return {
        zone_maps["ui_to_zone"][ui_id]
        for ui_id in zone_maps["wdm_instance_map_data"]
        if ui_id in zone_maps["ui_to_zone"]
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

    for point in points:
        coordinate = (round(float(point[0]), 2), round(float(point[1]), 2))
        if len(point) < 5:
            unrestricted.add(coordinate)
            continue
        restricted[(coordinate[0], coordinate[1], int(point[4]))] |= int(point[3])

    result = []
    for coordinate in unrestricted:
        result.append([coordinate[0], coordinate[1]])

    restricted_coordinates = defaultdict(list)
    for (x, y, map_id), spawn_mask in restricted.items():
        if (x, y) in unrestricted:
            continue
        restricted_coordinates[(x, y)].append((map_id, spawn_mask))

    for (x, y), map_masks in restricted_coordinates.items():
        if len(map_masks) == 1:
            map_id, spawn_mask = map_masks[0]
            if spawn_mask == map_difficulty_masks.get(map_id):
                result.append([x, y])
                continue
        for map_id, spawn_mask in map_masks:
            result.append([x, y, 0, spawn_mask, map_id])

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


def normalize_coordinate_table(value, waypoint=False):
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
                # spawn[3] is Questie's phase ID and is intentionally not
                # compared with AzerothCore data. Generated spawnMask/map
                # metadata lives at indices 4 and 5.
                if len(point) >= 5:
                    normalized_point += (int(point[3]), int(point[4]))
                normalized_points.append(normalized_point)
            zones.append((int(zone_id), tuple(sorted(normalized_points))))
    return tuple(sorted(zones))


def normalize_value(field, value):
    if field in LIST_FIELDS:
        return normalize_list(value)
    if field in NESTED_FIELDS:
        return normalize_coordinate_table(value, waypoint=(field == "waypoints"))
    if field in STRING_FIELDS:
        return value or ""
    return int(value or 0)


def collect_quest_referenced_ids(repo_root, candidate_ids):
    if not candidate_ids:
        return set()

    paths = [
        repo_root / "Database/Wotlk/wotlkQuestDB.lua",
        repo_root / "Database/Corrections/classicQuestFixes.lua",
        repo_root / "Database/Corrections/tbcQuestFixes.lua",
        repo_root / "Database/Corrections/wotlkQuestFixes.lua",
    ]
    texts = []
    for path in paths:
        if path.exists():
            texts.append(strip_lua_comments(path.read_text(encoding="utf-8")))
    quest_text = "\n".join(texts)

    referenced_numbers = {
        int(match.group(0))
        for match in re.finditer(r"(?<!\d)\d+(?!\d)", quest_text)
    }

    referenced_ids = set()
    for candidate_id in candidate_ids:
        if int(candidate_id) in referenced_numbers:
            referenced_ids.add(int(candidate_id))

    item_db_path = repo_root / "Database/Wotlk/wotlkItemDB.lua"
    if item_db_path.exists():
        item_keys = parse_item_keys(item_db_path)
        questie_items = load_effective_questie_items(repo_root, item_keys)
        for item_id in referenced_numbers:
            item = questie_items.get(item_id)
            if not item:
                continue
            for npc_id in normalize_list(item.get("npcDrops")):
                if npc_id in candidate_ids:
                    referenced_ids.add(npc_id)
    return referenced_ids


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
            expected = normalize_value(field, acore_value)
            actual = normalize_value(field, questie.get(field))
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


def write_corrections_module(corrections, output_path, zone_names):
    lines = [
        "---@type QuestieDB",
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")',
        "---@type ZoneDB",
        'local ZoneDB = QuestieLoader:ImportModule("ZoneDB")',
        "",
        "if QuestieCompat.WOW_PROJECT_ID < QuestieCompat.WOW_PROJECT_WRATH_CLASSIC then return end",
        "",
        "-- Generated from tools/generate_acore_npc_corrections.py.",
        "-- Regenerate this file when AzerothCore NPC data changes.",
        "",
        'QuestieCompat.RegisterCorrection("npcData", function()',
        "    local npcKeys = QuestieDB.npcKeys",
        "    local zoneIDs = ZoneDB.zoneIDs",
        "",
        "    return {",
    ]

    for npc_id in sorted(corrections):
        lines.append(f"        [{npc_id}] = {{")
        fields = corrections[npc_id]
        for field in FIELD_ORDER:
            if field in fields:
                lines.append(f"            [npcKeys.{field}] = {format_lua_field_value(field, fields[field], zone_names)},")
        lines.append("        },")
        lines.append("")

    lines.extend([
        "    }",
        "end)",
        "",
    ])
    text = "\n".join(lines)
    validate_lua_fragment(text, str(output_path))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(text, encoding="utf-8")


def write_report(corrections, skipped_mutations, fields, report_path):
    counts = defaultdict(int)
    for correction_fields in corrections.values():
        for field in correction_fields:
            counts[field] += 1

    lines = [
        "# AzerothCore NPC Corrections Report",
        "",
        f"NPCs with corrections: {len(corrections)}",
        "",
        "| Field | Corrections |",
        "| --- | ---: |",
    ]
    for field in FIELD_ORDER:
        if field in fields and counts[field]:
            lines.append(f"| `{field}` | {counts[field]} |")

    skipped = {table: count for table, count in skipped_mutations.items() if count}
    if skipped:
        lines.extend([
            "",
            "Skipped complex SQL mutations:",
            "",
            "| Table | Skipped statements/rows |",
            "| --- | ---: |",
        ])
        for table in sorted(skipped):
            lines.append(f"| `{table}` | {skipped[table]} |")

    omitted = {field: reason for field, reason in SKIPPED_FIELDS.items() if field not in fields}
    if omitted:
        lines.extend([
            "",
            "Fields not generated by default:",
            "",
            "| Questie field | Reason |",
            "| --- | --- |",
        ])
        for field, reason in omitted.items():
            lines.append(f"| `{field}` | {reason} |")

    lines.append("")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Generate Questie npcData corrections from AzerothCore 3.3.5 SQL data.")
    parser.add_argument("--acore-source", default=r"P:\AC\source", type=Path)
    parser.add_argument("--repo-root", default=Path("."), type=Path)
    parser.add_argument("--output", default=Path("Compat/AzerothCoreNPCCorrections.lua"), type=Path)
    parser.add_argument("--report", default=Path("tools/reports/acore_npc_corrections.md"), type=Path)
    parser.add_argument(
        "--wdm-root",
        default=DEFAULT_WDM_ROOT,
        type=Path,
        help="WDM export root containing DungeonMap.csv and DungeonMapChunk.csv.",
    )
    parser.add_argument("--include-modules", action="store_true", help="Also scan SQL under AzerothCore modules/. This can be slow.")
    parser.add_argument("--creature-sql", type=Path, help="Optional final creature table SQL export to use instead of AzerothCore source creature.sql.")
    parser.add_argument(
        "--map-difficulty-dbc",
        type=Path,
        help="MapDifficulty.dbc used by the server. Auto-detected from the AzerothCore build when omitted.",
    )
    parser.add_argument(
        "--creature-multispawn-sql",
        type=Path,
        help="Optional final creature_multispawn SQL export. Auto-detected next to --creature-sql when omitted.",
    )
    parser.add_argument(
        "--fields",
        nargs="+",
        default=DEFAULT_FIELD_ORDER,
        choices=FIELD_ORDER,
        help="Questie NPC fields to compare and generate.",
    )
    parser.add_argument("--include-missing-npcs", action="store_true", help="Generate corrections for NPC IDs missing from Questie.")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    npc_keys = parse_npc_keys(repo_root / "Database/Wotlk/wotlkNpcDB.lua")
    unknown_fields = [field for field in args.fields if field not in npc_keys]
    if unknown_fields:
        raise ValueError(f"Unknown npcKeys fields: {unknown_fields}")

    questie_npcs = load_effective_questie_npcs(repo_root, npc_keys, set(args.fields))
    acore_npcs, skipped_mutations = build_acore_npcs(
        args.acore_source,
        args.include_modules,
        repo_root,
        args.creature_sql,
        args.creature_multispawn_sql,
        args.map_difficulty_dbc,
        args.wdm_root,
    )
    candidate_spawn_ids = {
        npc_id
        for npc_id, npc_fields in questie_npcs.items()
        if normalize_value("spawns", npc_fields.get("spawns")) != ()
        and normalize_value("spawns", acore_npcs.get(npc_id, {}).get("spawns")) == ()
    }
    preserve_spawn_ids = collect_quest_referenced_ids(repo_root, candidate_spawn_ids)
    zone_maps = parse_zone_maps(repo_root, args.wdm_root)
    corrections = find_differences(
        questie_npcs,
        acore_npcs,
        args.fields,
        args.include_missing_npcs,
        preserve_spawn_ids,
        wdm_instance_zone_ids(zone_maps),
    )
    zone_names = parse_zone_id_names(repo_root, zone_maps)

    write_corrections_module(corrections, repo_root / args.output, zone_names)
    write_report(corrections, skipped_mutations, set(args.fields), repo_root / args.report)

    print(f"Wrote {len(corrections)} NPC corrections to {repo_root / args.output}")
    skipped = {table: count for table, count in skipped_mutations.items() if count}
    if skipped:
        print(f"Skipped complex SQL mutations: {skipped}")


if __name__ == "__main__":
    main()
