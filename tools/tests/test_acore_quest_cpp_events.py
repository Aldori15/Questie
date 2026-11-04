import pathlib
import sys
import unittest
from unittest.mock import patch

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

    def escort_source(self, cases=None, extra='', method='WaypointReached', base='npc_escortAI'):
        cases = cases or '''case 13: player->GroupEventHappens(219, me); break;
                            case 15: Talk(0); break;'''
        return f'''struct escort : public {base} {{
            void {method}(uint32 waypointId) override {{
                Player* player = GetPlayerForEscort();
                if (!player) return;
                switch (waypointId) {{ {cases} }}
            }}
            {extra}
            }}; void AddSC(){{RegisterCreatureAI(escort);}}'''

    def test_escort_completion_uses_credited_point_before_path_end(self):
        result = self.collect(self.escort_source())
        self.assertEqual(result['events'], {'219': [['monster', 349]]})
        self.assertEqual([(row['questId'], row['npcId'], row['pointId'])
                          for row in result['escortWaypoints']], [(219, 349, 13)])
        proof = result['escortWaypoints'][0]
        self.assertEqual(proof['script'], 'escort')
        self.assertEqual(proof['class'], 'escort')

    def test_separate_escort_cases_keep_quest_and_point_relationship(self):
        source = self.escort_source('''case 13: player->GroupEventHappens(219, me); break;
            case 42: player->GroupEventHappens(731, me); break;''')
        result = self.collect(source)
        self.assertEqual([(row['questId'], row['pointId']) for row in result['escortWaypoints']],
                         [(219, 13), (731, 42)])

    def test_escort_comments_and_strings_do_not_invent_waypoints_or_mutators(self):
        source = self.escort_source(extra='''const char* text = "AddWaypoint(99); case 99:";
            /* void WaypointReached(uint32 x) { AddWaypoint(4); } */''')
        self.assertEqual(self.collect(source)['escortWaypoints'][0]['pointId'], 13)

    def test_escort_requires_direct_base_waypoint_callback_and_escort_player(self):
        for source in [self.escort_source(method='Finish'), self.escort_source(base='OtherEscortAI'),
                       self.escort_source().replace('GetPlayerForEscort()', 'GetNearbyPlayer()'),
                       self.escort_source().replace('GroupEventHappens(219, me)', 'GroupEventHappens(219, player)'),
                       self.escort_source().replace('Player* player =', 'Creature* player ='),
                       self.escort_source().replace('if (!player) return;', 'if (!player) return; player = OtherPlayer();')]:
            with self.subTest(source=source):
                self.assertFalse(self.collect(source)['escortWaypoints'])

    def test_escort_rejects_path_changes_entry_swaps_and_manual_callbacks(self):
        for extra in ['void Change() { AddWaypoint(1, 2, 3, 4); }',
                      'void Change() { SetNextWaypoint(14); }',
                      'void Change() { me->NearTeleportTo(1, 2, 3, 4); }',
                      'void Change() { me->UpdateEntry(123); }',
                      'void Change() { me->GetMotionMaster()->MovePath(1, false); }',
                      'void MovementInform(uint32 type, uint32 point) override {}',
                      'void Change() { WaypointReached(13); }',
                      'void Change() { WaypointList.clear(); }']:
            with self.subTest(extra=extra):
                result = self.collect(self.escort_source(extra=extra))
                self.assertTrue(result['events'])
                self.assertFalse(result['escortWaypoints'])

    def test_escort_rejects_ambiguous_cases_fallthrough_and_unrelated_switches(self):
        for cases in ['case 12: Talk(0); case 13: player->GroupEventHappens(219, me); break;',
                      'case 13: player->GroupEventHappens(219, me); case 15: Talk(0); break;',
                      'case 13: player->GroupEventHappens(219, me); break; case 13: Talk(0); break;',
                      'case UNKNOWN: player->GroupEventHappens(219, me); break;',
                      'default: player->GroupEventHappens(219, me); break;',
                      'case 12: if (condition) break; case 13: player->GroupEventHappens(219, me); break;',
                      'case 13: switch (other) { case 14: player->GroupEventHappens(219, me); break; } break;']:
            with self.subTest(cases=cases):
                self.assertFalse(self.collect(self.escort_source(cases))['escortWaypoints'])

    def test_escort_callback_parameter_must_be_unmodified_switch_selector(self):
        for source in [self.escort_source().replace('switch (waypointId)', 'switch (other)'),
                       self.escort_source().replace('if (!player) return;', 'if (!player) return; ++waypointId;'),
                       self.escort_source().replace('if (!player) return;', 'if (!player) return; waypointId = 13;')]:
            with self.subTest(source=source):
                self.assertFalse(self.collect(source)['escortWaypoints'])

    def test_escort_rejects_hidden_base_methods_and_movement_aliases(self):
        for extra in ['Player* GetPlayerForEscort() const { return OtherPlayer(); }',
                      'void Start(bool active, ObjectGuid player) { OtherPath(); }',
                      'void Change() { Creature* body = me; body->GetMotionMaster()->MovePath(1, false); }',
                      'void Change() { auto* body = m_creature; body->GetMotionMaster()->Clear(); }',
                      'void Change() { auto* ai = this; ai->OtherPath(); }',
                      'void Change() { Creature* body(me); body->GetMotionMaster()->MovePath(1, false); }',
                      'void Change() { auto& ai = *this; ai.OtherPath(); }']:
            with self.subTest(extra=extra):
                result = self.collect(self.escort_source(extra=extra))
                self.assertTrue(result['events'])
                self.assertFalse(result['escortWaypoints'])

    def test_escort_player_if_initializer_is_supported(self):
        source = self.escort_source().replace('Player* player = GetPlayerForEscort();\n                if (!player) return;',
                                              'if (Player* player = GetPlayerForEscort()) {')
        source = source.replace('case 15: Talk(0); break;', 'case 15: Talk(0); break; }')
        self.assertEqual(self.collect(source)['escortWaypoints'][0]['pointId'], 13)

    def test_other_waypoint_movement_does_not_invalidate_direct_credit(self):
        source = self.escort_source('''case 22: me->GetMotionMaster()->MovePoint(0, 1, 2, 3); break;
            case 24: player->GroupEventHappens(12027, me); break;''')
        self.assertEqual(self.collect(source)['escortWaypoints'][0]['pointId'], 24)
        moving_credit = source.replace('case 24: player->',
                                       'case 24: me->GetMotionMaster()->MovePoint(0, 1, 2, 3); player->')
        self.assertFalse(self.collect(moving_credit)['escortWaypoints'])

    def test_braced_waypoint_cases_retain_exact_credit_point(self):
        source = self.escort_source('''case 3: { Talk(0); break; }
            case 7: { player->GroupEventHappens(9879, me); break; }''')
        self.assertEqual(self.collect(source)['escortWaypoints'][0]['pointId'], 7)

    def test_gossip_credit_uses_bound_actor_and_direct_callback_player(self):
        source = '''class Escort : public CreatureScript {
            Escort() : CreatureScript("escort") {}
            bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override {
                player->GroupEventHappens(6566, creature); return true;
            }
        };'''
        packet = self.collect(source)
        self.assertEqual(packet['events'], {'6566': [['monster', 349]]})
        self.assertEqual([(row['questId'], row['actor'], row['method']) for row in packet['interactionCredits']],
                         [(6566, ['monster', 349], 'OnGossipSelect')])
        reassigned = source.replace('player->GroupEventHappens', 'player = OtherPlayer(); player->GroupEventHappens')
        self.assertFalse(self.collect(reassigned)['interactionCredits'])
        wrong_method = source.replace('OnGossipSelect', 'SomeOtherMethod')
        self.assertFalse(self.collect(wrong_method)['interactionCredits'])

    def test_gameobject_gossip_and_ai_gossip_callbacks_are_supported(self):
        source = '''class Object : public GameObjectScript {
            Object() : GameObjectScript("object_script") {}
            bool OnGossipHello(Player* player, GameObject* go) override {
                player->AreaExploredOrEventHappens(2936); return true;
            }
        };
        struct escort : public ScriptedAI {
            void sGossipSelect(Player* player, uint32 menu, uint32 option) override {
                player->AreaExploredOrEventHappens(6566);
            }
        }; void AddSC() { RegisterCreatureAI(escort); }'''
        packet = self.collect(source, objects=[{'entry': 142715, 'ScriptName': 'object_script'}])
        self.assertEqual({(row['questId'], tuple(row['actor'])) for row in packet['interactionCredits']},
                         {(2936, ('object', 142715)), (6566, ('monster', 349))})

    def follower_source(self):
        return '''enum Follow { QUEST=1560, DEST=6015 };
            struct escort : public FollowerAI {
                void MoveInLineOfSight(Unit* who) override {
                    FollowerAI::MoveInLineOfSight(who);
                    if (!me->GetVictim() && who->GetEntry() == DEST) {
                        if (me->IsWithinDistInMap(who, INTERACTION_DISTANCE)) {
                            Player* player = GetLeaderForFollower();
                            if (player) player->GroupEventHappens(QUEST, me);
                        }
                    }
                }
            }; void AddSC() { RegisterCreatureAI(escort); }'''

    def test_follower_destination_requires_positive_entry_distance_and_leader(self):
        packet = self.collect(self.follower_source())
        self.assertEqual([(row['questId'], row['destinationNpcId'], row['radius'])
                          for row in packet['followerDestinations']], [(1560, 6015, 5)])
        for old, new in [('== DEST', '!= DEST'), ('&& who->GetEntry()', '|| who->GetEntry()'),
                         ('GetLeaderForFollower()', 'GetNearbyPlayer()'),
                         ('INTERACTION_DISTANCE', '500.0f'), ('public FollowerAI', 'public OtherAI')]:
            with self.subTest(new=new):
                self.assertFalse(self.collect(self.follower_source().replace(old, new))['followerDestinations'])

    def test_native_coordinate_credit_requires_enclosing_bounded_distance(self):
        source = '''struct escort : public PassiveAI {
            void UpdateAI(uint32 diff) override {
                if (me->GetDistance(-332.2f, -2.8f, -152.8f) < 5.0f) {
                    if (Player* player = ObjectAccessor::GetPlayer(*me, guid))
                        player->GroupEventHappens(2904, me);
                }
            }
        }; void AddSC() { RegisterCreatureAI(escort); }'''
        proof = self.collect(source)['coordinateCredits'][0]
        self.assertEqual((proof['questId'], proof['position_x'], proof['position_y'], proof['position_z']),
                         (2904, -332.2, -2.8, -152.8))
        for old, new in [('< 5.0f', '> 5.0f'), ('< 5.0f', '< 500.0f'),
                         ('-332.2f', '1e999'), ('me->GetDistance', 'other->GetDistance')]:
            self.assertFalse(self.collect(source.replace(old, new))['coordinateCredits'])

    def test_reviewed_delayed_escort_and_display_hint_expire_when_source_changes(self):
        source = '''struct escort : public npc_escortAI {
            void UpdateAI(uint32 diff) override {
                if (Player* player = GetPlayerForEscort()) player->GroupEventHappens(11570, me);
            }
        }; void AddSC() { RegisterCreatureAI(escort); }'''
        masked = cpp._mask(source)
        scope = cpp._classes(masked)[0]
        digest = cpp._source_digest(masked, scope)
        reviewed = {('src/server/scripts/event.cpp', 'escort'):
                    (digest, {'pointId': 41, 'requireLastPoint': True, 'minimumWaitMs': 12500})}
        with patch.object(cpp, 'REVIEWED_ESCORTS', reviewed):
            proof = self.collect(source)['escortWaypoints'][0]
            self.assertEqual((proof['pointId'], proof['minimumWaitMs']), (41, 12500))
            self.assertFalse(self.collect(source.replace('11570', '11571'))['escortWaypoints'])
        direct = self.escort_source()
        digest = cpp._source_digest(cpp._mask(direct), cpp._classes(cpp._mask(direct))[0])
        with patch.object(cpp, 'REVIEWED_ESCORTS', {('src/server/scripts/event.cpp', 'escort'):
                          (digest, {'pointId': 13, 'displayZone': 40})}):
            self.assertEqual(self.collect(direct)['escortWaypoints'][0]['displayZone'], 40)

    def test_reviewed_proximity_credit_requires_unchanged_source(self):
        source = '''struct escort : public ScriptedAI {
            void Finish(Player* player) { player->AreaExploredOrEventHappens(13930); }
        }; void AddSC() { RegisterCreatureAI(escort); }'''
        masked = cpp._mask(source)
        digest = cpp._source_digest(masked, cpp._classes(masked)[0])
        with patch.object(cpp, 'CHILDRENS_WEEK', 'src/server/scripts/event.cpp'), \
             patch.object(cpp, 'REVIEWED_PROXIMITY', {'escort': digest}):
            packet = self.collect(source)
            self.assertEqual(packet['proximityCredits'][0]['questId'], 13930)
            self.assertTrue(packet['proximityCredits'][0]['requiresStationary'])
            self.assertFalse(self.collect(source.replace('13930', '13931'))['proximityCredits'])

    def test_reviewed_children_selector_scopes_each_quest_to_its_actual_trigger(self):
        names = list(cpp.CHILDREN_DESTINATIONS)
        quest_names = [name for values in cpp.CHILDREN_DESTINATIONS.values() for name in values]
        definitions = [f'{name}={100+i}' for i, name in enumerate(names)]
        definitions += [f'{name}={200+i}' for i, name in enumerate(quest_names)]
        definitions += ['NPC_SILVERMOON_01_CW_TRIGGER=22866', 'QUEST_NOW_WHEN_I_GROW_UP=11975']
        cases = []
        for name, quests in cpp.CHILDREN_DESTINATIONS.items():
            expression = quests[0] if len(quests) == 1 else f'player->GetTeamId() ? {quests[0]} : {quests[1]}'
            cases.append(f'case {name}: questId={expression}; break;')
        cases.append('case NPC_SILVERMOON_01_CW_TRIGGER: player->AreaExploredOrEventHappens(QUEST_NOW_WHEN_I_GROW_UP); break;')
        source = 'enum Names {'+','.join(definitions)+'};' + '''
            class npc_cw_area_trigger : public CreatureScript {
                npc_cw_area_trigger() : CreatureScript("npc_cw_area_trigger") {}
                struct AI : public ScriptedAI {
                    void MoveInLineOfSight(Unit* who) override {
                        if (Player* player = who->ToPlayer()) {
                            uint32 questId=0;
                            switch (me->GetEntry()) {'''+' '.join(cases)+'''}
                            if (questId) player->AreaExploredOrEventHappens(questId);
                        }
                    }
                };
                CreatureAI* GetAI(Creature* creature) const override { return new AI(creature); }
            };'''
        masked = cpp._mask(source)
        scope = next(row for row in cpp._classes(masked) if row['name'] == 'npc_cw_area_trigger')
        digest = cpp._source_digest(masked, scope)
        creatures = [{'entry': entry, 'ScriptName': 'npc_cw_area_trigger'} for entry in list(range(100, 107))+[22866]]
        with patch.object(cpp, 'CHILDRENS_WEEK', 'src/server/scripts/event.cpp'), \
             patch.object(cpp, 'REVIEWED_CHILDREN_TRIGGER', digest):
            packet = self.collect(source, creatures=creatures)
            self.assertEqual(packet['events']['11975'], [['monster', 22866]])
            self.assertEqual(packet['events']['200'], [['monster', 100]])
            self.assertEqual(packet['events']['201'], [['monster', 100]])
            self.assertEqual(len(packet['proximityCredits']), 9)
            changed = self.collect(source.replace('uint32 questId=0', 'uint32 questId=1'), creatures=creatures)
            self.assertFalse(changed['proximityCredits'])
            self.assertFalse(changed['events'])


if __name__ == '__main__':
    unittest.main()
