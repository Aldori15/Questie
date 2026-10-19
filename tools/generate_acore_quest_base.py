"""Regenerate acoreQuestDB.lua from current AC source and Questie compatibility.

bootstrap is a one-time migration step. Routine generation needs no snapshot,
archive or previous source checkout. Use --output for a local candidate.
"""
import argparse
import copy
import json
import sys
from pathlib import Path

import audit_acore_item_sources as shared
import audit_acore_quest_sources as audit
import db_snapshot
from generate_acore_full_base import LuaBlobWriter, lua_quote, lua_value, row_to_lua
from generate_acore_npc_base import value_hash, write_manifest


ROOT = Path(__file__).resolve().parents[1]
FIELDS = audit.FIELDS
KEYS = {"s:" + field: index for index, field in enumerate(FIELDS, 1)}
LEGACY_FIELDS = set(FIELDS) - audit.SOURCE_FIELDS
ID_LIST_FIELDS = {field for field, kind in audit.metadata_reader.FIELD_KIND.items() if kind == "list"}
RELATION_FIELDS = {"startedBy", "finishedBy"}
DEFAULT_MANIFEST = Path("tools/data/acore_quest_compatibility.json")


def id_list(value):
    return isinstance(value, dict) and all(isinstance(k, str) and k.startswith("n:") and k[2:].isdigit() and int(k[2:]) > 0
                                         and type(v) is int and v != 0 for k, v in value.items())


def make_list_policy(actual, source):
    empty_value = actual is False
    if empty_value:
        actual = {}
    if not id_list(actual) or not id_list(source):
        raise ValueError("Expected an ordered quest ID list")
    policy = {"selected": copy.deepcopy(actual), "supplements": sorted(set(actual.values()) - set(source.values())),
              "excluded": sorted(set(source.values()) - set(actual.values()))}
    if empty_value:
        policy["emptyValue"] = False
    return policy


def refresh_list(policy, source):
    if not id_list(source):
        raise ValueError("Quest list source coverage is unavailable")
    allowed = (set(source.values()) - set(policy["excluded"])) | set(policy["supplements"])
    selected = policy["selected"]
    result = {key: value for key, value in selected.items() if value in allowed}
    index = max((int(k[2:]) for k in selected), default=0)
    for value in sorted(allowed - set(result.values())):
        index += 1
        result[f"n:{index}"] = value
    if set(selected) == {f"n:{i}" for i in range(1, len(selected) + 1)}:
        result = {f"n:{i}": value for i, (_, value) in enumerate(sorted(result.items(), key=lambda p: int(p[0][2:])), 1)}
    return False if not result and policy.get("emptyValue", {}) is False else result


def make_relation_policy(actual, source):
    if not isinstance(actual, dict) or not isinstance(source, dict):
        raise ValueError("Expected categorized quest relations")
    if not (set(actual) | set(source)) <= {"n:1", "n:2", "n:3"}:
        raise ValueError("Unknown quest relation source category")
    return {category: {"present": category in actual, **make_list_policy(actual.get(category, {}), source.get(category, {}))}
            for category in sorted(set(actual) | set(source))}


def refresh_relations(policy, source):
    if not isinstance(source, dict) or not set(source) <= {"n:1", "n:2", "n:3"}:
        raise ValueError("Quest relation source coverage is unavailable")
    result = {}
    for category in sorted(set(policy) | set(source)):
        selection = policy.get(category, {"selected": {}, "supplements": [], "excluded": [], "present": False})
        values = refresh_list(selection, source.get(category, {}))
        if values or selection["present"]:
            result[category] = values
    return result


