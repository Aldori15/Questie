"""Read AzerothCore gameobjects, their locations, and quest relations."""

import sys
from collections import defaultdict
from pathlib import Path


sys.dont_write_bytecode = True
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from acore_item_source_reader import (  # noqa: E402
    add_item_sources_from_loot,
    build_gameobject_loot_source_map,
    load_keyed_table,
    load_row_table,
)
from acore_npc_source_reader import (  # noqa: E402
    add_acore_spawn_visibility,
    find_map_difficulty_dbc,
    get_creature_entries,
    index_geometry_origins,
    index_partial_spawn_coverage,
    load_map_difficulty_masks,
    load_filtered_row_table,
    load_rows_from_sql_file,
    parse_zone_maps,
    resolve_coordinate_zone,
    source_zone_candidates,
    sort_coordinate_table,
)


FIELD_ORDER = [
    "name",
    "questStarts",
    "questEnds",
    "spawns",
    "zoneID",
    "factionID",
]


def load_rows_from_optional_sql_file(source_root, table_name, key_columns, include_modules=False, sql_path=None):
    if sql_path:
        return load_rows_from_sql_file(Path(sql_path), table_name, key_columns)
    return load_row_table(source_root, table_name, key_columns, include_modules)


def collect_item_object_source_ids(source_root, gameobject_template_rows, include_modules=False):
    reference_rows, skipped_reference = load_row_table(source_root, "reference_loot_template", ("Entry", "Item"), include_modules)
    gameobject_loot_rows, skipped_gameobject_loot = load_row_table(source_root, "gameobject_loot_template", ("Entry", "Item"), include_modules)

    reference_index = defaultdict(list)
    for row in reference_rows:
        reference_index[int(row["Entry"])].append(row)

    object_sources_by_item = add_item_sources_from_loot(
        gameobject_loot_rows,
        reference_index,
        build_gameobject_loot_source_map(gameobject_template_rows),
    )

    source_ids = set()
    for item_source_ids in object_sources_by_item.values():
        source_ids.update(item_source_ids)

    skipped_mutations = {
        "reference_loot_template:item_object_sources": skipped_reference,
        "gameobject_loot_template:item_object_sources": skipped_gameobject_loot,
    }
    return source_ids, skipped_mutations


def lantern_spell_binding(spell_rows, overrides):
    """Verify the child identity; destination targeting is guarded in C++."""
    spells = {int(row["ID"]): row for row in spell_rows}
    spells.update({int(row["ID"]): row for row in overrides})

    def effect(row, field):
        return int(row.get(field + "_1", row.get(field + "1", 0)) or 0)

    first, second = spells.get(44255, {}), spells.get(44231, {})
    if (effect(first, "Effect") == 32 and effect(first, "EffectTriggerSpell") == 44231
            and effect(second, "Effect") == 76 and effect(second, "EffectMiscValue") == 186887):
        return {44255: 186887}
    return {}


