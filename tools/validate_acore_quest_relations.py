import argparse
import json
import re
import sys
from itertools import product
from pathlib import Path
from typing import Optional


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_acore_quest_metadata import load_acore_sql_table


TARGET_TABLES = {
    "creature_queststarter": ("start", "creature"),
    "creature_questender": ("end", "creature"),
    "gameobject_queststarter": ("start", "object"),
    "gameobject_questender": ("end", "object"),
}

RELATION_SOURCE_ID_ALIASES = {
    "creature": {
        102055: 2055,
    },
}

RELATION_EXPORT_FILES = tuple(TARGET_TABLES)


def empty_relation():
    return {
        "start": {"creature": set(), "object": set(), "item": set()},
        "end": {"creature": set(), "object": set()},
    }


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

INSERT_RE = re.compile(
    r"(?P<kind>INSERT INTO|REPLACE INTO)\s+`(?P<table>creature_queststarter|creature_questender|gameobject_queststarter|gameobject_questender)`.*?VALUES\s*(?P<values>.*?);",
    re.IGNORECASE | re.DOTALL,
)
DELETE_RE = re.compile(
    r"DELETE FROM\s+`(?P<table>creature_queststarter|creature_questender|gameobject_queststarter|gameobject_questender)`\s+WHERE\s*(?P<where>.*?);",
    re.IGNORECASE | re.DOTALL,
)
PAIR_RE = re.compile(r"\(\s*(\d+)\s*,\s*(\d+)\s*\)")
QUEST_ENTRY_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\})$", re.DOTALL)
QUEST_FIELD_RE = re.compile(r"^\[(questKeys\.(?:startedBy|finishedBy))\]\s*=\s*(.+)$", re.DOTALL)


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
                escape_map = {
                    "n": "\n",
                    "r": "\r",
                    "t": "\t",
                    '"': '"',
                    "\\": "\\",
                }
                chars.append(escape_map.get(escaped, escaped))
                continue
            if char == '"':
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


def parse_number_list(value: str):
    if not value:
        return set()
    return {int(part.strip()) for part in value.split(",") if part.strip()}


def split_top_level_lua_table(lua_table: str):
    text = lua_table.strip()
    if not text.startswith("{") or not text.endswith("}"):
        raise ValueError("Expected a Lua table literal")

    items = []
    depth = 0
    start = 1
    index = 1
    in_string = False
    escaped = False

    while index < len(text) - 1:
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
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
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
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


def extract_return_table(lua_file_text: str):
    start = lua_file_text.find("return {")
    if start == -1:
        raise ValueError("Could not find return table")

    index = start + len("return ")
    depth = 0
    in_string = False
    escaped = False

    while index < len(lua_file_text):
        char = lua_file_text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return lua_file_text[start + len("return "): index + 1]
        index += 1

    raise ValueError("Could not extract return table")


def normalize_relation_source_id(source_type: str, source_id: int) -> int:
    return RELATION_SOURCE_ID_ALIASES.get(source_type, {}).get(source_id, source_id)


def parse_delete_pairs(where_clause: str, source_type: Optional[str] = None):
    id_match = re.search(r"`id`\s+IN\s*\(([^)]+)\)|`id`\s*=\s*(\d+)", where_clause, re.IGNORECASE)
    quest_match = re.search(r"`quest`\s+IN\s*\(([^)]+)\)|`quest`\s*=\s*(\d+)", where_clause, re.IGNORECASE)

    if not id_match or not quest_match:
        return set()

    ids = parse_number_list(id_match.group(1)) if id_match.group(1) else {int(id_match.group(2))}
    quests = parse_number_list(quest_match.group(1)) if quest_match.group(1) else {int(quest_match.group(2))}
    pairs = {(source_id, quest_id) for source_id, quest_id in product(ids, quests)}
    if source_type:
        return {(normalize_relation_source_id(source_type, source_id), quest_id) for source_id, quest_id in pairs}
    return pairs


def apply_sql_file(path: Path, state):
    text = path.read_text(encoding="utf-8")
    lowered = text.lower()
    if not any(table in lowered for table in TARGET_TABLES):
        return

    for match in DELETE_RE.finditer(text):
        table = match.group("table").lower()
        relation_type, source_type = TARGET_TABLES[table]
        state[table].difference_update(parse_delete_pairs(match.group("where"), source_type))

    for match in INSERT_RE.finditer(text):
        table = match.group("table").lower()
        relation_type, source_type = TARGET_TABLES[table]
        state[table].update(
            (
                normalize_relation_source_id(source_type, int(left)),
                int(right),
            )
            for left, right in PAIR_RE.findall(match.group("values"))
        )


