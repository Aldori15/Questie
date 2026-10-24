"""Derive Questie item-use classification and indirect acquisition sources."""

from collections import defaultdict
from pathlib import Path
import re
import math


CPP_RULES = (
    ("npcDrops", 9453, "npc_aquementas", "Kalimdor/zone_tanaris.cpp", ()),
    ("npcDrops", 3057, "npc_cairne_bloodhoof", "Kalimdor/zone_thunder_bluff.cpp", ("SPELL_CAIRNES_HOOFPRINT",)),
    ("npcDrops", 33224, "npc_lake_frog", "Northrend/zone_grizzly_hills.cpp", ("SPELL_SUMMON_ASHWOOD_BRAND",)),
    ("objectDrops", 169294, "go_tablet_of_the_seven", "World/go_scripts.cpp", (15065,)),
    ("objectDrops", 188458, "go_seer_of_zebhalak", "World/go_scripts.cpp", (47293,)),
    ("objectDrops", 185921, "go_bashir_crystalforge", "World/go_scripts.cpp",
     ("SPELL_CREATE_1_FLASK_OF_SORCERER", "SPELL_CREATE_5_FLASK_OF_SORCERER")),
    ("objectDrops", 188666, "go_amberpine_outhouse", "World/go_scripts.cpp",
     ("SPELL_INDISPOSED_MALE", "SPELL_INDISPOSED_FEMALE")),
)
BOUND_SPELL_RULES = {
    "spell_q9452_cast_net": "src/server/scripts/Spells/spell_quest.cpp",
    "spell_catch_the_wild_wolpertinger": "src/server/scripts/Events/brewfest.cpp",
}
CPP_LOOT_MODE_RULES = {
    "boss_flame_leviathan": "src/server/scripts/Northrend/Ulduar/Ulduar/boss_flame_leviathan.cpp",
    "boss_yoggsaron": "src/server/scripts/Northrend/Ulduar/Ulduar/boss_yoggsaron.cpp",
}
CPP_SOURCE_FILES = tuple(sorted({"src/server/scripts/" + rule[3] for rule in CPP_RULES} |
                                set(BOUND_SPELL_RULES.values()) |
                                set(CPP_LOOT_MODE_RULES.values()) |
                                 {"src/server/game/AI/SmartScripts/SmartAI.cpp",
                                  "src/server/game/Entities/GameObject/GameObject.cpp",
                                  "src/server/game/Entities/GameObject/GameObject.h",
                                  "src/server/game/Entities/Player/Player.cpp",
                                  "src/server/shared/SharedDefines.h",
                                 "src/server/game/Spells/Auras/SpellAuraDefines.h",
                                 "src/server/game/Entities/Creature/Creature.h",
                                 "src/server/scripts/Northrend/Ulduar/Ulduar/ulduar.h"}))


def number(row, name):
    value = row.get(name)
    if value is None and name[-1:].isdigit():
        value = row.get(name[:-1] + "_" + name[-1])
    return int(value or 0)


def quest_use_class(template, source):
    """Questie's class 12 enables usable quest-item buttons, not item tooltips.

    Call only for an explicitly scoped UI policy. Lost quest relationships or
    item spells restore the current server class instead of a stale override.
    """
    actual = int(source.get("class", template.get("class", 0)))
    related = bool(source.get("isStartItem") or source.get("relatedQuests"))
    usable = number(template, "InventoryType") > 0 or any(number(template, "spellid" + str(i)) > 0 and
                 number(template, "spelltrigger" + str(i)) in (0, 5)
                 for i in range(1, 6))
    return 12 if related and usable else actual


def created_items(spell):
    return {number(spell, "EffectItemType" + str(i)) for i in range(1, 4)
            if number(spell, "Effect" + str(i)) in (24, 157)
            and number(spell, "EffectItemType" + str(i)) > 0}


def _player_items(spell, recipient):
    result = set()
    for i in range(1, 4):
        if number(spell, "Effect" + str(i)) not in (24, 157):
            continue
        targets = {number(spell, "EffectImplicitTarget" + side + str(i)) for side in ("A", "B")}
        explicit = bool(targets & {6, 21, 25})
        caster = 1 in targets
        # CREATE_ITEM's effect metadata uses the explicit unit when A/B are
        # unset (SpellInfo.cpp / SelectEffectTypeImplicitTargets).
        fallback = targets == {0}
        valid = (explicit or fallback) if recipient == "explicit" else caster if recipient == "caster" else (explicit or caster or fallback)
        item = number(spell, "EffectItemType" + str(i))
        if valid and item > 0:
            result.add(item)
    return result


