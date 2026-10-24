"""Bounded generation evidence for two explicitly understood AC C++ placements.

This is not a general C++ interpreter. Changed ownership or movement constructs
produce review failures instead of retaining coordinates from an earlier source.
"""
import math
import re
from pathlib import Path


HOR = "src/server/scripts/Northrend/FrozenHalls/HallsOfReflection/"
AV = "src/server/game/Battlegrounds/Zones/"
CULLING = "src/server/scripts/Kalimdor/CavernsOfTime/CullingOfStratholme/"
ULDUAR = "src/server/scripts/Northrend/Ulduar/Ulduar/"
EYE = "src/server/scripts/Northrend/Nexus/EyeOfEternity/"
ZULDRAK = "src/server/scripts/Northrend/zone_zuldrak.cpp"
HALLOWS = "src/server/scripts/Events/hallows_end.cpp"
SPELL_FIXES = "src/server/game/Spells/SpellInfoCorrections.cpp"
SOURCE_FILES = (HOR + "halls_of_reflection.h", HOR + "halls_of_reflection.cpp",
                HOR + "instance_halls_of_reflection.cpp", AV + "BattlegroundAV.h",
                AV + "BattlegroundAV.cpp", "src/server/game/Maps/AreaDefines.h")
OBJECT_SOURCE_FILES = (CULLING + "culling_of_stratholme.h", CULLING + "boss_mal_ganis.cpp",
                       ULDUAR + "ulduar.h", ULDUAR + "boss_thorim.cpp", ULDUAR + "boss_mimiron.cpp",
                       EYE + "eye_of_eternity.h", EYE + "boss_malygos.cpp", ZULDRAK, SOURCE_FILES[-1],
                       "src/server/game/AI/ScriptedAI/ScriptedCreature.h", "src/server/game/Entities/Object/Object.cpp",
                       AV + "BattlegroundAV.h", AV + "BattlegroundAV.cpp", HALLOWS, SPELL_FIXES)
NPC_TEMPLATE_BINDINGS = {36955: {37554: "npc_hor_leader_second"}}
OBJECT_TEMPLATE_BINDINGS = {
    193597: {26533: "boss_mal_ganis"},
    194313: {32865: "boss_thorim"}, 194314: {32865: "boss_thorim"},
    194957: {33350: "boss_mimiron"}, 194958: {33350: "boss_mimiron"},
    194158: {28859: "boss_malygos"}, 194159: {28859: "boss_malygos"},
    202357: {28998: "npc_overlord_drakuru_betrayal"},
    186887: {23543: "npc_hallows_end_soh"},
}
OBJECT_SPELL_BINDINGS = {186887: 44255}
NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?[fF]?"


def _clean(text):
    return re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)


def _compact(text):
    return re.sub(r"\s+", "", _clean(text))


def _require(text, fragment):
    if _compact(fragment) not in _compact(text):
        raise ValueError("unsupported C++ ownership or movement: " + fragment)


def _integer(text, name):
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*(\d+)\s*[,;]", _clean(text))
    if not match:
        raise ValueError("missing numeric source identity: " + name)
    return int(match[1])


def _body(text, name):
    match = re.search(r"\b" + re.escape(name) + r"(?:\s*\[[^]]*\])*\s*=\s*\{", _clean(text))
    if not match:
        raise ValueError("missing C++ geometry array: " + name)
    text, start, depth = _clean(text), match.end(), 1
    for index in range(start, len(text)):
        depth += (text[index] == "{") - (text[index] == "}")
        if depth == 0:
            return text[start:index]
    raise ValueError("unterminated C++ geometry array: " + name)


def _numbers(body):
    parts = [part.strip() for part in body.split(",") if part.strip()]
    if not parts or any(not re.fullmatch(NUMBER, part) for part in parts):
        raise ValueError("unsupported numeric C++ geometry expression")
    values = [float(part.rstrip("fF")) for part in parts]
    if any(not math.isfinite(value) for value in values):
        raise ValueError("non-finite C++ geometry position")
    return values


