"""Generate bounded quest guides from current source relationships."""

import math
from collections import Counter, defaultdict

from acore_item_compatibility import number
from acore_scripted_geometry import typed
import acore_quest_flight_guides as flight_guides
import acore_quest_compatibility as compatibility


CORE_SOURCE_FILES = (
    "src/server/game/Conditions/ConditionMgr.cpp",
    "src/server/game/Entities/GameObject/GameObject.cpp",
    "src/server/game/Entities/GameObject/GameObjectData.h",
    "src/server/game/Entities/Unit/Unit.cpp",
    "src/server/game/Spells/Auras/SpellAuraEffects.cpp",
    "src/server/game/AI/SmartScripts/SmartAI.cpp",
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
    "src/server/game/Entities/GameObject/GameObject.h",
    "src/server/game/Entities/Creature/CreatureData.h",
    "src/server/game/Entities/Creature/Creature.cpp",
    "src/server/game/AI/ScriptedAI/ScriptedEscortAI.cpp",
    "src/server/game/AI/ScriptedAI/ScriptedEscortAI.h",
    "src/server/game/AI/ScriptedAI/ScriptedFollowerAI.cpp",
    "src/server/game/AI/ScriptedAI/ScriptedFollowerAI.h",
    "src/server/scripts/Spells/spell_generic.cpp",
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


def spawn_movement_type(template, spawn):
    return number(spawn, "MovementType") if "MovementType" in spawn else number(template, "MovementType")


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
                             project_point, script_bindings=(), smart_scripts=(), script_credits=()):
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
    cpp_credits = {(proof["questId"], proof["triggerId"]): proof for proof in script_credits
                   if bindings[proof["triggerId"]] == {proof["script"]}}
    points, omissions, evidence = defaultdict(lambda: defaultdict(list)), [], []
    candidates = _rows(relation_rows) + [{"quest": quest, "id": trigger}
                                        for quest, trigger in set(smart_credits) | set(cpp_credits)]
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
        elif (bindings[trigger_id] and (quest_id, trigger_id) not in smart_credits
              and (quest_id, trigger_id) not in cpp_credits):
            reason = "unprovedAreaTriggerScript"
        else:
            try:
                proof = cpp_credits.get((quest_id, trigger_id), {})
                if proof.get("displayZone"):
                    if number(trigger, "map") != proof.get("displayMap"):
                        raise ValueError("reviewed area map changed")
                    quest = dict(quest, QuestSortID=proof["displayZone"])
                projected = _point(project_point(trigger, quest))
            except (ValueError, TypeError, KeyError):
                projected = None
            if projected is None:
                reason = "unmappedAreaTrigger"
            else:
                zone, point = projected
                if point not in points[quest_id][zone]:
                    points[quest_id][zone].append(point)
                evidence.append(cpp_credits.get((quest_id, trigger_id),
                                {"questId": quest_id, "triggerId": trigger_id,
                                 "rule": "smartTriggerQuestCredit" if (quest_id, trigger_id) in smart_credits
                                 else "areaTriggerRelation"}))
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


