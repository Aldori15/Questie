import argparse
import json
import re
from pathlib import Path


QUEST_ENTRY_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\})$", re.DOTALL)
QUEST_FIELD_RE = re.compile(r"^\[(questKeys\.startedBy)\]\s*=\s*(.+)$", re.DOTALL)
ITEM_ENTRY_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\})$", re.DOTALL)
ITEM_FIELD_RE = re.compile(r"^\[(itemKeys\.startQuest)\]\s*=\s*(.+)$", re.DOTALL)


class LuaTableParser:
    def __init__(self, text: str):
        self.text = text
        self.length = len(text)
        self.index = 0

    def parse(self):
        value = self._parse_value()
        self._skip_ws()
        return value

    def _skip_ws(self):
        while self.index < self.length and self.text[self.index] in " \t\r\n":
            self.index += 1

    def _peek(self):
        return self.text[self.index] if self.index < self.length else ""

    def _parse_value(self):
        self._skip_ws()
        char = self._peek()
        if char == "{":
            return self._parse_table()
        if char == '"':
            return self._parse_string('"')
        if char == "'":
            return self._parse_string("'")
        if char == "-" or char.isdigit():
            return self._parse_number()
        if self.text.startswith("nil", self.index):
            self.index += 3
            return None
        if self.text.startswith("true", self.index):
            self.index += 4
            return True
        if self.text.startswith("false", self.index):
            self.index += 5
            return False
        raise ValueError(f"Unsupported Lua token near: {self.text[self.index:self.index + 32]!r}")

    def _parse_table(self):
        assert self._peek() == "{"
        self.index += 1
        items = []

        while True:
            self._skip_ws()
            if self._peek() == "}":
                self.index += 1
                return items

            items.append(self._parse_value())
            self._skip_ws()

            char = self._peek()
            if char == ",":
                self.index += 1
                continue
            if char == "}":
                self.index += 1
                return items
            raise ValueError(f"Unexpected character in Lua table: {char!r}")

    def _parse_string(self, delimiter):
        assert self._peek() == delimiter
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
                escape_map = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "'": "'", "\\": "\\"}
                chars.append(escape_map.get(escaped, escaped))
                continue
            if char == delimiter:
                return "".join(chars)
            chars.append(char)

        raise ValueError("Unterminated Lua string")

    def _parse_number(self):
        start = self.index
        if self._peek() == "-":
            self.index += 1
        while self.index < self.length and self.text[self.index].isdigit():
            self.index += 1
        return int(self.text[start:self.index])


def split_top_level_lua_table(lua_table: str):
    text = lua_table.strip()
    if not text.startswith("{") or not text.endswith("}"):
        raise ValueError("Expected a Lua table literal")

    items = []
    depth = 0
    start = 1
    index = 1
    in_string = False
    string_char = ""
    escaped = False

    while index < len(text) - 1:
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == string_char:
                in_string = False
            index += 1
            continue

        if char in {'"', "'"}:
            in_string = True
            string_char = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        elif char == "," and depth == 0:
            items.append(text[start:index].strip())
            start = index + 1
        index += 1

    tail = text[start:-1].strip()
    if tail:
        items.append(tail)
    return items


def strip_lua_comments(text: str):
    result = []
    index = 0
    in_string = False
    string_char = ""
    escaped = False

    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""

        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == string_char:
                in_string = False
            index += 1
            continue

        if char in {'"', "'"}:
            in_string = True
            string_char = char
            result.append(char)
            index += 1
            continue

        if char == "-" and nxt == "-":
            index += 2
            while index < len(text) and text[index] != "\n":
                index += 1
            continue

        result.append(char)
        index += 1

    return "".join(result)


def extract_table_after(start_index: int, lua_file_text: str):
    index = start_index
    while index < len(lua_file_text) and lua_file_text[index] != "{":
        index += 1
    if index >= len(lua_file_text):
        raise ValueError("Could not find opening table brace")

    start = index
    depth = 0
    in_string = False
    string_char = ""
    escaped = False

    while index < len(lua_file_text):
        char = lua_file_text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == string_char:
                in_string = False
            index += 1
            continue

        if char in {'"', "'"}:
            in_string = True
            string_char = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return lua_file_text[start:index + 1]
        index += 1

    raise ValueError("Could not extract table block")


def extract_named_tables(lua_file_text: str, markers):
    tables = []
    for marker in markers:
        index = 0
        while True:
            found = lua_file_text.find(marker, index)
            if found == -1:
                break
            start_index = found + len(marker) - 1 if marker.rstrip().endswith("{") else found + len(marker)
            tables.append(extract_table_after(start_index, lua_file_text))
            index = found + len(marker)
    return tables


def extract_item_starts(value):
    if not isinstance(value, list) or len(value) < 3 or not isinstance(value[2], list):
        return set()
    return {int(entry) for entry in value[2] if isinstance(entry, int)}


def load_quest_item_starts(quest_db_path: Path):
    per_quest = {}

    for raw_line in quest_db_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("["):
            continue
        match = re.match(r"\[(\d+)\]\s*=\s*(\{.*\}),?$", line)
        if not match:
            continue

        quest_id = int(match.group(1))
        fields = split_top_level_lua_table(match.group(2))
        if len(fields) < 2:
            continue

        per_quest[quest_id] = extract_item_starts(None if fields[1] == "nil" else LuaTableParser(fields[1]).parse())

    return per_quest


