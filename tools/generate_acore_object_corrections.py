import argparse
import ast
import re
import sys
from collections import defaultdict
from pathlib import Path


sys.dont_write_bytecode = True
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from generate_acore_item_corrections import (  # noqa: E402
    add_item_sources_from_loot,
    apply_multirow_insert,
    apply_variable_set,
    build_gameobject_loot_source_map,
    extract_function_return_tables,
    extract_lua_long_return_table,
    load_effective_questie_items,
    load_keyed_table,
    load_row_table,
    parse_item_keys,
    split_sql_statements,
    statement_targets_table,
    strip_lua_comments,
    strip_sql_comments,
    validate_lua_fragment,
)
from generate_acore_npc_corrections import (  # noqa: E402
    LuaParser,
    add_acore_spawn_visibility,
    extract_balanced_braces,
    find_map_difficulty_dbc,
    format_zone_ref,
    load_map_difficulty_masks,
    load_rows_from_sql_file,
    merge_entrance_spawn_placeholders,
    parse_zone_id_constants,
    parse_zone_id_names,
    parse_zone_maps,
    resolve_coordinate_zone,
    sort_coordinate_table,
    wdm_instance_zone_ids,
)


OBJECT_CORRECTION_FILES = [
    ("Database/Corrections/classicObjectFixes.lua", ("QuestieObjectFixes:Load",)),
    ("Database/Corrections/tbcObjectFixes.lua", ("QuestieTBCObjectFixes:Load",)),
    (
        "Database/Corrections/wotlkObjectFixes.lua",
        (
            "QuestieWotlkObjectFixes:Load",
            "QuestieWotlkObjectFixes:LoadReverseLinkFixes",
        ),
    ),
]

LIST_FIELDS = {"questStarts", "questEnds"}
NESTED_FIELDS = {"spawns"}
STRING_FIELDS = {"name"}
SCALAR_FIELDS = {"zoneID", "factionID"}

FIELD_ORDER = [
    "name",
    "questStarts",
    "questEnds",
    "spawns",
    "zoneID",
    "factionID",
]

QUEST_REQUIRED_ITEM_COLUMNS = tuple(f"RequiredItemId{index}" for index in range(1, 7))


def parse_object_keys(object_db_path):
    text = object_db_path.read_text(encoding="utf-8")
    key_block = extract_balanced_braces(text, text.find("{", text.find("QuestieDB.objectKeys")))
    return {name: int(value) for name, value in re.findall(r"\['([^']+)'\]\s*=\s*(\d+)", key_block)}


def load_questie_objects(object_db_path, object_keys):
    text = object_db_path.read_text(encoding="utf-8")
    table_text = extract_lua_long_return_table(text, "QuestieDB.objectData")
    parsed = LuaParser(table_text).parse()
    reverse_keys = {index: name for name, index in object_keys.items()}
    objects = {}
    for object_id, values in parsed.items():
        row = {}
        for index, value in enumerate(values, start=1):
            if value is not None and index in reverse_keys:
                row[reverse_keys[index]] = value
        objects[int(object_id)] = row
    return objects


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


def parse_targeted_correction_table(table_text, object_keys, fields, extra_constants=None):
    constants = dict(extra_constants or {})
    for name in object_keys:
        constants[f"objectKeys.{name}"] = name

    corrections = {}
    pattern = re.compile(r"\[objectKeys\.([A-Za-z0-9_]+)\]\s*=")
    for object_id, entry_text in iter_lua_keyed_entries(table_text):
        for match in pattern.finditer(entry_text):
            field = match.group(1)
            if field not in fields:
                continue
            expression = extract_lua_value_expression(entry_text, match.end())
            try:
                value = LuaParser(expression, constants).parse()
            except Exception:
                continue
            corrections.setdefault(object_id, {})[field] = value
    return corrections


def merge_corrections(target, source):
    for object_id, fields in source.items():
        target.setdefault(object_id, {}).update(fields)