def derive_cpp_escort_guide_packet(quest_templates, creature_templates, cpp_events, waypoint_rows,
                                  creature_spawns, project_point, quest_special_flags=None):
    """Project registered C++ escort credits at their explicit script_waypoint IDs."""
    quests, creatures = _templates(quest_templates, "ID"), _templates(creature_templates, "entry")
    paths, placements = defaultdict(list), defaultdict(list)
    for node in _rows(waypoint_rows):
        paths[number(node, "entry")].append(node)
    for spawn in _rows(creature_spawns):
        for entry in {number(spawn, key) for key in ("id1", "id2", "id3", "id", "entry")} - {0}:
            placements[entry].append(spawn)
    points, evidence, omissions, blocked = defaultdict(lambda: defaultdict(list)), [], [], set()
    candidates = cpp_events.get("escortWaypoints", ())
    proven_actors = defaultdict(set)
    proven_calls = defaultdict(Counter)

    def call_key(proof, entry):
        return (entry, proof["file"], proof["line"], proof.get("class"), proof["script"], proof.get("call"))

    for proof in candidates:
        proven_actors[proof["questId"]].add(("monster", proof["npcId"]))
        proven_calls[proof["questId"]][call_key(proof, proof["npcId"])] += 1
    for proof in candidates:
        quest_id, entry, point_id = proof["questId"], proof["npcId"], proof["pointId"]
        if quest_id not in quests:
            continue
        template, spawns = creatures.get(entry, {}), placements[entry]
        nodes = [node for node in paths[entry] if number(node, "pointid") == point_id]
        special = (quest_special_flags or {}).get(quest_id, number(quests[quest_id], "SpecialFlags"))
        reason = None
        if not special & 2:
            reason = "questDoesNotRequireExplorationEvent"
        elif (template.get("ScriptName") != proof["script"]
              or any(spawn.get("ScriptName") and spawn["ScriptName"] != proof["script"] for spawn in spawns)):
            reason = "overriddenEscortScript"
        elif {tuple(actor) for actor in cpp_events.get("events", {}).get(str(quest_id), ())} != proven_actors[quest_id]:
            reason = "unprovedAlternativeEscortActor"
        elif Counter(call_key(event, event["actor"][1])
                     for event in cpp_events.get("evidence", {}).get(str(quest_id), ())) != proven_calls[quest_id]:
            reason = "unprovedAlternativeEscortCredit"
        elif not spawns or len({number(spawn, "map") for spawn in spawns}) != 1:
            reason = "missingOrAmbiguousEscortPlacement"
        elif len(nodes) != 1:
            reason = "missingOrAmbiguousEscortWaypoint"
        projected = []
        if reason is None:
            try:
                if any(not math.isfinite(float(nodes[0][key])) for key in ("location_x", "location_y", "location_z")):
                    raise ValueError("non-finite escort coordinates")
                if (proof.get("requireLastPoint") and point_id != max(number(node, "pointid") for node in paths[entry])
                        or number(nodes[0], "waittime") < proof.get("minimumWaitMs", 0)):
                    raise ValueError("reviewed escort wait or final point changed")
                node = {"position_" + axis: nodes[0]["location_" + axis] for axis in ("x", "y", "z")}
                quest = quests[quest_id]
                if proof.get("displayZone"):
                    quest = dict(quest, QuestSortID=proof["displayZone"])
                projected = [_point(project_point(node, spawn, quest)) for spawn in spawns]
            except (ValueError, TypeError, KeyError, OverflowError):
                projected = []
            if not projected or any(point is None for point in projected):
                reason = "unmappedEscortEndpoint"
        if reason:
            blocked.add(quest_id)
            omissions.append({**proof, "reason": reason})
            continue
        for zone, point in projected:
            if point not in points[quest_id][zone]:
                points[quest_id][zone].append(point)
        evidence.append({**proof, "rule": "cppEscortWaypointCredit"})
    guides = {}
    for quest_id, zones in sorted(points.items()):
        if quest_id in blocked:
            continue
        entry = next(proof["npcId"] for proof in evidence if proof["questId"] == quest_id)
        description = str(quests[quest_id].get("AreaDescription") or "").strip()
        name = creatures[entry].get("name") or "the escort"
        guides[quest_id] = typed([description or f"Escort {name} to safety", dict(sorted(zones.items()))])
    return {"guides": guides, "evidence": evidence, "omissions": omissions}


