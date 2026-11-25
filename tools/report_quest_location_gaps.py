"""Inventory potential quest-location gaps without approving or changing DB data.

Run after regeneration. Base geometry and mapped quest guides are considered;
runtime faction, event, phase, eligibility and custom-server behavior still need
in-game review. Optional source caches label investigation leads, never approved
coordinates or proof that the current source still matches a cached extraction.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import re

from acore_npc_source_reader import LuaParser
from questie_base import base_text, parse_keys
from report_acore_quest_blacklist import parse_blacklist_entries, is_fully_blacklisted_in_wotlk


ROOT = Path(__file__).resolve().parents[1]
LIMITATIONS = [
    "Potential base-data coverage gaps are not a count of confirmed broken quests.",
    "Static blacklist entries are excluded; active seasonal events need a separate runtime check.",
    "Runtime faction/event/phase overrides, eligibility and custom server changes are not evaluated.",
    "Unused, testing, PvP and dungeon-specific quests can need no ordinary world-map marker.",
    "An alternate mapped guide does not establish that every quest stage is covered.",
    "Optional cache evidence is unvalidated and requires fresh source extraction and review.",
]


def _at(value, key, default=None):
    if isinstance(value, dict):
        return value.get(key, value.get("n:" + str(key), default))
    return value[key - 1] if isinstance(value, (list, tuple)) and 0 < key <= len(value) else default


def _values(value):
    if isinstance(value, dict):
        def order(key):
            text = str(key).removeprefix("n:")
            return (0, int(text)) if text.isdigit() else (1, text)
        return [value[key] for key in sorted(value, key=order)]
    return list(value) if isinstance(value, (list, tuple)) else []


def _points(value):
    pair = [_at(value, 1), _at(value, 2)]
    if all(type(number) in (int, float) and math.isfinite(number) and 0 <= number <= 100 for number in pair):
        return True
    return any(_points(child) for child in _values(value) if isinstance(child, (dict, list, tuple)))


def load_base(path, kind=None):
    """Decode generated single-row Lua records into field-name dictionaries."""
    path = Path(path)
    if kind is None:
        match = re.fullmatch(r"acore(Item|Npc|Object|Quest)DB\.lua", path.name)
        if match is None:
            raise ValueError("Specify the database kind for " + str(path))
        kind = match[1].lower()
    keys, records = parse_keys(path, kind), {}
    for line in base_text(path).splitlines():
        match = re.fullmatch(r"\s*\[(\d+)\]\s*=\s*(\{.*\})\s*,?\s*", line)
        if match:
            identity = int(match[1])
            if identity in records:
                raise ValueError("Duplicate database ID " + str(identity))
            raw = LuaParser(match[2]).parse()
            records[identity] = {field: _at(raw, slot) for field, slot in keys.items()}
    if not records:
        raise ValueError("No generated " + kind + " rows in " + str(path))
    return records


def analyze(quests, npcs, objects, items, blacklist=None, npc_source_cache=None, quest_source_cache=None):
    """Report missing base targets separately from usable alternate guides.

    Inputs use numeric IDs and native field-name records as returned by
    ``load_base``. Items may acquire locations through nested item containers.
    Objective numbering follows the generated NPC/object/item list order.
    """
    blacklist = blacklist or {}
    if isinstance(blacklist, dict):
        hidden = {int(key) for key, value in blacklist.items()
                  if value is True or isinstance(value, str) and is_fully_blacklisted_in_wotlk(value)}
    else:
        hidden = set(blacklist)
    tables = {"monster": npcs, "object": objects, "item": items}

    def has_location(kind, identity):
        row = tables[kind].get(identity, {})
        return _points(row.get("spawns")) or _points(row.get("waypoints"))

    def sources(kind, identity, seen=frozenset()):
        actor = (kind, identity)
        if actor in seen:
            return set()
        if kind != "item":
            return {actor}
        row, found = items.get(identity, {}), set()
        for field, child_kind in (("npcDrops", "monster"), ("objectDrops", "object"),
                                  ("vendors", "monster"), ("itemDrops", "item")):
            for child in _values(row.get(field)):
                if type(child) is int and child > 0:
                    found.update(sources(child_kind, child, seen | {actor}))
        return found or {actor}

    def mapped(kind, identity):
        return any(child_kind != "item" and has_location(child_kind, child)
                   for child_kind, child in sources(kind, identity))

    def target(kind, identity):
        providers = sources(kind, identity)
        return {"type": kind, "id": identity, "name": tables[kind].get(identity, {}).get("name"),
                "hasBaseLocation": mapped(kind, identity),
                "sources": [{"type": source_kind, "id": source_id,
                             "name": tables[source_kind].get(source_id, {}).get("name"),
                             "hasBaseLocation": source_kind != "item" and has_location(source_kind, source_id)}
                            for source_kind, source_id in sorted(providers)]}

    gaps, covered, counts = [], [], Counter()
    for quest_id, quest in sorted(quests.items()):
        if quest_id in hidden:
            counts["blacklistedQuestsSkipped"] += 1
            continue
        counts["questsReviewed"] += 1
        mapped_hints = []
        for hint in _values(quest.get("extraObjectives")):
            references = _values(_at(hint, 5))
            reference_location = any(_at(ref, 1) in tables and type(_at(ref, 2)) is int
                                     and mapped(_at(ref, 1), _at(ref, 2)) for ref in references)
            if _points(_at(hint, 1)) or reference_location:
                mapped_hints.append(_at(hint, 4, 0) or 0)
        trigger_location = _points(_at(quest.get("triggerEnd"), 2))
        counts["questsWithMappedGuide"] += bool(mapped_hints or trigger_location)
        common = {"questId": quest_id, "name": quest.get("name"), "zoneOrSort": quest.get("zoneOrSort")}
        objective_index = 0
        raw_objectives = quest.get("objectives")
        for category, kind in ((1, "monster"), (2, "object"), (3, "item")):
            for objective in _values(_at(raw_objectives, category)):
                objective_index += 1
                identity = _at(objective, 1)
                if type(identity) is not int or identity < 1:
                    continue
                if mapped(kind, identity):
                    continue
                alternate = trigger_location or any(index in (0, objective_index) for index in mapped_hints)
                row = {**common, "category": "objective", "objectiveIndex": objective_index,
                       "targets": [target(kind, identity)], "hasMappedGuide": bool(alternate),
                       "reason": "objectiveTargetHasNoBaseLocation"}
                if alternate:
                    covered.append(row)
                else:
                    gaps.append(row)
        # Kill-credit objectives can name several real actors. Audit the list,
        # rather than treating the artificial RootId as a permanent creature.
        for objective in _values(_at(raw_objectives, 5)):
            objective_index += 1
            identities = [value for value in _values(_at(objective, 1)) if type(value) is int and value > 0]
            if identities and not any(mapped("monster", value) for value in identities):
                alternate = trigger_location or any(index in (0, objective_index) for index in mapped_hints)
                row = {**common, "category": "objective", "objectiveIndex": objective_index,
                       "targets": [target("monster", value) for value in identities],
                       "hasMappedGuide": bool(alternate), "reason": "killCreditActorsHaveNoBaseLocation"}
                (covered if alternate else gaps).append(row)
        for role, field in (("starter", "startedBy"), ("finisher", "finishedBy")):
            actors = [(kind, identity) for index, kind in ((1, "monster"), (2, "object"), (3, "item"))
                      for identity in _values(_at(quest.get(field), index)) if type(identity) is int and identity > 0]
            missing = [target(kind, identity) for kind, identity in actors if not mapped(kind, identity)]
            if missing:
                gaps.append({**common, "category": role, "targets": missing,
                             "hasMappedAlternativeActor": any(mapped(kind, identity) for kind, identity in actors),
                             "hasMappedGuide": bool(mapped_hints or trigger_location),
                             "reason": role + "HasNoBaseLocation"})
        if not quest.get("startedBy"):
            counts["questsWithoutStarterRelations"] += 1
    packet = {"format": "questie-potential-location-gaps", "version": 1,
              "limitations": list(LIMITATIONS), "summary": dict(counts),
              "potentialGaps": gaps, "unlocatedObjectivesWithMappedGuide": covered}
    packet["summary"].update({"potentialGapRecords": len(gaps),
                              "questsWithPotentialGaps": len({row["questId"] for row in gaps}),
                              "unlocatedObjectivesWithMappedGuide": len(covered),
                              **{kind + "GapRecords": sum(row["category"] == kind for row in gaps)
                                 for kind in ("objective", "starter", "finisher")}})
    if npc_source_cache is not None or quest_source_cache is not None:
        npc_evidence = (npc_source_cache or {}).get("geometryProvenance", {}).get("scriptedGeometry", {}).get("entries", {})
        credit_evidence = (quest_source_cache or {}).get("objectiveCreditSources", {})
        for row in gaps:
            leads = []
            for entry in row["targets"]:
                for source in entry["sources"]:
                    if source["type"] != "monster":
                        continue
                    evidence = npc_evidence.get(str(source["id"]), {})
                    if _points(evidence.get("spawns")) and not evidence.get("failures", {}).get("spawns"):
                        leads.append({"type": "cachedFixedSummon", "npcId": source["id"]})
                if row["category"] == "objective" and entry["type"] == "monster":
                    actors = credit_evidence.get(str(entry["id"]), [])
                    located = [{"type": kind, "id": identity} for kind, identity in actors
                               if kind in tables and type(identity) is int and mapped(kind, identity)]
                    if located:
                        leads.append({"type": "cachedCreditActors", "creditId": entry["id"], "actors": located})
            if leads:
                row["unvalidatedCacheLeads"] = leads
                row["requiresFreshSourceReview"] = True
        packet["summary"]["gapRecordsWithUnvalidatedCacheLeads"] = sum(bool(row.get("unvalidatedCacheLeads")) for row in gaps)
    return packet


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for kind in ("quest", "npc", "object", "item"):
        parser.add_argument("--" + kind + "-db", type=Path,
                            default=ROOT / "Database/AzerothCore" / ("acore" + kind.title() + "DB.lua"))
    parser.add_argument("--blacklist", type=Path, default=ROOT / "Database/Corrections/QuestieQuestBlacklist.lua")
    parser.add_argument("--npc-source-cache", type=Path)
    parser.add_argument("--quest-source-cache", type=Path)
    parser.add_argument("--report", type=Path, default=ROOT / "tools/reports/quest-location-coverage.json")
    args = parser.parse_args(argv)
    report = args.report.resolve()
    if not report.is_relative_to(ROOT / "tools/reports") or report.suffix != ".json":
        raise ValueError("Report must be a .json file under tools/reports")
    inputs = [getattr(args, kind + "_db").resolve() for kind in ("quest", "npc", "object", "item")]
    inputs.extend(path.resolve() for path in (args.blacklist, args.npc_source_cache, args.quest_source_cache) if path)
    if report in inputs:
        raise ValueError("Report must not overwrite an input")
    data = {kind: load_base(getattr(args, kind + "_db"), kind) for kind in ("quest", "npc", "object", "item")}
    caches = {name: json.loads(path.read_text(encoding="utf-8")) if path else None
              for name, path in (("npc_source_cache", args.npc_source_cache), ("quest_source_cache", args.quest_source_cache))}
    packet = analyze(data["quest"], data["npc"], data["object"], data["item"],
                     parse_blacklist_entries(args.blacklist.read_text(encoding="utf-8-sig")), **caches)
    packet["inputs"] = {"baseFiles": [str(path) for path in inputs[:4]],
                        "cacheEvidenceValidated": False}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(packet, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"summary": packet["summary"], "report": str(report),
                      "notice": LIMITATIONS[0]}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit("Quest location audit failed: " + str(exc))
