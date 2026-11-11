// Reviewed cauldron scripts from AzerothCore df405cce050179efa7cf1e3c79397bbc5a1e1617.
// Only the enum and two actors used by the summon-credit proof are retained.

enum BasicChemistry
{
    NPC_PLAGUE_CAULDRON_KC_BUNNY        = 31767,
    NPC_CAULDRON_TARGET_00              = 31773,
    NPC_CAULDRON_BUNNY_00               = 31880,
    NPC_PLAGUE_DRENCHED_GHOUL           = 32176,
    NPC_RAMPAGING_GHOUL                 = 32178,
    NPC_CAULDRON_TARGET_01              = 32427,
    NPC_CAULDRON_BUNNY_01               = 32431,
    NPC_CAULDRON_TARGET_02              = 32442,
    NPC_CAULDRON_BUNNY_02               = 32445,

    SPELL_PIERCE_ARMOR                  = 6016,
    SPELL_ORANGE_RADIATION              = 45797,
    SPELL_DISEASE_CLOUD                 = 50106,
    SPELL_NEUTRALIZING_DOSE_APPLIED     = 59659,
    SPELL_EVENT_TIMER_BUFF              = 59872,
    SPELL_FLUID_TIMER_BUFF              = 59873,
    SPELL_CAULDRON_EVENT_FAILED         = 59874,
    SPELL_CAULDRON_EVENT_COMPLETE       = 59875,
    SPELL_HUGE_GREEN_SPLASH             = 60059,
    SPELL_PLAGUE_BITE                   = 60678,
    SPELL_EMERGE                        = 66947,

    // creature_text of the cauldron targets
    SAY_CAULDRON_BOILS                  = 0,

    // creature_text of the cauldron bunnies
    SAY_WAVE_EMERGES                    = 0,
    SAY_WAVE_EMPTY                      = 1,
    SAY_EVENT_COMPLETE                  = 2,
    SAY_FLUID_LOW                       = 3,
    SAY_FLUID_CRITICAL                  = 4,
    SAY_EVENT_FAILED                    = 5,

    // creature_summon_groups of the cauldron bunnies
    GROUP_PLAGUE_SWARM                  = 0,
    GROUP_GHOUL_AND_PLAGUE              = 1,
    GROUP_GHOUL_PAIR                    = 2,
    GROUP_DRENCHED_GHOUL                = 3,
    GROUP_NOTHING                       = 4,

    ACTION_ADD_FLUID                    = 1,
    ACTION_EVENT_FAILED                 = 2,
    ACTION_EVENT_COMPLETE               = 3,

    DATA_GHOUL_JUMP                     = 1,

    POINT_GHOUL_LANDED                  = 1
};

struct npc_plague_cauldron_target : public ScriptedAI
{
    npc_plague_cauldron_target(Creature* creature) : ScriptedAI(creature) { }

    void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_NEUTRALIZING_DOSE_APPLIED)
            return;

        Player* player = caster ? caster->ToPlayer() : nullptr;
        if (!player)
            return;

        // A dose landing while the event is up reschedules the waves and warnings
        if (Creature* bunny = me->FindNearestCreature(GetBunnyEntry(), 5.0f))
        {
            bunny->AI()->DoAction(ACTION_ADD_FLUID);
            return;
        }

        DoCastSelf(SPELL_ORANGE_RADIATION, true);
        Talk(SAY_CAULDRON_BOILS, player);

        if (Creature* bunny = me->SummonCreature(GetBunnyEntry(), me->GetPositionX(), me->GetPositionY(),
            me->GetPositionZ() + 0.0833f, me->GetOrientation(), TEMPSUMMON_TIMED_DESPAWN, 250 * IN_MILLISECONDS))
        {
            bunny->AI()->SetGUID(player->GetGUID());
        }
    }

    void SummonedCreatureDespawn(Creature* /*summon*/) override
    {
        me->RemoveAurasDueToSpell(SPELL_ORANGE_RADIATION);
    }

