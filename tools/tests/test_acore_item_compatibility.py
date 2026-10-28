import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_item_compatibility as compatibility
import db_snapshot


class ItemCompatibilityTests(unittest.TestCase):
    def test_scoped_quest_class_tracks_current_quest_and_use_spell(self):
        template = {"class": 0, "spellid_1": 100, "spelltrigger_1": 0}
        self.assertEqual(compatibility.quest_use_class(template, {"class": 0, "isStartItem": True}), 12)
        self.assertEqual(compatibility.quest_use_class(template, {"class": 0}), 0)
        self.assertEqual(compatibility.quest_use_class({"class": 13}, {"class": 13, "relatedQuests": [1]}), 13)
        self.assertEqual(compatibility.quest_use_class({"class": 12}, {"class": 12, "isStartItem": True}), 12)
        self.assertEqual(compatibility.quest_use_class({"class": 4, "InventoryType": 19},
                                                       {"class": 4, "relatedQuests": [1]}), 12)

    def test_smart_invoker_creation_and_self_timed_list(self):
        items = {5: {}}
        npcs = {7: {"AIName": "SmartAI", "ScriptName": ""}}
        spell = {100: {"Effect_1": 24, "EffectItemType_1": 5, "EffectImplicitTargetA_1": 25}}
        rows = [{"source_type": 0, "entryorguid": 7, "action_type": 80, "action_param1": 700,
                 "target_type": 1}, {"source_type": 9, "entryorguid": 700, "action_type": 11,
                                     "action_param1": 100, "target_type": 7}]
        result = compatibility.collect(items, npcs, {}, rows, spell)
        self.assertEqual(result["sources"], {"5": {"npcDrops": [7]}})
        rows[0]["target_type"] = 19
        self.assertEqual(compatibility.collect(items, npcs, {}, rows, spell)["sources"], {})
        rows[0]["target_type"] = 1
        npcs[7]["ScriptName"] = "custom_cpp"
        self.assertEqual(compatibility.collect(items, npcs, {}, rows, spell)["sources"], {})

    def test_item_use_requires_actual_focus_or_explicit_positive_target(self):
        items = {5: {}, 6: {"spellid_1": 100, "spelltrigger_1": 0}}
        objects = {8: {"type": 8, "Data0": 12}, 9: {"type": 3, "Data0": 12}}
        npcs = {7: {}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "RequiresSpellFocus": 12, "EffectImplicitTargetA1": 1}}
        condition = {"SourceTypeOrReferenceId": 13, "SourceEntry": 100, "ConditionTypeOrReference": 31,
                     "ConditionValue1": 3, "ConditionValue2": 7}
        result = compatibility.collect(items, npcs, objects, [], spells, [condition])
        self.assertEqual(result["sources"], {"5": {"objectDrops": [8], "npcDrops": [7]}})
        condition["NegativeCondition"] = 1
        items[6]["spelltrigger_1"] = 1
        self.assertEqual(compatibility.collect(items, npcs, objects, [], spells, [condition])["sources"], {})

    def test_spell_caster_conditions_do_not_become_acquisition_targets(self):
        items = {5: {}, 6: {"spellid_1": 100}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        row = {"SourceTypeOrReferenceId": 17, "SourceEntry": 100, "ConditionTypeOrReference": 31,
               "ConditionValue1": 3, "ConditionValue2": 7, "ConditionTarget": 0}
        self.assertEqual(compatibility.collect(items, {7: {}}, {}, [], spells, [row])["sources"], {})
        row["SourceTypeOrReferenceId"], row["ConditionTarget"] = 13, 1
        self.assertEqual(compatibility.collect(items, {7: {}}, {}, [], spells, [row])["sources"], {})

    def test_npc_creation_caster_does_not_grant_item_to_invoker(self):
        npcs = {7: {"AIName": "SmartAI"}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        row = {"source_type": 0, "entryorguid": 7, "action_type": 11,
               "action_param1": 100, "target_type": 7}
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, [row], spells)["sources"], {})
        row["action_type"] = 85
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, [row], spells)["sources"],
                         {"5": {"npcDrops": [7]}})

    def test_guid_restricted_condition_is_not_a_template_wide_source(self):
        items = {5: {}, 6: {"spellid_1": 100}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        row = {"SourceTypeOrReferenceId": 17, "SourceEntry": 100, "ConditionTypeOrReference": 31,
               "ConditionValue1": 3, "ConditionValue2": 7, "ConditionTarget": 1, "ConditionValue3": 100}
        self.assertEqual(compatibility.collect(items, {7: {}}, {}, [], spells, [row])["sources"], {})
        row["ConditionValue3"] = 0
        self.assertEqual(compatibility.collect(items, {7: {}}, {}, [], spells, [row])["sources"],
                         {"5": {"npcDrops": [7]}})
        row.update(ConditionValue1=5, ConditionValue2=8, ConditionValue3=1)
        self.assertEqual(compatibility.collect(items, {}, {8: {}}, [], spells, [row])["sources"], {})
        row["ConditionValue3"] = 0
        self.assertEqual(compatibility.collect(items, {}, {8: {}}, [], spells, [row])["sources"],
                         {"5": {"objectDrops": [8]}})

    def test_goober_player_use_and_noncreation_fields(self):
        objects = {8: {"type": 10, "Data10": 100}, 9: {"type": 10, "Data10": 100, "ScriptName": "custom"}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5}, 101: {"Effect1": 3, "EffectItemType1": 5}}
        self.assertEqual(compatibility.collect({5: {}}, {}, objects, [], spells)["sources"],
                         {"5": {"objectDrops": [8]}})
        objects[8]["Data10"] = 101
        self.assertEqual(compatibility.collect({5: {}}, {}, objects, [], spells)["sources"], {})

    def test_cpp_grants_follow_current_spells_and_reject_changed_calls(self):
        with db_snapshot.temporary_directory(Path(__file__).resolve().parents[1] / "reports") as folder:
            root = Path(folder)
            path = root / "src/server/scripts/Kalimdor/zone_thunder_bluff.cpp"
            path.parent.mkdir(parents=True)
            text = '''enum X { SPELL_CAIRNES_HOOFPRINT = 100 };
                class npc_cairne_bloodhoof : public CreatureScript {
                    npc_cairne_bloodhoof() : CreatureScript("npc_cairne_bloodhoof") {}
                    void sGossipSelect(Player* player) { player->CastSpell(player, SPELL_CAIRNES_HOOFPRINT, false); }
                };'''
            path.write_text(text)
            npcs = {3057: {"ScriptName": "npc_cairne_bloodhoof"}}
            spells = {100: {"Effect1": 24, "EffectItemType1": 5}}
            self.assertEqual(compatibility.collect_cpp(root, {5: {}, 6: {}}, npcs, {}, spells)["sources"],
                             {"5": {"npcDrops": [3057]}})
            spells[100]["EffectItemType1"] = 6
            self.assertEqual(compatibility.collect_cpp(root, {5: {}, 6: {}}, npcs, {}, spells)["sources"],
                             {"6": {"npcDrops": [3057]}})
            path.write_text(text.replace("CastSpell(player,", "CastSpell(enemy,"))
            with self.assertRaisesRegex(ValueError, "player cast"):
                compatibility.collect_cpp(root, {5: {}}, npcs, {}, spells)

    def test_random_range_call_visits_intermediate_lists(self):
        rows = [{"source_type": 0, "entryorguid": 7, "action_type": 88,
                 "action_param1": 700, "action_param2": 702, "target_type": 1},
                {"source_type": 9, "entryorguid": 701, "action_type": 56,
                 "action_param1": 5, "action_param2": 1, "target_type": 7}]
        self.assertEqual(compatibility.collect({5: {}}, {7: {"AIName": "SmartAI"}}, {}, rows, {})["sources"],
                         {"5": {"npcDrops": [7]}})
        rows[0]["target_type"] = 0
        self.assertEqual(compatibility.collect({5: {}}, {7: {"AIName": "SmartAI"}}, {}, rows, {})["sources"], {})


    def test_invoker_cast_creates_item_for_invoker_not_actor(self):
        npcs = {7: {"AIName": "SmartAI"}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        row = {"source_type": 0, "entryorguid": 7, "action_type": 134,
               "action_param1": 100, "target_type": 7}
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, [row], spells)["sources"],
                         {"5": {"npcDrops": [7]}})
        row["target_type"] = 1
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, [row], spells)["sources"], {})

    def test_cross_cast_requires_player_caster_and_recipient_stored_proofs(self):
        npcs = {7: {"AIName": "SmartAI"}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        store = {"source_type": 0, "entryorguid": 7, "id": 1, "action_type": 64,
                 "action_param1": 1, "target_type": 7}
        cast = {"source_type": 0, "entryorguid": 7, "id": 2, "action_type": 86,
                "action_param1": 100, "action_param3": 12, "action_param4": 1,
                "target_type": 12, "target_param1": 1}
        rows = [store, cast]
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, rows, spells)["sources"],
                         {"5": {"npcDrops": [7]}})
        for changed in ({**store, "id": 3, "target_type": 22},
                        {"source_type": 0, "entryorguid": 8, "action_type": 100,
                         "action_param1": 1, "target_type": 19, "target_param1": 7}):
            self.assertEqual(compatibility.collect({5: {}}, npcs, {}, rows + [changed], spells)["sources"], {})
        cast["action_param3"] = 1
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, rows, spells)["sources"], {})
        cast["action_param3"], store["target_type"], store["target_param1"] = 12, 12, 1
        self.assertEqual(compatibility.collect({5: {}}, npcs, {}, rows, spells)["sources"], {})

    def test_goober_script_effect_player_self_cast_follows_current_created_item(self):
        objects = {8: {"type": 10, "Data10": 100}}
        spells = {100: {"Effect3": 77, "EffectImplicitTargetA3": 25},
                  101: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        script = {"id": 100, "effIndex": 2, "command": 15, "datalong": 101, "datalong2": 2}
        def collect():
            return compatibility.collect({5: {}, 6: {}}, {}, objects, [], spells, spell_scripts=[script])["sources"]
        self.assertEqual(collect(), {"5": {"objectDrops": [8]}})
        spells[101]["EffectItemType1"] = 6
        self.assertEqual(collect(), {"6": {"objectDrops": [8]}})
        for field, value in (("command", 1), ("datalong2", 1), ("effIndex", 0), ("dataint", 1)):
            old = script.get(field, 0)
            script[field] = value
            self.assertEqual(collect(), {})
            script[field] = old
        spells[100]["EffectImplicitTargetA3"] = 1
        self.assertEqual(collect(), {})

    def test_dynamic_player_payload_cannot_poison_or_establish_another_player_list(self):
        npcs = {7: {"AIName": "SmartAI"}, 8: {"AIName": "SmartAI"}}
        objects = {9: {"AIName": "SmartGameObjectAI"}}
        spells = {100: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        store = {"source_type": 0, "entryorguid": 7, "action_type": 64,
                 "action_param1": 1, "target_type": 7}
        cast = {"source_type": 0, "entryorguid": 7, "id": 1, "action_type": 86,
                "action_param1": 100, "action_param3": 12, "action_param4": 1,
                "target_type": 12, "target_param1": 1}
        dynamic = {"source_type": 0, "entryorguid": -88, "action_type": 100,
                   "action_param1": 1, "target_type": 12, "target_param1": 2}
        payload = {"source_type": 1, "entryorguid": 9, "action_type": 64,
                   "action_param1": 1, "target_type": 7}
        send = {"source_type": 1, "entryorguid": 9, "id": 1, "action_type": 100,
                "action_param1": 1, "target_type": 19, "target_param1": 8}
        spawns = [{"guid": 88, "id1": 8}]
        def collect(rows):
            return compatibility.collect({5: {}}, npcs, objects, rows, spells,
                                         creature_spawns=spawns)["sources"]
        self.assertEqual(collect([store, cast, dynamic]), {})
        self.assertEqual(collect([store, cast, dynamic, payload, send]), {"5": {"npcDrops": [7]}})
        self.assertEqual(collect([cast, dynamic, payload, send]), {})
        payload["target_type"] = 1
        self.assertEqual(collect([store, cast, dynamic, payload, send]), {})

    def test_bound_spell_scripts_require_active_use_binding_and_guard_delivery(self):
        from unittest.mock import patch
        effects = "enum E { SPELL_EFFECT_DUMMY = 3, SPELL_EFFECT_ACTIVATE_OBJECT = 86, SPELL_EFFECT_APPLY_AURA = 6 };"
        auras = "enum A { SPELL_AURA_MOD_PACIFY_SILENCE = 60 };"
        snapper = '''
            enum X { ITEM_RED_SNAPPER = 5, GO_SCHOOL_OF_RED_SNAPPER = 8 };
            class spell_q9452_cast_net : public SpellScript {
                PrepareSpellScript(spell_q9452_cast_net);
                bool Load() override { return GetCaster()->IsPlayer(); }
                GameObject* go = GetCaster()->FindNearestGameObject(GO_SCHOOL_OF_RED_SNAPPER, 3.0f);
                if (!go || go->GetRespawnTime()) return SPELL_FAILED_REQUIRES_SPELL_FOCUS;
                Player* caster = GetCaster()->ToPlayer();
                if (roll_chance_i(66)) caster->AddItem(ITEM_RED_SNAPPER, 1);
                OnCheckCast += SpellCheckCastFn(spell_q9452_cast_net::CheckCast);
                OnEffectHit += SpellEffectFn(spell_q9452_cast_net::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
                OnEffectHitTarget += SpellEffectFn(spell_q9452_cast_net::HandleActiveObject, EFFECT_1, SPELL_EFFECT_ACTIVATE_OBJECT);
            };
            RegisterSpellScript(spell_q9452_cast_net);
        '''
        wolpertinger = '''
            enum X { ITEM_STUNNED_WOLPERTINGER = 5, NPC_WILD_WOLPERTINGER = 7 };
            class spell_catch_the_wild_wolpertinger : public AuraScript {
                PrepareAuraScript(spell_catch_the_wild_wolpertinger);
                if (Creature* wild = GetTarget()->ToCreature()) {
                    if (wild->GetEntry() == NPC_WILD_WOLPERTINGER) {
                        wild->ToCreature()->DespawnOrUnsummon(1s, 0s);
                        GetCaster()->ToPlayer()->AddItem(ITEM_STUNNED_WOLPERTINGER, 1);
                    }
                }
                OnEffectApply += AuraEffectApplyFn(spell_catch_the_wild_wolpertinger::HandleEffectApply,
                    EFFECT_0, SPELL_AURA_MOD_PACIFY_SILENCE, AURA_EFFECT_HANDLE_REAL);
            };
            RegisterSpellScript(spell_catch_the_wild_wolpertinger);
        '''
        items = {5: {}, 6: {"spellid_1": 100, "spelltrigger_1": 0}}
        cases = [("spell_q9452_cast_net", snapper, {"Effect1": 3, "Effect2": 86}, "objectDrops", 8),
                 ("spell_catch_the_wild_wolpertinger", wolpertinger,
                  {"Effect1": 6, "EffectApplyAuraName1": 60, "EffectImplicitTargetA1": 6}, "npcDrops", 7)]
        for name, script, spell, field, target in cases:
            def read(path, *args, **kwargs):
                return effects if path.name == "SharedDefines.h" else auras if path.name == "SpellAuraDefines.h" else script
            bindings = [{"ScriptName": name, "spell_id": 100}]
            with self.subTest(name=name), patch.object(Path, "read_text", read):
                result = compatibility.collect_bound_spells(Path("fixture"), items, {7: {}}, {8: {}}, {100: spell}, bindings)
                self.assertEqual(result["sources"], {"5": {field: [target]}})
                self.assertEqual(compatibility.collect_bound_spells(Path("fixture"), items, {7: {}}, {8: {}}, {}, [])["sources"], {})
                with self.assertRaisesRegex(ValueError, "effect layout"):
                    compatibility.collect_bound_spells(Path("fixture"), items, {7: {}}, {8: {}}, {100: {}}, bindings)
                with self.assertRaisesRegex(ValueError, "template is missing"):
                    compatibility.collect_bound_spells(Path("fixture"), items, {}, {}, {100: spell}, bindings)
            broken = script.replace("AddItem(", "SendMail(")
            with patch.object(Path, "read_text", lambda path, *args, **kwargs:
                              effects if path.name == "SharedDefines.h" else auras if path.name == "SpellAuraDefines.h" else broken):
                with self.assertRaisesRegex(ValueError, "delivery"):
                    compatibility.collect_bound_spells(Path("fixture"), items, {7: {}}, {8: {}}, {100: spell}, bindings)

    def test_bound_encounter_loot_masks_keep_default_reference_rows(self):
        from unittest.mock import patch
        files = {
            "SharedDefines.h": "enum LootModes { LOOT_MODE_DEFAULT = 0x01, };",
            "Creature.h": """void ResetLootMode() { m_LootMode = LOOT_MODE_DEFAULT; }
                void AddLootMode(uint16 lootMode) { m_LootMode |= lootMode; }
                void SetLootMode(uint16 lootMode) { m_LootMode = lootMode; }""",
            "ulduar.h": "enum E { EVENT_TOWER_OF_LIFE_DESTROYED = 30, EVENT_TOWER_OF_FLAMES_DESTROYED = 33 };",
            "boss_flame_leviathan.cpp": """struct boss_flame_leviathan : public BossAI { void EnterCombat() { ActivateTowers(); } };
                void boss_flame_leviathan::ActivateTowers() { _towersCount = 0; me->ResetLootMode();
                    for (uint32 i = EVENT_TOWER_OF_LIFE_DESTROYED; i <= EVENT_TOWER_OF_FLAMES_DESTROYED; ++i) {
                        if (instance->GetData(i)) { ++_towersCount; me->AddLootMode(1 << _towersCount); } } }
                RegisterUlduarCreatureAI(boss_flame_leviathan);""",
            "boss_yoggsaron.cpp": """struct boss_yoggsaron : public ScriptedAI {
                void Constructor() { uint8 _count = 4; me->SetLootMode(31);
                    for (uint8 i = 0; i < 4; ++i) if (watchersMask & (1 << i)) {
                        me->RemoveLootMode(1 << _count); --_count; } }
                void SpellHit() { if (spellInfo->Id == SPELL_IN_THE_MAWS_OF_THE_OLD_GOD) me->AddLootMode(32); } };
                RegisterUlduarCreatureAI(boss_yoggsaron);""",
        }
        npcs = {7: {"ScriptName": "boss_flame_leviathan"}, 8: {"ScriptName": "boss_yoggsaron"}, 9: {}}
        with patch.object(Path, "read_text", lambda path, *args, **kwargs: files[path.name]):
            result = compatibility.collect_cpp_loot_modes(Path("fixture"), npcs)
            self.assertEqual(result[7], [1, 3, 7, 15, 31])
            self.assertEqual(result[8], [1, 3, 7, 15, 31, 33, 35, 39, 47, 63])
            self.assertNotIn(9, result)
            self.assertTrue(all(mode & 1 for modes in result.values() for mode in modes))
            files["boss_flame_leviathan.cpp"] += " me->SetLootMode(0);"
            with self.assertRaisesRegex(ValueError, "mutations"):
                compatibility.collect_cpp_loot_modes(Path("fixture"), npcs)
            files["SharedDefines.h"] = "enum LootModes { LOOT_MODE_DEFAULT = 2, };"
            with self.assertRaisesRegex(ValueError, "default creature loot mode"):
                compatibility.collect_cpp_loot_modes(Path("fixture"), npcs)

    def test_item_target_cast_link_preserves_player_caster(self):
        items = {5: {}, 6: {"spellid_1": 100, "spelltrigger_1": 0}}
        spells = {100: {"Effect1": 3, "EffectImplicitTargetA1": 25},
                  101: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 1}}
        condition = {"SourceTypeOrReferenceId": 17, "SourceEntry": 100,
                     "ConditionTypeOrReference": 31, "ConditionTarget": 1,
                     "ConditionValue1": 3, "ConditionValue2": 7}
        link = {"spell_trigger": 100, "spell_effect": 101, "type": 0}
        def collect():
            return compatibility.collect(items, {7: {}}, {}, [], spells, [condition], spell_links=[link])["sources"]
        self.assertEqual(collect(), {"5": {"npcDrops": [7]}})
        spells[101]["EffectImplicitTargetA1"] = 25
        self.assertEqual(collect(), {})
        spells[101]["EffectImplicitTargetA1"], link["type"] = 1, 1
        self.assertEqual(collect(), {})
        link["type"], link["spell_effect"] = 0, -101
        self.assertEqual(collect(), {})

    def test_bound_player_aura_removal_grants_item_to_same_player(self):
        from unittest.mock import patch
        script = '''enum E { SPELL_INDISPOSED_MALE = 100, SPELL_INDISPOSED_FEMALE = 102 };
            class go_amberpine_outhouse : public GameObjectScript {
                go_amberpine_outhouse() : GameObjectScript("go_amberpine_outhouse") {}
                void Gossip(Player* player) {
                    player->CastSpell(player, SPELL_INDISPOSED_MALE);
                    player->CastSpell(player, SPELL_INDISPOSED_FEMALE);
                }
            };'''
        objects = {188666: {"ScriptName": "go_amberpine_outhouse"}}
        spells = {100: {"Effect1": 6, "EffectImplicitTargetA1": 1},
                  102: {"Effect1": 6, "EffectImplicitTargetA1": 1},
                  101: {"Effect1": 24, "EffectItemType1": 5, "EffectImplicitTargetA1": 25}}
        links = [{"spell_trigger": -100, "spell_effect": 101, "type": 0},
                 {"spell_trigger": -102, "spell_effect": 101, "type": 0}]
        with patch.object(Path, "read_text", lambda *args, **kwargs: script):
            def collect():
                return compatibility.collect_cpp(Path("fixture"), {5: {}}, {}, objects, spells, spell_links=links)["sources"]
            self.assertEqual(collect(), {"5": {"objectDrops": [188666]}})
            spells[100]["Effect1"], spells[102]["Effect1"] = 3, 3
            self.assertEqual(collect(), {})
            spells[100]["Effect1"], spells[102]["Effect1"] = 6, 6
            spells[100]["EffectImplicitTargetA1"], spells[102]["EffectImplicitTargetA1"] = 38, 38
            self.assertEqual(collect(), {})


class SummonedProviderTests(unittest.TestCase):
    CPP = '''
        enum X { NPC_CHANGED = 900 };
        class go_southfury_moonstone : public GameObjectScript {
            go_southfury_moonstone() : GameObjectScript("go_southfury_moonstone") { }
            bool OnGossipHello(Player* player, GameObject* go) override {
                if (Creature* creature = player->SummonCreature(NPC_CHANGED, 0.0f, 0.0f, 0.0f, 0.0f, TEMPSUMMON_DEAD_DESPAWN, 0)) {
                    creature->AI()->AttackStart(player);
                    go->DespawnOrUnsummon(8000ms);
                }
                return false;
            }
        };
        void AddSC() { new go_southfury_moonstone(); }
    '''

    def grant(self, item=700, npc=900):
        return {"sources": {str(item): {"npcDrops": [npc]}},
                "evidence": [{"itemId": item, "field": "npcDrops", "sourceId": npc, "rule": "smartInvokerGrant"}]}

    def test_cpp_handoff_decodes_source_npc_and_requires_independent_grant(self):
        from unittest.mock import patch
        args = [Path("fixture"), {700: {}}, {900: {}},
                {800: {"type": 10, "ScriptName": "go_southfury_moonstone"}}, [self.grant()]]
        with patch.object(Path, "read_text", return_value=self.CPP):
            self.assertEqual(compatibility.collect_summon_handoffs(*args)["sources"], {"700": {"objectDrops": [800]}})
            args[4] = [{"sourceKind": "creatureLoot", "sources": {"700": {"npcDrops": [900]}}}]
            self.assertEqual(compatibility.collect_summon_handoffs(*args)["sources"], {})
            args[4] = [{"sources": {"700": {"npcDrops": [900]}}, "evidence": []}]
            self.assertEqual(compatibility.collect_summon_handoffs(*args)["sources"], {})
        args[3][800]["ScriptName"] = "unbound"
        with patch.object(Path, "read_text", side_effect=AssertionError("inactive handler read")):
            self.assertEqual(compatibility.collect_summon_handoffs(*args)["sources"], {})

    def test_cpp_changed_actor_or_delivery_requires_review(self):
        from unittest.mock import patch
        for old, changed in (("NPC_CHANGED = 900", "NPC_CHANGED = 901"),
                             ("AttackStart(player)", "AttackStart(other)"),
                             ("player->SummonCreature", "go->SummonCreature")):
            with self.subTest(changed=changed), patch.object(Path, "read_text", return_value=self.CPP.replace(old, changed)):
                with self.assertRaises(ValueError):
                    compatibility.collect_summon_handoffs(Path("fixture"), {700: {}}, {900: {}},
                        {800: {"type": 10, "ScriptName": "go_southfury_moonstone"}}, [self.grant()])

    def smart(self, rows, obj=None, packets=None, conditions=()):
        from unittest.mock import patch
        if obj is None:
            obj = {"type": 3, "AIName": "SmartGameObjectAI"}
        if packets is None:
            packets = [{"sourceKind": "creatureLoot", "sources": {"700": {"npcDrops": [900]}}}]
        with patch.object(compatibility, "_validate_summon_core"):
            return compatibility.collect_summon_handoffs(Path("fixture"), {700: {}}, {900: {}},
                {800: obj}, packets, scripts=rows, conditions=conditions)

    def open_row(self, **changed):
        return dict({"source_type": 1, "entryorguid": 800, "id": 0, "event_type": 70,
                     "event_param1": 2, "event_chance": 100, "action_type": 12,
                     "action_param1": 900, "action_param2": 4, "target_type": 8,
                     "target_x": 1, "target_y": 2, "target_z": 3}, **changed)

    def test_smart_open_summon_keeps_corpse_provider_and_linked_rows(self):
        first = self.open_row(link=1)
        linked = self.open_row(id=1, event_type=61)
        result = self.smart([first, linked])
        self.assertEqual(result["sources"], {"700": {"objectDrops": [800]}})
        self.assertEqual(len(result["evidence"]), 2)
        self.assertEqual(self.smart([linked])["sources"], {})
        self.assertEqual(len(self.smart([first, dict(linked, event_type=0)])["evidence"]), 1)

    def test_smart_summon_requires_player_open_binding_and_valid_target(self):
        for changed in ({"event_type": 64}, {"event_param1": 1}, {"event_phase_mask": 1},
                        {"event_chance": 0}, {"action_param1": 901}, {"target_type": 19},
                        {"target_x": float("nan")}, {"source_type": 0}):
            with self.subTest(changed=changed):
                self.assertEqual(self.smart([self.open_row(**changed)])["sources"], {})
        for obj in ({"type": 3, "AIName": "other"},
                    {"type": 3, "AIName": "SmartGameObjectAI", "ScriptName": "custom"},
                    {"type": 5, "AIName": "SmartGameObjectAI"}):
            self.assertEqual(self.smart([self.open_row()], obj=obj)["sources"], {})
        self.assertEqual(self.smart([self.open_row()], packets=[{"sources": {"700": {"vendors": [900]}}}])["sources"], {})
        self.assertEqual(self.smart([self.open_row()], conditions=[{"SourceTypeOrReferenceId": 22, "SourceEntry": 800}])["sources"], {})

    def test_self_timed_list_is_reachable_but_cross_actor_list_is_not(self):
        root = self.open_row(action_type=80, action_param1=123, target_type=1)
        child = self.open_row(source_type=9, entryorguid=123, event_type=0)
        self.assertEqual(self.smart([root, child])["sources"], {"700": {"objectDrops": [800]}})
        root["target_type"] = 19
        self.assertEqual(self.smart([root, child])["sources"], {})


if __name__ == "__main__":
    unittest.main()