def derive_cpp_destination_guide_packet(quest_templates, creature_templates, cpp_events,
                                       creature_spawns, project_point, quest_special_flags=None):
    """Project reviewed follower arrivals, proximity credits and fixed completion checks."""
    quests, creatures = _templates(quest_templates, "ID"), _templates(creature_templates, "entry")
    placements = defaultdict(list)
    for spawn in _rows(creature_spawns):
        for entry in {number(spawn, key) for key in ("id1", "id2", "id3", "id", "entry")} - {0}:
            placements[entry].append(spawn)
    candidates = [(kind, proof) for kind in ("followerDestinations", "coordinateCredits", "proximityCredits")
                  for proof in cpp_events.get(kind, ())]
    proof_calls = defaultdict(Counter)

    def key(proof, actor):
        return (tuple(actor), proof["file"], proof["line"], proof.get("class"), proof["script"], proof.get("call"))

    for _, proof in candidates:
        proof_calls[proof["questId"]][key(proof, proof["actor"])] += 1
    points, evidence, omissions, blocked = defaultdict(lambda: defaultdict(list)), [], [], set()
    for kind, proof in candidates:
        quest_id, actor = proof["questId"], proof["actor"]
        if quest_id not in quests or actor[0] != "monster":
            continue
        entry = actor[1]
        source_spawns = placements[entry]
        target = proof.get("destinationNpcId", entry)
        spawns = placements[target]
        reason = None
        special = (quest_special_flags or {}).get(quest_id, number(quests[quest_id], "SpecialFlags"))
        if not special & 2:
            reason = "questDoesNotRequireExplorationEvent"
        elif (creatures.get(entry, {}).get("ScriptName") != proof["script"]
              or any(row.get("ScriptName") and row["ScriptName"] != proof["script"] for row in source_spawns)):
            reason = "overriddenDestinationScript"
        elif Counter(key(row, row["actor"]) for row in cpp_events.get("evidence", {}).get(str(quest_id), ())) != proof_calls[quest_id]:
            reason = "unprovedAlternativeDestinationCredit"
        elif (target not in creatures or not spawns or not source_spawns or len({number(row, "map") for row in source_spawns}) != 1
              or {number(row, "map") for row in spawns} != {number(row, "map") for row in source_spawns}):
            reason = "missingOrAmbiguousDestinationPlacement"
        elif kind != "coordinateCredits" and (
                any(spawn_movement_type(creatures[target], row) for row in spawns)
                or target != entry and (creatures.get(target, {}).get("ScriptName")
                                        or creatures.get(target, {}).get("AIName")
                                        or any(row.get("ScriptName") for row in spawns))):
            reason = "movingOrScriptedDestination"
        projected = []
        if reason is None:
            try:
                quest = quests[quest_id]
                if proof.get("displayZone"):
                    if any(number(spawn, "map") != proof["displayMap"] for spawn in spawns):
                        raise ValueError("reviewed destination map changed")
                    quest = dict(quest, QuestSortID=proof["displayZone"])
                for spawn in spawns:
                    node = proof if kind == "coordinateCredits" else spawn
                    if any(not math.isfinite(float(node["position_" + axis])) for axis in ("x", "y", "z")):
                        raise ValueError("non-finite destination")
                    projected.append(_point(project_point(node, spawn, quest)))
            except (ValueError, TypeError, KeyError, OverflowError):
                projected = []
            if not projected or any(point is None for point in projected):
                reason = "unmappedDestination"
        if reason:
            blocked.add(quest_id)
            omissions.append({**proof, "reason": reason})
            continue
        for zone, point in projected:
            if point not in points[quest_id][zone]:
                points[quest_id][zone].append(point)
        evidence.append({**proof, "npcId": entry, "rule": "cpp" + kind[0].upper() + kind[1:]})
    guides = {}
    for quest_id, zones in sorted(points.items()):
        if quest_id not in blocked:
            quest = quests[quest_id]
            label = str(quest.get("AreaDescription") or "").strip() or "Complete " + str(quest.get("LogTitle") or quest_id)
            guides[quest_id] = typed([label, dict(sorted(zones.items()))])
    return {"guides": guides, "evidence": evidence, "omissions": omissions}


