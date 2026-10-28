import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import acore_quest_cpp_events as cpp
import db_snapshot


class QuestCppEventTests(unittest.TestCase):
    def collect(self, source, creatures=None, objects=None):
        with db_snapshot.temporary_directory(pathlib.Path(__file__).resolve().parents[1]/'reports') as directory:
            path = directory/'src/server/scripts/event.cpp'
            path.parent.mkdir(parents=True)
            path.write_text(source, encoding='utf-8')
            return cpp.collect(directory, creatures or [{'entry': 349, 'ScriptName': 'escort'}], objects or [])

    def test_bound_nested_escort_ai_uses_enum_and_literal_quest(self):
        source = '''enum Quests { QUEST_ESCORT = 219 };
            class Escort : public CreatureScript {
                Escort() : CreatureScript("escort") {}
                struct EscortAI : public npc_escortAI {
                    void Finish() { player->GroupEventHappens(QUEST_ESCORT, me);
                                    player->AreaExploredOrEventHappens(220); }
                };
                CreatureAI* GetAI(Creature* c) const override { return new EscortAI(c); }
            };'''
        result = self.collect(source)
        self.assertEqual(result['events'], {'219': [['monster', 349]], '220': [['monster', 349]]})

    def test_macro_registered_ai_and_constexpr(self):
        source = '''constexpr uint32 QUEST = 123;
            struct escort : public EscortAI { void Finish() { player->GroupEventHappens(QUEST, m_creature); } };
            void AddSC_event() { RegisterCreatureAI(escort); }'''
        self.assertEqual(self.collect(source)['events'], {'123': [['monster', 349]]})

    def test_gameobject_actor_and_unrelated_classes_stay_separate(self):
        source = '''class Go : public GameObjectScript {
                Go() : GameObjectScript("object_script") {}
                void Click() { player->AreaExploredOrEventHappens(123); }
            };
            class Other { void Finish() { player->AreaExploredOrEventHappens(456); } };'''
        result = self.collect(source, objects=[{'entry': 1, 'ScriptName': 'object_script'}])
        self.assertEqual(result['events'], {'123': [['object', 1]]})

    def test_wrong_registration_does_not_prove_template_actor(self):
        for source in [
            'class Escort : public CreatureScript { Escort(): CreatureScript("other") {} void F(){p->GroupEventHappens(219,me);} };',
            'struct escort : public EscortAI { void F(){p->GroupEventHappens(219,me);} }; void AddSC(){RegisterCreatureAI(other);}',
        ]:
            with self.subTest(source=source):
                self.assertFalse(self.collect(source)['events'])

    def test_dynamic_and_ambiguous_quest_constants_are_rejected(self):
        for expression, prefix in [('questId', ''), ('QUEST', 'enum A{QUEST=219}; enum B{QUEST=220};'),
                                   ('QUEST', 'constexpr uint32 QUEST=219;')]:
            method = 'void F(uint32 QUEST)' if prefix.startswith('constexpr') else 'void F()'
            source = prefix + f'''struct escort : public EscortAI {{ {method} {{p->GroupEventHappens({expression},me);}} }};
                void AddSC(){{RegisterCreatureAI(escort);}}'''
            with self.subTest(expression=expression, prefix=prefix):
                result = self.collect(source)
                self.assertFalse(result['events'])
                self.assertTrue(result['unsupported'])

    def test_unrelated_group_actor_and_unowned_nested_class_are_rejected(self):
        source = '''class Escort : public CreatureScript { Escort(): CreatureScript("escort") {}
            void F(){p->GroupEventHappens(219,other);}
            struct Helper {void F(){p->AreaExploredOrEventHappens(220);}};
            };'''
        self.assertFalse(self.collect(source)['events'])

    def test_comments_and_string_braces_do_not_change_class_ownership(self):
        source = '''struct escort : public EscortAI {
            const char* text = "} { GroupEventHappens(999,me)";
            /* } AreaExploredOrEventHappens(888); */
            void F(){p->GroupEventHappens(219,me);}
            }; void AddSC(){RegisterCreatureAI(escort);}'''
        self.assertEqual(self.collect(source)['events'], {'219': [['monster', 349]]})

    def test_bound_player_completion_and_player_group_actor_are_retained(self):
        source = '''enum QuestIds { QUEST = 3525 };
            struct escort : public EscortAI {
                void Finish(Player* player) {
                    player->CompleteQuest(QUEST);
                    player->GroupEventHappens(5821, player);
                }
                void Nearby(WorldObject* object) {
                    if (Player* nearby = object->ToPlayer()) {
                        nearby->CompleteQuest(5943);
                    }
                }
            }; void AddSC(){RegisterCreatureAI(escort);}'''
        self.assertEqual(self.collect(source)['events'], {
            '3525': [['monster', 349]], '5821': [['monster', 349]],
            '5943': [['monster', 349]],
        })

    def test_completion_requires_player_type_and_matching_group_actor(self):
        source = '''struct escort : public EscortAI {
                void Finish(Creature* player, Player* other) {
                    player->CompleteQuest(3525);
                    other->GroupEventHappens(5821, player);
                }
                void Unknown() { player->CompleteQuest(5943); }
                void Dynamic(Player* player, uint32 questId) {
                    player->CompleteQuest(questId);
                }
            }; void AddSC(){RegisterCreatureAI(escort);}'''
        result = self.collect(source)
        self.assertFalse(result['events'])
        self.assertEqual(len(result['unsupported']), 4)

    def test_player_declaration_in_another_method_or_closed_block_is_rejected(self):
        source = '''struct escort : public EscortAI {
                void Earlier(Player* player) { player->GetGUID(); }
                void Finish() { player->CompleteQuest(3525); }
                void Blocks() {
                    { Player* player = GetPlayer(); }
                    player->GroupEventHappens(5821, player);
                }
                void Shadow(Player* player) {
                    { Creature* player = GetCreature(); player->CompleteQuest(5943); }
                }
            }; void AddSC(){RegisterCreatureAI(escort);}'''
        self.assertFalse(self.collect(source)['events'])

    def test_unbound_completion_actor_is_rejected(self):
        source = '''struct other : public EscortAI {
                void Finish(Player* player) { player->CompleteQuest(3525); }
            }; void AddSC(){RegisterCreatureAI(other);}'''
        self.assertFalse(self.collect(source)['events'])


if __name__ == '__main__':
    unittest.main()
