"""Source proofs for Questie quest relationships and objective display helpers."""
from collections import defaultdict
import copy
import re


def indexed(values):
    return {f"n:{i}": value for i, value in enumerate(values, 1)}


def derive_in_group_with(quest_ids, addon_rows):
    """Negative ExclusiveGroup identifies quests required together by the core."""
    active = set(quest_ids)
    groups = defaultdict(set)
    for row in addon_rows:
        quest_id, group = int(row["ID"]), int(row.get("ExclusiveGroup") or 0)
        if quest_id in active and group < 0:
            groups[group].add(quest_id)
    result = {str(quest_id): {} for quest_id in active}
    for members in groups.values():
        for quest_id in members:
            result[str(quest_id)] = indexed(sorted(members - {quest_id}))
    return result


def derive_reputation_objective(template):
    """Faction1 is the completion objective; Faction2 is an eligibility ceiling."""
    faction = int(template.get("RequiredFactionId1") or 0)
    return indexed([faction, int(template.get("RequiredFactionValue1") or 0)]) if faction else {}


def source_available_until_completed(conditions):
    """Extract a single conjunctive not-rewarded gate without flattening ORs."""
    by_quest = defaultdict(list)
    for row in conditions:
        if int(row.get("SourceTypeOrReferenceId") or 0) == 19:
            by_quest[int(row["SourceEntry"])].append(row)
    result = {}
    for quest_id, rows in by_quest.items():
        if any(int(row.get(field) or 0) for row in rows for field in ("SourceGroup", "SourceId", "ElseGroup")):
            continue
        if any(int(row.get("ConditionTypeOrReference") or 0) < 0 for row in rows):
            continue
        gates = {int(row.get("ConditionValue1") or 0) for row in rows
                 if int(row.get("ConditionTypeOrReference") or 0) == 8
                 and int(row.get("NegativeCondition") or 0) == 1}
        if len(gates) == 1 and next(iter(gates)) > 0:
            result[str(quest_id)] = gates.pop()
    return result


def _templates(rows):
    if isinstance(rows, dict):
        return {int(key): row for key, row in rows.items()}
    return {int(row["entry"]): row for row in rows}


def _creature_spawn_entries(creature_spawns):
    entries = {}
    rows = creature_spawns.values() if isinstance(creature_spawns, dict) else creature_spawns
    for row in rows:
        if isinstance(row, dict):
            guid = int(row.get("guid") or 0)
            entry = int(row.get("id1", row.get("id", row.get("entry", 0))) or 0)
            if guid > 0 and entry > 0:
                entries[guid] = entry
    if isinstance(creature_spawns, dict):
        for key, value in creature_spawns.items():
            if type(value) is int and int(key) > 0 and value > 0:
                entries[int(key)] = value
    return entries


def _source_context(creature_templates, object_templates, smart_scripts, creature_spawns=()):
    creatures, objects = _templates(creature_templates), _templates(object_templates)
    spawn_entries = _creature_spawn_entries(creature_spawns)
    nodes = defaultdict(list)
    for row in smart_scripts:
        nodes[(int(row["source_type"]), int(row["entryorguid"]))].append(row)

    def actions(node, visiting=frozenset()):
        if node in visiting:
            return
        for row in nodes.get(node, ()):
            yield row
            action, target = int(row.get("action_type") or 0), int(row.get("target_type") or 0)
            if target not in (0, 1):
                continue
            if action == 80:
                children = [int(row.get("action_param1") or 0)]
            elif action == 87:
                children = [int(row.get(f"action_param{i}") or 0) for i in range(1, 7)]
            elif action == 88:
                first, last = int(row.get("action_param1") or 0), int(row.get("action_param2") or 0)
                children = range(first, last + 1) if 0 < first <= last < first + 1000 else ()
            else:
                children = ()
            for child in children:
                if child > 0:
                    yield from actions((9, child), visiting | {node})

    contexts = defaultdict(list)
    for node in nodes:
        source_type, identifier = node
        if source_type not in (0, 1) or identifier == 0:
            continue
        guid = -identifier if identifier < 0 else None
        if guid is not None:
            identifier = spawn_entries.get(-identifier) if source_type == 0 else None
            if identifier is None:
                continue
        template = (creatures if source_type == 0 else objects).get(identifier, {})
        expected_ai = "SmartAI" if source_type == 0 else "SmartGameObjectAI"
        if template.get("AIName") == expected_ai and not template.get("ScriptName"):
            actor = ("monster" if source_type == 0 else "object", identifier)
            # Each spawned actor owns its stored lists. GUID scripts must not
            # borrow player provenance from another spawn of the same entry.
            if guid is not None:
                actor += (guid,)
            contexts[actor].extend(actions(node))
    yield from contexts.items()