def _rows(text, name, width):
    body = _body(text, name)
    matches = list(re.finditer(r"\{([^{}]+)\}", body))
    if re.sub(r"[\s,]", "", re.sub(r"\{[^{}]+\}", "", body)):
        raise ValueError("unsupported C++ geometry array contents: " + name)
    rows = [_numbers(match[1]) for match in matches]
    if not rows or any(len(row) != width for row in rows):
        raise ValueError("unexpected C++ geometry row width: " + name)
    return rows


def _function(text, name):
    text = _clean(text)
    match = re.search(r"\bvoid\s+" + re.escape(name) + r"\([^)]*\)\s*(?:override\s*)?\{", text)
    if not match:
        raise ValueError("missing C++ function: " + name)
    start, depth = match.end(), 1
    for index in range(start, len(text)):
        depth += (text[index] == "{") - (text[index] == "}")
        if not depth:
            return text[start:index]
    raise ValueError("unterminated C++ function: " + name)


def collect_source_zones(source_root):
    """Keep AV's proven instance zones even without projected map markers."""
    root = Path(source_root)
    packet = {"version": 1, "entries": {}, "failures": []}
    try:
        header = (root / (AV + "BattlegroundAV.h")).read_text(encoding="utf-8")
        script = (root / (AV + "BattlegroundAV.cpp")).read_text(encoding="utf-8")
        areas = (root / SOURCE_FILES[-1]).read_text(encoding="utf-8")
        map_id = _integer(areas, "MAP_ALTERAC_VALLEY")
        zone = _integer(areas, "AREA_ALTERAC_VALLEY")
        if (map_id, zone) != (30, 2597):
            raise ValueError("Alterac Valley map or area identity changed")
        _require(script, "Creature* BattlegroundAV::AddAVCreature(uint16 cinfoid, uint16 type)")
        _require(script, """if (type >= AV_CPLACE_MAX) {
            type -= AV_CPLACE_MAX;
            cinfoid = uint16(BG_AV_StaticCreaturePos[type][4]);
            creature = AddCreature(BG_AV_StaticCreatureInfo[cinfoid],
                type + AV_CPLACE_MAX, BG_AV_StaticCreaturePos[type][0],
                BG_AV_StaticCreaturePos[type][1], BG_AV_StaticCreaturePos[type][2],
                BG_AV_StaticCreaturePos[type][3]);
            isStatic = true;
        }""")
        _require(script, "for (i = 0; i < AV_STATICCPLACE_MAX; i++) AddAVCreature(0, i + AV_CPLACE_MAX);")
        infos = _numbers(_body(header, "BG_AV_StaticCreatureInfo"))
        rows = _rows(header, "BG_AV_StaticCreaturePos", 5)
        declared = re.search(r"\bBG_AV_StaticCreatureInfo\s*\[\s*(\d+)\s*\]", _clean(header))
        if not declared or len(infos) != int(declared[1]) or len(rows) != _integer(header, "AV_STATICCPLACE_MAX"):
            raise ValueError("AV static creature array counts changed incompatibly")
        if any(entry != int(entry) or entry < 1 for entry in infos):
            raise ValueError("AV static creature template identity is invalid")
        entries = {}
        for index, row in enumerate(rows):
            entry_index = int(row[4])
            if row[4] != entry_index or not 0 <= entry_index < len(infos):
                raise ValueError("AV static creature position index is invalid")
            entry = str(int(infos[entry_index]))
            data = entries.setdefault(entry, {"zones": [zone], "origins": {str(zone): []}})
            data["origins"][str(zone)].append(
                f"cpp-zone:av:map:{map_id}:BG_AV_StaticCreaturePos:{index}:info:{entry_index}")
        packet["entries"] = entries
    except (OSError, ValueError) as error:
        packet["failures"].append({"source": "cpp-zone:av", "reasons": [str(error)]})
    return packet


