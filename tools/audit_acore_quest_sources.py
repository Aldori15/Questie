"""Audit quest source coverage against a verified snapshot without changing addon data."""
import argparse
from collections import Counter
from contextlib import ExitStack
import copy
import hashlib
import inspect
import json
from pathlib import Path
import subprocess
from unittest.mock import patch

import audit_acore_item_sources as shared
import db_snapshot
import generate_acore_item_corrections as sql_reader
import validate_acore_quest_metadata as metadata_reader
import validate_acore_quest_relations as relation_reader


ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("name", "startedBy", "finishedBy", "requiredLevel", "questLevel", "requiredRaces",
          "requiredClasses", "objectivesText", "triggerEnd", "objectives", "sourceItemId",
          "preQuestGroup", "preQuestSingle", "childQuests", "inGroupWith", "exclusiveTo",
          "zoneOrSort", "requiredSkill", "requiredMinRep", "requiredMaxRep", "requiredSourceItems",
          "nextQuestInChain", "questFlags", "specialFlags", "parentQuest", "reputationReward",
          "breadcrumbForQuestId", "breadcrumbs", "extraObjectives", "requiredSpell",
          "requiredSpecialization", "requiredMaxLevel", "availableUntilCompleted",
          "availableStartingWith", "requiredRanks", "disabledByQuest", "requiredItemConditions")
SOURCE_FIELDS = set(metadata_reader.FIELD_ORDER) | {"startedBy", "finishedBy", "zoneOrSort"}
# Ordinary starter lists audited for the first faction migration. Scripted
# letter distributors, event quests and disputed eligibility rules stay separate.
FACTION_STARTER_QUESTS = frozenset({687, 737, 1718, 1947, 1953, 2861, 5050, 7562, 8254})
TABLE_KEYS = {
    "quest_template": ("ID",), "quest_template_addon": ("ID",), "item_template": ("entry",),
    "spell_dbc": ("ID",), "conditions": metadata_reader.CONDITION_KEY_COLUMNS,
    "disables": ("sourceType", "entry"),
    "creature_template": ("entry",), "factiontemplate_dbc": ("ID",),
    "smart_scripts": ("entryorguid", "source_type", "id", "link"),
    **{table: (("eventEntry", "id", "quest") if table.startswith("game_event_") else ("id", "quest"))
       for table in relation_reader.TARGET_TABLES},
}


def typed(value):
    if isinstance(value, (tuple, list)):
        return {f"n:{i}": typed(v) for i, v in enumerate(value, 1) if v is not None}
    if isinstance(value, dict):
        return {("n:" if type(k) is int else "s:") + str(k): typed(v) for k, v in value.items() if v is not None}
    return value


def source_signature(source, spell_sql, spell_table):
    paths = {p.resolve() for table in TABLE_KEYS for p in sql_reader.source_sql_files(source, table)}
    paths.update(source / "data/sql/base/db_world" / f"{table}.sql" for table in TABLE_KEYS)
    for root in metadata_reader.get_excluded_module_sql_roots(source):
        paths.update(p.resolve() for p in root.rglob("*.sql"))
    revision = subprocess.run(["git", "-C", str(source), "rev-parse", "HEAD"], capture_output=True, text=True)
    readers = ("generate_acore_item_corrections.py", "validate_acore_quest_metadata.py", "validate_acore_quest_relations.py")
    return {"version": 3, "sourceRoot": str(source), "includeModules": False,
            "sourceRevision": revision.stdout.strip() if revision.returncode == 0 else None,
            "sourceFiles": {str(p.relative_to(source)): db_snapshot.file_hash(p) for p in sorted(paths)},
            "spellExport": {"path": str(spell_sql), "sha256": db_snapshot.file_hash(spell_sql), "table": spell_table},
            "readers": {name: db_snapshot.file_hash(ROOT / "tools" / name) for name in readers},
            "extractor": hashlib.sha256((inspect.getsource(load_source) + inspect.getsource(typed)
                                         + inspect.getsource(build_relations) + inspect.getsource(missing_spell_references)
                                         + inspect.getsource(starter_teams) + inspect.getsource(script_quest_starters)
                                         + inspect.getsource(faction_reputation_rewards)
                                         + repr(sorted(FACTION_STARTER_QUESTS))).encode()).hexdigest()}