def _linked_player_items(spell_id, spells, spell_links, recipient, active=frozenset()):
    """Follow type-zero casts without changing the known player recipient.

    Positive cast links retain caster and explicit target. Negative links run
    on aura removal and make the aura recipient cast on itself; accept those
    only after proving that the original aura was applied to the player.
    """
    if spell_id in active:
        return set()
    spell = spells.get(spell_id, {})
    result = _player_items(spell, recipient)
    active = active | {spell_id}
    player_aura = any(number(spell, "Effect" + str(index)) == 6 and
        ((recipient in ("caster", "self") and number(spell, "EffectImplicitTargetA" + str(index)) == 1) or
         (recipient in ("explicit", "self") and number(spell, "EffectImplicitTargetA" + str(index)) in (6, 21, 25)))
        and number(spell, "EffectImplicitTargetB" + str(index)) == 0 for index in range(1, 4))
    for link in spell_links:
        trigger, effect = number(link, "spell_trigger"), number(link, "spell_effect")
        if number(link, "type") != 0 or effect <= 0:
            continue
        if trigger == spell_id:
            result.update(_linked_player_items(effect, spells, spell_links, recipient, active))
        elif trigger == -spell_id and player_aura:
            result.update(_linked_player_items(effect, spells, spell_links, "self", active))
    return result