def derive_interaction_guide_packet(quest_templates, creature_templates, object_templates, interactions,
                                    creature_spawns, object_spawns, project_point, quest_special_flags=None):
    """Keep proved interactions as entity hints; project complete static object locations."""
    quests = _templates(quest_templates, "ID")
    templates = {"monster": _templates(creature_templates, "entry"), "object": _templates(object_templates, "entry")}
    placements = defaultdict(list)
    for spawn in _rows(creature_spawns):
        for entry in {number(spawn, key) for key in ("id1", "id2", "id3", "id", "entry")} - {0}:
            placements[("monster", entry)].append(spawn)
    for spawn in _rows(object_spawns):
        placements[("object", number(spawn, "id"))].append(spawn)
    points, hints, evidence, omissions, blocked = defaultdict(lambda: defaultdict(list)), [], [], [], set()
    for proof in interactions:
        quest_id, actor = proof["questId"], tuple(proof["actor"])
        kind, entry = actor
        if quest_id not in quests or kind not in templates:
            continue
        template, spawns = templates[kind].get(entry, {}), placements[actor]
        credit_actor = tuple(proof.get("creditActor", actor))
        credit_kind, credit_entry = credit_actor
        credit_template = templates.get(credit_kind, {}).get(credit_entry, {})
        credit_spawns = placements[credit_actor]
        special = (quest_special_flags or {}).get(quest_id, number(quests[quest_id], "SpecialFlags"))
        if (not special & 2 or not template or not spawns or not credit_template or not credit_spawns
                or proof.get("script") and credit_template.get("ScriptName") != proof["script"]
                or any(row.get("ScriptName") and row["ScriptName"] != credit_template.get("ScriptName") for row in credit_spawns)
                or any(row.get("ScriptName") and row["ScriptName"] != template.get("ScriptName") for row in spawns)):
            blocked.add(quest_id)
            omissions.append({**proof, "reason": "unprovedInteractionPlacementOrEvent"})
            continue
        if credit_actor != actor and ({number(row, "map") for row in credit_spawns}
                                      != {number(row, "map") for row in spawns}):
            blocked.add(quest_id)
            omissions.append({**proof, "reason": "ambiguousFollowInteractionMap"})
            continue
        label = proof.get("label") or str(quests[quest_id].get("AreaDescription") or "").strip()
        label = label or ("Interact with " if kind == "object" else "Speak with ") + str(template.get("name") or entry)
        hints.append({**proof, "label": label})
        evidence.append({**proof, "rule": proof.get("rule", "sourceQuestInteraction")})
        projected = []
        if kind == "object":
            try:
                projected = [_point(project_point(spawn, spawn, quests[quest_id])) for spawn in spawns]
            except (ValueError, TypeError, KeyError, OverflowError):
                projected = []
        if not projected or any(point is None for point in projected):
            blocked.add(quest_id)
            continue
        for zone, point in projected:
            if point not in points[quest_id][zone]:
                points[quest_id][zone].append(point)
    guides = {}
    for quest_id, zones in sorted(points.items()):
        if quest_id not in blocked:
            label = next(proof["label"] for proof in hints if proof["questId"] == quest_id)
            guides[quest_id] = typed([label, dict(sorted(zones.items()))])
    return {"guides": guides, "interactions": hints, "evidence": evidence, "omissions": omissions}


def append_interaction_hints(packet, interactions, skip_quests=()):
    """Append entity hints without renumbering existing optional travel objectives."""
    skipped = set(skip_quests)
    for proof in interactions:
        quest_id, actor = proof["questId"], proof["actor"]
        if quest_id in skipped:
            continue
        hints = packet["guides"].setdefault(quest_id, {})
        existing = [target for hint in hints.values() for target in hint.get("n:5", {}).values()]
        if typed(actor) in existing:
            continue
        index = max((int(key[2:]) for key in hints), default=0) + 1
        hints[f"n:{index}"] = typed({2: 3, 3: proof["label"], 4: 0, 5: [actor]})
        packet["evidence"].append({**proof, "rule": proof.get("rule", "sourceQuestInteraction")})


