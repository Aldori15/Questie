"""Bounded SmartAI event-credit geometry and interaction guides."""
from collections import Counter, defaultdict
import math

from acore_item_compatibility import number
import acore_quest_compatibility as compatibility
import acore_quest_guides as common


CORE_SOURCE_FILES = (
    "src/server/game/AI/SmartScripts/SmartAI.cpp",
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
    "src/server/game/AI/SmartScripts/SmartScriptMgr.h",
    "src/server/game/Entities/Creature/Creature.cpp",
    "src/server/game/Entities/GameObject/GameObject.cpp",
    "src/server/game/Spells/SpellEffects.cpp",
    "src/server/game/Conditions/ConditionMgr.cpp",
)
PLAYER_SELECTORS = frozenset({17, 18, 21, 201})
# Linked presentation/state changes preserve the current waypoint position.
POSITION_PRESERVING_ACTIONS = frozenset({1, 2, 3, 4, 5, 8, 16, 17, 18, 19, 20, 21, 22,
                                        40, 42, 43, 44, 47, 48, 59, 60, 61, 66, 81, 82, 83,
                                        90, 91, 101})


def _chain(row, actions):
    def key(action):
        return tuple(number(action, name) for name in ("source_type", "entryorguid", "id"))

    counts = Counter(key(action) for action in actions)
    parents = defaultdict(list)
    for action in actions:
        if number(action, "link"):
            parents[(number(action, "source_type"), number(action, "entryorguid"), number(action, "link"))].append(action)
    result, seen = [], set()
    while True:
        identity = key(row)
        if identity in seen or counts[identity] != 1:
            return []
        seen.add(identity)
        result.append(row)
        if number(row, "event_type") != 61:
            return list(reversed(result))
        preceding = parents.get(identity, ())
        if len(preceding) != 1:
            return []
        row = preceding[0]


def _fixed_chain(chain):
    return (bool(chain) and all(number(row, "source_type") in (0, 1)
                               and not number(row, "event_phase_mask")
                               and float(row.get("event_chance", 100)) == 100 for row in chain))


def _player_credit(actor, row, actions, known_lists, event):
    target = number(row, "target_type")
    if target in PLAYER_SELECTORS:
        return True
    if target == 12:
        return (actor, number(row, "target_param1")) in known_lists
    return target == 7 and event in (19, 62, 64)


def _geometry_gates(actions, conditions):
    owners = {(number(row, "source_type"), number(row, "entryorguid")) for row in actions}
    gates = [row for row in conditions if number(row, "SourceTypeOrReferenceId") == 22
             and (number(row, "SourceId"), number(row, "SourceEntry")) in owners]
    references = defaultdict(list)
    for row in conditions:
        if number(row, "SourceTypeOrReferenceId") < 0:
            references[-number(row, "SourceTypeOrReferenceId")].append(row)
    evidence = []

    def preserves(row, seen=frozenset()):
        if row.get("ScriptName"):
            return False
        kind = number(row, "ConditionTypeOrReference")
        if kind < 0:
            reference = -kind
            if reference in seen or not references[reference]:
                return False
            valid = all(preserves(child, seen | {reference}) for child in references[reference])
        else:
            # An invoker aura gate changes eligibility, never the event's location.
            valid = kind == 1 and number(row, "ConditionTarget") == 0 and number(row, "ConditionValue1") > 0
        if valid:
            fields = ("SourceTypeOrReferenceId", "SourceGroup", "SourceEntry", "SourceId", "ElseGroup",
                      "ConditionTypeOrReference", "ConditionTarget", "ConditionValue1", "ConditionValue2",
                      "ConditionValue3", "NegativeCondition")
            proof = {field: number(row, field) for field in fields}
            if proof not in evidence:
                evidence.append(proof)
        return valid

    return evidence if all(preserves(row) for row in gates) else None


def _self_quest_spell(spell):
    effects = [index for index in range(1, 4) if number(spell, "Effect" + str(index))]
    if len(effects) != 1:
        return 0
    index = str(effects[0])
    if (number(spell, "Effect" + index) != 16 or number(spell, "EffectImplicitTargetA" + index) != 1
            or number(spell, "EffectImplicitTargetB" + index) != 0):
        return 0
    return number(spell, "EffectMiscValue" + index)