def collect(item_templates, creature_templates, object_templates, scripts, spells,
            conditions=(), spell_scripts=(), creature_spawns=(), spell_links=()):
    """Return source-backed interaction POIs; these are not drop probabilities.

    Supported rules are direct invoker grants, player-targeted creation spells,
    and item-use spells with explicit spell-focus or creature/object conditions.
    Timed lists are attributed only through self-targeted calls. Unsupported
    actor handoffs and C++ hooks need their own reviewed derivation.
    """
    templates = {int(k): v for k, v in item_templates.items()}
    npcs = {int(k): v for k, v in creature_templates.items()}
    objects = {int(k): v for k, v in object_templates.items()}
    spells = {int(k): v for k, v in spells.items()}
    callers = defaultdict(set)
    timed_lists = {number(row, "entryorguid") for row in scripts if number(row, "source_type") == 9}
    for row in scripts:
        action = number(row, "action_type")
        if action not in (80, 87, 88) or number(row, "target_type") != 1:
            continue
        targets = ([number(row, "action_param1")] if action == 80 else
                   [entry for entry in timed_lists if number(row, "action_param1") <= entry <= number(row, "action_param2")] if action == 88 else
                   [number(row, "action_param" + str(index)) for index in range(1, 7)])
        for target in targets:
            if target:
                callers[(9, target)].add((number(row, "source_type"), number(row, "entryorguid")))

    def roots(node, seen=frozenset()):
        if node in seen:
            return set()
        kind, entry = node
        if entry > 0 and kind in (0, 1):
            template = (npcs if kind == 0 else objects).get(entry, {})
            expected = "SmartAI" if kind == 0 else "SmartGameObjectAI"
            return {node} if template.get("AIName") == expected and not template.get("ScriptName") else set()
        return {root for parent in callers[node] for root in roots(parent, seen | {node})}

    spawn_rows = creature_spawns.values() if isinstance(creature_spawns, dict) else creature_spawns
    spawn_entries = {number(row, "guid"): number(row, "id1") or number(row, "id")
                     for row in spawn_rows}

    def provenance_roots(row):
        node = number(row, "source_type"), number(row, "entryorguid")
        if node[0] == 0 and node[1] < 0 and spawn_entries.get(-node[1]) in npcs:
            return {(0, spawn_entries[-node[1]])}
        return roots(node) or ({node} if node[0] in (0, 1, 2) else set())

    contexts = defaultdict(list)
    for row in scripts:
        for root in provenance_roots(row):
            contexts[root].append(row)
    writers = defaultdict(list)
    for root, rows in contexts.items():
        for row in rows:
            if number(row, "action_type") != 64:
                continue
            target, identifier = number(row, "target_type"), number(row, "action_param1")
            writers[(root, identifier)].append(True if target == 7 else
                (root, number(row, "target_param1")) if target == 12 else False)

    dynamic_sends = []
    for row in scripts:
        if number(row, "action_type") != 100:
            continue
        target, entry = number(row, "target_type"), number(row, "target_param1")
        identifier = number(row, "action_param1")
        if target in (9, 11, 19, 204):
            receiver = (0, entry)
        elif target in (13, 15, 20):
            receiver = (1, entry)
        elif target == 10:
            actual, expected = spawn_entries.get(entry), number(row, "target_param2")
            receiver = (0, actual) if actual and expected in (0, actual) else (0, expected) if expected else None
        else:
            receiver = None
        senders = provenance_roots(row)
        payloads = [(sender, identifier) for sender in senders] or [False]
        if receiver is None:
            dynamic_sends.append((identifier, payloads))
        else:
            writers[(receiver, identifier)].extend(payloads)

    def proven(payload, known):
        return payload is True or payload is not False and payload in known

    known = set()
    while True:
        added = {node for node, values in writers.items() if node not in known and
                 all(proven(value, known) for value in values)}
        if not added:
            break
        known.update(added)
    # A dynamic send cannot establish a recipient's list. Its already-proven
    # player payload is harmless to another player list; unknown payloads are
    # removed, including every list depending on them.
    while True:
        unsafe = {node for node in known if
                  not all(proven(value, known) for value in writers[node]) or
                  any(identifier == node[1] and not all(proven(value, known) for value in payloads)
                      for identifier, payloads in dynamic_sends)}
        if not unsafe:
            break
        known.difference_update(unsafe)

    def player_target(row, root, selector="target_type", parameter="target_param1"):
        target = number(row, selector)
        return target == 7 or target == 12 and (root, number(row, parameter)) in known

    sources, evidence = defaultdict(lambda: defaultdict(set)), []

    def add(item, field, entry, rule, detail):
        if item not in templates:
            return
        sources[item][field].add(entry)
        evidence.append({"itemId": item, "field": field, "sourceId": entry,
                         "rule": rule, **detail})

    for row in scripts:
        action = number(row, "action_type")
        target = number(row, "target_type")
        if action == 56 and target == 7:
            items = {number(row, "action_param1")} if number(row, "action_param2") > 0 else set()
        elif action in (11, 85, 134) and target == 7:
            items = _linked_player_items(number(row, "action_param1"), spells, spell_links,
                                         "explicit" if action == 11 else "self")
        elif action == 86:
            items = None
        else:
            continue
        for root in roots((number(row, "source_type"), number(row, "entryorguid"))):
            kind, entry = root
            granted = items
            if action == 86:
                if not player_target(row, root) or not player_target(
                        row, root, "action_param3", "action_param4"):
                    continue
                granted = _linked_player_items(number(row, "action_param1"), spells, spell_links, "self")
            for item in granted:
                add(item, "npcDrops" if kind == 0 else "objectDrops", entry, "smartInvokerGrant",
                    {"sourceType": number(row, "source_type"), "scriptEntry": number(row, "entryorguid"),
                     "scriptId": number(row, "id"), "spellId": number(row, "action_param1") if action != 56 else None,
                     "actionType": action})

    focuses = defaultdict(set)
    for entry, obj in objects.items():
        if number(obj, "type") == 8 and number(obj, "Data0") > 0:
            focuses[number(obj, "Data0")].add(entry)
        if number(obj, "type") == 10 and not obj.get("ScriptName"):
            spell_id = number(obj, "Data10")
            for item in _linked_player_items(spell_id, spells, spell_links, "self"):
                add(item, "objectDrops", entry, "gooberUseSpell", {"spellId": spell_id})
            for script in spell_scripts:
                index = number(script, "effIndex") + 1
                if (number(script, "id") != spell_id or index not in (1, 2, 3) or
                        number(spells.get(spell_id, {}), "Effect" + str(index)) != 77 or
                        number(spells.get(spell_id, {}), "EffectImplicitTargetA" + str(index)) != 25 or
                        number(spells.get(spell_id, {}), "EffectImplicitTargetB" + str(index)) != 0 or
                        number(script, "command") != 15 or number(script, "datalong2") != 2 or
                        number(script, "dataint") != 0):
                    continue
                created_spell = number(script, "datalong")
                for item in _player_items(spells.get(created_spell, {}), "caster"):
                    add(item, "objectDrops", entry, "gooberScriptPlayerCast",
                        {"spellId": spell_id, "effectIndex": index - 1, "createdSpellId": created_spell})
    targeted = defaultdict(set)
    for condition in conditions:
        source_type = number(condition, "SourceTypeOrReferenceId")
        if source_type not in (13, 17):
            continue
        if number(condition, "ConditionTarget") != (0 if source_type == 13 else 1):
            continue
        if number(condition, "ConditionTypeOrReference") != 31 or number(condition, "NegativeCondition"):
            continue
        kind, entry = number(condition, "ConditionValue1"), number(condition, "ConditionValue2")
        guid = number(condition, "ConditionValue3")
        if (kind == 3 and guid > 1) or (kind == 5 and guid != 0):
            continue  # A GUID restriction does not establish a template-wide POI.
        if (kind == 3 and entry in npcs) or (kind == 5 and entry in objects):
            targeted[number(condition, "SourceEntry")].add(("npcDrops" if kind == 3 else "objectDrops", entry))
    used = set()
    for template in templates.values():
        for i in range(1, 6):
            spell = number(template, "spellid" + str(i))
            if spell > 0 and number(template, "spelltrigger" + str(i)) in (0, 5):
                used.add(spell)
    for spell_id in sorted(used):
        spell = spells.get(spell_id, {})
        for item in _linked_player_items(spell_id, spells, spell_links, "self"):
            for entry in focuses[number(spell, "RequiresSpellFocus")]:
                add(item, "objectDrops", entry, "itemUseSpellFocus", {"spellId": spell_id})
        for item in _linked_player_items(spell_id, spells, spell_links, "caster"):
            for field, entry in targeted[spell_id]:
                add(item, field, entry, "itemUseTargetCondition", {"spellId": spell_id})
    return {"sources": {str(item): {field: sorted(values) for field, values in fields.items()}
                        for item, fields in sorted(sources.items())}, "evidence": evidence}