def combine_location_guide_packets(packets, event_sources):
    """Combine proved alternatives while requiring coverage of known completion actors."""
    result = {"guides": {}, "evidence": [], "omissions": [], "supersededOmissions": []}

    def superseded(omission, evidence):
        if omission.get("reason") not in ("unsupportedEscortActivation", "unprovedEscortCompletionFlow",
                                           "unprovedEscortPlayersOrScriptBinding"):
            return False
        return any(proof.get("rule") == "smartExplicitWaypointCredit"
                   and proof.get("sourceType") == 0
                   and proof.get("scriptEntry") == omission.get("scriptEntry")
                   and proof.get("actor") == ["monster", omission.get("npcId")]
                   and omission.get("pathId") in proof.get("pathIds", ()) for proof in evidence)

    candidates = sorted({quest for packet in packets for quest in packet["guides"]})
    for quest_id in candidates:
        selected = [packet for packet in packets if quest_id in packet["guides"]]
        evidence = [proof for packet in selected for proof in packet["evidence"] if proof["questId"] == quest_id]
        covered = {tuple(proof["actor"]) if "actor" in proof else ("monster", proof["npcId"])
                   for proof in evidence}
        known = {tuple(actor) for actor in event_sources.get(str(quest_id), ())}
        unresolved = [proof for packet in packets for proof in packet["omissions"]
                      if proof["questId"] == quest_id and not superseded(proof, evidence)]
        if not covered or known - covered or unresolved:
            result["omissions"].append({"questId": quest_id, "reason": "unprovedAlternativeEscortActor"})
            continue
        points = defaultdict(list)
        for packet in selected:
            for zone, rows in packet["guides"][quest_id]["n:2"].items():
                for point in rows.values():
                    if point not in points[zone]:
                        points[zone].append(point)
        first = selected[0]["guides"][quest_id]
        result["guides"][quest_id] = {"n:1": first["n:1"],
            "n:2": {zone: {f"n:{index}": point for index, point in enumerate(rows, 1)}
                    for zone, rows in sorted(points.items())}}
        result["evidence"].extend(evidence)
    for packet in packets:
        for proof in packet["omissions"]:
            target = "supersededOmissions" if proof["questId"] in result["guides"] else "omissions"
            result[target].append(proof)
    return result


