"""Source-derived interaction sites for unlocated summon and credit objectives.

Guides describe where players perform an objective. They do not turn summoned
creatures or invisible credit markers into permanent static NPC placements.
"""
from collections import defaultdict
import math
from pathlib import Path
import re

from acore_item_compatibility import number
from acore_scripted_geometry import typed
import acore_quest_compatibility as compatibility
import acore_quest_guides as common


CORE_SOURCE_FILES = (
    "src/server/game/Spells/SpellEffects.cpp",
    "src/server/game/Spells/Auras/SpellAuraEffects.cpp",
    "src/server/game/Entities/GameObject/GameObject.cpp",
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
)
CORE_REQUIREMENTS = {
    CORE_SOURCE_FILES[0]: (
        "void Spell::EffectSummonType(SpellEffIndex effIndex)",
        "uint32 entry = m_spellInfo->Effects[effIndex].MiscValue;",
        "void Spell::EffectKillCredit(SpellEffIndex effIndex)",
        "player->RewardPlayerAndGroupAtEvent(creatureEntry, unitTarget);",
    ),
    CORE_SOURCE_FILES[1]: (
        "HandleProcTriggerSpellAuraProc(aurApp, eventInfo);",
        "m_spellInfo->Effects[GetEffIndex()].TriggerSpell",
    ),
    CORE_SOURCE_FILES[2]: (
        "GetMap()->ScriptsStart(sEventScripts, info->goober.eventId, player, this);",
    ),
    CORE_SOURCE_FILES[3]: (
        "case SMART_ACTION_CAST:", "case SMART_ACTION_SEND_TARGET_TO_TARGET:",
    ),
}


def validate_source(source_root):
    for relative, fragments in CORE_REQUIREMENTS.items():
        text = (Path(source_root) / relative).read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S))
        if any(re.sub(r"\s+", "", fragment) not in compact for fragment in fragments):
            raise ValueError("Quest spell guides require core source review: " + relative)


def _rows(values):
    return list(values.values()) if isinstance(values, dict) else list(values or ())


def _templates(values, key):
    return ({int(identity): row for identity, row in values.items()} if isinstance(values, dict)
            else {number(row, key): row for row in values or ()})


def _targets(quest):
    result, index = [], 0
    for slot in range(1, 5):
        entry = number(quest, "RequiredNpcOrGo" + str(slot))
        if entry and number(quest, "RequiredNpcOrGoCount" + str(slot)) > 0:
            index += 1
            if entry > 0:
                result.append((entry, index))
    return result


def _field(value, index):
    if isinstance(value, dict):
        return value.get("n:" + str(index), value.get(index))
    return value[index - 1] if isinstance(value, (list, tuple)) and len(value) >= index else None


def _item_spell_paths(root, spells, omissions, quest_id, item_id):
    """Keep player-cast trigger chains and self-applied periodic/proc auras."""
    result, stack = [], [(root, ())]
    while stack:
        spell_id, path = stack.pop()
        if spell_id in path or len(path) >= 12:
            omissions.append({"questId": quest_id, "itemId": item_id, "spellId": spell_id,
                              "reason": "cyclicOrDeepItemSpellChain"})
            continue
        path = path + (spell_id,)
        result.append((spell_id, path))
        row = spells.get(spell_id, {})
        for slot in (1, 2, 3):
            child = number(row, "EffectTriggerSpell" + str(slot))
            effect = number(row, "Effect" + str(slot))
            if child <= 0:
                continue
            self_aura = (effect == 6 and number(row, "EffectApplyAuraName" + str(slot)) in (23, 42)
                         and number(row, "EffectImplicitTargetA" + str(slot)) == 1
                         and not number(row, "EffectImplicitTargetB" + str(slot)))
            self_trigger = (effect == 64 and number(row, "EffectImplicitTargetA" + str(slot)) == 1
                            and not number(row, "EffectImplicitTargetB" + str(slot)))
            if self_trigger or self_aura:
                stack.append((child, path))
    return result


def _summon_children(spell):
    result = set()
    for slot in (1, 2, 3):
        # No selectors (SQL-only spells) use the caster's destination. Nearby
        # entry selectors, explicit victims and remote destinations need their
        # own proof; never borrow the caster's static coordinates for those.
        selectors = {number(spell, "EffectImplicitTarget" + side + str(slot)) for side in ("A", "B")}
        if number(spell, "Effect" + str(slot)) == 28 and selectors <= {0, 1, 18, 22, 41, 42, 43, 44, 47}:
            entry = number(spell, "EffectMiscValue" + str(slot))
            if entry > 0:
                result.add(entry)
    return result