PLAYER_TARGETS = frozenset({7, 16, 17, 18, 21, 23, 27, 201})
SMART_ESCORT_TARGETS = 0xFFFFFF


def _valid_escort_start(actor, row, escort_paths):
    # SmartAI::StartPath requires an existing, nonempty Smart waypoint path.
    path = int(row.get("action_param2") or 0)
    return actor[0] == "monster" and path > 0 and escort_paths is not None and path in escort_paths


def _player_target(row, actions, known_lists=None, actor=None):
    target = int(row.get("target_type") or 0)
    if target in PLAYER_TARGETS:
        return True
    if target != 12:
        return False
    if known_lists is not None:
        return (actor, int(row.get("target_param1") or 0)) in known_lists
    writers = defaultdict(list)
    for action in actions:
        if int(action.get("action_type") or 0) == 64:
            writers[int(action.get("action_param1") or 0)].append(action)
    known = set()
    while True:
        added = {identifier for identifier, values in writers.items() if identifier not in known and all(
            int(value.get("target_type") or 0) in PLAYER_TARGETS or
            int(value.get("target_type") or 0) == 12 and int(value.get("target_param1") or 0) in known
            for value in values)}
        if not added:
            break
        known.update(added)
    return int(row.get("target_param1") or 0) in known


def _row_key(row):
    return tuple(int(row.get(key) or 0) for key in ("source_type", "entryorguid", "id", "link"))


def _known_player_lists(creature_templates, object_templates, scripts, contexts, creature_spawns=(), escort_paths=None):
    """Follow explicit stored-list copies, including cross-actor SAI100 sends.

    Every writer must supply players. Unknown sender contexts, unresolved GUID
    bindings, non-player stores and unanchored cycles cannot establish a list.
    """
    creatures, objects = _templates(creature_templates), _templates(object_templates)
    spawn_entries = _creature_spawn_entries(creature_spawns)

    def receiver(row):
        target = int(row.get("target_type") or 0)
        first, second = int(row.get("target_param1") or 0), int(row.get("target_param2") or 0)
        if target in (9, 11, 19) and first in creatures:
            actors = [actor for actor in contexts if actor[:2] == ("monster", first)] or [("monster", first)]
            return [(actor, True) for actor in actors]
        if target == 10:
            actual = spawn_entries.get(first)
            if actual in creatures and (not second or actual == second):
                actor = ("monster", actual, first)
                return [(actor if actor in contexts else ("monster", actual), True)]
            if second in creatures:
                actors = [actor for actor in contexts if actor[:2] == ("monster", second)] or [("monster", second)]
                return [(actor, False) for actor in actors]
        if target in (13, 15, 20) and first in objects:
            return [(("object", first), True)]
        return []

    writers = defaultdict(list)
    attributed = set()
    for actor, actions in contexts.items():
        for row in actions:
            attributed.add(_row_key(row))
            action = int(row.get("action_type") or 0)
            identifier = int(row.get("action_param1") or 0)
            if action == 64:
                target = int(row.get("target_type") or 0)
                # SMART_TARGET_NONE stores an empty vector. Clearing a list
                # adds no non-player recipient, but cannot establish players.
                if target == 0:
                    continue
                source = True if target in PLAYER_TARGETS else (actor, int(row.get("target_param1") or 0)) if target == 12 else False
                writers[(actor, identifier)].append(source)
            elif action == 53 and actor[0] == "monster" and escort_paths is not None:
                # ESCORT_START stores its player targets in the core's reserved
                # list. Creature/object-only targets leave the old list intact.
                target = int(row.get("target_type") or 0)
                if target in PLAYER_TARGETS:
                    writers[(actor, SMART_ESCORT_TARGETS)].append(_valid_escort_start(actor, row, escort_paths))
                elif target == 12:
                    source_list = int(row.get("target_param1") or 0)
                    if source_list != SMART_ESCORT_TARGETS:
                        source = (actor, source_list) if _valid_escort_start(actor, row, escort_paths) else False
                        writers[(actor, SMART_ESCORT_TARGETS)].append(source)
                elif target not in (0, 1, 9, 10, 11, 13, 14, 15, 19, 20):
                    writers[(actor, SMART_ESCORT_TARGETS)].append(False)
            elif action == 100:
                for target_actor, resolved in receiver(row):
                    writers[(target_actor, identifier)].append((actor, identifier) if resolved else False)
    for row in scripts:
        if int(row.get("action_type") or 0) == 100 and _row_key(row) not in attributed:
            for target_actor, _ in receiver(row):
                writers[(target_actor, int(row.get("action_param1") or 0))].append(False)
    known = set()
    while True:
        added = {node for node, sources in writers.items() if node not in known and
                 all(source is True or source is not False and source in known for source in sources)}
        if not added:
            break
        known.update(added)
    return known


