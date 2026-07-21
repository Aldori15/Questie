import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from generate_acore_item_corrections import (  # noqa: E402
    apply_multirow_delete,
    apply_multirow_update,
    apply_variable_set,
    extract_sql_columns,
    load_keyed_table,
    parse_insert_sql_value,
    source_sql_files,
    split_sql_rows,
    split_sql_statements,
    split_sql_values,
    statement_targets_table,
    strip_sql_comments,
)


ITEM_NAME_RE = re.compile(r'^\[(\d+)\]\s*=\s*\{(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')', re.DOTALL)
OBJECT_LOOT_PRIMARY_CHANCE = 100.0
LOW_CHANCE_CREATURE_DROP_THRESHOLD = 1.0
QUEST_ITEM_COLUMNS = (
    *(f"RequiredItemId{index}" for index in range(1, 7)),
    *(f"ItemDrop{index}" for index in range(1, 5)),
)
LOOT_COLUMN_DEFAULTS = {
    "Reference": 0,
    "Chance": 0,
    "QuestRequired": 0,
    "LootMode": 1,
    "GroupId": 0,
    "MinCount": 1,
    "MaxCount": 1,
    "Comment": None,
}


def normalize_loot_rows(rows):
    return [
        {
            "entry": int(row.get("Entry") or 0),
            "item": int(row.get("Item") or 0),
            "reference": int(row.get("Reference") or 0),
            "chance": float(row.get("Chance") or 0),
            "quest_required": int(row.get("QuestRequired") or 0),
            "loot_mode": int(row.get("LootMode") or 1),
            "group_id": int(row.get("GroupId") or 0),
            "max_count": int(row.get("MaxCount") or 1),
        }
        for row in rows
    ]