def _self_action_path(root, scripts, seen=None):
    """Follow linked actions and self-owned timed lists, retaining their owner."""
    seen = set() if seen is None else seen
    node = number(root, "source_type"), number(root, "entryorguid")
    identity = (*node, number(root, "id"))
    if identity in seen:
        return []
    seen.add(identity)
    result = [root]
    if number(root, "action_type") == 80 and number(root, "target_type") == 1:
        children = [row for row in scripts if number(row, "source_type") == 9
                    and number(row, "entryorguid") == number(root, "action_param1")]
        for row in children:
            result.extend(_self_action_path(row, scripts, seen))
    link = number(root, "link")
    if link:
        following = [row for row in scripts if (number(row, "source_type"), number(row, "entryorguid")) == node
                     and number(row, "id") == link and number(row, "event_type") == 61]
        if len(following) == 1:
            result.extend(_self_action_path(following[0], scripts, seen))
    return result


def _drinking_providers(scripts, contexts, known_lists, spells):
    """Prove the reviewed zero-selector group credit through the same player list."""
    spell = spells.get(36421, {})
    effects = [slot for slot in (1, 2, 3) if number(spell, "Effect" + str(slot))]
    if (effects != [1] or number(spell, "Effect1") != 134 or number(spell, "EffectMiscValue1") != 21241
            or number(spell, "EffectImplicitTargetA1") or number(spell, "EffectImplicitTargetB1")):
        return []
    result = []
    trigger_actions = contexts.get(("monster", 21241), ())
    for send in trigger_actions:
        actor = ("monster", number(send, "target_param1"))
        player_list = number(send, "action_param1")
        if number(send, "action_type") != 100 or number(send, "target_type") != 19 or player_list <= 0:
            continue
        linked = [row for row in trigger_actions if number(row, "id") == number(send, "link")
                  and number(row, "event_type") == 61]
        if len(linked) != 1:
            continue
        data = linked[0]
        if (number(data, "action_type") != 45 or number(data, "target_type") != 19
                or number(data, "target_param1") != actor[1]):
            continue
        actions = contexts.get(actor, ())

        def credits(path):
            return any(number(cast, "action_type") == 11 and number(cast, "action_param1") == 36421
                       and number(cast, "target_type") == 12 and number(cast, "target_param1") == player_list
                       and float(cast.get("event_chance", 100)) > 0
                       and compatibility._player_target(cast, actions, known_lists, actor) for cast in path)

        for receive in actions:
            if (number(receive, "source_type") != 0 or number(receive, "event_type") != 38
                    or number(receive, "event_param1") != number(data, "action_param1")
                    or number(receive, "event_param2") != number(data, "action_param2")):
                continue
            path = _self_action_path(receive, scripts)
            if credits(path):
                result.append(actor)
                break
            # Current brute/Korgaah scripts first move to the keg, then their
            # phase-bound trigger-range handler starts the credit action list.
            moves_to_keg = any(number(row, "action_type") == 69 and number(row, "target_type") == 19
                               and number(row, "target_param1") == 21241 for row in path)
            phases = {number(row, "action_param1") for row in path if number(row, "action_type") == 22}
            if not moves_to_keg:
                continue
            for nearby in actions:
                phase_mask = number(nearby, "event_phase_mask")
                if (number(nearby, "source_type") == 0 and number(nearby, "event_type") == 75
                        and number(nearby, "event_param2") == 21241 and number(nearby, "event_param3") > 0
                        and any(phase > 0 and phase_mask & (1 << (phase - 1)) for phase in phases)
                        and credits(_self_action_path(nearby, scripts))):
                    result.append(actor)
                    break
    return sorted(set(result))