def build_event_sources(creature_templates, object_templates, smart_scripts, creature_spawns=(), *, escort_paths=None):
    """Find the actual entities executing a quest exploration/event completion."""
    result = defaultdict(set)
    contexts = {actor: list(actions) for actor, actions in _source_context(creature_templates, object_templates, smart_scripts, creature_spawns)}
    known_lists = _known_player_lists(creature_templates, object_templates, smart_scripts, contexts, creature_spawns, escort_paths)
    for actor, actions in contexts.items():
        for row in actions:
            action, quest_id = int(row.get("action_type") or 0), int(row.get("action_param1") or 0)
            if action in (15, 26) and quest_id > 0 and _player_target(row, actions, known_lists, actor):
                result[quest_id].add(actor[:2])
            elif action == 53 and _valid_escort_start(actor, row, escort_paths):
                # EndPath awards wpStart.quest to the reserved escort players;
                # it does not use the movement mode in action_param1 as a quest.
                escort_quest = int(row.get("action_param4") or 0)
                if escort_quest > 0 and (actor, SMART_ESCORT_TARGETS) in known_lists:
                    result[escort_quest].add(actor[:2])
    return {str(quest): [list(actor) for actor in sorted(actors)] for quest, actors in sorted(result.items())}


def build_credit_sources(creature_templates, object_templates, smart_scripts, spells, creature_spawns=(), *, escort_paths=None):
    """Map actual credit IDs to their emitting entities, never unrelated spawns.

    Creature KillCredit1/2, bound SmartAI actions, and credit spell effects are
    explicit source links. Cross-actor action-list calls are excluded because
    their actions run on another entity. C++ relationships need separate proofs.
    """
    creatures = _templates(creature_templates)
    spell_rows = {int(key): row for key, row in spells.items()}
    result = defaultdict(set)
    for creature, template in creatures.items():
        for field in ("KillCredit1", "KillCredit2"):
            credit = int(template.get(field) or 0)
            if credit:
                result[credit].add(("monster", creature))

    spell_cache = {}

    def spell_credits(spell_id, visiting=frozenset()):
        if spell_id in spell_cache:
            return spell_cache[spell_id]
        if spell_id in visiting:
            return set()
        row = spell_rows.get(spell_id, {})
        credits = set()
        for slot in (1, 2, 3):
            effect = int(row.get(f"Effect{slot}") or 0)
            targets = {int(row.get(f"EffectImplicitTarget{side}{slot}") or 0) for side in ("A", "B")}
            if not targets & {6, 21, 25, 35, 45, 57}:
                continue
            if effect in (90, 134):
                credit = int(row.get(f"EffectMiscValue{slot}") or 0)
                if credit:
                    credits.add(credit)
            if effect in (32, 64, 140, 141, 142, 148, 151):
                trigger = int(row.get(f"EffectTriggerSpell{slot}") or 0)
                if trigger:
                    credits.update(spell_credits(trigger, visiting | {spell_id}))
        # A cyclic branch may produce a partial answer; don't memoize it.
        if not visiting:
            spell_cache[spell_id] = credits
        return credits

    contexts = {actor: list(actions) for actor, actions in _source_context(creature_templates, object_templates, smart_scripts, creature_spawns)}
    known_lists = _known_player_lists(creature_templates, object_templates, smart_scripts, contexts, creature_spawns, escort_paths)
    for actor, actions in contexts.items():
        for row in actions:
            action, first = int(row.get("action_type") or 0), int(row.get("action_param1") or 0)
            loot_recipient = actor[0] == "monster" and int(row.get("target_type") or 0) in (0, 1)
            if action == 33 and first and (loot_recipient or _player_target(row, actions, known_lists, actor)):
                result[first].add(actor[:2])
            elif action == 36 and first in creatures and actor[0] == "monster":
                result[first].add(actor[:2])
            elif action == 11 and _player_target(row, actions, known_lists, actor):
                for credit in spell_credits(first):
                    result[credit].add(actor[:2])
    return {str(credit): [list(actor) for actor in sorted(actors)] for credit, actors in sorted(result.items())}


