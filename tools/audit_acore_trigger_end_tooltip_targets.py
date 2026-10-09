import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path


sys.dont_write_bytecode = True
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import validate_acore_quest_metadata as validator  # noqa: E402


QUEST_FIX_FILES = (
    Path("Database/Corrections/classicQuestFixes.lua"),
    Path("Database/Corrections/tbcQuestFixes.lua"),
    Path("Database/Corrections/wotlkQuestFixes.lua"),
)

QUEST_ROW_RE = re.compile(r"^\s{8}\[(\d+)\]\s*=\s*\{")
TOOLTIP_TARGET_RE = re.compile(
    r"QuestieCorrections\.triggerEndTooltipTargets\[(\d+)\]\s*=\s*\{(.*)\}"
)
TARGET_RE = re.compile(r'\{\s*"(monster|object|item)"\s*,\s*(\d+)\s*\}')
CPP_COMPLETION_RE = re.compile(
    r"(?:GroupEventHappens|AreaExploredOrEventHappens|CompleteQuest)\s*\(([^);]+)"
)

SMART_ACTION_NAMES = {
    15: "area explored/event happens",
    26: "group event happens",
    53: "start generic escort",
    55: "stop generic escort",
}

# These matches are deliberately not emitted as tooltip targets. The entity that
# grants AC credit is absent, hidden, redundant, or not the semantic objective.
REVIEW_REASONS = {
    437: "Area trigger; no hoverable entity.",
    1719: "Twiggy controls the event, but the triggerEnd step is entering the grate area.",
    2969: "Kindal controls a multi-creature Sprite Darter rescue counter.",
    5944: "Tirion grants final credit but is not the escort/event objective represented by triggerEnd.",
    6622: "Doctor Gregory controls the event; the Horde patients are the interacted entities.",
    6624: "Doctor Gustaf controls the event; the Alliance patients are the interacted entities.",
    6641: "Muglash grants credit, while Vorsha is the named combat target.",
    7622: "Eris controls a multi-actor rescue/defense event.",
    8447: "Keeper Remulos controls the scripted sequence rather than representing its objective.",
    8519: "Anachronos controls the narrated event rather than representing its objective.",
    8736: "Credit can flow through Remulos, Eranikus, and Nightmare Phantasms.",
    9686: "The Second Trial spans Master Kelerun and four champions.",
    9759: "Legoso grants credit for the separate Vector Coil and Sironas goals.",
    9991: "Altruis starts the flight; the triggerEnd objective is surveying two locations.",
    10269: "Area trigger; no hoverable entity.",
    10275: "Area trigger; no hoverable entity.",
    10525: "Spell-driven completion; no direct hoverable entity.",
    10594: "Spell-driven completion; no direct hoverable entity.",
    11097: "Commander Hobb controls a multi-creature defense event.",
    11101: "Commander Arcus controls a multi-creature defense event.",
    11108: "Yarzill grants credit for meeting Illidan; the quest is disabled in corrections.",
    11131: "Holiday fire event; no single direct hoverable entity.",
    11219: "Holiday fire event; no single direct hoverable entity.",
    11711: "The Valiance Keep Officer grants credit for delivering a separate deserter.",
    11975: "Completion uses invisible Children's Week trigger creatures.",
    12135: "Holiday fire event; no single direct hoverable entity.",
    12139: "Holiday fire event; no single direct hoverable entity.",
    12427: "Grennix grants credit; Ironhide already has a normal Questie objective.",
    12428: "Grennix grants credit; Torgg already has a normal Questie objective.",
    12429: "Grennix grants credit; Rustblood already has a normal Questie objective.",
    12430: "Grennix grants credit; Horgrenn already has a normal Questie objective.",
    13929: "Completion uses an invisible Children's Week trigger creature.",
    13930: "Completion uses an invisible Children's Week trigger creature.",
    13933: "High-Oracle Soo-roo is the destination NPC, not the player's orphan Roo.",
    13934: "Elder Kekek is the destination NPC, not the player's orphan Kekek.",
    13950: "Winterfin Playmate is the destination NPC, not the player's orphan Roo.",
    13951: "Snowfall Glade Playmate is the destination NPC, not the player's orphan Kekek.",
}


