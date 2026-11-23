"""Source-reviewed guides for classic objectives carried by temporary actors.

Helpers reference the static interaction targets. They never turn a summoned or
transformed creature into a permanent spawn or replace its actual quest credit.
"""
from pathlib import Path
import hashlib
import re

from acore_item_compatibility import number
from acore_scripted_geometry import typed


CORE_SOURCE_FILES = (
    "src/server/scripts/Spells/spell_generic.cpp",
    "src/server/scripts/Kalimdor/zone_desolace.cpp",
    "src/server/scripts/Spells/spell_quest.cpp",
    "src/server/scripts/World/go_scripts.cpp",
)
CPP_REVIEWS = {
    "bramble": (CORE_SOURCE_FILES[0],
                r"\benum YehkinyaBramble\b.*?^\};\s*class spell_gen_yehkinya_bramble\b.*?^\};",
                "6ef758d40c825af730c043250e947d2248e47a4cc62a6b71b292b139199b78c5"),
    "kodo": (CORE_SOURCE_FILES[1],
             r"\benum DyingKodo\b.*?^\};\s*struct npc_aged_dying_ancient_kodo\b.*?^\};",
             "a7f3a912cd33fd413a1dcd93403c0af6579c7f612072253a4dac27224695381a"),
    "kodo_spell": (CORE_SOURCE_FILES[2], r"std::vector<uint32> kodoEntry\s*\{.*?^\};",
                   "cc0c47a834f5bba1eaf0ac39656a3dfdef741ee5629073831b680eaf5b24be62"),
    "cask": (CORE_SOURCE_FILES[3],
             r"\benum ResoniteCask\b.*?^\};\s*class go_resonite_cask\b.*?^\};",
             "bee961e08f80ac80c5a8adfe31e79940a067130f8694590aaffa9dddeb46927d"),
}


def _rows(values):
    return list(values.values()) if isinstance(values, dict) else list(values or ())


def _templates(values, key):
    return {int(identity): row for identity, row in values.items()} if isinstance(values, dict) else {
        number(row, key): row for row in values or ()}


def _require(valid, quest, reason):
    if not valid:
        raise ValueError(f"Quest{quest} classic guide requires source review: {reason}")


def _review_cpp(source_root, rule, quest):
    """Fingerprint complete reviewed classes and their numeric bindings."""
    _require(source_root is not None, quest, "missing AzerothCore C++ source")
    from acore_cpp_geometry import _clean
    relative, pattern, expected = CPP_REVIEWS[rule]
    text = _clean((Path(source_root) / relative).read_text(encoding="utf-8"))
    match = re.search(pattern, text, re.S | re.M)
    actual = hashlib.sha256(re.sub(r"\s+", "", match[0]).encode()).hexdigest() if match else None
    _require(actual == expected, quest, f"changed {rule} C++ ownership, target or credit behavior")


def _objective(quest, identity, target):
    _require(number(quest, "RequiredNpcOrGo1") == target
             and number(quest, "RequiredNpcOrGoCount1") > 0,
             identity, "first objective no longer uses the reviewed creature")


def _item_spell(items, quest, identity, item_id, spell_id):
    item = items.get(item_id, {})
    _require(number(quest, "StartItem") == item_id and not item.get("ScriptName")
             and any(number(item, f"spellid{i}") == spell_id
                     and number(item, f"spelltrigger{i}") in (0, 5) for i in range(1, 6)),
             identity, "quest item no longer uses the reviewed spell")


def _binding(spell_scripts, identity, spell, script):
    actual = {row.get("ScriptName") for row in spell_scripts if number(row, "spell_id") == spell}
    _require(actual == {script}, identity, "spell script registration changed")


def _effect(spell, effect, entry=None, first=None, second=None):
    return any(number(spell, f"Effect{i}") == effect
               and (entry is None or number(spell, f"EffectMiscValue{i}") == entry)
               and (first is None or number(spell, f"EffectImplicitTargetA{i}") == first)
               and (second is None or number(spell, f"EffectImplicitTargetB{i}") == second)
               for i in range(1, 4))


def _helper(label, kind, identities):
    return {2: 3, 3: label, 4: 1, 5: [[kind, identity] for identity in identities]}


