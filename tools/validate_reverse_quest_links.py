import argparse
import json
import re
from pathlib import Path


QUEST_ENTRY_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\})$", re.DOTALL)
QUEST_FIELD_RE = re.compile(r"^\[(questKeys\.(?:startedBy|finishedBy))\]\s*=\s*(.+)$", re.DOTALL)
NPC_ENTRY_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\})$", re.DOTALL)
NPC_FIELD_RE = re.compile(r"^\[(npcKeys\.(?:questStarts|questEnds))\]\s*=\s*(.+)$", re.DOTALL)
OBJECT_FIELD_RE = re.compile(r"^\[(objectKeys\.(?:questStarts|questEnds))\]\s*=\s*(.+)$", re.DOTALL)


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
            return self._parse_string()
        if char == "'":
            return self._parse_single_quoted_string()
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
        if char == "[":
            return self._parse_bracket_key_value()
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

    def _parse_string(self):
        assert self._peek() == '"'
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
                escape_map = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
                chars.append(escape_map.get(escaped, escaped))
                continue
            if char == '"':
                return "".join(chars)
            chars.append(char)

        raise ValueError("Unterminated Lua string")

    def _parse_single_quoted_string(self):
        assert self._peek() == "'"
        self.index += 1
        chars = []

        while self.index < self.length:
            char = self.text[self.index]
            self.index += 1
            if char == "\\":
                if self.index >= self.length:
                    break
                chars.append(self.text[self.index])
                self.index += 1
                continue
            if char == "'":
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

    def _parse_bracket_key_value(self):
        assert self._peek() == "["
        depth = 0
        start = self.index
        while self.index < self.length:
            char = self.text[self.index]
            if char == "[":
                depth += 1
            elif char == "]":
                depth -= 1
                if depth == 0:
                    self.index += 1
                    break
            self.index += 1

        self._skip_ws()
        if self._peek() != "=":
            raise ValueError(f"Unsupported bracket token near: {self.text[start:self.index + 16]!r}")
        self.index += 1
        return {"__kv__": True, "key": self.text[start:self.index].strip(), "value": self._parse_value()}


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


def extract_table_after(marker_index: int, lua_file_text: str):
    index = marker_index
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


def extract_relation_sources(value):
    if not isinstance(value, list):
        return {"creature": set(), "object": set()}

    creature = set()
    obj = set()

    if len(value) > 0 and isinstance(value[0], list):
        creature = {int(entry) for entry in value[0] if isinstance(entry, int)}
    if len(value) > 1 and isinstance(value[1], list):
        obj = {int(entry) for entry in value[1] if isinstance(entry, int)}

    return {"creature": creature, "object": obj}


def load_questie_relations(quest_db_path: Path):
    per_quest = {}

    for raw_line in quest_db_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("["):
            continue

        quest_id_match = re.match(r"\[(\d+)\]\s*=\s*(\{.*\}),?$", line)
        if not quest_id_match:
            continue

        quest_id = int(quest_id_match.group(1))
        fields = split_top_level_lua_table(quest_id_match.group(2))
        if len(fields) < 3:
            continue

        per_quest[quest_id] = {
            "start": extract_relation_sources(LuaTableParser(fields[1]).parse() if fields[1] != "nil" else None),
            "end": extract_relation_sources(LuaTableParser(fields[2]).parse() if fields[2] != "nil" else None),
        }

    return per_quest


def load_quest_relation_overrides(fix_file_path: Path):
    text = strip_lua_comments(fix_file_path.read_text(encoding="utf-8"))
    overrides = {}

    for table_text in extract_named_tables(text, ["return {"]):
        for entry in split_top_level_lua_table(table_text):
            match = QUEST_ENTRY_RE.match(entry.strip())
            if not match:
                continue

            quest_id = int(match.group(1))
            body = match.group(2)
            parsed_fields = {}

            for field in split_top_level_lua_table(body):
                field_match = QUEST_FIELD_RE.match(field.strip())
                if not field_match:
                    continue

                field_name = field_match.group(1)
                field_value = field_match.group(2).strip()
                parsed_fields[field_name] = None if field_value == "nil" else LuaTableParser(field_value).parse()

            if parsed_fields:
                quest_override = overrides.setdefault(quest_id, {})
                if "questKeys.startedBy" in parsed_fields:
                    quest_override["start"] = extract_relation_sources(parsed_fields["questKeys.startedBy"])
                if "questKeys.finishedBy" in parsed_fields:
                    quest_override["end"] = extract_relation_sources(parsed_fields["questKeys.finishedBy"])

    return overrides


def apply_relation_overrides(questie_relations, overrides):
    for quest_id, override in overrides.items():
        relation = questie_relations.setdefault(
            quest_id,
            {
                "start": {"creature": set(), "object": set()},
                "end": {"creature": set(), "object": set()},
            },
        )
        for relation_type, value in override.items():
            relation[relation_type] = value


def parse_optional_int_list(value):
    if value is None:
        return set()
    if isinstance(value, list):
        return {int(entry) for entry in value if isinstance(entry, int)}
    return set()