def cpp_spell_ids(source_root):
    """Numeric spell dependencies of the bounded C++ acquisition rules."""
    result = set()
    for _, _, _, relative, selectors in CPP_RULES:
        if not selectors:
            continue
        path = Path(source_root) / "src/server/scripts" / relative
        text = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(encoding="utf-8"), flags=re.S)
        for selector in selectors:
            if isinstance(selector, int):
                result.add(selector)
                continue
            match = re.search(r"\b" + re.escape(selector) + r"\s*=\s*(\d+)\s*(?=[,;}])", text)
            if not match:
                raise ValueError("Missing item-acquisition C++ spell: " + selector)
            result.add(int(match[1]))
    return result


def bound_spell_ids(bindings):
    return {number(row, "spell_id") for row in bindings
            if row.get("ScriptName") in BOUND_SPELL_RULES and number(row, "spell_id") > 0}


def _cpp_text(path):
    return re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(encoding="utf-8"), flags=re.S)


def _cpp_integer(text, name):
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\s*(?=[,;}])", text)
    if not match:
        raise ValueError("Missing bound item-script identity: " + name)
    return int(match[1])


def _cpp_class(text, name, base):
    match = re.search(r"\bclass\s+" + re.escape(name) + r"\s*:\s*public\s+" + re.escape(base) + r"\s*\{", text)
    if not match:
        raise ValueError("Unsupported bound item-script class: " + name)
    start, depth = match.end(), 1
    for end in range(start, len(text)):
        depth += (text[end] == "{") - (text[end] == "}")
        if not depth:
            return text[start:end]
    raise ValueError("Unterminated bound item-script class: " + name)


def _cpp_require(text, fragment):
    if re.sub(r"\s+", "", fragment) not in re.sub(r"\s+", "", text):
        raise ValueError("Unsupported bound item-script delivery: " + fragment)


