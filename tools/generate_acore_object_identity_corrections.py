import argparse
import re
from pathlib import Path


STOCK_OBJECT_FILES = [
    "Database/Wotlk/wotlkObjectDB.lua",
    "Database/Corrections/classicObjectFixes.lua",
    "Database/Corrections/tbcObjectFixes.lua",
    "Database/Corrections/wotlkObjectFixes.lua",
]


def read_text(path):
    return path.read_text(encoding="utf-8", errors="ignore")


def lua_quote(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


def parse_lua_object_ids(path):
    if not path.exists():
        return set()

    text = read_text(path)
    return {int(match.group(1)) for match in re.finditer(r"^\s*\[(\d+)\]\s*=", text, re.M)}


def parse_item_object_drops(path):
    text = read_text(path)
    object_ids = set()
    for match in re.finditer(r"\[itemKeys\.objectDrops\]\s*=\s*\{([^}]*)\}", text):
        object_ids.update(int(value) for value in re.findall(r"\d+", match.group(1)))
    return object_ids


def parse_sql_string(value):
    return value.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")


def load_gameobject_template_names(source_root):
    names = {}
    for path in sorted(Path(source_root).rglob("*.sql")):
        text = read_text(path)
        if "gameobject_template" not in text:
            continue

        for statement in text.split(";"):
            if re.search(r"\b(?:INSERT|REPLACE)\s+INTO\s+`?gameobject_template`?", statement, re.I):
                for match in re.finditer(
                    r"\((\d+)\s*,\s*\d+\s*,\s*\d+\s*,\s*'((?:\\'|[^'])*)'",
                    statement,
                ):
                    names[int(match.group(1))] = parse_sql_string(match.group(2))
            elif re.search(r"\bUPDATE\s+`?gameobject_template`?", statement, re.I):
                match = re.search(
                    r"SET\s+`?name`?\s*=\s*'((?:\\'|[^'])*)'.*?WHERE\s+`?entry`?\s*=\s*(\d+)",
                    statement,
                    re.I | re.S,
                )
                if match:
                    names[int(match.group(2))] = parse_sql_string(match.group(1))

    return names


def write_lua(output_path, object_names):
    lines = [
        "---@type QuestieDB",
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")',
        "",
        "if QuestieCompat.WOW_PROJECT_ID < QuestieCompat.WOW_PROJECT_WRATH_CLASSIC then return end",
        "",
        "-- Generated from tools/generate_acore_object_identity_corrections.py.",
        "-- Regenerate this file after regenerating AzerothCore item/object corrections.",
        "",
        'QuestieCompat.RegisterCorrection("objectData", function()',
        "    local objectKeys = QuestieDB.objectKeys",
        "",
        "    return {",
    ]

    for object_id in sorted(object_names):
        lines.extend([
            f"        [{object_id}] = {{",
            f'            [objectKeys.name] = "{lua_quote(object_names[object_id])}",',
            "        },",
            "",
        ])

    lines.extend([
        "    }",
        "end)",
        "",
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(
        description="Generate name-only objectData corrections for AC objectDrops missing from stock Questie data."
    )
    parser.add_argument("--acore-source", default=r"P:\AC\source", type=Path)
    parser.add_argument("--repo-root", default=Path("."), type=Path)
    parser.add_argument("--item-corrections", default=Path("Database/AzerothCore/AzerothCoreItemCorrections.lua"), type=Path)
    parser.add_argument("--output", default=Path("Database/AzerothCore/AzerothCoreObjectIdentityCorrections.lua"), type=Path)
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    stock_object_ids = set()
    for relative_path in STOCK_OBJECT_FILES:
        stock_object_ids.update(parse_lua_object_ids(repo_root / relative_path))

    object_drop_ids = parse_item_object_drops(repo_root / args.item_corrections)
    missing_ids = sorted(object_drop_ids - stock_object_ids)
    template_names = load_gameobject_template_names(args.acore_source)
    object_names = {object_id: template_names[object_id] for object_id in missing_ids if object_id in template_names}
    missing_names = [object_id for object_id in missing_ids if object_id not in template_names]

    write_lua(repo_root / args.output, object_names)

    print(f"Wrote {len(object_names)} object identity corrections to {repo_root / args.output}")
    if missing_names:
        print("Missing gameobject_template names: " + ", ".join(str(object_id) for object_id in missing_names))


if __name__ == "__main__":
    main()