def collect(source_root, zone_maps):
    import generate_acore_npc_corrections as reader
    from acore_scripted_geometry import typed

    source_root = Path(source_root)
    entries = {}

    def packet_entry(entry, function):
        data = {"spawns": {}, "waypoints": {}, "origins": {"spawns": {}, "waypoints": {}},
                "failures": {"spawns": [], "waypoints": []}}
        entries[str(entry)] = data
        try:
            function(data)
        except (OSError, ValueError) as error:
            # A structural failure invalidates both fields. No stale fallback.
            for field in ("spawns", "waypoints"):
                data[field] = {}
                data["origins"][field] = {}
                data["failures"][field].append({"source": "cpp-geometry:" + str(entry),
                                               "reasons": [str(error)]})

    def read(relative):
        return (source_root / relative).read_text(encoding="utf-8")

    def project(xyz, map_id, zone):
        row = dict(map=map_id, zoneId=zone, position_x=xyz[0], position_y=xyz[1], position_z=xyz[2])
        actual, point = reader.resolve_coordinate_zone(row, zone_maps)
        if actual != zone or not point:
            raise ValueError(f"C++ position does not map to reviewed zone {zone}")
        return point

    def put(data, field, zone, values, identities):
        data[field] = typed({zone: values})
        data["origins"][field] = {f"n:{zone}": {f"n:{i}": [identity]
                                                   for i, identity in enumerate(identities, 1)}}

    def jaina(data):
        header, script, instance = (read(HOR + name) for name in
                                   ("halls_of_reflection.h", "halls_of_reflection.cpp", "instance_halls_of_reflection.cpp"))
        areas = read(SOURCE_FILES[-1])
        if _integer(header, "NPC_JAINA_PART2") != 36955 or _integer(header, "NPC_SYLVANAS_PART2") != 37554:
            raise ValueError("HoR leader entry identity changed")
        map_id, zone = _integer(areas, "MAP_HALLS_OF_REFLECTION"), _integer(areas, "AREA_HALLS_OF_REFLECTION")
        _require(instance, "RegisterInstanceScript(instance_halls_of_reflection, MAP_HALLS_OF_REFLECTION);")
        _require(instance, "case NPC_SYLVANAS_PART2:")
        _require(instance, "if (GetTeamIdInInstance() == TEAM_ALLIANCE) creature->UpdateEntry(NPC_JAINA_PART2);")
        _require(instance, "creature->UpdatePosition(LeaderEscapePos, true);")
        _require(instance, "else if (GetBossState(DATA_LICH_KING) != DONE)")
        _require(instance, "else { creature->UpdatePosition(PathWaypoints[PATH_WP_COUNT - 1], true); creature->StopMovingOnCurrentPos(); }")
        _require(script, 'npc_hor_leader_second() : CreatureScript("npc_hor_leader_second")')
        _require(script, "return GetHallsOfReflectionAI<npc_hor_leader_secondAI>(creature);")
        _require(script, "for (uint8 i = WP_STOP[currentStopPoint - 1] + (currentStopPoint == 1 ? 0 : 1); i <= WP_STOP[currentStopPoint]; ++i) path.emplace_back(PathWaypoints[i].GetPositionX(), PathWaypoints[i].GetPositionY(), PathWaypoints[i].GetPositionZ());")
        _require(script, "me->GetMotionMaster()->MoveSplinePath(&path, FORCED_MOVEMENT_RUN);")
        rows = _rows(header, "PathWaypoints", 4)
        count = re.search(r"#define\s+PATH_WP_COUNT\s+(\d+)\b", header)
        stops = _numbers(_body(header, "WP_STOP"))
        if not count or len(rows) != int(count[1]) or stops != sorted(set(stops)) or stops[0] != 0 or stops[-1] != len(rows) - 1:
            raise ValueError("HoR route count or stop indexes changed incompatibly")
        escape = _numbers(_body(header, "LeaderEscapePos"))
        if len(escape) != 4:
            raise ValueError("HoR escape position has unexpected width")
        # Both are possible event-state positions; this is not a claim that both
        # copies exist at once or that the addon knows the current boss state.
        put(data, "spawns", zone, [project(escape, map_id, zone), project(rows[-1], map_id, zone)],
            ["cpp-position:hor:LeaderEscapePos:entry:36955", "cpp-position:hor:PathWaypoints:last:entry:36955"])
        put(data, "waypoints", zone, [[project(row, map_id, zone) for row in rows]], ["cpp-path:hor:PathWaypoints:entry:36955"])

    def legionnaire(data):
        header, script, areas = read(AV + "BattlegroundAV.h"), read(AV + "BattlegroundAV.cpp"), read(SOURCE_FILES[-1])
        _require(script, "cinfoid = uint16(BG_AV_StaticCreaturePos[type][4]);")
        _require(script, "creature = AddCreature(BG_AV_StaticCreatureInfo[cinfoid], type + AV_CPLACE_MAX, BG_AV_StaticCreaturePos[type][0], BG_AV_StaticCreaturePos[type][1], BG_AV_StaticCreaturePos[type][2], BG_AV_StaticCreaturePos[type][3]);")
        _require(script, "for (i = 0; i < AV_STATICCPLACE_MAX; i++) AddAVCreature(0, i + AV_CPLACE_MAX);")
        infos = _numbers(_body(header, "BG_AV_StaticCreatureInfo"))
        rows = _rows(header, "BG_AV_StaticCreaturePos", 5)
        map_id, zone = _integer(areas, "MAP_ALTERAC_VALLEY"), _integer(areas, "AREA_ALTERAC_VALLEY")
        positions, origins = [], []
        for index, row in enumerate(rows):
            entry_index = int(row[4])
            if entry_index != row[4] or not 0 <= entry_index < len(infos):
                raise ValueError("AV static position entry index is invalid")
            if infos[entry_index] == 12051:
                positions.append(project(row, map_id, zone))
                origins.append(f"cpp-position:av:BG_AV_StaticCreaturePos:{index}:entry:12051")
        if not positions:
            raise ValueError("AV Legionnaire static placements removed; review source")
        put(data, "spawns", zone, positions, origins)

    packet_entry(36955, jaina)
    packet_entry(12051, legionnaire)
    return {"version": 1, "entries": entries}


