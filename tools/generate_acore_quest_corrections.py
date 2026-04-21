import argparse
from pathlib import Path


MANUAL_QUEST_OVERRIDES = {
    13966: {
        "startedBy": "{nil, nil, {46740}}",
    },
}


TABLE_INDENT = "        "
FIELD_INDENT = "            "


def validate_lua_fragment(fragment: str, label: str):
    balance = 0
    in_string = None
    escaped = False

    for line_number, line in enumerate(fragment.splitlines(), start=1):
        index = 0

        if in_string is None and line.lstrip().startswith("--"):
            continue

        while index < len(line):
            char = line[index]

            if in_string is not None:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == in_string:
                    in_string = None
                index += 1
                continue

            if char == "-" and index + 1 < len(line) and line[index + 1] == "-":
                break

            if char in ('"', "'"):
                in_string = char
            elif char == "{":
                balance += 1
            elif char == "}":
                balance -= 1
                if balance < 0:
                    raise ValueError(f"{label} has an unmatched closing brace on line {line_number}.")

            index += 1

    if balance != 0:
        raise ValueError(f"{label} has unbalanced braces ({balance:+d}).")


def append_fragment(lines, fragment: str):
    for line in fragment.rstrip().splitlines():
        lines.append(f"{TABLE_INDENT}{line}" if line else "")


def build_table_block(name: str, suggestions: str, include_manual_overrides: bool):
    lines = [f"    local {name} = {{"]

    append_fragment(lines, suggestions)

    if include_manual_overrides and MANUAL_QUEST_OVERRIDES:
        lines.append("")
        lines.append(f"{TABLE_INDENT}-- Manual AzerothCore quest-start overrides not covered by the relation report.")
        for quest_id in sorted(MANUAL_QUEST_OVERRIDES):
            lines.append(f"{TABLE_INDENT}[{quest_id}] = {{")
            for field_name, value_expr in MANUAL_QUEST_OVERRIDES[quest_id].items():
                lines.append(f"{FIELD_INDENT}[questKeys.{field_name}] = {value_expr},")
            lines.append(f"{TABLE_INDENT}" + "},")

    lines.append("    }")
    lines.append("")
    return lines


def build_module_text(relation_suggestions: str, metadata_suggestions: str) -> str:
    lines = [
        "---@type QuestieDB",
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")',
        "",
        "if QuestieCompat.WOW_PROJECT_ID < QuestieCompat.WOW_PROJECT_WRATH_CLASSIC then return end",
        "",
        "-- Generated from tools/reports/acore_relation_suggestions.lua and tools/reports/acore_metadata_suggestions.lua.",
        "-- Regenerate this file from the validators when AzerothCore quest data changes.",
        "",
        'QuestieCompat.RegisterCorrection("questData", function()',
        "    local questKeys = QuestieDB.questKeys",
        "",
    ]

    lines.append("    -- AzerothCore quest relation parity.")
    lines.extend(build_table_block("relationCorrections", relation_suggestions, include_manual_overrides=True))
    lines.append("    -- AzerothCore quest metadata parity.")
    lines.extend(build_table_block("metadataCorrections", metadata_suggestions, include_manual_overrides=False))
    lines.extend([
        "    return QuestieCompat.Merge(relationCorrections, metadataCorrections, true)",
        "end)",
        "",
    ])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate the Questie AzerothCore quest correction module.")
    parser.add_argument(
        "--relation-input",
        "--input",
        dest="relation_input",
        default=Path("tools/reports/acore_relation_suggestions.lua"),
        type=Path,
        help="Path to the generated relation suggestion Lua fragment.",
    )
    parser.add_argument(
        "--metadata-input",
        default=Path("tools/reports/acore_metadata_suggestions.lua"),
        type=Path,
        help="Path to the generated metadata suggestion Lua fragment.",
    )
    parser.add_argument(
        "--output",
        default=Path("Compat/AzerothCoreCorrections.lua"),
        type=Path,
        help="Path to the addon module to write.",
    )
    args = parser.parse_args()

    relation_suggestions = args.relation_input.read_text(encoding="utf-8")
    metadata_suggestions = args.metadata_input.read_text(encoding="utf-8")

    validate_lua_fragment(relation_suggestions, str(args.relation_input))
    validate_lua_fragment(metadata_suggestions, str(args.metadata_input))

    module_text = build_module_text(relation_suggestions, metadata_suggestions)
    validate_lua_fragment(module_text, str(args.output))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(module_text, encoding="utf-8")
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()