"""C++ geometry follows actual callsites and fails closed on unsupported changes."""
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
from db_snapshot import temporary_directory
import acore_cpp_geometry as cpp
import generate_acore_npc_corrections as reader


class CppGeometryTests(unittest.TestCase):
    def fixture(self):
        return {
            cpp.HOR + "halls_of_reflection.h": """
                NPC_JAINA_PART2 = 36955, NPC_SYLVANAS_PART2 = 37554,
                #define PATH_WP_COUNT 2
                const uint8 WP_STOP[2] = {0, 1};
                const Position LeaderEscapePos = {10.f, 20.f, 30.f, 0.f};
                const Position PathWaypoints[PATH_WP_COUNT] = {
                    {11.f, 21.f, 31.f, 0.f}, {12.f, 22.f, 32.f, 0.f}};
            """,
            cpp.HOR + "halls_of_reflection.cpp": """
                npc_hor_leader_second() : CreatureScript("npc_hor_leader_second") {}
                return GetHallsOfReflectionAI<npc_hor_leader_secondAI>(creature);
                for (uint8 i = WP_STOP[currentStopPoint - 1] + (currentStopPoint == 1 ? 0 : 1); i <= WP_STOP[currentStopPoint]; ++i)
                    path.emplace_back(PathWaypoints[i].GetPositionX(), PathWaypoints[i].GetPositionY(), PathWaypoints[i].GetPositionZ());
                me->GetMotionMaster()->MoveSplinePath(&path, FORCED_MOVEMENT_RUN);
            """,
            cpp.HOR + "instance_halls_of_reflection.cpp": """
                RegisterInstanceScript(instance_halls_of_reflection, MAP_HALLS_OF_REFLECTION);
                case NPC_SYLVANAS_PART2:
                if (GetTeamIdInInstance() == TEAM_ALLIANCE) creature->UpdateEntry(NPC_JAINA_PART2);
                else if (GetBossState(DATA_LICH_KING) != DONE) {
                    creature->UpdatePosition(LeaderEscapePos, true);
                } else {
                    creature->UpdatePosition(PathWaypoints[PATH_WP_COUNT - 1], true);
                    creature->StopMovingOnCurrentPos();
                }
            """,
            cpp.AV + "BattlegroundAV.h": """
                const uint32 BG_AV_StaticCreatureInfo[2] = {777, 12051};
                const float BG_AV_StaticCreaturePos[3][5] = {
                    {1.f, 2.f, 3.f, 0.f, 0},
                    {40.f, 50.f, 60.f, 0.f, 1},
                    {41.f, 51.f, 61.f, 0.f, 1}};
            """,
            cpp.AV + "BattlegroundAV.cpp": """
                cinfoid = uint16(BG_AV_StaticCreaturePos[type][4]);
                creature = AddCreature(BG_AV_StaticCreatureInfo[cinfoid], type + AV_CPLACE_MAX,
                    BG_AV_StaticCreaturePos[type][0], BG_AV_StaticCreaturePos[type][1],
                    BG_AV_StaticCreaturePos[type][2], BG_AV_StaticCreaturePos[type][3]);
                for (i = 0; i < AV_STATICCPLACE_MAX; i++) AddAVCreature(0, i + AV_CPLACE_MAX);
            """,
            cpp.SOURCE_FILES[-1]: """
                MAP_HALLS_OF_REFLECTION = 668, AREA_HALLS_OF_REFLECTION = 4820,
                MAP_ALTERAC_VALLEY = 30, AREA_ALTERAC_VALLEY = 2597,
            """,
        }

    def collect(self, files, gap=False):
        seen = []

        def project(row, maps):
            seen.append(row)
            if gap and row["position_z"] == 32:
                return None, None
            self.assertNotIn("guid", row)
            self.assertNotIn("areaId", row)
            return row["zoneId"], [row["position_x"], row["position_y"]]

        with temporary_directory(ADDON_ROOT / "tools/reports") as root:
            for relative, text in files.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            with patch.object(reader, "resolve_coordinate_zone", side_effect=project):
                packet = cpp.collect(root, {})
        return packet["entries"], seen

    def test_real_callsite_fixtures_use_entry_lookup_and_each_positions_own_height(self):
        entries, rows = self.collect(self.fixture())
        self.assertEqual(entries["36955"]["spawns"]["n:4820"]["n:1"], {"n:1": 10, "n:2": 20})
        self.assertEqual(entries["36955"]["spawns"]["n:4820"]["n:2"], {"n:1": 12, "n:2": 22})
        self.assertEqual(len(entries["36955"]["waypoints"]["n:4820"]["n:1"]), 2)
        self.assertEqual(len(entries["12051"]["spawns"]["n:2597"]), 2)
        self.assertEqual([row["position_z"] for row in rows], [30, 32, 31, 32, 60, 61])
        self.assertFalse(entries["12051"]["waypoints"])
        self.assertTrue(entries["36955"]["origins"]["waypoints"]["n:4820"]["n:1"])
        self.assertFalse(entries["36955"]["failures"]["spawns"])

    def test_future_numeric_source_changes_refresh_without_legacy_coordinates(self):
        files = self.fixture()
        files[cpp.HOR + "halls_of_reflection.h"] = files[cpp.HOR + "halls_of_reflection.h"].replace("12.f, 22.f", "14.f, 24.f")
        files[cpp.AV + "BattlegroundAV.h"] = files[cpp.AV + "BattlegroundAV.h"].replace("40.f, 50.f", "45.f, 55.f")
        entries, _ = self.collect(files)
        self.assertEqual(entries["36955"]["waypoints"]["n:4820"]["n:1"]["n:2"], {"n:1": 14, "n:2": 24})
        self.assertEqual(entries["36955"]["spawns"]["n:4820"]["n:2"], {"n:1": 14, "n:2": 24})
        self.assertEqual(entries["12051"]["spawns"]["n:2597"]["n:1"], {"n:1": 45, "n:2": 55})

    def test_changed_actor_or_path_callsites_fail_instead_of_using_old_geometry(self):
        changes = [(cpp.HOR + "instance_halls_of_reflection.cpp", "TEAM_ALLIANCE", "TEAM_HORDE"),
                   (cpp.HOR + "halls_of_reflection.cpp", "MoveSplinePath", "DifferentMovement"),
                   (cpp.HOR + "instance_halls_of_reflection.cpp", "PathWaypoints[PATH_WP_COUNT - 1], true", "OtherFinishPos, true"),
                   (cpp.HOR + "halls_of_reflection.h", "PATH_WP_COUNT 2", "PATH_WP_COUNT 3"),
                   (cpp.HOR + "halls_of_reflection.h", "36955", "36956")]
        for path, old, new in changes:
            with self.subTest(old=old):
                files = self.fixture()
                files[path] = files[path].replace(old, new)
                entries, _ = self.collect(files)
                self.assertTrue(entries["36955"]["failures"]["spawns"])
                self.assertFalse(entries["36955"]["spawns"])
                self.assertFalse(entries["36955"]["waypoints"])
                self.assertFalse(entries["12051"]["failures"]["spawns"])

    def test_missing_height_mapping_stops_full_cpp_record_for_review(self):
        entries, _ = self.collect(self.fixture(), gap=True)
        self.assertTrue(entries["36955"]["failures"]["waypoints"])
        self.assertFalse(entries["36955"]["waypoints"])

    def test_changed_av_entry_index_and_removed_spawn_loop_require_review(self):
        for path, old, new in [(cpp.AV + "BattlegroundAV.h", "60.f, 0.f, 1", "60.f, 0.f, 9"),
                               (cpp.AV + "BattlegroundAV.cpp", "AddAVCreature(0, i + AV_CPLACE_MAX)", "OtherSpawn(i)"),
                               (cpp.AV + "BattlegroundAV.h", "12051", "12052")]:
            with self.subTest(old=old):
                files = self.fixture()
                files[path] = files[path].replace(old, new)
                entries, _ = self.collect(files)
                self.assertTrue(entries["12051"]["failures"]["spawns"])
                self.assertFalse(entries["12051"]["spawns"])

    def test_unavailable_source_file_is_explicit_per_entry_failure(self):
        files = self.fixture()
        del files[cpp.AV + "BattlegroundAV.cpp"]
        entries, _ = self.collect(files)
        self.assertTrue(entries["12051"]["failures"]["spawns"])
        self.assertFalse(entries["36955"]["failures"]["spawns"])

    def object_fixture(self):
        files = {
            cpp.CULLING + "culling_of_stratholme.h": "GO_MALGANIS_CHEST_N = 190663, GO_MALGANIS_CHEST_H = 193597,",
            cpp.CULLING + "boss_mal_ganis.cpp": "instance->instance->SummonGameObject(DUNGEON_MODE(GO_MALGANIS_CHEST_N, GO_MALGANIS_CHEST_H), 2288.35f, 1498.73f, 128.414f, 0, 0);",
            cpp.ULDUAR + "ulduar.h": """
                GO_THORIM_CHEST = 194312, GO_THORIM_CHEST_HERO = 194314,
                GO_MIMIRON_CHEST = 194789, GO_MIMIRON_CHEST_HARD = 194957,
                GO_MIMIRON_CHEST_HERO = 194956, GO_MIMIRON_CHEST_HERO_HARD = 194958,
            """,
            cpp.ULDUAR + "boss_thorim.cpp": """
                uint32 chestId = me->GetMap()->Is25ManRaid() ? GO_THORIM_CHEST_HERO : GO_THORIM_CHEST;
                if (_hardMode) chestId += 1;
                me->GetMap()->SummonGameObject(chestId, 2134.73f, -286.32f, 419.51f, 0, 0);
            """,
            cpp.ULDUAR + "boss_mimiron.cpp": """
                if (uint32 chestId = (_hardmode ? RAID_MODE(GO_MIMIRON_CHEST_HARD, GO_MIMIRON_CHEST_HERO_HARD) : RAID_MODE(GO_MIMIRON_CHEST, GO_MIMIRON_CHEST_HERO)))
                me->GetMap()->SummonGameObject(chestId, 2744.65f, 2569.46f, 364.397f, 0, 0);
            """,
            cpp.EYE + "eye_of_eternity.h": """
                #define HEART_OF_MAGIC DUNGEON_MODE(194158, 194159)
                const Position HeartOfMagicPos = {773.98f, 1275.97f, 266.254f, 0.f};
            """,
            cpp.EYE + "boss_malygos.cpp": "me->SummonGameObject(HEART_OF_MAGIC, HeartOfMagicPos.GetPositionX(), HeartOfMagicPos.GetPositionY(), HeartOfMagicPos.GetPositionZ(), 0, 0);",
            cpp.ZULDRAK: """
                GO_DRAKURUS_LAST_WISH = 202357,
                struct npc_overlord_drakuru_betrayal : public ScriptedAI {};
                RegisterCreatureAI(npc_overlord_drakuru_betrayal);
                me->SummonGameObject(GO_DRAKURUS_LAST_WISH, 6185.989, -2029.6979, 590.87787, 0, 0);
            """,
            cpp.SOURCE_FILES[-1]: "MAP_THE_CULLING_OF_STRATHOLME = 595, MAP_ULDUAR = 603, MAP_THE_EYE_OF_ETERNITY = 616, MAP_NORTHREND = 571, AREA_ZUL_DRAK = 66, MAP_ALTERAC_VALLEY = 30, AREA_ALTERAC_VALLEY = 2597,",
            "src/server/game/AI/ScriptedAI/ScriptedCreature.h": """
                case DUNGEON_DIFFICULTY_NORMAL: return normal5;
                case DUNGEON_DIFFICULTY_HEROIC: return heroic10;
                case RAID_DIFFICULTY_10MAN_NORMAL: return normal10;
                case RAID_DIFFICULTY_25MAN_NORMAL: return normal25;
            """,
            "src/server/game/Entities/Object/Object.cpp": """
                go->Create(id, entry, this, PHASEMASK_NORMAL, x, y, z);
                go->Create(map->GenerateLowGuid<HighGuid::GameObject>(), entry, map, GetPhaseMask(), x, y, z);
            """,
            cpp.AV + "BattlegroundAV.h": """
                BG_AV_OBJECTID_MINE_N = 178785, BG_AV_OBJECTID_MINE_S = 178784,
                AV_OPLACE_MINE_SUPPLY_N_MIN = 0, AV_OPLACE_MINE_SUPPLY_N_MAX = 1,
                AV_OPLACE_MINE_SUPPLY_S_MIN = 2, AV_OPLACE_MINE_SUPPLY_S_MAX = 2,
                BG_AV_OBJECT_MINE_SUPPLY_N_MIN = 100, BG_AV_OBJECT_MINE_SUPPLY_N_MAX = 101,
                BG_AV_OBJECT_MINE_SUPPLY_S_MIN = 102, BG_AV_OBJECT_MINE_SUPPLY_S_MAX = 102,
                BG_AV_OBJECT_GENERIC_MIN = 200, BG_AV_OBJECT_GENERIC_MAX = 201,
                float BG_AV_ObjectPos[3][4] = {{10,20,30,0},{11,21,31,0},{12,22,32,0}};
                tuple BG_AV_GenericObjectPos[2] = {
                    {179438,{40,50,60,0},{0,0,0,1}}, {3835,{41,51,61,0},{0,0,0,1}}};
            """,
            cpp.AV + "BattlegroundAV.cpp": """
                for (uint16 i = 0; i <= (BG_AV_OBJECT_GENERIC_MAX - BG_AV_OBJECT_GENERIC_MIN); i++)
                    AddObject(BG_AV_OBJECT_GENERIC_MIN + i, std::get<0>(BG_AV_GenericObjectPos[i]), std::get<1>(BG_AV_GenericObjectPos[i]).GetPositionX(), std::get<1>(BG_AV_GenericObjectPos[i]).GetPositionY(), std::get<1>(BG_AV_GenericObjectPos[i]).GetPositionZ(), 0);
            """,
        }
        for side in ("N", "S"):
            files[cpp.AV + "BattlegroundAV.cpp"] += f"""
                for (uint16 i = 0; i <= (BG_AV_OBJECT_MINE_SUPPLY_{side}_MAX - BG_AV_OBJECT_MINE_SUPPLY_{side}_MIN); i++)
                    AddObject(BG_AV_OBJECT_MINE_SUPPLY_{side}_MIN + i, BG_AV_OBJECTID_MINE_{side}, BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][0], BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][1], BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][2], BG_AV_ObjectPos[AV_OPLACE_MINE_SUPPLY_{side}_MIN + i][3], 0);
            """
        return files

    def collect_objects(self, files, wrong_floor=False, wrong_actor_phase=False, lantern=False, missing_spell=False):
        seen = []
        zone_ui = {4100: 130, 4660: 147, 4661: 148, 4500: 141, 2597: 99}
        maps = {"instance_to_zone": {595: 4100, 603: 4273, 616: 4500},
                "ui_by_instance": {595: [130], 603: [147, 148], 616: [141]}}

        def project(row, _maps):
            seen.append(row)
            self.assertNotIn("guid", row)
            zone = row["zoneId"] if row["map"] in (0, 1, 530) else {595: 4100, 616: 4500, 571: 66, 30: 2597}.get(row["map"], 4660 if row["position_z"] < 400 else 4661)
            if wrong_floor and row["map"] == 603:
                zone = 4100
            return zone, [row["position_x"], row["position_y"]]

        with temporary_directory(ADDON_ROOT / "tools/reports") as root:
            for relative, text in files.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            with patch.object(reader, "resolve_coordinate_zone", side_effect=project), patch.object(reader, "zone_to_ui", side_effect=lambda z, _: zone_ui.get(z)):
                actors = {28859: [{"map": 616, "phaseMask": 1}], 28998: [{"map": 571, "phaseMask": 1, "areaId": 4314}]}
                if wrong_actor_phase:
                    actors[28998][0]["phaseMask"] = 4
                templates, spells = {}, {}
                if lantern:
                    templates = {24519: {"ScriptName": "npc_costumed_orphan_matron"},
                                 23973: {"ScriptName": "npc_costumed_orphan_matron"}}
                    actors[24519] = [dict(map=m, zoneId=z, areaId=a, phaseMask=1)
                                     for m, z, a in ((0, 12, 87), (0, 1, 131), (530, 3524, 3576))]
                    actors[23973] = [dict(map=m, zoneId=z, areaId=a, phaseMask=1)
                                     for m, z, a in ((1, 14, 362), (0, 85, 159), (530, 3430, 3665))]
                    spells = {} if missing_spell else {44255: 186887}
                packet = cpp.collect_objects(root, maps, actor_spawns=actors,
                                             actor_templates=templates, spell_object_bindings=spells)
                self.last_packet = packet
        return packet["entries"], seen

    def test_chest_mode_ids_and_source_heights_select_native_instance_floors(self):
        entries, rows = self.collect_objects(self.object_fixture())
        self.assertEqual(set(entries), {"193597", "194313", "194314", "194957", "194958", "194158", "194159", "202357", "178784", "178785", "179438", "3835", "186887"})
        self.assertEqual(set(entries["194313"]["spawns"]), {"n:4661"})
        self.assertEqual(set(entries["194957"]["spawns"]), {"n:4660"})
        self.assertEqual([row["position_z"] for row in rows][:8], [128.414, 419.51, 419.51, 364.397, 364.397, 266.254, 266.254, 590.87787])
        self.assertTrue(all(not data["failures"]["spawns"] for entry, data in entries.items() if entry != "186887"))
        self.assertTrue(entries["186887"]["failures"]["spawns"])
        modes = {"193597": (2, 595), "194313": (1, 603), "194314": (2, 603),
                 "194957": (1, 603), "194958": (2, 603), "194158": (1, 616), "194159": (2, 616)}
        for entry, (mask, map_id) in modes.items():
            point = next(iter(entries[entry]["spawns"].values()))["n:1"]
            self.assertEqual([point[f"n:{i}"] for i in (3, 4, 5)], [0, mask, map_id])
        drakuru = entries["202357"]["spawns"]["n:66"]["n:1"]
        self.assertEqual([drakuru[f"n:{i}"] for i in (3, 4, 5, 6, 7)], [0, 1, 571, 1, 0])
        self.assertNotIn("n:8", drakuru)
        self.assertFalse(self.last_packet["failures"])

    def test_chest_positions_refresh_and_unsupported_mode_or_dynamic_position_fails(self):
        files = self.object_fixture()
        files[cpp.EYE + "eye_of_eternity.h"] = files[cpp.EYE + "eye_of_eternity.h"].replace("773.98f", "775.98f")
        entries, _ = self.collect_objects(files)
        self.assertEqual(entries["194158"]["spawns"]["n:4500"]["n:1"]["n:1"], 775.98)
        for relative, before, after, entry in [
            (cpp.ULDUAR + "boss_thorim.cpp", "chestId += 1", "chestId += 2", "194313"),
            (cpp.ULDUAR + "boss_mimiron.cpp", "_hardmode ?", "_othermode ?", "194957"),
            (cpp.CULLING + "boss_mal_ganis.cpp", "2288.35f", "me->GetPositionX()", "193597"),
            (cpp.EYE + "eye_of_eternity.h", "194158, 194159", "194158, 194160", "194158"),
            (cpp.ZULDRAK, "RegisterCreatureAI(npc_overlord_drakuru_betrayal)", "RegisterCreatureAI(other_actor)", "202357")]:
            with self.subTest(entry=entry):
                files = self.object_fixture()
                files[relative] = files[relative].replace(before, after)
                entries, _ = self.collect_objects(files)
                self.assertTrue(entries[entry]["failures"]["spawns"])
                self.assertFalse(entries[entry]["spawns"])

    def test_chest_projection_to_different_instance_requires_review(self):
        entries, _ = self.collect_objects(self.object_fixture(), wrong_floor=True)
        self.assertTrue(entries["194313"]["failures"]["spawns"])
        self.assertFalse(entries["194313"]["spawns"])
        self.assertFalse(entries["193597"]["failures"]["spawns"])

    def test_world_object_does_not_drop_changed_actor_phase_or_copy_actor_region(self):
        entries, _ = self.collect_objects(self.object_fixture(), wrong_actor_phase=True)
        self.assertTrue(entries["202357"]["failures"]["spawns"])
        self.assertFalse(entries["202357"]["spawns"])

    def test_av_object_arrays_refresh_new_ids_coordinates_and_keep_other_source_points(self):
        files = self.object_fixture()
        path = cpp.AV + "BattlegroundAV.h"
        files[path] = files[path].replace("{3835,{41,51,61,0}", "{3836,{42,52,62,0}")
        entries, _ = self.collect_objects(files)
        self.assertNotIn("3835", entries)
        self.assertEqual(entries["3836"]["spawns"]["n:2597"]["n:1"]["n:1"], 42)
        self.assertEqual(len(entries["178785"]["spawns"]["n:2597"]), 2)
        self.assertEqual(len(entries["178784"]["spawns"]["n:2597"]), 1)
        self.assertEqual(entries["179438"]["spawns"]["n:2597"]["n:1"]["n:5"], 30)
        files[path] = files[path].replace("AV_OPLACE_MINE_SUPPLY_N_MAX = 1", "AV_OPLACE_MINE_SUPPLY_N_MAX = 2")
        self.collect_objects(files)
        self.assertTrue(self.last_packet["failures"])

    def lantern_fixture(self):
        files = self.object_fixture()
        names = ["GOLDSHIRE", "KHARANOS", "AZURE_WATCH", "RAZOR_HILL", "BRILL", "FALCONWING_SQUARE"]
        area_ids = [87, 131, 3576, 362, 159, 3665]
        files[cpp.SOURCE_FILES[-1]] += ",".join(f" AREA_{name} = {area}," for name, area in zip(names, area_ids))
        init = "".join(f"case AREA_{name}: path = {235431 + i}; break;" for i, name in enumerate(names))
        land = "".join(f"case {235431 + i}: x = {100 + i}; y = {200 + i}; z = {300 + i}; break;" for i in range(6))
        files[cpp.HALLOWS] = """
            SPELL_SUMMON_LANTERN = 44255, NPC_SHADE_OF_HORSEMAN = 23543,
            struct npc_hallows_end_soh : public ScriptedAI {};
            RegisterCreatureAI(npc_hallows_end_soh);
            RegisterCreatureAI(npc_costumed_orphan_matron);
            GetInitXYZ(x, y, z, o, path);
            me->SummonCreature(NPC_SHADE_OF_HORSEMAN, x, y, z, o, TEMPSUMMON_CORPSE_TIMED_DESPAWN, 10000);
            cr->AI()->DoAction(path);
            void DoAction(int32 param) override { pos = param; }
            void JustDied(Unit*) override {
                GetPosToLand(x, y, z); me->CastSpell(x, y, z, SPELL_SUMMON_LANTERN, true);
            }
        """ + "void GetInitXYZ(float& x, float& y, float& z, float& o, uint32& path) { switch (me->GetAreaId()) {" + init + "}}" + "void GetPosToLand(float& x, float& y, float& z) { switch (pos) {" + land + "default: x = 0; y = 0; z = 0; break; }}"
        files[cpp.SPELL_FIXES] = """
            ApplySpellFix({44255, 44231}, [](SpellInfo* spellInfo) {
                spellInfo->Effects[EFFECT_0].TargetA = SpellImplicitTargetInfo(TARGET_DEST_DEST);
                spellInfo->Effects[EFFECT_0].TargetB = SpellImplicitTargetInfo();
            });
        """
        return files

    def test_lantern_uses_fixed_landing_xyz_and_native_matron_map_without_corpse_position(self):
        entries, seen = self.collect_objects(self.lantern_fixture(), lantern=True)
        data = entries["186887"]
        self.assertFalse(data["failures"]["spawns"])
        self.assertEqual(len(data["spawns"]), 6)
        for zone in (3524, 3430):
            self.assertEqual(data["spawns"][f"n:{zone}"]["n:1"]["n:5"], 530)
        self.assertEqual(data["spawns"]["n:3524"]["n:1"]["n:1"], 102)
        landing = [row for row in seen if row["map"] in (0, 1, 530)]
        self.assertEqual([row["position_z"] for row in landing], list(range(300, 306)))
        self.assertTrue(all("areaId" not in row and "guid" not in row for row in landing))

    def test_lantern_source_and_spell_changes_fail_or_refresh_without_legacy_fallback(self):
        files = self.lantern_fixture()
        files[cpp.HALLOWS] = files[cpp.HALLOWS].replace("x = 102", "x = 112")
        entries, _ = self.collect_objects(files, lantern=True)
        self.assertEqual(entries["186887"]["spawns"]["n:3524"]["n:1"]["n:1"], 112)
        entries, _ = self.collect_objects(files, lantern=True, missing_spell=True)
        self.assertTrue(entries["186887"]["failures"]["spawns"])
        for relative, old, new in [
            (cpp.HALLOWS, "me->CastSpell(x, y, z", "me->CastSpell(me->GetPositionX(), y, z"),
            (cpp.HALLOWS, "case 235436:", "case 235437:"),
            (cpp.HALLOWS, "RegisterCreatureAI(npc_hallows_end_soh)", "RegisterCreatureAI(other_ai)"),
            (cpp.SPELL_FIXES, "44255, 44231", "44255, 44232"),
            (cpp.SPELL_FIXES, "TARGET_DEST_DEST", "TARGET_DEST_CASTER"),
            (cpp.SPELL_FIXES, "spellInfo->Effects[EFFECT_0].TargetB = SpellImplicitTargetInfo();", "")]:
            with self.subTest(old=old):
                files = self.lantern_fixture()
                files[relative] = files[relative].replace(old, new)
                entries, _ = self.collect_objects(files, lantern=True)
                self.assertTrue(entries["186887"]["failures"]["spawns"])
                self.assertFalse(entries["186887"]["spawns"])


if __name__ == "__main__":
    unittest.main()