def load_trigger_ends(addon_root):
    records = {}
    for relative_path in QUEST_FIX_FILES:
        quest_id = None
        path = addon_root / relative_path
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            quest_match = QUEST_ROW_RE.match(line)
            if quest_match:
                quest_id = int(quest_match.group(1))
            if quest_id is None or "[questKeys.triggerEnd]" not in line:
                continue
            if re.search(r"=\s*(?:nil|false)\s*,?\s*$", line):
                records.pop(quest_id, None)
                continue
            text_match = re.search(r'=\s*\{\s*"((?:\\.|[^"\\])*)"', line)
            records[quest_id] = {
                "file": relative_path.as_posix(),
                "line": line_number,
                "text": text_match.group(1) if text_match else "",
            }
    return records


def load_configured_targets(addon_root):
    configured = {}
    for relative_path in QUEST_FIX_FILES:
        path = addon_root / relative_path
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = TOOLTIP_TARGET_RE.search(line)
            if not match:
                continue
            quest_id = int(match.group(1))
            targets = [(kind, int(entry)) for kind, entry in TARGET_RE.findall(match.group(2))]
            if not targets:
                raise ValueError(f"No tooltip targets parsed at {relative_path}:{line_number}")
            if quest_id in configured:
                raise ValueError(f"Duplicate triggerEnd tooltip target definition for quest {quest_id}")
            configured[quest_id] = {
                "file": relative_path.as_posix(),
                "line": line_number,
                "targets": targets,
            }
    return configured


def load_effective_questie_metadata(addon_root):
    constants = validator.load_constants(addon_root)
    metadata = validator.load_questie_base_metadata(
        addon_root / "Database/questDB.lua",
        constants["quest_keys"],
        constants,
    )
    for relative_path in QUEST_FIX_FILES:
        overrides = validator.load_questie_correction_file(addon_root / relative_path, constants)
        validator.apply_questie_overrides(metadata, overrides)
    return metadata


def build_action_list_callers(smart_rows):
    callers = defaultdict(list)
    for row in smart_rows:
        action_type = int(row.get("action_type") or 0)
        if action_type == 80:
            callers[int(row.get("action_param1") or 0)].append(row)
        elif action_type == 87:
            for index in range(1, 7):
                action_list_id = int(row.get(f"action_param{index}") or 0)
                if action_list_id:
                    callers[action_list_id].append(row)
        elif action_type == 88:
            low = int(row.get("action_param1") or 0)
            high = int(row.get("action_param2") or 0)
            if 0 < low <= high and high - low <= 100:
                for action_list_id in range(low, high + 1):
                    callers[action_list_id].append(row)
    return callers


def resolve_smart_sources(row, callers, creature_spawns, object_spawns, seen=None):
    seen = set() if seen is None else seen
    source_type = int(row.get("source_type") or 0)
    entry_or_guid = int(row.get("entryorguid") or 0)
    key = (source_type, entry_or_guid)
    if key in seen:
        return set()
    seen.add(key)

    if source_type == 0:
        if entry_or_guid < 0:
            spawn = creature_spawns.get(-entry_or_guid, {})
            entry_or_guid = int(
                spawn.get("id1") or spawn.get("id") or spawn.get("entry") or 0
            )
        return {("monster", entry_or_guid)} if entry_or_guid else set()
    if source_type == 1:
        if entry_or_guid < 0:
            spawn = object_spawns.get(-entry_or_guid, {})
            entry_or_guid = int(spawn.get("id") or spawn.get("entry") or 0)
        return {("object", entry_or_guid)} if entry_or_guid else set()
    if source_type != 9:
        return set()

    result = set()
    for caller in callers.get(entry_or_guid, []):
        result.update(
            resolve_smart_sources(caller, callers, creature_spawns, object_spawns, seen)
        )
    return result


def collect_smart_evidence(source_root, trigger_ids, creature_spawns, object_spawns):
    smart_rows = validator.load_acore_sql_rows(
        source_root,
        "smart_scripts",
        ("entryorguid", "source_type", "id", "link"),
    )
    callers = build_action_list_callers(smart_rows)
    evidence = defaultdict(list)
    matched_quests = set()

    for row in smart_rows:
        action_type = int(row.get("action_type") or 0)
        if action_type in (15, 26):
            quest_id = int(row.get("action_param1") or 0)
        elif action_type == 53:
            quest_id = int(row.get("action_param4") or 0)
        elif action_type == 55 and not int(row.get("action_param3") or 0):
            quest_id = int(row.get("action_param2") or 0)
        else:
            continue
        if quest_id not in trigger_ids:
            continue

        matched_quests.add(quest_id)
        targets = resolve_smart_sources(
            row,
            callers,
            creature_spawns,
            object_spawns,
        )
        comment = str(row.get("comment") or "").strip()
        proof = f"smart_scripts action {action_type} ({SMART_ACTION_NAMES[action_type]})"
        if comment:
            proof += f": {comment}"
        for target in targets:
            evidence[(quest_id, *target)].append(proof)

    return evidence, matched_quests


