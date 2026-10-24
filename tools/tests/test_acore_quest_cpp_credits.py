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
    def collect(self, source, creatures=None, objects=None, broken_core=False):
        with db_snapshot.temporary_directory(Path(__file__).resolve().parents[1] / "reports") as directory:
            path = directory / "src/server/scripts/credit.cpp"
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
