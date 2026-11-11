from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import acore_quest_cpp_credits as cpp
import db_snapshot


CORE_FIXTURES = {
    "src/server/game/Entities/Player/Player.h": '''
        void KilledMonsterCredit(uint32 entry, ObjectGuid guid = ObjectGuid::Empty);
        void RewardPlayerAndGroupAtEvent(uint32 creature_id, WorldObject* pRewardSource);
    ''',
    "src/server/game/Entities/Player/PlayerQuest.cpp": '''
        void Player::KilledMonsterCredit(uint32 entry, ObjectGuid guid) {
            uint16 addkillcount = 1;
            uint32 real_entry = entry;
            if (guid) {
                Creature* killed = GetMap()->GetCreature(guid);
                if (killed && killed->GetEntry()) real_entry = killed->GetEntry();
            }
            for (uint8 j = 0; j < QUEST_OBJECTIVES_COUNT; ++j) {
                uint32 reqkill = qInfo->RequiredNpcOrGo[j];
                if (reqkill == real_entry) {
                    q_status.CreatureOrGOCount[j] = curkillcount + addkillcount;
                }
            }
        }
    ''',
    "src/server/game/Entities/Player/Player.cpp": '''
        void Player::RewardPlayerAndGroupAtEvent(uint32 creature_id, WorldObject* pRewardSource) {
            if (!pRewardSource) return;
            ObjectGuid creature_guid;
            if (pRewardSource->IsCreature() && pRewardSource->GetEntry() == creature_id)
                creature_guid = pRewardSource->GetGUID();
            if (Group* group = GetGroup()) {
                Player* player = group->GetFirstMember()->GetSource();
                player->KilledMonsterCredit(creature_id, creature_guid);
            }
            else KilledMonsterCredit(creature_id, creature_guid);
        }
    ''',
}