def collect_cpp_evidence(source_root, trigger_ids, creature_rows, object_rows):
    creatures_by_script = defaultdict(list)
    for entry, row in creature_rows.items():
        script_name = str(row.get("ScriptName") or "")
        if script_name:
            creatures_by_script[script_name].append(entry)
    objects_by_script = defaultdict(list)
    for entry, row in object_rows.items():
        script_name = str(row.get("ScriptName") or "")
        if script_name:
            objects_by_script[script_name].append(entry)

    evidence = defaultdict(list)
    matched_quests = set()
    scripts_root = source_root / "src/server/scripts"
    for path in scripts_root.rglob("*.cpp"):
        text = path.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        constants = {
            name: int(value)
            for name, value in re.findall(r"\b([A-Z][A-Z0-9_]*)\s*=\s*(\d+)\b", text)
        }
        for line_number, line in enumerate(lines, 1):
            match = CPP_COMPLETION_RE.search(line)
            if not match:
                continue
            expression = match.group(1).strip()
            quest_ids = set()
            if expression.isdigit():
                quest_ids.add(int(expression))
            for name in re.findall(r"\b[A-Z][A-Z0-9_]*\b", expression):
                if name in constants:
                    quest_ids.add(constants[name])
            quest_ids &= trigger_ids
            if not quest_ids:
                continue

            prefix = "\n".join(lines[max(0, line_number - 300):line_number])
            owners = re.findall(
                r"(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_]*)\s*"
                r"(?::\s*public[^\n{]+)?\s*\{",
                prefix,
            )
            owner = owners[-1] if owners else ""
            owner_variants = {owner, owner[:-2] if owner.endswith("AI") else owner}
            target_keys = set()
            for variant in owner_variants:
                target_keys.update(("monster", entry) for entry in creatures_by_script.get(variant, []))
                target_keys.update(("object", entry) for entry in objects_by_script.get(variant, []))

            relative_path = path.relative_to(source_root).as_posix()
            proof = f"{relative_path}:{line_number}: {line.strip()}"
            for quest_id in quest_ids:
                matched_quests.add(quest_id)
                for target_type, target_id in target_keys:
                    evidence[(quest_id, target_type, target_id)].append(proof)

    return evidence, matched_quests


def target_name(target_type, target_id, creature_rows, object_rows, item_rows):
    if target_type == "monster":
        return str(creature_rows.get(target_id, {}).get("name") or "")
    if target_type == "object":
        return str(object_rows.get(target_id, {}).get("name") or "")
    return str(item_rows.get(target_id, {}).get("name") or "")


def target_is_normal_objective(metadata, quest_id, target_type, target_id):
    objectives = metadata.get(quest_id, {}).get("objectives", ((), (), ()))
    category = {"monster": 0, "object": 1, "item": 2}[target_type]
    if category >= len(objectives):
        return False
    return any(record and int(record[0]) == target_id for record in objectives[category])