def _array(value):
    if not isinstance(value, dict) or set(value) != {f"n:{i}" for i in range(1, len(value) + 1)}:
        raise ValueError("Expected a dense typed array")
    return [value[f"n:{i}"] for i in range(1, len(value) + 1)]


def verify_objective_display(source, display, credit_sources, event_sources=(), *, quest_id=None, spells=None):
    """Return a conservative proof for a complete proposed objective view.

    Display text/icons may decorate verified targets. Every server objective
    must still have exactly one corresponding display record, and each credit
    expansion member must have an explicit source link to that objective.
    """
    try:
        if not isinstance(source, dict) or not isinstance(display, dict):
            return False, "invalidObjectiveShape"
        if set(display) - {"n:1", "n:2", "n:3", "n:4", "n:5", "n:6"}:
            return False, "unsupportedObjectiveCategory"
        if display.get("n:4", {}) != source.get("n:4", {}):
            return False, "reputationObjectiveChanged"
        remaining = []
        labels = {"n:1": "monster", "n:2": "object", "n:3": "item"}
        for category, label in labels.items():
            for record in _array(source.get(category, {})):
                if not isinstance(record, dict) or type(record.get("n:1")) is not int:
                    return False, "unsupportedSourceObjectiveShape"
                remaining.append((label, record["n:1"]))
        displayed = []
        for category, label in labels.items():
            for record in _array(display.get(category, {})):
                if not isinstance(record, dict) or type(record.get("n:1")) is not int:
                    return False, "unsupportedDisplayObjectiveShape"
                displayed.append((label, [record["n:1"]], None))
        for record in _array(display.get("n:5", {})):
            ids = _array(record.get("n:1", {}))
            base = record.get("n:2")
            if not ids or type(base) is not int or any(type(value) is not int for value in ids):
                return False, "unsupportedCreditObjectiveShape"
            displayed.append(("monster", ids, base))
        event_used = False
        for record in _array(display.get("n:6", {})):
            spell_id = record.get("n:1")
            spell = (spells or {}).get(str(spell_id), (spells or {}).get(spell_id, {}))
            supported = type(quest_id) is int and any(
                int(spell.get(f"Effect{i}") or 0) == 16 and int(spell.get(f"EffectMiscValue{i}") or 0) == quest_id and
                {int(spell.get(f"EffectImplicitTarget{side}{i}") or 0) for side in ("A", "B")} & {6, 21, 25, 35, 45, 57}
                for i in (1, 2, 3))
            if event_used or type(spell_id) is not int or not supported:
                return False, "unprovedQuestCompletionSpell"
            event_used = True
        event_actors = {tuple(actor) for actor in event_sources}
        for label, ids, base in displayed:
            matches = []
            for slot, (source_kind, credit) in enumerate(remaining):
                if base is not None and (source_kind != "monster" or base != credit):
                    continue
                actors = {tuple(actor) for actor in credit_sources.get(str(credit), ())} if source_kind == "monster" else set()
                if all((label == source_kind and entity == credit) or (label, entity) in actors for entity in ids):
                    matches.append(slot)
            if not matches and base is None and not event_used and len(ids) == 1 and (label, ids[0]) in event_actors:
                event_used = True
                continue
            if len(matches) != 1:
                return False, "unprovedOrAmbiguousDisplayTarget"
            remaining.pop(matches[0])
        if remaining:
            return False, "sourceObjectiveRemoved"
        return True, "verifiedSourceTargets"
    except (KeyError, TypeError, ValueError):
        return False, "invalidObjectiveShape"


def source_objectives_with_reputation(objectives, template):
    result = copy.deepcopy(objectives)
    reputation = derive_reputation_objective(template)
    if reputation:
        result["n:4"] = reputation
    return result


def _number(row, key):
    value = row.get(key)
    if value is None and key[-1:].isdigit():
        value = row.get(key[:-1] + "_" + key[-1])
    return int(value or 0)


def build_required_tool_index(item_templates, spells):
    """Build once per source extraction; the quest loop reuses these indices."""
    templates = _templates(item_templates)
    spell_rows = {int(key): row for key, row in spells.items()}
    item_spells = {item: sorted({_number(row, f"spellid{i}") for i in range(1, 6)
                                if _number(row, f"spellid{i}") > 0 and _number(row, f"spelltrigger{i}") in (0, 5)})
                   for item, row in templates.items()}
    reagents, creates, creators = {}, {}, defaultdict(set)
    for spell_id, row in spell_rows.items():
        reagents[spell_id] = {_number(row, f"Reagent{i}") for i in range(1, 9)} - {0}
        creates[spell_id] = {_number(row, f"EffectItemType{i}") for i in (1, 2, 3)
                            if _number(row, f"Effect{i}") in (24, 157)} - {0}
        for item in creates[spell_id]:
            creators[item].add(spell_id)
    return {"templates": templates, "itemSpells": item_spells, "spellReagents": reagents,
            "spellCreates": creates, "itemCreators": dict(creators)}


