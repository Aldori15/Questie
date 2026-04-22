import argparse
import ast
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


QUESTIE_FIX_FILES = [
    "Database/Corrections/classicQuestFixes.lua",
    "Database/Corrections/tbcQuestFixes.lua",
    "Database/Corrections/wotlkQuestFixes.lua",
]

QUESTIE_RUNTIME_FLAGS = {
    "Questie.IsEra": False,
    "Questie.IsClassic": False,
    "Questie.IsTBC": False,
    "Questie.IsWotlk": True,
    "QuestieCompat.Is335": True,
    "VANILLA": False,
}

FIELD_ORDER = [
    "questLevel",
    "requiredLevel",
    "requiredRaces",
    "requiredClasses",
    "objectivesText",
    "objectives",
    "sourceItemId",
    "requiredSourceItems",
    "requiredSkill",
    "requiredMinRep",
    "requiredMaxRep",
    "preQuestSingle",
    "parentQuest",
    "exclusiveTo",
    "nextQuestInChain",
    "breadcrumbForQuestId",
    "breadcrumbs",
    "requiredMaxLevel",
    "questFlags",
    "specialFlags",
]

FIELD_KIND = {
    "questLevel": "int",
    "requiredLevel": "int",
    "requiredRaces": "int",
    "requiredClasses": "int",
    "objectivesText": "text_list",
    "objectives": "objectives",
    "sourceItemId": "int",
    "requiredSourceItems": "list",
    "requiredSkill": "pair",
    "requiredMinRep": "rep",
    "requiredMaxRep": "rep",
    "preQuestSingle": "list",
    "parentQuest": "int",
    "exclusiveTo": "list",
    "nextQuestInChain": "int",
    "breadcrumbForQuestId": "int",
    "breadcrumbs": "list",
    "requiredMaxLevel": "int",
    "questFlags": "int",
    "specialFlags": "int",
}

EMPTY_OBJECTIVES = ((), (), ())

QUEST_KEY_RE = re.compile(r"\['([^']+)'\]\s*=\s*(\d+)")
TABLE_ENTRY_RE = re.compile(r"^([A-Za-z0-9_]+)\s*=\s*(.+)$", re.DOTALL)
QUEST_ROW_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\}),?$", re.DOTALL)
QUEST_FIELD_RE = re.compile(r"^\[questKeys\.([A-Za-z0-9_]+)\]\s*=\s*(.+)$", re.DOTALL)
QUESTIE_ICON_TYPE_RE = re.compile(r"Questie\.(ICON_TYPE_[A-Za-z0-9_]+)\s*=\s*(-?\d+)")


def strip_lua_comments(text):
    result = []
    index = 0
    in_string = False
    quote = ""
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
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
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


def strip_sql_comments(text):
    result = []
    index = 0
    in_string = False
    quote = ""
    escaped = False
    in_block_comment = False

    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""

        if in_block_comment:
            if char == "*" and nxt == "/":
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue

        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
            result.append(char)
            index += 1
            continue

        if char == "-" and nxt == "-":
            index += 2
            while index < len(text) and text[index] != "\n":
                index += 1
            continue

        if char == "#":
            index += 1
            while index < len(text) and text[index] != "\n":
                index += 1
            continue

        if char == "/" and nxt == "*":
            in_block_comment = True
            index += 2
            continue

        result.append(char)
        index += 1

    return "".join(result)


def extract_braced_block(text, marker):
    match = re.search(rf"{re.escape(marker)}\s*=\s*\{{", text)
    if not match:
        raise ValueError(f"Could not find table marker: {marker}")

    open_brace = text.find("{", match.end() - 1)
    if open_brace == -1:
        raise ValueError(f"Could not find opening brace for table: {marker}")

    depth = 0
    in_string = False
    quote = ""
    escaped = False

    for index in range(open_brace, len(text)):
        char = text[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace + 1 : index]

    raise ValueError(f"Could not extract table body for {marker}")