class QuestCppCreditTests(unittest.TestCase):
    def collect(self, source, creatures=None, objects=None, broken_core=False,
                relative="src/server/scripts/credit.cpp"):
        with db_snapshot.temporary_directory(Path(__file__).resolve().parents[1] / "reports") as directory:
            path = directory / relative
            path.parent.mkdir(parents=True)
            path.write_text(source, encoding="utf-8")
            for relative, text in CORE_FIXTURES.items():
                target = directory / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                if broken_core:
                    text = text.replace("reqkill == real_entry", "reqkill != real_entry")
                target.write_text(text, encoding="utf-8")
            return cpp.collect(directory, creatures or [{"entry": 2164, "ScriptName": "bear"}], objects or [])

    def test_bound_nested_actor_keeps_literal_and_enum_credits(self):
        source = '''enum Credit { CAPTURED = 11836 };
            class Bear : public CreatureScript {
                Bear() : CreatureScript("bear") {}
                struct AI : public FollowerAI {
                    void Capture(Player* player) {
                        player->KilledMonsterCredit(CAPTURED);
                        player->KilledMonsterCredit(22131, ObjectGuid::Empty);
                    }
                };
                CreatureAI* GetAI(Creature* creature) const { return new AI(creature); }
            };'''
        self.assertEqual(self.collect(source)["credits"], {
            "11836": [["monster", 2164]], "22131": [["monster", 2164]],
        })

    def test_bound_gameobject_actor_and_macro_ai(self):
        source = '''constexpr uint32 CREDIT = 17375;
            class Cage : public GameObjectScript {
                Cage() : GameObjectScript("cage") {}
                void Click(Player* player) { player->KilledMonsterCredit(CREDIT); }
            };
            struct bear : public ScriptedAI {
                void Reward(Player* player) { player->KilledMonsterCredit(11836); }
            }; void AddSC(){RegisterCreatureAI(bear);}'''
        result = self.collect(source, objects={181714: {"ScriptName": "cage"}})
        self.assertEqual(result["credits"], {
            "17375": [["object", 181714]], "11836": [["monster", 2164]],
        })

    def test_bound_group_event_credit_preserves_literal_entry(self):
        source = '''enum Credit { CAPTIVE = 17375 };
            struct bear : public ScriptedAI {
                void Rescue(Player* player) {
                    player->RewardPlayerAndGroupAtEvent(CAPTIVE, me);
                    player->RewardPlayerAndGroupAtEvent(16534, m_creature);
                }
            }; void AddSC(){RegisterCreatureAI(bear);}'''
        self.assertEqual(self.collect(source)["credits"], {
            "17375": [["monster", 2164]], "16534": [["monster", 2164]],
        })

    def test_group_event_requires_player_literal_credit_and_known_reward_source(self):
        source = '''struct bear : public ScriptedAI {
            void F(Player* player, Creature* creature, Player* other, uint32 credit) {
                player->RewardPlayerAndGroupAtEvent(1, creature);
                creature->RewardPlayerAndGroupAtEvent(2, me);
                player->RewardPlayerAndGroupAtEvent(credit, me);
                player->RewardPlayerAndGroupAtEvent(3, other);
            }
        }; void AddSC(){RegisterCreatureAI(bear);}'''
        result = self.collect(source)
        self.assertFalse(result["credits"])
        self.assertEqual(len(result["unsupported"]), 4)

    def test_group_event_can_use_the_same_proven_player_as_reward_source(self):
        source = '''enum Credit { RESCUED = 17678 };
            struct bear : public ScriptedAI {
                void Rescue(Player* owner) {
                    owner->RewardPlayerAndGroupAtEvent(RESCUED, owner);
                }
            }; void AddSC(){RegisterCreatureAI(bear);}'''
        self.assertEqual(self.collect(source)["credits"], {"17678": [["monster", 2164]]})

    def test_group_event_player_source_does_not_approve_a_nonplayer_receiver(self):
        source = '''struct bear : public ScriptedAI {
                void Rescue(Creature* owner) {
                    owner->RewardPlayerAndGroupAtEvent(17678, owner);
                }
            }; void AddSC(){RegisterCreatureAI(bear);}'''
        result = self.collect(source)
        self.assertFalse(result["credits"])
        self.assertEqual(len(result["unsupported"]), 1)

    def test_unregistered_and_unowned_nested_helpers_are_not_actor_proof(self):
        source = '''class Bear : public CreatureScript {
                Bear() : CreatureScript("other") {}
                void Reward(Player* player) { player->KilledMonsterCredit(1); }
            };
            struct bear : public ScriptedAI {
                struct Helper {void Reward(Player* player) {player->KilledMonsterCredit(2);}};
            }; void AddSC(){RegisterCreatureAI(bear);}'''
        self.assertEqual(self.collect(source)["credits"], {})

    def test_nonempty_guid_and_unproven_player_are_rejected(self):
        source = '''struct bear : public ScriptedAI {
            void F(Player* player, Creature* creature) {
                player->KilledMonsterCredit(1, creature->GetGUID());
                creature->KilledMonsterCredit(2);
                unknown->KilledMonsterCredit(3);
            }
            void Other() { player->KilledMonsterCredit(4); }
        }; void AddSC(){RegisterCreatureAI(bear);}'''
        result = self.collect(source)
        self.assertFalse(result["credits"])
        self.assertEqual(len(result["unsupported"]), 4)

    def test_dynamic_ambiguous_and_shadowed_credit_ids_are_rejected(self):
        for prefix, expression, parameter in [
            ("", "credit", "uint32 credit"),
            ("enum A { CREDIT = 1 }; enum B { CREDIT = 2 };", "CREDIT", ""),
            ("constexpr uint32 CREDIT = 1;", "CREDIT", "uint32 CREDIT"),
        ]:
            source = prefix + f'''struct bear : public ScriptedAI {{
                void F(Player* player {',' if parameter else ''} {parameter}) {{
                    player->KilledMonsterCredit({expression});
                }}
            }}; void AddSC(){{RegisterCreatureAI(bear);}}'''
            with self.subTest(expression=expression, prefix=prefix):
                result = self.collect(source)
                self.assertFalse(result["credits"])
                self.assertEqual(len(result["unsupported"]), 1)

    def test_player_variable_scopes_and_shadow_types_are_respected(self):
        source = '''struct bear : public ScriptedAI {
            void F() {
                { Player* player = GetPlayer(); }
                player->KilledMonsterCredit(1);
            }
            void G(Player* player) {
                { Creature* player = GetCreature(); player->KilledMonsterCredit(2); }
            }
        }; void AddSC(){RegisterCreatureAI(bear);}'''
        self.assertFalse(self.collect(source)["credits"])

    def test_comments_strings_and_unrelated_classes_do_not_emit_credit(self):
        source = '''struct bear : public ScriptedAI {
            const char* text = "} player->KilledMonsterCredit(1); {";
            /* player->KilledMonsterCredit(2); */
            void F(Player* player) { player->KilledMonsterCredit(3); }
        }; void AddSC(){RegisterCreatureAI(bear);}
        struct unrelated { void F(Player* player) { player->KilledMonsterCredit(4); } };'''
        self.assertEqual(self.collect(source)["credits"], {"3": [["monster", 2164]]})


    def cauldron_fixture(self):
        source = (Path(__file__).parent / "fixtures/basic_chemistry.cpp").read_text(encoding="utf-8")
        creatures = [{"entry": entry, "ScriptName": script}
                     for entries, script in (((31773, 32427, 32442), "npc_plague_cauldron_target"),
                                             ((31880, 32431, 32445), "npc_plague_cauldron_bunny"))
                     for entry in entries]
        return source, creatures

    def test_cauldron_summoners_inherit_only_their_reviewed_helper_credit(self):
        source, creatures = self.cauldron_fixture()
        result = self.collect(source, creatures, relative=cpp.CAULDRON_SOURCE)
        self.assertEqual(result["credits"]["31767"],
                         [["monster", entry] for entry in (31773, 31880, 32427, 32431, 32442, 32445)])
        handoffs = [row for row in result["evidence"]["31767"] if "viaActor" in row]
        self.assertEqual([(row["actor"][1], row["viaActor"][1]) for row in handoffs],
                         [(31773, 31880), (32427, 32431), (32442, 32445)])

    def test_changed_cauldron_handoff_requires_review(self):
        source, creatures = self.cauldron_fixture()
        changes = [
            ("bunny->AI()->SetGUID(player->GetGUID());", "bunny->AI()->SetGUID(ObjectGuid::Empty);"),
            ("_doserGUID = guid;", "_doserGUID = ObjectGuid::Empty;"),
            ("return NPC_CAULDRON_BUNNY_01;", "return NPC_CAULDRON_BUNNY_02;"),
            ("return ObjectAccessor::GetPlayer(*me, _doserGUID);", "return nullptr;"),
            ("NPC_PLAGUE_CAULDRON_KC_BUNNY, me", "NPC_CAULDRON_TARGET_00, me"),
        ]
        for before, after in changes:
            with self.subTest(change=before):
                self.assertIn(before, source)
                result = self.collect(source.replace(before, after), creatures, relative=cpp.CAULDRON_SOURCE)
                for actors in result["credits"].values():
                    self.assertFalse({31773, 32427, 32442} & {actor[1] for actor in actors})

    def test_cauldron_proof_requires_the_matching_helper_binding_and_credit(self):
        source, creatures = self.cauldron_fixture()
        for missing in (31880, 32431, 32445):
            with self.subTest(missing=missing):
                rows = [row for row in creatures if row["entry"] != missing]
                result = self.collect(source, rows, relative=cpp.CAULDRON_SOURCE)
                target = {31880: 31773, 32431: 32427, 32445: 32442}[missing]
                self.assertNotIn(["monster", target], result["credits"]["31767"])

    def test_cauldron_proof_rejects_unreviewed_bindings_paths_and_duplicate_classes(self):
        source, creatures = self.cauldron_fixture()
        result = self.collect(source, creatures + [{"entry": 99999, "ScriptName": "npc_plague_cauldron_target"}],
                              relative=cpp.CAULDRON_SOURCE)
        self.assertNotIn(["monster", 99999], result["credits"]["31767"])
        for changed, relative in ((source, "src/server/scripts/other.cpp"),
                                  (source + "\nstruct npc_plague_cauldron_target {};", cpp.CAULDRON_SOURCE)):
            result = self.collect(changed, creatures, relative=relative)
            self.assertFalse({31773, 32427, 32442} & {actor[1] for actor in result["credits"]["31767"]})

    def test_cauldron_proof_ignores_comments_and_whitespace(self):
        source, creatures = self.cauldron_fixture()
        source = source.replace("_doserGUID = guid;", "_doserGUID /* same player */ =\n guid;")
        result = self.collect(source, creatures, relative=cpp.CAULDRON_SOURCE)
        for entry in (31773, 32427, 32442):
            self.assertIn(["monster", entry], result["credits"]["31767"])

    def test_core_semantics_change_requires_review(self):
        source = '''struct bear : public ScriptedAI {
            void F(Player* player) { player->KilledMonsterCredit(11836); }
        }; void AddSC(){RegisterCreatureAI(bear);}'''
        with self.assertRaisesRegex(ValueError, "Unsupported C\\+\\+ quest credit semantics"):
            self.collect(source, broken_core=True)

    def test_no_template_bindings_need_no_cpp_source(self):
        self.assertEqual(cpp.collect(Path("missing-source"), {}, {}), {
            "credits": {}, "evidence": {}, "unsupported": [],
        })


if __name__ == "__main__":
    unittest.main()