def derive_escort_guide_packet(quest_templates, creature_templates, scripts, waypoint_rows,
                              creature_spawns, project_point, conditions=(), quest_special_flags=None):
    """Prove quest-accept escorts completed by EndPath or explicit waypoint credit."""
    quests, creatures = _templates(quest_templates, "ID"), _templates(creature_templates, "entry")
    scripts, spawns = _rows(scripts), _rows(creature_spawns)
    candidates = [row for row in scripts if number(row, "source_type") == 0
                  and compatibility.is_quest_escort_start(row)]
    if not candidates:
        return {"guides": {}, "evidence": [], "omissions": []}
    paths, by_entry = defaultdict(list), defaultdict(list)
    by_guid = {}
    for row in _rows(waypoint_rows):
        paths[number(row, "entry")].append(row)
    for row in spawns:
        by_guid[number(row, "guid")] = row
        entries = {number(row, key) for key in ("id1", "id2", "id3", "id", "entry")} - {0}
        for entry in entries:
            by_entry[entry].append(row)
    contexts = dict(compatibility._source_context(creatures, {}, scripts, spawns))
    player_lists = compatibility._known_player_lists(creatures, {}, scripts, contexts, spawns, set(paths))
    guid_scripts = {-number(row, "entryorguid") for row in scripts
                    if number(row, "source_type") == 0 and number(row, "entryorguid") < 0}
    entry_scripts = {number(row, "entryorguid") for row in scripts
                     if number(row, "source_type") == 0 and number(row, "entryorguid") > 0}
    conditional = {(number(row, "SourceId"), number(row, "SourceEntry")) for row in _rows(conditions)
                   if number(row, "SourceTypeOrReferenceId") == 22}
    points, evidence, omissions, blocked = defaultdict(lambda: defaultdict(list)), [], [], set()

    for row in candidates:
        quest_id = number(row, "action_param4") or number(row, "event_param1")
        if quest_id not in quests:
            continue
        owner, path_id = number(row, "entryorguid"), number(row, "action_param2")
        placement = by_guid.get(-owner) if owner < 0 else None
        entry = (number(placement or {}, "id1") or number(placement or {}, "id")) if owner < 0 else owner
        actor = ("monster", entry, -owner) if owner < 0 else ("monster", entry)
        placements = [placement] if placement else by_entry.get(entry, []) if owner > 0 else []
        actions = [action for action in contexts.get(actor, ()) if float(action.get("event_chance", 100)) > 0]
        nodes = sorted(paths.get(path_id, ()), key=lambda node: number(node, "pointid"))
        parents = defaultdict(list)
        action_ids = Counter(number(action, "id") for action in actions if number(action, "source_type") == 0)
        for action in actions:
            if number(action, "link"):
                parents[number(action, "link")].append(action)

        def event_chain(action, seen=frozenset()):
            identity = number(action, "id")
            if number(action, "source_type") != 0 or identity in seen or action_ids[identity] != 1:
                return []
            if number(action, "event_type") != 61:
                return [action]
            preceding = parents.get(identity, ())
            if len(preceding) != 1:
                return []
            chain = event_chain(preceding[0], seen | {identity})
            return chain + [action] if chain else []

        activation = event_chain(row)
        credits = [action for action in actions if number(action, "action_type") in (15, 26)
                   and number(action, "action_param1") == quest_id]
        credit_chains = [event_chain(action) for action in credits]
        point_id = len(nodes)
        proof = {"questId": quest_id, "npcId": entry, "pathId": path_id,
                 "scriptEntry": owner, "rowId": number(row, "id")}
        reason = None
        special = (quest_special_flags or {}).get(quest_id, number(quests[quest_id], "SpecialFlags"))
        if not special & 2:
            reason = "questDoesNotRequireExplorationEvent"
        elif (not activation or number(activation[0], "event_type") != 19
                or number(activation[0], "event_param1") != quest_id
                or number(row, "action_param4") != quest_id
                or number(row, "target_type") not in ((1, 7) if credits else (7,))):
            reason = "unsupportedEscortActivation"
        elif not actions or not credits and (actor, compatibility.SMART_ESCORT_TARGETS) not in player_lists:
            reason = "unprovedEscortPlayersOrScriptBinding"
        elif (number(row, "action_param3") or (0, owner) in conditional
              or any(number(action, "event_phase_mask") or float(action.get("event_chance", 100)) != 100
                     for action in activation)):
            reason = "conditionalOrRepeatingEscort"
        elif not nodes or [number(node, "pointid") for node in nodes] != list(range(1, len(nodes) + 1)):
            reason = "missingOrNoncontiguousEscortPath"
        elif not placements or len({number(spawn, "map") for spawn in placements}) != 1:
            reason = "missingOrAmbiguousEscortPlacement"
        elif (owner > 0 and any(number(spawn, "guid") in guid_scripts for spawn in placements)
              or owner < 0 and entry in entry_scripts and number(creatures[entry], "flags_extra") & 0x08000000
              or any(spawn.get("ScriptName") for spawn in placements)):
            # CreatureData.h: CREATURE_FLAG_EXTRA_DONT_OVERRIDE_ENTRY_SAI merges
            # generic scripts into GUID scripts; neither isolated context proves it.
            reason = "overriddenOrMergedEscortScript"
        elif any(number(action, "action_type") in (62, 69, 80, 87, 88)
                 or number(action, "action_type") == 55 and not number(action, "action_param3")
                 or number(action, "action_type") == 53 and (
                     number(action, "action_param2") != path_id
                     or not event_chain(action) or number(event_chain(action)[0], "event_type") != 19
                     or number(action, "target_type") not in ((1, 7) if credits else (7,))
                     or number(action, "action_param4") <= 0)
                 for action in actions):
            reason = "unprovedEscortCompletionFlow"
        if reason is None and credits:
            valid_credits = all(
                chain and number(chain[0], "event_type") == 40
                and number(chain[0], "event_param2") in (0, path_id)
                and 1 <= number(chain[0], "event_param1") <= len(nodes)
                and all(not number(action, "event_phase_mask")
                        and float(action.get("event_chance", 100)) == 100 for action in chain)
                and number(credit, "target_type") == 12
                and (actor, number(credit, "target_param1")) in player_lists
                for credit, chain in zip(credits, credit_chains))
            points_credited = {number(chain[0], "event_param1") for chain in credit_chains if chain}
            for credit in credits:
                identifier = number(credit, "target_param1")
                writers = [action for action in actions if number(action, "action_type") == 64
                           and number(action, "action_param1") == identifier]
                if identifier == compatibility.SMART_ESCORT_TARGETS:
                    valid_credits &= number(row, "target_type") == 7 and not writers
                else:
                    valid_credits &= bool(writers) and all(
                        number(writer, "target_type") == 7 and event_chain(writer)
                        and number(event_chain(writer)[0], "event_type") == 19
                        and number(event_chain(writer)[0], "event_param1") == quest_id
                        and all(not number(action, "event_phase_mask")
                                and float(action.get("event_chance", 100)) == 100
                                for action in event_chain(writer)) for writer in writers)
            if not valid_credits or len(points_credited) != 1:
                reason = "unprovedEscortCompletionFlow"
            else:
                point_id = points_credited.pop()
        if reason is None:
            def terminal_despawn(action, seen=frozenset()):
                identity = number(action, "id")
                if identity in seen:
                    return False
                event = number(action, "event_type")
                if event == 6:
                    return True
                if event == 40:
                    return (number(action, "event_param1") in (point_id, len(nodes))
                            and number(action, "event_param2") in (0, path_id))
                preceding = parents.get(identity, ())
                return event == 61 and bool(preceding) and all(
                    terminal_despawn(parent, seen | {identity}) for parent in preceding)

            if any(number(action, "action_type") == 41 and not terminal_despawn(action) for action in actions):
                reason = "unprovedEarlyEscortDespawn"
        projected = []
        if reason is None:
            try:
                if any(not math.isfinite(float(node[key])) for node in nodes
                       for key in ("position_x", "position_y", "position_z")):
                    raise ValueError("non-finite escort coordinates")
                projected = [_point(project_point(nodes[point_id - 1], spawn, quests[quest_id])) for spawn in placements]
            except (ValueError, TypeError, KeyError, OverflowError):
                projected = []
            if not projected or any(point is None for point in projected):
                reason = "unmappedEscortEndpoint"
        if reason:
            blocked.add(quest_id)
            omissions.append({**proof, "reason": reason})
            continue
        for zone, point in projected:
            if point not in points[quest_id][zone]:
                points[quest_id][zone].append(point)
        evidence.append({**proof, "pointId": point_id,
                         "rule": "smartEscortWaypointCredit" if credits else "smartEscortEndPathCredit"})
    guides = {}
    for quest_id, zones in sorted(points.items()):
        if quest_id in blocked:
            continue
        actor = next(proof["npcId"] for proof in evidence if proof["questId"] == quest_id)
        description = str(quests[quest_id].get("AreaDescription") or "").strip()
        name = creatures[actor].get("name") or "the escort"
        guides[quest_id] = typed([description or f"Escort {name} to safety", dict(sorted(zones.items()))])
    return {"guides": guides, "evidence": evidence, "omissions": omissions}


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


