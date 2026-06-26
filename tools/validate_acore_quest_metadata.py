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

EXCLUDED_MODULE_NAMES = {
    "mod-individual-progression",
}

FIELD_ORDER = [
    "name",
    "questLevel",
    "requiredLevel",
    "requiredRaces",
    "requiredClasses",
    "objectivesText",
    "objectives",
    "reputationReward",
    "sourceItemId",
    "requiredSourceItems",
    "requiredSkill",
    "requiredMinRep",
    "requiredMaxRep",
    "preQuestGroup",
    "preQuestSingle",
    "parentQuest",
    "exclusiveTo",
    "nextQuestInChain",
    "breadcrumbForQuestId",
    "breadcrumbs",
    "requiredSpell",
    "requiredMaxLevel",
    "questFlags",
    "specialFlags",
]

FIELD_KIND = {
    "name": "string",
    "questLevel": "int",
    "requiredLevel": "int",
    "requiredRaces": "int",
    "requiredClasses": "int",
    "objectivesText": "text_list",
    "objectives": "objectives",
    "reputationReward": "rep_reward",
    "sourceItemId": "int",
    "requiredSourceItems": "list",
    "requiredSkill": "pair",
    "requiredMinRep": "rep",
    "requiredMaxRep": "rep",
    "preQuestGroup": "list",
    "preQuestSingle": "list",
    "parentQuest": "int",
    "exclusiveTo": "list",
    "nextQuestInChain": "int",
    "breadcrumbForQuestId": "int",
    "breadcrumbs": "list",
    "requiredSpell": "int",
    "requiredMaxLevel": "int",
    "questFlags": "int",
    "specialFlags": "int",
}

CONDITION_SOURCE_TYPE_QUEST_AVAILABLE = 19
CONDITION_SOURCE_TYPE_SPELL = 17
CONDITION_QUESTREWARDED = 8
CONDITION_SPELL = 25
CONDITION_OBJECT_ENTRY_GUID = 31
CONDITION_OBJECT_TYPE_UNIT = 3
SMART_SOURCE_TYPE_CREATURE = 0
SMART_EVENT_GOSSIP_SELECT = 62
SMART_ACTION_KILL_UNIT = 33
SMART_SCRIPT_KEY_COLUMNS = ("entryorguid", "source_type", "id", "link")

CONDITION_KEY_COLUMNS = (
    "SourceTypeOrReferenceId",
    "SourceGroup",
    "SourceEntry",
    "SourceId",
    "ElseGroup",
    "ConditionTypeOrReference",
    "ConditionTarget",
    "ConditionValue1",
    "ConditionValue2",
    "ConditionValue3",
)

EMPTY_OBJECTIVES = ((), (), ())
SPELL_EFFECT_CREATE_ITEM = {24, 157}
ITEM_CLASS_QUEST = 12
QUEST_FACTION_REWARD_VALUES = {
    1: (0, 10, 25, 75, 150, 250, 350, 500, 1000, 5),
    2: (0, -10, -25, -75, -150, -250, -350, -500, -1000, -5),
}


def relation_has_sources(relation):
    if not relation:
        return False

    return any(
        relation[relation_type][source_type]
        for relation_type in ("start", "end")
        for source_type in relation[relation_type]
    )

# Quests where AC omits PrevQuestID even though a real prerequisite chain
# exists (the gate is enforced by server-side C++ scripts, not SQL).
_PRE_QUEST_SINGLE_CHAIN_PRESERVE = {
    # Shadow Vault questline (Icecrown) — hub quests are gated by NPC scripts
    12806,  # prereq 12982
    12992,  # prereq 12951
    13069,  # prereq 12982
    13084,  # prereq 12951
    13106,  # prereq 12896/12897
    13169,  # prereq 13168
    13170,  # prereq 13168
    13171,  # prereq 13168
}

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


def normalize_reputation_reward(value):
    if value is None or value is False:
        return ()

    pairs = []
    for pair in value:
        if not pair:
            continue
        if not isinstance(pair, (list, tuple)) or len(pair) < 2:
            continue
        faction = int(pair[0] or 0)
        reward = int(pair[1] or 0)
        if faction and reward:
            pairs.append((faction, reward))

    return tuple(sorted(pairs))


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


def extract_kill_credit_objectives(value):
    if not isinstance(value, (list, tuple)) or len(value) < 5:
        return ()

    category_value = value[4]
    if not isinstance(category_value, (list, tuple, set)):
        return ()

    records = []
    for record in category_value:
        if not isinstance(record, (list, tuple, set)) or not record:
            continue
        ids = normalize_list(record[0])
        if ids:
            records.append(ids)

    return tuple(records)


def build_acore_objectives(row, item_spell_target_creatures=None):
    creature_objectives = []
    object_objectives = []
    item_objectives = []

    for index in range(1, 5):
        entry = normalize_int(row.get(f"RequiredNpcOrGo{index}"))
        if entry > 0:
            creature_objectives.append((entry,))
        elif entry < 0:
            object_objectives.append((abs(entry),))

    start_item = normalize_int(row.get("StartItem"))
    for index in range(1, 7):
        entry = normalize_int(row.get(f"RequiredItemId{index}"))
        if entry > 0 and entry != start_item:
            item_objectives.append((entry,))

    if item_spell_target_creatures and len(creature_objectives) == 1:
        creature_objectives = [tuple(sorted(item_spell_target_creatures))]

    return normalize_objectives([creature_objectives, object_objectives, item_objectives])


def build_item_use_spell_map(item_template_rows):
    item_use_spells = defaultdict(set)

    for item_id, row in item_template_rows.items():
        for index in range(1, 6):
            spell_id = normalize_int(row.get(f"spellid_{index}"))
            spell_trigger = normalize_int(row.get(f"spelltrigger_{index}"))
            if spell_id > 0 and spell_trigger == 0:
                item_use_spells[item_id].add(spell_id)

    return item_use_spells


def get_numbered_spell_field(row, field_name, index):
    return row.get(f"{field_name}_{index}", row.get(f"{field_name}{index}"))


def build_spell_created_item_map(spell_rows):
    spell_created_items = defaultdict(set)

    for spell_id, row in spell_rows.items():
        for index in range(1, 4):
            effect = normalize_int(get_numbered_spell_field(row, "Effect", index))
            item_id = normalize_int(get_numbered_spell_field(row, "EffectItemType", index))
            if effect in SPELL_EFFECT_CREATE_ITEM and item_id > 0:
                spell_created_items[spell_id].add(item_id)

    return spell_created_items


def build_spell_reagent_item_map(spell_rows):
    spell_reagent_items = defaultdict(set)

    for spell_id, row in spell_rows.items():
        for index in range(1, 9):
            item_id = normalize_int(get_numbered_spell_field(row, "Reagent", index))
            item_count = normalize_int(get_numbered_spell_field(row, "ReagentCount", index))
            if item_id > 0 and item_count > 0:
                spell_reagent_items[spell_id].add(item_id)

    return spell_reagent_items


def is_quest_item(item_template_rows, item_id):
    row = item_template_rows.get(item_id)
    return row is not None and normalize_int(row.get("class")) == ITEM_CLASS_QUEST


def infer_created_required_source_items(source_items, item_use_spells, spell_created_items, spell_reagent_items, item_template_rows):
    source_item_set = set(source_items)
    inferred_items = set()

    for item_id in source_item_set:
        for spell_id in item_use_spells.get(item_id, set()):
            reagent_items = spell_reagent_items.get(spell_id, set())
            if not reagent_items or not reagent_items.issubset(source_item_set):
                continue

            for created_item_id in spell_created_items.get(spell_id, set()):
                if created_item_id not in source_item_set and is_quest_item(item_template_rows, created_item_id):
                    inferred_items.add(created_item_id)

    return inferred_items