def model_digest(saved):
    payload = {key: saved[key] for key in ("quests", "tableCoverage", "diagnostics", "disabledQuestIds", "moduleQuestIds", "spellCoverage")}
    payload["starterTeams"] = saved.get("starterTeams", {})
    payload["scriptQuestStarters"] = saved.get("scriptQuestStarters", {})
    payload["factionReputationRewards"] = saved.get("factionReputationRewards", {})
    return hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=True, allow_nan=False,
                                     separators=(",", ":")).encode()).hexdigest()


def build_relations(rows, module_ids, disabled_ids):
    result = {}
    excluded = set(module_ids) | set(disabled_ids)
    for table, (side, kind) in relation_reader.TARGET_TABLES.items():
        for row in rows(table):
            quest, source_id = int(row.get("quest") or 0), int(row.get("id") or 0)
            if not quest or not source_id or quest in excluded:
                continue
            source_id = relation_reader.normalize_relation_source_id(kind, source_id)
            result.setdefault(quest, relation_reader.empty_relation())[side][kind].add(source_id)
    for row in rows("item_template"):
        quest = int(row.get("startquest") or row.get("StartQuest") or 0)
        if quest > 0 and quest not in excluded:
            result.setdefault(quest, relation_reader.empty_relation())["start"]["item"].add(int(row["entry"]))
    return result


def script_quest_starters(rows, templates):
    """Locate Ravenholdt letter distributors through their gossip action chains.

    Spell21100 creates item17126, which starts quest6681. This explicit script
    interpretation supplies map helpers, not additional server quest relations.
    """
    if 6681 not in templates:
        return {}
    scripts = [row for row in rows("smart_scripts") if int(row.get("source_type") or 0) == 0]
    by_npc = {}
    for row in scripts:
        by_npc.setdefault(int(row["entryorguid"]), {})[int(row["id"])] = row
    menus = {(int(row["SourceGroup"]), int(row["SourceEntry"])) for row in rows("conditions")
             if int(row.get("SourceTypeOrReferenceId") or 0) == 15
             and int(row.get("ConditionTypeOrReference") or 0) in (8, 9, 28)
             and int(row.get("ConditionValue1") or 0) == 6681}
    givers = set()
    for npc, actions in by_npc.items():
        if npc <= 0:
            continue
        for root in actions.values():
            if int(root.get("event_type") or 0) != 62 or (
                    int(root.get("event_param1") or 0), int(root.get("event_param2") or 0)) not in menus:
                continue
            action, visited = root, set()
            while action is not None:
                identifier = int(action["id"])
                if identifier in visited:
                    raise ValueError(f"Quest6681 letter NPC {npc}: cyclic gossip action chain")
                visited.add(identifier)
                if (int(action.get("action_type") or 0) == 11 and int(action.get("action_param1") or 0) == 21100
                        and int(action.get("target_type") or 0) == 7):
                    givers.add(npc)
                link = int(action.get("link") or 0)
                if link and link not in actions:
                    raise ValueError(f"Quest6681 letter NPC {npc}: missing linked gossip action {link}")
                action = actions.get(link) if link else None
    if not givers:
        raise ValueError("Quest6681 letter distributors are unavailable; review current SmartAI/gossip rules")
    return {"6681": sorted(givers)}


def faction_reputation_rewards(derived, rows, excluded):
    """Mirror Player::RewardReputation for the audited Hilary exception.

    The core picks the first template by ID for each reputation faction, then
    skips a reward if its EnemyGroup contains that player's team. New/changed
    rewards refresh here rather than being hidden by a permanent empty table.
    """
    if 3741 not in derived or 3741 in excluded:
        return {}
    first = {}
    for row in sorted(rows("factiontemplate_dbc"), key=lambda value: int(value["ID"])):
        first.setdefault(int(row.get("Faction") or 0), int(row.get("EnemyGroup") or 0))
    rewards = derived[3741]["reputationReward"]
    return {"3741": {team: typed([reward for reward in rewards if not first.get(int(reward[0]), 0) & mask])
                     for team, mask in (("Alliance", 2), ("Horde", 4))}}


