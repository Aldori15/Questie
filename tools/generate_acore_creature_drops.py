import argparse
import re
from collections import defaultdict
from pathlib import Path


INSERT_RE = re.compile(
    r"INSERT INTO `(?P<table>creature_loot_template|reference_loot_template)` VALUES\s*(?P<values>.*?);",
    re.IGNORECASE | re.DOTALL,
)
ROW_RE = re.compile(
    r"\((?P<entry>\d+),(?P<item>\d+),(?P<reference>-?\d+),(?P<chance>-?\d+(?:\.\d+)?),(?P<quest_required>\d+),(?P<loot_mode>\d+),(?P<group_id>\d+),(?P<min_count>\d+),(?P<max_count>\d+),'(?:[^'\\]|\\.)*'\)"
)
ITEM_NAME_RE = re.compile(r'^\[(\d+)\]\s*=\s*\{(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')', re.DOTALL)


def load_rows(path: Path, table_name: str):
    rows = []
    text = path.read_text(encoding="utf-8")
    for match in INSERT_RE.finditer(text):
        if match.group("table").lower() != table_name:
            continue
        values = match.group("values")
        for row in ROW_RE.finditer(values):
            rows.append(
                {
                    "entry": int(row.group("entry")),
                    "item": int(row.group("item")),
                    "reference": int(row.group("reference")),
                    "chance": float(row.group("chance")),
                    "quest_required": int(row.group("quest_required")),
                    "group_id": int(row.group("group_id")),
                }
            )
    return rows


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


def build_creature_drop_table(creature_rows, reference_index):
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
        "-- Generated from AzerothCore creature_loot_template/reference_loot_template quest-required rows.",
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
    args = parser.parse_args()

    base = Path(args.acore_source) / "data" / "sql" / "base" / "db_world"
    creature_rows = load_rows(base / "creature_loot_template.sql", "creature_loot_template")
    reference_rows = load_rows(base / "reference_loot_template.sql", "reference_loot_template")
    reference_index = build_reference_index(reference_rows)
    per_item = build_creature_drop_table(creature_rows, reference_index)
    item_names = load_item_names(Path(args.item_db))
    write_output(per_item, item_names, Path(args.output))
    print(f"Wrote {len(per_item)} item rows to {args.output}")


if __name__ == "__main__":
    main()