def split_top_level_lua_table(lua_table):
    text = lua_table.strip()
    if not text.startswith("{") or not text.endswith("}"):
        raise ValueError("Expected a Lua table literal")

    items = []
    depth = 0
    start = 1
    index = 1
    in_string = False
    quote = ""
    escaped = False

    while index < len(text) - 1:
        char = text[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
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


def split_sql_values(row_text):
    items = []
    depth = 0
    start = 0
    index = 0
    in_string = False
    quote = ""
    escaped = False

    while index < len(row_text):
        char = row_text[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            items.append(row_text[start:index].strip())
            start = index + 1
        index += 1

    tail = row_text[start:].strip()
    if tail:
        items.append(tail)

    return items


def split_sql_rows(values_text):
    rows = []
    depth = 0
    start = None
    index = 0
    in_string = False
    quote = ""
    escaped = False

    while index < len(values_text):
        char = values_text[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
        elif char == "(":
            if depth == 0:
                start = index + 1
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0 and start is not None:
                rows.append(values_text[start:index])
                start = None

        index += 1

    return rows


def split_sql_statements(sql_text):
    statements = []
    start = 0
    index = 0
    in_string = False
    quote = ""
    escaped = False

    while index < len(sql_text):
        char = sql_text[index]

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
        else:
            if char in ('"', "'"):
                in_string = True
                quote = char
            elif char == ";":
                statement = sql_text[start:index].strip()
                if statement:
                    statements.append(statement)
                start = index + 1

        index += 1

    tail = sql_text[start:].strip()
    if tail:
        statements.append(tail)

    return statements


def parse_lua_string(token):
    return ast.literal_eval(token)


def _eval_ast(node):
    if isinstance(node, ast.Constant):
        return node.value

    if isinstance(node, ast.UnaryOp):
        operand = _eval_ast(node.operand)
        if isinstance(node.op, ast.UAdd):
            return +operand
        if isinstance(node.op, ast.USub):
            return -operand
        if isinstance(node.op, ast.Not):
            return not operand
        if isinstance(node.op, ast.Invert):
            return ~operand

    if isinstance(node, ast.BinOp):
        left = _eval_ast(node.left)
        right = _eval_ast(node.right)
        if isinstance(node.op, ast.Add):
            return left + right
        if isinstance(node.op, ast.Sub):
            return left - right
        if isinstance(node.op, ast.Mult):
            return left * right
        if isinstance(node.op, ast.Div):
            return left / right
        if isinstance(node.op, ast.FloorDiv):
            return left // right
        if isinstance(node.op, ast.Mod):
            return left % right
        if isinstance(node.op, ast.BitOr):
            return left | right
        if isinstance(node.op, ast.BitAnd):
            return left & right
        if isinstance(node.op, ast.BitXor):
            return left ^ right
        if isinstance(node.op, ast.LShift):
            return left << right
        if isinstance(node.op, ast.RShift):
            return left >> right

    if isinstance(node, ast.BoolOp):
        values = [_eval_ast(value) for value in node.values]
        if isinstance(node.op, ast.And):
            result = values[0]
            for value in values[1:]:
                result = result and value
            return result
        if isinstance(node.op, ast.Or):
            result = values[0]
            for value in values[1:]:
                result = result or value
            return result

    raise ValueError(f"Unsupported expression node: {ast.dump(node, include_attributes=False)}")


def replace_constant_refs(expr, constants):
    def replace_match(match):
        alias = match.group(1)
        name = match.group(2)
        value = constants.get(alias, {}).get(name)
        if value is None and alias not in constants:
            raise KeyError(f"Unknown constant reference {alias}.{name}")
        if isinstance(value, bool):
            return "True" if value else "False"
        return str(value)

    return re.sub(r"\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\b", replace_match, expr)


def safe_eval_scalar(expr, constants):
    token = expr.strip()
    if not token:
        return None

    if token in {"nil", "None"}:
        return None
    if token in {"true", "True"}:
        return True
    if token in {"false", "False"}:
        return False
    if token[0] in {'"', "'"} and token[-1] == token[0]:
        return parse_lua_string(token)

    token = token.replace("Questie.IsEra", "False")
    token = token.replace("Questie.IsClassic", "False")
    token = token.replace("Questie.IsTBC", "False")
    token = token.replace("Questie.IsWotlk", "True")
    token = token.replace("QuestieCompat.Is335", "True")
    token = re.sub(r"\bVANILLA\b", "False", token)
    token = replace_constant_refs(token, constants)

    l10n_match = re.fullmatch(r"l10n\((.*)\)", token, re.DOTALL)
    if l10n_match:
        string_token = l10n_match.group(1).strip()
        if string_token and string_token[0] in {'"', "'"} and string_token[-1] == string_token[0]:
            return parse_lua_string(string_token)
        raise ValueError(f"Unsupported l10n expression: {expr}")

    token = re.sub(r"\bnil\b", "None", token)
    token = re.sub(r"\btrue\b", "True", token)
    token = re.sub(r"\bfalse\b", "False", token)

    node = ast.parse(token, mode="eval")
    return _eval_ast(node.body)


def parse_lua_value(token, constants):
    value = token.strip()
    if not value:
        return None
    if value.startswith("{") and value.endswith("}"):
        return [parse_lua_value(item, constants) for item in split_top_level_lua_table(value)]
    return safe_eval_scalar(value, constants)


def load_constant_table(path, table_marker, constants=None, manual_values=None):
    constants = constants or {}
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    body = extract_braced_block(text, table_marker)
    parsed = {}

    for raw_line in body.splitlines():
        line = raw_line.strip().rstrip(",")
        if not line or line.startswith("--"):
            continue

        match = TABLE_ENTRY_RE.match(line)
        if not match:
            continue

        key = match.group(1)
        expr = match.group(2).strip()
        if expr.startswith("(function()"):
            continue

        parsed[key] = safe_eval_scalar(expr, constants)

    if manual_values:
        parsed.update(manual_values)

    return parsed


def load_quest_keys(path):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    body = extract_braced_block(text, "QuestieDB.questKeys")
    quest_keys = {}
    for match in QUEST_KEY_RE.finditer(body):
        quest_keys[match.group(1)] = int(match.group(2))
    return quest_keys


def load_questie_icon_types(path):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    icon_types = {}
    for match in QUESTIE_ICON_TYPE_RE.finditer(text):
        icon_types[match.group(1)] = int(match.group(2))
    return icon_types


def load_constants(addon_root):
    questie_db_path = addon_root / "Database" / "QuestieDB.lua"
    questie_quest_db_path = addon_root / "Database" / "questDB.lua"
    questie_root_path = addon_root / "Questie.lua"
    professions_path = addon_root / "Modules" / "QuestieProfessions.lua"
    zone_ids_path = addon_root / "Database" / "Zones" / "zoneTables.lua"

    quest_keys = load_quest_keys(questie_quest_db_path)
    questie_icons = load_questie_icon_types(questie_root_path)
    zone_ids = load_constant_table(zone_ids_path, "ZoneDB.private.zoneIDs")
    faction_ids = load_constant_table(questie_quest_db_path, "QuestieDB.factionIDs")
    quest_flags = load_constant_table(questie_quest_db_path, "QuestieDB.questFlags")
    special_flags = load_constant_table(questie_db_path, "QuestieDB.specialFlags")

    race_ids = load_constant_table(
        questie_db_path,
        "QuestieDB.raceKeys",
        constants={"VANILLA": False},
    )
    class_ids = load_constant_table(
        questie_db_path,
        "QuestieDB.classKeys",
        manual_values={"ALL_CLASSES": 1535},
    )

    profession_keys = load_constant_table(professions_path, "QuestieProfessions.professionKeys")
    rank_keys = load_constant_table(professions_path, "QuestieProfessions.rankNames")

    return {
        "quest_keys": quest_keys,
        "zoneIDs": zone_ids,
        "Questie": questie_icons,
        "raceIDs": race_ids,
        "classIDs": class_ids,
        "factionIDs": faction_ids,
        "profKeys": profession_keys,
        "rankKeys": rank_keys,
        "questFlags": quest_flags,
        "specialFlags": special_flags,
    }


def resolve_addon_path(addon_root, path_value):
    path = Path(path_value)
    if path.is_absolute():
        return path
    return addon_root / path


def normalize_int(value):
    if value is None or value is False or value == []:
        return 0
    if isinstance(value, bool):
        return int(value)
    return int(value)


def normalize_list(value):
    if value is None or value is False:
        return ()

    flattened = []

    def collect(item):
        if item is None or item is False or item == 0:
            return
        if isinstance(item, (list, tuple, set)):
            for nested in item:
                collect(nested)
            return
        flattened.append(int(item))

    collect(value)
    return tuple(sorted(set(flattened)))


def normalize_pair(value):
    if value is None or value is False:
        return ()
    if not isinstance(value, (list, tuple)):
        if value == 0:
            return ()
        return (int(value), 0)

    pair = [int(item) for item in value if item is not None and item is not False]
    if not pair:
        return ()
    if len(pair) == 1:
        pair.append(0)
    pair = pair[:2]
    if pair[0] == 0 and pair[1] == 0:
        return ()
    return tuple(pair)


def normalize_text_list(value):
    if value is None or value is False:
        return ()

    flattened = []

    def collect(item, from_sequence=False):
        if item is None or item is False:
            return
        if isinstance(item, (list, tuple, set)):
            for nested in item:
                collect(nested, from_sequence=True)
            return

        text = str(item)
        if not text:
            if from_sequence:
                flattened.append("")
            return

        text = text.replace("$B$B", "\n\n").replace("$B", "\n")
        flattened.extend(text.splitlines())

    collect(value)
    return tuple(flattened)


def normalize_objectives(value):
    if value is None or value is False:
        return EMPTY_OBJECTIVES
    if not isinstance(value, (list, tuple)):
        return EMPTY_OBJECTIVES

    normalized_categories = []
    for category_index in range(3):
        category_value = value[category_index] if category_index < len(value) else None
        if category_value is None or category_value is False:
            normalized_categories.append(())
            continue

        if not isinstance(category_value, (list, tuple, set)):
            category_value = [category_value]

        records = []
        for record in category_value:
            if record is None or record is False:
                continue
            if isinstance(record, (list, tuple, set)):
                ids = normalize_list(record[0] if record else None)
            else:
                ids = normalize_list(record)
            if ids:
                records.append(ids)

        normalized_categories.append(tuple(records))

    return tuple(normalized_categories)


def build_acore_objectives(row):
    creature_objectives = []
    object_objectives = []
    item_objectives = []

    for index in range(1, 5):
        entry = normalize_int(row.get(f"RequiredNpcOrGo{index}"))
        if entry > 0:
            creature_objectives.append((entry,))
        elif entry < 0:
            object_objectives.append((abs(entry),))

    for index in range(1, 7):
        entry = normalize_int(row.get(f"RequiredItemId{index}"))
        if entry > 0:
            item_objectives.append((entry,))

    return normalize_objectives([creature_objectives, object_objectives, item_objectives])


def normalize_field(field, value):
    kind = FIELD_KIND[field]
    if kind == "int":
        return normalize_int(value)
    if kind == "list":
        return normalize_list(value)
    if kind == "pair":
        return normalize_pair(value)
    if kind == "rep":
        return normalize_pair(value)
    if kind == "text_list":
        return normalize_text_list(value)
    if kind == "objectives":
        return normalize_objectives(value)
    raise ValueError(f"Unknown field kind: {kind}")


def default_field_value(field):
    kind = FIELD_KIND[field]
    if kind == "int":
        return 0
    if kind == "objectives":
        return EMPTY_OBJECTIVES
    return ()


def lua_string_literal(value):
    escaped = []
    for char in value:
        if char == "\\":
            escaped.append("\\\\")
        elif char == '"':
            escaped.append("\\\"")
        elif char == "\a":
            escaped.append("\\a")
        elif char == "\b":
            escaped.append("\\b")
        elif char == "\f":
            escaped.append("\\f")
        elif char == "\n":
            escaped.append("\\n")
        elif char == "\r":
            escaped.append("\\r")
        elif char == "\t":
            escaped.append("\\t")
        elif char == "\v":
            escaped.append("\\v")
        elif ord(char) < 32 or ord(char) == 127:
            escaped.append(f"\\{ord(char):03d}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def format_objectives_value(value):
    categories = list(value or ())
    if categories:
        last_non_empty = -1
        for index, category in enumerate(categories[:3]):
            if category:
                last_non_empty = index

        if last_non_empty >= 0:
            parts = []
            for index in range(last_non_empty + 1):
                category = categories[index] if index < len(categories) else ()
                if not category:
                    parts.append("nil")
                    continue

                records = []
                for record in category:
                    if not record:
                        continue
                    records.append("{" + ",".join(str(int(item)) for item in record) + "}")
                parts.append("{" + ",".join(records) + "}")

            return "{" + ",".join(parts) + "}"

    return "nil"


def get_sql_row_key(row, key_column):
    for candidate in (key_column, key_column.lower(), key_column.upper()):
        value = row.get(candidate)
        if value not in (None, ""):
            return int(value)
    return 0


def extract_return_table(lua_text):
    start = lua_text.find("return {")
    if start == -1:
        raise ValueError("Could not find return table")

    index = start + len("return ")
    depth = 0
    in_string = False
    quote = ""
    escaped = False

    while index < len(lua_text):
        char = lua_text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ('"', "'"):
            in_string = True
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return lua_text[start + len("return ") : index + 1]
        index += 1

    raise ValueError("Could not extract return table")


def load_questie_base_metadata(quest_db_path, quest_keys, constants):
    data = {}
    text = quest_db_path.read_text(encoding="utf-8")

    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = QUEST_ROW_RE.match(line)
        if not match:
            continue

        quest_id = int(match.group(1))
        row_values = split_top_level_lua_table(match.group(2))
        quest_entry = {}

        for field in FIELD_ORDER:
            index = quest_keys.get(field)
            if index is None:
                continue

            row_index = index - 1
            if row_index >= len(row_values):
                quest_entry[field] = default_field_value(field)
                continue

            value = parse_lua_value(row_values[row_index], constants)
            quest_entry[field] = normalize_field(field, value)

        data[quest_id] = quest_entry

    return data


def load_questie_correction_file(path, constants):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    return_table = extract_return_table(text)
    overrides = {}

    for entry in split_top_level_lua_table(return_table):
        match = QUEST_ROW_RE.match(entry.strip())
        if not match:
            continue

        quest_id = int(match.group(1))
        body = match.group(2)
        quest_override = overrides.setdefault(quest_id, {})

        for field_entry in split_top_level_lua_table(body):
            field_match = QUEST_FIELD_RE.match(field_entry.strip())
            if not field_match:
                continue

            field_name = field_match.group(1)
            if field_name not in FIELD_KIND:
                continue

            value = parse_lua_value(field_match.group(2), constants)
            if value is None:
                continue

            quest_override[field_name] = normalize_field(field_name, value)

    return overrides


def apply_questie_overrides(questie_data, overrides):
    for quest_id, quest_override in overrides.items():
        quest_entry = questie_data.setdefault(
            quest_id,
            {field: default_field_value(field) for field in FIELD_ORDER},
        )
        for field, value in quest_override.items():
            quest_entry[field] = value


def extract_sql_columns(path, table_name):
    text = strip_sql_comments(path.read_text(encoding="utf-8"))
    match = re.search(
        rf"CREATE TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+`?{re.escape(table_name)}`?\s*\((?P<body>.*?)\)\s*ENGINE",
        text,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        raise ValueError(f"Could not find CREATE TABLE for {table_name} in {path}")

    columns = []
    for raw_line in match.group("body").splitlines():
        line = raw_line.strip().rstrip(",")
        if not line.startswith("`"):
            continue
        column_match = re.match(r"`([^`]+)`\s+", line)
        if column_match:
            columns.append(column_match.group(1))
    return columns


def parse_sql_value(token, context=None):
    value = token.strip()
    if not value or value.upper() == "NULL":
        return None

    if value[0] in {'"', "'"} and value[-1] == value[0]:
        return ast.literal_eval(value)

    if context:
        value = value.replace("`", "")
        for name in sorted(context, key=len, reverse=True):
            replacement = context[name]
            if isinstance(replacement, bool):
                replacement = int(replacement)
            if replacement is None:
                replacement = 0
            if isinstance(replacement, (list, tuple, dict)):
                continue
            value = re.sub(rf"\b{re.escape(name)}\b", str(replacement), value, flags=re.IGNORECASE)

    value = re.sub(r"\bNULL\b", "None", value, flags=re.IGNORECASE)
    value = re.sub(r"\bTRUE\b", "True", value, flags=re.IGNORECASE)
    value = re.sub(r"\bFALSE\b", "False", value, flags=re.IGNORECASE)
    node = ast.parse(value, mode="eval")
    return _eval_ast(node.body)


def apply_sql_insert(statement, table_name, columns, rows, key_column="ID"):
    insert_match = re.search(
        rf"(?:INSERT INTO|REPLACE INTO)\s+`?{re.escape(table_name)}`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not insert_match:
        return

    statement_columns = columns
    if insert_match.group("columns"):
        statement_columns = [
            column_match.group(1)
            for column_match in re.finditer(r"`([^`]+)`", insert_match.group("columns"))
        ]

    for row_text in split_sql_rows(insert_match.group("values")):
        row_values = split_sql_values(row_text)
        if len(row_values) != len(statement_columns):
            continue

        row = {}
        for column_name, raw_value in zip(statement_columns, row_values):
            row[column_name] = parse_sql_value(raw_value)

        quest_id = get_sql_row_key(row, key_column)
        if quest_id:
            rows[quest_id] = row

def apply_sql_update(statement, table_name, rows, key_column="ID"):
    update_match = re.search(
        rf"UPDATE\s+`?{re.escape(table_name)}`?\s+SET\s+(?P<set>.*?)\s+WHERE\s+(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not update_match:
        return

    where_clause = update_match.group("where")
    key_pattern = re.escape(key_column)
    id_matches = re.findall(
        rf"`?{key_pattern}`?\s+IN\s*\(([^)]+)\)|`?{key_pattern}`?\s*=\s*(-?\d+)",
        where_clause,
        re.IGNORECASE,
    )
    ids = set()
    for in_values, single_value in id_matches:
        if in_values:
            ids.update(int(part.strip()) for part in in_values.split(",") if part.strip())
        elif single_value:
            ids.add(int(single_value))

    if not ids:
        return

    assignments = split_sql_values(update_match.group("set"))

    for quest_id in ids:
        row = rows.setdefault(quest_id, {key_column: quest_id})
        context = {
            key: value
            for key, value in row.items()
            if not isinstance(value, (list, tuple, dict))
        }

        for assignment in assignments:
            assign_match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(.+)$", assignment.strip(), re.DOTALL)
            if not assign_match:
                continue

            column = assign_match.group(1)
            expr = assign_match.group(2).strip()
            current_value = row.get(column)
            if column in context:
                context[column] = current_value if current_value is not None else 0

            try:
                row[column] = parse_sql_value(expr, context)
            except Exception:
                continue


def apply_sql_delete(statement, table_name, rows, key_column="ID"):
    delete_match = re.search(
        rf"DELETE FROM\s+`?{re.escape(table_name)}`?\s+WHERE\s+(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not delete_match:
        return

    where_clause = delete_match.group("where")
    ids = set()
    key_pattern = re.escape(key_column)
    for in_values, single_value in re.findall(
        rf"`?{key_pattern}`?\s+IN\s*\(([^)]+)\)|`?{key_pattern}`?\s*=\s*(-?\d+)",
        where_clause,
        re.IGNORECASE,
    ):
        if in_values:
            ids.update(int(part.strip()) for part in in_values.split(",") if part.strip())
        elif single_value:
            ids.add(int(single_value))

    for quest_id in ids:
        rows.pop(quest_id, None)


def load_acore_sql_table(source_root, table_name, base_file_override=None, key_column="ID"):
    if base_file_override:
        base_file = Path(base_file_override)
        updates_dir = None
        module_sql_roots = []
    else:
        base_file = source_root / "data" / "sql" / "base" / "db_world" / f"{table_name}.sql"
        updates_dir = source_root / "data" / "sql" / "updates" / "db_world"
        module_sql_roots = []
        modules_dir = source_root / "modules"
        if modules_dir.exists():
            for module_dir in sorted((path for path in modules_dir.iterdir() if path.is_dir()), key=lambda path: path.name.lower()):
                for relative_root in ("data/sql/world/base", "data/sql/world/updates"):
                    sql_root = module_dir / relative_root
                    if sql_root.exists():
                        module_sql_roots.append(sql_root)

    columns = extract_sql_columns(base_file, table_name)
    rows = {}
    apply_insert = apply_sql_insert
    apply_update = apply_sql_update
    apply_delete = apply_sql_delete

    def apply_file(path):
        text = strip_sql_comments(path.read_text(encoding="utf-8"))
        for statement in split_sql_statements(text):
            if not re.search(rf"\b{re.escape(table_name)}\b", statement, re.IGNORECASE):
                continue
            if statement.upper().startswith(("INSERT INTO", "REPLACE INTO")):
                apply_insert(statement, table_name, columns, rows, key_column)
            elif statement.upper().startswith("UPDATE"):
                apply_update(statement, table_name, rows, key_column)
            elif statement.upper().startswith("DELETE FROM"):
                apply_delete(statement, table_name, rows, key_column)

    apply_file(base_file)
    if updates_dir:
        for update_file in sorted(updates_dir.glob("*.sql")):
            apply_file(update_file)
    for sql_root in module_sql_roots:
        for sql_file in sorted(sql_root.rglob("*.sql"), key=lambda path: str(path).lower()):
            apply_file(sql_file)

    return rows


def derive_acore_metadata(source_root, quest_template_sql=None, quest_template_addon_sql=None):
    quest_rows = load_acore_sql_table(source_root, "quest_template", quest_template_sql)
    addon_rows = load_acore_sql_table(source_root, "quest_template_addon", quest_template_addon_sql)

    quest_ids = set(quest_rows) | set(addon_rows)
    combined_rows = {}
    prereq_sets = defaultdict(set)
    parent_quests = defaultdict(set)
    exclusive_groups = defaultdict(set)
    breadcrumbs_for = defaultdict(set)

    for quest_id in quest_ids:
        base_row = quest_rows.get(quest_id, {})
        addon_row = addon_rows.get(quest_id, {})
        row = dict(base_row)
        row.update(addon_row)
        combined_rows[quest_id] = row

        prev_quest = int(row.get("PrevQuestID") or row.get("PrevQuestId") or 0)
        if prev_quest > 0:
            prereq_sets[quest_id].add(prev_quest)
        elif prev_quest < 0:
            parent_quests[quest_id].add(abs(prev_quest))

        next_quest = int(row.get("NextQuestID") or row.get("NextQuestId") or 0)
        if next_quest > 0:
            prereq_sets[next_quest].add(quest_id)

        exclusive_group = int(row.get("ExclusiveGroup") or 0)
        if exclusive_group > 0:
            exclusive_groups[exclusive_group].add(quest_id)

        breadcrumb_for = int(row.get("BreadcrumbForQuestId") or 0)
        if breadcrumb_for > 0:
            breadcrumbs_for[breadcrumb_for].add(quest_id)

    acore_metadata = {}
    for quest_id, row in combined_rows.items():
        metadata = {field: default_field_value(field) for field in FIELD_ORDER}

        metadata["questLevel"] = normalize_int(row.get("QuestLevel"))
        metadata["requiredLevel"] = normalize_int(row.get("MinLevel"))
        metadata["requiredRaces"] = normalize_int(row.get("AllowableRaces"))
        metadata["requiredClasses"] = normalize_int(row.get("AllowableClasses"))
        metadata["objectivesText"] = normalize_text_list(row.get("LogDescription"))
        metadata["objectives"] = build_acore_objectives(row)
        metadata["sourceItemId"] = normalize_int(row.get("StartItem"))
        metadata["requiredSourceItems"] = normalize_list(
            [
                row.get("ItemDrop1"),
                row.get("ItemDrop2"),
                row.get("ItemDrop3"),
                row.get("ItemDrop4"),
            ]
        )
        metadata["requiredSkill"] = normalize_pair(
            [
                row.get("RequiredSkillID"),
                row.get("RequiredSkillPoints"),
            ]
        )
        metadata["requiredMinRep"] = normalize_pair(
            [
                row.get("RequiredMinRepFaction"),
                row.get("RequiredMinRepValue"),
            ]
        )
        metadata["requiredMaxRep"] = normalize_pair(
            [
                row.get("RequiredMaxRepFaction"),
                row.get("RequiredMaxRepValue"),
            ]
        )
        metadata["preQuestSingle"] = normalize_list(prereq_sets.get(quest_id, set()))
        metadata["parentQuest"] = normalize_int(next(iter(parent_quests.get(quest_id, set())), 0))
        exclusive_group = int(row.get("ExclusiveGroup") or 0)
        if exclusive_group > 0:
            metadata["exclusiveTo"] = normalize_list(sorted(exclusive_groups[exclusive_group] - {quest_id}))
        metadata["nextQuestInChain"] = normalize_int(row.get("RewardNextQuest"))
        metadata["breadcrumbForQuestId"] = normalize_int(row.get("BreadcrumbForQuestId"))
        metadata["breadcrumbs"] = normalize_list(breadcrumbs_for.get(quest_id, set()))
        metadata["requiredMaxLevel"] = normalize_int(row.get("MaxLevel"))
        metadata["questFlags"] = normalize_int(row.get("Flags"))
        metadata["specialFlags"] = normalize_int(row.get("SpecialFlags"))

        acore_metadata[quest_id] = metadata

    return acore_metadata


def compare_metadata(acore_metadata, questie_metadata):
    mismatches = []
    all_quest_ids = sorted(set(acore_metadata) | set(questie_metadata))
    summary = Counter()

    empty_entry = {field: default_field_value(field) for field in FIELD_ORDER}

    for quest_id in all_quest_ids:
        acore = acore_metadata.get(quest_id, empty_entry)
        questie = questie_metadata.get(quest_id, empty_entry)

        for field in FIELD_ORDER:
            if acore[field] != questie[field]:
                mismatches.append(
                    {
                        "questId": quest_id,
                        "field": field,
                        "acore": acore[field],
                        "questie": questie[field],
                    }
                )
                summary[field] += 1

    return mismatches, summary


def format_lua_value(field, value):
    kind = FIELD_KIND[field]
    if kind == "int":
        return str(normalize_int(value))
    if kind == "rep":
        if not value:
            return "false"
        return "{" + ",".join(str(part) for part in value) + "}"
    if kind == "text_list":
        if not value:
            return "{}"
        return "{" + ",".join(lua_string_literal(str(part)) for part in value) + "}"
    if kind == "objectives":
        return format_objectives_value(value)
    if kind in {"list", "pair"}:
        if not value:
            return "{}"
        return "{" + ",".join(str(part) for part in value) + "}"
    raise ValueError(f"Unsupported field kind: {kind}")


def build_lua_suggestions(mismatches, acore_metadata):
    by_quest = defaultdict(dict)
    empty_entry = {field: default_field_value(field) for field in FIELD_ORDER}

    for mismatch in mismatches:
        by_quest[mismatch["questId"]][mismatch["field"]] = acore_metadata.get(
            mismatch["questId"],
            empty_entry,
        )[mismatch["field"]]

    lines = [
        "-- REVIEW BEFORE APPLYING.",
        "-- Generated from AzerothCore quest_template and quest_template_addon metadata.",
        "-- This fragment should be wrapped by the metadata generator into a QuestieCompat.RegisterCorrection module.",
        "",
    ]

    for quest_id in sorted(by_quest):
        lines.append(f"[{quest_id}] = {{")
        for field in FIELD_ORDER:
            if field not in by_quest[quest_id]:
                continue
            lines.append(f"    [questKeys.{field}] = {format_lua_value(field, by_quest[quest_id][field])},")
        lines.append("},")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def build_summary(mismatches):
    summary = {"total": len(mismatches)}
    for field in FIELD_ORDER:
        summary[field] = 0

    for mismatch in mismatches:
        summary[mismatch["field"]] += 1

    return summary


def main():
    parser = argparse.ArgumentParser(description="Validate Questie metadata against AzerothCore quest SQL.")
    parser.add_argument("--acore-source", default=r"P:\AC\source", help="Path to the AzerothCore source tree")
    parser.add_argument("--quest-db", default="Database/Wotlk/wotlkQuestDB.lua", help="Path to the Questie WotLK quest DB")
    parser.add_argument("--quest-template-sql", help="Optional HeidiSQL export for quest_template")
    parser.add_argument("--quest-template-addon-sql", help="Optional HeidiSQL export for quest_template_addon")
    parser.add_argument(
        "--quest-fixes",
        nargs="*",
        default=QUESTIE_FIX_FILES,
        help="Quest correction files to merge before comparison",
    )
    parser.add_argument("--limit", type=int, default=20, help="How many mismatches to print")
    parser.add_argument("--report", help="Optional path to write the full JSON report")
    parser.add_argument("--suggest-lua", help="Optional path to write candidate Lua quest metadata fixes")
    args = parser.parse_args()

    addon_root = Path(__file__).resolve().parents[1]
    source_root = Path(args.acore_source)
    quest_db_path = resolve_addon_path(addon_root, args.quest_db)
    quest_template_sql = Path(args.quest_template_sql) if args.quest_template_sql else None
    quest_template_addon_sql = Path(args.quest_template_addon_sql) if args.quest_template_addon_sql else None

    constants = load_constants(addon_root)
    questie_metadata = load_questie_base_metadata(quest_db_path, constants["quest_keys"], constants)
    for fix_file in args.quest_fixes:
        overrides = load_questie_correction_file(resolve_addon_path(addon_root, fix_file), constants)
        apply_questie_overrides(questie_metadata, overrides)
    for quest_entry in questie_metadata.values():
        for field in FIELD_ORDER:
            quest_entry.setdefault(field, default_field_value(field))

    acore_metadata = derive_acore_metadata(source_root, quest_template_sql, quest_template_addon_sql)
    mismatches, field_counts = compare_metadata(acore_metadata, questie_metadata)
    summary = build_summary(mismatches)

    print("AzerothCore quest metadata validation")
    print(f"AzerothCore source: {source_root}")
    print(f"Quest DB: {quest_db_path}")
    print(f"Total mismatches: {summary['total']}")
    for field in FIELD_ORDER:
        print(f"  {field}: {summary[field]}")

    if mismatches:
        print("")
        print(f"Showing first {min(args.limit, len(mismatches))} mismatches:")
        for mismatch in mismatches[: args.limit]:
            print(json.dumps(mismatch, separators=(",", ":")))

    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(
                {
                    "summary": summary,
                    "fieldCounts": dict(field_counts),
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
        suggestion_path.write_text(build_lua_suggestions(mismatches, acore_metadata), encoding="utf-8")
        print(f"Lua suggestions written to {suggestion_path}")


if __name__ == "__main__":
    main()
