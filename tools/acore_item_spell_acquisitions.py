"""Bounded item acquisitions through triggered spells and quest-use auras."""
from collections import defaultdict
from pathlib import Path
import re

from acore_item_compatibility import number
from acore_quest_compatibility import _source_context


CORE_SOURCE_FILES = (
    "src/server/game/Spells/SpellEffects.cpp",
    "src/server/game/Spells/SpellInfo.cpp",
    "src/server/game/Spells/Auras/SpellAuraEffects.cpp",
    "src/server/game/Spells/Auras/SpellAuraDefines.h",
    "src/server/shared/SharedDefines.h",
)


def _code(text):
    return re.sub(r"\s+", "", re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S))


def validate_source(source_root):
    requirements = {
        CORE_SOURCE_FILES[0]: (
            "Player* player = unitTarget->ToPlayer(); if (!player) { return; }",
            "m_caster->CastSpell(std::move(targets), spellInfo->Id, args);",
        ),
        CORE_SOURCE_FILES[1]: (
            "if (NeedsExplicitUnitTarget()) return true;",
            "return (AttributesEx & (SPELL_ATTR1_IS_CHANNELED | SPELL_ATTR1_IS_SELF_CHANNELED));",
            "if (triggeringSpell->IsChanneled())",
            "if (mask & TARGET_FLAG_UNIT_MASK) return true;",
        ),
        CORE_SOURCE_FILES[2]: (
            "if (apply || aurApp->GetRemoveMode() != AURA_REMOVE_BY_DEATH) return;",
            "if (!caster || !caster->IsPlayer()) return;",
            "if (GetAmount() <= 0) return;",
            "plCaster->StoreNewItem(dest, GetSpellInfo()->Effects[m_effIndex].ItemType, true);",
            "Unit* triggerCaster = triggeredSpellInfo->NeedsToBeTriggeredByCaster(m_spellInfo, GetEffIndex()) ? caster : target",
            "triggerCaster->CastSpell(targets, triggeredSpellInfo, nullptr, triggerFlags, nullptr, this);",
        ),
        CORE_SOURCE_FILES[3]: ("SPELL_AURA_CHANNEL_DEATH_ITEM = 86,",),
        CORE_SOURCE_FILES[4]: (
            "SPELL_ATTR1_IS_CHANNELED = 0x00000004,",
            "SPELL_ATTR1_IS_SELF_CHANNELED = 0x00000040,",
            "TARGET_UNIT_CASTER = 1,", "TARGET_UNIT_CHANNEL_TARGET = 77,",
        ),
    }
    for relative, fragments in requirements.items():
        text = _code((Path(source_root) / relative).read_text(encoding="utf-8"))
        if any(_code(fragment) not in text for fragment in fragments):
            raise ValueError("Unsupported triggered-item source semantics in " + relative)


def _rows(values):
    return list(values.values()) if isinstance(values, dict) else list(values)


def _templates(values, key="entry"):
    if isinstance(values, dict):
        return {int(identity): row for identity, row in values.items()}
    return {number(row, key): row for row in values}


def _targets(row, slot):
    return {number(row, "EffectImplicitTarget" + side + str(slot)) for side in ("A", "B")} - {0}


