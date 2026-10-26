"""Generate bounded quest guides from current source relationships."""

import math
from collections import defaultdict

from acore_item_compatibility import number
from acore_scripted_geometry import typed
import acore_quest_flight_guides as flight_guides


CORE_SOURCE_FILES = (
    "src/server/game/Conditions/ConditionMgr.cpp",
    "src/server/game/Entities/GameObject/GameObject.cpp",
    "src/server/game/Entities/GameObject/GameObjectData.h",
    "src/server/game/Entities/Unit/Unit.cpp",
    "src/server/game/Spells/Auras/SpellAuraEffects.cpp",
    "src/server/game/AI/SmartScripts/SmartAI.cpp",
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
    "src/server/game/Entities/GameObject/GameObject.h",
) + flight_guides.CORE_SOURCE_FILES


def _rows(values):
    return list(values.values()) if isinstance(values, dict) else list(values)


def _templates(values, key):
    if isinstance(values, dict):
        return {int(identity): row for identity, row in values.items()}
    alternatives = ("ID", "id", "entry") if key == "ID" else (key, "ID", "id")
    return {_identity(row, *alternatives): row for row in values}


def _identity(row, *keys):
    return next((number(row, key) for key in keys if row.get(key) is not None), 0)


def _point(value):
    if not isinstance(value, (tuple, list)) or len(value) != 2:
        return None
    zone, point = value
    if type(zone) is not int or zone <= 0 or not isinstance(point, (tuple, list)) or len(point) < 2:
        return None
    if any(type(v) not in (int, float) or not math.isfinite(v) for v in point):
        return None
    if not (0 <= point[0] <= 100 and 0 <= point[1] <= 100):
        return None
    return zone, list(point)


def derive_area_guide_packet(quest_templates, relation_rows, trigger_rows,
                             project_point, script_bindings=(), smart_scripts=()):
    """Keep default area-trigger guides and report unsupported scripted cases."""
    quests = _templates(quest_templates, "ID")
    triggers = _templates(trigger_rows, "ID")
    bindings = defaultdict(set)
    for row in _rows(script_bindings):
        if row.get("ScriptName"):
            bindings[_identity(row, "entry", "id", "ID")].add(row["ScriptName"])
    smart_credits = {}
    for row in _rows(smart_scripts):
        trigger = number(row, "entryorguid")
        quest = number(row, "action_param1")
        if (number(row, "source_type") == 2 and bindings[trigger] == {"SmartTrigger"} and
                number(row, "event_type") == 46 and number(row, "event_param1") in (0, trigger) and
                number(row, "action_type") == 15 and number(row, "target_type") == 7 and
                number(row, "event_phase_mask") == 0 and float(row.get("event_chance", 100)) > 0 and
                trigger > 0 and quest > 0):
            smart_credits[(quest, trigger)] = number(row, "id")
    points, omissions, evidence = defaultdict(lambda: defaultdict(list)), [], []
    candidates = _rows(relation_rows) + [{"quest": quest, "id": trigger}
                                        for quest, trigger in smart_credits]
    relations = sorted(candidates,
                       key=lambda row: (_identity(row, "quest", "QuestId", "Quest"),
                                        _identity(row, "id", "ID", "entry")))
    reviewed = set()
    for relation in relations:
        quest_id = _identity(relation, "quest", "QuestId", "Quest")
        trigger_id = _identity(relation, "id", "ID", "entry")
        if (quest_id, trigger_id) in reviewed:
            continue
        reviewed.add((quest_id, trigger_id))
        quest, trigger = quests.get(quest_id), triggers.get(trigger_id)
        reason = None
        if quest is None:
            reason = "missingQuestTemplate"
        elif trigger is None:
            reason = "missingAreaTrigger"
        elif bindings[trigger_id] and (quest_id, trigger_id) not in smart_credits:
            reason = "unprovedAreaTriggerScript"
        else:
            try:
                projected = _point(project_point(trigger, quest))
            except (ValueError, TypeError, KeyError):
                projected = None
            if projected is None:
                reason = "unmappedAreaTrigger"
            else:
                zone, point = projected
                if point not in points[quest_id][zone]:
                    points[quest_id][zone].append(point)
                evidence.append({"questId": quest_id, "triggerId": trigger_id,
                                 "rule": "smartTriggerQuestCredit" if (quest_id, trigger_id) in smart_credits
                                 else "areaTriggerRelation"})
        if reason:
            omissions.append({"questId": quest_id, "triggerId": trigger_id, "reason": reason})
    guides = {}
    for quest_id, zones in sorted(points.items()):
        quest = quests[quest_id]
        description = str(quest.get("AreaDescription") or "").strip()
        title = str(quest.get("LogTitle") or quest_id).strip()
        guides[quest_id] = typed([description or "Explore " + title, dict(sorted(zones.items()))])
    return {"guides": guides, "omissions": omissions, "evidence": evidence}


