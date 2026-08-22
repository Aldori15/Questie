import argparse
import ast
import json
import re
import sys
from collections import defaultdict
from functools import lru_cache
from pathlib import Path


sys.dont_write_bytecode = True
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_acore_quest_metadata import (  # noqa: E402
    extract_sql_columns,
    parse_sql_value,
    split_sql_rows,
    split_sql_statements,
    split_sql_values,
    strip_sql_comments,
)


ITEM_CORRECTION_FILES = [
    "Database/Corrections/classicItemFixes.lua",
    "Database/Corrections/tbcItemFixes.lua",
    "Database/Corrections/wotlkItemFixes.lua",
    "Database/Corrections/Automatic/itemStartFixes.lua",
]
ITEM_START_FIXES_FILE = "Database/Corrections/Automatic/itemStartFixes.lua"

STATIC_FIELD_MAP = {
    "name": "name",
    "flags": "Flags",
    "foodType": "FoodType",
    "itemLevel": "ItemLevel",
    "requiredLevel": "RequiredLevel",
    "ammoType": "ammo_type",
    "class": "class",
    "subClass": "subclass",
}

LIST_FIELDS = {"npcDrops", "objectDrops", "itemDrops", "questRewards", "vendors", "relatedQuests"}
OBJECT_LOOT_PRIMARY_CHANCE = 100.0
LOW_CHANCE_CREATURE_DROP_THRESHOLD = 1.0
SCALAR_FIELDS = {"name", "startQuest", "flags", "foodType", "itemLevel", "requiredLevel", "ammoType", "class", "subClass"}

FIELD_ORDER = [
    "name",
    "npcDrops",
    "objectDrops",
    "itemDrops",
    "startQuest",
    "questRewards",
    "flags",
    "foodType",
    "itemLevel",
    "requiredLevel",
    "ammoType",
    "class",
    "subClass",
    "vendors",
    "relatedQuests",
]

ACORE_SOURCE = "AzerothCore"

def strip_lua_comments(text):
    result = []
    index = 0
    in_string = None
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
            elif char == in_string:
                in_string = None
            index += 1
            continue

        if char in ("'", '"'):
            in_string = char
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


def extract_lua_long_return_table(text, marker):
    marker_index = text.find(marker)
    if marker_index == -1:
        raise ValueError(f"Could not find marker {marker!r}")
    start = text.find("[[return", marker_index)
    if start == -1:
        raise ValueError(f"Could not find long return table after {marker!r}")
    open_brace = text.find("{", start)
    end = text.find("}]]", open_brace)
    if open_brace == -1 or end == -1:
        raise ValueError(f"Could not extract long return table after {marker!r}")
    return text[open_brace : end + 1]


def extract_function_return_tables(text, function_name):
    tables = []
    search_at = 0
    pattern = re.compile(rf"function\s+{re.escape(function_name)}\s*\([^)]*\)")
    while True:
        match = pattern.search(text, search_at)
        if not match:
            return tables

        function_end = find_lua_function_end(text, match.end())
        body = text[match.end() : function_end]
        for return_match in re.finditer(r"\breturn\s*\{", body):
            open_brace = match.end() + return_match.end() - 1
            tables.append(extract_balanced_braces(text, open_brace))
        search_at = function_end + 3


def find_lua_function_end(text, start):
    depth = 1
    index = start
    in_string = None
    escaped = False

    token_re = re.compile(r"\b(function|if|for|while|repeat|do|end|until)\b")
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
            index += 1
            continue

        if char == "-" and index + 1 < len(text) and text[index + 1] == "-":
            while index < len(text) and text[index] != "\n":
                index += 1
            continue

        token = token_re.match(text, index)
        if token:
            value = token.group(1)
            if value in {"function", "if", "for", "while", "repeat", "do"}:
                depth += 1
            elif value in {"end", "until"}:
                depth -= 1
                if depth == 0:
                    return index
            index = token.end()
            continue

        index += 1

    raise ValueError("Could not find function end")


def extract_balanced_braces(text, open_brace):
    if text[open_brace] != "{":
        raise ValueError("Expected opening brace")

    depth = 0
    in_string = None
    escaped = False
    index = open_brace

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
            depth -= 1
            if depth == 0:
                return text[open_brace : index + 1]

        index += 1

    raise ValueError("Unbalanced Lua table")


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


def parse_item_keys(item_db_path):
    text = item_db_path.read_text(encoding="utf-8")
    key_block = extract_balanced_braces(text, text.find("{", text.find("QuestieDB.itemKeys")))
    keys = {}
    for name, value in re.findall(r"\['([^']+)'\]\s*=\s*(\d+)", key_block):
        keys[name] = int(value)
    return keys


def load_questie_items(item_db_path, item_keys):
    text = item_db_path.read_text(encoding="utf-8")
    table_text = extract_lua_long_return_table(text, "QuestieDB.itemData")
    parsed = LuaParser(table_text).parse()
    items = {}
    reverse_keys = {index: name for name, index in item_keys.items()}
    for item_id, values in parsed.items():
        row = {}
        for index, value in enumerate(values, start=1):
            if value is not None and index in reverse_keys:
                row[reverse_keys[index]] = value
        items[int(item_id)] = row
    return items