def build_spell_target_creature_map(condition_rows):
    spell_target_creatures = defaultdict(set)

    for row in condition_rows:
        if normalize_int(row.get("SourceTypeOrReferenceId")) != CONDITION_SOURCE_TYPE_SPELL:
            continue
        if normalize_int(row.get("ConditionTypeOrReference")) != CONDITION_OBJECT_ENTRY_GUID:
            continue
        if normalize_int(row.get("ConditionValue1")) != CONDITION_OBJECT_TYPE_UNIT:
            continue
        if normalize_int(row.get("NegativeCondition")):
            continue

        spell_id = normalize_int(row.get("SourceEntry"))
        creature_id = normalize_int(row.get("ConditionValue2"))
        if spell_id > 0 and creature_id > 0:
            spell_target_creatures[spell_id].add(creature_id)

    return spell_target_creatures


def get_quest_source_item_ids(row):
    item_ids = normalize_list(
        [
            row.get("StartItem"),
            row.get("ItemDrop1"),
            row.get("ItemDrop2"),
            row.get("ItemDrop3"),
            row.get("ItemDrop4"),
        ]
    )
    return item_ids


def get_item_spell_target_creatures(row, item_use_spells, spell_target_creatures):
    target_creatures = set()

    for item_id in get_quest_source_item_ids(row):
        for spell_id in item_use_spells.get(item_id, set()):
            target_creatures.update(spell_target_creatures.get(spell_id, set()))

    return target_creatures


def build_creature_kill_credit_map(creature_template_rows):
    kill_credit_map = {}

    for creature_id, row in creature_template_rows.items():
        credits = {
            normalize_int(row.get("KillCredit1")),
            normalize_int(row.get("KillCredit2")),
        }
        credits.discard(0)
        if credits:
            kill_credit_map[creature_id] = credits

    return kill_credit_map


def build_acore_spawned_creature_ids(source_root):
    spawned_creature_ids = set()
    table_name = "creature"
    base_file = source_root / "data" / "sql" / "base" / "db_world" / f"{table_name}.sql"
    default_columns = extract_sql_columns(base_file, table_name)
    sql_files = [base_file]
    sql_files.extend(sorted((source_root / "data" / "sql" / "updates" / "db_world").glob("*.sql")))

    for sql_file in sql_files:
        raw_text = sql_file.read_text(encoding="utf-8")
        if not re.search(r"\bcreature\b", raw_text, re.IGNORECASE):
            continue

        text = strip_sql_comments(raw_text)
        for statement in split_sql_statements(text):
            insert_match = re.search(
                r"(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO)\s+`?creature`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
                statement,
                re.IGNORECASE | re.DOTALL,
            )
            if not insert_match:
                continue

            statement_columns = default_columns
            if insert_match.group("columns"):
                statement_columns = [
                    column_match.group(1)
                    for column_match in re.finditer(r"`([^`]+)`", insert_match.group("columns"))
                ]

            creature_column_indexes = [
                index
                for index, column_name in enumerate(statement_columns)
                if column_name.lower() in {"id", "id1", "id2", "id3"}
            ]
            if not creature_column_indexes:
                continue

            for row_text in split_sql_rows(insert_match.group("values")):
                row_values = split_sql_values(row_text)
                if len(row_values) != len(statement_columns):
                    continue
                for index in creature_column_indexes:
                    token = row_values[index].strip()
                    if re.fullmatch(r"-?\d+", token):
                        creature_id = int(token)
                        if creature_id > 0:
                            spawned_creature_ids.add(creature_id)

    return spawned_creature_ids