def derive_area_guides(quest_templates, relation_rows, trigger_rows,
                       project_point, script_bindings=(), smart_scripts=()):
    return derive_area_guide_packet(quest_templates, relation_rows, trigger_rows,
                                    project_point, script_bindings, smart_scripts)["guides"]


def _quest_items(quest, required_only=False):
    fields = ["RequiredItemId" + str(i) for i in range(1, 7)]
    if not required_only:
        fields += ["StartItem"] + ["ItemDrop" + str(i) for i in range(1, 5)]
        fields += ["RequiredSourceItemId" + str(i) for i in range(1, 5)]
    return {number(quest, field) for field in fields if number(quest, field) > 0}


def _source_context(scripts, creature_templates, conditions):
    """Find self casts reached from actual SmartAI death handlers only."""
    groups, lists = defaultdict(dict), defaultdict(list)
    for row in scripts:
        node = (number(row, "source_type"), number(row, "entryorguid"))
        groups[node][number(row, "id")] = row
        if node[0] == 9:
            lists[node[1]].append(row)
    conditional = {abs(number(row, "SourceEntry")) for row in conditions
                   if number(row, "SourceTypeOrReferenceId") == 22}

    def usable(row):
        return (float(row.get("event_chance", 100)) > 0 and
                number(row, "event_phase_mask") == 0)

    def walk(row, node, seen=frozenset()):
        identity = (*node, number(row, "id"))
        if identity in seen or not usable(row):
            return []
        seen = seen | {identity}
        found = []
        action, target = number(row, "action_type"), number(row, "target_type")
        if action == 11 and target == 1 and number(row, "action_param2") & 2:
            found.append(row)
        elif action in (80, 87, 88) and target == 1:
            if action == 80:
                children = [number(row, "action_param1")]
            elif action == 87:
                children = [number(row, "action_param" + str(i)) for i in range(1, 7)]
            else:
                children = [entry for entry in lists
                            if number(row, "action_param1") <= entry <= number(row, "action_param2")]
            for child in children:
                if child in conditional:
                    continue
                steps = sorted(lists[child], key=lambda candidate: number(candidate, "id"))
                if any(number(step, "event_type") != 0 or number(step, "target_type") != 1 or
                       number(step, "action_type") not in (11, 80, 87, 88) for step in steps):
                    continue
                for step in steps:
                    if number(step, "event_type") == 0:
                        found.extend(walk(step, (9, child), seen))
        link = number(row, "link")
        linked = groups[node].get(link) if link else None
        if linked is not None and number(linked, "event_type") == 61:
            found.extend(walk(linked, node, seen))
        return found

    casts = []
    for entry, template in sorted(creature_templates.items()):
        if template.get("AIName") != "SmartAI" or template.get("ScriptName") or entry in conditional:
            continue
        for row in groups[(0, entry)].values():
            if number(row, "event_type") == 6:
                casts.extend((entry, cast) for cast in walk(row, (0, entry)))
    return casts