# Reviewed coordinates from Questie d695e9048, checked against current fishing loot below.
# Quest 9205 also uses Jademir Lake reports: https://www.wowhead.com/ptr-2/item=13890/plated-armorfish#comments
FISHING_GUIDES = {
    (1141, 12238): (12238, ((148, 148, [[35.71, 44.68]]),)),
    (1579, 6717): (6717, ((148, 148, [[35.71, 44.68]]),)),
    (1580, 6718): (6718, ((456, 148, [[50.7, 23.8]]), (454, 148, [[40, 73.6]]))),
    (6607, 16967): (16967, ((2521, 357, [[62.6, 50.2]]),)),
    (6607, 16970): (16970, ((300, 8, [[90.2, 22.4]]),)),
    (6607, 16968): (16968, ((598, 405, [[25.8, 77.4]]),)),
    (6607, 16969): (16969, ((301, 33, [[27.7, 21]]), (1578, 33, [[27.4, 68.9]]))),
    (9205, 13890): (13890, ((1112, 357, [[49, 11]]),)),
    (11665, 34864): (34864, ((1519, 1519, [[48.5, 67.9], [45.7, 60.5], [45.4, 53.3], [35.7, 45.6],
                                      [34.3, 59], [51.8, 47.1], [60.2, 46.6], [65.2, 53.7],
                                      [61.1, 37], [65.6, 32], [55.9, 33.5], [50.9, 23.8]]),
                         (1637, 1637, [[70.4, 28.3], [67.8, 33.7], [64.8, 26], [35.2, 78.6],
                                      [37.6, 81.7], [33.3, 84.4], [36.3, 86]]))),
    (11666, 34865): (34865, ((3519, 3519, [[51.9, 34.7], [55.3, 44.1], [60.2, 53.9]]),)),
    (11667, 34868): (34868, ((3614, 3518, [[62, 35]]),)),
    (11668, 34866): (35313, ((3521, 3521, [[75.6, 82.9]]),)),
    (11669, 34867): (34867, ((3483, 3483, [[39.4, 43]]), (3520, 3520, [[24, 32.5], [31.9, 29.9], [40.1, 60.1]]))),
    (13830, 45902): (45902, ((4290, 3711, [[48.2, 63.4]]),)),
    (13832, 45903): (45903, ((4560, 4560, [[46, 68]]),)),
    (13834, 45904): (45904, ((4197, 4197, [[70, 36], [63, 60], [50, 44], [37.6, 36],
                                                    [56, 66], [42, 75], [34.7, 19.5]]),)),
    (13836, 45323): (45328, ((4567, 4395, [[67.43, 61.38], [62.43, 70.05]]),)),
}


