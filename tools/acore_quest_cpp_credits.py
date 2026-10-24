"""Source-bound C++ quest credits emitted by registered NPC/object actors.

Only direct Player pointers and literal or unambiguous numeric enum credits are
accepted. This establishes actor relationships, never coordinates or quest state.
"""
from collections import defaultdict
from pathlib import Path
import re

import acore_quest_cpp_events as cpp


CORE_SOURCE_FILES = (
    "src/server/game/Entities/Player/Player.h",
    "src/server/game/Entities/Player/PlayerQuest.cpp",
    "src/server/game/Entities/Player/Player.cpp",
)

CORE_REQUIREMENTS = {
    CORE_SOURCE_FILES[0]: (
        "void KilledMonsterCredit(uint32 entry, ObjectGuid guid = ObjectGuid::Empty);",
        "void RewardPlayerAndGroupAtEvent(uint32 creature_id, WorldObject* pRewardSource);",
    ),
    CORE_SOURCE_FILES[1]: (
        "void Player::KilledMonsterCredit(uint32 entry, ObjectGuid guid)",
        "uint32 real_entry = entry;",
        "if (guid) { Creature* killed = GetMap()->GetCreature(guid); "
        "if (killed && killed->GetEntry()) real_entry = killed->GetEntry(); }",
        "uint32 reqkill = qInfo->RequiredNpcOrGo[j];",
        "if (reqkill == real_entry)",
        "q_status.CreatureOrGOCount[j] = curkillcount + addkillcount;",
    ),
    CORE_SOURCE_FILES[2]: (
        "void Player::RewardPlayerAndGroupAtEvent(uint32 creature_id, WorldObject* pRewardSource)",
        "if (!pRewardSource) return;",
        "ObjectGuid creature_guid;",
        "if (pRewardSource->IsCreature() && pRewardSource->GetEntry() == creature_id) "
        "creature_guid = pRewardSource->GetGUID();",
        "player->KilledMonsterCredit(creature_id, creature_guid);",
        "else KilledMonsterCredit(creature_id, creature_guid);",
    ),
}


def _compact(text):
    return re.sub(r"\s+", "", cpp._mask(text, strings=False))


def validate_source(source_root):
    for relative, fragments in CORE_REQUIREMENTS.items():
        source = _compact((Path(source_root) / relative).read_text(encoding="utf-8"))
        if any(_compact(fragment) not in source for fragment in fragments):
            raise ValueError("Unsupported C++ quest credit semantics in " + relative)


def _owners(masked, comments_removed, classes, bindings):
    by_name = defaultdict(list)
    for row in classes:
        by_name[row["name"]].append(row)
    result = defaultdict(set)
    for row in classes:
        if len(by_name[row["name"]]) != 1:
            continue
        registrations = []
        for base, kind in (("CreatureScript", "monster"), ("GameObjectScript", "object")):
            if not re.search(r"\b" + base + r"\b", row["declaration"]):
                continue
            body = comments_removed[row["open"] + 1:row["end"]]
            pattern = (r"\b" + re.escape(row["name"]) + r"\s*\([^;{}]*\)\s*:\s*"
                       + base + r'\s*\(\s*"([^"\\]+)"\s*\)')
            registrations.extend((match[1], kind) for match in re.finditer(pattern, body))
        for macro, kind in (("RegisterCreatureAI", "monster"), ("RegisterGameObjectAI", "object")):
            if re.search(r"\b" + macro + r"\s*\(\s*" + re.escape(row["name"]) + r"\s*\)", masked):
                registrations.append((row["name"], kind))
        owned = [row]
        for name in cpp._factory_ais(masked, row):
            if len(by_name[name]) == 1:
                owned.append(by_name[name][0])
        for script, kind in registrations:
            for actor in bindings.get(script, ()):
                if actor[0] == kind:
                    for owner in owned:
                        result[owner["start"]].add((actor, script))
    return result


def collect(source_root, creature_templates, object_templates):
    """Return credit-to-actor mappings proven by active script bindings.

    A nonempty GUID can replace the supplied entry inside KilledMonsterCredit.
    Such calls need separate GUID provenance and are deliberately not inferred.
    RewardPlayerAndGroupAtEvent preserves the entry; its reward source must be
    the bound actor or the same proven Player receiver, not an unrelated object.
    """
    root = Path(source_root)
    bindings = cpp._template_bindings(creature_templates, "monster")
    for script, actors in cpp._template_bindings(object_templates, "object").items():
        bindings[script].update(actors)
    if not bindings:
        return {"credits": {}, "evidence": {}, "unsupported": []}
    validate_source(root)
    credits, evidence, unsupported = defaultdict(set), defaultdict(list), []
    for path in cpp.source_files(root):
        text = path.read_text(encoding="utf-8")
        if not any(name in text for name in ("KilledMonsterCredit", "RewardPlayerAndGroupAtEvent")):
            continue
        masked, comments_removed = cpp._mask(text), cpp._mask(text, strings=False)
        relative = path.relative_to(root).as_posix()
        try:
            classes = cpp._classes(masked)
            constants = cpp._constants(masked, classes)
            owners = _owners(masked, comments_removed, classes, bindings)
        except ValueError as error:
            unsupported.append({"file": relative, "reason": str(error)})
            continue
        for call in re.finditer(r"\b(KilledMonsterCredit|RewardPlayerAndGroupAtEvent)\s*\(", masked):
            parents = [row for row in classes if row["open"] < call.start() < row["end"]]
            if not parents:
                continue
            owner = min(parents, key=lambda row: row["end"] - row["open"])
            actual_owners = owners.get(owner["start"], ())
            if not actual_owners:
                continue
            try:
                end = cpp._close(masked, call.end() - 1, "(", ")")
            except ValueError:
                continue
            arguments = masked[call.end():end].split(",")
            credit = cpp._quest_id(arguments[0], constants, masked[owner["open"] + 1:owner["end"]])
            recipient = cpp._player_receiver(masked, owner, call.start())
            if call[1] == "KilledMonsterCredit":
                valid_delivery = (len(arguments) == 1 or len(arguments) == 2 and
                                  re.sub(r"\s+", "", arguments[1]) == "ObjectGuid::Empty")
            else:
                valid_delivery = len(arguments) == 2 and arguments[1].strip() in ("me", "m_creature", recipient)
            line = text.count("\n", 0, call.start()) + 1
            if credit is None or not recipient or not valid_delivery:
                unsupported.append({"file": relative, "line": line, "class": owner["name"],
                                    "reason": "Dynamic credit, unproven Player receiver or unsupported credit delivery",
                                    "call": call[1],
                                    "expression": masked[call.end():end].strip()})
                continue
            for actor, script in sorted(actual_owners):
                credits[str(credit)].add(actor)
                evidence[str(credit)].append({"actor": list(actor), "file": relative, "line": line,
                    "class": owner["name"], "script": script, "call": call[1],
                    "receiver": recipient})
    return {"credits": {key: [list(actor) for actor in sorted(actors)]
                        for key, actors in sorted(credits.items(), key=lambda row: int(row[0]))},
            "evidence": dict(evidence), "unsupported": unsupported}