def _spell_target_conditions(conditions, spells, npcs, objects):
    """Resolve target-side entry restrictions, excluding caster/GUID rules."""
    result = defaultdict(set)
    for row in conditions:
        source = number(row, "SourceTypeOrReferenceId")
        if (number(row, "ConditionTypeOrReference") != 31 or
                number(row, "NegativeCondition") != 0 or row.get("ScriptName") or
                number(row, "SourceId") != 0):
            continue
        spell_id = number(row, "SourceEntry")
        spell = spells.get(spell_id)
        if not spell:
            continue
        if source == 13:
            mask = number(row, "SourceGroup")
            if (number(row, "ConditionTarget") != 0 or mask <= 0 or mask > 7 or
                    not any(mask & (1 << (i-1)) and number(spell, "Effect" + str(i)) > 0
                            for i in range(1, 4))):
                continue
        elif source == 17:
            if (number(row, "ConditionTarget") != 1 or number(row, "SourceGroup") != 0 or
                    not any(number(spell, "Effect" + str(i)) > 0 for i in range(1, 4))):
                continue
        else:
            continue
        kind = number(row, "ConditionValue1")
        entry, guid = number(row, "ConditionValue2"), number(row, "ConditionValue3")
        if kind == 3 and entry in npcs and guid in (0, 1):
            result[spell_id].add(("monster", entry))
        elif kind == 5 and entry in objects and guid == 0:
            result[spell_id].add(("object", entry))
    return result


def _vehicle_spellclicks(conditions, spells, npcs, click_rows):
    """Prove quest-bound clicks that apply a player control aura to the NPC."""
    clicks = defaultdict(list)
    for row in click_rows:
        clicks[(number(row, "npc_entry"), number(row, "spell_id"))].append(row)
    targets = defaultdict(set)
    for condition in conditions:
        if (number(condition, "SourceTypeOrReferenceId") == 13 and
                number(condition, "ConditionTypeOrReference") == 31 and
                number(condition, "ConditionTarget") == 0 and
                number(condition, "ConditionValue1") == 3 and
                number(condition, "ConditionValue3") in (0, 1) and
                number(condition, "NegativeCondition") == 0 and
                number(condition, "SourceId") == 0 and not condition.get("ScriptName")):
            mask = number(condition, "SourceGroup")
            if 0 < mask < 8:
                targets[(number(condition, "SourceEntry"), number(condition, "ConditionValue2"))].add(mask)
    result = defaultdict(set)
    for condition in conditions:
        if (number(condition, "SourceTypeOrReferenceId") != 18 or
                number(condition, "ConditionTypeOrReference") != 9 or
                number(condition, "ConditionTarget") != 0 or
                number(condition, "NegativeCondition") != 0 or
                number(condition, "SourceId") != 0 or condition.get("ScriptName")):
            continue
        npc, spell_id = number(condition, "SourceGroup"), number(condition, "SourceEntry")
        template, spell = npcs.get(npc, {}), spells.get(spell_id, {})
        if (number(template, "VehicleId") <= 0 or template.get("ScriptName") or
                template.get("AIName", "") not in ("", "SmartAI")):
            continue
        for click in clicks[(npc, spell_id)]:
            flags = number(click, "cast_flags")
            if not flags & 1:
                continue
            for slot in range(1, 4):
                if (number(spell, "Effect" + str(slot)) != 6 or
                        number(spell, "EffectApplyAuraName" + str(slot)) != 236 or
                        number(spell, "EffectImplicitTargetB" + str(slot)) != 0):
                    continue
                target = number(spell, "EffectImplicitTargetA" + str(slot))
                direct = target == 25 and not flags & 2
                nearby = target == 38 and any(mask & (1 << (slot-1))
                                               for mask in targets[(spell_id, npc)])
                if direct or nearby:
                    quest = number(condition, "ConditionValue1")
                    if quest > 0:
                        result[quest].add((npc, spell_id))
    return result


