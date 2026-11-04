"""Source-reviewed area-trigger completion guides; changed behavior stays unmapped."""
from collections import defaultdict
import hashlib
from pathlib import Path
import re

import acore_quest_cpp_events as cpp
from acore_item_compatibility import number


RECIPES = {
    "at_bring_your_orphan_to": {
        "file": "src/server/scripts/Events/childrens_week.cpp",
        "class": "at_bring_your_orphan_to",
        "sha256": "2241a330701d0a181e14d6f584a71cc09d78d0cf5220262d26ef8a5dcc289ddc",
        "kind": "orphan",
        "displayZones": {
            "AT_DOWN_AT_THE_DOCKS": (1, 17), "AT_GATEWAY_TO_THE_FRONTIER": (1, 17),
            "AT_LORDAERON_THRONE_ROOM": (0, 1497), "AT_BOUGHT_OF_ETERNALS": (1, 1657),
            "AT_SPOOKY_LIGHTHOUSE": (0, 40), "AT_STONEWROUGHT_DAM": (0, 38), "AT_DARK_PORTAL": (530, 3483),
        },
    },
    "at_celestial_planetarium_enterance": {
        "file": "src/server/scripts/Northrend/Ulduar/Ulduar/ulduar.cpp",
        "class": "AreaTrigger_at_celestial_planetarium_enterance",
        "sha256": "26ac8e6cedda65584fff1e0999eb4e504b7068bbd71666534e40a07ca4a49d38",
        "kind": "raid",
    },
}
CORE_SOURCE_FILES = tuple(sorted({recipe["file"] for recipe in RECIPES.values()}))


def class_digest(text):
    return hashlib.sha256(re.sub(r"\s+", "", cpp._mask(text, strings=False)).encode()).hexdigest()


def _orphan_pairs(body, constants):
    pairs = []
    pattern = r"\bcase\s+(\w+)\s*:\s*questId\s*=\s*([^;]+);\s*orphanId\s*=\s*[^;]+;\s*break\s*;"
    for match in re.finditer(pattern, body):
        trigger = cpp._quest_id(match[1], constants, body)
        expression = match[2].strip()
        choices = re.fullmatch(r"player\s*->\s*GetTeamId\s*\(\s*\)\s*==\s*TEAM_ALLIANCE\s*"
                               r"\?\s*(\w+)\s*:\s*(\w+)", expression)
        quests = [cpp._quest_id(value, constants, body)
                  for value in (choices.groups() if choices else (expression,))]
        if trigger is None or any(quest is None for quest in quests):
            raise ValueError("unresolvedAreaTriggerChoice")
        pairs.extend((trigger, quest) for quest in quests)
    if not pairs:
        raise ValueError("missingAreaTriggerChoices")
    return pairs


def _smart_credits(bindings, smart_scripts, conditions):
    scripts = smart_scripts.values() if isinstance(smart_scripts, dict) else smart_scripts
    conditions = list(conditions.values()) if isinstance(conditions, dict) else list(conditions)
    references = defaultdict(list)
    for row in conditions:
        source = number(row, "SourceTypeOrReferenceId")
        if source < 0:
            references[source].append(row)

    def condition_gates(rows, seen=frozenset()):
        result = []
        for row in rows:
            if row.get("ScriptName"):
                return None
            reference = number(row, "ConditionTypeOrReference")
            proof = dict(row)
            if reference < 0:
                if reference in seen or reference not in references:
                    return None
                nested = condition_gates(references[reference], seen | {reference})
                if nested is None:
                    return None
                proof["referenceConditions"] = nested
            result.append(proof)
        return result

    owners = defaultdict(list)
    for row in scripts:
        if number(row, "source_type") == 2:
            owners[number(row, "entryorguid")].append(row)
    credits, omissions = [], []
    for entry, actions in owners.items():
        if bindings.get(entry) != {"SmartTrigger"}:
            continue
        parents, by_id = defaultdict(list), defaultdict(list)
        for row in actions:
            by_id[number(row, "id")].append(row)
            if number(row, "link"):
                parents[number(row, "link")].append(row)

        def chain(row, seen=frozenset()):
            identity = number(row, "id")
            if identity in seen or len(by_id[identity]) != 1:
                return []
            if number(row, "event_type") != 61:
                return [row]
            if len(parents[identity]) != 1:
                return []
            preceding = chain(parents[identity][0], seen | {identity})
            return preceding + [row] if preceding else []

        candidates = defaultdict(list)
        gates = condition_gates(row for row in conditions if number(row, "SourceTypeOrReferenceId") == 22
                                and number(row, "SourceId") == 2 and number(row, "SourceEntry") == entry)
        for row in actions:
            if number(row, "action_type") in (15, 26) and number(row, "action_param1") > 0:
                candidates[number(row, "action_param1")].append(row)
        for quest, rows in candidates.items():
            proven = []
            for row in rows:
                sequence = chain(row)
                if (gates is None or not sequence or number(sequence[0], "event_type") != 46
                        or number(sequence[0], "event_param1") not in (0, entry)
                        or number(row, "target_type") not in (7, 16)
                        or any(number(action, "event_phase_mask") or float(action.get("event_chance", 100)) != 100
                               for action in sequence)
                        or any(number(action, "action_type") not in (0, 1, 12, 15, 26, 72) for action in sequence)):
                    continue
                proven.append({"questId": quest, "triggerId": entry, "script": "SmartTrigger",
                               "rule": "linkedSmartTriggerQuestCredit", "sourceScriptEntry": entry,
                               "rowId": number(row, "id"), "conditionGates": gates})
            if len(proven) == len(rows):
                credits.extend(proven)
            else:
                omissions.append({"questId": quest, "triggerId": entry, "script": "SmartTrigger",
                                  "reason": "unprovedSmartTriggerCreditFlow"})
    return credits, omissions