def starter_teams(relations, rows, script_starters=None):
    """Filter only explicit opposite-team hostility, not neutral reputation.

    Match AC FactionTemplateEntry::IsHostileTo, including explicit relations.
    This is a faction map selection, not a replacement for quest eligibility,
    player reputation, conditions or scripted item-distribution helpers.
    """
    wanted = {npc for quest in FACTION_STARTER_QUESTS
              for npc in relations.get(quest, {}).get("start", {}).get("creature", ())}
    wanted.update(npc for givers in (script_starters or {}).values() for npc in givers)
    if not wanted:
        return {}
    creatures = {int(row["entry"]): row for row in rows("creature_template")}
    factions = {int(row["ID"]): row for row in rows("factiontemplate_dbc")}
    # The same player-race templates used by the NPC source reader. Differing
    # hostility within one team needs race-specific handling, not an approximation.
    player_templates = {"Alliance": (1, 3, 4, 115, 1629), "Horde": (2, 5, 6, 116, 1610)}
    for anchors in player_templates.values():
        if any(anchor not in factions for anchor in anchors):
            raise ValueError("Quest starters: missing player faction templates")

    def hostile(template, player):
        faction = int(player.get("Faction") or 0)
        if faction:
            if any(int(template.get(f"Enemies_{i}") or 0) == faction for i in range(1, 5)):
                return True
            if any(int(template.get(f"Friend_{i}") or 0) == faction for i in range(1, 5)):
                return False
        return bool(int(template["EnemyGroup"]) & int(player["FactionGroup"]))

    result = {}
    for npc in sorted(wanted):
        template = creatures.get(npc)
        faction = factions.get(int(template.get("faction") or 0)) if template else None
        if faction is None or "EnemyGroup" not in faction:
            raise ValueError(f"Quest starter NPC {npc}: missing source faction hostility data")
        teams = 0
        for team, bit in (("Alliance", 1), ("Horde", 2)):
            reactions = {hostile(faction, factions[anchor]) for anchor in player_templates[team]}
            if len(reactions) != 1:
                raise ValueError(f"Quest starter NPC {npc}: race-specific hostility within {team}; review eligibility")
            if reactions == {False}:
                teams |= bit
        if not teams:
            raise ValueError(f"Quest starter NPC {npc}: hostile to both teams; review scripted eligibility")
        result[str(npc)] = teams
    return result


def missing_spell_references(missing_ids, items, quests):
    """Separate unresolved spells on arbitrary items from quest source-item uses."""
    missing_ids = set(missing_ids)
    item_spells = metadata_reader.build_item_use_spell_map({int(row["entry"]): row for row in items})
    references = []
    for spell_id in sorted(missing_ids):
        affected = {item_id for item_id, spells in item_spells.items() if spell_id in spells}
        source_quests, start_quests, required_quests = set(), set(), set()
        for row in quests:
            quest_id = int(row["ID"])
            if any(int(row.get(f"ItemDrop{i}") or 0) in affected for i in range(1, 5)):
                source_quests.add(quest_id)
            if int(row.get("StartItem") or 0) in affected:
                start_quests.add(quest_id)
            if any(int(row.get(f"RequiredItemId{i}") or 0) in affected for i in range(1, 7)):
                required_quests.add(quest_id)
        references.append({"spellId": spell_id,
                           "items": [{"itemId": int(row["entry"]), "name": row.get("name", "")}
                                     for row in items if int(row["entry"]) in affected],
                           "requiredSourceItemQuestIds": sorted(source_quests),
                           "startItemQuestIds": sorted(start_quests), "requiredItemQuestIds": sorted(required_quests)})
    return references