def load_lua_item_corrections(path, item_keys):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    constants = {
        "itemClasses.QUEST": 12,
    }
    for name, index in item_keys.items():
        constants[f"itemKeys.{name}"] = name

    tables = []
    for function_name in (
        "QuestieItemFixes:Load",
        "QuestieTBCItemFixes:Load",
        "QuestieWotlkItemFixes:Load",
        "QuestieWotlkItemFixes:LoadReverseStartQuestFixes",
        "QuestieItemStartFixes:LoadAutomaticQuestStarts",
    ):
        tables.extend(extract_function_return_tables(text, function_name))

    corrections = {}
    for table_text in tables:
        parsed = LuaParser(table_text, constants).parse()
        for item_id, fields in parsed.items():
            if not isinstance(item_id, int) or not isinstance(fields, dict):
                continue
            corrections.setdefault(item_id, {})
            for key, value in fields.items():
                if key in item_keys:
                    corrections[item_id][key] = value
    return corrections


def apply_corrections(items, corrections, no_overwrites=False, no_new_entries=False):
    for item_id, fields in corrections.items():
        if item_id not in items:
            if no_new_entries:
                continue
            items[item_id] = {}
        for field, value in fields.items():
            if no_overwrites and items[item_id].get(field) is not None:
                continue
            items[item_id][field] = value


def load_effective_questie_items(repo_root, item_keys):
    items = load_questie_items(repo_root / "Database/Wotlk/wotlkItemDB.lua", item_keys)
    for relative_path in ITEM_CORRECTION_FILES:
        path = repo_root / relative_path
        if not path.exists():
            continue
        corrections = load_lua_item_corrections(path, item_keys)
        if relative_path.endswith("itemStartFixes.lua"):
            apply_corrections(items, corrections, no_overwrites=True, no_new_entries=True)
        else:
            apply_corrections(items, corrections)
    return items


def source_sql_files(source_root, table_name, include_modules=False):
    source_root = Path(source_root)
    base_file = source_root / "data/sql/base/db_world" / f"{table_name}.sql"
    if base_file.exists():
        yield base_file

    roots = [source_root / "data/sql/updates/db_world"]
    modules_dir = source_root / "modules"
    if include_modules and modules_dir.exists():
        for module_dir in sorted((path for path in modules_dir.iterdir() if path.is_dir()), key=lambda path: path.name.lower()):
            roots.append(module_dir / "data/sql/world/base")
            roots.append(module_dir / "data/sql/world/updates")

    for root in roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.sql"), key=lambda path: str(path).lower()):
            yield path


@lru_cache(maxsize=None)
def load_sql_statements(path_text):
    raw_text = Path(path_text).read_text(encoding="utf-8")
    return raw_text, tuple(split_sql_statements(strip_sql_comments(raw_text)))


def load_row_table(source_root, table_name, key_columns, include_modules=False):
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
                skipped_mutations += apply_multirow_insert(statement, table_name, columns, rows, key_columns, sql_context)
            elif upper.startswith("DELETE"):
                skipped_mutations += apply_multirow_delete(statement, table_name, rows, sql_context)
            elif upper.startswith("UPDATE"):
                skipped_mutations += apply_multirow_update(statement, table_name, rows, sql_context)

    return list(rows.values()), skipped_mutations


def load_keyed_table(source_root, table_name, key_column, include_modules=False):
    rows, skipped_mutations = load_row_table(source_root, table_name, (key_column,), include_modules)
    keyed = {}
    for row in rows:
        key = row.get(key_column)
        if key is not None:
            keyed[int(key)] = row
    return keyed, skipped_mutations


def statement_targets_table(statement, table_name):
    table = re.escape(table_name)
    return any(
        re.match(pattern, statement, re.IGNORECASE | re.DOTALL)
        for pattern in (
            rf"\s*(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO)\s+`?{table}`?\b",
            rf"\s*UPDATE\s+`?{table}`?\b",
            rf"\s*DELETE\s+(?:`?{table}`?\s+)?FROM\s+`?{table}`?\b",
        )
    )


def apply_variable_set(statement, context):
    body = statement.strip()[3:].strip()
    for assignment in split_sql_values(body):
        match = re.match(r"(@[A-Za-z0-9_]+)\s*(?::=|=)\s*(.+)$", assignment.strip(), re.DOTALL)
        if not match:
            continue
        try:
            context[match.group(1).lower()] = parse_insert_sql_value(match.group(2), context)
        except Exception:
            continue