def collect_cpp_loot_modes(source_root, creature_templates):
    """Combined loot masks supported by the bound encounter state machines.

    Reference rows retain the complete mask. Testing an isolated hard-mode
    bit would incorrectly discard ordinary-mode rows inside the reference.
    """
    bound = {int(entry): row.get("ScriptName") for entry, row in creature_templates.items()
             if row.get("ScriptName") in CPP_LOOT_MODE_RULES}
    if not bound:
        return {}
    root = Path(source_root)
    shared = _cpp_text(root / "src/server/shared/SharedDefines.h")
    default = re.search(r"\bLOOT_MODE_DEFAULT\s*=\s*(0x[0-9a-fA-F]+|\d+)\s*,", shared)
    if not default or int(default[1], 0) != 1:
        raise ValueError("Unsupported default creature loot mode")
    creature = _cpp_text(root / "src/server/game/Entities/Creature/Creature.h")
    for fragment in ("void ResetLootMode() { m_LootMode = LOOT_MODE_DEFAULT; }",
                     "void AddLootMode(uint16 lootMode) { m_LootMode |= lootMode; }",
                     "void SetLootMode(uint16 lootMode) { m_LootMode = lootMode; }"):
        _cpp_require(creature, fragment)
    masks = {}
    for name in set(bound.values()):
        text = _cpp_text(root / CPP_LOOT_MODE_RULES[name])
        _cpp_require(text, "RegisterUlduarCreatureAI(" + name + ");")
        expected = (1, 1, 0, 0) if name == "boss_flame_leviathan" else (0, 1, 1, 1)
        actual = tuple(len(re.findall(r"\bme\s*->\s*" + method + r"\s*\(", text))
                       for method in ("ResetLootMode", "AddLootMode", "SetLootMode", "RemoveLootMode"))
        if actual != expected:
            raise ValueError("Unsupported bound encounter loot-mode mutations: " + name)
        if name == "boss_flame_leviathan":
            header = _cpp_text(root / "src/server/scripts/Northrend/Ulduar/Ulduar/ulduar.h")
            first = _cpp_integer(header, "EVENT_TOWER_OF_LIFE_DESTROYED")
            last = _cpp_integer(header, "EVENT_TOWER_OF_FLAMES_DESTROYED")
            count = last - first + 1
            if count <= 0 or count > 8:
                raise ValueError("Unsupported Leviathan tower range")
            for fragment in ("struct boss_flame_leviathan : public BossAI",
                             "ActivateTowers();",
                             "void boss_flame_leviathan::ActivateTowers() { _towersCount = 0; me->ResetLootMode();",
                             "for (uint32 i = EVENT_TOWER_OF_LIFE_DESTROYED; i <= EVENT_TOWER_OF_FLAMES_DESTROYED; ++i) { if (instance->GetData(i)) { ++_towersCount; me->AddLootMode(1 << _towersCount);"):
                _cpp_require(text, fragment)
            masks[name] = [((1 << (active + 1)) - 1) for active in range(count + 1)]
        else:
            for fragment in ("struct boss_yoggsaron : public ScriptedAI",
                             "uint8 _count = 4; me->SetLootMode(31);",
                             "for (uint8 i = 0; i < 4; ++i) if (watchersMask & (1 << i)) { me->RemoveLootMode(1 << _count); --_count; }",
                             "if (spellInfo->Id == SPELL_IN_THE_MAWS_OF_THE_OLD_GOD) me->AddLootMode(32);"):
                _cpp_require(text, fragment)
            base = [((1 << (active + 1)) - 1) for active in range(5)]
            masks[name] = sorted(set(base) | {mode | 32 for mode in base})
    return {entry: masks[name] for entry, name in sorted(bound.items())}


def _validate_summon_core(source_root):
    requirements = {
        "src/server/game/Entities/GameObject/GameObject.h": (
            "enum LootState { GO_NOT_READY, GO_READY, GO_ACTIVATED, GO_JUST_DEACTIVATED };",),
        "src/server/game/Entities/GameObject/GameObject.cpp": ("AI()->OnStateChanged(state, unit);",),
        "src/server/game/Entities/Player/Player.cpp": ("go->SetLootState(GO_ACTIVATED, this);",),
        "src/server/game/AI/SmartScripts/SmartAI.cpp": (
            "GetScript()->ProcessEventsFor(SMART_EVENT_GO_STATE_CHANGED, unit, state);",),
        "src/server/game/AI/SmartScripts/SmartScript.cpp": (
            "WorldObject* summoner = preferUnit ? unit : Coalesce<WorldObject>(GetBaseObject(), unit);",
            "summoner->SummonCreature(e.action.summonCreature.creature, e.target.x, e.target.y, e.target.z, e.target.o, (TempSummonType)e.action.summonCreature.type, e.action.summonCreature.duration)",),
    }
    for relative, fragments in requirements.items():
        text = _cpp_text(Path(source_root) / relative)
        for fragment in fragments:
            _cpp_require(text, fragment)


