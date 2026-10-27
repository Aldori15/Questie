import ast
import math
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
    load_acore_sql_table,
    parse_sql_value,
    split_sql_rows,
    split_sql_statements,
    split_sql_values,
    strip_sql_comments,
)


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


def load_row_table(source_root, table_name, key_columns, include_modules=False, column_defaults=None):
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
                skipped_mutations += apply_multirow_insert(statement, table_name, columns, rows, key_columns, sql_context,
                                                          column_defaults=column_defaults)
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
    column_defaults=None,
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
        row = dict(column_defaults or {})
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
    # Quoted text is literal SQL data, even when it contains @ or leading zeros.
    if value[0] in {"'", '"'} and value[-1] == value[0]:
        return ast.literal_eval(value)
    if "@" in value and not context:
        raise ValueError("SQL variables are not supported in bulk inserts")
    value = replace_sql_variables(value, context)
    value = re.sub(r"(?<![\w.])0+([1-9]\d*)\b", r"\1", value)
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

        if depth == 0 and (index == 0 or not (where_clause[index - 1].isalnum() or where_clause[index - 1] == "_")):
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

        if depth == 0 and (index == 0 or not (where_clause[index - 1].isalnum() or where_clause[index - 1] == "_")):
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
    where_clause = strip_wrapping_parentheses(where_clause)
    # SQL AND binds more tightly than OR; BETWEEN's AND is not a boolean split.
    or_clauses = split_or_clauses(where_clause)
    if or_clauses:
        branches = [parse_where_constraints(clause, context) for clause in or_clauses]
        return None if any(branch is None for branch in branches) else {"__or_0": ("or", branches)}
    constraints = {}
    clauses = split_where_clauses(where_clause)
    if clauses is None:
        return None
    if len(clauses) > 1:
        branches = [parse_where_constraints(clause, context) for clause in clauses]
        return None if any(branch is None for branch in branches) else {"__and_0": ("and", branches)}
    for raw_clause in clauses:
        clause = strip_wrapping_parentheses(raw_clause)
        match = re.fullmatch(r"\((?P<columns>[^()]+)\)\s+IN\s*\((?P<values>.*)\)", clause, re.IGNORECASE | re.DOTALL)
        if match:
            columns = [column.strip().strip("`").lower() for column in split_sql_values(match.group("columns"))]
            if len(columns) < 2 or any(not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", column) for column in columns):
                return None
            values = set()
            for token in split_sql_values(match.group("values")):
                token = token.strip()
                if not token.startswith("(") or not token.endswith(")"):
                    return None
                try:
                    parts = tuple(parse_insert_sql_value(part, context) for part in split_sql_values(token[1:-1]))
                    if len(parts) != len(columns) or any(part is None for part in parts):
                        return None
                    values.add(parts)
                except Exception:
                    return None
            if not values:
                return None
            constraints[f"__tuple_{len(constraints)}"] = ("tuple_in", columns, values)
            continue
        match = re.fullmatch(r"`?([A-Za-z0-9_]+)`?\s*IN\s*\((.*)\)\s*", clause, re.IGNORECASE | re.DOTALL)
        if match:
            values = set()
            for token in split_sql_values(match.group(2)):
                token = token.strip()
                try:
                    values.add(parse_insert_sql_value(token, context))
                except Exception:
                    return None
            constraints[match.group(1).lower()] = values
            continue

        match = re.match(r"`?([A-Za-z0-9_]+)`?\s+BETWEEN\s+(.+?)\s+AND\s+(.+)$", clause, re.IGNORECASE | re.DOTALL)
        if match:
            try:
                constraints[match.group(1).lower()] = ("between", parse_insert_sql_value(match.group(2), context),
                                                     parse_insert_sql_value(match.group(3), context))
            except Exception:
                return None
            continue

        match = re.match(r"`?([A-Za-z0-9_]+)`?\s*=\s*(.+)$", clause, re.IGNORECASE | re.DOTALL)
        if match:
            token = match.group(2).strip()
            try:
                constraints[match.group(1).lower()] = {parse_insert_sql_value(token, context)}
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
        if isinstance(values, tuple) and values and values[0] == "tuple_in":
            if tuple(lower_row.get(name) for name in values[1]) not in values[2]:
                return False
            continue
        if isinstance(values, tuple) and values and values[0] == "or":
            if not any(row_matches_constraints(row, sub_constraints) for sub_constraints in values[1]):
                return False
            continue
        if isinstance(values, tuple) and values and values[0] == "and":
            if not all(row_matches_constraints(row, sub_constraints) for sub_constraints in values[1]):
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


def record_source_issue(diagnostics, kind, value):
    if diagnostics is not None:
        diagnostics.setdefault(kind, set()).add(int(value))


def add_item_sources_from_loot(rows, reference_index, source_to_object_ids=None, object_primary_items=None, diagnostics=None,
                               loot_modes=None):
    object_primary_items = object_primary_items or set()
    per_item = defaultdict(set)
    grouped = defaultdict(list)
    for row in rows:
        grouped[int(row["Entry"])].append(row)

    reference_cache = {}
    for source_id, source_rows in grouped.items():
        source_ids = {source_id} if source_to_object_ids is None else source_to_object_ids.get(source_id, ())
        if not source_ids:
            record_source_issue(diagnostics, "unmappedLootSourceEntries", source_id)
            continue
        item_chances = resolve_loot_row_chances(source_rows, reference_index, reference_cache=reference_cache,
                                               diagnostics=diagnostics, loot_modes=loot_modes)
        for item_id, chance in item_chances.items():
            if item_id in object_primary_items and chance <= LOW_CHANCE_CREATURE_DROP_THRESHOLD:
                continue
            for resolved_source_id in source_ids:
                per_item[item_id].add(resolved_source_id)
    return per_item


def resolve_loot_rows(rows, reference_index, seen=None):
    return set(resolve_loot_row_chances(rows, reference_index, seen))


def resolve_loot_row_chances(rows, reference_index, seen=None, quest_required_only=False,
                             reference_cache=None, diagnostics=None, loot_modes=None):
    """Base at-least-once chances, unioned over loot modes (no rates/scripts).

    Match LootGroup::Roll: explicit entries consume the group roll first, then
    zero-chance entries share its remainder. Filter quest results AFTER rolling
    so non-quest siblings still contribute to the selection denominator.
    """
    reference_cache = reference_cache if reference_cache is not None else {}

    def combine(first, second):
        return first + second - first * second / 100.0

    def repeated(chance, count):
        if chance >= 100:
            return 100.0
        return -100.0 * math.expm1(count * math.log1p(-chance / 100.0))

    def outcomes(row, mode, active):
        reference = abs(int(row.get("Reference") or 0))
        if not reference:
            item_id = int(row.get("Item") or 0)
            if item_id > 0 and (not quest_required_only or int(row.get("QuestRequired") or 0) == 1):
                return {item_id: 100.0}
            return {}
        if reference in active:
            record_source_issue(diagnostics, "lootReferenceCycles", reference)
            return {}
        if reference not in reference_index:
            record_source_issue(diagnostics, "missingLootReferences", reference)
            return {}
        count = max(0, int(row.get("MaxCount", 1) or 0))
        if count == 0:
            return {}
        # Include the active path: a cycle-pruned result must not leak into a
        # later traversal that reaches the same reference through another path.
        key = reference, mode, quest_required_only, active
        if key not in reference_cache:
            reference_cache[key] = resolve_mode(reference_index[reference], mode, active | {reference})
        return {item_id: repeated(chance, count)
                for item_id, chance in reference_cache[key].items()}

    def resolve_mode(template, mode, active):
        resolved, groups = defaultdict(float), defaultdict(list)
        for row in template:
            if not (int(row.get("LootMode", 1) or 0) & mode):
                continue
            group = int(row.get("GroupId") or 0)
            chance = float(row.get("Chance") or 0)
            if group > 0 and chance >= 0:
                groups[group].append(row)
            elif group == 0 and chance > 0:
                for item_id, nested_chance in outcomes(row, mode, active).items():
                    resolved[item_id] = combine(resolved[item_id], min(100.0, chance) * nested_chance / 100.0)
        for group_rows in groups.values():
            remaining, selections, equal_rows = 100.0, [], []
            for row in group_rows:
                chance = float(row.get("Chance") or 0)
                if chance > 0:
                    selected = min(remaining, chance)
                    remaining -= selected
                    selections.append((row, selected))
                else:
                    equal_rows.append(row)
            if equal_rows and remaining > 0:
                selections.extend((row, remaining / len(equal_rows)) for row in equal_rows)
            grouped_results = defaultdict(float)
            for row, selected in selections:
                if selected <= 0:
                    continue
                for item_id, nested_chance in outcomes(row, mode, active).items():
                    grouped_results[item_id] += selected * nested_chance / 100.0
            for item_id, chance in grouped_results.items():
                resolved[item_id] = combine(resolved[item_id], min(100.0, chance))
        return dict(resolved)

    mask = 0
    for row in rows:
        mask |= max(0, int(row.get("LootMode", 1) or 0))
    if loot_modes is None:
        modes = [1 << bit for bit in range(mask.bit_length()) if mask & (1 << bit)]
    else:
        modes = sorted(set(loot_modes))
        if any(type(mode) is not int or not 0 < mode <= 65535 for mode in modes):
            raise ValueError("Invalid source-defined loot mode")
    resolved = {}
    for mode in modes:
        for item_id, chance in resolve_mode(rows, mode, frozenset(seen or ())).items():
            if chance > 0:
                resolved[item_id] = max(resolved.get(item_id, 0), chance)
    return resolved


def build_object_primary_item_ids(gameobject_loot_rows, reference_index, diagnostics=None):
    object_primary_items = set()
    grouped = defaultdict(list)
    for row in gameobject_loot_rows:
        grouped[int(row["Entry"])].append(row)

    reference_cache = {}
    for source_rows in grouped.values():
        for item_id, chance in resolve_loot_row_chances(source_rows, reference_index, quest_required_only=True,
                                                       reference_cache=reference_cache, diagnostics=diagnostics).items():
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


def build_creature_loot_source_map(creature_template_rows, loot_column="lootid"):
    if loot_column not in {"lootid", "pickpocketloot", "skinloot"}:
        raise ValueError("Unsupported creature loot template column: " + loot_column)
    source_map = defaultdict(set)
    for row in creature_template_rows.values():
        loot_id = int(row.get(loot_column) or 0)
        if loot_id > 0:
            source_map[loot_id].add(int(row["entry"]))
    return source_map


def add_item_sources_from_spellclick(npc_spellclick_rows, spell_rows, valid_item_ids=None,
                                      valid_npc_ids=None, diagnostics=None):
    per_item = defaultdict(set)
    for row in npc_spellclick_rows:
        npc_id = int(row.get("npc_entry") or 0)
        spell_id = int(row.get("spell_id") or 0)
        if not npc_id or not spell_id:
            continue
        if valid_npc_ids is not None and npc_id not in valid_npc_ids:
            record_source_issue(diagnostics, "unknownSpellclickNpcIds", npc_id)
            continue

        spell = spell_rows.get(spell_id)
        if not spell:
            record_source_issue(diagnostics, "missingSpellclickSpellIds", spell_id)
            continue

        for index in range(1, 4):
            item_id = int(spell.get(f"EffectItemType_{index}") or 0)
            if item_id <= 0:
                continue
            if int(spell.get(f"Effect_{index}") or 0) not in {24, 157}:  # CREATE_ITEM / CREATE_ITEM_2
                record_source_issue(diagnostics, "nonCreationSpellclickItemValues", item_id)
                continue
            if valid_item_ids is not None and item_id not in valid_item_ids:
                record_source_issue(diagnostics, "unknownSpellclickItemIds", item_id)
                continue
            per_item[item_id].add(npc_id)
    return per_item


def build_item_vendor_sources(rows, valid_item_ids, valid_vendor_ids, diagnostics=None):
    """Expand npc_vendor references while retaining the original seller ID."""
    by_vendor, result, cache = defaultdict(list), defaultdict(set), {}
    for row in rows:
        by_vendor[int(row.get("entry") or 0)].append(row)

    def resolve(vendor, active):
        if vendor in active:
            record_source_issue(diagnostics, "vendorReferenceCycles", vendor)
            return set()
        if vendor not in by_vendor:
            record_source_issue(diagnostics, "missingVendorReferences", vendor)
            return set()
        key = vendor, active
        if key not in cache:
            items = set()
            for row in by_vendor[vendor]:
                item_id = int(row.get("item") or 0)
                if item_id < 0:
                    items.update(resolve(-item_id, active | {vendor}))
                elif item_id in valid_item_ids:
                    items.add(item_id)
                elif item_id:
                    record_source_issue(diagnostics, "unknownVendorItemIds", item_id)
            cache[key] = items
        return cache[key]

    for vendor in sorted(by_vendor):
        if vendor not in valid_vendor_ids:
            record_source_issue(diagnostics, "nonCreatureVendorEntries", vendor)
            continue
        for item_id in resolve(vendor, frozenset()):
            result[item_id].add(vendor)
    return result


def validate_loot_items(rows, valid_item_ids, diagnostics):
    valid = []
    for row in rows:
        item_id = int(row.get("Item") or 0)
        reference = int(row.get("Reference") or 0)
        group = int(row.get("GroupId") or 0)
        minimum = int(row.get("MinCount", 1) or 0)
        maximum = int(row.get("MaxCount", 1) or 0)
        if not 0 <= group < 128 or minimum < 1 or (not reference and maximum < minimum):
            record_source_issue(diagnostics, "invalidLootEntryIds", row.get("Entry") or 0)
            continue
        if reference or item_id in valid_item_ids:
            valid.append(row)
        else:
            record_source_issue(diagnostics, "unknownLootItemIds", item_id)
    return valid


def known_item_reference(item_id, valid_item_ids, diagnostics, kind):
    if item_id > 0 and item_id in valid_item_ids:
        return True
    if item_id:
        record_source_issue(diagnostics, kind, item_id)
    return False


def build_creature_guid_to_entry(creature_rows):
    mapping = {}
    for row in creature_rows.values():
        guid = row.get("guid")
        entry = row.get("id") or row.get("entry") or row.get("id1")
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


def load_item_source_spells(source_root, sql_spells, spell_ids, spell_sql=None, spell_table="spell",
                            follow_triggers=False, trigger_roots=None):
    """Load numeric effect inputs for direct and bounded triggered acquisitions.

    Match DBCStores/DBCDatabaseLoader: SQL records replace DBC numeric values,
    including zeros. Trigger discovery uses the overlaid records so a SQL zero
    can remove a DBC trigger instead of accidentally retaining its old grant.
    """
    fields = [f"{prefix}_{index}" for prefix in ("Effect", "EffectItemType") for index in range(1, 4)]

    trigger_fields = [f"{prefix}_{index}" for prefix in ("EffectTriggerSpell", "EffectBasePoints", "EffectDieSides")
                      for index in range(1, 4)] + ["AttributesEx"]

    def normalize(row):
        return {field: int(row.get(field, row.get(field.replace("_", ""), 0)) or 0)
                for field in fields + ["RequiresSpellFocus"] +
                [f"EffectApplyAuraName_{index}" for index in range(1, 4)] +
                [f"EffectImplicitTarget{side}_{index}" for side in ("A", "B") for index in range(1, 4)] + trigger_fields}

    spells, exported_ids = {}, set()
    requested = set(spell_ids)
    coverage = {"exportProvided": spell_sql is not None, "requestedSpellIds": len(spell_ids),
                "exportRowsLoaded": 0, "sqlRowsLoaded": len(sql_spells), "exportIdsOverriddenBySql": 0}
    if spell_sql is not None:
        spell_sql = Path(spell_sql)
        if not spell_sql.is_file():
            raise ValueError(f"Spell SQL export not found: {spell_sql}")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", spell_table):
            raise ValueError("Spell export table must be a simple SQL table name")
        columns = extract_sql_columns(spell_sql, spell_table)
        if "ID" not in columns or any(field not in columns and field.replace("_", "") not in columns for field in fields):
            raise ValueError("Spell export must contain ID, Effect1..3 and EffectItemType1..3 (underscored names also accepted)")
        extended_fields = trigger_fields + ["RequiresSpellFocus"] + [
            f"{prefix}_{i}" for prefix in ("EffectApplyAuraName", "EffectImplicitTargetA", "EffectImplicitTargetB")
            for i in range(1, 4)]
        if follow_triggers and any(field not in columns and field.replace("_", "") not in columns
                                   for field in extended_fields):
            raise ValueError("Triggered acquisitions require complete trigger, aura and channel fields in the spell export")
        exported = load_acore_sql_table(Path(source_root), spell_table, base_file_override=spell_sql,
                                       key_column="ID", wanted_keys=None if follow_triggers else requested)
        for spell_id, row in exported.items():
            if any(field not in row and field.replace("_", "") not in row for field in fields):
                raise ValueError(f"Incomplete numeric effect fields in exported spell {spell_id}")
            spells[int(spell_id)] = normalize(row)
        exported_ids = set(spells)
    # Replace each record rather than merging nonzero values: SQL zero is authoritative.
    spells.update({spell_id: normalize(row) for spell_id, row in sql_spells.items()})
    if follow_triggers:
        pending = list(requested if trigger_roots is None else set(trigger_roots))
        visited = set()
        while pending:
            current = pending.pop()
            if current in visited:
                continue
            visited.add(current)
            row = spells.get(current, {})
            for slot in range(1, 4):
                effect = int(row.get(f"Effect_{slot}") or 0)
                if effect != 64 and not (effect == 6 and int(row.get(f"EffectApplyAuraName_{slot}") or 0) == 23):
                    continue
                child = int(row.get(f"EffectTriggerSpell_{slot}") or 0)
                if child > 0:
                    requested.add(child)
                    if child not in visited:
                        pending.append(child)
        spells = {key: row for key, row in spells.items() if key in requested or key in sql_spells}
    coverage["requestedSpellIds"] = len(requested)
    coverage["exportRowsLoaded"] = len(exported_ids & requested)
    coverage["exportIdsOverriddenBySql"] = len(exported_ids & requested & set(sql_spells))
    coverage["resolvedRequestedSpellIds"] = len(requested & set(spells))
    coverage["missingRequestedSpellIds"] = len(requested - set(spells))
    coverage["missingRequestedSpellIdList"] = sorted(requested - set(spells))
    return spells, coverage


def build_acore_items(source_root, include_modules=False, spell_sql=None, spell_table="spell"):
    source_root = Path(source_root)
    item_rows, skipped_item_template = load_keyed_table(source_root, "item_template", "entry", include_modules)
    quest_rows, skipped_quest_template = load_keyed_table(source_root, "quest_template", "ID", include_modules)
    gameobject_template_rows, skipped_gameobject_template = load_keyed_table(source_root, "gameobject_template", "entry", include_modules)
    creature_template_rows, skipped_creature_template = load_keyed_table(source_root, "creature_template", "entry", include_modules)
    creature_rows, skipped_creature = load_keyed_table(source_root, "creature", "guid", include_modules)
    spell_rows, skipped_spell_dbc = load_keyed_table(source_root, "spell_dbc", "ID", include_modules)

    reference_rows, skipped_reference = load_row_table(source_root, "reference_loot_template", ("Entry", "Item"), include_modules)
    creature_loot_rows, skipped_creature_loot = load_row_table(source_root, "creature_loot_template", ("Entry", "Item"), include_modules)
    pickpocket_rows, skipped_pickpocket = load_row_table(source_root, "pickpocketing_loot_template", ("Entry", "Item"), include_modules)
    skinning_rows, skipped_skinning = load_row_table(source_root, "skinning_loot_template", ("Entry", "Item"), include_modules)
    gameobject_loot_rows, skipped_gameobject_loot = load_row_table(source_root, "gameobject_loot_template", ("Entry", "Item"), include_modules)
    item_loot_rows, skipped_item_loot = load_row_table(source_root, "item_loot_template", ("Entry", "Item"), include_modules)
    npc_vendor_rows, skipped_npc_vendor = load_row_table(source_root, "npc_vendor", ("entry", "item", "ExtendedCost"), include_modules)
    event_vendor_rows, skipped_event_vendor = load_row_table(source_root, "game_event_npc_vendor", ("eventEntry", "guid", "item"), include_modules)
    npc_spellclick_rows, skipped_npc_spellclick = load_row_table(source_root, "npc_spellclick_spells", ("npc_entry", "spell_id"), include_modules)
    smart_rows, skipped_smart = load_row_table(source_root, "smart_scripts", ("entryorguid", "source_type", "id", "link"), include_modules)
    spell_script_rows, skipped_spell_scripts = load_row_table(source_root, "spell_script_names", ("spell_id", "ScriptName"), include_modules)
    spell_command_rows, skipped_spell_commands = load_row_table(
        source_root, "spell_scripts", ("id", "effIndex", "delay", "command", "datalong", "datalong2", "dataint", "x", "y", "z", "o"), include_modules)
    spell_link_rows, skipped_spell_links = load_row_table(
        source_root, "spell_linked_spell", ("spell_trigger", "spell_effect", "type"), include_modules)
    ender_rows, skipped_enders = load_row_table(source_root, "creature_questender", ("id", "quest"), include_modules)
    object_ender_rows, skipped_object_enders = load_row_table(source_root, "gameobject_questender", ("id", "quest"), include_modules)
    starter_rows, skipped_starters = load_row_table(source_root, "creature_queststarter", ("id", "quest"), include_modules)
    object_starter_rows, skipped_object_starters = load_row_table(source_root, "gameobject_queststarter", ("id", "quest"), include_modules)
    disabled_rows, skipped_disabled = load_row_table(source_root, "disables", ("sourceType", "entry"), include_modules)
    active_quests = set(quest_rows) - {int(row["entry"]) for row in disabled_rows if int(row.get("sourceType") or 0) == 1}
    from validate_acore_quest_metadata import CONDITION_KEY_COLUMNS
    condition_rows, skipped_conditions = load_row_table(source_root, "conditions", CONDITION_KEY_COLUMNS, include_modules,
                                                       column_defaults={column: 0 for column in CONDITION_KEY_COLUMNS})
    spell_ids = {int(row["spell_id"]) for row in npc_spellclick_rows if int(row.get("spell_id") or 0) > 0}
    spell_ids.update(int(row.get("action_param1") or 0) for row in smart_rows
                     if int(row.get("action_type") or 0) in (11, 85, 86, 134) and int(row.get("action_param1") or 0) > 0)
    spell_ids.update(int(row.get("datalong") or 0) for row in spell_command_rows
                     if int(row.get("command") or 0) == 15 and int(row.get("datalong") or 0) > 0)
    spell_ids.update(int(row.get(f"spellid_{index}") or 0) for row in item_rows.values() for index in range(1, 6)
                     if int(row.get(f"spellid_{index}") or 0) > 0)
    spell_ids.update(int(row.get("Data10") or 0) for row in gameobject_template_rows.values()
                     if int(row.get("type") or 0) == 10 and int(row.get("Data10") or 0) > 0)
    import acore_item_compatibility
    import acore_item_spell_acquisitions
    spell_ids.update(acore_item_compatibility.bound_spell_ids(spell_script_rows))
    if any(row.get("ScriptName") == rule[2] for row in list(creature_template_rows.values()) + list(gameobject_template_rows.values())
           for rule in acore_item_compatibility.CPP_RULES):
        spell_ids.update(acore_item_compatibility.cpp_spell_ids(source_root))
    while True:
        linked_ids = {int(row.get("spell_effect") or 0) for row in spell_link_rows
                      if int(row.get("type") or 0) == 0
                      and abs(int(row.get("spell_trigger") or 0)) in spell_ids
                      and int(row.get("spell_effect") or 0) > 0}
        if linked_ids <= spell_ids:
            break
        spell_ids.update(linked_ids)
    item_use_spells = {int(row.get(f"spellid_{index}") or 0) for row in item_rows.values() for index in range(1, 6)
                       if int(row.get(f"spellid_{index}") or 0) > 0
                       and int(row.get(f"spelltrigger_{index}") or 0) in (0, 5)}
    spell_rows, spell_coverage = load_item_source_spells(source_root, spell_rows, spell_ids, spell_sql, spell_table,
                                                     follow_triggers=True, trigger_roots=item_use_spells)

    diagnostics = {}
    valid_item_ids = {item_id for item_id in item_rows if item_id > 0}
    for item_id in set(item_rows) - valid_item_ids:
        record_source_issue(diagnostics, "invalidTemplateItemIds", item_id)
    valid_npc_ids = {npc_id for npc_id in creature_template_rows if npc_id > 0}
    reference_rows = validate_loot_items(reference_rows, valid_item_ids, diagnostics)
    creature_loot_rows = validate_loot_items(creature_loot_rows, valid_item_ids, diagnostics)
    pickpocket_rows = validate_loot_items(pickpocket_rows, valid_item_ids, diagnostics)
    skinning_rows = validate_loot_items(skinning_rows, valid_item_ids, diagnostics)
    gameobject_loot_rows = validate_loot_items(gameobject_loot_rows, valid_item_ids, diagnostics)
    item_loot_rows = validate_loot_items(item_loot_rows, valid_item_ids, diagnostics)
    reference_index = defaultdict(list)
    for row in reference_rows:
        reference_index[int(row["Entry"])].append(row)
    gameobject_loot_source_map = build_gameobject_loot_source_map(gameobject_template_rows)
    mapped_object_loot_rows = [row for row in gameobject_loot_rows if int(row["Entry"]) in gameobject_loot_source_map]
    object_primary_items = build_object_primary_item_ids(mapped_object_loot_rows, reference_index, diagnostics)
    creature_loot_source_map = build_creature_loot_source_map(creature_template_rows)
    interaction_loot = defaultdict(set)
    for rows, column in ((pickpocket_rows, "pickpocketloot"), (skinning_rows, "skinloot")):
        mapped = build_creature_loot_source_map(creature_template_rows, column)
        for item_id, sources in add_item_sources_from_loot(rows, reference_index, mapped,
                                                         diagnostics=diagnostics).items():
            interaction_loot[item_id].update(sources)
    # Scripted boss modes can combine the default bit with a hard-mode bit.
    # References must receive that same combined mask at every depth.
    for actor, modes in acore_item_compatibility.collect_cpp_loot_modes(source_root, creature_template_rows).items():
        loot_id = int(creature_template_rows[actor].get("lootid") or 0)
        rows = [row for row in creature_loot_rows if int(row["Entry"]) == loot_id]
        for item_id, sources in add_item_sources_from_loot(
                rows, reference_index, {loot_id: {actor}}, diagnostics=diagnostics, loot_modes=modes).items():
            interaction_loot[item_id].update(sources)

    acore_items = {}
    for item_id, row in item_rows.items():
        if item_id not in valid_item_ids:
            continue
        item = {}
        for field, column in STATIC_FIELD_MAP.items():
            value = row.get(column)
            if value is not None:
                item[field] = value

        start_quest = int(row.get("startquest") or 0)
        if start_quest > 0 and start_quest in quest_rows:
            item["startQuest"] = start_quest
        acore_items[int(item_id)] = item

    creature_item_sources = add_item_sources_from_loot(
        creature_loot_rows, reference_index, source_to_object_ids=creature_loot_source_map,
        object_primary_items=object_primary_items, diagnostics=diagnostics)
    for field, per_item in (
        ("npcDrops", creature_item_sources),
        ("objectDrops", add_item_sources_from_loot(gameobject_loot_rows, reference_index,
                                                  gameobject_loot_source_map, diagnostics=diagnostics)),
        ("itemDrops", add_item_sources_from_loot(item_loot_rows, reference_index, diagnostics=diagnostics)),
    ):
        for item_id, source_ids in per_item.items():
            if not known_item_reference(item_id, valid_item_ids, diagnostics, "unknownLootItemIds"):
                continue
            if field == "itemDrops":
                for container in source_ids - valid_item_ids:
                    record_source_issue(diagnostics, "unknownItemLootContainers", container)
                source_ids = source_ids & valid_item_ids
            if source_ids:
                acore_items[item_id][field] = sorted(source_ids)

    for item_id, source_ids in add_item_sources_from_spellclick(npc_spellclick_rows, spell_rows, valid_item_ids,
                                                               valid_npc_ids, diagnostics).items():
        existing_sources = set(acore_items[item_id].get("npcDrops") or [])
        existing_sources.update(source_ids)
        acore_items[item_id]["npcDrops"] = sorted(existing_sources)

    for item_id, vendor_ids in build_item_vendor_sources(npc_vendor_rows, valid_item_ids, valid_npc_ids, diagnostics).items():
        acore_items[item_id].setdefault("vendors", set()).update(vendor_ids)

    creature_guid_to_entry = build_creature_guid_to_entry(creature_rows)
    for row in event_vendor_rows:
        item_id = int(row.get("item") or 0)
        guid = int(row.get("guid") or 0)
        vendor_id = creature_guid_to_entry.get(guid)
        if not known_item_reference(item_id, valid_item_ids, diagnostics, "unknownEventVendorItemIds"):
            continue
        if not vendor_id:
            record_source_issue(diagnostics, "unmappedEventVendorGuids", guid)
        elif vendor_id not in valid_npc_ids:
            record_source_issue(diagnostics, "unknownEventVendorNpcIds", vendor_id)
        else:
            acore_items[item_id].setdefault("vendors", set()).add(vendor_id)

    for item in acore_items.values():
        if isinstance(item.get("vendors"), set):
            item["vendors"] = sorted(item["vendors"])

    for quest_id, row in quest_rows.items():
        quest_id = int(quest_id)
        for column in ("RewardItem1", "RewardItem2", "RewardItem3", "RewardItem4"):
            item_id = int(row.get(column) or 0)
            if known_item_reference(item_id, valid_item_ids, diagnostics, "unknownQuestItemIds"):
                acore_items[item_id].setdefault("questRewards", set()).add(quest_id)
        for column in (
            "RewardChoiceItemID1",
            "RewardChoiceItemID2",
            "RewardChoiceItemID3",
            "RewardChoiceItemID4",
            "RewardChoiceItemID5",
            "RewardChoiceItemID6",
        ):
            item_id = int(row.get(column) or 0)
            if known_item_reference(item_id, valid_item_ids, diagnostics, "unknownQuestItemIds"):
                acore_items[item_id].setdefault("questRewards", set()).add(quest_id)
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
            if known_item_reference(item_id, valid_item_ids, diagnostics, "unknownQuestItemIds"):
                acore_items[item_id].setdefault("relatedQuests", set()).add(quest_id)
                # Mark items that appear in quest_template.StartItem so we can
                # treat them as quest items even when item_template.class
                # differs in AzerothCore's item_template.
                if column == "StartItem":
                    acore_items[item_id]["isStartItem"] = True

    for item in acore_items.values():
        for field in ("questRewards", "relatedQuests"):
            if isinstance(item.get(field), set):
                item[field] = sorted(item[field])
    indirect = acore_item_compatibility.collect(item_rows, creature_template_rows, gameobject_template_rows,
                                               smart_rows, spell_rows, condition_rows, spell_scripts=spell_command_rows,
                                               creature_spawns=creature_rows, spell_links=spell_link_rows)
    cpp_sources = acore_item_compatibility.collect_cpp(source_root, item_rows, creature_template_rows,
                                                      gameobject_template_rows, spell_rows, spell_links=spell_link_rows)
    bound_spell_sources = acore_item_compatibility.collect_bound_spells(
        source_root, item_rows, creature_template_rows, gameobject_template_rows, spell_rows, spell_script_rows)
    triggered_sources = acore_item_spell_acquisitions.collect(
        item_rows, creature_template_rows, gameobject_template_rows, smart_rows, spell_rows, condition_rows,
        source_root=source_root)
    corpse_sources = {"sourceKind": "creatureLoot", "sources": {
        str(item): {"npcDrops": sorted(npcs)} for item, npcs in creature_item_sources.items() if npcs}}
    summon_sources = acore_item_compatibility.collect_summon_handoffs(
        source_root, item_rows, creature_template_rows, gameobject_template_rows,
        (indirect, cpp_sources, bound_spell_sources, triggered_sources, corpse_sources),
        scripts=smart_rows, conditions=condition_rows)
    quest_enders = defaultdict(lambda: defaultdict(set))
    for field, relations in (("npcDrops", ender_rows), ("objectDrops", object_ender_rows)):
        for relation in relations:
            if int(relation["quest"]) in active_quests:
                quest_enders[int(relation["quest"])][field].add(int(relation["id"]))
    start_items = defaultdict(lambda: defaultdict(set))
    for field, relations, actors in (("npcDrops", starter_rows, valid_npc_ids),
                                     ("objectDrops", object_starter_rows, set(gameobject_template_rows))):
        for relation in relations:
            quest_id, actor = int(relation["quest"]), int(relation["id"])
            item_id = int(quest_rows.get(quest_id, {}).get("StartItem") or 0)
            if quest_id in active_quests and actor in actors and item_id in valid_item_ids:
                start_items[item_id][field].add(actor)
    for item_id, item in acore_items.items():
        item["questUseClass"] = acore_item_compatibility.quest_use_class(item_rows[item_id], item)
        sources = defaultdict(set)
        for packet in (indirect, cpp_sources, bound_spell_sources, triggered_sources, summon_sources):
            for field, values in packet["sources"].get(str(item_id), {}).items():
                sources[field].update(values)
        # Interaction loot supplies acquisition POIs without changing corpse
        # drop probabilities or expanding the manifest's item/source scope.
        if item_id in interaction_loot:
            sources["npcDrops"].update(interaction_loot[item_id])
        for field, actors in start_items[item_id].items():
            sources[field].update(actors)
        for quest in item.get("questRewards", ()):
            for field, values in quest_enders[quest].items():
                sources[field].update(values)
        item["indirectSources"] = {field: sorted(values) for field, values in sorted(sources.items())}
        item["questRelevant"] = bool((set(item.get("relatedQuests", ())) | set(item.get("questRewards", ())) |
                                      {int(item.get("startQuest") or 0)}) & active_quests)

    skipped_mutations = {
        "item_template": skipped_item_template,
        "quest_template": skipped_quest_template,
        "gameobject_template": skipped_gameobject_template,
        "creature_template": skipped_creature_template,
        "creature": skipped_creature,
        "spell_dbc": skipped_spell_dbc,
        "reference_loot_template": skipped_reference,
        "creature_loot_template": skipped_creature_loot,
        "pickpocketing_loot_template": skipped_pickpocket,
        "skinning_loot_template": skipped_skinning,
        "gameobject_loot_template": skipped_gameobject_loot,
        "item_loot_template": skipped_item_loot,
        "npc_vendor": skipped_npc_vendor,
        "game_event_npc_vendor": skipped_event_vendor,
        "npc_spellclick_spells": skipped_npc_spellclick,
        "smart_scripts": skipped_smart,
        "spell_script_names": skipped_spell_scripts,
        "spell_scripts": skipped_spell_commands,
        "spell_linked_spell": skipped_spell_links,
        "conditions": skipped_conditions,
        "creature_questender": skipped_enders,
        "gameobject_questender": skipped_object_enders,
        "creature_queststarter": skipped_starters,
        "gameobject_queststarter": skipped_object_starters,
        "disables": skipped_disabled,
    }
    source_context = {
        "spawnedCreatureIds": build_spawned_entry_ids(creature_rows, ("id", "entry", "id1", "id2", "id3")),
        "gameObjectTemplateIds": set(gameobject_template_rows),
        "sourceDiagnostics": {key: sorted(values) for key, values in sorted(diagnostics.items())},
        "spellCoverage": spell_coverage,
        "acquisitionCoverage": {"triggered": triggered_sources, "summonHandoffs": summon_sources},
    }
    return acore_items, skipped_mutations, source_context


def normalize_list(value):
    if not value:
        return ()
    return tuple(sorted({int(v) for v in value if v is not None}))


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


def main():
    raise SystemExit("Correction layers are retired. Use tools/generate_acore_item_base.py; "
                     "this module retains shared source-reading helpers.")


if __name__ == "__main__":
    main()
