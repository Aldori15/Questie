"""Source-bound vehicle and cross-cast event actors, without map geometry."""
from collections import defaultdict

from acore_quest_compatibility import _source_context, _templates


CORE_SOURCE_FILES = (
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
    "src/server/game/AI/SmartScripts/SmartScriptMgr.h",
    "src/server/game/Spells/SpellEffects.cpp",
)


def _number(row, key):
    return int(row.get(key) or 0)


def _effect(row, field, slot):
    return int(row.get(f"{field}{slot}", row.get(f"{field}_{slot}", 0)) or 0)


def _mapping(values):
    return {str(key): [list(actor) for actor in sorted({actor[:2] for actor in actors})]
            for key, actors in sorted(values.items())}


def _source_rows(values):
    if isinstance(values, dict):
        return {int(key): row for key, row in values.items()}
    return {int(row.get("ID", row.get("entry", 0))): row for row in values}


def collect(creature_templates, scripts, spells, *, quest_templates=(), creature_spawns=()):
    """Prove actors from explicit vehicle completion or player-caster credits.

    A vehicle's self-targeted event completion credits its player passengers in
    SmartScript. A cross-cast with the closest-player caster and a caster-only
    spell effect credits that player, even when the explicit cast target is the
    actor. Both rules require a bound SmartAI template and actual spell fields.
    Quest templates optionally turn source credit-objective links into event
    tooltip associations. These associations do not replace quest objectives.
    """
    creatures = _templates(creature_templates)
    spell_rows = _source_rows(spells)
    events, credits, evidence = defaultdict(set), defaultdict(set), []
    contexts = _source_context(creatures, {}, scripts, creature_spawns)
    for actor, actions in contexts:
        template = creatures[actor[1]]
        for row in actions:
            if _number(row, "event_chance") <= 0:
                continue
            action = _number(row, "action_type")
            if (action in (15, 26) and _number(row, "target_type") == 1
                    and _number(template, "VehicleId") > 0):
                quest = _number(row, "action_param1")
                if quest > 0:
                    events[quest].add(actor)
                    evidence.append({"rule": "vehiclePlayerPassengerEvent", "actor": list(actor),
                                     "questId": quest, "vehicleId": _number(template, "VehicleId"),
                                     "sourceType": _number(row, "source_type"),
                                     "scriptEntry": _number(row, "entryorguid"),
                                     "rowId": _number(row, "id")})
            if (action != 86 or _number(row, "target_type") != 1
                    or _number(row, "action_param3") != 21):
                continue
            spell_id = _number(row, "action_param1")
            spell = spell_rows.get(spell_id, {})
            for slot in (1, 2, 3):
                # TARGET_UNIT_CASTER (1), with no second target selector.
                # Other spell destinations need their own recipient proof.
                if (_effect(spell, "EffectImplicitTargetA", slot) != 1
                        or _effect(spell, "EffectImplicitTargetB", slot) != 0):
                    continue
                effect = _effect(spell, "Effect", slot)
                value = _effect(spell, "EffectMiscValue", slot)
                if effect == 90 and value in creatures:
                    credits[value].add(actor)
                    evidence.append({"rule": "closestPlayerCrossCastCredit", "actor": list(actor),
                                     "spellId": spell_id, "creditNpcId": value, "effectSlot": slot,
                                     "sourceType": _number(row, "source_type"),
                                     "scriptEntry": _number(row, "entryorguid"),
                                     "rowId": _number(row, "id")})
                elif effect == 16 and value > 0:
                    events[value].add(actor)
                    evidence.append({"rule": "closestPlayerCrossCastQuestCompletion",
                                     "actor": list(actor), "spellId": spell_id,
                                     "questId": value, "effectSlot": slot})
    for quest_id, quest in _source_rows(quest_templates).items():
        for slot in (1, 2, 3, 4):
            credit = _number(quest, f"RequiredNpcOrGo{slot}")
            if credit > 0 and credit in credits:
                events[quest_id].update(credits[credit])
    return {"events": _mapping(events), "credits": _mapping(credits), "evidence": evidence}