def load_lua_object_corrections(path, function_names, object_keys, fields, extra_constants=None):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    corrections = {}
    for function_name in function_names:
        for table_text in extract_function_return_tables(text, function_name):
            merge_corrections(corrections, parse_targeted_correction_table(table_text, object_keys, fields, extra_constants))
    return corrections


def apply_corrections(objects, corrections):
    for object_id, fields in corrections.items():
        objects.setdefault(object_id, {}).update(fields)


def load_effective_questie_objects(repo_root, object_keys, fields):
    objects = load_questie_objects(repo_root / "Database/Wotlk/wotlkObjectDB.lua", object_keys)
    zone_constants = parse_zone_id_constants(repo_root)
    for relative_path, function_names in OBJECT_CORRECTION_FILES:
        path = repo_root / relative_path
        if not path.exists():
            continue
        corrections = load_lua_object_corrections(path, function_names, object_keys, fields, zone_constants)
        apply_corrections(objects, corrections)
    return objects


def load_rows_from_optional_sql_file(source_root, table_name, key_columns, include_modules=False, sql_path=None):
    if sql_path:
        return load_rows_from_sql_file(Path(sql_path), table_name, key_columns)
    return load_row_table(source_root, table_name, key_columns, include_modules)


def collect_item_object_source_ids(source_root, gameobject_template_rows, include_modules=False):
    reference_rows, skipped_reference = load_row_table(source_root, "reference_loot_template", ("Entry", "Item"), include_modules)
    gameobject_loot_rows, skipped_gameobject_loot = load_row_table(source_root, "gameobject_loot_template", ("Entry", "Item"), include_modules)

    reference_index = defaultdict(list)
    for row in reference_rows:
        reference_index[int(row["Entry"])].append(row)

    object_sources_by_item = add_item_sources_from_loot(
        gameobject_loot_rows,
        reference_index,
        build_gameobject_loot_source_map(gameobject_template_rows),
    )

    source_ids = set()
    for item_source_ids in object_sources_by_item.values():
        source_ids.update(item_source_ids)

    skipped_mutations = {
        "reference_loot_template:item_object_sources": skipped_reference,
        "gameobject_loot_template:item_object_sources": skipped_gameobject_loot,
    }
    return source_ids, skipped_mutations