FISHING_POOL_GUIDES = {
    (13833, 45905): (45905, ((194479, 3537, [[57.5, 33.2], [62.2, 64.2], [45, 45]]),)),
}


def append_fishing_hints(packet, quest_templates, item_templates, fishing_rows, reference_rows, item_loot_rows,
                         object_templates=(), object_loot_rows=()):
    """Restore reviewed water locations only while their source acquisition still exists."""
    from generate_acore_item_corrections import resolve_loot_rows

    quests, items = _templates(quest_templates, "ID"), _templates(item_templates, "entry")
    references, fishing, containers, object_loot = (defaultdict(list) for _ in range(4))
    for row in _rows(reference_rows):
        references[number(row, "Entry")].append(row)
    for row in _rows(fishing_rows):
        fishing[number(row, "Entry")].append(row)
    for row in _rows(item_loot_rows):
        containers[number(row, "Entry")].append(row)
    for row in _rows(object_loot_rows):
        object_loot[number(row, "Entry")].append(row)
    catches = {area: resolve_loot_rows(rows, references) for area, rows in fishing.items()}
    objects = _templates(object_templates, "entry")
    pools = {entry: resolve_loot_rows(object_loot[number(row, "Data1")], references)
             for entry, row in objects.items() if number(row, "type") == 25}
    for catalog, sources, source_field in ((FISHING_GUIDES, catches, "fishingAreaIds"),
                                            (FISHING_POOL_GUIDES, pools, "fishingObjectIds")):
        for (quest_id, item), (catch, locations) in catalog.items():
            quest = quests.get(quest_id)
            if (not quest or item not in items or catch not in items
                    or any(number(quest, "RequiredNpcOrGo" + str(i)) for i in range(1, 5))):
                continue
            required = [number(quest, "RequiredItemId" + str(i)) for i in range(1, 7)
                        if number(quest, "RequiredItemId" + str(i)) and number(quest, "RequiredItemCount" + str(i)) > 0]
            source_items = {number(quest, "ItemDrop" + str(i)) for i in range(1, 5)
                            if number(quest, "ItemDropQuantity" + str(i)) > 0}
            if item not in required and item not in source_items:
                continue
            if catch != item and item not in resolve_loot_rows(containers[catch], references):
                continue
            points, source_ids = {}, []
            for source_id, zone, coordinates in locations:
                if catch in sources.get(source_id, ()):
                    points.setdefault(zone, []).extend([list(point) for point in coordinates])
                    source_ids.append(source_id)
            if not points:
                continue
            label = "Fish for " + str(items[catch].get("name") or catch)
            if source_field == "fishingObjectIds":
                label = "Create a " + str(objects[source_ids[0]]["name"]) + " in water, then fish for " + str(items[catch]["name"])
            if catch != item:
                label += " and open it for " + str(items[item].get("name") or item)
            hints = packet["guides"].setdefault(quest_id, {})
            index = max((int(key[2:]) for key in hints), default=0) + 1
            hint = {1: points, 2: 20, 3: label, 4: required.index(item) + 1 if item in required else 0}
            if item not in required:
                hint[5] = [["item", item]]
            hints[f"n:{index}"] = typed(hint)
            packet["evidence"].append({"questId": quest_id, "rule": "reviewedFishingLocation",
                                       "itemId": item, "fishingItemId": catch, source_field: source_ids})