def derive(quests, items, spells, scripts, conditions, creature_templates, object_templates,
           spell_scripts, *, source_root=None):
    quests = _templates(quests, "ID")
    items, spells = _templates(items, "entry"), _templates(spells, "ID")
    creatures, objects = _templates(creature_templates, "entry"), _templates(object_templates, "entry")
    scripts, conditions, spell_scripts = _rows(scripts), _rows(conditions), _rows(spell_scripts)
    packet = {"guides": {}, "evidence": [], "omissions": []}

    for identity in (3520, 5561):
        if identity in quests:
            spell = 12699 if identity == 3520 else 18153
            _require(not any(number(row, "SourceTypeOrReferenceId") in (13, 17)
                             and number(row, "SourceEntry") == spell for row in conditions),
                     identity, "new spell conditions require a target-location review")

    if 3520 in quests:
        quest = quests[3520]
        _objective(quest, 3520, 8612)
        _item_spell(items, quest, 3520, 10699, 12699)
        _binding(spell_scripts, 3520, 12699, "spell_gen_yehkinya_bramble")
        _review_cpp(source_root, "bramble", 3520)
        _require(_effect(spells.get(12699, {}), 28, 8612, 6, 46),
                 3520, "bramble spell no longer summons the reviewed spirit")
        actor = creatures.get(8612, {})
        _require(actor.get("AIName") == "SmartAI" and not actor.get("ScriptName")
                 and all(target in creatures for target in (5307, 5308))
                 and any(number(row, "source_type") == 0 and number(row, "entryorguid") == 8612
                         and number(row, "event_type") == 64 and number(row, "event_phase_mask") == 0
                         and number(row, "action_type") == 33 and number(row, "action_param1") == 8612
                         and number(row, "target_type") == 7 and float(row.get("event_chance", 100)) > 0
                         for row in scripts), 3520, "spirit gossip credit or screecher templates changed")
        packet["guides"][3520] = typed([_helper(
            "Use Yeh'kinya's Bramble on dead Vale Screechers, then speak with their spirits",
            "monster", [5307, 5308])])
        packet["evidence"].append({"questId": 3520, "rule": "scriptBoundCorpseSpiritGuide",
                                   "itemId": 10699, "spellId": 12699, "creditNpcId": 8612,
                                   "targetNpcIds": [5307, 5308], "realObjectiveIndex": 1})

    if 5561 in quests:
        quest = quests[5561]
        _objective(quest, 5561, 11627)
        _item_spell(items, quest, 5561, 13892, 18153)
        _binding(spell_scripts, 5561, 18153, "spell_q5561_kodo_roundup_kodo_kombobulator")
        _review_cpp(source_root, "kodo", 5561)
        _review_cpp(source_root, "kodo_spell", 5561)
        _require(_effect(spells.get(18153, {}), 3, first=6)
                 and 11596 in creatures
                 and all(creatures.get(target, {}).get("ScriptName") == "npc_aged_dying_ancient_kodo"
                         for target in (4700, 4701, 4702, 11627)),
                 5561, "kodo spell, NPC bindings or Smeed delivery target changed")
        packet["guides"][5561] = typed([
            _helper("Use the Kodo Kombobulator on an Aged, Dying or Ancient Kodo", "monster", [4700, 4701, 4702]),
            _helper("Lead each tamed kodo to Smeed Scrabblescrew, then speak with the kodo", "monster", [11596]),
        ])
        packet["evidence"].append({"questId": 5561, "rule": "scriptBoundKodoCaptureAndDelivery",
                                   "itemId": 13892, "spellId": 18153, "creditNpcId": 11627,
                                   "targetNpcIds": [4700, 4701, 4702], "deliveryNpcId": 11596,
                                   "realObjectiveIndex": 1})

    if 6481 in quests:
        _objective(quests[6481], 6481, 11920)
        _review_cpp(source_root, "cask", 6481)
        cask = objects.get(178145, {})
        _require(number(cask, "type") == 10 and cask.get("ScriptName") == "go_resonite_cask"
                 and 11920 in creatures, 6481, "Resonite Cask or summoned Goggeroc binding changed")
        packet["guides"][6481] = typed([
            _helper("Open the Resonite Cask to summon Goggeroc", "object", [178145]),
        ])
        packet["evidence"].append({"questId": 6481, "rule": "scriptBoundCaskSummon",
                                   "objectId": 178145, "creditNpcId": 11920, "realObjectiveIndex": 1})
    return packet