def build_acore_objects(
    source_root,
    include_modules=False,
    repo_root=None,
    gameobject_sql=None,
    map_difficulty_dbc=None,
    wdm_root=None,
):
    source_root = Path(source_root)
    map_difficulty_dbc = find_map_difficulty_dbc(source_root, map_difficulty_dbc)
    map_difficulty_masks = load_map_difficulty_masks(map_difficulty_dbc)
    template_rows, skipped_template = load_keyed_table(source_root, "gameobject_template", "entry", include_modules)
    template_addon_rows, skipped_template_addon = load_keyed_table(source_root, "gameobject_template_addon", "entry", include_modules)
    gameobject_rows, skipped_gameobject = load_rows_from_optional_sql_file(
        source_root,
        "gameobject",
        ("guid",),
        include_modules,
        gameobject_sql,
    )
    starter_rows, skipped_starter = load_row_table(source_root, "gameobject_queststarter", ("id", "quest"), include_modules)
    event_starter_rows, skipped_event_starter = load_row_table(
        source_root,
        "game_event_gameobject_quest",
        ("eventEntry", "id", "quest"),
        include_modules,
    )
    ender_rows, skipped_ender = load_row_table(source_root, "gameobject_questender", ("id", "quest"), include_modules)
    item_object_source_ids, skipped_item_object_sources = collect_item_object_source_ids(
        source_root,
        template_rows,
        include_modules,
    )

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

    spawns_by_entry = defaultdict(lambda: defaultdict(list))
    spawn_zone_counts = defaultdict(lambda: defaultdict(int))
    seen_spawn_entries = set()
    unmapped_spawn_entries = set()
    map_stats = defaultdict(int)
    zone_maps = parse_zone_maps(Path(repo_root or ".").resolve(), wdm_root)

    for row in gameobject_rows:
        entry = int(row.get("id") or row.get("entry") or 0)
        if not entry:
            continue
        seen_spawn_entries.add(entry)
        zone_id, point = resolve_coordinate_zone(row, zone_maps)
        if zone_id and point:
            spawns_by_entry[entry][zone_id].append(
                add_acore_spawn_visibility(point, row, map_difficulty_masks)
            )
            spawn_zone_counts[entry][zone_id] += 1
        else:
            unmapped_spawn_entries.add(entry)
            map_stats["unmapped_spawns"] += 1

    acore_objects = {}
    for object_id, row in template_rows.items():
        object_id = int(object_id)
        obj = {"name": row.get("name") or ""}

        if object_id in unmapped_spawn_entries:
            pass
        elif spawns_by_entry.get(object_id):
            obj["spawns"] = sort_coordinate_table(
                spawns_by_entry[object_id],
                map_difficulty_masks,
            )
            obj["zoneID"] = max(spawn_zone_counts[object_id].items(), key=lambda item: (item[1], -item[0]))[0]
        elif object_id not in seen_spawn_entries:
            obj["spawns"] = {}
            obj["zoneID"] = 0

        obj["questStarts"] = sorted(starts_by_entry.get(object_id, set()))
        obj["questEnds"] = sorted(ends_by_entry.get(object_id, set()))

        addon = template_addon_rows.get(object_id)
        obj["factionID"] = int((addon or {}).get("faction") or 0)

        acore_objects[object_id] = obj

    skipped_mutations = {
        "gameobject_template": skipped_template,
        "gameobject_template_addon": skipped_template_addon,
        "gameobject": skipped_gameobject,
        "gameobject_queststarter": skipped_starter,
        "game_event_gameobject_quest": skipped_event_starter,
        "gameobject_questender": skipped_ender,
        **skipped_item_object_sources,
        **{f"mapping:{key}": value for key, value in map_stats.items()},
    }
    return acore_objects, skipped_mutations, item_object_source_ids


def normalize_list(value):
    if not value:
        return ()
    if isinstance(value, dict):
        value = value.values()
    return tuple(sorted({int(v) for v in value if v is not None}))


def normalize_coordinate_table(value):
    if not value or not isinstance(value, dict):
        return ()
    zones = []
    for zone_id, points in value.items():
        if not points:
            zones.append((int(zone_id), ()))
            continue
        zones.append(
            (
                int(zone_id),
                tuple(
                    sorted(
                        (
                            round(float(point[0]), 2),
                            round(float(point[1]), 2),
                            *((int(point[3]), int(point[4])) if len(point) >= 5 else ()),
                        )
                        for point in points
                        if isinstance(point, list) and len(point) >= 2
                    )
                ),
            )
        )
    return tuple(sorted(zones))


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

    referenced_ids = set()
    for candidate_id in candidate_ids:
        if re.search(rf"(?<!\d){int(candidate_id)}(?!\d)", quest_text):
            referenced_ids.add(int(candidate_id))
    return referenced_ids


def collect_acore_required_quest_item_ids(source_root, include_modules=False):
    quest_rows, skipped_mutations = load_keyed_table(
        source_root,
        "quest_template",
        "ID",
        include_modules,
    )
    item_ids = {
        int(row.get(column) or 0)
        for row in quest_rows.values()
        for column in QUEST_REQUIRED_ITEM_COLUMNS
        if int(row.get(column) or 0) > 0
    }
    return item_ids, skipped_mutations


