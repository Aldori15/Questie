"""Reviewed quest guidance for summons whose positions follow a player item.

The coordinates belong to the item-use area, never to permanent spirit spawns.
This deliberately bounded proof covers Fel Spirits; changed spell/script chains
require review instead of silently restoring coordinates from an older database.
"""
from collections import defaultdict
import math
from pathlib import Path
import re
import struct

from acore_scripted_geometry import typed
from acore_item_compatibility import number as _number


CORE_SOURCE_FILES = (
    "src/server/game/Spells/SpellInfo.cpp",
    "src/server/game/Spells/SpellEffects.cpp",
    "src/server/game/AI/SmartScripts/SmartScript.cpp",
    "src/server/game/Conditions/ConditionMgr.cpp",
    "src/server/game/Spells/Spell.cpp",
    "src/server/shared/DataStores/DBCStructure.h",
    "src/server/shared/SharedDefines.h",
)

CORE_REQUIREMENTS = {
    CORE_SOURCE_FILES[0]: (
        "AreaGroupEntry const* groupEntry = sAreaGroupStore.LookupEntry(AreaGroupId);",
        "if (groupEntry->AreaId[i] == zone_id || groupEntry->AreaId[i] == area_id) found = true;",
        "groupEntry = sAreaGroupStore.LookupEntry(groupEntry->nextGroup);",
        "if (!found) return SPELL_FAILED_INCORRECT_AREA;",
    ),
    CORE_SOURCE_FILES[1]: (
        "void Spell::EffectSummonType(SpellEffIndex effIndex)",
        "uint32 entry = m_spellInfo->Effects[effIndex].MiscValue;",
        "SummonCreature(entry, *destTarget, properties, duration, unitCaster, m_spellInfo->Id, 0, personalSpawn)",
    ),
    CORE_SOURCE_FILES[4]: (
        "void Spell::SelectImplicitNearbyTargets(SpellEffIndex effIndex, SpellImplicitTargetInfo const& targetType, uint32 effMask)",
        "SpellDestination dest(*target); CallScriptDestinationTargetSelectHandlers(dest, effIndex, targetType); m_targets.SetDst(dest);",
    ),
    CORE_SOURCE_FILES[5]: ("#define MAX_GROUP_AREA_IDS 6", "uint32 AreaId[MAX_GROUP_AREA_IDS];", "uint32 nextGroup;"),
    CORE_SOURCE_FILES[6]: ("TARGET_DEST_NEARBY_ENTRY = 46", "TARGET_DEST_CASTER_FRONT = 47", "TARGET_UNIT_SRC_AREA_ENTRY = 7"),
}


def _compact(text):
    return re.sub(r"\s+", "", re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S))


def validate_source(source_root):
    """Changed area restrictions or summon destinations need an explicit review."""
    for relative, fragments in CORE_REQUIREMENTS.items():
        source = _compact((Path(source_root) / relative).read_text(encoding="utf-8"))
        if any(_compact(fragment) not in source for fragment in fragments):
            raise ValueError("Quest10909 relic guide requires source review: unsupported core semantics in " + relative)


def load_area_groups(dbc_path):
    """Read the WotLK ID/six-area/next-group layout, including chained groups."""
    data = Path(dbc_path).read_bytes()
    if len(data) < 20 or data[:4] != b"WDBC":
        raise ValueError("Invalid AreaGroup.dbc header")
    count, fields, size, strings = struct.unpack_from("<4I", data, 4)
    if count == 0 or fields != 8 or size != 32 or strings < 1 or len(data) != 20 + count * size + strings:
        raise ValueError("Invalid or truncated AreaGroup.dbc layout")
    rows = {}
    for offset in range(20, 20 + count * size, size):
        row = struct.unpack_from("<8I", data, offset)
        if row[0] in rows:
            raise ValueError("Duplicate AreaGroup.dbc group ID")
        rows[row[0]] = row
    result = {}
    for identity in rows:
        areas, visiting, current = set(), set(), identity
        while True:
            if current in visiting:
                raise ValueError("Cyclic AreaGroup.dbc next-group chain")
            if current not in rows:
                raise ValueError("Missing AreaGroup.dbc next-group record")
            visiting.add(current)
            row = rows[current]
            areas.update(value for value in row[1:7] if value > 0)
            current = row[7]
            if not current:
                break
        result[identity] = sorted(areas)
    return result


def _rows(values):
    return list(values.values()) if isinstance(values, dict) else list(values or ())


def _templates(values, key):
    if isinstance(values, dict):
        return {int(identity): row for identity, row in values.items()}
    return {_number(row, key): row for row in values or ()}


def _require(valid, reason):
    if not valid:
        raise ValueError("Quest10909 relic guide requires source review: " + reason)


def _effect(spell, effect, entry, target):
    return any(_number(spell, "Effect" + str(i)) == effect
               and _number(spell, "EffectMiscValue" + str(i)) == entry
               and _number(spell, "EffectImplicitTargetA" + str(i)) == target
               and _number(spell, "EffectImplicitTargetB" + str(i)) == 0
               for i in (1, 2, 3))