def load_acore_sql_rows(source_root, table_name, key_columns):
    base_file = source_root / "data" / "sql" / "base" / "db_world" / f"{table_name}.sql"
    updates_dir = source_root / "data" / "sql" / "updates" / "db_world"
    columns = extract_sql_columns(base_file, table_name)
    rows = {}

    def row_key(row):
        try:
            return tuple(int(row.get(column) or 0) for column in key_columns)
        except Exception:
            return None

    def apply_insert(statement):
        insert_match = re.search(
            rf"(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO)\s+`?{re.escape(table_name)}`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
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
            try:
                for column_name, raw_value in zip(statement_columns, row_values):
                    row[column_name] = parse_sql_value(raw_value)
            except Exception:
                continue

            key = row_key(row)
            if key is not None:
                rows[key] = row

    def apply_update(statement):
        update_match = re.search(
            rf"UPDATE\s+`?{re.escape(table_name)}`?\s+SET\s+(?P<set>.*?)\s+WHERE\s+(?P<where>.*)$",
            statement,
            re.IGNORECASE | re.DOTALL,
        )
        if not update_match:
            return

        where_conditions = parse_simple_where_conditions(update_match.group("where"))
        if where_conditions is None:
            return

        assignments = split_sql_values(update_match.group("set"))

        for key, row in list(rows.items()):
            if not condition_row_matches(row, where_conditions):
                continue

            context = {
                name: value
                for name, value in row.items()
                if not isinstance(value, (list, tuple, dict))
            }
            for assignment in assignments:
                assign_match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(.+)$", assignment.strip(), re.DOTALL)
                if not assign_match:
                    continue

                column = assign_match.group(1)
                expr = assign_match.group(2).strip()
                if column in context:
                    context[column] = row.get(column) or 0

                try:
                    row[column] = parse_sql_value(expr, context)
                except Exception:
                    continue

            new_key = row_key(row)
            if new_key != key:
                rows.pop(key, None)
                if new_key is not None:
                    rows[new_key] = row

    def apply_delete(statement):
        delete_match = re.search(
            rf"DELETE FROM\s+`?{re.escape(table_name)}`?\s+WHERE\s+(?P<where>.*)$",
            statement,
            re.IGNORECASE | re.DOTALL,
        )
        if not delete_match:
            return

        where_conditions = parse_simple_where_conditions(delete_match.group("where"))
        if where_conditions is None:
            return

        for key, row in list(rows.items()):
            if condition_row_matches(row, where_conditions):
                rows.pop(key, None)

    def apply_file(path):
        text = strip_sql_comments(path.read_text(encoding="utf-8"))
        for statement in split_sql_statements(text):
            if not re.search(rf"\b{re.escape(table_name)}\b", statement, re.IGNORECASE):
                continue
            if statement.upper().startswith(("INSERT INTO", "INSERT IGNORE INTO", "REPLACE INTO")):
                apply_insert(statement)
            elif statement.upper().startswith("UPDATE"):
                apply_update(statement)
            elif statement.upper().startswith("DELETE FROM"):
                apply_delete(statement)

    apply_file(base_file)
    if updates_dir.exists():
        for update_file in sorted(updates_dir.glob("*.sql")):
            apply_file(update_file)

    return list(rows.values())


def build_smartai_gossip_kill_credit_source_map(source_root):
    credit_sources = defaultdict(set)

    for row in load_acore_sql_rows(source_root, "smart_scripts", SMART_SCRIPT_KEY_COLUMNS):
        source_entry = normalize_int(row.get("entryorguid"))
        if source_entry <= 0:
            continue
        if normalize_int(row.get("source_type")) != SMART_SOURCE_TYPE_CREATURE:
            continue
        if normalize_int(row.get("event_type")) != SMART_EVENT_GOSSIP_SELECT:
            continue
        if normalize_int(row.get("action_type")) != SMART_ACTION_KILL_UNIT:
            continue

        credit_id = normalize_int(row.get("action_param1"))
        if credit_id > 0:
            credit_sources[credit_id].add(source_entry)

    return credit_sources


def flatten_objective_records(records):
    return tuple(
        int(entry)
        for record in (records or ())
        for entry in (record or ())
    )


def build_objective_display_risks(mismatches, questie_metadata, spawned_creature_ids, creature_template_rows):
    display_risks = []

    for mismatch in mismatches:
        if mismatch["field"] != "objectives" or mismatch.get("preservedCreatureDisplay"):
            continue

        quest_id = mismatch["questId"]
        questie_entry = questie_metadata.get(quest_id, {})
        questie_creature_ids = flatten_objective_records(
            questie_entry.get("objectives", EMPTY_OBJECTIVES)[0]
        )
        questie_kill_credit_ids = flatten_objective_records(
            questie_entry.get("_killCreditObjectives", ())
        )
        questie_display_ids = tuple(sorted(set(questie_creature_ids + questie_kill_credit_ids)))
        acore_creature_ids = flatten_objective_records(mismatch["acore"][0])

        if not acore_creature_ids or not questie_display_ids:
            continue

        acore_spawned_ids = tuple(
            creature_id for creature_id in acore_creature_ids if creature_id in spawned_creature_ids
        )
        questie_spawned_ids = tuple(
            creature_id for creature_id in questie_display_ids if creature_id in spawned_creature_ids
        )
        if acore_spawned_ids or not questie_spawned_ids:
            continue

        display_risks.append(
            {
                "questId": quest_id,
                "acoreCreatureIds": list(acore_creature_ids),
                "acoreCreatureNames": [
                    creature_template_rows.get(creature_id, {}).get("name", "")
                    for creature_id in acore_creature_ids
                ],
                "questieCreatureIds": list(questie_creature_ids),
                "questieKillCreditIds": list(questie_kill_credit_ids),
                "questieSpawnedIds": list(questie_spawned_ids),
                "questieSpawnedNames": [
                    creature_template_rows.get(creature_id, {}).get("name", "")
                    for creature_id in questie_spawned_ids
                ],
            }
        )

    return display_risks


def objective_values_have_spawned_display_replacement(
    acore_objectives,
    questie_objectives,
    questie_kill_credit_records,
    spawned_creature_ids,
):
    acore_creatures = acore_objectives[0]
    questie_creatures = questie_objectives[0]

    acore_creature_ids = flatten_objective_records(acore_creatures)
    questie_display_ids = tuple(
        sorted(
            set(
                flatten_objective_records(questie_creatures)
                + flatten_objective_records(questie_kill_credit_records)
            )
        )
    )
    if not acore_creature_ids or not questie_display_ids:
        return False

    acore_has_spawned_target = any(
        creature_id in spawned_creature_ids
        for creature_id in acore_creature_ids
    )
    questie_has_spawned_target = any(
        creature_id in spawned_creature_ids
        for creature_id in questie_display_ids
    )
    return not acore_has_spawned_target and questie_has_spawned_target


def objective_values_have_questie_object_superset(acore_objectives, questie_objectives):
    if acore_objectives == questie_objectives:
        return False

    acore_creatures, acore_objects, acore_items = acore_objectives
    questie_creatures, questie_objects, questie_items = questie_objectives

    if acore_creatures != questie_creatures:
        return False

    if not set(acore_objects).issubset(set(questie_objects)):
        return False

    if not set(acore_items).issubset(set(questie_items)):
        return False

    return len(questie_objects) > len(acore_objects)


def objective_values_have_smartai_gossip_display_replacement(
    acore_objectives,
    questie_objectives,
    smartai_gossip_kill_credit_sources,
):
    if acore_objectives == questie_objectives:
        return False

    if acore_objectives[1:] != questie_objectives[1:]:
        return False

    acore_creatures = acore_objectives[0]
    questie_creatures = questie_objectives[0]
    if not acore_creatures or len(acore_creatures) != len(questie_creatures):
        return False

    for acore_record, questie_record in zip(acore_creatures, questie_creatures):
        if not acore_record or not questie_record:
            return False

        source_creatures = set()
        for credit_id in acore_record:
            source_creatures.update(smartai_gossip_kill_credit_sources.get(credit_id, set()))

        if not source_creatures or not set(questie_record).issubset(source_creatures):
            return False

    return True


def raw_objectives_from_normalized(objectives):
    raw_categories = []
    for category in objectives[:3]:
        if not category:
            raw_categories.append(None)
            continue
        raw_categories.append([list(record) for record in category])
    return raw_categories


def merge_objectives_with_questie_creature_display(acore_objectives, questie_raw_objectives):
    merged = raw_objectives_from_normalized(acore_objectives)
    questie_raw_objectives = list(questie_raw_objectives or ())

    if questie_raw_objectives:
        merged[0] = questie_raw_objectives[0]

    # Preserve Questie's non-SQL display channels. These carry spawned targets,
    # icon overrides, and spell/event helpers that the static AC objective rows
    # cannot represent.
    while len(merged) < len(questie_raw_objectives):
        merged.append(None)
    for index in range(3, len(questie_raw_objectives)):
        merged[index] = questie_raw_objectives[index]

    while merged and merged[-1] is None:
        merged.pop()
    return merged


def raw_objectives_have_display_helpers(raw_objectives):
    if not isinstance(raw_objectives, (list, tuple)) or len(raw_objectives) <= 3:
        return False
    return any(bool(category) for category in raw_objectives[3:])


def objective_record_is_supported_kill_credit_expansion(acore_record, questie_record, kill_credit_map):
    if len(acore_record) != 1 or len(questie_record) <= 1:
        return False

    root_id = acore_record[0]
    if root_id not in questie_record:
        return False

    for creature_id in questie_record:
        if creature_id == root_id:
            continue
        if root_id not in kill_credit_map.get(creature_id, set()):
            return False

    return True


def match_supported_creature_objectives(acore_records, questie_records, questie_kill_credit_records, kill_credit_map):
    if len(acore_records) != len(questie_records) + len(questie_kill_credit_records):
        return None

    unmatched_questie_records = [
        ("creature", record)
        for record in questie_records
    ] + [
        ("killCredit", record)
        for record in questie_kill_credit_records
    ]
    preserved_expansions = []

    for acore_record in acore_records:
        exact_match = next(
            (
                candidate
                for candidate in unmatched_questie_records
                if candidate[0] == "creature" and candidate[1] == acore_record
            ),
            None,
        )
        if exact_match is not None:
            unmatched_questie_records.remove(exact_match)
            continue

        matching_record = next(
            (
                candidate
                for candidate in unmatched_questie_records
                if objective_record_is_supported_kill_credit_expansion(
                    acore_record,
                    candidate[1],
                    kill_credit_map,
                )
            ),
            None,
        )
        if matching_record is None:
            return None

        unmatched_questie_records.remove(matching_record)
        preserved_expansions.append(
            {
                "rootId": acore_record[0],
                "sourceCategory": matching_record[0],
                "expandedIds": list(matching_record[1]),
            }
        )

    if unmatched_questie_records:
        return None

    return preserved_expansions


def objective_values_are_equivalent(acore_objectives, questie_objectives, questie_kill_credit_records, kill_credit_map):
    if acore_objectives == questie_objectives:
        return True, []

    acore_creatures, acore_objects, acore_items = acore_objectives
    questie_creatures, questie_objects, questie_items = questie_objectives

    if acore_objects != questie_objects or acore_items != questie_items:
        return False, []

    preserved_expansions = match_supported_creature_objectives(
        acore_creatures,
        questie_creatures,
        questie_kill_credit_records,
        kill_credit_map,
    )
    if preserved_expansions is None:
        return False, []

    return True, preserved_expansions


def normalize_field(field, value):
    kind = FIELD_KIND[field]
    if kind == "string":
        return str(value or "")
    if kind == "int":
        return normalize_int(value)
    if kind == "list":
        return normalize_list(value)
    if kind == "pair":
        return normalize_pair(value)
    if kind == "rep":
        return normalize_pair(value)
    if kind == "rep_reward":
        return normalize_reputation_reward(value)
    if kind == "text_list":
        return normalize_text_list(value)
    if kind == "objectives":
        return normalize_objectives(value)
    raise ValueError(f"Unknown field kind: {kind}")


def build_acore_reputation_reward(row):
    rewards = []

    for index in range(1, 6):
        faction = normalize_int(row.get(f"RewardFactionID{index}"))
        if not faction:
            continue

        override = normalize_int(row.get(f"RewardFactionOverride{index}"))
        if override:
            reward = int(override / 100)
        else:
            value_id = normalize_int(row.get(f"RewardFactionValue{index}"))
            reward_row = QUEST_FACTION_REWARD_VALUES[2 if value_id < 0 else 1]
            field_index = abs(value_id)
            reward = reward_row[field_index] if field_index < len(reward_row) else 0

        if reward:
            rewards.append((faction, reward))

    return normalize_reputation_reward(rewards)


def default_field_value(field):
    kind = FIELD_KIND[field]
    if kind == "int":
        return 0
    if kind == "string":
        return ""
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


def format_raw_lua_value(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return lua_string_literal(value)
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (list, tuple)):
        return "{" + ",".join(format_raw_lua_value(item) for item in value) + "}"
    raise TypeError(f"Unsupported raw Lua value: {value!r}")


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
            if field == "objectives":
                quest_entry["_killCreditObjectives"] = extract_kill_credit_objectives(value)
                quest_entry["_rawObjectives"] = value
            quest_entry[field] = normalize_field(field, value)

        data[quest_id] = quest_entry

    return data


def load_questie_base_list_field(quest_db_path, quest_keys, constants, field_name):
    data = {}
    field_index = quest_keys.get(field_name)
    if field_index is None:
        return data

    text = quest_db_path.read_text(encoding="utf-8")
    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = QUEST_ROW_RE.match(line)
        if not match:
            continue

        row_values = split_top_level_lua_table(match.group(2))
        row_index = field_index - 1
        if row_index >= len(row_values):
            continue

        value = parse_lua_value(row_values[row_index], constants)
        normalized = normalize_list(value)
        if normalized:
            data[int(match.group(1))] = normalized

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

            if field_name == "objectives":
                quest_override["_killCreditObjectives"] = extract_kill_credit_objectives(value)
                quest_override["_rawObjectives"] = value
            quest_override[field_name] = normalize_field(field_name, value)

    return overrides


def load_questie_correction_list_field(path, constants, field_name):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    return_table = extract_return_table(text)
    overrides = {}

    for entry in split_top_level_lua_table(return_table):
        match = QUEST_ROW_RE.match(entry.strip())
        if not match:
            continue

        quest_id = int(match.group(1))
        body = match.group(2)

        for field_entry in split_top_level_lua_table(body):
            field_match = QUEST_FIELD_RE.match(field_entry.strip())
            if not field_match or field_match.group(1) != field_name:
                continue

            value = parse_lua_value(field_match.group(2), constants)
            if value is None:
                continue

            overrides[quest_id] = normalize_list(value)

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


def apply_sql_insert(statement, table_name, columns, rows, key_column="ID", wanted_keys=None):
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
        row_values = None
        if wanted_keys is not None and key_column in statement_columns:
            key_index = statement_columns.index(key_column)
            if key_index == 0:
                key_match = re.match(r"\s*(-?\d+)\s*,", row_text)
                if not key_match:
                    continue
                row_key = int(key_match.group(1))
            else:
                row_values = split_sql_values(row_text)
                if len(row_values) != len(statement_columns):
                    continue
                try:
                    row_key = int(parse_sql_value(row_values[key_index]))
                except Exception:
                    continue
            if row_key not in wanted_keys:
                continue

        if row_values is None:
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
            ids.update(int(part.strip()) for part in in_values.split(",") if re.fullmatch(r"\s*-?\d+\s*", part))
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
            ids.update(int(part.strip()) for part in in_values.split(",") if re.fullmatch(r"\s*-?\d+\s*", part))
        elif single_value:
            ids.add(int(single_value))

    for quest_id in ids:
        rows.pop(quest_id, None)


def condition_row_key(row):
    return tuple(int(row.get(column) or 0) for column in CONDITION_KEY_COLUMNS)


def split_sql_and_clauses(where_clause):
    clauses = []
    current = []
    index = 0
    in_string = False
    quote = ""
    escaped = False
    depth = 0

    while index < len(where_clause):
        char = where_clause[index]

        if in_string:
            current.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue

        if char in ("'", '"'):
            in_string = True
            quote = char
            current.append(char)
            index += 1
            continue

        if char == "(":
            depth += 1
            current.append(char)
            index += 1
            continue

        if char == ")":
            depth = max(0, depth - 1)
            current.append(char)
            index += 1
            continue

        if (
            depth == 0
            and where_clause[index : index + 3].upper() == "AND"
            and (index == 0 or not where_clause[index - 1].isalnum())
            and (index + 3 == len(where_clause) or not where_clause[index + 3].isalnum())
        ):
            clauses.append("".join(current).strip())
            current = []
            index += 3
            continue

        current.append(char)
        index += 1

    if current:
        clauses.append("".join(current).strip())

    return clauses


def parse_simple_where_conditions(where_clause):
    conditions = []
    for clause in split_sql_and_clauses(where_clause.strip().rstrip(";")):
        clause = clause.strip()
        while clause.startswith("(") and clause.endswith(")"):
            clause = clause[1:-1].strip()

        in_match = re.match(r"`?([A-Za-z0-9_]+)`?\s+IN\s*\((?P<values>[^)]+)\)$", clause, re.IGNORECASE | re.DOTALL)
        if in_match:
            try:
                values = {
                    parse_sql_value(value)
                    for value in split_sql_values(in_match.group("values"))
                }
            except Exception:
                return None
            conditions.append((in_match.group(1), values))
            continue

        equal_match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(?P<value>.+)$", clause, re.IGNORECASE | re.DOTALL)
        if equal_match:
            try:
                value = parse_sql_value(equal_match.group("value"))
            except Exception:
                return None
            conditions.append((equal_match.group(1), {value}))
            continue

        return None

    return conditions


def condition_row_matches(row, conditions):
    for column, values in conditions:
        if row.get(column) not in values:
            return False
    return True


def apply_condition_insert(statement, columns, rows):
    insert_match = re.search(
        r"(?:INSERT INTO|REPLACE INTO)\s+`?conditions`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
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
        try:
            for column_name, raw_value in zip(statement_columns, row_values):
                row[column_name] = parse_sql_value(raw_value)
        except Exception:
            continue

        rows[condition_row_key(row)] = row


def apply_condition_update(statement, rows):
    update_match = re.search(
        r"UPDATE\s+`?conditions`?\s+SET\s+(?P<set>.*?)\s+WHERE\s+(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not update_match:
        return

    where_conditions = parse_simple_where_conditions(update_match.group("where"))
    if where_conditions is None:
        return

    assignments = split_sql_values(update_match.group("set"))
    for key, row in list(rows.items()):
        if not condition_row_matches(row, where_conditions):
            continue

        updated_row = dict(row)
        context = {
            column: value
            for column, value in updated_row.items()
            if not isinstance(value, (list, tuple, dict))
        }
        for assignment in assignments:
            assign_match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(.+)$", assignment.strip(), re.DOTALL)
            if not assign_match:
                continue

            column = assign_match.group(1)
            expr = assign_match.group(2).strip()
            try:
                updated_row[column] = parse_sql_value(expr, context)
                context[column] = updated_row[column] if updated_row[column] is not None else 0
            except Exception:
                continue

        rows.pop(key, None)
        rows[condition_row_key(updated_row)] = updated_row


def apply_condition_delete(statement, rows):
    delete_match = re.search(
        r"DELETE FROM\s+`?conditions`?\s+WHERE\s+(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if not delete_match:
        return

    where_conditions = parse_simple_where_conditions(delete_match.group("where"))
    if where_conditions is None:
        return

    for key, row in list(rows.items()):
        if condition_row_matches(row, where_conditions):
            rows.pop(key, None)


def load_acore_conditions(source_root):
    base_file = source_root / "data" / "sql" / "base" / "db_world" / "conditions.sql"
    updates_dir = source_root / "data" / "sql" / "updates" / "db_world"
    columns = extract_sql_columns(base_file, "conditions")
    rows = {}

    def apply_file(path):
        text = strip_sql_comments(path.read_text(encoding="utf-8"))
        for statement in split_sql_statements(text):
            if not re.search(r"\bconditions\b", statement, re.IGNORECASE):
                continue
            if statement.upper().startswith(("INSERT INTO", "REPLACE INTO")):
                apply_condition_insert(statement, columns, rows)
            elif statement.upper().startswith("UPDATE"):
                apply_condition_update(statement, rows)
            elif statement.upper().startswith("DELETE FROM"):
                apply_condition_delete(statement, rows)

    apply_file(base_file)
    if updates_dir.exists():
        for update_file in sorted(updates_dir.glob("*.sql")):
            apply_file(update_file)

    return list(rows.values())


def extract_statement_key_ids(statement, table_name, columns, key_column="ID"):
    insert_match = re.search(
        rf"(?:INSERT INTO|REPLACE INTO)\s+`?{re.escape(table_name)}`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if insert_match:
        statement_columns = columns
        if insert_match.group("columns"):
            statement_columns = [
                column_match.group(1)
                for column_match in re.finditer(r"`([^`]+)`", insert_match.group("columns"))
            ]
        if key_column not in statement_columns:
            return set()

        key_index = statement_columns.index(key_column)
        ids = set()
        for row_text in split_sql_rows(insert_match.group("values")):
            row_values = split_sql_values(row_text)
            if key_index >= len(row_values):
                continue
            try:
                ids.add(int(parse_sql_value(row_values[key_index])))
            except Exception:
                continue
        return ids

    id_matches = []
    update_match = re.search(
        rf"UPDATE\s+`?{re.escape(table_name)}`?\s+SET\s+.*?\s+WHERE\s+(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    delete_match = re.search(
        rf"DELETE FROM\s+`?{re.escape(table_name)}`?\s+WHERE\s+(?P<where>.*)$",
        statement,
        re.IGNORECASE | re.DOTALL,
    )
    if update_match:
        where_clause = update_match.group("where")
    elif delete_match:
        where_clause = delete_match.group("where")
    else:
        return set()

    key_pattern = re.escape(key_column)
    id_matches = re.findall(
        rf"`?{key_pattern}`?\s+IN\s*\(([^)]+)\)|`?{key_pattern}`?\s*=\s*(-?\d+)",
        where_clause,
        re.IGNORECASE,
    )
    ids = set()
    for in_values, single_value in id_matches:
        if in_values:
            ids.update(int(part.strip()) for part in in_values.split(",") if re.fullmatch(r"\s*-?\d+\s*", part))
        elif single_value:
            ids.add(int(single_value))
    return ids


def load_acore_sql_table(source_root, table_name, base_file_override=None, key_column="ID", include_modules=False, wanted_keys=None):
    if base_file_override:
        base_file = Path(base_file_override)
        updates_dir = None
        module_sql_roots = []
    else:
        base_file = source_root / "data" / "sql" / "base" / "db_world" / f"{table_name}.sql"
        updates_dir = source_root / "data" / "sql" / "updates" / "db_world"
        module_sql_roots = []
        modules_dir = source_root / "modules"
        if include_modules and modules_dir.exists():
            for module_dir in sorted((path for path in modules_dir.iterdir() if path.is_dir()), key=lambda path: path.name.lower()):
                if module_dir.name in EXCLUDED_MODULE_NAMES:
                    continue
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
                apply_insert(statement, table_name, columns, rows, key_column, wanted_keys)
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


def get_excluded_module_sql_roots(source_root):
    modules_dir = source_root / "modules"
    if not modules_dir.exists():
        return []

    roots = []
    for module_name in sorted(EXCLUDED_MODULE_NAMES):
        module_dir = modules_dir / module_name
        if not module_dir.exists():
            continue
        for relative_root in ("data/sql/world/base", "data/sql/world/updates"):
            sql_root = module_dir / relative_root
            if sql_root.exists():
                roots.append(sql_root)
    return roots


def load_excluded_module_touched_quest_ids(source_root, table_name, key_column="ID"):
    columns = extract_sql_columns(source_root / "data" / "sql" / "base" / "db_world" / f"{table_name}.sql", table_name)
    touched_ids = set()

    for sql_root in get_excluded_module_sql_roots(source_root):
        for sql_file in sorted(sql_root.rglob("*.sql"), key=lambda path: str(path).lower()):
            text = strip_sql_comments(sql_file.read_text(encoding="utf-8"))
            if not re.search(rf"\b{re.escape(table_name)}\b", text, re.IGNORECASE):
                continue

            for statement in split_sql_statements(text):
                if not re.search(rf"\b{re.escape(table_name)}\b", statement, re.IGNORECASE):
                    continue
                touched_ids.update(extract_statement_key_ids(statement, table_name, columns, key_column))

    return touched_ids


def restore_excluded_module_metadata_rows(exported_rows, source_rows, source_root, table_name):
    for quest_id in load_excluded_module_touched_quest_ids(source_root, table_name):
        if quest_id in source_rows:
            exported_rows[quest_id] = dict(source_rows[quest_id])
        else:
            exported_rows.pop(quest_id, None)


def load_module_created_quest_ids(source_root):
    module_quest_ids = set()
    columns_cache = {}

    for sql_root in get_excluded_module_sql_roots(source_root):
        for sql_file in sorted(sql_root.rglob("*.sql"), key=lambda path: str(path).lower()):
            text = strip_sql_comments(sql_file.read_text(encoding="utf-8"))
            if not re.search(r"\bquest_template\b", text, re.IGNORECASE):
                continue

            for statement in split_sql_statements(text):
                insert_match = re.search(
                    r"(?:INSERT INTO|REPLACE INTO)\s+`?quest_template`?(?:\s*\((?P<columns>.*?)\))?\s*VALUES\s*(?P<values>.*)$",
                    statement,
                    re.IGNORECASE | re.DOTALL,
                )
                if not insert_match:
                    continue

                if insert_match.group("columns"):
                    columns = [
                        column_match.group(1)
                        for column_match in re.finditer(r"`([^`]+)`", insert_match.group("columns"))
                    ]
                else:
                    columns = columns_cache.setdefault(
                        "quest_template",
                        extract_sql_columns(source_root / "data" / "sql" / "base" / "db_world" / "quest_template.sql", "quest_template"),
                    )
                row_id = columns.index("ID") if "ID" in columns else 0

                for row_text in split_sql_rows(insert_match.group("values")):
                    row_values = split_sql_values(row_text)
                    if row_id >= len(row_values):
                        continue
                    try:
                        quest_id = int(parse_sql_value(row_values[row_id]))
                    except Exception:
                        continue
                    module_quest_ids.add(quest_id)

    core_quest_ids = set(load_acore_sql_table(source_root, "quest_template"))
    return module_quest_ids - core_quest_ids


def derive_quest_availability_conditions(source_root, condition_rows=None):
    condition_prereqs = defaultdict(set)
    spell_conditions = defaultdict(list)

    if condition_rows is None:
        condition_rows = load_acore_conditions(source_root)

    for row in condition_rows:
        if int(row.get("SourceTypeOrReferenceId") or 0) != CONDITION_SOURCE_TYPE_QUEST_AVAILABLE:
            continue

        quest_id = int(row.get("SourceEntry") or 0)
        if not quest_id:
            continue

        condition_type = int(row.get("ConditionTypeOrReference") or 0)
        condition_value = int(row.get("ConditionValue1") or 0)
        is_negative = int(row.get("NegativeCondition") or 0) != 0

        if condition_type == CONDITION_QUESTREWARDED and condition_value > 0 and not is_negative:
            condition_prereqs[quest_id].add(condition_value)
        elif condition_type == CONDITION_SPELL and condition_value > 0:
            spell_conditions[quest_id].append(-condition_value if is_negative else condition_value)

    required_spells = {}
    for quest_id, spells in spell_conditions.items():
        unique_spells = sorted(set(spells), key=lambda spell_id: (abs(spell_id), spell_id))
        if len(unique_spells) == 1:
            required_spells[quest_id] = unique_spells[0]

    return condition_prereqs, required_spells


def derive_acore_metadata(source_root, quest_template_sql=None, quest_template_addon_sql=None, spell_sql=None, spell_table="spell"):
    source_quest_rows = load_acore_sql_table(source_root, "quest_template")
    source_addon_rows = load_acore_sql_table(source_root, "quest_template_addon")
    quest_rows = load_acore_sql_table(source_root, "quest_template", quest_template_sql) if quest_template_sql else dict(source_quest_rows)
    addon_rows = load_acore_sql_table(source_root, "quest_template_addon", quest_template_addon_sql) if quest_template_addon_sql else dict(source_addon_rows)
    restore_excluded_module_metadata_rows(quest_rows, source_quest_rows, source_root, "quest_template")
    restore_excluded_module_metadata_rows(addon_rows, source_addon_rows, source_root, "quest_template_addon")

    module_quest_ids = load_module_created_quest_ids(source_root)
    for quest_id in module_quest_ids:
        quest_rows.pop(quest_id, None)
        addon_rows.pop(quest_id, None)

    quest_ids = set(quest_rows) | set(addon_rows)
    combined_rows = {}
    prereq_sets = defaultdict(set)
    prequest_groups = defaultdict(set)
    negative_exclusive_groups = defaultdict(set)
    negative_exclusive_next_quests = defaultdict(lambda: defaultdict(set))
    parent_quests = defaultdict(set)
    exclusive_groups = defaultdict(set)
    breadcrumbs_for = defaultdict(set)
    condition_rows = load_acore_conditions(source_root)
    condition_prereqs, required_spells = derive_quest_availability_conditions(source_root, condition_rows)
    item_template_rows = load_acore_sql_table(source_root, "item_template", key_column="entry")
    item_use_spells = build_item_use_spell_map(item_template_rows)
    spell_created_items = {}
    spell_reagent_items = {}
    if spell_sql:
        wanted_spell_ids = set()
        for spell_ids in item_use_spells.values():
            wanted_spell_ids.update(spell_ids)
        spell_rows = load_acore_sql_table(source_root, spell_table, spell_sql, wanted_keys=wanted_spell_ids)
        spell_created_items = build_spell_created_item_map(spell_rows)
        spell_reagent_items = build_spell_reagent_item_map(spell_rows)
    spell_target_creatures = build_spell_target_creature_map(condition_rows)

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

        prereq_sets[quest_id].update(condition_prereqs.get(quest_id, set()))

        next_quest = int(row.get("NextQuestID") or row.get("NextQuestId") or 0)
        exclusive_group = int(row.get("ExclusiveGroup") or 0)
        if next_quest > 0:
            if exclusive_group < 0:
                negative_exclusive_next_quests[next_quest][exclusive_group].add(quest_id)
            else:
                prereq_sets[next_quest].add(quest_id)

        if exclusive_group > 0:
            exclusive_groups[exclusive_group].add(quest_id)
        elif exclusive_group < 0:
            negative_exclusive_groups[exclusive_group].add(quest_id)

        breadcrumb_for = int(row.get("BreadcrumbForQuestId") or 0)
        if breadcrumb_for > 0:
            breadcrumbs_for[breadcrumb_for].add(quest_id)

    for next_quest, groups in negative_exclusive_next_quests.items():
        for exclusive_group, grouped_prereqs in groups.items():
            full_group = negative_exclusive_groups.get(exclusive_group, set())
            if len(full_group) > 1:
                prequest_groups[next_quest].update(full_group)
            elif len(grouped_prereqs) > 1:
                prequest_groups[next_quest].update(grouped_prereqs)
            else:
                prereq_sets[next_quest].update(grouped_prereqs)

    for quest_id, prereqs in list(prereq_sets.items()):
        expanded_groups = set()
        for prereq in prereqs:
            prereq_group = int(combined_rows.get(prereq, {}).get("ExclusiveGroup") or 0)
            if prereq_group < 0 and len(negative_exclusive_groups.get(prereq_group, set())) > 1:
                expanded_groups.update(negative_exclusive_groups[prereq_group])

        if expanded_groups:
            prequest_groups[quest_id].update(expanded_groups)
            prereqs.difference_update(expanded_groups)

    acore_metadata = {}
    for quest_id, row in combined_rows.items():
        if quest_id in module_quest_ids:
            continue

        metadata = {field: default_field_value(field) for field in FIELD_ORDER}

        metadata["name"] = str(row.get("LogTitle") or "")
        metadata["questLevel"] = normalize_int(row.get("QuestLevel"))
        metadata["requiredLevel"] = normalize_int(row.get("MinLevel"))
        metadata["requiredRaces"] = normalize_int(row.get("AllowableRaces"))
        metadata["requiredClasses"] = normalize_int(row.get("AllowableClasses"))
        metadata["objectivesText"] = normalize_text_list(row.get("LogDescription"))
        metadata["objectives"] = build_acore_objectives(
            row,
            get_item_spell_target_creatures(row, item_use_spells, spell_target_creatures),
        )
        metadata["reputationReward"] = build_acore_reputation_reward(row)
        metadata["sourceItemId"] = normalize_int(row.get("StartItem"))
        required_source_items = normalize_list(
            [
                row.get("ItemDrop1"),
                row.get("ItemDrop2"),
                row.get("ItemDrop3"),
                row.get("ItemDrop4"),
            ]
        )
        metadata["requiredSourceItems"] = normalize_list(
            (
                required_source_items,
                infer_created_required_source_items(
                    required_source_items,
                    item_use_spells,
                    spell_created_items,
                    spell_reagent_items,
                    item_template_rows,
                ),
            )
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
        metadata["preQuestGroup"] = normalize_list(prequest_groups.get(quest_id, set()))
        metadata["preQuestSingle"] = normalize_list(() if metadata["preQuestGroup"] else prereq_sets.get(quest_id, set()))
        metadata["parentQuest"] = normalize_int(next(iter(parent_quests.get(quest_id, set())), 0))
        exclusive_group = int(row.get("ExclusiveGroup") or 0)
        if exclusive_group > 0:
            metadata["exclusiveTo"] = normalize_list(sorted(exclusive_groups[exclusive_group] - {quest_id}))
        metadata["nextQuestInChain"] = normalize_int(row.get("RewardNextQuest"))
        metadata["breadcrumbForQuestId"] = normalize_int(row.get("BreadcrumbForQuestId"))
        metadata["breadcrumbs"] = normalize_list(breadcrumbs_for.get(quest_id, set()))
        metadata["requiredSpell"] = normalize_int(required_spells.get(quest_id, 0))
        metadata["requiredMaxLevel"] = normalize_int(row.get("MaxLevel"))
        metadata["questFlags"] = normalize_int(row.get("Flags"))
        metadata["specialFlags"] = normalize_int(row.get("SpecialFlags"))

        acore_metadata[quest_id] = metadata

    return acore_metadata


def compare_metadata(
    acore_metadata,
    questie_metadata,
    creature_kill_credits,
    spawned_creature_ids,
    protected_required_race_quest_ids=None,
    questie_prequest_groups=None,
    smartai_gossip_kill_credit_sources=None,
    active_acore_quest_ids=None,
):
    mismatches = []
    preserved_objective_expansions = []
    preserved_display_objectives = []
    preserved_empty_prequest_clears = []
    preserved_empty_prequest_group_clears = []
    preserved_empty_required_race_clears = []
    preserved_group_as_single_prequest = []
    preserved_required_source_item_supersets = []
    all_quest_ids = sorted(set(acore_metadata) | set(questie_metadata))
    summary = Counter()
    protected_required_race_quest_ids = protected_required_race_quest_ids or set()
    questie_prequest_groups = questie_prequest_groups or {}
    smartai_gossip_kill_credit_sources = smartai_gossip_kill_credit_sources or {}
    active_acore_quest_ids = active_acore_quest_ids or set()

    empty_entry = {field: default_field_value(field) for field in FIELD_ORDER}

    for quest_id in all_quest_ids:
        if quest_id not in questie_metadata and quest_id not in active_acore_quest_ids:
            continue

        acore = acore_metadata.get(quest_id, empty_entry)
        questie = questie_metadata.get(quest_id, empty_entry)

        for field in FIELD_ORDER:
            if field == "name" and questie.get(field):
                continue
            if field == "objectives":
                if (
                    acore[field] == EMPTY_OBJECTIVES
                    and questie[field] != EMPTY_OBJECTIVES
                ):
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                            "reason": "emptyAcoreObjectives",
                        }
                    )
                    continue

                if (
                    acore[field] != questie[field]
                    and objective_values_have_questie_object_superset(acore[field], questie[field])
                ):
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                            "reason": "questieObjectObjectiveSuperset",
                        }
                    )
                    continue

                if (
                    acore[field] != questie[field]
                    and raw_objectives_have_display_helpers(questie.get("_rawObjectives", ()))
                ):
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                            "reason": "questieDisplayHelpers",
                        }
                    )
                    continue

                if (
                    acore[field] != questie[field]
                    and objective_values_have_smartai_gossip_display_replacement(
                        acore[field],
                        questie[field],
                        smartai_gossip_kill_credit_sources,
                    )
                ):
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                            "reason": "smartAiGossipKillCreditDisplay",
                        }
                    )
                    continue

                has_display_replacement = objective_values_have_spawned_display_replacement(
                    acore[field],
                    questie[field],
                    questie.get("_killCreditObjectives", ()),
                    spawned_creature_ids,
                )
                if (
                    acore[field] != questie[field]
                    and has_display_replacement
                    and acore[field][1:] == questie[field][1:]
                ):
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                        }
                    )
                    continue

                # AC uses unspawned credit marker creatures as server-side
                # kill credit targets, but Questie already supplies item or
                # gameobject objectives that resolve to spawned world objects.
                acore_creature_ids = flatten_objective_records(acore[field][0] if acore[field] else ())
                questie_creature_ids = flatten_objective_records(questie[field][0] if questie[field] else ())
                questie_object_ids = flatten_objective_records(
                    questie[field][1] if len(questie[field]) > 1 else ()
                )
                questie_item_ids = flatten_objective_records(
                    questie[field][2] if len(questie[field]) > 2 else ()
                )
                if (
                    acore[field] != questie[field]
                    and acore_creature_ids
                    and not questie_creature_ids
                    and (questie_object_ids or questie_item_ids)
                    and not any(cid in spawned_creature_ids for cid in acore_creature_ids)
                ):
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                            "reason": "acoreUnspawnedCreaturesQuestieHasNonCreatureObjectives",
                        }
                    )
                    continue

                equivalent, expansions = objective_values_are_equivalent(
                    acore[field],
                    questie[field],
                    questie.get("_killCreditObjectives", ()),
                    creature_kill_credits,
                )
                if equivalent:
                    if expansions:
                        preserved_objective_expansions.append(
                            {
                                "questId": quest_id,
                                "expansions": expansions,
                            }
                        )
                    continue

            if (
                field == "preQuestSingle"
                and acore[field] == ()
                and questie[field]
                and quest_id in _PRE_QUEST_SINGLE_CHAIN_PRESERVE
            ):
                preserved_empty_prequest_clears.append(
                    {
                        "questId": quest_id,
                        "acore": acore[field],
                        "questie": questie[field],
                    }
                )
                continue

            if field == "preQuestGroup" and acore[field] == () and questie[field]:
                preserved_empty_prequest_group_clears.append(
                    {
                        "questId": quest_id,
                        "acore": acore[field],
                        "questie": questie[field],
                        "reason": "preserveQuestiePreQuestGroupWhenAcoreHasNoGroup",
                    }
                )
                continue

            if (
                field == "requiredRaces"
                and acore[field] == 0
                and questie[field] != 0
                and quest_id in protected_required_race_quest_ids
            ):
                preserved_empty_required_race_clears.append(
                    {
                        "questId": quest_id,
                        "acore": acore[field],
                        "questie": questie[field],
                        "reason": "explicitQuestieRequiredRacesCorrection",
                    }
                )
                continue

            if (
                field == "preQuestSingle"
                and acore[field]
                and not questie[field]
                and acore[field] == questie_prequest_groups.get(quest_id)
            ):
                preserved_group_as_single_prequest.append(
                    {
                        "questId": quest_id,
                        "acore": acore[field],
                        "questiePreQuestGroup": questie_prequest_groups[quest_id],
                        "reason": "matchesQuestiePreQuestGroup",
                    }
                )
                continue

            if (
                field == "requiredSourceItems"
                and acore[field] != questie[field]
                and acore[field]
                and questie[field]
                and set(acore[field]).issubset(set(questie[field]))
            ):
                preserved_required_source_item_supersets.append(
                    {
                        "questId": quest_id,
                        "acore": acore[field],
                        "questie": questie[field],
                        "reason": "preserveQuestieRequiredSourceItemSuperset",
                    }
                )
                continue

            if acore[field] != questie[field]:
                mismatch = {
                    "questId": quest_id,
                    "field": field,
                    "acore": acore[field],
                    "questie": questie[field],
                }
                if field == "objectives" and has_display_replacement:
                    mismatch["suggestedRawObjectives"] = merge_objectives_with_questie_creature_display(
                        acore[field],
                        questie.get("_rawObjectives", ()),
                    )
                    mismatch["preservedCreatureDisplay"] = True
                    preserved_display_objectives.append(
                        {
                            "questId": quest_id,
                            "acore": acore[field],
                            "questie": questie[field],
                        }
                    )
                mismatches.append(
                    mismatch
                )
                summary[field] += 1

    return (
        mismatches,
        summary,
        preserved_objective_expansions,
        preserved_display_objectives,
        preserved_empty_prequest_clears,
        preserved_empty_prequest_group_clears,
        preserved_empty_required_race_clears,
        preserved_group_as_single_prequest,
        preserved_required_source_item_supersets,
    )