def load_acore_relations(acore_source: Path, quest_template_sql: Optional[Path] = None):
    state = {table: set() for table in TARGET_TABLES}
    base_dir = acore_source / "data" / "sql" / "base" / "db_world"
    updates_dir = acore_source / "data" / "sql" / "updates" / "db_world"

    relation_export_dir = quest_template_sql.parent if quest_template_sql else None
    relation_export_files = {}
    if relation_export_dir:
        for table in RELATION_EXPORT_FILES:
            export_path = relation_export_dir / f"{table}.sql"
            if export_path.exists():
                relation_export_files[table] = export_path

    if len(relation_export_files) == len(RELATION_EXPORT_FILES):
        for table in RELATION_EXPORT_FILES:
            apply_sql_file(relation_export_files[table], state)
    else:
        for table in TARGET_TABLES:
            apply_sql_file(base_dir / f"{table}.sql", state)

        for update_file in sorted(updates_dir.glob("*.sql")):
            apply_sql_file(update_file, state)

    per_quest = {}
    for table, pairs in state.items():
        relation_type, source_type = TARGET_TABLES[table]
        for source_id, quest_id in pairs:
            relation = per_quest.setdefault(quest_id, empty_relation())
            relation[relation_type][source_type].add(source_id)

    item_template_export = None
    if quest_template_sql:
        candidate = quest_template_sql.parent / "item_template.sql"
        if candidate.exists():
            item_template_export = candidate

    if item_template_export:
        for item_id, row in load_acore_sql_table(
            acore_source,
            "item_template",
            item_template_export,
            key_column="entry",
        ).items():
            start_quest = int(row.get("startquest") or row.get("StartQuest") or 0)
            if start_quest <= 0:
                continue

            relation = per_quest.setdefault(start_quest, empty_relation())
            relation["start"]["item"].add(item_id)
    else:
        for quest_id, row in load_acore_sql_table(acore_source, "quest_template").items():
            start_item = int(row.get("StartItem") or 0)
            if start_item <= 0:
                continue

            relation = per_quest.setdefault(quest_id, empty_relation())
            relation["start"]["item"].add(start_item)
    return per_quest


def extract_relation_sources(value):
    if not isinstance(value, list):
        return {"creature": set(), "object": set(), "item": set()}

    creature = set()
    obj = set()
    item = set()

    if len(value) > 0 and isinstance(value[0], list):
        creature = {int(entry) for entry in value[0] if isinstance(entry, int)}
    if len(value) > 1 and isinstance(value[1], list):
        obj = {int(entry) for entry in value[1] if isinstance(entry, int)}
    if len(value) > 2 and isinstance(value[2], list):
        item = {int(entry) for entry in value[2] if isinstance(entry, int)}

    return {"creature": creature, "object": obj, "item": item}


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
    return_table = extract_return_table(text)
    overrides = {}

    for entry in split_top_level_lua_table(return_table):
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
        relation = questie_relations.setdefault(quest_id, empty_relation())
        for relation_type, value in override.items():
            relation[relation_type] = value


def format_relation_table(source_map):
    creature = sorted(source_map.get("creature", set()))
    obj = sorted(source_map.get("object", set()))
    item = sorted(source_map.get("item", set()))

    if not creature and not obj and not item:
        return "{}"

    if not item:
        parts = []
        if creature:
            parts.append("{" + ",".join(str(value) for value in creature) + "}")
        elif obj:
            parts.append("nil")

        if obj:
            parts.append("{" + ",".join(str(value) for value in obj) + "}")

        return "{" + ",".join(parts) + "}"

    parts = [
        "{" + ",".join(str(value) for value in creature) + "}" if creature else "nil",
        "{" + ",".join(str(value) for value in obj) + "}" if obj else "nil",
        "{" + ",".join(str(value) for value in item) + "}",
    ]

    return "{" + ",".join(parts) + "}"