def load_base_npc_reverse(npc_db_path: Path):
    result = {}
    for raw_line in npc_db_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("["):
            continue
        match = re.match(r"\[(\d+)\]\s*=\s*(\{.*\}),?$", line)
        if not match:
            continue

        npc_id = int(match.group(1))
        fields = split_top_level_lua_table(match.group(2))
        if len(fields) < 11:
            continue

        result[npc_id] = {
            "questStarts": parse_optional_int_list(None if fields[9] == "nil" else LuaTableParser(fields[9]).parse()),
            "questEnds": parse_optional_int_list(None if fields[10] == "nil" else LuaTableParser(fields[10]).parse()),
        }
    return result


def load_base_object_reverse(object_db_path: Path):
    result = {}
    for raw_line in object_db_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("["):
            continue
        match = re.match(r"\[(\d+)\]\s*=\s*(\{.*\}),?$", line)
        if not match:
            continue

        object_id = int(match.group(1))
        fields = split_top_level_lua_table(match.group(2))
        if len(fields) < 3:
            continue

        result[object_id] = {
            "questStarts": parse_optional_int_list(None if fields[1] == "nil" else LuaTableParser(fields[1]).parse()),
            "questEnds": parse_optional_int_list(None if fields[2] == "nil" else LuaTableParser(fields[2]).parse()),
        }
    return result


def load_reverse_overrides(fix_file_path: Path, entity_kind: str):
    text = strip_lua_comments(fix_file_path.read_text(encoding="utf-8"))
    markers = ["return {", "local npcFixesHorde = ", "local npcFixesAlliance = ", "local objectFixesHorde = ", "local objectFixesAlliance = "]
    field_re = NPC_FIELD_RE if entity_kind == "npc" else OBJECT_FIELD_RE
    overrides = {}

    for table_text in extract_named_tables(text, markers):
        for entry in split_top_level_lua_table(table_text):
            match = NPC_ENTRY_RE.match(entry.strip())
            if not match:
                continue

            entity_id = int(match.group(1))
            body = match.group(2)
            parsed_fields = {}

            for field in split_top_level_lua_table(body):
                field_match = field_re.match(field.strip())
                if not field_match:
                    continue

                field_name = field_match.group(1)
                field_value = field_match.group(2).strip()
                parsed_fields[field_name] = None if field_value == "nil" else LuaTableParser(field_value).parse()

            if parsed_fields:
                entity_override = overrides.setdefault(entity_id, {})
                if entity_kind == "npc":
                    if "npcKeys.questStarts" in parsed_fields:
                        entity_override["questStarts"] = parse_optional_int_list(parsed_fields["npcKeys.questStarts"])
                    if "npcKeys.questEnds" in parsed_fields:
                        entity_override["questEnds"] = parse_optional_int_list(parsed_fields["npcKeys.questEnds"])
                else:
                    if "objectKeys.questStarts" in parsed_fields:
                        entity_override["questStarts"] = parse_optional_int_list(parsed_fields["objectKeys.questStarts"])
                    if "objectKeys.questEnds" in parsed_fields:
                        entity_override["questEnds"] = parse_optional_int_list(parsed_fields["objectKeys.questEnds"])

    return overrides


def apply_reverse_overrides(reverse_map, overrides):
    for entity_id, fields in overrides.items():
        target = reverse_map.setdefault(entity_id, {"questStarts": set(), "questEnds": set()})
        for field_name, value in fields.items():
            target[field_name] = set(value)


def build_expected_reverse_maps(quest_relations):
    npc_expected = {}
    object_expected = {}

    for quest_id, relation in quest_relations.items():
        for npc_id in relation["start"]["creature"]:
            npc_expected.setdefault(npc_id, {"questStarts": set(), "questEnds": set()})["questStarts"].add(quest_id)
        for npc_id in relation["end"]["creature"]:
            npc_expected.setdefault(npc_id, {"questStarts": set(), "questEnds": set()})["questEnds"].add(quest_id)
        for object_id in relation["start"]["object"]:
            object_expected.setdefault(object_id, {"questStarts": set(), "questEnds": set()})["questStarts"].add(quest_id)
        for object_id in relation["end"]["object"]:
            object_expected.setdefault(object_id, {"questStarts": set(), "questEnds": set()})["questEnds"].add(quest_id)

    return npc_expected, object_expected


def compare_reverse(expected_map, current_map, entity_kind):
    mismatches = []
    target_entries = {}

    for entity_id, expected in sorted(expected_map.items()):
        current = current_map.get(entity_id, {"questStarts": set(), "questEnds": set()})
        for field_name in ("questStarts", "questEnds"):
            missing = expected[field_name] - current[field_name]
            if missing:
                target = target_entries.setdefault(entity_id, {
                    "questStarts": set(current["questStarts"]),
                    "questEnds": set(current["questEnds"]),
                })
                target[field_name].update(expected[field_name])
                mismatches.append(
                    {
                        "entityKind": entity_kind,
                        "entityId": entity_id,
                        "field": field_name,
                        "missingInReverse": sorted(missing),
                        "current": sorted(current[field_name]),
                        "expected": sorted(expected[field_name]),
                    }
                )

    return mismatches, target_entries