def _summoned_quest_finishers(quests, objects, npcs, scripts, conditions, quest_relations):
    """Find direct object interactions that summon an actual quest finisher."""
    finishers = defaultdict(set)
    for quest_id, relation in (quest_relations or {}).items():
        quest_id = int(quest_id)
        if quest_id in quests:
            for npc in relation.get("end", {}).get("creature", ()):
                finishers[int(npc)].add(quest_id)
    conditional = {abs(number(row, "SourceEntry")) for row in conditions
                   if number(row, "SourceTypeOrReferenceId") == 22 and number(row, "SourceId") == 1}
    result = defaultdict(set)
    for row in scripts:
        obj, npc = number(row, "entryorguid"), number(row, "action_param1")
        template, actor = objects.get(obj, {}), npcs.get(npc, {})
        if (number(row, "source_type") != 1 or number(row, "event_type") != 70 or
                number(row, "event_param1") != 2 or number(row, "action_type") != 12 or
                number(row, "target_type") != 8 or number(row, "event_phase_mask") != 0 or
                number(row, "event_flags") != 0 or float(row.get("event_chance", 100)) <= 0 or
                obj in conditional or template.get("AIName") != "SmartGameObjectAI" or
                template.get("ScriptName") or number(template, "type") not in (1, 10) or
                not number(actor, "npcflag") & 2):
            continue
        # GameObject::SetLootState sends GO_ACTIVATED (2) to SAI event 70.
        # Default button/goober use handlers enter that state on interaction.
        if not all(math.isfinite(float(row.get("target_" + axis, 0))) for axis in ("x", "y", "z", "o")):
            continue
        for quest_id in finishers[npc]:
            if number(template, "type") == 10 and number(template, "Data1") not in (0, quest_id):
                continue
            result[quest_id].add((obj, npc))
    return result