def _normalized_words(text):
    return re.sub(r"[^a-z0-9]+", " ", str(text).lower().replace("'", "").replace("’", "")).strip()


def _named_quest_item(item, quest_text):
    name = _normalized_words(item.get("name", ""))
    words = name.split()
    common = {"bait", "water", "oil", "torch", "elixir", "wand", "dust", "meat", "key", "blood", "sword", "shield", "letter", "gem"}
    if not words or len(words) == 1 and (len(name) < 8 or name in common):
        return False
    variants = {name}
    without_ordinal = [word for word in words if word not in {"first", "second", "third", "fourth", "fifth"}]
    # A named set such as Dertrok's four wands is an explicit quest instruction.
    # Removing the ordinal remains specific only with a named possessive owner.
    if without_ordinal != words and len(without_ordinal) >= 2 and ("'s" in item.get("name", "").lower() or "’s" in item.get("name", "").lower()):
        variants.add(" ".join(without_ordinal))
    variants.update(value + "s" for value in tuple(variants) if not value.endswith("s"))
    return any(re.search(r"(?<![a-z0-9])" + re.escape(value) + r"(?![a-z0-9])", quest_text) for value in variants)


def derive_required_tool_items(quest, item_templates, spells, candidate_ids=(), *, with_reasons=False, index=None):
    """Derive auxiliary tools from source items, recipes and explicit quest text.

    Candidates are proposals to verify, never authority. Main objective items are
    excluded from the auxiliary list because the runtime tracks them separately.
    Text evidence uses specific item names, including named ordinal sets, rather
    than generic words such as 'elixir', 'wand' or 'bait'.
    """
    index = build_required_tool_index(item_templates, spells) if index is None else index
    templates = index["templates"]
    objective_items = {_number(quest, f"RequiredItemId{i}") for i in range(1, 7)} - {0}
    provided = _number(quest, "StartItem")
    drops = {_number(quest, f"ItemDrop{i}") for i in range(1, 5)} - {0}
    seeds = drops | ({provided} if provided else set())
    result, reasons = set(), defaultdict(list)

    def add(item, rule, **details):
        if item > 0 and item in templates:
            result.add(item)
            reason = {"rule": rule, **details}
            if reason not in reasons[str(item)]:
                reasons[str(item)].append(reason)

    if provided:
        add(provided, "questProvidedItem")
    for item in drops:
        add(item, "questItemDrop")
    text = _normalized_words(" ".join(str(quest.get(key) or "") for key in
                             ("LogDescription", "QuestDescription", "QuestCompletionLog", "AreaDescription")))
    candidates = {int(value) for value in candidate_ids if type(value) is int and value > 0}
    for candidate in sorted(candidates):
        if candidate in templates and _named_quest_item(templates[candidate], text):
            add(candidate, "explicitQuestTextNamedItem", itemName=templates[candidate].get("name"))

    # An objective's combine-item recipe can be invoked by a proposed component
    # even when ItemDrop only names the upstream tool (the five Khan gems).
    associated_spells = {spell for item in seeds | candidates for spell in index["itemSpells"].get(item, ())}
    for goal in sorted(objective_items):
        for spell in index["itemCreators"].get(goal, set()) & associated_spells:
            for item in index["spellReagents"].get(spell, ()):
                add(item, "questObjectiveCreationReagent", spellId=spell, objectiveItem=goal)

    visited = set()
    while (result - visited) - (objective_items - seeds):
        tool = min((result - visited) - (objective_items - seeds))
        visited.add(tool)
        for spell in index["itemSpells"].get(tool, ()):
            for item in index["spellReagents"].get(spell, ()):
                add(item, "questToolSpellReagent", spellId=spell, toolItem=tool)
            created = index["spellCreates"].get(spell, ())
            for item in created:
                if item not in objective_items:
                    add(item, "questToolCreatedItem", spellId=spell, toolItem=tool)
    omitted = sorted(result & objective_items)
    values = sorted(result - objective_items)
    if with_reasons:
        return {"items": values, "reasons": {str(item): reasons[str(item)] for item in values},
                "omittedObjectiveItems": omitted}
    return values