def load_source(source, spell_sql, spell_table, signature, cache, refresh=False):
    if cache.exists() and not refresh:
        saved = json.loads(cache.read_text(encoding="utf-8"))
        if saved.get("signature") == signature:
            if saved.get("modelSha256") != model_digest(saved):
                raise ValueError("Quest cache checksum mismatch; use --refresh-source")
            print(f"Using validated quest source cache: {cache}", flush=True)
            return saved
    tables, coverage, skipped_statements = {}, {}, []
    spell_coverage = {}
    script_spell_items = {}
    original_rows, original_statements = sql_reader.load_row_table, sql_reader.load_sql_statements
    original_table = metadata_reader.load_acore_sql_table
    current_file = {"path": None}

    def statements(path):
        current_file["path"] = Path(path).resolve()
        return original_statements(path)

    def trace_mutation(name, original):
        def replay(statement, table, *args, **kwargs):
            skipped = original(statement, table, *args, **kwargs)
            if skipped:
                path = current_file["path"]
                skipped_statements.append({"table": table, "operation": name.removeprefix("apply_multirow_"),
                                           "file": str(path.relative_to(source)) if path and path.is_relative_to(source) else str(path),
                                           "skippedCount": skipped, "statement": statement[:4000],
                                           "statementTruncated": len(statement) > 4000,
                                           "statementSha256": hashlib.sha256(statement.encode()).hexdigest()})
            return skipped
        return replay

    def rows(table):
        if table not in tables:
            print(f"Reading {table}...", flush=True)
            if table == "conditions":
                # Every condition primary-key column is NOT NULL DEFAULT 0 in
                # AC's schema. Apply those defaults only for omitted columns;
                # explicit NULL must still fail rather than becoming zero.
                values, skipped = original_rows(source, table, TABLE_KEYS[table], False,
                                                column_defaults={column: 0 for column in TABLE_KEYS[table]})
            else:
                values, skipped = original_rows(source, table, TABLE_KEYS[table], False)
            tables[table] = values
            coverage[table] = {"rows": len(values), "skippedMutations": skipped}
        return tables[table]

    def keyed(root, table, base_file_override=None, key_column="ID", include_modules=False, wanted_keys=None):
        if include_modules:
            raise ValueError("Quest audit must not include module SQL")
        if base_file_override is not None:
            if Path(base_file_override).resolve() != spell_sql or table != spell_table:
                raise ValueError("Unexpected quest audit SQL export")
            if wanted_keys is not None and any(int(row["ID"]) == 6681 for row in rows("quest_template")):
                wanted_keys = set(wanted_keys) | {21100}
            exported = original_table(root, table, base_file_override, key_column=key_column, wanted_keys=wanted_keys)
            sql_spells = {int(row["ID"]): row for row in rows("spell_dbc")}
            # Numeric SQL spell overrides, including zeros, supersede the DBC.
            for spell_id, row in sql_spells.items():
                if wanted_keys is None or spell_id in wanted_keys:
                    exported[spell_id] = {**exported.get(spell_id, {}), **row}
            wanted = set(wanted_keys or ())
            spell = exported.get(21100, {})
            script_spell_items[21100] = sorted({metadata_reader.get_numbered_spell_field(spell, "EffectItemType", i)
                                               for i in range(1, 4)
                                               if metadata_reader.get_numbered_spell_field(spell, "Effect", i) in (24, 157)})
            spell_coverage.update({"requestedSpellIds": len(wanted), "resolvedRequestedSpellIds": len(wanted & set(exported)),
                                   "missingRequestedSpellIds": sorted(wanted - set(exported)), "sqlRows": len(sql_spells)})
            return exported
        return {int(row[key_column]): copy.deepcopy(row) for row in rows(table)}

    with ExitStack() as stack:
        stack.enter_context(patch.object(sql_reader, "load_sql_statements", statements))
        for name in ("apply_multirow_insert", "apply_multirow_delete", "apply_multirow_update"):
            stack.enter_context(patch.object(sql_reader, name, trace_mutation(name, getattr(sql_reader, name))))
        stack.enter_context(patch.object(metadata_reader, "load_acore_sql_table", keyed))
        stack.enter_context(patch.object(metadata_reader, "load_acore_conditions", lambda root: copy.deepcopy(rows("conditions"))))
        derived = metadata_reader.derive_acore_metadata(source, spell_sql=spell_sql, spell_table=spell_table)
        module_ids = metadata_reader.load_module_created_quest_ids(source)
        disabled_ids = {int(row["entry"]) for row in rows("disables") if int(row.get("sourceType") or 0) == 1}
        relations = build_relations(rows, module_ids, disabled_ids)
        templates = {int(row["ID"]): row for row in rows("quest_template")}
        eligible_templates = {key: row for key, row in templates.items() if key not in disabled_ids and key not in module_ids}
        if 6681 in eligible_templates and 17126 not in script_spell_items.get(21100, []):
            raise ValueError("Quest6681: spell21100 no longer creates item17126; review letter-distribution helpers")
        script_starters = script_quest_starters(rows, eligible_templates)
        faction_rewards = faction_reputation_rewards(derived, rows, disabled_ids | module_ids)
        spell_coverage["scriptItemSpells"] = {str(key): value for key, value in script_spell_items.items() if value}
        teams = starter_teams(relations, rows, script_starters)
        spell_coverage["missingSpellReferences"] = missing_spell_references(
            spell_coverage.get("missingRequestedSpellIds", []), rows("item_template"), list(templates.values()))
    quests = {}
    for quest_id, fields in sorted(derived.items()):
        row = {}
        for field in metadata_reader.FIELD_ORDER:
            value = fields[field]
            if field == "objectives":
                value = metadata_reader.raw_objectives_from_normalized(value)
            row["s:" + field] = typed(value)
        relation = relations.get(quest_id, relation_reader.empty_relation())
        for field, side in (("startedBy", "start"), ("finishedBy", "end")):
            row["s:" + field] = typed({i: sorted(relation[side][kind]) for i, kind in enumerate(("creature", "object", "item"), 1)
                                      if kind in relation[side] and relation[side][kind]})
        if quest_id in templates:
            row["s:zoneOrSort"] = int(templates[quest_id].get("QuestSortID") or 0)
        quests[str(quest_id)] = row
    if source_signature(source, spell_sql, spell_table) != signature:
        raise ValueError("Quest source inputs changed during extraction")
    unresolved_source_spells = [row["spellId"] for row in spell_coverage["missingSpellReferences"] if row["requiredSourceItemQuestIds"]]
    saved = {"signature": signature, "quests": quests, "tableCoverage": coverage,
             "diagnostics": {"skippedSqlMutations": skipped_statements, "missingRequiredSourceItemSpellIds": unresolved_source_spells},
             "disabledQuestIds": sorted(disabled_ids), "moduleQuestIds": sorted(module_ids), "spellCoverage": spell_coverage,
             "starterTeams": teams, "scriptQuestStarters": script_starters,
             "factionReputationRewards": faction_rewards}
    saved["modelSha256"] = model_digest(saved)
    shared.write_json(cache, saved)
    return saved