def collect(item_templates, creature_templates, object_templates, scripts, spells, conditions, *, source_root=None):
    """Map proven item-use targets/providers without guessing NPC recipients.

    Trigger-spell effects keep their caster. Periodic triggers retain that caster
    only for a self aura or a supported NeedsToBeTriggeredByCaster case. A
    CREATE_ITEM effect directed only at the NPC never proves a player grant.
    Positive entry conditions are intersected through the chain; missing bounds
    do not expand into every creature that could hypothetically be targeted.
    """
    items = _templates(item_templates)
    used_spells = {number(row, "spellid" + str(slot)) for row in items.values() for slot in range(1, 6)
                   if not row.get("ScriptName") and number(row, "spellid" + str(slot)) > 0
                   and number(row, "spelltrigger" + str(slot)) in (0, 5)}
    if not used_spells:
        return {"sources": {}, "evidence": [], "omissions": []}
    if source_root is not None:
        validate_source(source_root)
    creatures = _templates(creature_templates)
    objects = _templates(object_templates)
    spell_rows = _templates(spells, "ID")
    condition_rows = _rows(conditions)
    by_spell = defaultdict(list)
    for row in condition_rows:
        if number(row, "SourceTypeOrReferenceId") in (13, 17):
            by_spell[number(row, "SourceEntry")].append(row)
    sources, evidence, omissions = defaultdict(lambda: defaultdict(set)), [], []

    def bounds(spell_id, slot=None):
        result = set()
        for row in by_spell[spell_id]:
            source = number(row, "SourceTypeOrReferenceId")
            if number(row, "ConditionTypeOrReference") < 0 or row.get("ScriptName"):
                return None
            if (number(row, "ConditionTypeOrReference") != 31 or number(row, "NegativeCondition")
                    or number(row, "SourceId") or number(row, "ConditionValue3")):
                continue
            if source == 17:
                if number(row, "SourceGroup") or number(row, "ConditionTarget") != 1:
                    continue
            else:
                mask = number(row, "SourceGroup")
                if number(row, "ConditionTarget") or not 0 < mask <= 7:
                    continue
                active = (1 << (slot - 1)) if slot is not None else sum(
                    1 << (i - 1) for i in (1, 2, 3) if number(spell_rows.get(spell_id, {}), "Effect" + str(i)))
                if not mask & active:
                    continue
            kind, entry = number(row, "ConditionValue1"), number(row, "ConditionValue2")
            if kind == 3 and entry in creatures:
                result.add(("npcDrops", entry))
            elif kind == 5 and entry in objects:
                result.add(("objectDrops", entry))
        return result

    def merge(first, second):
        return first & second if first and second else first or second

    def emit(item_id, actors, root, path, rule):
        if item_id not in items:
            return
        for field, actor in sorted(actors):
            sources[item_id][field].add(actor)
            evidence.append({"itemId": item_id, "field": field, "sourceId": actor,
                             "rootSpellId": root, "spellPath": list(path), "rule": rule})

    def walk(spell_id, root, actors, player_caster=True, explicit_player=False, path=()):
        if spell_id in path or len(path) >= 12:
            omissions.append({"rootSpellId": root, "spellId": spell_id, "reason": "cyclicOrDeepTriggerChain"})
            return
        row = spell_rows.get(spell_id)
        if row is None:
            return
        path = path + (spell_id,)
        for slot in (1, 2, 3):
            effect = number(row, "Effect" + str(slot))
            selected = _targets(row, slot)
            restricted = bounds(spell_id, slot)
            if restricted is None:
                continue
            actors_here = merge(actors, restricted)
            if actors and restricted and not actors_here:
                continue
            if effect in (24, 157):
                if (1 in selected and player_caster) or (selected & {6, 21, 25, 77} and explicit_player):
                    emit(number(row, "EffectItemType" + str(slot)), actors_here, root, path,
                         "sourceBoundTriggeredItemCreation")
            elif effect == 6 and number(row, "EffectApplyAuraName" + str(slot)) == 86:
                # Death removes the aura from the NPC; its player caster gets
                # ItemType only when the calculated amount is positive.
                if (player_caster and selected & {6, 21, 25, 38}
                        and number(row, "EffectDieSides" + str(slot)) >= 1
                        and number(row, "EffectBasePoints" + str(slot)) >= 0):
                    actor_npcs = {actor for actor in actors_here if actor[0] == "npcDrops"}
                    if actor_npcs:
                        emit(number(row, "EffectItemType" + str(slot)), actor_npcs, root, path,
                             "sourceBoundChannelDeathItem")
                    elif number(row, "EffectItemType" + str(slot)) in items:
                        omissions.append({"rootSpellId": root, "itemId": number(row, "EffectItemType" + str(slot)),
                                          "reason": "channelDeathItemHasNoSpecificActorBinding"})
            child = number(row, "EffectTriggerSpell" + str(slot))
            if child <= 0 or child not in spell_rows:
                continue
            target_player = player_caster if 1 in selected else explicit_player if selected & {6, 21, 25, 77} else False
            if effect == 64:
                walk(child, root, actors_here, player_caster, target_player, path)
            elif effect == 6 and number(row, "EffectApplyAuraName" + str(slot)) == 23:
                child_row = spell_rows[child]
                child_targets = set().union(*(_targets(child_row, i) for i in (1, 2, 3)
                                             if number(child_row, "Effect" + str(i))))
                original = (bool(child_targets & {6, 21, 25}) or
                            38 in selected and 38 in child_targets or
                            bool(number(row, "AttributesEx") & 0x44 and child_targets & {6, 21, 25, 38, 77}))
                child_player = player_caster if original else target_player
                if child_player:
                    walk(child, root, actors_here, child_player, target_player, path)
                elif actors_here:
                    omissions.append({"rootSpellId": root, "spellId": child,
                                      "reason": "periodicCasterIsNotProvenPlayer"})

    aura_providers = defaultdict(set)
    for actor, actions in _source_context(creatures, objects, _rows(scripts)):
        if actor[0] != "monster":
            continue
        for row in actions:
            target = number(row, "target_type")
            combat_victim = target == 2 and number(row, "event_type") == 0
            player_selector = target in (16, 17, 18, 21, 201)
            if (number(row, "action_type") != 11 or not (combat_victim or player_selector)
                    or number(row, "event_phase_mask") or float(row.get("event_chance", 100)) <= 0):
                continue
            spell_id = number(row, "action_param1")
            spell = spell_rows.get(spell_id, {})
            for slot in (1, 2, 3):
                if (number(spell, "Effect" + str(slot)) == 6 and
                        number(spell, "EffectApplyAuraName" + str(slot)) > 0 and
                        _targets(spell, slot) & {6, 21, 25}):
                    aura_providers[(spell_id, slot - 1)].add(("npcDrops", actor[1]))

    for root in sorted(used_spells):
        actors = bounds(root)
        if actors is None:
            continue
        walk(root, root, actors)
        root_row = spell_rows.get(root, {})
        for condition in by_spell[root]:
            if (number(condition, "SourceTypeOrReferenceId") != 17 or number(condition, "SourceGroup")
                    or number(condition, "SourceId") or number(condition, "ElseGroup")
                    or number(condition, "ConditionTypeOrReference") != 1
                    or number(condition, "ConditionTarget") or number(condition, "NegativeCondition")
                    or condition.get("ScriptName")):
                continue
            providers = aura_providers[(number(condition, "ConditionValue1"), number(condition, "ConditionValue2"))]
            for slot in (1, 2, 3):
                if number(root_row, "Effect" + str(slot)) in (24, 157) and 1 in _targets(root_row, slot):
                    emit(number(root_row, "EffectItemType" + str(slot)), providers, root, (root,),
                         "sourceBoundCasterAuraProvider")
    return {"sources": {str(key): {field: sorted(actors) for field, actors in sorted(fields.items())}
                        for key, fields in sorted(sources.items())},
            "evidence": evidence, "omissions": omissions}