def build_lua_suggestions(entity_kind, entries):
    key_name = "npcKeys" if entity_kind == "npc" else "objectKeys"
    lines = [
        "-- REVIEW BEFORE APPLYING.",
        "-- Generated from Questie quest-side startedBy/finishedBy relations.",
        "-- This only backfills missing reverse questStarts/questEnds links.",
        "",
    ]

    for entity_id in sorted(entries):
        fields = entries[entity_id]
        lines.append(f"[{entity_id}] = {{")
        if fields["questStarts"]:
            starts = ",".join(str(value) for value in sorted(fields["questStarts"]))
            lines.append(f"    [{key_name}.questStarts] = {{{starts}}},")
        if fields["questEnds"]:
            ends = ",".join(str(value) for value in sorted(fields["questEnds"]))
            lines.append(f"    [{key_name}.questEnds] = {{{ends}}},")
        lines.append("},")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main():
    parser = argparse.ArgumentParser(description="Validate reverse NPC/object quest links against effective Questie quest relations.")
    parser.add_argument("--quest-db", default="Database/Wotlk/wotlkQuestDB.lua")
    parser.add_argument("--npc-db", default="Database/Wotlk/wotlkNpcDB.lua")
    parser.add_argument("--object-db", default="Database/Wotlk/wotlkObjectDB.lua")
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
        "--npc-fixes",
        nargs="*",
        default=[
            "Database/Corrections/classicNPCFixes.lua",
            "Database/Corrections/tbcNPCFixes.lua",
            "Database/Corrections/wotlkNPCFixes.lua",
        ],
    )
    parser.add_argument(
        "--object-fixes",
        nargs="*",
        default=[
            "Database/Corrections/classicObjectFixes.lua",
            "Database/Corrections/tbcObjectFixes.lua",
            "Database/Corrections/wotlkObjectFixes.lua",
        ],
    )
    parser.add_argument("--report", help="Optional path to write the full JSON report")
    parser.add_argument("--suggest-npc-lua", help="Optional path to write NPC reverse-link fix suggestions")
    parser.add_argument("--suggest-object-lua", help="Optional path to write object reverse-link fix suggestions")
    args = parser.parse_args()

    quest_relations = load_questie_relations(Path(args.quest_db))
    for fix_file in args.quest_fixes:
        apply_relation_overrides(quest_relations, load_quest_relation_overrides(Path(fix_file)))

    npc_current = load_base_npc_reverse(Path(args.npc_db))
    for fix_file in args.npc_fixes:
        apply_reverse_overrides(npc_current, load_reverse_overrides(Path(fix_file), "npc"))

    object_current = load_base_object_reverse(Path(args.object_db))
    for fix_file in args.object_fixes:
        apply_reverse_overrides(object_current, load_reverse_overrides(Path(fix_file), "object"))

    npc_expected, object_expected = build_expected_reverse_maps(quest_relations)
    npc_mismatches, npc_targets = compare_reverse(npc_expected, npc_current, "npc")
    object_mismatches, object_targets = compare_reverse(object_expected, object_current, "object")

    summary = {
        "npcEntitiesMissing": len(npc_targets),
        "npcFieldsMissing": len(npc_mismatches),
        "objectEntitiesMissing": len(object_targets),
        "objectFieldsMissing": len(object_mismatches),
        "totalEntitiesMissing": len(npc_targets) + len(object_targets),
        "totalFieldsMissing": len(npc_mismatches) + len(object_mismatches),
    }

    print("Quest reverse-link validation")
    print(f"Quest DB: {args.quest_db}")
    print(f"NPC DB:   {args.npc_db}")
    print(f"Object DB:{args.object_db}")
    print(f"NPC entities missing reverse links:    {summary['npcEntitiesMissing']}")
    print(f"NPC fields missing reverse links:      {summary['npcFieldsMissing']}")
    print(f"Object entities missing reverse links: {summary['objectEntitiesMissing']}")
    print(f"Object fields missing reverse links:   {summary['objectFieldsMissing']}")
    print(f"Total entities missing reverse links:  {summary['totalEntitiesMissing']}")

    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(
                {
                    "summary": summary,
                    "npcMismatches": npc_mismatches,
                    "objectMismatches": object_mismatches,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"Full report written to {report_path}")

    if args.suggest_npc_lua:
        suggestion_path = Path(args.suggest_npc_lua)
        suggestion_path.parent.mkdir(parents=True, exist_ok=True)
        suggestion_path.write_text(build_lua_suggestions("npc", npc_targets), encoding="utf-8")
        print(f"NPC Lua suggestions written to {suggestion_path}")

    if args.suggest_object_lua:
        suggestion_path = Path(args.suggest_object_lua)
        suggestion_path.parent.mkdir(parents=True, exist_ok=True)
        suggestion_path.write_text(build_lua_suggestions("object", object_targets), encoding="utf-8")
        print(f"Object Lua suggestions written to {suggestion_path}")


if __name__ == "__main__":
    main()