def empty_table(value):
    return isinstance(value, dict) and all(empty_table(v) for v in value.values())


def representation_only(field, actual, expected):
    kind = metadata_reader.FIELD_KIND.get(field)
    if field in {"startedBy", "finishedBy"} or kind not in ("int", "string", None):
        return (actual is shared.ABSENT or actual is False or empty_table(actual)) and empty_table(expected)
    if kind == "string":
        return actual is shared.ABSENT and expected == ""
    return actual is shared.ABSENT and type(expected) in (int, float) and expected == 0


def compare_fields(baseline, source, fields):
    reports = {}
    for field in fields:
        counts, differences = Counter(), []
        key = "s:" + field
        for quest_id, current in sorted(baseline.items()):
            if quest_id not in source:
                counts["missingSourceTemplate"] += 1
                continue
            raw = source[quest_id]
            actual, expected = current.get(key, shared.ABSENT), raw.get(key, shared.ABSENT)
            if field not in SOURCE_FIELDS or expected is shared.ABSENT:
                counts["unavailableInSource"] += 1
                if actual is shared.ABSENT:
                    continue
                status = "unavailableInSource"
            elif shared.same_value(actual, expected):
                counts["exactMatches"] += 1
                continue
            elif representation_only(field, actual, expected):
                counts["representationOnly"] += 1
                continue
            else:
                status = "valueDifferences"
                counts[status] += 1
            differences.append({"questId": quest_id, "name": raw.get("s:name"), "status": status,
                                "snapshotPresent": actual is not shared.ABSENT, "sourcePresent": expected is not shared.ABSENT,
                                "snapshot": None if actual is shared.ABSENT else actual,
                                "source": None if expected is shared.ABSENT else expected})
        reports[field] = {"counts": dict(counts), "differences": differences}
    return reports


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--acore-source", type=Path, default=Path("P:/AC/source"))
    parser.add_argument("--spell-sql", type=Path, required=True)
    parser.add_argument("--spell-table", default="spell")
    parser.add_argument("--source-cache", type=Path, default=Path("tools/reports/acore_quest_source_model.json"))
    parser.add_argument("--report", type=Path, default=Path("tools/reports/acore_quest_source_audit.json"))
    parser.add_argument("--refresh-source", action="store_true")
    args = parser.parse_args(argv)
    source, spell_sql = args.acore_source.resolve(), args.spell_sql.resolve()
    report, cache = (shared.local_output(ROOT, p) for p in (args.report, args.source_cache))
    if report == cache or args.snapshot.resolve() in (report, cache):
        raise ValueError("Report, cache and snapshot must use different paths")
    snapshot_sha = db_snapshot.file_hash(args.snapshot)
    print("Validating snapshot and quest contexts...", flush=True)
    baseline, fields, overrides, metadata = shared.read_static_records(args.snapshot, ROOT, "quest")
    if tuple(fields) != FIELDS:
        raise ValueError("Unexpected quest schema; review field coverage")
    signature = source_signature(source, spell_sql, args.spell_table)
    saved = load_source(source, spell_sql, args.spell_table, signature, cache, args.refresh_source)
    model = {int(key): row for key, row in saved["quests"].items()}
    data = {"snapshotSha256": snapshot_sha, "sourceInputs": signature,
            "counts": {"snapshotQuests": len(baseline), "sourceQuests": len(model), "schemaFields": len(fields),
                       "sourceFields": len(SOURCE_FIELDS), "unsupportedFields": len(set(fields) - SOURCE_FIELDS)},
            "unsupportedFields": [field for field in fields if field not in SOURCE_FIELDS],
            "fields": compare_fields(baseline, model, fields), "runtimeOverrides": overrides,
            "snapshotOnlyIds": sorted(set(baseline) - set(model)), "sourceOnlyIds": sorted(set(model) - set(baseline)),
            **{key: saved[key] for key in ("tableCoverage", "diagnostics", "disabledQuestIds", "moduleQuestIds", "spellCoverage")},
            "limitations": ["Audit only; source differences are not approved data changes.",
                            "Derived metadata uses existing quest rules with the shared SQL replay reader; skipped mutations are reported.",
                            "Questie display helpers, event triggers and custom availability fields require explicit compatibility coverage.",
                            "Raw starter/ender relations exclude disabled and module-created quests; manual script-specific relation overrides are not applied.",
                            "Race masks are raw quest metadata; NPC friendliness inference and protected legacy overrides are not applied.",
                            "Objectives contain SQL target IDs, not complete script-driven display targets or Questie helper metadata.",
                            "Spell export uses the existing metadata loader with numeric SQL spell overrides; arbitrary scripts and pending updates are outside the model."]}
    if source_signature(source, spell_sql, args.spell_table) != signature:
        raise ValueError("Quest source inputs changed during audit")
    if db_snapshot.file_hash(args.snapshot) != snapshot_sha or any(
            db_snapshot.file_hash(ROOT / name) != digest for name, digest in metadata["sources"].items()):
        raise ValueError("Snapshot or addon changed during audit")
    shared.write_json(report, data)
    summary = {key: data[key] for key in ("counts", "unsupportedFields", "tableCoverage", "spellCoverage")}
    summary["spellCoverage"] = {key: len(value) if isinstance(value, list) else value
                                for key, value in saved["spellCoverage"].items()}
    summary["fields"] = {field: row["counts"] for field, row in data["fields"].items()}
    summary["diagnostics"] = {key: len(value) for key, value in data["diagnostics"].items()}
    summary.update({"snapshotOnlyQuests": len(data["snapshotOnlyIds"]), "sourceOnlyQuests": len(data["sourceOnlyIds"]),
                    "disabledQuests": len(data["disabledQuestIds"]), "moduleQuests": len(data["moduleQuestIds"])})
    print(json.dumps(summary, indent=2))
    print(f"Report: {report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, EOFError, KeyError, TypeError) as exc:
        raise SystemExit(f"Quest source audit failed: {exc}")
