"""Prove optional quest flight hints from bound SmartAI gossip actions.

Gossip text is not destination evidence: some AC options have swapped labels.
Only follow actual player-targeted taxi actions and quest-state conditions.
"""

from collections import defaultdict

from acore_item_compatibility import number


CORE_SOURCE_FILES = (
    "src/server/game/Conditions/ConditionMgr.cpp",
    "src/server/game/Conditions/ConditionMgr.h",
    "src/server/game/Quests/QuestDef.h",
    "src/server/game/Entities/Player/PlayerGossip.cpp",
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
    "src/server/game/AI/SmartScripts/SmartScriptMgr.h",
    "src/server/game/Spells/SpellEffects.cpp",
)

# ConditionMgr::Meets and QuestStatus: none, complete, incomplete, failed, rewarded.
QUEST_STATE_MASK = 1 | 2 | 8 | 32 | 64
ACTIVE_QUEST_STATES = 2 | 8


def quest_state_mask(row):
    """Interpret only built-in quest-state predicates with valid parameters."""
    kind = number(row, "ConditionTypeOrReference")
    if number(row, "ConditionValue3"):
        return None
    value = number(row, "ConditionValue2")
    if kind in (9, 28):
        return (8 if kind == 9 else 2) if not value else None
    if kind == 47 and value > 0 and not value & ~QUEST_STATE_MASK:
        return value
    return None