def build_lua_suggestions(mismatches, acore_relations):
    by_quest = {}
    for mismatch in mismatches:
        quest_id = mismatch["questId"]
        relation = by_quest.setdefault(quest_id, {})
        relation[mismatch["relationType"]] = acore_relations.get(
            quest_id,
            empty_relation(),
        )[mismatch["relationType"]]

    lines = [
        "-- REVIEW BEFORE APPLYING.",
        "-- Generated from AzerothCore static quest relation tables and item_template.startquest.",
        "-- Scripted starts, events, phasing, and intentional Questie divergences still need manual review.",
        "",
    ]

    for quest_id in sorted(by_quest):
        lines.append(f"[{quest_id}] = {{")
        if "start" in by_quest[quest_id]:
            lines.append(f"    [questKeys.startedBy] = {format_relation_table(by_quest[quest_id]['start'])},")
        if "end" in by_quest[quest_id]:
            lines.append(f"    [questKeys.finishedBy] = {format_relation_table(by_quest[quest_id]['end'])},")
        lines.append("},")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def compare_relations(acore_relations, questie_relations):
    mismatches = []
    all_quest_ids = sorted(set(acore_relations) | set(questie_relations))

    for quest_id in all_quest_ids:
        acore = acore_relations.get(quest_id, empty_relation())
        questie = questie_relations.get(quest_id, empty_relation())

        for relation_type in ("start", "end"):
            source_types = ("creature", "object", "item") if relation_type == "start" else ("creature", "object")
            for source_type in source_types:
                acore_set = acore[relation_type][source_type]
                questie_set = questie[relation_type][source_type]
                if acore_set != questie_set:
                    mismatches.append(
                        {
                            "questId": quest_id,
                            "relationType": relation_type,
                            "sourceType": source_type,
                            "missingInQuestie": sorted(acore_set - questie_set),
                            "extraInQuestie": sorted(questie_set - acore_set),
                        }
                    )

    return mismatches


def build_summary(mismatches):
    summary = {
        "total": len(mismatches),
        "startCreature": 0,
        "startObject": 0,
        "startItem": 0,
        "endCreature": 0,
        "endObject": 0,
    }

    for mismatch in mismatches:
        key = mismatch["relationType"] + mismatch["sourceType"].capitalize()
        summary[key] += 1

    return summary


def main():
    parser = argparse.ArgumentParser(description="Validate Questie WotLK quest starter/finisher data against AzerothCore SQL.")
    parser.add_argument("--acore-source", default=r"P:\AC\source", help="Path to the AzerothCore source tree")
    parser.add_argument("--quest-db", default="Database/Wotlk/wotlkQuestDB.lua", help="Path to the Questie WotLK quest DB")
    parser.add_argument(
        "--quest-template-sql",
        help="Optional HeidiSQL export for quest_template; sibling relation exports and item_template.sql will be used when present",
    )
    parser.add_argument(
        "--quest-fixes",
        nargs="*",
        default=[
            "Database/Corrections/classicQuestFixes.lua",
            "Database/Corrections/tbcQuestFixes.lua",
            "Database/Corrections/wotlkQuestFixes.lua",
        ],
        help="Quest correction files to merge before comparison",
    )
    parser.add_argument("--limit", type=int, default=20, help="How many mismatches to print")
    parser.add_argument("--report", help="Optional path to write the full JSON report")
    parser.add_argument("--suggest-lua", help="Optional path to write candidate Lua quest relation fixes")
    args = parser.parse_args()

    acore_source = Path(args.acore_source)
    quest_db_path = Path(args.quest_db)
    quest_template_sql = Path(args.quest_template_sql) if args.quest_template_sql else None

    acore_relations = load_acore_relations(acore_source, quest_template_sql)
    questie_relations = load_questie_relations(quest_db_path)
    for fix_file in args.quest_fixes:
        apply_relation_overrides(questie_relations, load_quest_relation_overrides(Path(fix_file)))
    mismatches = compare_relations(acore_relations, questie_relations)
    summary = build_summary(mismatches)

    print("AzerothCore quest relation validation")
    print(f"AzerothCore source: {acore_source}")
    print(f"Quest DB: {quest_db_path}")
    if quest_template_sql:
        print(f"Quest template export: {quest_template_sql}")
    print(f"Total mismatches: {summary['total']}")
    print(f"  start/creature: {summary['startCreature']}")
    print(f"  start/object:   {summary['startObject']}")
    print(f"  start/item:     {summary['startItem']}")
    print(f"  end/creature:   {summary['endCreature']}")
    print(f"  end/object:     {summary['endObject']}")

    if mismatches:
        print("")
        print(f"Showing first {min(args.limit, len(mismatches))} mismatches:")
        for mismatch in mismatches[: args.limit]:
            print(
                json.dumps(
                    mismatch,
                    separators=(",", ":"),
                )
            )

    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(
                {
                    "summary": summary,
                    "mismatches": mismatches,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        print("")
        print(f"Full report written to {report_path}")

    if args.suggest_lua:
        suggestion_path = Path(args.suggest_lua)
        suggestion_path.parent.mkdir(parents=True, exist_ok=True)
        suggestion_text = build_lua_suggestions(mismatches, acore_relations)
        validate_lua_fragment(suggestion_text, str(suggestion_path))
        suggestion_path.write_text(suggestion_text, encoding="utf-8")
        print(f"Lua suggestions written to {suggestion_path}")


if __name__ == "__main__":
    main()