def format_named_bitmask(value, constants, prefix, exact_names=()):
    value = normalize_int(value)
    exact_lookup = {constant_value: name for name, constant_value in constants.items()}

    for name in exact_names:
        if constants.get(name) == value:
            return f"{prefix}.{name}"

    if value in exact_lookup and value == 0:
        return f"{prefix}.{exact_lookup[value]}"

    parts = []
    remainder = value
    for name, constant_value in constants.items():
        if name in exact_names or name.startswith("ALL_") or constant_value == 0:
            continue
        if constant_value > 0 and constant_value & (constant_value - 1) == 0 and value & constant_value:
            parts.append(f"{prefix}.{name}")
            remainder &= ~constant_value

    if not parts:
        if value in exact_lookup:
            return f"{prefix}.{exact_lookup[value]}"
        return str(value)

    if remainder:
        parts.append(str(remainder))

    return " + ".join(parts)


def format_required_skill(value, constants):
    if not value:
        return "{}"

    skill, level = value
    profession_lookup = {profession_id: name for name, profession_id in constants["profKeys"].items()}
    skill_expr = f"profKeys.{profession_lookup[skill]}" if skill in profession_lookup else str(skill)
    return "{" + f"{skill_expr},{level}" + "}"


def format_reputation_reward(value, constants):
    if not value:
        return "{}"

    faction_lookup = {faction_id: name for name, faction_id in constants["factionIDs"].items()}
    rewards = []
    for faction, reward in value:
        faction_expr = f"factionIDs.{faction_lookup[faction]}" if faction in faction_lookup else str(faction)
        rewards.append("{" + f"{faction_expr},{reward}" + "}")

    return "{" + ",".join(rewards) + "}"