def derive(quests, creatures, spells, conditions, scripts, gossip_options,
           spell_scripts=()):
    """Return generic NPC hints, proof paths and explicitly unsupported candidates.

    Conditions 9/28/47 identify accepted quest states. Rewarded-only
    prerequisites and arbitrary gossip labels do not establish a quest flight.
    Other visibility conditions remain server-controlled; these are possible
    interaction locations, not a promise that an option is available right now.
    """
    menus = {(number(row, "MenuID"), number(row, "OptionID")): row for row in gossip_options}
    predicates, action_predicates = defaultdict(list), set()
    for row in conditions:
        source = number(row, "SourceTypeOrReferenceId")
        if source == 15:
            predicates[number(row, "SourceGroup"), number(row, "SourceEntry")].append(row)
        elif source == 22:
            action_predicates.add((number(row, "SourceEntry"), number(row, "SourceId"),
                                   number(row, "SourceGroup") - 1))
    custom_spells = {abs(number(row, "spell_id")) for row in spell_scripts if row.get("ScriptName")}
    actions = defaultdict(dict)
    for row in scripts:
        if number(row, "source_type") == 0:
            actions[number(row, "entryorguid")][number(row, "id")] = row
    guides, evidence, omissions = defaultdict(dict), [], []

    for npc, rows in sorted(actions.items()):
        actor = creatures.get(npc, {})
        for root in sorted(rows.values(), key=lambda row: number(row, "id")):
            if number(root, "event_type") != 62:
                continue
            menu, option = number(root, "event_param1"), number(root, "event_param2")
            groups = defaultdict(list)
            for condition in predicates[menu, option]:
                groups[number(condition, "ElseGroup")].append(condition)
            candidates, unsupported_groups = [], []
            for group, members in sorted(groups.items()):
                recognizable = sorted({number(row, "ConditionValue1") for row in members
                                       if number(row, "ConditionTypeOrReference") in (9, 28, 47)
                                       and number(row, "ConditionValue1") in quests
                                       and not number(row, "NegativeCondition")})
                # References/custom predicates need their own source interpreter.
                if any(number(row, "ConditionTypeOrReference") <= 0 or row.get("ScriptName")
                       or number(row, "ConditionTarget") != 0
                       or (number(row, "ConditionTypeOrReference") in (9, 28, 47)
                           and quest_state_mask(row) is None) for row in members):
                    if recognizable:
                        unsupported_groups.append({"creatureId": npc, "menuId": menu,
                                                   "optionId": option, "elseGroup": group,
                                                   "questIds": recognizable,
                                                   "reason": "unsupportedFlightCondition"})
                    continue
                states, positive = {}, defaultdict(set)
                for row in members:
                    kind, quest = number(row, "ConditionTypeOrReference"), number(row, "ConditionValue1")
                    if kind not in (9, 28, 47) or quest not in quests:
                        continue
                    mask = quest_state_mask(row)
                    if number(row, "NegativeCondition"):
                        mask = QUEST_STATE_MASK & ~mask
                    elif mask & ACTIVE_QUEST_STATES:
                        positive[quest].add(kind)
                    states[quest] = states.get(quest, QUEST_STATE_MASK) & mask
                for quest, kinds in sorted(positive.items()):
                    if states[quest] & ACTIVE_QUEST_STATES:
                        candidates.append((quest, group, min(kinds), states[quest]))
            omissions.extend(unsupported_groups)
            if not candidates:
                continue
            context = {"creatureId": npc, "menuId": menu, "optionId": option,
                       "questIds": sorted({quest for quest, _, _, _ in candidates})}

            def omit(reason):
                omissions.append({**context, "reason": reason})

            if (npc <= 0 or actor.get("AIName") != "SmartAI" or actor.get("ScriptName")
                    or number(actor, "gossip_menu_id") != menu or not number(actor, "npcflag") & 1):
                omit("unprovedFlightGossipBinding")
                continue
            selected = menus.get((menu, option))
            if (not selected or number(selected, "OptionType") != 1
                    or not number(selected, "OptionNpcFlag") & number(actor, "npcflag")
                    or number(selected, "ActionMenuID") or number(selected, "BoxCoded")
                    or number(selected, "BoxMoney")):
                omit("unsupportedFlightGossipOption")
                continue
            if (number(root, "event_phase_mask") or number(root, "event_chance") != 100
                    or number(root, "event_flags") & ~512):
                omit("conditionalFlightEvent")
                continue
            flights, visited, row, reason = [], set(), root, None
            while row is not None:
                identity = number(row, "id")
                if identity in visited:
                    reason = "cyclicFlightActionLink"
                    break
                visited.add(identity)
                if ((npc, 0, identity) in action_predicates or number(row, "event_phase_mask")
                        or row is not root and (number(row, "event_type") != 61
                                               or number(row, "event_chance") != 100
                                               or number(row, "event_flags") & ~512)):
                    reason = "conditionalFlightAction"
                    break
                action = number(row, "action_type")
                if action in (11, 52):
                    if number(row, "target_type") != 7:
                        reason = "flightDoesNotTargetInvoker"
                        break
                    spell_id = number(row, "action_param1") if action == 11 else 0
                    spell = spells.get(spell_id)
                    if action == 11 and (not spell or spell_id in custom_spells):
                        reason = "missingOrScriptedFlightSpell"
                        break
                    paths = ([number(row, "action_param1")] if action == 52 else
                             [number(spell, "EffectMiscValue" + str(i)) for i in range(1, 4)
                              if number(spell, "Effect" + str(i)) == 123
                              and number(spell, "EffectImplicitTargetA" + str(i)) == 25
                              and not number(spell, "EffectImplicitTargetB" + str(i))])
                    if len(paths) != 1 or paths[0] <= 0:
                        reason = "unprovedTaxiPath"
                        break
                    flights.append({"actionId": identity, "actionType": action,
                                    "spellId": spell_id, "taxiPathId": paths[0]})
                elif action not in (0, 1, 72):
                    # Do not assume timed lists, target handoffs or other side
                    # effects are equivalent to a direct flight interaction.
                    reason = "unsupportedFlightActionChain"
                    break
                link = number(row, "link")
                if link and link not in rows:
                    reason = "missingFlightActionLink"
                    break
                row = rows.get(link) if link else None
            if reason or len(flights) != 1:
                omit(reason or "ambiguousOrMissingFlightAction")
                continue
            for quest, group, kind, state_mask in candidates:
                label = "Speak with " + str(actor.get("name") or npc)
                guides[quest][npc] = {2: 5, 3: label, 4: 0, 5: [["monster", npc]]}
                evidence.append({**context, "questId": quest, "elseGroup": group,
                                 "conditionType": kind, "allowedQuestStateMask": state_mask,
                                 "rule": "questConditionedGossipTaxi",
                                 "proofScope": "sourceTaxiInstruction; destination geometry is not inferred",
                                 **flights[0]})
    return {"guides": {quest: [hints[npc] for npc in sorted(hints)]
                       for quest, hints in sorted(guides.items())},
            "evidence": evidence, "omissions": omissions}