def apply_loot_insert(statement, table_name, default_columns, rows, key_columns, sql_context):
    match = re.search(
        rf"(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO)\s+`?{re.escape(table_name)}`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return 1

    columns = default_columns
    if match.group("columns"):
        columns = [column.group(1) for column in re.finditer(r"`([^`]+)`", match.group("columns"))]
        canonical_columns = {column.lower(): column for column in default_columns}
        columns = [canonical_columns.get(column.lower(), column) for column in columns]

    insert_ignore = bool(re.match(r"\s*INSERT\s+IGNORE\b", statement, re.IGNORECASE))
    skipped = 0
    for row_text in split_sql_rows(match.group("values")):
        values = split_sql_values(row_text)
        if len(values) != len(columns):
            skipped += 1
            continue
        row = dict(LOOT_COLUMN_DEFAULTS)
        try:
            for column, raw_value in zip(columns, values):
                row[column] = parse_insert_sql_value(raw_value, sql_context)
        except Exception:
            skipped += 1
            continue
        key = tuple(row.get(column) for column in key_columns)
        if not all(value is not None for value in key):
            skipped += 1
        elif not insert_ignore or key not in rows:
            rows[key] = row
    return skipped


def load_effective_loot_rows(source_root: Path, table_name: str, key_columns, include_modules=False):
    base_file = source_root / "data/sql/base/db_world" / f"{table_name}.sql"
    columns = extract_sql_columns(base_file, table_name)
    rows = {}
    skipped_mutations = 0
    potentially_relevant_skips = 0
    sql_context = {}

    for path in source_sql_files(source_root, table_name, include_modules):
        raw_text = path.read_text(encoding="utf-8")
        if not re.search(rf"\b{re.escape(table_name)}\b|@\w+", raw_text, re.IGNORECASE):
            continue
        text = strip_sql_comments(raw_text)
        for statement in split_sql_statements(text):
            upper = statement.lstrip().upper()
            if re.match(r"\s*SET\b", statement, re.IGNORECASE):
                apply_variable_set(statement, sql_context)
                continue
            if not statement_targets_table(statement, table_name):
                continue
            if upper.startswith(("INSERT", "REPLACE")):
                skipped = apply_loot_insert(statement, table_name, columns, rows, key_columns, sql_context)
                potentially_relevant_skips += skipped
            elif upper.startswith("DELETE"):
                skipped = apply_multirow_delete(statement, table_name, rows, sql_context)
                potentially_relevant_skips += skipped
            elif upper.startswith("UPDATE"):
                skipped = apply_multirow_update(statement, table_name, rows, sql_context)
                potentially_relevant_skips += skipped
            else:
                skipped = 0
            skipped_mutations += skipped

    return normalize_loot_rows(list(rows.values())), {
        "total": skipped_mutations,
        "potentially_relevant": potentially_relevant_skips,
    }


def build_reference_index(rows):
    refs = defaultdict(list)
    for row in rows:
        refs[row["entry"]].append(row)
    return refs


def combine_independent_chances(first, second):
    first = max(0.0, min(100.0, first)) / 100.0
    second = max(0.0, min(100.0, second)) / 100.0
    return (1.0 - ((1.0 - first) * (1.0 - second))) * 100.0


def repeated_chance(chance, count):
    chance = max(0.0, min(100.0, chance)) / 100.0
    return (1.0 - ((1.0 - chance) ** max(1, count))) * 100.0


def loot_modes(rows):
    modes = set()
    for row in rows:
        mask = row["loot_mode"]
        bit = 1
        while mask:
            if mask & bit:
                modes.add(bit)
                mask &= ~bit
            bit <<= 1
    return modes or {1}


def row_result_chances(row, reference_index, loot_mode, seen, quest_required_only, reference_cache):
    item_id = row["item"]
    reference = row["reference"]
    if reference <= 0:
        return {item_id: 100.0} if item_id > 0 else {}

    ref_key = (reference, loot_mode, quest_required_only)
    if ref_key in seen:
        return {}
    if ref_key in reference_cache:
        nested = reference_cache[ref_key]
    else:
        nested = resolve_template_chances(
            reference_index.get(reference, []),
            reference_index,
            loot_mode,
            seen | {ref_key},
            quest_required_only,
            reference_cache,
        )
        reference_cache[ref_key] = nested

    return {
        nested_item_id: repeated_chance(chance, row["max_count"])
        for nested_item_id, chance in nested.items()
    }


def resolve_template_chances(
    rows,
    reference_index,
    loot_mode,
    seen=None,
    quest_required_only=False,
    reference_cache=None,
):
    seen = seen or set()
    reference_cache = reference_cache if reference_cache is not None else {}
    eligible = [
        row for row in rows
        if row["loot_mode"] & loot_mode
        and (not quest_required_only or row["quest_required"] == 1)
    ]
    resolved = defaultdict(float)

    groups = defaultdict(list)
    for row in eligible:
        if row["group_id"] > 0:
            groups[row["group_id"]].append(row)
            continue
        if row["chance"] <= 0:
            continue
        row_chance = min(100.0, row["chance"])
        for item_id, result_chance in row_result_chances(
            row, reference_index, loot_mode, seen, quest_required_only, reference_cache
        ).items():
            effective = row_chance * result_chance / 100.0
            resolved[item_id] = combine_independent_chances(resolved[item_id], effective)

    for group_rows in groups.values():
        remaining = 100.0
        selections = []
        equal_rows = []
        for row in group_rows:
            if row["chance"] > 0:
                selection_chance = min(remaining, row["chance"])
                remaining -= selection_chance
                selections.append((row, selection_chance))
            else:
                equal_rows.append(row)
        if equal_rows and remaining > 0:
            equal_chance = remaining / len(equal_rows)
            selections.extend((row, equal_chance) for row in equal_rows)

        group_results = defaultdict(float)
        for row, selection_chance in selections:
            for item_id, result_chance in row_result_chances(
                row, reference_index, loot_mode, seen, quest_required_only, reference_cache
            ).items():
                group_results[item_id] += selection_chance * result_chance / 100.0
        for item_id, chance in group_results.items():
            resolved[item_id] = combine_independent_chances(resolved[item_id], chance)

    return resolved


def resolve_all_loot_modes(rows, reference_index, quest_required_only=False, reference_cache=None):
    resolved = defaultdict(float)
    reference_cache = reference_cache if reference_cache is not None else {}
    for loot_mode in loot_modes(rows):
        mode_results = resolve_template_chances(
            rows,
            reference_index,
            loot_mode,
            quest_required_only=quest_required_only,
            reference_cache=reference_cache,
        )
        for item_id, chance in mode_results.items():
            resolved[item_id] = max(resolved[item_id], chance)
    return resolved


def load_relevant_quest_item_ids(source_root, include_modules=False):
    quest_rows, skipped = load_keyed_table(source_root, "quest_template", "ID", include_modules)
    relevant = set()
    for row in quest_rows.values():
        for column in QUEST_ITEM_COLUMNS:
            item_id = int(row.get(column) or 0)
            if item_id > 0:
                relevant.add(item_id)
    return relevant, skipped


def build_object_primary_item_ids(gameobject_rows, reference_index):
    object_primary_items = set()
    reference_cache = {}

    grouped = defaultdict(list)
    for row in gameobject_rows:
        grouped[row["entry"]].append(row)

    for rows in grouped.values():
        for item_id, chance in resolve_all_loot_modes(
            rows,
            reference_index,
            quest_required_only=True,
            reference_cache=reference_cache,
        ).items():
            if chance >= OBJECT_LOOT_PRIMARY_CHANCE - 0.0001:
                object_primary_items.add(item_id)

    return object_primary_items


def build_creature_drop_table(creature_rows, reference_index, relevant_item_ids, object_primary_items=None):
    object_primary_items = object_primary_items or set()
    per_item = defaultdict(dict)
    reference_cache = {}
    grouped = defaultdict(list)

    for row in creature_rows:
        grouped[row["entry"]].append(row)

    for npc_id, rows in grouped.items():
        for item_id, chance in resolve_all_loot_modes(
            rows, reference_index, reference_cache=reference_cache
        ).items():
            if item_id not in relevant_item_ids:
                continue
            if (
                item_id in object_primary_items
                and chance <= LOW_CHANCE_CREATURE_DROP_THRESHOLD + 0.0001
            ):
                continue
            if chance > 0:
                per_item[item_id][npc_id] = round(chance, 4)

    return per_item


def unescape_lua_string(value: str):
    return value.replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\")


def load_item_names(item_db_path: Path):
    names = {}
    for raw_line in item_db_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("["):
            continue
        match = ITEM_NAME_RE.match(line)
        if not match:
            continue
        item_id = int(match.group(1))
        raw_name = match.group(2) if match.group(2) is not None else match.group(3)
        names[item_id] = unescape_lua_string(raw_name)
    return names


def write_output(per_item, item_names, output_path: Path):
    lines = [
        "---@class QuestieWotlkAcoreItemDrops",
        'local QuestieWotlkAcoreItemDrops = QuestieLoader:CreateModule("QuestieWotlkAcoreItemDrops")',
        "",
        "-- Generated from effective AzerothCore creature/reference loot for quest-relevant items.",
        "",
        "QuestieWotlkAcoreItemDrops.data = [[return {",
    ]

    for item_id in sorted(per_item):
        item_name = item_names.get(item_id)
        if item_name:
            lines.append(f"    [{item_id}] = {{ -- {item_name}")
        else:
            lines.append(f"    [{item_id}] = {{")
        for npc_id in sorted(per_item[item_id]):
            lines.append(f"        [{npc_id}] = {per_item[item_id][npc_id]},")
        lines.append("    },")

    lines.append("}]]")
    lines.append("")
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_coverage_report(relevant_item_ids, per_item, skipped_stats, output_path):
    generated_pairs = sum(len(npcs) for npcs in per_item.values())
    payload = {
        "relevantQuestItemCount": len(relevant_item_ids),
        "itemsWithCreatureDrops": len(per_item),
        "generatedItemNpcPairs": generated_pairs,
        "itemsWithoutCreatureDrops": sorted(relevant_item_ids - set(per_item)),
        "potentiallyRelevantSkippedSqlMutations": {
            table: count for table, count in skipped_stats.items() if count
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Generate AzerothCore creature quest-item drop rates for Questie.")
    parser.add_argument("--acore-source", default=r"P:\AC\source")
    parser.add_argument("--output", default="Database/DropTables/data/wotlkAcoreItemDrops.lua")
    parser.add_argument("--item-db", default="Database/Wotlk/wotlkItemDB.lua")
    parser.add_argument("--coverage-report", default="tools/reports/acore_creature_drop_coverage.json")
    parser.add_argument("--include-modules", action="store_true", help="Also scan SQL under AzerothCore modules/. This can be slow.")
    args = parser.parse_args()

    source_root = Path(args.acore_source)
    creature_rows, creature_skip_stats = load_effective_loot_rows(
        source_root,
        "creature_loot_template",
        ("Entry", "Item", "Reference", "GroupId"),
        args.include_modules,
    )
    reference_rows, reference_skip_stats = load_effective_loot_rows(
        source_root,
        "reference_loot_template",
        ("Entry", "Item", "Reference", "GroupId"),
        args.include_modules,
    )
    reference_index = build_reference_index(reference_rows)
    relevant_item_ids, quest_template_skips = load_relevant_quest_item_ids(
        source_root, args.include_modules
    )
    gameobject_rows, gameobject_skip_stats = load_effective_loot_rows(
        source_root,
        "gameobject_loot_template",
        ("Entry", "Item", "Reference", "GroupId"),
        args.include_modules,
    )
    object_primary_items = build_object_primary_item_ids(gameobject_rows, reference_index)
    per_item = build_creature_drop_table(
        creature_rows, reference_index, relevant_item_ids, object_primary_items
    )
    item_names = load_item_names(Path(args.item_db))
    write_output(per_item, item_names, Path(args.output))
    print(f"Wrote {len(per_item)} item rows to {args.output}")
    potentially_relevant_skips = {
        "creature_loot_template": creature_skip_stats["potentially_relevant"],
        "reference_loot_template": reference_skip_stats["potentially_relevant"],
        "gameobject_loot_template": gameobject_skip_stats["potentially_relevant"],
        "quest_template": quest_template_skips,
    }
    write_coverage_report(
        relevant_item_ids,
        per_item,
        potentially_relevant_skips,
        Path(args.coverage_report),
    )
    potentially_relevant_skips = {table: count for table, count in potentially_relevant_skips.items() if count}
    if potentially_relevant_skips:
        print(f"Potentially relevant skipped SQL mutations: {potentially_relevant_skips}")


if __name__ == "__main__":
    main()