def escape_markdown(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def build_report(addon_root, source_root):
    trigger_ends = load_trigger_ends(addon_root)
    configured = load_configured_targets(addon_root)
    questie_metadata = load_effective_questie_metadata(addon_root)
    trigger_ids = set(trigger_ends)

    quest_rows = validator.load_acore_sql_table(source_root, "quest_template")
    creature_rows = validator.load_acore_sql_table(
        source_root, "creature_template", key_column="entry"
    )
    object_rows = validator.load_acore_sql_table(
        source_root, "gameobject_template", key_column="entry"
    )
    item_rows = validator.load_acore_sql_table(source_root, "item_template", key_column="entry")
    creature_spawns = validator.load_acore_sql_table(
        source_root, "creature", key_column="guid"
    )
    object_spawns = validator.load_acore_sql_table(
        source_root, "gameobject", key_column="guid"
    )

    smart_evidence, smart_quests = collect_smart_evidence(
        source_root,
        trigger_ids,
        creature_spawns,
        object_spawns,
    )
    cpp_evidence, cpp_quests = collect_cpp_evidence(
        source_root,
        trigger_ids,
        creature_rows,
        object_rows,
    )
    all_evidence = defaultdict(list)
    for source in (smart_evidence, cpp_evidence):
        for key, values in source.items():
            all_evidence[key].extend(values)

    failures = []
    rows = []
    for quest_id, definition in sorted(configured.items()):
        trigger = trigger_ends.get(quest_id)
        if not trigger:
            failures.append(f"Quest {quest_id} has tooltip targets but no effective triggerEnd correction")
        quest = quest_rows.get(quest_id, {})
        for target_type, target_id in definition["targets"]:
            name = target_name(target_type, target_id, creature_rows, object_rows, item_rows)
            proof = all_evidence.get((quest_id, target_type, target_id), [])
            if not name:
                failures.append(f"Quest {quest_id} target {target_type}:{target_id} is absent from AC templates")
            if not proof:
                failures.append(f"Quest {quest_id} target {target_type}:{target_id} has no direct AC proof")
            if target_is_normal_objective(
                questie_metadata, quest_id, target_type, target_id
            ):
                failures.append(
                    f"Quest {quest_id} target {target_type}:{target_id} already has a normal objective"
                )
            rows.append(
                {
                    "quest_id": quest_id,
                    "quest": str(quest.get("LogTitle") or ""),
                    "trigger": trigger["text"] if trigger else "",
                    "target": f"{target_type}:{target_id} {name}".strip(),
                    "proof": "<br>".join(proof),
                }
            )

    matched_quests = smart_quests | cpp_quests
    unclassified_matches = sorted(matched_quests - set(configured) - set(REVIEW_REASONS))
    if unclassified_matches:
        failures.append(
            "AC completion matches lack a direct mapping or review reason: "
            + ", ".join(map(str, unclassified_matches))
        )

    lines = [
        "# AzerothCore triggerEnd tooltip-target audit",
        "",
        f"- AzerothCore source: `{source_root}`",
        f"- Effective Questie triggerEnd corrections: {len(trigger_ids)}",
        f"- Direct configured quests: {len(configured)}",
        f"- Direct configured targets: {len(rows)}",
        f"- SmartAI completion matches: {len(smart_quests)}",
        f"- C++ completion matches: {len(cpp_quests)}",
        f"- Unique completion matches: {len(matched_quests)}",
        f"- Explicitly reviewed but not configured: {len(REVIEW_REASONS)}",
        f"- Completion-path matches not found: {len(trigger_ids - matched_quests)}",
        f"- Validation failures: {len(failures)}",
        "",
        "## Direct configured targets",
        "",
        "Each row requires an effective triggerEnd correction, a valid AC entity, a direct AC completion path from that entity, and no identical normal Questie objective.",
        "",
        "| Quest | triggerEnd | Tooltip target | AC proof |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['quest_id']} {escape_markdown(row['quest'])} | "
            f"{escape_markdown(row['trigger'])} | {escape_markdown(row['target'])} | "
            f"{escape_markdown(row['proof'])} |"
        )

    lines.extend([
        "",
        "## Reviewed but not configured",
        "",
        "| Quest | Reason |",
        "| --- | --- |",
    ])
    for quest_id, reason in sorted(REVIEW_REASONS.items()):
        quest_name = str(quest_rows.get(quest_id, {}).get("LogTitle") or "")
        lines.append(
            f"| {quest_id} {escape_markdown(quest_name)} | {escape_markdown(reason)} |"
        )

    if failures:
        lines.extend(["", "## Validation failures", ""])
        lines.extend(f"- {escape_markdown(failure)}" for failure in failures)

    return "\n".join(lines) + "\n", failures


def main():
    parser = argparse.ArgumentParser(
        description="Audit Questie triggerEnd tooltip targets against effective AzerothCore data."
    )
    parser.add_argument("--acore-source", required=True, type=Path)
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("tools/reports/acore_trigger_end_tooltip_targets.md"),
    )
    args = parser.parse_args()

    addon_root = Path(__file__).resolve().parents[1]
    report, failures = build_report(addon_root, args.acore_source)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(report, encoding="utf-8")
    print(report.split("\n\n", 1)[1].split("\n\n", 1)[0])
    print(f"Report written to {args.report}")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
