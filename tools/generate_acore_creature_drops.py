import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from generate_acore_item_corrections import (  # noqa: E402
    apply_multirow_delete,
    apply_multirow_insert,
    apply_multirow_update,
    apply_variable_set,
    extract_sql_columns,
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


def normalize_loot_rows(rows):
    return [
        {
            "entry": int(row.get("Entry") or 0),
            "item": int(row.get("Item") or 0),
            "reference": int(row.get("Reference") or 0),
            "chance": float(row.get("Chance") or 0),
            "quest_required": int(row.get("QuestRequired") or 0),
            "group_id": int(row.get("GroupId") or 0),
        }
        for row in rows
    ]


def skipped_insert_may_affect_quest_required_rows(statement, table_name, default_columns, sql_context):
    match = re.search(
        rf"(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO)\s+`?{re.escape(table_name)}`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return True

    columns = default_columns
    if match.group("columns"):
        columns = [column_match.group(1) for column_match in re.finditer(r"`([^`]+)`", match.group("columns"))]
        canonical_columns = {column.lower(): column for column in default_columns}
        columns = [canonical_columns.get(column.lower(), column) for column in columns]

    if "QuestRequired" not in columns:
        return False

    quest_required_index = columns.index("QuestRequired")
    for row_text in split_sql_rows(match.group("values")):
        values = split_sql_values(row_text)
        if quest_required_index >= len(values):
            return True
        try:
            quest_required = int(parse_insert_sql_value(values[quest_required_index], sql_context) or 0)
        except Exception:
            return True
        if quest_required != 0:
            return True

    return False


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
                skipped = apply_multirow_insert(statement, table_name, columns, rows, key_columns, sql_context)
                if skipped and skipped_insert_may_affect_quest_required_rows(statement, table_name, columns, sql_context):
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


def resolve_reference_groups(reference_rows, reference_index, seen=None):
    seen = seen or set()
    resolved = defaultdict(float)

    for row in reference_rows:
        if row["quest_required"] != 1:
            continue
        if row["reference"] > 0:
            ref_key = ("ref", row["reference"])
            if ref_key in seen:
                continue
            nested = resolve_reference_groups(reference_index.get(row["reference"], []), reference_index, seen | {ref_key})
            multiplier = row["chance"] / 100.0 if row["chance"] > 0 else 1.0
            for item_id, chance in nested.items():
                resolved[item_id] += chance * multiplier
        elif row["item"] > 0 and row["chance"] > 0:
            resolved[row["item"]] += row["chance"]

    return resolved


def build_object_primary_item_ids(gameobject_rows, reference_index):
    object_primary_items = set()

    grouped = defaultdict(list)
    for row in gameobject_rows:
        grouped[row["entry"]].append(row)

    for rows in grouped.values():
        for item_id, chance in resolve_reference_groups(rows, reference_index).items():
            if chance >= OBJECT_LOOT_PRIMARY_CHANCE:
                object_primary_items.add(item_id)

    return object_primary_items


def build_creature_drop_table(creature_rows, reference_index, object_primary_items=None):
    object_primary_items = object_primary_items or set()
    per_item = defaultdict(dict)
    grouped = defaultdict(list)

    for row in creature_rows:
        grouped[row["entry"]].append(row)

    for npc_id, rows in grouped.items():
        direct = defaultdict(float)
        references = []

        for row in rows:
            if row["quest_required"] != 1:
                continue
            if row["reference"] > 0:
                references.append(row)
            elif row["item"] > 0 and row["chance"] > 0:
                direct[row["item"]] += row["chance"]

        nested = resolve_reference_groups(references, reference_index, {("npc", npc_id)})
        for item_id, chance in nested.items():
            direct[item_id] += chance

        for item_id, chance in direct.items():
            if item_id in object_primary_items and chance <= LOW_CHANCE_CREATURE_DROP_THRESHOLD:
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
        "-- Generated from effective AzerothCore creature_loot_template/reference_loot_template quest-required rows.",
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


def main():
    parser = argparse.ArgumentParser(description="Generate AzerothCore creature quest-item drop rates for Questie.")
    parser.add_argument("--acore-source", default=r"P:\AC\source")
    parser.add_argument("--output", default="Database/DropTables/data/wotlkAcoreItemDrops.lua")
    parser.add_argument("--item-db", default="Database/Wotlk/wotlkItemDB.lua")
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
        ("Entry", "Item"),
        args.include_modules,
    )
    reference_index = build_reference_index(reference_rows)
    gameobject_rows, gameobject_skip_stats = load_effective_loot_rows(
        source_root,
        "gameobject_loot_template",
        ("Entry", "Item"),
        args.include_modules,
    )
    object_primary_items = build_object_primary_item_ids(gameobject_rows, reference_index)
    per_item = build_creature_drop_table(creature_rows, reference_index, object_primary_items)
    item_names = load_item_names(Path(args.item_db))
    write_output(per_item, item_names, Path(args.output))
    print(f"Wrote {len(per_item)} item rows to {args.output}")
    potentially_relevant_skips = {
        "creature_loot_template": creature_skip_stats["potentially_relevant"],
        "reference_loot_template": reference_skip_stats["potentially_relevant"],
        "gameobject_loot_template": gameobject_skip_stats["potentially_relevant"],
    }
    potentially_relevant_skips = {table: count for table, count in potentially_relevant_skips.items() if count}
    if potentially_relevant_skips:
        print(f"Potentially relevant skipped SQL mutations: {potentially_relevant_skips}")


if __name__ == "__main__":
    main()