def collect_summon_handoffs(source_root, item_templates, creature_templates, object_templates,
                            source_packets, *, scripts=(), conditions=()):
    """Map reviewed object interactions to their summoned item providers.

    C++ handoffs require an active reviewed handler and an independently proven
    NPC grant. SmartGO open handlers may also use a caller-tagged direct creature
    loot packet. Vendor/reward lists and unproven source packets are excluded.
    """
    items = {int(key) for key in item_templates}
    creatures = {int(key): row for key, row in creature_templates.items()}
    objects = {int(key): row for key, row in object_templates.items()}
    grants, loot = defaultdict(set), defaultdict(set)
    grant_rules = {"smartInvokerGrant", "cppPlayerGrant", "boundItemSpellScript", "itemUseTargetCondition",
                   "sourceBoundTriggeredItemCreation", "sourceBoundCasterAuraProvider", "sourceBoundChannelDeathItem"}
    for packet in source_packets:
        accepted = {(int(row["itemId"]), int(row["sourceId"])) for row in packet.get("evidence", ())
                    if row.get("field") == "npcDrops" and row.get("rule") in grant_rules}
        for key, fields in packet.get("sources", {}).items():
            item_id = int(key)
            if item_id not in items:
                continue
            for npc in fields.get("npcDrops", ()):
                if npc not in creatures:
                    continue
                if packet.get("sourceKind") == "creatureLoot":
                    loot[npc].add(item_id)
                elif (item_id, npc) in accepted:
                    grants[npc].add(item_id)
    sources, evidence = defaultdict(set), []

    def add(entry, npc, candidates, rule, **proof):
        for item_id in sorted(candidates):
            sources[item_id].add(entry)
            evidence.append({"itemId": item_id, "field": "objectDrops", "sourceId": entry,
                             "summonedNpcId": npc, "rule": rule, **proof})

    bound = {entry for entry, row in objects.items()
             if row.get("ScriptName") == "go_southfury_moonstone" and number(row, "type") == 10}
    if bound and grants:
        text = _cpp_text(Path(source_root) / "src/server/scripts/World/go_scripts.cpp")
        body = _cpp_class(text, "go_southfury_moonstone", "GameObjectScript")
        for fragment in (
            'go_southfury_moonstone() : GameObjectScript("go_southfury_moonstone") { }',
            "bool OnGossipHello(Player* player, GameObject* go) override",
            "creature->AI()->AttackStart(player);", "go->DespawnOrUnsummon(8000ms);",
        ):
            _cpp_require(body, fragment)
        _cpp_require(text, "new go_southfury_moonstone();")
        calls = re.findall(r"player\s*->\s*SummonCreature\s*\(\s*([A-Za-z_][A-Za-z_0-9]*|\d+)\s*,\s*0\.0f\s*,\s*0\.0f\s*,\s*0\.0f\s*,\s*0\.0f\s*,\s*TEMPSUMMON_DEAD_DESPAWN\s*,\s*0\s*\)", body)
        if len(calls) != 1 or len(re.findall(r"\bSummonCreature\s*\(", body)) != 1:
            raise ValueError("Unsupported Southfury summoned-provider handoff")
        npc = int(calls[0]) if calls[0].isdigit() else _cpp_integer(text, calls[0])
        if npc not in creatures:
            raise ValueError("Southfury summoned-provider template is missing")
        for entry in sorted(bound):
            add(entry, npc, grants[npc], "cppSummonedItemProvider", script="go_southfury_moonstone")

    groups = defaultdict(dict)
    for row in scripts:
        groups[(number(row, "source_type"), number(row, "entryorguid"))][number(row, "id")] = row
    conditional = {abs(number(row, "SourceEntry")) for row in conditions
                   if number(row, "SourceTypeOrReferenceId") == 22}
    active = {entry for entry, row in objects.items() if number(row, "type") in (1, 3, 10)
              and row.get("AIName") == "SmartGameObjectAI" and not row.get("ScriptName")
              and entry not in conditional and (number(row, "type") != 10 or number(row, "Data3") > 0)}
    roots = [(entry, row) for entry in active for row in groups[(1, entry)].values()
             if number(row, "event_type") == 70 and number(row, "event_param1") == 2
             and number(row, "event_phase_mask") == 0 and float(row.get("event_chance", 100)) > 0
             and number(row, "action_type") in (12, 80, 87, 88)]
    def usable(row):
        return number(row, "event_phase_mask") == 0 and float(row.get("event_chance", 100)) > 0

    def walk(entry, node, row, seen=frozenset()):
        identity = (*node, number(row, "id"))
        if identity in seen or not usable(row) or abs(node[1]) in conditional:
            return
        seen = seen | {identity}
        action, target = number(row, "action_type"), number(row, "target_type")
        if action == 12:
            npc = number(row, "action_param1")
            if npc not in creatures or number(row, "action_param2") <= 0:
                return
            if target == 8:
                try:
                    if not all(math.isfinite(float(row.get("target_" + axis, 0))) for axis in ("x", "y", "z", "o")):
                        return
                except (TypeError, ValueError):
                    return
            elif target != 1:
                return
            add(entry, npc, grants[npc] | loot[npc], "smartOpenSummonedItemProvider",
                sourceType=node[0], scriptEntry=node[1], scriptId=number(row, "id"))
        elif action in (80, 87, 88) and target == 1:
            if action == 80:
                children = [number(row, "action_param1")]
            elif action == 87:
                children = [number(row, "action_param" + str(i)) for i in range(1, 7)]
            else:
                first, last = number(row, "action_param1"), number(row, "action_param2")
                children = range(first, last + 1) if 0 < first <= last < first + 1000 else ()
            for child in children:
                for step in groups[(9, child)].values():
                    if number(step, "event_type") == 0:
                        walk(entry, (9, child), step, seen)
        else:
            return
        link = number(row, "link")
        linked = groups[node].get(link) if link else None
        if linked is not None and number(linked, "event_type") == 61:
            walk(entry, node, linked, seen)

    for entry, row in roots:
        walk(entry, (1, entry), row)
    if any(row["rule"] == "smartOpenSummonedItemProvider" for row in evidence):
        _validate_summon_core(source_root)
    return {"sources": {str(item_id): {"objectDrops": sorted(entries)} for item_id, entries in sorted(sources.items())},
            "evidence": evidence}