def build_acore_objects(
    source_root,
    include_modules=False,
    repo_root=None,
    gameobject_sql=None,
    map_difficulty_dbc=None,
    wdm_root=None,
    provenance=None,
    creature_sql=None,
    creature_multispawn_sql=None,
    spell_sql=None,
):
    source_root = Path(source_root)
    map_difficulty_dbc = find_map_difficulty_dbc(source_root, map_difficulty_dbc)
    map_difficulty_masks = load_map_difficulty_masks(map_difficulty_dbc)
    template_rows, skipped_template = load_keyed_table(source_root, "gameobject_template", "entry", include_modules)
    template_addon_rows, skipped_template_addon = load_keyed_table(source_root, "gameobject_template_addon", "entry", include_modules)
    gameobject_rows, skipped_gameobject = load_rows_from_optional_sql_file(
        source_root,
        "gameobject",
        ("guid",),
        include_modules,
        gameobject_sql,
    )
    starter_rows, skipped_starter = load_row_table(source_root, "gameobject_queststarter", ("id", "quest"), include_modules)
    event_starter_rows, skipped_event_starter = load_row_table(
        source_root,
        "game_event_gameobject_quest",
        ("eventEntry", "id", "quest"),
        include_modules,
    )
    ender_rows, skipped_ender = load_row_table(source_root, "gameobject_questender", ("id", "quest"), include_modules)
    item_object_source_ids, skipped_item_object_sources = collect_item_object_source_ids(
        source_root,
        template_rows,
        include_modules,
    )

    starts_by_entry = defaultdict(set)
    for row in starter_rows + event_starter_rows:
        entry = int(row.get("id") or 0)
        quest = int(row.get("quest") or 0)
        if entry and quest:
            starts_by_entry[entry].add(quest)

    ends_by_entry = defaultdict(set)
    for row in ender_rows:
        entry = int(row.get("id") or 0)
        quest = int(row.get("quest") or 0)
        if entry and quest:
            ends_by_entry[entry].add(quest)

    spawns_by_entry = defaultdict(lambda: defaultdict(list))
    spawn_origins = defaultdict(lambda: defaultdict(list))
    spawn_zone_counts = defaultdict(lambda: defaultdict(int))
    seen_spawn_entries = set()
    unmapped_spawn_entries = set()
    unmapped_spawn_guids = defaultdict(set)
    map_stats = defaultdict(int)
    zone_maps = parse_zone_maps(Path(repo_root or ".").resolve(), wdm_root)
    source_zones = defaultdict(lambda: defaultdict(set))

    for row in gameobject_rows:
        entry = int(row.get("id") or row.get("entry") or 0)
        if not entry:
            continue
        seen_spawn_entries.add(entry)
        for zone in source_zone_candidates(row, zone_maps):
            source_zones[entry][zone].add(f"gameobject:{int(row.get('guid') or 0)}")
        zone_id, point = resolve_coordinate_zone(row, zone_maps)
        if zone_id and point:
            visible_point = add_acore_spawn_visibility(point, row, map_difficulty_masks)
            spawns_by_entry[entry][zone_id].append(visible_point)
            guid = int(row.get("guid") or 0)
            if provenance is not None and guid:
                spawn_origins[entry][zone_id].append((visible_point, f"gameobject:{guid}"))
            spawn_zone_counts[entry][zone_id] += 1
        else:
            unmapped_spawn_entries.add(entry)
            unmapped_spawn_guids[entry].add(int(row.get("guid") or 0))
            map_stats["unmapped_spawns"] += 1

    acore_objects = {}
    for object_id, row in template_rows.items():
        object_id = int(object_id)
        obj = {"name": row.get("name") or ""}

        if object_id in unmapped_spawn_entries:
            pass
        elif spawns_by_entry.get(object_id):
            obj["spawns"] = sort_coordinate_table(
                spawns_by_entry[object_id],
                map_difficulty_masks,
            )
            obj["zoneID"] = max(spawn_zone_counts[object_id].items(), key=lambda item: (item[1], -item[0]))[0]
        elif object_id not in seen_spawn_entries:
            obj["spawns"] = {}
            obj["zoneID"] = 0

        obj["questStarts"] = sorted(starts_by_entry.get(object_id, set()))
        obj["questEnds"] = sorted(ends_by_entry.get(object_id, set()))

        addon = template_addon_rows.get(object_id)
        obj["factionID"] = int((addon or {}).get("faction") or 0)

        acore_objects[object_id] = obj

    if provenance is not None:
        provenance.update(index_geometry_origins(acore_objects, spawn_origins, {}, map_difficulty_masks))
        provenance["sourceZones"] = {"version": 1, "entries": {
            str(entry): {"zones": sorted(zones), "origins": {
                str(zone): sorted(origins) for zone, origins in sorted(zones.items())}}
            for entry, zones in sorted(source_zones.items())}, "failures": []}
        index_partial_spawn_coverage(provenance, spawns_by_entry, spawn_origins,
                                     unmapped_spawn_guids, map_difficulty_masks)

    scripted_skips = {}
    if creature_multispawn_sql is not None and creature_sql is None:
        raise ValueError("Object summon context requires --creature-sql with --creature-multispawn-sql")
    scripted_geometry = {"version": 1, "entries": {}}
    actors_by_entry = defaultdict(list)
    actor_templates = {}
    spell_bindings = {}
    if spell_sql is not None:
        spell_rows, spell_skips = load_rows_from_sql_file(
            Path(spell_sql), "spell", ("ID",), row_filter=lambda row: int(row.get("ID") or 0) in (44255, 44231))
        overrides, override_skips = load_filtered_row_table(
            source_root, "spell_dbc", ("ID",), lambda row: int(row.get("ID") or 0) in (44255, 44231), include_modules)
        if not spell_skips and not override_skips:
            spell_bindings = lantern_spell_binding(spell_rows, overrides)
        scripted_skips.update({"spell": spell_skips, "spell_dbc": override_skips})
    if creature_sql is not None:
        import acore_scripted_geometry

        actor_templates, skipped_actor_templates = load_keyed_table(
            source_root, "creature_template", "entry", include_modules)
        smart_rows, skipped_smart = load_filtered_row_table(
            source_root, "smart_scripts", ("entryorguid", "source_type", "id", "link"),
            lambda row: True, include_modules)
        creature_rows, skipped_creatures = load_rows_from_sql_file(
            Path(creature_sql), "creature", ("guid",))
        multispawn_rows, skipped_multispawns = (load_rows_from_sql_file(
            Path(creature_multispawn_sql), "creature_multispawn", ("spawnId", "entry"))
            if creature_multispawn_sql is not None else ([], 0))
        multispawns = defaultdict(set)
        for row in multispawn_rows:
            multispawns[int(row.get("spawnId") or 0)].add(int(row.get("entry") or 0))
        actors_by_entry = defaultdict(list)
        actors_by_guid = {}
        for row in creature_rows:
            actors_by_guid[int(row.get("guid") or 0)] = row
            for entry in get_creature_entries(row, multispawns):
                actors_by_entry[entry].append(row)
        scripted_geometry = acore_scripted_geometry.collect(
            smart_rows, actors_by_entry, actors_by_guid, actor_templates, zone_maps, {},
            object_templates=template_rows, summon_action=50)
        scripted_skips.update({"creature_template": skipped_actor_templates, "smart_scripts": skipped_smart,
                              "creature": skipped_creatures, "creature_multispawn": skipped_multispawns})
    if provenance is not None:
        scripted_geometry["actorContextAvailable"] = creature_sql is not None
        provenance["scriptedGeometry"] = scripted_geometry
        import acore_cpp_geometry
        provenance["cppGeometry"] = acore_cpp_geometry.collect_objects(
            source_root, zone_maps, actor_spawns=actors_by_entry, actor_templates=actor_templates,
            spell_object_bindings=spell_bindings)
        for identifier, bindings in acore_cpp_geometry.OBJECT_TEMPLATE_BINDINGS.items():
            if creature_sql is None or any(actor_templates.get(actor, {}).get("ScriptName") != script
                                            for actor, script in bindings.items()):
                data = provenance["cppGeometry"]["entries"][str(identifier)]
                data["failures"]["spawns"].append({"source": "creature_template",
                    "reasons": ["C++ object actor context or script binding is unavailable; refresh using creature exports"]})

    skipped_mutations = {
        "gameobject_template": skipped_template,
        "gameobject_template_addon": skipped_template_addon,
        "gameobject": skipped_gameobject,
        "gameobject_queststarter": skipped_starter,
        "game_event_gameobject_quest": skipped_event_starter,
        "gameobject_questender": skipped_ender,
        **skipped_item_object_sources,
        **scripted_skips,
        **{f"mapping:{key}": value for key, value in map_stats.items()},
    }
    return acore_objects, skipped_mutations, item_object_source_ids