def collect_indirect_quest_item_object_source_ids(
    questie_items,
    required_quest_item_ids,
    candidate_ids,
):
    candidate_ids = set(candidate_ids)
    source_ids = set()
    for item_id in required_quest_item_ids:
        for object_id in normalize_list(questie_items.get(item_id, {}).get("objectDrops")):
            if object_id in candidate_ids:
                source_ids.add(object_id)
    return source_ids


def normalize_value(field, value):
    if field in LIST_FIELDS:
        return normalize_list(value)
    if field in NESTED_FIELDS:
        return normalize_coordinate_table(value)
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
    questie_objects,
    acore_objects,
    fields,
    include_missing_objects=False,
    preserve_spawn_ids=None,
    force_include_ids=None,
    entrance_marker_zone_ids=None,
):
    corrections = {}
    preserve_spawn_ids = preserve_spawn_ids or set()
    ids = set(questie_objects) | set(force_include_ids or ())
    if include_missing_objects:
        ids |= set(acore_objects)

    for object_id in sorted(ids):
        acore = acore_objects.get(object_id)
        if not acore:
            continue
        questie = questie_objects.get(object_id, {})
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
                object_id in preserve_spawn_ids
                and field in {"spawns", "zoneID"}
                and field in acore
                and normalize_value("spawns", acore.get("spawns")) == ()
                and normalize_value("spawns", questie.get("spawns")) != ()
            ):
                continue
            if expected != actual:
                corrections.setdefault(object_id, {})[field] = correction_value(field, acore_value)
    return corrections


def add_missing_object_identity_corrections(corrections, questie_objects, acore_objects, object_source_ids):
    for object_id in sorted(object_source_ids):
        if object_id in questie_objects:
            continue

        acore = acore_objects.get(object_id)
        if not acore or not acore.get("name"):
            continue

        corrections.setdefault(object_id, {})["name"] = acore["name"]


def lua_quote(value):
    return ast.literal_eval(repr(value)).replace("\\", "\\\\").replace('"', '\\"')