def collect_bound_spells(source_root, item_templates, creature_templates,
                         object_templates, spells, bindings):
    """Derive two reviewed item-use hooks from their active SQL bindings.

    The source enum values identify the granted item and required target. The
    bound effect layout, on-use item, player recipient and registered handler
    must agree; a matching script name alone does not establish an acquisition.
    """
    source_root = Path(source_root)
    templates = {int(key): row for key, row in item_templates.items()}
    npcs = {int(key): row for key, row in creature_templates.items()}
    objects = {int(key): row for key, row in object_templates.items()}
    spells = {int(key): row for key, row in spells.items()}
    used = defaultdict(set)
    for item, row in templates.items():
        for index in range(1, 6):
            spell = number(row, "spellid" + str(index))
            if spell > 0 and number(row, "spelltrigger" + str(index)) in (0, 5):
                used[spell].add(item)
    selected = defaultdict(set)
    for row in bindings:
        name, spell = row.get("ScriptName"), number(row, "spell_id")
        if name in BOUND_SPELL_RULES and spell > 0 and spell in used:
            selected[name].add(spell)
    if not selected:
        return {"sources": {}, "evidence": []}
    effects = _cpp_text(source_root / "src/server/shared/SharedDefines.h")
    auras = _cpp_text(source_root / "src/server/game/Spells/Auras/SpellAuraDefines.h")
    sources, evidence = defaultdict(lambda: defaultdict(set)), []
    for name, spell_ids in sorted(selected.items()):
        relative = BOUND_SPELL_RULES[name]
        script = _cpp_text(source_root / relative)
        base = "SpellScript" if name == "spell_q9452_cast_net" else "AuraScript"
        body = _cpp_class(script, name, base)
        _cpp_require(script, f"RegisterSpellScript({name});")
        if name == "spell_q9452_cast_net":
            _cpp_require(body, "PrepareSpellScript(spell_q9452_cast_net);")
            _cpp_require(body, "bool Load() override { return GetCaster()->IsPlayer(); }")
            _cpp_require(body, "GameObject* go = GetCaster()->FindNearestGameObject(GO_SCHOOL_OF_RED_SNAPPER, 3.0f);")
            _cpp_require(body, "if (!go || go->GetRespawnTime()) return SPELL_FAILED_REQUIRES_SPELL_FOCUS;")
            _cpp_require(body, "Player* caster = GetCaster()->ToPlayer(); if (roll_chance_i(66)) caster->AddItem(ITEM_RED_SNAPPER, 1);")
            _cpp_require(body, "OnCheckCast += SpellCheckCastFn(spell_q9452_cast_net::CheckCast);")
            _cpp_require(body, "OnEffectHit += SpellEffectFn(spell_q9452_cast_net::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);")
            _cpp_require(body, "OnEffectHitTarget += SpellEffectFn(spell_q9452_cast_net::HandleActiveObject, EFFECT_1, SPELL_EFFECT_ACTIVATE_OBJECT);")
            item = _cpp_integer(script, "ITEM_RED_SNAPPER")
            target = _cpp_integer(script, "GO_SCHOOL_OF_RED_SNAPPER")
            field, actors = "objectDrops", objects
        else:
            _cpp_require(body, "PrepareAuraScript(spell_catch_the_wild_wolpertinger);")
            _cpp_require(body, "if (Creature* wild = GetTarget()->ToCreature()) { if (wild->GetEntry() == NPC_WILD_WOLPERTINGER) { wild->ToCreature()->DespawnOrUnsummon(1s, 0s); GetCaster()->ToPlayer()->AddItem(ITEM_STUNNED_WOLPERTINGER, 1); } }")
            _cpp_require(body, "OnEffectApply += AuraEffectApplyFn(spell_catch_the_wild_wolpertinger::HandleEffectApply, EFFECT_0, SPELL_AURA_MOD_PACIFY_SILENCE, AURA_EFFECT_HANDLE_REAL);")
            item = _cpp_integer(script, "ITEM_STUNNED_WOLPERTINGER")
            target = _cpp_integer(script, "NPC_WILD_WOLPERTINGER")
            field, actors = "npcDrops", npcs
        if item not in templates or target not in actors:
            raise ValueError("Bound item-script item or target template is missing: " + name)
        for spell_id in sorted(spell_ids):
            spell = spells.get(spell_id)
            if spell is None:
                raise ValueError("Missing bound item-script spell data: " + str(spell_id))
            if name == "spell_q9452_cast_net":
                valid = (number(spell, "Effect1") == _cpp_integer(effects, "SPELL_EFFECT_DUMMY") and
                         number(spell, "Effect2") == _cpp_integer(effects, "SPELL_EFFECT_ACTIVATE_OBJECT"))
            else:
                valid = (number(spell, "Effect1") == _cpp_integer(effects, "SPELL_EFFECT_APPLY_AURA") and
                         number(spell, "EffectApplyAuraName1") == _cpp_integer(auras, "SPELL_AURA_MOD_PACIFY_SILENCE") and
                         bool({number(spell, "EffectImplicitTargetA1"), number(spell, "EffectImplicitTargetB1")} & {6, 21, 25}))
            if not valid:
                raise ValueError("Unsupported bound item-script effect layout: " + str(spell_id))
            sources[item][field].add(target)
            evidence.append({"itemId": item, "field": field, "sourceId": target,
                             "rule": "boundItemSpellScript", "script": name,
                             "sourceFile": relative, "spellId": spell_id,
                             "usedItemIds": sorted(used[spell_id])})
    return {"sources": {str(item): {field: sorted(values) for field, values in fields.items()}
                        for item, fields in sorted(sources.items())}, "evidence": evidence}