def replace_sql_variables(value, context):
    if not context:
        return value
    for name, replacement in sorted(context.items(), key=lambda item: len(item[0]), reverse=True):
        if replacement is None:
            replacement = 0
        value = re.sub(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", str(replacement), value, flags=re.IGNORECASE)
    return value


def apply_multirow_insert(
    statement,
    table_name,
    default_columns,
    rows,
    key_columns,
    sql_context=None,
    row_filter=None,
):
    match = re.search(
        rf"(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO)\s+`?{re.escape(table_name)}`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return 1

    columns = default_columns
    if match.group("columns"):
        columns = [column_match.group(1) for column_match in re.finditer(r"`([^`]+)`", match.group("columns"))]
        canonical_columns = {column.lower(): column for column in default_columns}
        columns = [canonical_columns.get(column.lower(), column) for column in columns]

    skipped = 0
    for row_text in split_sql_rows(match.group("values")):
        values = split_sql_values(row_text)
        if len(values) != len(columns):
            skipped += 1
            continue
        row = {}
        try:
            for column, raw_value in zip(columns, values):
                row[column] = parse_insert_sql_value(raw_value, sql_context)
        except Exception:
            skipped += 1
            continue
        key = tuple(row.get(column) for column in key_columns)
        if all(value is not None for value in key):
            if row_filter is None or row_filter(row):
                rows[key] = row
            else:
                # INSERT/REPLACE can overwrite a previously relevant row with
                # one that no longer belongs in a filtered table replay.
                rows.pop(key, None)
        else:
            skipped += 1
    return skipped


def parse_insert_sql_value(token, context=None):
    value = token.strip()
    if not value or value.upper() == "NULL":
        return None
    if "@" in value and not context:
        raise ValueError("SQL variables are not supported in bulk inserts")
    value = replace_sql_variables(value, context)
    value = re.sub(r"(?<![\w.])0+([1-9]\d*)\b", r"\1", value)
    if value[0] in {"'", '"'} and value[-1] == value[0]:
        return ast.literal_eval(value)
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    if re.fullmatch(r"-?(?:\d+\.\d*|\d*\.\d+)", value):
        return float(value)
    return parse_sql_value(value)


def strip_wrapping_parentheses(clause):
    clause = clause.strip()
    while clause.startswith("(") and clause.endswith(")"):
        depth = 0
        in_string = None
        escaped = False
        wraps = True
        for index, char in enumerate(clause):
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == in_string:
                    in_string = None
                continue
            if char in ("'", '"'):
                in_string = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0 and index != len(clause) - 1:
                    wraps = False
                    break
        if not wraps:
            break
        clause = clause[1:-1].strip()
    return clause


def split_where_clauses(where_clause):
    clauses = []
    start = 0
    index = 0
    depth = 0
    in_string = None
    escaped = False
    between_pending = False

    while index < len(where_clause):
        char = where_clause[index]
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
            index += 1
            continue
        if char == "(":
            depth += 1
            index += 1
            continue
        if char == ")":
            depth -= 1
            index += 1
            continue

        if depth == 0:
            token = re.match(r"\b(AND|BETWEEN|OR)\b", where_clause[index:], re.IGNORECASE)
            if token:
                value = token.group(1).upper()
                if value == "BETWEEN":
                    between_pending = True
                elif value == "OR":
                    return None
                elif value == "AND":
                    if between_pending:
                        between_pending = False
                    else:
                        clauses.append(where_clause[start:index].strip())
                        start = token.end() + index
                index += len(token.group(0))
                continue

        index += 1

    tail = where_clause[start:].strip()
    if tail:
        clauses.append(tail)
    return clauses


def split_or_clauses(where_clause):
    clauses = []
    start = 0
    index = 0
    depth = 0
    in_string = None
    escaped = False

    while index < len(where_clause):
        char = where_clause[index]
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
            index += 1
            continue
        if char == "(":
            depth += 1
            index += 1
            continue
        if char == ")":
            depth -= 1
            index += 1
            continue

        if depth == 0:
            token = re.match(r"\bOR\b", where_clause[index:], re.IGNORECASE)
            if token:
                clauses.append(where_clause[start:index].strip())
                start = index + len(token.group(0))
                index = start
                continue

        index += 1

    tail = where_clause[start:].strip()
    if tail:
        clauses.append(tail)
    return clauses if len(clauses) > 1 else None


def split_update_statement(statement, table_name):
    match = re.match(rf"\s*UPDATE\s+`?{re.escape(table_name)}`?\s+SET\s+", statement, re.IGNORECASE)
    if not match:
        return None, None, False

    body = statement[match.end() :]
    depth = 0
    in_string = None
    escaped = False
    index = 0
    while index < len(body):
        char = body[index]
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
            index += 1
            continue
        if char == "(":
            depth += 1
            index += 1
            continue
        if char == ")":
            depth -= 1
            index += 1
            continue
        if depth == 0 and re.match(r"\bWHERE\b", body[index:], re.IGNORECASE):
            return body[:index].strip(), body[index + 5 :].strip(), True
        index += 1

    return body.strip(), None, True


def parse_where_constraints(where_clause, context=None):
    constraints = {}
    clauses = split_where_clauses(strip_wrapping_parentheses(where_clause))
    if clauses is None:
        return None
    for raw_clause in clauses:
        clause = strip_wrapping_parentheses(raw_clause)
        if re.search(r"\s+OR\s+", clause, re.IGNORECASE):
            or_clauses = split_or_clauses(clause)
            if not or_clauses:
                return None
            or_constraints = []
            for or_clause in or_clauses:
                parsed = parse_where_constraints(or_clause, context)
                if parsed is None:
                    return None
                or_constraints.append(parsed)
            constraints[f"__or_{len(constraints)}"] = ("or", or_constraints)
            continue

        match = re.match(r"`?([A-Za-z0-9_]+)`?\s*IN\s*\(([^)]+)\)", clause, re.IGNORECASE | re.DOTALL)
        if match:
            values = set()
            for token in split_sql_values(match.group(2)):
                token = token.strip()
                if "@" in token and not context:
                    return None
                token = replace_sql_variables(token, context)
                try:
                    values.add(parse_sql_value(token))
                except Exception:
                    return None
            constraints[match.group(1).lower()] = values
            continue

        match = re.match(r"`?([A-Za-z0-9_]+)`?\s+BETWEEN\s+(.+?)\s+AND\s+(.+)$", clause, re.IGNORECASE | re.DOTALL)
        if match:
            low = replace_sql_variables(match.group(2).strip(), context)
            high = replace_sql_variables(match.group(3).strip(), context)
            try:
                constraints[match.group(1).lower()] = ("between", parse_sql_value(low), parse_sql_value(high))
            except Exception:
                return None
            continue

        match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(.+)$", clause, re.IGNORECASE | re.DOTALL)
        if match:
            token = match.group(2).strip()
            if "@" in token and not context:
                return None
            token = replace_sql_variables(token, context)
            try:
                constraints[match.group(1).lower()] = {parse_sql_value(token)}
            except Exception:
                return None
            continue

        match = re.match(r"(.+?)\s*(=|!=|<>|>=|<=|>|<)\s*(.+)$", clause, re.IGNORECASE | re.DOTALL)
        if match:
            left = replace_sql_variables(match.group(1).strip().replace("`", ""), context)
            right = replace_sql_variables(match.group(3).strip().replace("`", ""), context)
            constraints[f"__expr_{len(constraints)}"] = ("expr", left, match.group(2), right)
            continue

        return None

    return constraints


def row_matches_constraints(row, constraints):
    lower_row = {key.lower(): value for key, value in row.items()}
    for column, values in constraints.items():
        if isinstance(values, tuple) and values and values[0] == "or":
            if not any(row_matches_constraints(row, sub_constraints) for sub_constraints in values[1]):
                return False
            continue
        if isinstance(values, tuple) and values and values[0] == "expr":
            left = parse_sql_value(values[1], lower_row)
            right = parse_sql_value(values[3], lower_row)
            operator = values[2]
            if operator == "=" and not (left == right):
                return False
            if operator in {"!=", "<>"} and not (left != right):
                return False
            if operator == ">" and not (left > right):
                return False
            if operator == "<" and not (left < right):
                return False
            if operator == ">=" and not (left >= right):
                return False
            if operator == "<=" and not (left <= right):
                return False
            continue
        actual = lower_row.get(column)
        if isinstance(values, tuple) and values and values[0] == "between":
            if isinstance(actual, str) and re.fullmatch(r"-?\d+(?:\.\d+)?", actual):
                actual = float(actual) if "." in actual else int(actual)
            if actual is None or not (values[1] <= actual <= values[2]):
                return False
            continue
        if actual not in values:
            return False
    return True


def apply_multirow_delete(statement, table_name, rows, sql_context=None):
    match = re.search(
        rf"DELETE\s+(?:`?{re.escape(table_name)}`?\s+)?FROM\s+`?{re.escape(table_name)}`?\s+WHERE\s*(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return 1
    constraints = parse_where_constraints(match.group("where"), sql_context)
    if constraints is None:
        return 1
    for key, row in list(rows.items()):
        if row_matches_constraints(row, constraints):
            rows.pop(key, None)
    return 0


def apply_multirow_update(statement, table_name, rows, sql_context=None):
    assignments_text, where_text, matched = split_update_statement(statement, table_name)
    if not matched:
        return 1
    constraints = parse_where_constraints(where_text, sql_context) if where_text else {}
    if constraints is None:
        return 1

    assignments = split_sql_values(assignments_text)
    for row in rows.values():
        if not row_matches_constraints(row, constraints):
            continue
        context = {key: value for key, value in row.items() if not isinstance(value, (list, tuple, dict))}
        for assignment in assignments:
            assign_match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(.+)$", assignment.strip(), re.DOTALL)
            if not assign_match:
                continue
            try:
                expression = replace_sql_variables(assign_match.group(2), sql_context)
                row[assign_match.group(1)] = parse_sql_value(expression, context)
            except Exception:
                continue
    return 0


def add_item_sources_from_loot(rows, reference_index, source_to_object_ids=None, object_primary_items=None):
    object_primary_items = object_primary_items or set()
    per_item = defaultdict(set)
    grouped = defaultdict(list)
    for row in rows:
        grouped[int(row["Entry"])].append(row)

    for source_id, source_rows in grouped.items():
        source_ids = source_to_object_ids.get(source_id, {source_id}) if source_to_object_ids else {source_id}
        item_chances = resolve_loot_row_chances(source_rows, reference_index)
        for item_id, chance in item_chances.items():
            if item_id in object_primary_items and chance <= LOW_CHANCE_CREATURE_DROP_THRESHOLD:
                continue
            for resolved_source_id in source_ids:
                per_item[item_id].add(resolved_source_id)
    return per_item


def resolve_loot_rows(rows, reference_index, seen=None):
    return set(resolve_loot_row_chances(rows, reference_index, seen))


def resolve_loot_row_chances(rows, reference_index, seen=None, quest_required_only=False):
    seen = seen or set()
    item_chances = defaultdict(float)
    for row in rows:
        chance = float(row.get("Chance") or 0)
        if chance <= 0:
            continue
        if quest_required_only and int(row.get("QuestRequired") or 0) != 1:
            continue
        reference = int(row.get("Reference") or 0)
        item_id = int(row.get("Item") or 0)
        if reference > 0:
            if reference in seen:
                continue
            multiplier = chance / 100.0
            for referenced_item_id, referenced_chance in resolve_loot_row_chances(
                reference_index.get(reference, []),
                reference_index,
                seen | {reference},
                quest_required_only,
            ).items():
                item_chances[referenced_item_id] += referenced_chance * multiplier
        elif item_id > 0:
            item_chances[item_id] += chance
    return item_chances


def build_object_primary_item_ids(gameobject_loot_rows, reference_index):
    object_primary_items = set()
    grouped = defaultdict(list)
    for row in gameobject_loot_rows:
        grouped[int(row["Entry"])].append(row)

    for source_rows in grouped.values():
        for item_id, chance in resolve_loot_row_chances(source_rows, reference_index, quest_required_only=True).items():
            if chance >= OBJECT_LOOT_PRIMARY_CHANCE:
                object_primary_items.add(item_id)

    return object_primary_items


def build_gameobject_loot_source_map(gameobject_template_rows):
    source_map = defaultdict(set)
    for row in gameobject_template_rows.values():
        gameobject_type = int(row.get("type") or 0)
        if gameobject_type not in {3, 25}:
            continue
        loot_id = int(row.get("Data1") or 0)
        if loot_id > 0:
            source_map[loot_id].add(int(row["entry"]))
    return source_map


def build_creature_loot_source_map(creature_template_rows):
    source_map = defaultdict(set)
    for row in creature_template_rows.values():
        loot_id = int(row.get("lootid") or 0)
        if loot_id > 0:
            source_map[loot_id].add(int(row["entry"]))
    return source_map


def add_item_sources_from_spellclick(npc_spellclick_rows, spell_rows):
    per_item = defaultdict(set)
    for row in npc_spellclick_rows:
        npc_id = int(row.get("npc_entry") or 0)
        spell_id = int(row.get("spell_id") or 0)
        if not npc_id or not spell_id:
            continue

        spell = spell_rows.get(spell_id)
        if not spell:
            continue

        for index in range(1, 4):
            item_id = int(spell.get(f"EffectItemType_{index}") or 0)
            if item_id > 0:
                per_item[item_id].add(npc_id)
    return per_item


def build_creature_guid_to_entry(creature_rows):
    mapping = {}
    for row in creature_rows.values():
        guid = row.get("guid")
        entry = row.get("id") or row.get("entry")
        if guid and entry:
            mapping[int(guid)] = int(entry)
    return mapping


def build_spawned_entry_ids(rows, entry_columns):
    spawned_entry_ids = set()
    iterable = rows.values() if isinstance(rows, dict) else rows
    for row in iterable:
        for column in entry_columns:
            entry = int(row.get(column) or 0)
            if entry > 0:
                spawned_entry_ids.add(entry)
    return spawned_entry_ids


def build_acore_items(source_root, include_modules=False):
    source_root = Path(source_root)
    item_rows, skipped_item_template = load_keyed_table(source_root, "item_template", "entry", include_modules)
    quest_rows, skipped_quest_template = load_keyed_table(source_root, "quest_template", "ID", include_modules)
    gameobject_template_rows, skipped_gameobject_template = load_keyed_table(source_root, "gameobject_template", "entry", include_modules)
    creature_template_rows, skipped_creature_template = load_keyed_table(source_root, "creature_template", "entry", include_modules)
    creature_rows, skipped_creature = load_keyed_table(source_root, "creature", "guid", include_modules)
    spell_rows, skipped_spell_dbc = load_keyed_table(source_root, "spell_dbc", "ID", include_modules)

    reference_rows, skipped_reference = load_row_table(source_root, "reference_loot_template", ("Entry", "Item"), include_modules)
    creature_loot_rows, skipped_creature_loot = load_row_table(source_root, "creature_loot_template", ("Entry", "Item"), include_modules)
    gameobject_loot_rows, skipped_gameobject_loot = load_row_table(source_root, "gameobject_loot_template", ("Entry", "Item"), include_modules)
    item_loot_rows, skipped_item_loot = load_row_table(source_root, "item_loot_template", ("Entry", "Item"), include_modules)
    npc_vendor_rows, skipped_npc_vendor = load_row_table(source_root, "npc_vendor", ("entry", "item", "ExtendedCost"), include_modules)
    event_vendor_rows, skipped_event_vendor = load_row_table(source_root, "game_event_npc_vendor", ("eventEntry", "guid", "item"), include_modules)
    npc_spellclick_rows, skipped_npc_spellclick = load_row_table(source_root, "npc_spellclick_spells", ("npc_entry", "spell_id"), include_modules)

    reference_index = defaultdict(list)
    for row in reference_rows:
        reference_index[int(row["Entry"])].append(row)
    object_primary_items = build_object_primary_item_ids(gameobject_loot_rows, reference_index)
    creature_loot_source_map = build_creature_loot_source_map(creature_template_rows)

    acore_items = {}
    for item_id, row in item_rows.items():
        item = {}
        for field, column in STATIC_FIELD_MAP.items():
            value = row.get(column)
            if value is not None:
                item[field] = value

        start_quest = int(row.get("startquest") or 0)
        if start_quest > 0:
            item["startQuest"] = start_quest
        acore_items[int(item_id)] = item

    for field, per_item in (
        (
            "npcDrops",
            add_item_sources_from_loot(
                creature_loot_rows,
                reference_index,
                source_to_object_ids=creature_loot_source_map,
                object_primary_items=object_primary_items,
            ),
        ),
        ("objectDrops", add_item_sources_from_loot(gameobject_loot_rows, reference_index, build_gameobject_loot_source_map(gameobject_template_rows))),
        ("itemDrops", add_item_sources_from_loot(item_loot_rows, reference_index)),
    ):
        for item_id, source_ids in per_item.items():
            acore_items.setdefault(item_id, {})[field] = sorted(source_ids)

    for item_id, source_ids in add_item_sources_from_spellclick(npc_spellclick_rows, spell_rows).items():
        existing_sources = set(acore_items.setdefault(item_id, {}).get("npcDrops") or [])
        existing_sources.update(source_ids)
        acore_items[item_id]["npcDrops"] = sorted(existing_sources)

    for row in npc_vendor_rows:
        item_id = int(row.get("item") or 0)
        vendor_id = int(row.get("entry") or 0)
        if item_id and vendor_id:
            acore_items.setdefault(item_id, {}).setdefault("vendors", set()).add(vendor_id)

    creature_guid_to_entry = build_creature_guid_to_entry(creature_rows)
    for row in event_vendor_rows:
        item_id = int(row.get("item") or 0)
        guid = int(row.get("guid") or 0)
        vendor_id = creature_guid_to_entry.get(guid)
        if item_id and vendor_id:
            acore_items.setdefault(item_id, {}).setdefault("vendors", set()).add(vendor_id)

    for item in acore_items.values():
        if isinstance(item.get("vendors"), set):
            item["vendors"] = sorted(item["vendors"])

    for quest_id, row in quest_rows.items():
        quest_id = int(quest_id)
        for column in ("RewardItem1", "RewardItem2", "RewardItem3", "RewardItem4"):
            item_id = int(row.get(column) or 0)
            if item_id:
                acore_items.setdefault(item_id, {}).setdefault("questRewards", set()).add(quest_id)
        for column in (
            "RewardChoiceItemID1",
            "RewardChoiceItemID2",
            "RewardChoiceItemID3",
            "RewardChoiceItemID4",
            "RewardChoiceItemID5",
            "RewardChoiceItemID6",
        ):
            item_id = int(row.get(column) or 0)
            if item_id:
                acore_items.setdefault(item_id, {}).setdefault("questRewards", set()).add(quest_id)
        for column in (
            "StartItem",
            "ItemDrop1",
            "ItemDrop2",
            "ItemDrop3",
            "ItemDrop4",
            "RequiredItemId1",
            "RequiredItemId2",
            "RequiredItemId3",
            "RequiredItemId4",
            "RequiredItemId5",
            "RequiredItemId6",
        ):
            item_id = int(row.get(column) or 0)
            if item_id:
                acore_items.setdefault(item_id, {}).setdefault("relatedQuests", set()).add(quest_id)
                # Mark items that appear in quest_template.StartItem so we can
                # treat them as quest items even when item_template.class
                # differs in AzerothCore's item_template.
                if column == "StartItem":
                    acore_items.setdefault(item_id, {})["isStartItem"] = True

    for item in acore_items.values():
        for field in ("questRewards", "relatedQuests"):
            if isinstance(item.get(field), set):
                item[field] = sorted(item[field])

    skipped_mutations = {
        "item_template": skipped_item_template,
        "quest_template": skipped_quest_template,
        "gameobject_template": skipped_gameobject_template,
        "creature_template": skipped_creature_template,
        "creature": skipped_creature,
        "spell_dbc": skipped_spell_dbc,
        "reference_loot_template": skipped_reference,
        "creature_loot_template": skipped_creature_loot,
        "gameobject_loot_template": skipped_gameobject_loot,
        "item_loot_template": skipped_item_loot,
        "npc_vendor": skipped_npc_vendor,
        "game_event_npc_vendor": skipped_event_vendor,
        "npc_spellclick_spells": skipped_npc_spellclick,
    }
    source_context = {
        "spawnedCreatureIds": build_spawned_entry_ids(creature_rows, ("id", "entry", "id1", "id2", "id3")),
        "gameObjectTemplateIds": set(gameobject_template_rows),
    }
    return acore_items, skipped_mutations, source_context


def normalize_scalar(field, value):
    if field == "name":
        return value or ""
    if field == "startQuest":
        return int(value or 0)
    return int(value or 0)


def normalize_list(value):
    if not value:
        return ()
    return tuple(sorted({int(v) for v in value if v is not None}))


def correction_value(field, acore_value):
    if field in LIST_FIELDS:
        return list(normalize_list(acore_value))
    if field == "startQuest":
        return int(acore_value or 0)
    if field == "name":
        return acore_value or ""
    return int(acore_value or 0)


def should_preserve_indirect_quest_item_npc_sources(field, questie, acore, questie_base=None):
    if field != "npcDrops":
        return False

    # Some quest items are awarded through scripted interactions rather than a
    # direct creature loot row. AzerothCore's static item/loot tables do not
    # always describe the creature source in that case, but Questie's existing
    # item data may still have the correct map source for that scripted flow.
    if (
        not normalize_list(acore.get("npcDrops"))
        and bool(normalize_list(questie.get("npcDrops")))
        and bool(normalize_list(acore.get("relatedQuests")))
        and not normalize_list(acore.get("objectDrops"))
        and not normalize_list(acore.get("itemDrops"))
    ):
        return True

    has_matching_container_source = (
        not normalize_list(acore.get("npcDrops"))
        and bool(normalize_list(questie.get("npcDrops")))
        and bool(normalize_list(acore.get("relatedQuests")))
        and bool(normalize_list(acore.get("itemDrops")))
        and normalize_list(acore.get("itemDrops")) == normalize_list(questie.get("itemDrops"))
    )
    if not has_matching_container_source:
        return False

    # When AzerothCore identifies a container source but no direct creature
    # source, NPCs inherited from Questie's base DB may be stale. Preserve
    # them only when a manual correction explicitly added or changed them to
    # describe a scripted NPC -> container -> item interaction. If no base
    # row was supplied, retain the old conservative behavior.
    return (
        questie_base is None
        or normalize_list(questie.get("npcDrops")) != normalize_list(questie_base.get("npcDrops"))
    )


def should_preserve_indirect_quest_item_object_sources(field, questie, acore, source_context=None):
    if field != "objectDrops":
        return False

    source_context = source_context or {}
    questie_object_drops = normalize_list(questie.get("objectDrops"))
    gameobject_template_ids = source_context.get("gameObjectTemplateIds")
    if gameobject_template_ids is not None and not set(questie_object_drops).issubset(gameobject_template_ids):
        return False
    spawned_gameobject_ids = source_context.get("spawnedGameObjectIds")
    if spawned_gameobject_ids is not None and not set(questie_object_drops).issubset(spawned_gameobject_ids):
        return False

    acore_npc_drops = normalize_list(acore.get("npcDrops"))
    spawned_creature_ids = source_context.get("spawnedCreatureIds")
    has_mappable_acore_npc_source = (
        bool(acore_npc_drops)
        if spawned_creature_ids is None
        else any(npc_id in spawned_creature_ids for npc_id in acore_npc_drops)
    )

    # Some quest items are obtained via using an item on a gameobject or
    # through scripted interactions where AzerothCore's `gameobject_loot`
    # table does not include a direct mapping. If Questie already has
    # object POIs for such items and AC lists the item as related to a
    # quest, prefer preserving the existing object POIs rather than
    # overriding them with an empty list.
    if (
        not normalize_list(acore.get("objectDrops"))
        and bool(questie_object_drops)
        and (
            bool(normalize_list(acore.get("relatedQuests")))
            or bool(normalize_list(questie.get("relatedQuests")))
        )
        and not has_mappable_acore_npc_source
        and not normalize_list(acore.get("itemDrops"))
    ):
        return True

    return (
        not normalize_list(acore.get("objectDrops"))
        and bool(questie_object_drops)
        and (
            bool(normalize_list(acore.get("relatedQuests")))
            or bool(normalize_list(questie.get("relatedQuests")))
        )
        and bool(normalize_list(acore.get("itemDrops")))
        and normalize_list(acore.get("itemDrops")) == normalize_list(questie.get("itemDrops"))
    )


def find_differences(
    questie_items,
    acore_items,
    fields,
    include_missing_items=False,
    questie_base_items=None,
    extra_item_ids=None,
    startquest_only_ids=None,
    preservations=None,
    source_context=None,
):
    corrections = {}
    ids = set(questie_items)
    if include_missing_items:
        ids |= set(acore_items)
    if extra_item_ids:
        ids |= set(extra_item_ids)

    for item_id in sorted(ids):
        acore = acore_items.get(item_id)
        if not acore:
            continue
        questie = questie_items.get(item_id, {})

        for field in fields:
            if startquest_only_ids and item_id in startquest_only_ids and field != "startQuest":
                continue

            if field in LIST_FIELDS:
                expected = normalize_list(acore.get(field))
                actual = normalize_list(questie.get(field))
            else:
                expected = normalize_scalar(field, acore.get(field))
                actual = normalize_scalar(field, questie.get(field))

            # If AC's quest_template references this item as a StartItem,
            # treat it as a quest item (class 12) regardless of the value in
            # AzerothCore's item_template.class. This ensures items that are
            # handed to the player by a quest get classified as quest items
            # so Questie's runtime behavior (tracker/item buttons) works.
            if field == "class":
                if acore.get("isStartItem") or (acore.get("startQuest") and int(acore.get("startQuest") or 0) > 0):
                    expected = 12

            if expected != actual:
                # Preserve certain indirect sources handled above
                base_item = questie_base_items.get(item_id, {}) if questie_base_items is not None else None
                preserve_npc = should_preserve_indirect_quest_item_npc_sources(field, questie, acore, base_item)
                preserve_object = should_preserve_indirect_quest_item_object_sources(
                    field,
                    questie,
                    acore,
                    source_context,
                )
                if preserve_npc or preserve_object:
                    if preservations is not None:
                        preservations.append({
                            "itemId": item_id,
                            "name": questie.get("name") or acore.get("name") or "",
                            "field": field,
                            "reason": "indirectNpcSource" if preserve_npc else "indirectObjectSource",
                            "questie": list(actual),
                            "acore": list(expected),
                            "base": list(normalize_list((base_item or {}).get(field))),
                            "itemDrops": list(normalize_list(acore.get("itemDrops"))),
                            "relatedQuests": list(normalize_list(acore.get("relatedQuests"))),
                            "spawnedNpcDrops": [
                                npc_id
                                for npc_id in normalize_list(acore.get("npcDrops"))
                                if npc_id in (source_context or {}).get("spawnedCreatureIds", set())
                            ],
                        })
                    continue

                # If the field is 'class' and Questie's value differs from the
                # base wotlkItemDB value (i.e. it was changed by an existing
                # manual correction file such as tbcItemFixes.lua or
                # wotlkItemFixes.lua), prefer preserving that manual fix rather
                # than overwriting it with AzerothCore's value. This avoids the
                # generator undoing intentional quest-item class corrections
                # which can break runtime behavior like tracker item buttons.
                if field == "class" and questie_base_items is not None:
                    base = normalize_scalar(field, questie_base_items.get(item_id, {}).get(field))
                    current = normalize_scalar(field, questie.get(field))
                    if current != base:
                        if preservations is not None:
                            preservations.append({
                                "itemId": item_id,
                                "name": questie.get("name") or acore.get("name") or "",
                                "field": field,
                                "reason": "manualClassOverride",
                                "questie": actual,
                                "acore": expected,
                                "base": base,
                                "itemDrops": list(normalize_list(acore.get("itemDrops"))),
                                "relatedQuests": list(normalize_list(acore.get("relatedQuests"))),
                            })
                        continue

                corrections.setdefault(item_id, {})[field] = correction_value(field, acore.get(field))

    return corrections


def load_item_start_fix_items(repo_root, item_keys):
    path = repo_root / ITEM_START_FIXES_FILE
    if not path.exists():
        return {}
    return load_lua_item_corrections(path, item_keys)


def find_missing_startquest_items(questie_items, acore_items, item_start_fix_items):
    item_ids = set()
    for item_id, acore in acore_items.items():
        start_quest = normalize_scalar("startQuest", acore.get("startQuest"))
        if start_quest <= 0 or item_id in questie_items:
            continue

        current_start_quest = normalize_scalar(
            "startQuest",
            item_start_fix_items.get(item_id, {}).get("startQuest"),
        )
        if current_start_quest != start_quest:
            item_ids.add(item_id)

    return item_ids


def lua_quote(value):
    return ast.literal_eval(repr(value)).replace("\\", "\\\\").replace('"', '\\"')


def format_lua_value(value):
    if isinstance(value, str):
        return f'"{lua_quote(value)}"'
    if isinstance(value, list):
        return "{" + ",".join(str(int(item)) for item in value) + "}"
    if isinstance(value, int):
        return str(value)
    raise TypeError(f"Unsupported Lua value: {value!r}")


def validate_lua_fragment(fragment, label):
    balance = 0
    in_string = None
    escaped = False
    for line_number, line in enumerate(fragment.splitlines(), start=1):
        index = 0
        while index < len(line):
            char = line[index]
            if in_string:
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
                    raise ValueError(f"{label} has unmatched closing brace on line {line_number}")
            index += 1
    if balance != 0:
        raise ValueError(f"{label} has unbalanced braces ({balance:+d})")


def write_corrections_module(corrections, output_path):
    lines = [
        "---@type QuestieDB",
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")',
        "",
        "if QuestieCompat.WOW_PROJECT_ID < QuestieCompat.WOW_PROJECT_WRATH_CLASSIC then return end",
        "",
        "-- Generated from tools/generate_acore_item_corrections.py.",
        "-- Regenerate this file when AzerothCore item data changes.",
        "",
        'QuestieCompat.RegisterCorrection("itemData", function()',
        "    local itemKeys = QuestieDB.itemKeys",
        "",
        "    return {",
    ]

    for item_id in sorted(corrections):
        lines.append(f"        [{item_id}] = {{")
        fields = corrections[item_id]
        for field in FIELD_ORDER:
            if field not in fields:
                continue
            lines.append(f"            [itemKeys.{field}] = {format_lua_value(fields[field])},")
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


def write_report(corrections, skipped_mutations, report_path):
    counts = defaultdict(int)
    for fields in corrections.values():
        for field in fields:
            counts[field] += 1
    lines = [
        "# AzerothCore Item Corrections Report",
        "",
        f"Items with corrections: {len(corrections)}",
        "",
        "| Field | Corrections |",
        "| --- | ---: |",
    ]
    for field in FIELD_ORDER:
        if counts[field]:
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
    lines.append("")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")


def write_preservation_report(preservations, report_path):
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(preservations, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Generate Questie itemData corrections from AzerothCore 3.3.5 SQL data.")
    parser.add_argument("--acore-source", default=r"P:\AC\source", type=Path)
    parser.add_argument("--repo-root", default=Path("."), type=Path)
    parser.add_argument("--output", default=Path("Compat/AzerothCoreItemCorrections.lua"), type=Path)
    parser.add_argument("--report", default=Path("tools/reports/acore_item_corrections.md"), type=Path)
    parser.add_argument("--preservation-report", default=Path("tools/reports/acore_item_preservations.json"), type=Path)
    parser.add_argument("--include-modules", action="store_true", help="Also scan SQL under AzerothCore modules/. This can be slow.")
    parser.add_argument(
        "--fields",
        nargs="+",
        default=FIELD_ORDER,
        choices=FIELD_ORDER,
        help="Questie item fields to compare and generate.",
    )
    parser.add_argument("--include-missing-items", action="store_true", help="Generate corrections for item IDs missing from Questie.")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    item_keys = parse_item_keys(repo_root / "Database/Wotlk/wotlkItemDB.lua")
    # Load the base Questie WotLK item DB (before applying local correction files)
    questie_base_items = load_questie_items(repo_root / "Database/Wotlk/wotlkItemDB.lua", item_keys)
    # Load the effective Questie items after applying classic/tbc/wotlk corrections
    questie_items = load_effective_questie_items(repo_root, item_keys)
    item_start_fix_items = load_item_start_fix_items(repo_root, item_keys)
    acore_items, skipped_mutations, source_context = build_acore_items(args.acore_source, args.include_modules)
    missing_startquest_items = find_missing_startquest_items(questie_items, acore_items, item_start_fix_items)
    comparison_items = dict(questie_items)
    for item_id in missing_startquest_items:
        if item_id in item_start_fix_items:
            comparison_items[item_id] = item_start_fix_items[item_id]

    preservations = []
    corrections = find_differences(
        comparison_items,
        acore_items,
        args.fields,
        args.include_missing_items,
        questie_base_items,
        extra_item_ids=missing_startquest_items,
        startquest_only_ids=missing_startquest_items if not args.include_missing_items else None,
        preservations=preservations,
        source_context=source_context,
    )

    write_corrections_module(corrections, repo_root / args.output)
    write_report(corrections, skipped_mutations, repo_root / args.report)
    write_preservation_report(preservations, repo_root / args.preservation_report)

    print(f"Wrote {len(corrections)} item corrections to {repo_root / args.output}")
    print(f"Recorded {len(preservations)} preserved differences in {repo_root / args.preservation_report}")
    skipped = {table: count for table, count in skipped_mutations.items() if count}
    if skipped:
        print(f"Skipped complex SQL mutations: {skipped}")


if __name__ == "__main__":
    main()