def load_quest_start_overrides(fix_file_path: Path):
    text = strip_lua_comments(fix_file_path.read_text(encoding="utf-8"))
    overrides = {}

    for table_text in extract_named_tables(text, ["return {"]):
        for entry in split_top_level_lua_table(table_text):
            match = QUEST_ENTRY_RE.match(entry.strip())
            if not match:
                continue

            quest_id = int(match.group(1))
            body = match.group(2)
            for field in split_top_level_lua_table(body):
                field_match = QUEST_FIELD_RE.match(field.strip())
                if not field_match:
                    continue
                field_value = field_match.group(2).strip()
                overrides[quest_id] = extract_item_starts(None if field_value == "nil" else LuaTableParser(field_value).parse())

    return overrides


def apply_quest_overrides(quest_item_starts, overrides):
    for quest_id, item_ids in overrides.items():
        quest_item_starts[quest_id] = set(item_ids)


def load_base_item_starts(item_db_path: Path):
    result = {}
    for raw_line in item_db_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("["):
            continue
        match = re.match(r"\[(\d+)\]\s*=\s*(\{.*\}),?$", line)
        if not match:
            continue

        item_id = int(match.group(1))
        fields = split_top_level_lua_table(match.group(2))
        if len(fields) < 5:
            continue
        result[item_id] = None if fields[4] == "nil" else int(fields[4])
    return result


def load_item_start_overrides(fix_file_path: Path):
    text = strip_lua_comments(fix_file_path.read_text(encoding="utf-8"))
    overrides = {}
    markers = ["return {", "local itemFixesHorde = ", "local itemFixesAlliance = "]

    for table_text in extract_named_tables(text, markers):
        for entry in split_top_level_lua_table(table_text):
            match = ITEM_ENTRY_RE.match(entry.strip())
            if not match:
                continue
            item_id = int(match.group(1))
            body = match.group(2)
            for field in split_top_level_lua_table(body):
                field_match = ITEM_FIELD_RE.match(field.strip())
                if not field_match:
                    continue
                raw_value = field_match.group(2).strip()
                overrides[item_id] = None if raw_value == "nil" else int(raw_value)

    return overrides


def apply_item_overrides(item_starts, overrides):
    for item_id, quest_id in overrides.items():
        item_starts[item_id] = quest_id


def compare_item_starts(quest_item_starts, item_starts):
    mismatches = []
    targets = {}

    for quest_id, item_ids in sorted(quest_item_starts.items()):
        for item_id in sorted(item_ids):
            current = item_starts.get(item_id)
            if current != quest_id:
                mismatches.append(
                    {
                        "itemId": item_id,
                        "expectedQuest": quest_id,
                        "currentQuest": current,
                    }
                )
                targets[item_id] = quest_id

    return mismatches, targets


def build_lua_suggestions(targets):
    lines = [
        "-- REVIEW BEFORE APPLYING.",
        "-- Generated from Questie quest-side startedBy item relations.",
        "-- This only backfills or corrects itemKeys.startQuest.",
        "",
    ]

    for item_id in sorted(targets):
        lines.append(f"[{item_id}] = {{")
        lines.append(f"    [itemKeys.startQuest] = {targets[item_id]},")
        lines.append("},")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main():
    parser = argparse.ArgumentParser(description="Validate item startQuest links against effective Questie quest startedBy item data.")
    parser.add_argument("--quest-db", default="Database/Wotlk/wotlkQuestDB.lua")
    parser.add_argument("--item-db", default="Database/Wotlk/wotlkItemDB.lua")
    parser.add_argument(
        "--quest-fixes",
        nargs="*",
        default=[
            "Database/Corrections/classicQuestFixes.lua",
            "Database/Corrections/tbcQuestFixes.lua",
            "Database/Corrections/wotlkQuestFixes.lua",
        ],
    )
    parser.add_argument(
        "--item-fixes",
        nargs="*",
        default=[
            "Database/Corrections/classicItemFixes.lua",
            "Database/Corrections/tbcItemFixes.lua",
            "Database/Corrections/wotlkItemFixes.lua",
            "Database/Corrections/Automatic/itemStartFixes.lua",
        ],
    )
    parser.add_argument("--report", help="Optional path to write the full JSON report")
    parser.add_argument("--suggest-lua", help="Optional path to write candidate Lua item fixes")
    args = parser.parse_args()

    quest_item_starts = load_quest_item_starts(Path(args.quest_db))
    for fix_file in args.quest_fixes:
        apply_quest_overrides(quest_item_starts, load_quest_start_overrides(Path(fix_file)))

    item_starts = load_base_item_starts(Path(args.item_db))
    for fix_file in args.item_fixes:
        apply_item_overrides(item_starts, load_item_start_overrides(Path(fix_file)))

    mismatches, targets = compare_item_starts(quest_item_starts, item_starts)
    summary = {
        "totalMismatches": len(mismatches),
        "itemsNeedingFixes": len(targets),
    }

    print("Item startQuest validation")
    print(f"Quest DB: {args.quest_db}")
    print(f"Item DB:  {args.item_db}")
    print(f"Items needing startQuest fixes: {summary['itemsNeedingFixes']}")

    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps({"summary": summary, "mismatches": mismatches}, indent=2), encoding="utf-8")
        print(f"Full report written to {report_path}")

    if args.suggest_lua:
        suggestion_path = Path(args.suggest_lua)
        suggestion_path.parent.mkdir(parents=True, exist_ok=True)
        suggestion_path.write_text(build_lua_suggestions(targets), encoding="utf-8")
        print(f"Lua suggestions written to {suggestion_path}")


if __name__ == "__main__":
    main()