def collect_cpp(source_root, item_templates, creature_templates, object_templates, spells, spell_links=()):
    """Derive bounded, reviewed C++ grant paths with template and call guards."""
    spells = {int(k): v for k, v in spells.items()}
    items = set(map(int, item_templates))
    npcs = {int(k): v for k, v in creature_templates.items()}
    objects = {int(k): v for k, v in object_templates.items()}
    sources, evidence = defaultdict(lambda: defaultdict(set)), []
    for field, entry, script, relative, selectors in CPP_RULES:
        template = (npcs if field == "npcDrops" else objects).get(entry)
        if not template or template.get("ScriptName") != script:
            continue
        path = Path(source_root) / "src/server/scripts" / relative
        text = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(encoding="utf-8"), flags=re.S)
        match = re.search(r"\bclass\s+" + re.escape(script) + r"\s*:\s*public\s+\w+\s*\{", text)
        if not match:
            raise ValueError("Unsupported item-acquisition C++ class: " + script)
        start, depth = match.end(), 1
        for end in range(start, len(text)):
            depth += (text[end] == "{") - (text[end] == "}")
            if not depth:
                break
        else:
            raise ValueError("Unterminated item-acquisition C++ class: " + script)
        body = text[start:end]
        if not re.search(re.escape(script) + r'\s*\(\)\s*:\s*(?:CreatureScript|GameObjectScript)\s*\(\s*"' + re.escape(script) + r'"\s*\)', body):
            raise ValueError("Unsupported item-acquisition C++ registration: " + script)
        granted = []
        for selector in selectors:
            if isinstance(selector, int):
                spell_id = selector
            else:
                constant = re.search(r"\b" + re.escape(selector) + r"\s*=\s*(\d+)\s*(?=[,;}])", text)
                if not constant:
                    raise ValueError("Missing item-acquisition C++ spell: " + selector)
                spell_id = int(constant[1])
            token = re.escape(str(selector))
            call = (r"(?:player\s*->\s*CastSpell\s*\(\s*player\s*,\s*" + token +
                    r"\s*[,)]|DoCast\s*\(\s*player\s*,\s*" + token + r"\s*[,)]" + ")")
            if not re.search(call, body):
                raise ValueError("Unsupported item-acquisition C++ player cast: " + script)
            if spell_id not in spells:
                raise ValueError("Missing item-acquisition spell data: " + str(spell_id))
            granted.extend((item, spell_id) for item in _linked_player_items(spell_id, spells, spell_links, "self"))
        if script == "npc_aquementas":
            grants = re.findall(r"player\s*->\s*StoreNewItem\s*\(\s*dest\s*,\s*(\d+)\s*,\s*true\s*\)", body)
            if len(grants) != 1 or not re.search(r"player\s*->\s*CanStoreNewItem\s*\(\s*NULL_BAG\s*,\s*NULL_SLOT\s*,\s*dest\s*,\s*" + grants[0] + r"\s*,", body):
                raise ValueError("Unsupported Aquementas item delivery")
            granted.append((int(grants[0]), None))
        for item, spell_id in granted:
            if item in items:
                sources[item][field].add(entry)
                evidence.append({"itemId": item, "field": field, "sourceId": entry,
                                 "rule": "cppPlayerGrant", "script": script,
                                 "sourceFile": str(path), "spellId": spell_id})
    return {"sources": {str(item): {field: sorted(values) for field, values in fields.items()}
                        for item, fields in sorted(sources.items())}, "evidence": evidence}