def collect_objects(source_root, zone_maps, actor_spawns=None, actor_templates=None, spell_object_bindings=None):
    """Fixed boss-reward chest positions; mode expressions bind actual entries."""
    import generate_acore_npc_corrections as reader
    from acore_scripted_geometry import typed

    source_root = Path(source_root)
    entries = {}
    packet_failures = []

    def read(relative):
        return (source_root / relative).read_text(encoding="utf-8")

    def literal_summon(text, expression):
        pattern = r"SummonGameObject\(" + re.escape(_compact(expression)) + ","
        pattern += ",".join("(" + NUMBER + ")" for _ in range(3)) + ","
        matches = re.findall(pattern, _compact(text))
        if len(matches) != 1:
            raise ValueError("missing or ambiguous fixed chest SummonGameObject call")
        return [float(value.rstrip("fF")) for value in matches[0]]

    def add(entry, map_name, xyz, identity, zone_name=None, spawn_mask=None, phase_region=None):
        areas = read(SOURCE_FILES[-1])
        map_id = _integer(areas, map_name)
        zone = _integer(areas, zone_name) if zone_name else zone_maps.get("instance_to_zone", {}).get(map_id)
        if not zone:
            raise ValueError("chest instance lacks client map context")
        actual, point = reader.resolve_coordinate_zone(dict(map=map_id, zoneId=zone,
            position_x=xyz[0], position_y=xyz[1], position_z=xyz[2]), zone_maps)
        ui = reader.zone_to_ui(actual, zone_maps) if actual else None
        valid_zone = actual == zone if zone_name else ui in zone_maps.get("ui_by_instance", {}).get(map_id, ())
        if not point or not valid_zone:
            raise ValueError("fixed chest position does not map to its reviewed instance/floor")
        if spawn_mask is not None:
            # These are distinct AC difficulty variants, including when the
            # offline map display cannot know the eventual instance mode.
            point = [point[0], point[1], 0, spawn_mask, map_id]
        if phase_region is not None:
            phase, region = phase_region
            point = [point[0], point[1], 0, spawn_mask or 1, map_id, phase, region]
        return {"spawns": typed({actual: [point]}), "waypoints": {},
                "origins": {"spawns": {f"n:{actual}": {"n:1": [identity]}}, "waypoints": {}},
                "failures": {"spawns": [], "waypoints": []}}

    def group(ids, function):
        try:
            result = function()
            for entry in ids:
                entries[str(entry)] = result[entry]
        except (OSError, ValueError) as error:
            for entry in ids:
                failure = {"source": f"cpp-object:{entry}", "reasons": [str(error)]}
                entries[str(entry)] = {"spawns": {}, "waypoints": {}, "origins": {},
                    "failures": {"spawns": [failure], "waypoints": [failure]}}

    def ordinary_actor(entry, map_id):
        rows = (actor_spawns or {}).get(entry, ())
        if not rows or any(row.get("map") != map_id or row.get("phaseMask") != 1 for row in rows):
            raise ValueError(f"C++ summoned object actor {entry} lacks ordinary-phase map evidence")
        # The summon inherits phase, not the actor's area. An unverified child
        # area stays zero so the bridge cannot apply a fabricated area filter.
        return 1, 0

    def mode_semantics(raid=False):
        core = read("src/server/game/AI/ScriptedAI/ScriptedCreature.h")
        if raid:
            _require(core, "case RAID_DIFFICULTY_10MAN_NORMAL: return normal10;")
            _require(core, "case RAID_DIFFICULTY_25MAN_NORMAL: return normal25;")
        else:
            _require(core, "case DUNGEON_DIFFICULTY_NORMAL: return normal5;")
            _require(core, "case DUNGEON_DIFFICULTY_HEROIC: return heroic10;")

    def inherited_phase_semantics():
        _require(read("src/server/game/Entities/Object/Object.cpp"),
                 "go->Create(map->GenerateLowGuid<HighGuid::GameObject>(), entry, map, GetPhaseMask(),")

    def malganis():
        header, script = read(CULLING + "culling_of_stratholme.h"), read(CULLING + "boss_mal_ganis.cpp")
        if _integer(header, "GO_MALGANIS_CHEST_H") != 193597 or _integer(header, "GO_MALGANIS_CHEST_N") != 190663:
            raise ValueError("Malganis chest mode identities changed")
        xyz = literal_summon(script, "DUNGEON_MODE(GO_MALGANIS_CHEST_N, GO_MALGANIS_CHEST_H)")
        mode_semantics()
        _require(read("src/server/game/Entities/Object/Object.cpp"), "entry, this, PHASEMASK_NORMAL,")
        return {193597: add(193597, "MAP_THE_CULLING_OF_STRATHOLME", xyz, "cpp-object:malganis:GO_MALGANIS_CHEST_H", spawn_mask=2)}

    def thorim():
        header, script = read(ULDUAR + "ulduar.h"), read(ULDUAR + "boss_thorim.cpp")
        if _integer(header, "GO_THORIM_CHEST") != 194312 or _integer(header, "GO_THORIM_CHEST_HERO") != 194314:
            raise ValueError("Thorim chest mode identities changed")
        _require(script, "uint32 chestId = me->GetMap()->Is25ManRaid() ? GO_THORIM_CHEST_HERO : GO_THORIM_CHEST;")
        _require(script, "if (_hardMode) chestId += 1;")
        xyz = literal_summon(script, "chestId")
        _require(read("src/server/game/Entities/Object/Object.cpp"), "entry, this, PHASEMASK_NORMAL,")
        return {entry: add(entry, "MAP_ULDUAR", xyz, f"cpp-object:thorim:chestId:{entry}", spawn_mask=mask)
                for entry, mask in ((194313, 1), (194314, 2))}

    def mimiron():
        header, script = read(ULDUAR + "ulduar.h"), read(ULDUAR + "boss_mimiron.cpp")
        for name, entry in (("GO_MIMIRON_CHEST", 194789), ("GO_MIMIRON_CHEST_HARD", 194957),
                            ("GO_MIMIRON_CHEST_HERO", 194956), ("GO_MIMIRON_CHEST_HERO_HARD", 194958)):
            if _integer(header, name) != entry:
                raise ValueError("Mimiron chest mode identities changed")
        _require(script, "uint32 chestId = (_hardmode ? RAID_MODE(GO_MIMIRON_CHEST_HARD, GO_MIMIRON_CHEST_HERO_HARD) : RAID_MODE(GO_MIMIRON_CHEST, GO_MIMIRON_CHEST_HERO))")
        xyz = literal_summon(script, "chestId")
        mode_semantics(raid=True)
        _require(read("src/server/game/Entities/Object/Object.cpp"), "entry, this, PHASEMASK_NORMAL,")
        return {entry: add(entry, "MAP_ULDUAR", xyz, f"cpp-object:mimiron:chestId:{entry}", spawn_mask=mask)
                for entry, mask in ((194957, 1), (194958, 2))}

    def magic():
        header, script = read(EYE + "eye_of_eternity.h"), read(EYE + "boss_malygos.cpp")
        _require(header, "#define HEART_OF_MAGIC DUNGEON_MODE(194158, 194159)")
        _require(script, "me->SummonGameObject(HEART_OF_MAGIC, HeartOfMagicPos.GetPositionX(), HeartOfMagicPos.GetPositionY(), HeartOfMagicPos.GetPositionZ(),")
        xyz = _numbers(_body(header, "HeartOfMagicPos"))
        if len(xyz) != 4:
            raise ValueError("Heart of Magic position has unexpected width")
        mode_semantics()
        inherited_phase_semantics()
        ordinary_actor(28859, 616)
        if "SetPhaseMask(" in _compact(script):
            raise ValueError("Heart of Magic actor has an unsupported phase mutation")
        return {entry: add(entry, "MAP_THE_EYE_OF_ETERNITY", xyz, f"cpp-object:malygos:HeartOfMagicPos:{entry}", spawn_mask=mask)
                for entry, mask in ((194158, 1), (194159, 2))}

    def drakuru():
        script = read(ZULDRAK)
        if _integer(script, "GO_DRAKURUS_LAST_WISH") != 202357:
            raise ValueError("Drakuru object identity changed")
        _require(script, "struct npc_overlord_drakuru_betrayal : public ScriptedAI")
        _require(script, "RegisterCreatureAI(npc_overlord_drakuru_betrayal);")
        xyz = literal_summon(script, "GO_DRAKURUS_LAST_WISH")
        phase_region = ordinary_actor(28998, 571)
        inherited_phase_semantics()
        if "SetPhaseMask(" in _compact(script):
            raise ValueError("Drakuru actor has an unsupported phase mutation")
        return {202357: add(202357, "MAP_NORTHREND", xyz, "cpp-object:drakuru:GO_DRAKURUS_LAST_WISH", "AREA_ZUL_DRAK", phase_region=phase_region)}

    def av_objects():
        header, script = read(AV + "BattlegroundAV.h"), read(AV + "BattlegroundAV.cpp")
        result = {}

        def put_many(entry, positions, identities):
            merged = {"spawns": {}, "waypoints": {}, "origins": {"spawns": {}, "waypoints": {}},
                      "failures": {"spawns": [], "waypoints": []}}
            for xyz, identity in zip(positions, identities):
                data = add(entry, "MAP_ALTERAC_VALLEY", xyz, identity, "AREA_ALTERAC_VALLEY", spawn_mask=1)
                for zone, units in data["spawns"].items():
                    target = merged["spawns"].setdefault(zone, {})
                    origin = merged["origins"]["spawns"].setdefault(zone, {})
                    for key, value in units.items():
                        new_key = f"n:{len(target) + 1}"
                        target[new_key] = value
                        origin[new_key] = data["origins"]["spawns"][zone][key]
            result[entry] = merged

        rows = _rows(header, "BG_AV_ObjectPos", 4)
        for side, expected in (("N", 178785), ("S", 178784)):
            if _integer(header, "BG_AV_OBJECTID_MINE_" + side) != expected:
                raise ValueError("AV mine object identity changed")
            low = _integer(header, f"AV_OPLACE_MINE_SUPPLY_{side}_MIN")
            high = _integer(header, f"AV_OPLACE_MINE_SUPPLY_{side}_MAX")
            first = _integer(header, f"BG_AV_OBJECT_MINE_SUPPLY_{side}_MIN")
            last = _integer(header, f"BG_AV_OBJECT_MINE_SUPPLY_{side}_MAX")
            if high - low != last - first or not 0 <= low <= high < len(rows):
                raise ValueError("AV mine object position range changed incompatibly")
            _require(script, f"for (uint16 i = 0; i <= (BG_AV_OBJECT_MINE_SUPPLY_{side}_MAX - BG_AV_OBJECT_MINE_SUPPLY_{side}_MIN); i++)")
            _require(script, f"AddObject(BG_AV_OBJECT_MINE_SUPPLY_{side}_MIN + i, BG_AV_OBJECTID_MINE_{side}, BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][0], BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][1], BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][2], BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][3],")
            put_many(expected, rows[low:high + 1], [f"cpp-object:av:BG_AV_ObjectPos:{i}:entry:{expected}" for i in range(low, high + 1)])

        _require(script, "for (uint16 i = 0; i <= (BG_AV_OBJECT_GENERIC_MAX - BG_AV_OBJECT_GENERIC_MIN); i++)")
        _require(script, "AddObject(BG_AV_OBJECT_GENERIC_MIN + i, std::get<0>(BG_AV_GenericObjectPos[i]), std::get<1>(BG_AV_GenericObjectPos[i]).GetPositionX(), std::get<1>(BG_AV_GenericObjectPos[i]).GetPositionY(), std::get<1>(BG_AV_GenericObjectPos[i]).GetPositionZ(),")
        body = _body(header, "BG_AV_GenericObjectPos")
        pattern = r"\{\s*(\d+)\s*,\s*\{([^{}]+)\}\s*,\s*\{([^{}]+)\}\s*\}"
        matches = list(re.finditer(pattern, body))
        if re.sub(r"[\s,]", "", re.sub(pattern, "", body)):
            raise ValueError("unsupported AV generic object position contents")
        if len(matches) != _integer(header, "BG_AV_OBJECT_GENERIC_MAX") - _integer(header, "BG_AV_OBJECT_GENERIC_MIN") + 1:
            raise ValueError("AV generic object count changed incompatibly")
        selected = {}
        for index, match in enumerate(matches):
            xyz, rotation = _numbers(match[2]), _numbers(match[3])
            if len(xyz) != 4 or len(rotation) != 4:
                raise ValueError("AV generic object position or rotation has unexpected width")
            selected.setdefault(int(match[1]), []).append((index, xyz))
        for entry, values in selected.items():
            put_many(entry, [xyz for _, xyz in values], [f"cpp-object:av:BG_AV_GenericObjectPos:{i}:entry:{entry}" for i, _ in values])
        return result

    def lantern():
        script, areas = read(HALLOWS), read(SOURCE_FILES[-1])
        if _integer(script, "SPELL_SUMMON_LANTERN") != 44255 or _integer(script, "NPC_SHADE_OF_HORSEMAN") != 23543:
            raise ValueError("Hallows End lantern spell or shade identity changed")
        if (spell_object_bindings or {}).get(44255) != 186887:
            raise ValueError("Lantern spell lacks verified fixed-destination gameobject binding")
        # Runtime spell corrections override the exported DBC target fields.
        # Both stages must retain the explicit landing destination; the original
        # missile target alone is not proof of the actual server placement.
        _require(read(SPELL_FIXES), """
            ApplySpellFix({ 44255, 44231 }, [](SpellInfo* spellInfo) {
                spellInfo->Effects[EFFECT_0].TargetA = SpellImplicitTargetInfo(TARGET_DEST_DEST);
                spellInfo->Effects[EFFECT_0].TargetB = SpellImplicitTargetInfo();
            });
        """)
        _require(script, "struct npc_hallows_end_soh : public ScriptedAI")
        _require(script, "RegisterCreatureAI(npc_hallows_end_soh);")
        _require(script, "RegisterCreatureAI(npc_costumed_orphan_matron);")
        _require(script, "GetInitXYZ(x, y, z, o, path);")
        _require(script, "me->SummonCreature(NPC_SHADE_OF_HORSEMAN, x, y, z, o, TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000)")
        _require(script, "cr->AI()->DoAction(path);")
        _require(script, "void DoAction(int32 param) override { pos = param; }")
        died = _function(script, "JustDied")
        _require(died, "GetPosToLand(x, y, z); me->CastSpell(x, y, z, SPELL_SUMMON_LANTERN, true);")
        init, land = _function(script, "GetInitXYZ"), _function(script, "GetPosToLand")
        _require(init, "switch (me->GetAreaId())")
        _require(land, "switch (pos)")
        init_cases = re.findall(r"case\s+(AREA_\w+)\s*:(.*?)break\s*;", init, flags=re.S)
        land_cases = re.findall(r"case\s+(\d+)\s*:(.*?)break\s*;", land, flags=re.S)
        if len(init_cases) != 6 or len(land_cases) != 6:
            raise ValueError("Hallows End landing context count changed; review supported sites")
        paths = {}
        for area, body in init_cases:
            path = re.search(r"\bpath\s*=\s*(\d+)\s*;", body)
            if not path or int(path[1]) in paths:
                raise ValueError("ambiguous Hallows End landing path context")
            paths[int(path[1])] = _integer(areas, area)
        default = land.split("default:", 1)
        if len(default) != 2:
            raise ValueError("Hallows End unknown path behavior changed")
        _require(default[1], "x = 0; y = 0; z = 0; break;")
        matrons = {entry for entry, template in (actor_templates or {}).items()
                   if template.get("ScriptName") == "npc_costumed_orphan_matron"}
        if not matrons:
            raise ValueError("Lantern lacks static matron actor template context")
        data = {"spawns": {}, "waypoints": {}, "origins": {"spawns": {}, "waypoints": {}},
                "failures": {"spawns": [], "waypoints": []}}
        seen_paths = set()
        for path_text, body in land_cases:
            path = int(path_text)
            if path not in paths or path in seen_paths:
                raise ValueError("Hallows End landing path does not match matron context")
            seen_paths.add(path)
            context = [row for entry in matrons for row in (actor_spawns or {}).get(entry, ())
                       if row.get("areaId") == paths[path]]
            contexts = {(row.get("map"), row.get("zoneId"), row.get("phaseMask")) for row in context}
            if len(contexts) != 1:
                raise ValueError("Lantern landing map/zone/phase context is unavailable or ambiguous")
            map_id, zone, phase = next(iter(contexts))
            if map_id is None or not zone or phase != 1:
                raise ValueError("Lantern landing map or ordinary phase is unsupported")
            if any("SetPhaseMask(" in _compact(text) for text in (script,)):
                raise ValueError("Lantern actor has an unsupported phase mutation")
            match = re.fullmatch(";".join(axis + "=(" + NUMBER + ")" for axis in "xyz") + ";", _compact(body))
            if not match:
                raise ValueError("unsupported Hallows End landing coordinate expression")
            xyz = [float(value.rstrip("fF")) for value in match.groups()]
            actual, point = reader.resolve_coordinate_zone(dict(map=map_id, zoneId=zone,
                position_x=xyz[0], position_y=xyz[1], position_z=xyz[2]), zone_maps)
            if actual != zone or not point:
                raise ValueError("Lantern landing position does not map to its source context")
            key = f"n:{len(data['spawns'].setdefault(f'n:{actual}', {})) + 1}"
            data["spawns"][f"n:{actual}"][key] = typed([point[0], point[1], 0, 1, map_id, 1, 0])
            data["origins"]["spawns"].setdefault(f"n:{actual}", {})[key] = [f"cpp-object:hallows:GetPosToLand:{path}:map:{map_id}"]
        return {186887: data}

    group((193597,), malganis)
    group((194313, 194314), thorim)
    group((194957, 194958), mimiron)
    group((194158, 194159), magic)
    group((202357,), drakuru)
    group((186887,), lantern)
    try:
        entries.update({str(entry): value for entry, value in av_objects().items()})
    except (OSError, ValueError) as error:
        # Unlike a fixed chest, this table may introduce new entries on future
        # updates. A broken table/consumer proof invalidates the whole packet;
        # it must not masquerade as deletion of formerly collected objects.
        packet_failures.append({"source": "cpp-object:av-arrays", "reasons": [str(error)]})
    return {"version": 1, "entries": entries, "failures": packet_failures}