def make_manifest(records, source, metadata, snapshot_sha, signature):
    scope, extras, legacy, lists, relations, overrides = {}, {}, {}, {}, {}, {}
    for quest_id, row in sorted(records.items()):
        if not row or not set(row) <= set(KEYS):
            raise ValueError(f"Invalid baseline quest {quest_id}")
        row_to_lua(row, KEYS)
        key = str(quest_id)
        scope[key] = sum(1 << (KEYS[field] - 1) for field in row)
        if quest_id not in source:
            extras[key] = copy.deepcopy(row)
            continue
        raw = source[quest_id]
        for field in FIELDS:
            typed_key = "s:" + field
            actual, expected = row.get(typed_key, shared.ABSENT), raw.get(typed_key, shared.ABSENT)
            if field in LEGACY_FIELDS:
                if actual is not shared.ABSENT:
                    legacy.setdefault(key, {})[field] = copy.deepcopy(actual)
            elif field in ID_LIST_FIELDS:
                if expected is shared.ABSENT:
                    raise ValueError(f"Missing {field} source for quest {quest_id}")
                selection = {} if actual is shared.ABSENT else actual
                if not shared.same_value(selection, expected):
                    lists.setdefault(key, {})[field] = make_list_policy(selection, expected)
            elif field in RELATION_FIELDS:
                if expected is shared.ABSENT:
                    raise ValueError(f"Missing {field} source for quest {quest_id}")
                selection = {} if actual is shared.ABSENT else actual
                if not shared.same_value(selection, expected):
                    relations.setdefault(key, {})[field] = make_relation_policy(selection, expected)
            elif actual is shared.ABSENT:
                if expected is not shared.ABSENT and not audit.representation_only(field, shared.ABSENT, expected):
                    overrides.setdefault(key, {})[field] = {"omit": True, "expectedSource": value_hash(expected)}
            elif not shared.same_value(actual, expected):
                override = {"value": copy.deepcopy(actual), "expectedSource": value_hash(expected)}
                # Empty/default spelling changes may refresh freely. Nonempty
                # objective helpers cannot be dropped when source targets change.
                if field == "objectives" and not audit.representation_only(field, actual, expected):
                    override["reviewOnChange"] = True
                overrides.setdefault(key, {})[field] = override
    size = candidate_size(records)
    return {"format": "questie-acore-quest-compatibility", "version": 1,
            "provenance": {"snapshotSha256": snapshot_sha, "snapshotCommit": (metadata.get("git") or {}).get("commit"),
                           "acoreCommit": signature.get("sourceRevision")},
            "policy": "Refresh source fields; preserve explicit helpers, list supplements/exclusions and conditional scalar exceptions. Review changed objective-helper assumptions.",
            "limits": {"maxOutputBytes": size + max(65536, size // 20)},
            "scope": scope, "excludedQuestIds": sorted(set(source) - set(records)), "extraRecords": extras,
            "legacyFields": legacy, "lists": lists, "relations": relations, "overrides": overrides}


def validate_manifest(manifest):
    if manifest.get("format") != "questie-acore-quest-compatibility" or manifest.get("version") != 1:
        raise ValueError("Unsupported quest compatibility manifest")
    scope = manifest.get("scope")
    if not isinstance(scope, dict) or not scope:
        raise ValueError("Missing quest scope")
    for key, mask in scope.items():
        if not key.isdigit() or int(key) < 1 or str(int(key)) != key or type(mask) is not int or not 0 < mask < 1 << len(FIELDS):
            raise ValueError("Invalid quest scope ID or field mask")
    excluded = manifest.get("excludedQuestIds")
    if not isinstance(excluded, list) or not all(type(i) is int and i > 0 for i in excluded) or excluded != sorted(set(excluded)) or set(excluded) & {int(k) for k in scope}:
        raise ValueError("Invalid excluded quest IDs")
    sections = {"legacyFields": LEGACY_FIELDS, "lists": ID_LIST_FIELDS, "relations": RELATION_FIELDS,
                "overrides": set(FIELDS) - LEGACY_FIELDS - ID_LIST_FIELDS - RELATION_FIELDS}
    for section in (*sections, "extraRecords"):
        if not isinstance(manifest.get(section), dict) or not set(manifest[section]) <= set(scope):
            raise ValueError(f"Invalid {section} IDs")
    if any(set(manifest["extraRecords"]) & set(manifest[s]) for s in sections):
        raise ValueError("Extra quests cannot have source-backed policies")
    for key, row in manifest["extraRecords"].items():
        if not isinstance(row, dict) or not set(row) <= set(KEYS) or sum(1 << (KEYS[k] - 1) for k in row) != scope[key]:
            raise ValueError("Invalid extra quest record")
        row_to_lua(row, KEYS)
    for section, allowed in sections.items():
        for fields in manifest[section].values():
            if not isinstance(fields, dict) or not set(fields) <= allowed:
                raise ValueError(f"Invalid {section} fields")
            for value in fields.values():
                if section == "overrides":
                    if (not isinstance(value, dict) or not isinstance(value.get("expectedSource"), str)
                            or ("value" in value) == (value.get("omit") is True)
                            or set(value) - {"value", "omit", "expectedSource", "reviewOnChange"}
                            or "reviewOnChange" in value and value["reviewOnChange"] is not True):
                        raise ValueError("Invalid quest conditional override")
                elif section in {"lists", "relations"}:
                    policies = value.values() if section == "relations" and isinstance(value, dict) else [value]
                    if section == "relations" and (not isinstance(value, dict) or not set(value) <= {"n:1", "n:2", "n:3"}):
                        raise ValueError("Invalid quest relation categories")
                    for policy in policies:
                        if (not isinstance(policy, dict) or not id_list(policy.get("selected"))
                                or any(not isinstance(policy.get(name), list) or any(type(i) is not int or i == 0 for i in policy[name])
                                       for name in ("supplements", "excluded"))
                                or section == "relations" and type(policy.get("present")) is not bool
                                or "emptyValue" in policy and policy["emptyValue"] is not False):
                            raise ValueError("Invalid quest list policy")
    if type(manifest.get("limits", {}).get("maxOutputBytes")) is not int or manifest["limits"]["maxOutputBytes"] < 1:
        raise ValueError("Missing quest size budget")
    return manifest


def build_records(source, manifest):
    validate_manifest(manifest)
    result = {}
    scope = {int(key) for key in manifest["scope"]} | (set(source) - set(manifest["excludedQuestIds"]))
    for quest_id in sorted(scope):
        key = str(quest_id)
        if key in manifest["extraRecords"]:
            if quest_id in source:
                raise ValueError(f"Supplemental quest {quest_id} now has a source template; resolve this ID collision")
            result[quest_id] = copy.deepcopy(manifest["extraRecords"][key])
            continue
        if quest_id not in source:
            continue
        raw, row = source[quest_id], {}
        mask = manifest["scope"].get(key, sum(1 << (KEYS[k] - 1) for k in raw if k in KEYS))
        for field in FIELDS:
            typed_key = "s:" + field
            present = bool(mask & (1 << (KEYS[typed_key] - 1)))
            value = raw.get(typed_key, shared.ABSENT)
            if field in LEGACY_FIELDS:
                value = manifest["legacyFields"].get(key, {}).get(field, shared.ABSENT)
            elif field in ID_LIST_FIELDS:
                value = refresh_list(manifest["lists"].get(key, {}).get(field, {"selected": {}, "supplements": [], "excluded": []}), value)
            elif field in RELATION_FIELDS:
                value = refresh_relations(manifest["relations"].get(key, {}).get(field, {}), value)
            else:
                override = manifest["overrides"].get(key, {}).get(field)
                if override:
                    if value_hash(value) == override["expectedSource"]:
                        value = shared.ABSENT if override.get("omit") else override["value"]
                    elif override.get("reviewOnChange"):
                        raise ValueError(f"Quest {quest_id} {field}: source targets changed behind display helpers; review this compatibility override")
            if value is shared.ABSENT:
                if present:
                    raise ValueError(f"Missing source or explicit compatibility field {field} for quest {quest_id}")
                continue
            if present or not audit.representation_only(field, shared.ABSENT, value):
                row[typed_key] = copy.deepcopy(value)
        row_to_lua(row, KEYS)
        result[quest_id] = row
    if len(result) < len(manifest["scope"]) * 0.95:
        raise ValueError("Unexpected removal of more than 5% of quest records; check source completeness")
    return result


def compare_records(before, after):
    differences = []
    for quest_id in sorted(set(before) | set(after)):
        a, b = before.get(quest_id, shared.ABSENT), after.get(quest_id, shared.ABSENT)
        if not shared.same_value(a, b):
            differences.append({"questId": quest_id, "before": None if a is shared.ABSENT else a,
                                "after": None if b is shared.ABSENT else b})
    return {"exactParity": not differences, "changedRecords": len(differences), "differences": differences}


def build_starter_selections(source, records, teams, script_starters=None):
    """Generate faction views from raw relations, never the retired trainer lists."""
    selections = {"Alliance": {}, "Horde": {}}
    script_starters = script_starters or {}
    scope = audit.FACTION_STARTER_QUESTS | {int(key) for key in script_starters}
    for quest_id in sorted(scope & set(records) & set(source)):
        raw = copy.deepcopy(source[quest_id]["s:startedBy"])
        givers = script_starters.get(str(quest_id), [])
        if givers:
            raw["n:1"] = audit.typed(sorted(set(raw.get("n:1", {}).values()) | set(givers)))
        for faction, bit in (("Alliance", 1), ("Horde", 2)):
            relation = copy.deepcopy(raw)
            npcs = raw.get("n:1", {})
            if not id_list(npcs):
                raise ValueError(f"Quest {quest_id}: invalid source starter list")
            selected = []
            for _, npc in sorted(npcs.items(), key=lambda pair: int(pair[0][2:])):
                mask = teams.get(str(npc))
                if type(mask) is not int or mask not in (1, 2, 3):
                    raise ValueError(f"Quest {quest_id} starter NPC {npc}: missing faction selection")
                if mask & bit:
                    selected.append(npc)
            if selected:
                relation["n:1"] = audit.typed(selected)
            else:
                relation.pop("n:1", None)
            # Empty selections deliberately suppress the other team's starters.
            selections[faction][quest_id] = {"s:startedBy": relation}
    return selections


def build_chain_selections(source, records, excluded=()):
    """Route the audited neutral chains using current child prerequisites/races."""
    result = {"Alliance": {}, "Horde": {}}
    active = set(source) - set(excluded)
    for parent in sorted({2954, 5021, 6981, 8928, 8996} & set(records) & active):
        direct = source[parent].get("s:nextQuestInChain", 0)
        children = {direct} if direct else {child for child in active
                    if parent in source[child].get("s:preQuestSingle", {}).values()}
        for team, mask in (("Alliance", 1101), ("Horde", 690)):
            eligible = []
            for child in sorted(children & active):
                races = source[child].get("s:requiredRaces", 0)
                if not races or races & mask:
                    if child not in records:
                        raise ValueError(f"Quest {parent}: {team} child {child} is excluded from the base; review chain routing")
                    eligible.append(child)
            if len(eligible) > 1:
                raise ValueError(f"Quest {parent}: ambiguous {team} successors {eligible}; review chain routing")
            result[team][parent] = {"s:nextQuestInChain": eligible[0] if eligible else 0}
    return result


def write_stream(stream, records, starter_selections=None):
    stream.write('-- Generated from AzerothCore source and explicit Questie compatibility data.\n')
    stream.write('-- Generator: tools/generate_acore_quest_base.py\n')
    stream.write('local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n\nQuestieDB.questKeys = {\n')
    for field, index in KEYS.items():
        stream.write(f'    [{lua_quote(field[2:])}] = {index},\n')
    stream.write('}\n\n')
    writer = LuaBlobWriter(stream, "questData")
    for quest_id, row in sorted(records.items()):
        writer.write(f'[{quest_id}]={row_to_lua(row, KEYS)},\n')
    writer.finish()
    if starter_selections is not None:
        stream.write('\n-- Source-derived faction views; quest records above remain shared.\n')
        stream.write('QuestieDB.questFactionSelections = (UnitFactionGroup("player") == "Horde") and {\n')
        for faction, ending in (("Horde", '} or {\n'), ("Alliance", '}\n')):
            for quest_id, fields in sorted(starter_selections[faction].items()):
                stream.write(f'    [{quest_id}] = {lua_value({"n:" + str(KEYS[field]): value for field, value in fields.items()})},\n')
            stream.write(ending)


def candidate_size(records, starter_selections=None):
    class ByteCounter:
        size = 0

        def write(self, value):
            self.size += len(value.encode("utf-8"))
    counter = ByteCounter()
    write_stream(counter, records, starter_selections)
    return counter.size


def local_path(path, directory, suffix):
    path = (ROOT / path).resolve()
    production = (ROOT / "Database/AzerothCore/acoreQuestDB.lua").resolve()
    if (not path.is_relative_to(ROOT / directory) and not (directory == "tools/reports" and path == production)) or path.suffix != suffix:
        raise ValueError(f"Output must be {suffix} under {directory}")
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("bootstrap", "generate"):
        child = commands.add_parser(name)
        child.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
        child.add_argument("--spell-sql", type=Path, required=True)
        child.add_argument("--spell-table", default="spell")
        child.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
        child.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_quest_source_model.json"))
        child.add_argument("--force", action="store_true", help="Overwrite a one-time migration manifest")
    commands.choices["bootstrap"].add_argument("--snapshot", type=Path, required=True)
    commands.choices["generate"].add_argument("--compare-snapshot", type=Path,
                                             help="Compare shared quest rows; review generated faction selections separately")
    commands.choices["generate"].add_argument("--output", type=Path, default=Path("Database/AzerothCore/acoreQuestDB.lua"))
    commands.choices["generate"].add_argument("--report", type=Path, default=Path("tools/reports/acore_quest_base_candidate.json"))
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments and arguments[0].startswith("-"):
        arguments.insert(0, "generate")
    args = parser.parse_args(arguments)
    source, spell = args.acore_source.resolve(), args.spell_sql.resolve()
    cache = shared.local_output(ROOT, args.source_cache)
    manifest_path = local_path(args.manifest, "tools/data", ".json")
    snapshot_path = args.snapshot if args.command == "bootstrap" else args.compare_snapshot
    targets = [manifest_path] if args.command == "bootstrap" else [local_path(args.output, "tools/reports", ".lua"), shared.local_output(ROOT, args.report)]
    inputs = {cache, spell, *([snapshot_path.resolve()] if snapshot_path else [])}
    if args.command == "generate":
        inputs.add(manifest_path)
    if len(set(targets)) != len(targets) or any(p in inputs for p in targets):
        raise ValueError("Output paths must differ from inputs and each other")
    if args.command == "bootstrap" and manifest_path.exists() and not args.force:
        raise ValueError("Manifest already exists; review it or explicitly use --force")
    signature = audit.source_signature(source, spell, args.spell_table)
    saved = audit.load_source(source, spell, args.spell_table, signature, cache)
    if any(saved["diagnostics"].values()) or any(row["skippedMutations"] for row in saved["tableCoverage"].values()):
        raise ValueError("Quest source diagnostics require review before generation")
    model = {int(key): row for key, row in saved["quests"].items()}
    baseline = metadata = snapshot_sha = None
    if snapshot_path:
        snapshot_sha = db_snapshot.file_hash(snapshot_path)
        baseline, fields, _, metadata = shared.read_static_records(snapshot_path, ROOT, "quest")
        if tuple(fields) != FIELDS:
            raise ValueError("Unexpected quest schema")
    if args.command == "bootstrap":
        manifest = make_manifest(baseline, model, metadata, snapshot_sha, signature)
    else:
        manifest_sha = db_snapshot.file_hash(manifest_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = build_records(model, manifest)
    starter_selections = build_starter_selections(model, records, saved.get("starterTeams", {}),
                                                saved.get("scriptQuestStarters", {}))
    starter_ids = sorted(starter_selections["Alliance"])
    chain_selections = build_chain_selections(model, records, set(saved.get("disabledQuestIds", [])) | set(saved.get("moduleQuestIds", [])))
    for team in starter_selections:
        for quest_id, fields in chain_selections[team].items():
            starter_selections[team].setdefault(quest_id, {}).update(fields)
        for key, rewards in saved.get("factionReputationRewards", {}).items():
            quest_id = int(key)
            if quest_id in records and not shared.same_value(records[quest_id].get("s:reputationReward", {}), rewards[team]):
                starter_selections[team].setdefault(quest_id, {})["s:reputationReward"] = rewards[team]
    comparison = compare_records(baseline, records) if baseline is not None else None
    if comparison and not comparison["exactParity"]:
        if args.command == "generate":
            shared.write_json(targets[1], {"comparison": comparison})
        ids = [row["questId"] for row in comparison["differences"][:20]]
        raise ValueError(f"Quest candidate differs from baseline ({comparison['changedRecords']} records; IDs {ids}); no candidate or manifest published")
    if candidate_size(records, starter_selections) > manifest["limits"]["maxOutputBytes"]:
        raise ValueError("Quest candidate exceeds its baseline size budget")
    if audit.source_signature(source, spell, args.spell_table) != signature:
        raise ValueError("Quest source inputs changed during generation")
    if snapshot_path and (db_snapshot.file_hash(snapshot_path) != snapshot_sha or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items())):
        raise ValueError("Snapshot or addon changed during generation")
    summary = {"quests": len(records), "exactParity": comparison["exactParity"] if comparison else None,
               "changedRecords": comparison["changedRecords"] if comparison else None,
               "parityScope": "shared quest rows; faction selections require runtime snapshot review",
               "factionStarterQuests": starter_ids, "factionChainQuests": sorted(chain_selections["Alliance"])}
    if args.command == "bootstrap":
        write_manifest(manifest_path, manifest)
        summary.update({"manifest": str(manifest_path), "extraRecords": len(manifest["extraRecords"]),
                        "questsWithLegacyFields": len(manifest["legacyFields"]),
                        "guardedObjectiveOverrides": sum(bool(row.get("objectives", {}).get("reviewOnChange")) for row in manifest["overrides"].values())})
    else:
        if db_snapshot.file_hash(manifest_path) != manifest_sha:
            raise ValueError("Quest compatibility manifest changed during generation")
        output, report = targets
        output.parent.mkdir(parents=True, exist_ok=True)
        with db_snapshot.temporary_directory(output.parent) as directory:
            candidate = directory / "acoreQuestDB.lua"
            with candidate.open("w", encoding="utf-8", newline="\n") as stream:
                write_stream(stream, records, starter_selections)
            if candidate.stat().st_size > manifest["limits"]["maxOutputBytes"]:
                raise ValueError("Serialized quest candidate exceeds size budget")
            shared.write_json(report, {"sourceInputs": signature, "manifestSha256": manifest_sha,
                                      "comparisonSnapshotSha256": snapshot_sha, "comparison": comparison,
                                      "outputSha256": db_snapshot.file_hash(candidate), "outputBytes": candidate.stat().st_size,
                                      "maxOutputBytes": manifest["limits"]["maxOutputBytes"], "counts": summary,
                                      "factionSelections": starter_selections,
                                      "excludedSourceQuestIds": sorted(set(model) - set(records))})
            candidate.replace(output)
        summary.update({"output": str(output), "report": str(report), "outputMiB": round(output.stat().st_size / 1048576, 2)})
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit(f"Quest base generation failed: {exc}")
