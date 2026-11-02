"""Scope missing-spell reviews to the source relationships that use each gap."""
from collections import defaultdict
import copy
import hashlib
import json


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True, allow_nan=False,
                                     separators=(",", ":")).encode()).hexdigest()


def number(row, field):
    return int(row.get(field, row.get(field.replace("_", ""), 0)) or 0)


def rows(tables, name):
    table = tables.get(name, ())
    return table.values() if isinstance(table, dict) else table


def build_usage(missing_ids, spells, tables, cpp_spell_ids=()):
    """Record effective ancestor spells and their item, quest and script users.

    Include the overlaid SQL/DBC effects, not the export's path or byte hash.
    New users of an existing gap must require review just like new missing IDs.
    """
    if not missing_ids:
        return {}
    parents, children = defaultdict(set), defaultdict(set)

    def edge(parent, child):
        if parent > 0 and child > 0:
            parents[child].add(parent)
            children[parent].add(child)

    for spell_id, row in spells.items():
        for slot in range(1, 4):
            effect = number(row, f"Effect_{slot}")
            if effect == 64 or effect == 6 and number(row, f"EffectApplyAuraName_{slot}") == 23:
                edge(spell_id, number(row, f"EffectTriggerSpell_{slot}"))
    links = list(rows(tables, "spell_linked_spell"))
    for row in links:
        if number(row, "type") == 0:
            edge(abs(number(row, "spell_trigger")), number(row, "spell_effect"))

    references = []
    for row in rows(tables, "item_template"):
        for slot in range(1, 6):
            spell = number(row, f"spellid_{slot}")
            if spell > 0:
                references.append({"table": "item_template", "spellId": spell,
                                   "itemId": number(row, "entry"), "slot": slot,
                                   "trigger": number(row, f"spelltrigger_{slot}"),
                                   "charges": number(row, f"spellcharges_{slot}"),
                                   "class": number(row, "class"), "bonding": number(row, "bonding"),
                                   "startQuest": number(row, "startquest")})
    for table, column, predicate in (
        ("npc_spellclick_spells", "spell_id", lambda row: True),
        ("smart_scripts", "action_param1", lambda row: number(row, "action_type") in (11, 85, 86, 134)),
        ("spell_scripts", "datalong", lambda row: number(row, "command") == 15),
        ("gameobject_template", "Data10", lambda row: number(row, "type") == 10),
        ("spell_script_names", "spell_id", lambda row: True),
    ):
        for row in rows(tables, table):
            spell = number(row, column)
            if spell > 0 and predicate(row):
                references.append({"table": table, "spellId": spell, "row": row})
    references.extend({"table": "bound_cpp", "spellId": spell} for spell in sorted(set(cpp_spell_ids)))

    quest_fields = (["StartItem"] + [f"ItemDrop{i}" for i in range(1, 5)]
                    + [f"RequiredItemId{i}" for i in range(1, 7)]
                    + [f"RewardItem{i}" for i in range(1, 5)]
                    + [f"RewardChoiceItemID{i}" for i in range(1, 7)])
    disabled = {number(row, "entry") for row in rows(tables, "disables") if number(row, "sourceType") == 1}
    result = {}
    for missing in sorted(set(missing_ids)):
        ancestors, pending = {missing}, [missing]
        while pending:
            fresh = parents[pending.pop()] - ancestors
            ancestors.update(fresh)
            pending.extend(fresh)
        users = [row for row in references if row["spellId"] in ancestors]
        # Discard orphan SQL spells that are not reached from a real user.
        reached, pending = {missing}, [row["spellId"] for row in users]
        while pending:
            spell = pending.pop()
            if spell in reached:
                continue
            reached.add(spell)
            pending.extend((children[spell] & ancestors) - reached)
        item_ids = {row["itemId"] for row in users if row["table"] == "item_template"}
        item_ids.update(number(spells[spell], f"EffectItemType_{slot}") for spell in reached if spell in spells
                        for slot in range(1, 4) if number(spells[spell], f"Effect_{slot}") in (24, 157))
        item_ids.discard(0)
        quests = [{"questId": number(row, "ID"), "field": field, "itemId": number(row, field),
                   "disabled": number(row, "ID") in disabled}
                  for row in rows(tables, "quest_template") for field in quest_fields
                  if number(row, field) in item_ids]
        result[str(missing)] = {
            "references": sorted(users, key=lambda row: json.dumps(row, sort_keys=True)),
            "spells": {str(spell): spells[spell] for spell in sorted(reached) if spell in spells},
            "links": sorted((row for row in links if number(row, "type") == 0
                             and abs(number(row, "spell_trigger")) in reached
                             and number(row, "spell_effect") in reached),
                            key=lambda row: json.dumps(row, sort_keys=True)),
            "quests": sorted(quests, key=lambda row: (row["questId"], row["field"])),
        }
    return copy.deepcopy(result)