def format_lua_value(field, value, constants):
    kind = FIELD_KIND[field]
    if field == "requiredRaces":
        return format_named_bitmask(
            value,
            constants["raceIDs"],
            "raceIDs",
            exact_names=("NONE", "ALL_ALLIANCE", "ALL_HORDE"),
        )
    if field == "requiredClasses":
        return format_named_bitmask(
            value,
            constants["classIDs"],
            "classIDs",
            exact_names=("NONE", "ALL_CLASSES"),
        )
    if field == "specialFlags":
        return format_named_bitmask(
            value,
            constants["specialFlags"],
            "specialFlags",
            exact_names=("NONE",),
        )
    if field == "requiredSkill":
        return format_required_skill(value, constants)
    if kind == "string":
        return lua_string_literal(str(value or ""))
    if kind == "int":
        return str(normalize_int(value))
    if kind == "rep":
        if not value:
            return "false"
        return "{" + ",".join(str(part) for part in value) + "}"
    if kind == "rep_reward":
        return format_reputation_reward(value, constants)
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


def build_lua_suggestions(mismatches, acore_metadata, constants):
    by_quest = defaultdict(dict)
    empty_entry = {field: default_field_value(field) for field in FIELD_ORDER}

    for mismatch in mismatches:
        if mismatch["field"] == "objectives" and "suggestedRawObjectives" in mismatch:
            by_quest[mismatch["questId"]][mismatch["field"]] = (
                mismatch["suggestedRawObjectives"],
                True,
            )
        else:
            by_quest[mismatch["questId"]][mismatch["field"]] = (
                acore_metadata.get(
                    mismatch["questId"],
                    empty_entry,
                )[mismatch["field"]],
                False,
            )

    lines = [
        "-- Generated from AzerothCore quest_template and quest_template_addon metadata.",
        "-- This fragment should be wrapped by the metadata generator into a QuestieCompat.RegisterCorrection module.",
        "",
    ]

    for quest_id in sorted(by_quest):
        lines.append(f"[{quest_id}] = {{")
        for field in FIELD_ORDER:
            if field not in by_quest[quest_id]:
                continue
            value, is_raw = by_quest[quest_id][field]
            formatted_value = format_raw_lua_value(value) if is_raw else format_lua_value(field, value, constants)
            lines.append(f"    [questKeys.{field}] = {formatted_value},")
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
    from validate_acore_quest_relations import apply_acore_relation_overrides, load_acore_relations

    parser = argparse.ArgumentParser(description="Validate Questie metadata against AzerothCore quest SQL.")
    parser.add_argument("--acore-source", default=r"P:\AC\source", help="Path to the AzerothCore source tree")
    parser.add_argument("--quest-db", default="Database/Wotlk/wotlkQuestDB.lua", help="Path to the Questie WotLK quest DB")
    parser.add_argument("--quest-template-sql", help="Optional HeidiSQL export for quest_template")
    parser.add_argument("--quest-template-addon-sql", help="Optional HeidiSQL export for quest_template_addon")
    parser.add_argument("--spell-sql", help="Optional Spell.dbc SQL export used to infer crafted/created quest source items")
    parser.add_argument("--spell-table", default="spell", help="Table name inside --spell-sql")
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
    spell_sql = Path(args.spell_sql) if args.spell_sql else None

    constants = load_constants(addon_root)
    questie_metadata = load_questie_base_metadata(quest_db_path, constants["quest_keys"], constants)
    questie_prequest_groups = load_questie_base_list_field(
        quest_db_path,
        constants["quest_keys"],
        constants,
        "preQuestGroup",
    )
    protected_required_race_quest_ids = set()
    for fix_file in args.quest_fixes:
        fix_path = resolve_addon_path(addon_root, fix_file)
        overrides = load_questie_correction_file(fix_path, constants)
        protected_required_race_quest_ids.update(
            quest_id
            for quest_id, quest_override in overrides.items()
            if quest_override.get("requiredRaces", 0) != 0
        )
        questie_prequest_groups.update(
            load_questie_correction_list_field(fix_path, constants, "preQuestGroup")
        )
        apply_questie_overrides(questie_metadata, overrides)
    for quest_entry in questie_metadata.values():
        for field in FIELD_ORDER:
            quest_entry.setdefault(field, default_field_value(field))

    acore_metadata = derive_acore_metadata(
        source_root,
        quest_template_sql,
        quest_template_addon_sql,
        spell_sql,
        args.spell_table,
    )
    acore_relations = load_acore_relations(source_root, quest_template_sql)
    apply_acore_relation_overrides(acore_relations)
    active_acore_quest_ids = {
        quest_id
        for quest_id, relation in acore_relations.items()
        if relation_has_sources(relation)
    }
    creature_template_rows = load_acore_sql_table(source_root, "creature_template", key_column="entry")
    creature_kill_credits = build_creature_kill_credit_map(creature_template_rows)
    spawned_creature_ids = build_acore_spawned_creature_ids(source_root)
    smartai_gossip_kill_credit_sources = build_smartai_gossip_kill_credit_source_map(source_root)
    (
        mismatches,
        field_counts,
        preserved_objective_expansions,
        preserved_display_objectives,
        preserved_empty_prequest_clears,
        preserved_empty_prequest_group_clears,
        preserved_empty_required_race_clears,
        preserved_group_as_single_prequest,
        preserved_required_source_item_supersets,
    ) = compare_metadata(
        acore_metadata,
        questie_metadata,
        creature_kill_credits,
        spawned_creature_ids,
        protected_required_race_quest_ids,
        questie_prequest_groups,
        smartai_gossip_kill_credit_sources,
        active_acore_quest_ids,
    )
    objective_display_risks = build_objective_display_risks(
        mismatches,
        questie_metadata,
        spawned_creature_ids,
        creature_template_rows,
    )
    summary = build_summary(mismatches)

    print("AzerothCore quest metadata validation")
    print(f"AzerothCore source: {source_root}")
    print(f"Quest DB: {quest_db_path}")
    print(f"Total mismatches: {summary['total']}")
    for field in FIELD_ORDER:
        print(f"  {field}: {summary[field]}")
    print(f"  preservedObjectiveExpansions: {len(preserved_objective_expansions)}")
    print(f"  preservedDisplayObjectives: {len(preserved_display_objectives)}")
    print(f"  preservedEmptyPreQuestClears: {len(preserved_empty_prequest_clears)}")
    print(f"  preservedEmptyPreQuestGroupClears: {len(preserved_empty_prequest_group_clears)}")
    print(f"  preservedEmptyRequiredRaceClears: {len(preserved_empty_required_race_clears)}")
    print(f"  preservedGroupAsSinglePreQuests: {len(preserved_group_as_single_prequest)}")
    print(f"  preservedRequiredSourceItemSupersets: {len(preserved_required_source_item_supersets)}")
    print(f"  objectiveDisplayRisks: {len(objective_display_risks)}")

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
                    "preservedObjectiveExpansions": preserved_objective_expansions,
                    "preservedDisplayObjectives": preserved_display_objectives,
                    "preservedEmptyPreQuestClears": preserved_empty_prequest_clears,
                    "preservedEmptyPreQuestGroupClears": preserved_empty_prequest_group_clears,
                    "preservedEmptyRequiredRaceClears": preserved_empty_required_race_clears,
                    "preservedGroupAsSinglePreQuests": preserved_group_as_single_prequest,
                    "preservedRequiredSourceItemSupersets": preserved_required_source_item_supersets,
                    "objectiveDisplayRisks": objective_display_risks,
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
        suggestion_path.write_text(build_lua_suggestions(mismatches, acore_metadata, constants), encoding="utf-8")
        print(f"Lua suggestions written to {suggestion_path}")


if __name__ == "__main__":
    main()