def derive_extra_guide_packet(quest_templates, item_templates, object_templates,
                              spells, conditions, scripts, item_sources,
                              creature_templates, npc_spellclick_rows=(), quest_relations=None,
                              gossip_options=(), spell_scripts=()):
    quests = _templates(quest_templates, "ID")
    items = _templates(item_templates, "entry")
    objects = _templates(object_templates, "entry")
    npcs = _templates(creature_templates, "entry")
    spell_rows = _templates(spells, "ID")
    condition_rows = _rows(conditions)
    target_conditions = _spell_target_conditions(condition_rows, spell_rows, npcs, objects)
    vehicle_clicks = _vehicle_spellclicks(condition_rows, spell_rows, npcs, _rows(npc_spellclick_rows))
    summoned_finishers = _summoned_quest_finishers(
        quests, objects, npcs, _rows(scripts), condition_rows, quest_relations)
    flights = flight_guides.derive(quests, npcs, spell_rows, condition_rows,
                                   _rows(scripts), _rows(gossip_options), _rows(spell_scripts))
    source_items = {int(key): row for key, row in item_sources.items()}
    focuses, goobers = defaultdict(set), defaultdict(set)
    for entry, obj in objects.items():
        if number(obj, "type") == 8 and number(obj, "Data0") > 0:
            focuses[number(obj, "Data0")].add(entry)
        if (number(obj, "type") == 10 and number(obj, "Data1") in quests and
                not obj.get("ScriptName") and obj.get("AIName", "") in ("", "SmartGameObjectAI")):
            goobers[number(obj, "Data1")].add(entry)
    death_containers = defaultdict(set)
    for actor, cast in _source_context(_rows(scripts), npcs, _rows(conditions)):
        spell = spell_rows.get(number(cast, "action_param1"), {})
        for i in range(1, 4):
            if number(spell, "Effect" + str(i)) not in {50, 76, 104, 105, 106, 107}:
                continue
            targets = {number(spell, "EffectImplicitTarget" + side + str(i)) for side in ("A", "B")}
            if not targets & {1, 18} or targets - {0, 1, 18}:
                continue
            obj = number(spell, "EffectMiscValue" + str(i))
            if obj in objects and number(objects[obj], "type") in (3, 25):
                death_containers[obj].add(actor)
    guides, optional, evidence, omissions = {}, {}, [], []
    for quest_id, quest in sorted(quests.items()):
        hints = {}
        for item in sorted(_quest_items(quest)):
            template = items.get(item)
            if template is None:
                continue
            for index in range(1, 6):
                if number(template, "spelltrigger" + str(index)) not in (0, 5):
                    continue
                spell_id = number(template, "spellid" + str(index))
                spell = spell_rows.get(spell_id, {})
                focus_id = number(spell, "RequiresSpellFocus")
                focus_objects = focuses[focus_id]
                # A shared focus describes a casting requirement, not which
                # object this quest intends. Keep only an unambiguous identity;
                # explicit target conditions below remain independent proof.
                if focus_id > 0 and len(focus_objects) != 1:
                    omissions.append({"questId": quest_id, "itemId": item, "spellId": spell_id,
                                      "focusId": focus_id, "candidateObjectIds": sorted(focus_objects),
                                      "reason": "sharedSpellFocusDoesNotProveQuestLocation" if focus_objects
                                      else "missingSpellFocusObject"})
                for obj in sorted(focus_objects if len(focus_objects) == 1 else ()):
                    label = "Use " + str(template.get("name") or item) + " at " + str(objects[obj].get("name") or obj)
                    hints[(3, label, "object", obj)] = {2: 3, 3: label, 4: 0, 5: [["object", obj]]}
                    evidence.append({"questId": quest_id, "rule": "questItemSpellFocus",
                                     "itemId": item, "spellId": spell_id, "objectId": obj})
                for kind, entry in sorted(target_conditions[spell_id]):
                    target = (npcs if kind == "monster" else objects)[entry]
                    label = "Use " + str(template.get("name") or item) + " on " + str(target.get("name") or entry)
                    hints[(3, label, kind, entry)] = {2: 3, 3: label, 4: 0, 5: [[kind, entry]]}
                    evidence.append({"questId": quest_id, "rule": "questItemSpellTargetCondition",
                                     "itemId": item, "spellId": spell_id, "kind": kind, "entry": entry})
        for obj in sorted(goobers[quest_id]):
            label = "Interact with " + str(objects[obj].get("name") or obj)
            hints[(3, label, "object", obj)] = {2: 3, 3: label, 4: 0, 5: [["object", obj]]}
            evidence.append({"questId": quest_id, "rule": "sourceGooberQuestInteraction", "objectId": obj})
        for npc, spell_id in sorted(vehicle_clicks[quest_id]):
            label = "Mount " + str(npcs[npc].get("name") or npc)
            hints[(3, label, "monster", npc)] = {2: 3, 3: label, 4: 0, 5: [["monster", npc]]}
            evidence.append({"questId": quest_id, "rule": "questConditionedVehicleSpellClick",
                             "creatureId": npc, "spellId": spell_id})
        for obj, npc in sorted(summoned_finishers[quest_id]):
            label = "Use " + str(objects[obj].get("name") or obj) + " to summon " + str(npcs[npc].get("name") or npc)
            hints[(3, label, "object", obj)] = {2: 3, 3: label, 4: 0, 5: [["object", obj]]}
            evidence.append({"questId": quest_id, "rule": "activatedObjectSummonsQuestFinisher",
                             "objectId": obj, "creatureId": npc, "sourceType": 1,
                             "eventType": 70, "eventState": 2, "actionType": 12, "targetType": 8})
        for item in sorted(_quest_items(quest, required_only=True)):
            for obj in source_items.get(item, {}).get("objectDrops", ()):
                for actor in sorted(death_containers[obj]):
                    label = "Defeat " + str(npcs[actor].get("name") or actor) + " to find " + str(objects[obj].get("name") or obj)
                    hints[(1, label, "monster", actor)] = {2: 1, 3: label, 4: 0, 5: [["monster", actor]]}
                    evidence.append({"questId": quest_id, "rule": "deathSummonedQuestContainer",
                                     "itemId": item, "objectId": obj, "creatureId": actor})
        travel_keys = set()
        for hint in flights["guides"].get(quest_id, ()):
            kind, npc = hint[5][0]
            key = (hint[2], hint[3], kind, npc)
            hints[key] = hint
            travel_keys.add(key)
        if hints:
            ordered = sorted(hints.items())
            guides[quest_id] = typed([value for _, value in ordered])
            indices = [index for index, (key, _) in enumerate(ordered, 1) if key in travel_keys]
            if indices:
                optional[str(quest_id)] = indices
    return {"guides": guides, "optional": optional, "evidence": evidence,
            "omissions": omissions, "flights": flights}


def derive_extra_guides(quest_templates, item_templates, object_templates, spells,
                        conditions, scripts, item_sources, creature_templates, npc_spellclick_rows=(), quest_relations=None,
                        gossip_options=(), spell_scripts=()):
    return derive_extra_guide_packet(quest_templates, item_templates, object_templates,
                                     spells, conditions, scripts, item_sources,
                                     creature_templates, npc_spellclick_rows, quest_relations,
                                     gossip_options, spell_scripts)["guides"]