def format_lua_number(value):
    if isinstance(value, int) or float(value).is_integer():
        return str(int(value))
    return f"{float(value):.2f}".rstrip("0").rstrip(".")


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
        "-- Generated from tools/generate_acore_object_corrections.py.",
        "-- Regenerate this file when AzerothCore object data changes.",
        "",
        'QuestieCompat.RegisterCorrection("objectData", function()',
        "    local objectKeys = QuestieDB.objectKeys",
        "    local zoneIDs = ZoneDB.zoneIDs",
        "",
        "    return {",
    ]

    for object_id in sorted(corrections):
        lines.append(f"        [{object_id}] = {{")
        correction_fields = corrections[object_id]
        for field in FIELD_ORDER:
            if field in correction_fields:
                lines.append(f"            [objectKeys.{field}] = {format_lua_field_value(field, correction_fields[field], zone_names)},")
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
        "# AzerothCore Object Corrections Report",
        "",
        f"Objects with corrections: {len(corrections)}",
        "",
        "| Field | Corrections |",
        "| --- | ---: |",
    ]
    for field in FIELD_ORDER:
        if field in fields and counts[field]:
            lines.append(f"| `{field}` | {counts[field]} |")

    skipped = {table: count for table, count in skipped_mutations.items() if count and not table.startswith("mapping:")}
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

    mapping = {table.removeprefix("mapping:"): count for table, count in skipped_mutations.items() if count and table.startswith("mapping:")}
    if mapping:
        lines.extend([
            "",
            "Unmapped coordinate rows:",
            "",
            "| Mapping issue | Rows |",
            "| --- | ---: |",
        ])
        for issue in sorted(mapping):
            lines.append(f"| `{issue}` | {mapping[issue]} |")

    lines.append("")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Generate Questie objectData corrections from AzerothCore 3.3.5 SQL data.")
    parser.add_argument("--acore-source", default=r"P:\AC\source", type=Path)
    parser.add_argument("--repo-root", default=Path("."), type=Path)
    parser.add_argument("--output", default=Path("Compat/AzerothCoreObjectCorrections.lua"), type=Path)
    parser.add_argument("--report", default=Path("tools/reports/acore_object_corrections.md"), type=Path)
    parser.add_argument(
        "--wdm-root",
        default=Path(r"E:\downloads\WDM stuff"),
        type=Path,
        help="WDM export root containing DungeonMap.csv and DungeonMapChunk.csv.",
    )
    parser.add_argument("--include-modules", action="store_true", help="Also scan SQL under AzerothCore modules/. This can be slow.")
    parser.add_argument("--gameobject-sql", type=Path, help="Optional final gameobject table SQL export to use instead of AzerothCore source gameobject.sql.")
    parser.add_argument(
        "--map-difficulty-dbc",
        type=Path,
        help="MapDifficulty.dbc used by the server. Auto-detected from the AzerothCore build when omitted.",
    )
    parser.add_argument(
        "--fields",
        nargs="+",
        default=FIELD_ORDER,
        choices=FIELD_ORDER,
        help="Questie object fields to compare and generate.",
    )
    parser.add_argument("--include-missing-objects", action="store_true", help="Generate corrections for object IDs missing from Questie.")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    object_keys = parse_object_keys(repo_root / "Database/Wotlk/wotlkObjectDB.lua")
    item_keys = parse_item_keys(repo_root / "Database/Wotlk/wotlkItemDB.lua")
    unknown_fields = [field for field in args.fields if field not in object_keys]
    if unknown_fields:
        raise ValueError(f"Unknown objectKeys fields: {unknown_fields}")

    questie_objects = load_effective_questie_objects(repo_root, object_keys, set(args.fields))
    questie_items = load_effective_questie_items(repo_root, item_keys)
    acore_objects, skipped_mutations, item_object_source_ids = build_acore_objects(
        args.acore_source,
        args.include_modules,
        repo_root,
        args.gameobject_sql,
        args.map_difficulty_dbc,
        args.wdm_root,
    )
    required_quest_item_ids, skipped_quest_template = collect_acore_required_quest_item_ids(
        args.acore_source,
        args.include_modules,
    )
    skipped_mutations["quest_template:required_item_object_sources"] = skipped_quest_template
    candidate_spawn_ids = {
        object_id
        for object_id, object_fields in questie_objects.items()
        if object_id in acore_objects
        if normalize_value("spawns", object_fields.get("spawns")) != ()
        and normalize_value("spawns", acore_objects.get(object_id, {}).get("spawns")) == ()
    }
    preserve_spawn_ids = collect_quest_referenced_ids(repo_root, candidate_spawn_ids)
    preserve_spawn_ids.update(
        collect_indirect_quest_item_object_source_ids(
            questie_items,
            required_quest_item_ids,
            candidate_spawn_ids,
        )
    )
    zone_maps = parse_zone_maps(repo_root, args.wdm_root)
    corrections = find_differences(
        questie_objects,
        acore_objects,
        args.fields,
        args.include_missing_objects,
        preserve_spawn_ids,
        None,
        wdm_instance_zone_ids(zone_maps),
    )
    add_missing_object_identity_corrections(corrections, questie_objects, acore_objects, item_object_source_ids)
    zone_names = parse_zone_id_names(repo_root, zone_maps)

    write_corrections_module(corrections, repo_root / args.output, zone_names)
    write_report(corrections, skipped_mutations, set(args.fields), repo_root / args.report)

    print(f"Wrote {len(corrections)} object corrections to {repo_root / args.output}")
    skipped = {table: count for table, count in skipped_mutations.items() if count and not table.startswith("mapping:")}
    if skipped:
        print(f"Skipped complex SQL mutations: {skipped}")
    mapping = {table: count for table, count in skipped_mutations.items() if count and table.startswith("mapping:")}
    if mapping:
        print(f"Unmapped coordinate rows: {mapping}")


if __name__ == "__main__":
    main()