def derive(quests, items, spells, scripts, conditions, creature_templates, object_templates,
           creature_spawns, object_spawns, event_scripts, credit_sources, project_point, *,
           existing_guides=None, source_root=None, area_groups=None):
    """Return typed extra objectives, retaining the server's actual kill IDs."""
    quests, items = _templates(quests, "ID"), _templates(items, "entry")
    creatures, objects = _templates(creature_templates, "entry"), _templates(object_templates, "entry")
    spells = {int(key): row for key, row in (spells or {}).items()}
    scripts, conditions, events = _rows(scripts), _rows(conditions), _rows(event_scripts)
    spawns = {"monster": defaultdict(list), "object": defaultdict(list)}
    for row in _rows(creature_spawns):
        for entry in {number(row, field) for field in ("id", "id1", "id2", "id3", "entry")} - {0}:
            spawns["monster"][entry].append(row)
    for row in _rows(object_spawns):
        spawns["object"][number(row, "id")].append(row)
    packet = {"guides": {}, "evidence": [], "omissions": []}
    position_cache = {}

    def positions(kind, entry, quest_id, guid=None, area_restrictions=()):
        key = kind, entry, quest_id, guid, area_restrictions
        if key in position_cache:
            return position_cache[key]
        points, guids = defaultdict(list), []
        for spawn in spawns[kind].get(entry, ()):
            if guid and number(spawn, "guid") != guid:
                continue
            if number(spawn, "phaseMask") != 1 or spawn.get("ScriptName"):
                continue
            spawn_areas = {number(spawn, "zoneId"), number(spawn, "areaId")} - {0}
            if any(not spawn_areas.intersection((area_groups or {}).get(group, ()))
                   for group in area_restrictions):
                continue
            try:
                zone, point = project_point(spawn, quests[quest_id])
            except (ValueError, KeyError, TypeError, OverflowError):
                continue
            if (type(zone) is not int or zone <= 0 or not isinstance(point, (list, tuple)) or len(point) < 2
                    or any(type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 100 for v in point[:2])):
                continue
            if list(point[:2]) not in points[zone]:
                points[zone].append(list(point[:2]))
            guids.append(number(spawn, "guid"))
        result = {zone: sorted(values) for zone, values in sorted(points.items())}, sorted(set(guids))
        position_cache[key] = result
        return result

    contexts = {actor: list(actions) for actor, actions in compatibility._source_context(
        creatures, objects, scripts, creature_spawns)}
    providers = defaultdict(list)
    for actor, actions in contexts.items():
        if actor[0] != "monster" or any(number(row, "action_type") in (44, 62) for row in actions):
            continue
        for cast in actions:
            event = number(cast, "event_type")
            if (number(cast, "action_type") != 11 or number(cast, "target_type") != 1
                    or event not in (6, 8) or number(cast, "event_phase_mask")
                    or not number(cast, "action_param2") & 2
                    or float(cast.get("event_chance", 100)) <= 0):
                continue
            spell = number(cast, "action_param1")
            proof = {"summonSpellId": spell}
            if event == 8:
                proof["requiredHitSpellId"] = number(cast, "event_param1")
                if not proof["requiredHitSpellId"]:
                    continue
            for child in _summon_children(spells.get(spell, {})):
                providers[child].append((actor, "smartSelfSummonsObjective", proof))
    for credit, actors in (credit_sources or {}).items():
        for actor in actors:
            if actor[0] in spawns and int(actor[1]) != int(credit):
                providers[int(credit)].append((tuple(actor), "sourceCreditProvider", {}))

    # Reviewed SQL-only group-credit spell. Its zero implicit selectors are not
    # enough for the general credit mapper: the explicit SAI recipient must be
    # proved to be the player saved by the item-created trigger.
    known_lists = compatibility._known_player_lists(creatures, objects, scripts, contexts, creature_spawns)
    drink_providers = _drinking_providers(scripts, contexts, known_lists, spells)

    target_conditions = common._spell_target_conditions(conditions, spells, creatures, objects)
    event_summons = defaultdict(set)
    for row in events:
        if number(row, "command") == 10 and number(row, "datalong") > 0:
            event_summons[number(row, "id")].add(number(row, "datalong"))
    object_providers = defaultdict(list)
    for obj, template in objects.items():
        if (number(template, "type") == 10 and not template.get("ScriptName")
                and template.get("AIName", "") in ("", "SmartGameObjectAI")):
            for child in event_summons[number(template, "Data2")]:
                object_providers[child].append(obj)

    for quest_id, quest in sorted(quests.items()):
        missing = [(target, index) for target, index in _targets(quest)
                   if not positions("monster", target, quest_id)[0]]
        if not missing:
            continue
        hints, proof_by_hint, covered = {}, {}, set()
        previous = existing_guides or {}
        if "guides" in previous:
            previous = previous["guides"]
        previous = _rows(previous.get(quest_id, previous.get(str(quest_id), {})))

        def add(actor, index, target, rule, proof, label, area_restrictions=()):
            kind, entry = actor[:2]
            coords, guids = positions(kind, entry, quest_id, actor[2] if len(actor) > 2 else None,
                                      area_restrictions)
            if not coords:
                return
            for hint in previous:
                if _field(hint, 4) not in (None, 0, index):
                    continue
                refs = _rows(_field(hint, 5))
                already_referenced = any((_field(ref, 1), _field(ref, 2)) == (kind, entry) for ref in refs)
                if already_referenced or _field(hint, 1) == typed(coords):
                    covered.add(target)
                    return
            key = kind, entry, index
            hint = {2: 3, 3: label, 4: index}
            template = creatures.get(entry, {})
            template_credit = (kind == "monster" and len(actor) == 2 and not area_restrictions
                               and rule == "sourceCreditProvider"
                               and target in (number(template, "KillCredit1"), number(template, "KillCredit2")))
            if template_credit:
                # Every copy grants this template credit. Reuse the NPC row's
                # geometry and runtime visibility instead of duplicating it.
                hint[5] = [[kind, entry]]
            else:
                hint[1] = coords
            hints[key] = hint
            proof_by_hint[key] = {"questId": quest_id, "objectiveNpcId": target, "actor": list(actor),
                                  "rule": rule, "sourceGuids": guids, "realObjectiveIndex": index, **proof}
            if template_credit:
                proof_by_hint[key]["geometry"] = "npcReference"
            covered.add(target)

        for target, index in missing:
            for actor, rule, proof in providers[target]:
                if "requiredHitSpellId" in proof:
                    continue  # The quest item chain must reach the spell that causes the summon.
                name = (creatures if actor[0] == "monster" else objects).get(actor[1], {}).get("name", str(actor[1]))
                add(actor, index, target, rule, proof, "Complete the objective near " + str(name))
            for obj in object_providers[target]:
                template = objects[obj]
                # Goober quest restrictions may bind it to one other quest.
                if number(template, "Data1") not in (0, quest_id):
                    continue
                label = "Use " + str(template.get("name") or obj) + " to summon " + str(creatures.get(target, {}).get("name") or target)
                add(("object", obj), index, target, "gooberEventSummonsObjective",
                    {"eventId": number(template, "Data2")}, label)

        for item_id in sorted(common._quest_items(quest)):
            item = items.get(item_id, {})
            if item.get("ScriptName"):
                continue
            for slot in range(1, 6):
                root = number(item, "spellid" + str(slot))
                if root <= 0 or number(item, "spelltrigger" + str(slot)) not in (0, 5):
                    continue
                if (item_id == 30353 and root == 35129 and 21241 in {target for target, _ in missing}
                        and 21241 in _summon_children(spells.get(root, {}))):
                    index = next(index for target, index in missing if target == 21241)
                    for actor in drink_providers:
                        label = "Place " + str(item.get("name") or item_id) + " near " + str(creatures[actor[1]].get("name") or actor[1])
                        add(actor, index, 21241, "storedPlayerSpellCredit",
                            {"itemId": item_id, "itemSpellId": root, "creditSpellId": 36421}, label)
                for spell, path in _item_spell_paths(root, spells, packet["omissions"], quest_id, item_id):
                    groups = tuple(sorted({number(spells.get(step, {}), "AreaGroupId") for step in path} - {0}))
                    for actor in sorted(target_conditions[spell]):
                        matching = [(target, index) for target, index in missing
                                    if any(provider[:2] == actor
                                           and proof.get("requiredHitSpellId", spell) == spell
                                           for provider, _, proof in providers[target])]
                        if not matching:
                            continue
                        name = (creatures if actor[0] == "monster" else objects)[actor[1]].get("name") or actor[1]
                        label = "Use " + str(item.get("name") or item_id) + " near " + str(name)
                        for target, index in matching:
                            add(actor, index, target, "questItemTriggeredSpellTarget",
                                {"itemId": item_id, "spellPath": list(path)}, label, groups)
        if hints:
            ordered = sorted(hints)
            packet["guides"][quest_id] = typed([hints[key] for key in ordered])
            packet["evidence"].extend(proof_by_hint[key] for key in ordered)
        for target, index in missing:
            if target not in covered:
                packet["omissions"].append({"questId": quest_id, "objectiveNpcId": target,
                                             "realObjectiveIndex": index, "reason": "noProvedObjectiveGuide"})
    if packet["guides"] and source_root is not None:
        validate_source(source_root)
    return packet