def _entry_condition(conditions, spell, entry):
    rows = [row for row in conditions if _number(row, "SourceTypeOrReferenceId") in (13, 17)
            and _number(row, "SourceEntry") == spell]
    return len(rows) == 1 and all(
        _number(row, "SourceTypeOrReferenceId") == 13
        and _number(row, "SourceGroup") == 1
        and _number(row, "ConditionTypeOrReference") == 31
        and _number(row, "ConditionValue1") == 3
        and _number(row, "ConditionValue2") == entry
        and not any(_number(row, field) for field in
                    ("SourceId", "ElseGroup", "ConditionTarget", "ConditionValue3", "NegativeCondition"))
        and not row.get("ScriptName") for row in rows)


def _action(scripts, owner, event, action, first, phase=0, **fields):
    return any(_number(row, "source_type") == 0 and _number(row, "entryorguid") == owner
               and _number(row, "event_type") == event and _number(row, "action_type") == action
               and _number(row, "action_param1") == first
               and _number(row, "event_phase_mask") == phase and _number(row, "target_type") == 1
               and float(row.get("event_chance", 100)) > 0
               and all(_number(row, key) == value for key, value in fields.items())
               for row in scripts)


def derive(quests, items, spells, scripts, conditions, creature_spawns, area_groups, project_point):
    """Return an area-filtered extra objective associated with the real kill slot.

    ``area_groups`` contains AreaGroup.dbc memberships. ``creature_spawns`` must
    retain the server-calculated areaId, phaseMask and current XYZ from an export.
    ``project_point(spawn, quest)`` returns a Questie zone and percent coordinates.
    """
    packet = {"guides": {}, "evidence": [], "omissions": []}
    quests = _templates(quests, "ID")
    if 10909 not in quests:
        return packet
    quest = quests[10909]
    items, spells = _templates(items, "entry"), _templates(spells, "ID")
    scripts, conditions = _rows(scripts), _rows(conditions)
    item, use, summon = items.get(31772, {}), spells.get(39183, {}), spells.get(39206, {})
    aura = spells.get(39184, {})
    _require(_number(quest, "StartItem") == 31772
             and _number(quest, "RequiredNpcOrGo1") == 22454
             and _number(quest, "RequiredNpcOrGoCount1") > 0,
             "quest source item or first kill objective changed")
    _require(not item.get("ScriptName") and any(
        _number(item, "spellid" + str(i)) == 39183
        and _number(item, "spelltrigger" + str(i)) in (0, 5) for i in range(1, 6)),
        "Anchorite Relic no longer uses the reviewed spell")
    _require(_effect(use, 28, 22444, 47) and _effect(use, 76, 185298, 47),
             "relic spell no longer creates the relic and bunny at the caster")
    _require(_effect(summon, 28, 22454, 46)
             and _entry_condition(conditions, 39206, 22444)
             and _entry_condition(conditions, 39184, 16878),
             "spirit summon destination or Berserker aura targets changed")
    _require(_number(aura, "Effect1") == 6 and _number(aura, "EffectApplyAuraName1") == 4
             and _number(aura, "EffectImplicitTargetA1") == 22
             and _number(aura, "EffectImplicitTargetB1") == 7,
             "relic aura no longer affects nearby Berserkers")
    _require(_action(scripts, 16878, 8, 22, 1, event_param1=39184)
             and _action(scripts, 16878, 6, 11, 39206, phase=1, action_param2=2)
             and _action(scripts, 22444, 60, 11, 39184, action_param2=2),
             "relic aura, Berserker phase or death-cast relationship changed")
    group = _number(use, "AreaGroupId")
    areas = {int(value) for value in (area_groups or {}).get(group, ()) if int(value) > 0}
    _require(group > 0 and bool(areas), "missing relic spell AreaGroup.dbc membership")
    _require(creature_spawns is not None, "missing creature export with calculated areaId")
    points, guids = defaultdict(list), []
    for spawn in _rows(creature_spawns):
        entries = {_number(spawn, key) for key in ("id1", "id2", "id3", "id", "entry")}
        if 16878 not in entries or not ({_number(spawn, "areaId"), _number(spawn, "zoneId")} & areas):
            continue
        if _number(spawn, "phaseMask") != 1 or spawn.get("ScriptName"):
            packet["omissions"].append({"questId": 10909, "guid": _number(spawn, "guid"),
                                         "reason": "nonordinaryOrCustomBerserkerPlacement"})
            continue
        zone, point = project_point(spawn, quest)
        _require(type(zone) is int and zone > 0 and isinstance(point, (list, tuple))
                 and len(point) >= 2 and all(type(value) in (int, float) and math.isfinite(value)
                                            and 0 <= value <= 100 for value in point[:2]),
                 "unmappable Berserker placement in the relic use area")
        if list(point[:2]) not in points[zone]:
            points[zone].append(list(point[:2]))
        guids.append(_number(spawn, "guid"))
    _require(bool(points), "no ordinary Berserker placements inside the relic use area")
    label = "Place the Anchorite Relic near Shattered Hand Berserkers, then defeat released Fel Spirits"
    coordinates = {zone: sorted(values) for zone, values in sorted(points.items())}
    packet["guides"][10909] = typed([{1: coordinates, 2: 3, 3: label, 4: 1}])
    packet["evidence"].append({"questId": 10909, "rule": "areaBoundRelicSpiritSummon",
                                "itemId": 31772, "itemSpellId": 39183, "areaGroupId": group,
                                "areaIds": sorted(areas), "sourceNpcId": 16878,
                                "objectiveNpcId": 22454, "summonSpellId": 39206,
                                "sourceGuids": sorted(set(guids)), "realObjectiveIndex": 1})
    return packet
