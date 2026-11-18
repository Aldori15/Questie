"""Player-placed relic summons need source-area guidance, not fictional spawns."""
import unittest
import struct

from _test_paths import ADDON_ROOT
import acore_quest_summon_guides as guides
from acore_scripted_geometry import typed
import db_snapshot


class RelicSummonGuideTests(unittest.TestCase):
    def dbc(self, rows, fields=8, size=32, magic=b"WDBC"):
        return struct.pack("<4s4I", magic, len(rows), fields, size, 1) + b"".join(
            struct.pack("<8I", *row) for row in rows) + b"\0"

    def test_area_group_reader_resolves_six_members_and_chained_groups(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "AreaGroup.dbc"
            path.write_bytes(self.dbc([(88, 3811, 0, 0, 0, 0, 0, 90), (90, 1, 2, 3, 4, 5, 6, 0)]))
            self.assertEqual(guides.load_area_groups(path), {88: [1, 2, 3, 4, 5, 6, 3811], 90: [1, 2, 3, 4, 5, 6]})

    def test_area_group_reader_rejects_bad_layouts_and_unresolved_chains(self):
        row = (88, 3811, 0, 0, 0, 0, 0, 0)
        cases = [b"", self.dbc([row], magic=b"BAD!"), self.dbc([row], fields=9),
                 self.dbc([row], size=36), self.dbc([row])[:-1], self.dbc([row]) + b"x",
                 self.dbc([row, row]), self.dbc([row[:-1] + (88,)]),
                 self.dbc([row[:-1] + (89,)])]
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            path = directory / "AreaGroup.dbc"
            for data in cases:
                path.write_bytes(data)
                with self.subTest(data=data[:20]), self.assertRaisesRegex(ValueError, "AreaGroup.dbc"):
                    guides.load_area_groups(path)

    def test_changed_core_area_or_summon_semantics_require_review(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as directory:
            for relative, fragments in guides.CORE_REQUIREMENTS.items():
                path = directory / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("\n".join(fragments), encoding="utf-8")
            guides.validate_source(directory)
            path = directory / guides.CORE_SOURCE_FILES[0]
            original = path.read_text(encoding="utf-8")
            path.write_text(original.replace("area_id", "unrelated_id"), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "unsupported core semantics"):
                guides.validate_source(directory)

    def fixture(self):
        quests = {10909: {"ID": 10909, "StartItem": 31772, "RequiredNpcOrGo1": 22454,
                          "RequiredNpcOrGoCount1": 10}}
        items = {31772: {"entry": 31772, "spellid_1": 39183, "spelltrigger_1": 0}}
        spells = {39183: {"ID": 39183, "Effect1": 76, "EffectMiscValue1": 185298,
                           "EffectImplicitTargetA1": 47, "Effect2": 28, "EffectMiscValue2": 22444,
                           "EffectImplicitTargetA2": 47, "AreaGroupId": 88},
                  39184: {"ID": 39184, "Effect1": 6, "EffectApplyAuraName1": 4,
                           "EffectImplicitTargetA1": 22, "EffectImplicitTargetB1": 7},
                  39206: {"ID": 39206, "Effect1": 28, "EffectMiscValue1": 22454,
                           "EffectImplicitTargetA1": 46}}
        def action(owner, event, action, first, **values):
            return dict(source_type=0, entryorguid=owner, event_type=event,
                        action_type=action, action_param1=first, target_type=1, **values)
        scripts = [action(16878, 8, 22, 1, event_param1=39184),
                   action(16878, 6, 11, 39206, event_phase_mask=1, action_param2=2),
                   action(22444, 60, 11, 39184, action_param2=2)]
        conditions = [dict(SourceTypeOrReferenceId=13, SourceGroup=1, SourceEntry=spell,
                           ConditionTypeOrReference=31, ConditionValue1=3, ConditionValue2=npc)
                      for spell, npc in ((39184, 16878), (39206, 22444))]
        spawn = {"guid": 1, "id1": 16878, "areaId": 3811, "phaseMask": 1,
                 "position_x": 30, "position_y": 40}
        spawns = [spawn, dict(spawn, guid=2, position_x=31),
                  dict(spawn, guid=3, areaId=3483, position_x=80),
                  dict(spawn, guid=4, phaseMask=2), dict(spawn, guid=5, ScriptName="override"),
                  dict(spawn, guid=6, id1=22454)]
        return [quests, items, spells, scripts, conditions, spawns, {88: [3811]},
                lambda spawn, quest: (3483, [spawn["position_x"], spawn["position_y"]])]

    def test_only_ordinary_area_members_become_guidance_and_kill_slot_is_preserved(self):
        packet = guides.derive(*self.fixture())
        helper = packet["guides"][10909]["n:1"]
        self.assertEqual(helper["n:1"], typed({3483: [[30, 40], [31, 40]]}))
        self.assertEqual(helper["n:4"], 1)
        self.assertNotIn("n:5", helper)
        self.assertEqual(packet["evidence"][0]["sourceGuids"], [1, 2])
        self.assertEqual(len(packet["omissions"]), 2)

    def test_native_item_column_names_and_normalized_aliases_have_identical_guidance(self):
        args = self.fixture()
        native = guides.derive(*args)
        args[1][31772] = {"entry": 31772, "spellid1": 39183, "spelltrigger1": 0}
        self.assertEqual(guides.derive(*args), native)

    def test_current_positions_and_area_membership_refresh_without_legacy_coordinates(self):
        args = self.fixture()
        before = guides.derive(*args)
        args[5][0]["position_x"] = 33
        args[6][88] = [3483]
        after = guides.derive(*args)
        self.assertNotEqual(before["guides"], after["guides"])
        self.assertEqual(after["guides"][10909]["n:1"]["n:1"], typed({3483: [[80, 40]]}))
        self.assertEqual(after["evidence"][0]["sourceGuids"], [3])

    def test_changed_proof_or_missing_geography_requires_review(self):
        mutations = [lambda a: a[0][10909].update(RequiredNpcOrGo1=999),
                     lambda a: a[1][31772].update(ScriptName="override"),
                     lambda a: a[2][39183].update(EffectMiscValue2=999),
                     lambda a: a[2][39206].update(EffectImplicitTargetA1=1),
                     lambda a: a[2][39184].update(EffectImplicitTargetB1=1),
                     lambda a: a[3][0].update(event_param1=1),
                     lambda a: a[3][1].update(event_phase_mask=0),
                     lambda a: a[3][1].update(action_param2=0),
                     lambda a: a[3][2].update(action_param1=999),
                     lambda a: a[4][1].update(ElseGroup=1),
                     lambda a: a[6].clear(), lambda a: a.__setitem__(5, None),
                     lambda a: a[5].clear(),
                     lambda a: a.__setitem__(7, lambda spawn, quest: (3483, [float("nan"), 1]))]
        for mutate in mutations:
            args = self.fixture()
            mutate(args)
            with self.subTest(mutation=mutate), self.assertRaisesRegex(ValueError, "Quest10909.*review"):
                guides.derive(*args)

    def test_unrelated_quest_sets_need_no_relic_inputs(self):
        self.assertEqual(guides.derive({}, {}, {}, [], [], None, None, None),
                         {"guides": {}, "evidence": [], "omissions": []})


if __name__ == "__main__":
    unittest.main()