def derive(quest_templates, creature_templates, object_templates, scripts, waypoint_rows,
           creature_spawns, project_point, conditions=(), quest_special_flags=None,
           gameobject_spawns=None, spells=None):
    """Keep explicit credit points; never substitute an escort's final waypoint."""
    quests = common._templates(quest_templates, "ID")
    creatures, objects = (common._templates(rows, "entry") for rows in (creature_templates, object_templates))
    scripts, creature_spawns = common._rows(scripts), common._rows(creature_spawns)
    object_spawns = None if gameobject_spawns is None else common._rows(gameobject_spawns)
    paths = defaultdict(dict)
    for node in common._rows(waypoint_rows):
        path, point = number(node, "entry"), number(node, "pointid")
        if point in paths[path]:
            paths[path][point] = None
        else:
            paths[path][point] = node
    contexts = dict(compatibility._source_context(creatures, objects, scripts, creature_spawns))
    known_lists = compatibility._known_player_lists(creatures, objects, scripts, contexts, creature_spawns, set(paths))
    conditions = common._rows(conditions)
    spells = {int(key): row for key, row in (spells or {}).items()}
    placements = defaultdict(list)
    for spawn in creature_spawns:
        for entry in {number(spawn, key) for key in ("id1", "id2", "id3", "id", "entry")} - {0}:
            placements[("monster", entry)].append(spawn)
    for spawn in object_spawns or ():
        placements[("object", number(spawn, "id"))].append(spawn)
    overrides = {(number(row, "source_type"), -number(row, "entryorguid")) for row in scripts
                 if number(row, "entryorguid") < 0}
    points, interactions = defaultdict(lambda: defaultdict(list)), []
    evidence, omissions, blocked = [], [], set()

    def project(nodes, spawns, quest):
        result = []
        if not spawns or len({number(spawn, "map") for spawn in spawns}) != 1:
            return []
        try:
            for node in nodes:
                if node is None or any(not math.isfinite(float(node[key]))
                                       for key in ("position_x", "position_y", "position_z")):
                    return []
                for spawn in spawns:
                    point = common._point(project_point(node, spawn, quest))
                    if point is None:
                        return []
                    result.append(point)
        except (ValueError, TypeError, KeyError, OverflowError):
            return []
        return result

    for actor, actions in contexts.items():
        kind, entry = actor[:2]
        template = (creatures if kind == "monster" else objects)[entry]
        actor_spawns = placements[(kind, entry)]
        if len(actor) == 3:
            actor_spawns = [spawn for spawn in actor_spawns if number(spawn, "guid") == actor[2]]
        owner, source_type = (-actor[2] if len(actor) == 3 else entry), (0 if kind == "monster" else 1)
        condition_gates = _geometry_gates(actions, conditions)
        for row in actions:
            action = number(row, "action_type")
            follow = action == 29 and number(row, "action_param5") == 1
            spell_id = number(row, "action_param1") if action == 134 else 0
            spell_quest = _self_quest_spell(spells.get(spell_id, {})) if spell_id else 0
            if action not in (15, 26) and not follow and not spell_quest or float(row.get("event_chance", 100)) <= 0:
                continue
            quest_id = spell_quest or number(row, "action_param4" if follow else "action_param1")
            if quest_id not in quests:
                continue
            proof = {"questId": quest_id, "actor": list(actor[:2]), "sourceType": source_type,
                     "scriptEntry": owner, "rowId": number(row, "id")}
            chain = _chain(row, actions)
            event = number(chain[0], "event_type") if chain else -1
            special = (quest_special_flags or {}).get(quest_id, number(quests[quest_id], "SpecialFlags"))
            reason, projected, interaction = None, [], None
            if not special & 2:
                reason = "questDoesNotRequireExplorationEvent"
            elif not _fixed_chain(chain):
                reason = "conditionalOrUnprovedCreditChain"
            elif condition_gates is None:
                reason = "conditionalSmartActor"
            elif kind == "object" and object_spawns is None:
                reason = "unverifiedObjectPlacements"
            elif not actor_spawns:
                reason = "missingActorPlacements"
            elif (any(spawn.get("ScriptName") for spawn in actor_spawns)
                  or len(actor) == 2 and any((source_type, number(spawn, "guid")) in overrides for spawn in actor_spawns)
                  or len(actor) == 3 and number(template, "flags_extra") & 0x08000000):
                reason = "overriddenOrMergedSmartActor"
            elif follow:
                destination = number(row, "action_param3")
                destination_spawns = placements[("monster", destination)]
                follow_hint = {"questId": quest_id, "actor": ["monster", destination],
                               "label": "Lead " + str(template.get("name") or entry) + " to "
                                        + str(creatures.get(destination, {}).get("name") or destination)}
                if (kind != "monster" or event != 19 or number(chain[0], "event_param1") != quest_id
                        or number(row, "target_type") != 7 or destination not in creatures
                        or any(number(prior, "action_type") not in POSITION_PRESERVING_ACTIONS for prior in chain[:-1])):
                    reason = "unprovedFollowDestination"
                elif (destination_spawns and ({number(spawn, "map") for spawn in actor_spawns}
                                              != {number(spawn, "map") for spawn in destination_spawns})):
                    reason = "ambiguousFollowDestinationMap"
                elif (not destination_spawns or number(creatures[destination], "MovementType")
                      or creatures[destination].get("ScriptName") or creatures[destination].get("AIName") not in (None, "", "SmartAI")
                      or any(spawn.get("ScriptName") for spawn in destination_spawns)
                      or any(number(spawn, "phaseMask") not in (0, 1) for spawn in destination_spawns)
                      or any(common.spawn_movement_type(creatures[destination], spawn) for spawn in destination_spawns)
                      or any(number(action_row, "action_type") in (29, 46, 53, 62, 69, 201, 232, 233)
                             for destination_actor, destination_actions in contexts.items()
                             if destination_actor[:2] == ("monster", destination) for action_row in destination_actions)):
                    interaction = follow_hint
                else:
                    projected = project(destination_spawns, destination_spawns, quests[quest_id])
                    if not projected:
                        interaction = follow_hint
                proof.update(rule="smartFollowDestination", destinationNpcId=destination)
            elif spell_quest:
                if (kind != "monster" or event != 10 or number(row, "target_type") != 7
                        or number(chain[0], "event_param2") <= 0
                        or any(number(prior, "action_type") not in POSITION_PRESERVING_ACTIONS for prior in chain[:-1])
                        or any(number(action_row, "action_type") in (29, 46, 53, 58, 62, 69, 201, 232, 233)
                               for action_row in actions)):
                    reason = "unprovedQuestSpellRegion"
                else:
                    if any(common.spawn_movement_type(template, spawn) for spawn in actor_spawns):
                        interaction = {"questId": quest_id, "actor": list(actor[:2]),
                                       "label": str(quests[quest_id].get("AreaDescription") or "").strip()
                                                or "Complete the quest event"}
                    else:
                        projected = project(actor_spawns, actor_spawns, quests[quest_id])
                        if not projected:
                            reason = "unmappedQuestSpellRegion"
                proof.update(rule="smartLosQuestCompleteSpell", spellId=spell_id,
                             range=number(chain[0], "event_param2"))
            elif not _player_credit(actor, row, actions, known_lists, event):
                reason = "unprovedCreditPlayers"
            elif event in (62, 64):
                interaction = {"questId": quest_id, "actor": list(actor[:2]),
                               "label": ("Speak with " if kind == "monster" else "Interact with ")
                                        + str(template.get("name") or entry)}
                proof.update(rule="smartGossipQuestCredit", eventType=event)
            elif event == 40 and kind == "monster":
                point_id, explicit_path = number(chain[0], "event_param1"), number(chain[0], "event_param2")
                actor_paths = {number(action_row, "action_param2") for action_row in actions
                               if number(action_row, "action_type") == 53 and number(action_row, "action_param2") > 0}
                selected_paths = {explicit_path} if explicit_path else actor_paths
                selected_nodes = [paths[path].get(point_id) for path in sorted(selected_paths)]
                conflicting = False
                for sibling in actions:
                    sibling_action = number(sibling, "action_type")
                    if sibling_action in (36, 58):
                        conflicting = True
                        break
                    successful_stop = sibling_action == 55 and not number(sibling, "action_param3")
                    if sibling_action not in (46, 53, 62, 69, 80, 87, 88, 201, 232, 233) and not successful_stop:
                        continue
                    sibling_chain = _chain(sibling, actions)
                    if not sibling_chain:
                        conflicting = True
                        break
                    sibling_root = sibling_chain[0]
                    same_event = (number(sibling_root, "event_type") == 40
                                  and number(sibling_root, "event_param1") == point_id
                                  and number(sibling_root, "event_param2") in selected_paths | {0})
                    after_credit = any(prior is row for prior in sibling_chain[:-1])
                    if (same_event or successful_stop) and not after_credit:
                        conflicting = True
                        break
                if (point_id <= 0 or not selected_paths or not selected_paths <= actor_paths or not selected_nodes
                        or any(node is None for node in selected_nodes) or conflicting
                        or any(number(prior, "action_type") not in POSITION_PRESERVING_ACTIONS for prior in chain[:-1])
                        or any(common.spawn_movement_type(template, spawn) for spawn in actor_spawns)
                        or any(number(action_row, "action_type") in (232, 233) for action_row in actions)):
                    reason = "unprovedWaypointCreditPath"
                else:
                    projected = project(selected_nodes, actor_spawns, quests[quest_id])
                    if not projected:
                        reason = "unmappedWaypointCredit"
                proof.update(rule="smartExplicitWaypointCredit", pointId=point_id, pathIds=sorted(selected_paths))
            else:
                reason = "unsupportedCreditActivation"
            if reason:
                blocked.add(quest_id)
                omissions.append({**proof, "reason": reason})
                continue
            for zone, point in projected:
                if point not in points[quest_id][zone]:
                    points[quest_id][zone].append(point)
            if interaction and interaction not in interactions:
                interactions.append(interaction)
            if condition_gates:
                proof["conditionGates"] = condition_gates
            evidence.append(proof)
    guides = {}
    for quest_id, zones in sorted(points.items()):
        if quest_id in blocked:
            continue
        description = str(quests[quest_id].get("AreaDescription") or "").strip()
        guides[quest_id] = common.typed([description or "Complete the quest event", dict(sorted(zones.items()))])
    return {"guides": guides, "interactions": [record for record in interactions if record["questId"] not in blocked],
            "evidence": evidence, "omissions": omissions}