private:
    uint32 GetBunnyEntry() const
    {
        switch (me->GetEntry())
        {
            case NPC_CAULDRON_TARGET_01:
                return NPC_CAULDRON_BUNNY_01;
            case NPC_CAULDRON_TARGET_02:
                return NPC_CAULDRON_BUNNY_02;
            default:
                return NPC_CAULDRON_BUNNY_00;
        }
    }
};

struct npc_plague_cauldron_bunny : public ScriptedAI
{
    npc_plague_cauldron_bunny(Creature* creature) : ScriptedAI(creature)
    {
        me->SetReactState(REACT_PASSIVE);
    }

    void SetGUID(ObjectGuid const& guid, int32 /*id*/) override
    {
        _doserGUID = guid;
    }

    void IsSummonedBy(WorldObject* /*summoner*/) override
    {
        DoCastSelf(SPELL_EVENT_TIMER_BUFF, true);
        AddFluid();
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_ADD_FLUID:
                AddFluid();
                break;
            case ACTION_EVENT_FAILED:
                DoCastSelf(SPELL_CAULDRON_EVENT_FAILED, true);
                Talk(SAY_EVENT_FAILED, GetDoser());
                EndEvent();
                break;
            case ACTION_EVENT_COMPLETE:
            {
                DoCastSelf(SPELL_CAULDRON_EVENT_COMPLETE, true);

                Player* doser = GetDoser();
                Talk(SAY_EVENT_COMPLETE, doser);

                if (doser)
                    doser->RewardPlayerAndGroupAtEvent(NPC_PLAGUE_CAULDRON_KC_BUNNY, me);

                EndEvent();
                break;
            }
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        scheduler.Update(diff);
    }

private:

    void EndEvent()
    {
        scheduler.CancelAll();
        me->DespawnOrUnsummon(500ms);
    }

    // Adding a dose schedules two waves and the warnings
    // Adding another dose during the event just re-schedules these
    void AddFluid()
    {
        DoCastSelf(SPELL_FLUID_TIMER_BUFF, true);

        scheduler.CancelAll();
        scheduler.Schedule(5s, [this](TaskContext /*context*/)
        {
            SummonWave();
        }).Schedule(30s, [this](TaskContext /*context*/)
        {
            SummonWave();
        }).Schedule(46s, [this](TaskContext /*context*/)
        {
            Talk(SAY_FLUID_LOW, GetDoser());
        }).Schedule(58s, [this](TaskContext /*context*/)
        {
            Talk(SAY_FLUID_CRITICAL, GetDoser());
        });
    }

    void SummonWave()
    {
        uint8 const group = RollWaveGroup();

        // A tick that rolls nothing is silent apart from the line
        if (group == GROUP_NOTHING)
        {
            Talk(SAY_WAVE_EMPTY, GetDoser());
            return;
        }

        DoCastSelf(SPELL_HUGE_GREEN_SPLASH);
        Talk(SAY_WAVE_EMERGES, GetDoser());

        std::list<TempSummon*> summons;
        me->SummonCreatureGroup(group, &summons);

        // No group mixes the two ghoul entries, so one counter walking the list in row order is
        // enough to tell a paired group's two ghouls apart.
        uint32 slot = 0;
        for (TempSummon* summon : summons)
            if (summon->GetEntry() == NPC_RAMPAGING_GHOUL || summon->GetEntry() == NPC_PLAGUE_DRENCHED_GHOUL)
                summon->AI()->SetData(DATA_GHOUL_JUMP, GhoulJumpId(me->GetEntry(), group, slot++));
    }

    uint8 RollWaveGroup() const
    {
        uint8 roll = urand(0, 99);
        for (WaveChance const& wave : WaveChances)
        {
            if (roll < wave.chance)
                return wave.group;

            roll -= wave.chance;
        }

        return GROUP_NOTHING;
    }

    Player* GetDoser() const
    {
        return ObjectAccessor::GetPlayer(*me, _doserGUID);
    }

    ObjectGuid _doserGUID;
};

void AddSC_icecrown()
{
    RegisterCreatureAI(npc_plague_cauldron_target);
    RegisterCreatureAI(npc_plague_cauldron_bunny);
}