def collect(source_root, script_bindings, smart_scripts=(), conditions=()):
    rows = script_bindings.values() if isinstance(script_bindings, dict) else script_bindings
    bindings = defaultdict(set)
    for row in rows:
        if row.get("ScriptName"):
            bindings[int(row.get("entry", row.get("id", 0)))].add(row["ScriptName"])
    credits, omissions = _smart_credits(bindings, smart_scripts, conditions)
    for script, recipe in RECIPES.items():
        bound = [entry for entry, names in bindings.items() if script in names]
        if not bound:
            continue
        reason = None
        try:
            text = (Path(source_root) / recipe["file"]).read_text(encoding="utf-8-sig")
            masked = cpp._mask(text)
            classes = cpp._classes(masked)
            owners = [row for row in classes if row["name"] == recipe["class"]
                      and re.search(r"\bAreaTriggerScript\b", row["declaration"])]
            if len(owners) != 1:
                raise ValueError("ambiguousAreaTriggerClass")
            owner = owners[0]
            raw_body = text[owner["start"]:owner["end"] + 1]
            if class_digest(raw_body) != recipe["sha256"]:
                raise ValueError("changedAreaTriggerBehavior")
            if not re.search(r"\bnew\s+" + re.escape(recipe["class"]) + r"\s*\(\s*\)\s*;", masked):
                raise ValueError("unregisteredAreaTriggerClass")
            body = masked[owner["open"] + 1:owner["end"]]
            constructor = cpp._mask(raw_body, strings=False)
            if not re.search(r'\bAreaTriggerScript\s*\(\s*"' + re.escape(script) + r'"\s*\)', constructor):
                raise ValueError("unboundAreaTriggerClass")
            constants = cpp._constants(masked, classes)
            display_zones = {cpp._quest_id(name, constants, body): value
                             for name, value in recipe.get("displayZones", {}).items()}
            if recipe["kind"] == "orphan":
                pairs = _orphan_pairs(body, constants)
            else:
                choice = re.search(r"Is25ManRaid\s*\(\s*\)\s*\?\s*(\d+)\s*:\s*(\d+)", body)
                if not choice:
                    raise ValueError("unresolvedAreaTriggerChoice")
                pairs = [(entry, int(quest)) for entry in bound for quest in choice.groups()]
            call = body.find("AreaExploredOrEventHappens")
            line = text.count("\n", 0, owner["open"] + 1 + call) + 1
            covered = set()
            for trigger, quest in pairs:
                if trigger not in bound:
                    continue
                covered.add(trigger)
                if bindings[trigger] != {script}:
                    omissions.append({"triggerId": trigger, "script": script,
                                      "reason": "ambiguousAreaTriggerBinding"})
                    continue
                proof = {"questId": quest, "triggerId": trigger, "script": script,
                         "file": recipe["file"], "line": line, "rule": "reviewedAreaTriggerCredit",
                         "sourceClassSha256": recipe["sha256"]}
                if trigger in display_zones:
                    proof["displayMap"], proof["displayZone"] = display_zones[trigger]
                credits.append(proof)
            for trigger in set(bound) - covered:
                omissions.append({"triggerId": trigger, "script": script, "reason": "unprovedAreaTriggerCase"})
        except (OSError, ValueError, KeyError) as error:
            reason = str(error)
        if reason:
            omissions.extend({"triggerId": trigger, "script": script, "reason": reason} for trigger in bound)
    return {"credits": credits, "omissions": omissions}
