"""Regenerate categorized trainer IDs from current AzerothCore SQL and addon spawns."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import sys

from acore_item_source_reader import load_row_table, extract_balanced_braces
from acore_npc_source_reader import LuaParser, load_filtered_row_table
from questie_base import base_text, parse_keys


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Modules/QuestieMenu/ProfessionTrainers.lua"
CATEGORIES = {
    "FIRST_AID": 129, "BLACKSMITHING": 164, "LEATHERWORKING": 165, "ALCHEMY": 171,
    "HERBALISM": 182, "COOKING": 185, "MINING": 186, "TAILORING": 197,
    "ENGINEERING": 202, "ENCHANTING": 333, "FISHING": 356, "SKINNING": 393,
    "JEWELCRAFTING": 755, "INSCRIPTION": 773, "RIDING": 762, "WEAPON_MASTER": None,
}
SKILLS = {skill: category for category, skill in CATEGORIES.items() if skill is not None}
# AC's trainer rows use these learn-spell wrappers for the initial skill rank.
INITIAL_SPELLS = dict(zip(
    (3279, 2020, 2155, 2275, 2372, 2551, 2581, 3911, 4039, 7414, 7733, 8615, 25245, 45375, 33388),
    ("FIRST_AID", "BLACKSMITHING", "LEATHERWORKING", "ALCHEMY", "HERBALISM", "COOKING",
     "MINING", "TAILORING", "ENGINEERING", "ENCHANTING", "FISHING", "SKINNING",
     "JEWELCRAFTING", "INSCRIPTION", "RIDING"),
))
WEAPON_SPELLS = {196, 197, 198, 199, 200, 201, 202, 227, 264, 266, 1180, 2567, 5009, 5011, 15590}
# Gubber teaches Apprentice Fishing through SmartAI gossip action134/spell7733,
# rather than a trainer list (AC smart_scripts entry10216, gossip menu2562/option1).
SCRIPTED_TRAINERS = {10216: "FISHING"}
TABLES = {
    "creature_default_trainer": ("CreatureId",), "creature_template": ("entry",),
    "trainer": ("Id",), "trainer_spell": ("TrainerId", "SpellId"),
}


def load_sources(source, npcs=None):
    tables = {}
    for name, keys in TABLES.items():
        print(f"Reading {name}...", flush=True)
        if name == "creature_template" and npcs is not None:
            linked = {int(row["CreatureId"]) for row in tables["creature_default_trainer"]} | set(SCRIPTED_TRAINERS)
            candidates = {entry for entry in linked if entry in npcs and has_spawns(npcs[entry])}
            rows, skipped = load_filtered_row_table(source, name, keys,
                                                    lambda row: int(row.get("entry") or 0) in candidates)
        else:
            rows, skipped = load_row_table(source, name, keys)
        if skipped:
            raise ValueError(f"{name}: {skipped} unsupported SQL mutations; trainer lists were not written")
        tables[name] = rows
        print(f"{name}: {len(rows)} source rows", flush=True)
    rows, skipped = load_filtered_row_table(source, "smart_scripts", ("entryorguid", "source_type", "id", "link"),
                                            lambda row: int(row.get("entryorguid") or 0) in SCRIPTED_TRAINERS)
    if skipped:
        raise ValueError(f"smart_scripts: {skipped} unsupported SQL mutations; trainer lists were not written")
    tables["smart_scripts"] = rows
    rows, skipped = load_filtered_row_table(source, "gossip_menu_option", ("MenuID", "OptionID"),
                                            lambda row: int(row.get("MenuID") or 0) == 2562)
    if skipped:
        raise ValueError(f"gossip_menu_option: {skipped} unsupported SQL mutations; trainer lists were not written")
    tables["gossip_menu_option"] = rows
    return tables


def slot(row, index):
    if isinstance(row, dict):
        return row.get(index)
    return row[index - 1] if isinstance(row, list) and len(row) >= index else None


def load_current_npcs(path=ROOT / "Database/AzerothCore/acoreNpcDB.lua"):
    keys = parse_keys(path, "npc")
    records = {}
    # Generated source chunks serialize one complete NPC per line. Parse each
    # record separately so the shared parser never repeatedly slices a huge blob.
    for match in re.finditer(r"^\s*\[(\d+)\]\s*=\s*(\{[^\r\n]*\})\s*,?\s*$", base_text(path), re.MULTILINE):
        row = LuaParser(match.group(2)).parse()
        records[int(match.group(1))] = {field: slot(row, keys[field])
                                      for field in ("name", "subName", "spawns", "npcFlags")}
    if not records:
        raise ValueError(f"No serialized NPC records found: {path}")
    return records


def has_spawns(record):
    spawns = record.get("spawns") or {}
    zones = spawns.values() if isinstance(spawns, dict) else spawns
    for points in zones:
        points = points.values() if isinstance(points, dict) else points or []
        if any(isinstance(point, (dict, list)) and slot(point, 1) is not None
               and slot(point, 2) is not None for point in points):
            return True
    return False


def build_categories(tables, npcs):
    """Use spell evidence, never localized NPC subtitles, to classify active trainers."""
    templates = {int(row["entry"]): row for row in tables["creature_template"]}
    defaults = {int(row["CreatureId"]): int(row["TrainerId"]) for row in tables["creature_default_trainer"]}
    trainers = {int(row["Id"]): row for row in tables["trainer"]}
    spells = defaultdict(list)
    for row in tables["trainer_spell"]:
        spells[int(row["TrainerId"])].append(row)

    def spell_categories(rows):
        result = set()
        for row in rows:
            spell = int(row.get("SpellId") or 0)
            if spell in INITIAL_SPELLS:
                result.add(INITIAL_SPELLS[spell])
            if spell in WEAPON_SPELLS:
                result.add("WEAPON_MASTER")
            skill = int(row.get("ReqSkillLine") or 0)
            if skill in SKILLS:
                result.add(SKILLS[skill])
        return result

    categories = {category: set() for category in CATEGORIES}
    unresolved = []
    for entry, template in sorted(templates.items()):
        flags = int(template.get("npcflag") or 0)
        if not flags & 16 or entry not in npcs or not has_spawns(npcs[entry]):
            continue
        trainer_id = defaults.get(entry)
        if trainer_id is None:
            continue  # Current AC reads creature_default_trainer, not the obsolete npc_trainer table.
        trainer = trainers.get(trainer_id)
        if trainer and int(trainer["Type"]) in (0, 3):
            continue  # Class and pet trainers do not belong in these menus.
        if flags & 32 and not flags & 64:
            continue
        if trainer_id is not None and trainer is None:
            unresolved.append(f"{entry} ({template.get('name')}): missing trainer {trainer_id}")
            continue
        if trainer and int(trainer["Type"]) not in (1, 2):
            unresolved.append(f"{entry} ({template.get('name')}): unsupported trainer type {trainer['Type']}")
            continue
        found = spell_categories(spells.get(trainer_id, []))
        if not found:
            unresolved.append(f"{entry} ({template.get('name')}): no supported training spell evidence")
        for category in found:
            categories[category].add(entry)
    if unresolved:
        raise ValueError("Unresolved active trainers:\n" + "\n".join(unresolved))
    for entry, category in SCRIPTED_TRAINERS.items():
        if entry not in templates or entry not in npcs or not has_spawns(npcs[entry]):
            continue
        template = templates[entry]
        accessible = (template.get("AIName") == "SmartAI" and int(template.get("gossip_menu_id") or 0) == 2562
                      and int(template.get("npcflag") or 0) & 1
                      and any(int(row.get("MenuID") or 0) == 2562 and int(row.get("OptionID") or 0) == 1
                              and int(row.get("OptionType") or 0) == 1
                              for row in tables.get("gossip_menu_option", [])))
        if not accessible:
            continue
        lessons = [row for row in tables.get("smart_scripts", [])
                   if int(row.get("entryorguid") or 0) == entry and int(row.get("source_type") or 0) == 0
                   and int(row.get("event_type") or 0) == 62
                   and int(row.get("event_param1") or 0) == 2562 and int(row.get("event_param2") or 0) == 1
                   and int(row.get("action_type") or 0) == 134]
        if any(int(row.get("action_param1") or 0) != 7733 for row in lessons):
            raise ValueError(f"Scripted trainer {entry}: unreviewed gossip lesson")
        if lessons:
            categories[category].add(entry)
    return {category: sorted(ids) for category, ids in categories.items()}


def read_previous(path):
    if not path.exists():
        return {category: [] for category in CATEGORIES}
    text = path.read_text(encoding="utf-8-sig")
    match = re.search(r"local\s+professionTrainers\s*=\s*", text)
    if not match:
        raise ValueError(f"Cannot read previous trainer list: {path}")
    table = LuaParser(extract_balanced_braces(text, text.index("{", match.end()))).parse()
    if isinstance(table, dict):
        unknown = set(table) - set(CATEGORIES)
        if unknown:
            raise ValueError(f"Unknown previous trainer categories: {sorted(unknown)}")
        if any(not isinstance(ids, list) or any(type(entry) is not int or entry <= 0 for entry in ids)
               for ids in table.values()):
            raise ValueError(f"Invalid categorized trainer IDs: {path}")
        return {category: sorted(set(table.get(category, []))) for category in CATEGORIES}
    raise ValueError(f"Expected categorized trainer IDs, not the retired flat list: {path}")


def render(categories):
    lines = ["-- Generated from AzerothCore source by tools/generate_acore_trainer_lists.py.",
             'local Townsfolk = QuestieLoader:ImportModule("Townsfolk")', "", "local professionTrainers = {"]
    for category in CATEGORIES:
        lines.append('    ["' + category + '"] = {' + ",".join(map(str, categories[category])) + "},")
    return "\n".join(lines + ["}", "", "function Townsfolk.GetProfessionTrainers()",
                              "    return professionTrainers", "end", ""])


def changes(before, after, npcs):
    def memberships(categories):
        result = defaultdict(set)
        for category, ids in categories.items():
            for entry in ids:
                result[entry].add(category)
        return result
    old, new = memberships(before), memberships(after)
    return [{"npcId": entry, "name": npcs.get(entry, {}).get("name", "Unknown NPC"),
             "before": sorted(old[entry]), "after": sorted(new[entry])}
            for entry in sorted(old.keys() | new.keys()) if old[entry] != new[entry]]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acore-source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args(argv)
    report = {"status": "error", "updated": False, "changes": []}
    try:
        print("Reading current NPC data...", flush=True)
        npcs = load_current_npcs()
        print(f"NPC data: {len(npcs)} records", flush=True)
        tables = load_sources(args.acore_source, npcs)
        categories = build_categories(tables, npcs)
        previous = read_previous(args.output if args.output.exists() else OUTPUT)
        report["changes"] = changes(previous, categories, npcs)
        rendered = render(categories)
        report["updated"] = not args.output.exists() or args.output.read_text(encoding="utf-8-sig") != rendered
        report.update(categoryCounts={key: len(value) for key, value in categories.items()},
                      summary={"npcCount": len({entry for ids in categories.values() for entry in ids}),
                               "membershipCount": sum(map(len, categories.values())),
                               "changedNpcCount": len(report["changes"])})
        if report["updated"]:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered, encoding="utf-8", newline="\n")
        report["status"] = "ok"
    except (ValueError, OSError, KeyError) as error:
        report["error"] = str(error)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"] if report["status"] == "ok" else {"error": report.get("error")},
                     ensure_ascii=False))
    return 0 if report["status"] == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
