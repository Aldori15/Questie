"""Fixed summons need real SmartAI callers, current coordinates and map context."""
import copy
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import acore_scripted_geometry as scripts
import generate_acore_npc_corrections as reader
import generate_acore_npc_base as base
import audit_acore_npc_sources as audit


def action(kind, owner, index, typ, first=0, second=0, target=1, **values):
    return dict(source_type=kind, entryorguid=owner, id=index, link=0, action_type=typ,
                action_param1=first, action_param2=second, target_type=target, **values)


class ScriptedGeometryTests(unittest.TestCase):
    def fixture(self):
        rows = [action(0, 10, 0, 80, 501), action(9, 501, 0, 80, 9000123),
                action(9, 9000123, 0, 12, 20, target=8, target_x=30, target_y=40, target_z=0),
                action(0, 20, 0, 53, 1, 7)]
        creatures = {10: [{"guid": 11, "id": 10, "map": 0, "zoneId": 12, "phaseMask": 1,
                           "position_x": 1, "position_y": 2, "position_z": 999}]}
        templates = {i: {"AIName": "SmartAI", "ScriptName": ""} for i in (10, 20, 30)}
        paths = {7: [{"pointid": 1, "position_x": 31, "position_y": 41, "position_z": 0},
                     {"pointid": 2, "position_x": 32, "position_y": 42, "position_z": 1}]}
        return rows, creatures, templates, paths

    def collect(self, rows, creatures, templates, paths):
        def project(row, maps):
            if row.get("map") != 0 or row.get("position_x") == 999:
                return None, None
            self.assertNotIn("guid", row)  # A summoned copy never borrows a static GUID.
            return 12, [row["position_x"], row["position_y"]]
        with patch.object(reader, "resolve_coordinate_zone", side_effect=project):
            return scripts.collect(rows, creatures, {11: creatures[10][0]}, templates,
                                   {"instance_to_zone": {}}, paths)

    def build(self, packet):
        source = {20: {"s:name": "Summoned NPC", "s:spawns": {}, "s:waypoints": {}}}
        manifest = base.upgrade_manifest(base.make_manifest(source, source, {}, "snapshot", {}), source, {})
        manifest["geometry"]["20"] = {field: {"slots": {}, "sourceScripted": True}
                                       for field in ("spawns", "waypoints")}
        return base.build_records(source, manifest, {"scriptedGeometry": packet})

    def test_nested_self_calls_derive_map_without_guessing_owner_from_list_id(self):
        packet = self.collect(*self.fixture())
        data = packet["entries"]["20"]
        self.assertEqual(data["spawns"], audit.typed({12: [[30, 40]]}))
        self.assertEqual(data["waypoints"], audit.typed({12: [[[31, 41], [32, 42]]]}))
        self.assertEqual(data["origins"]["spawns"]["n:12"]["n:1"], ["smart-summon:9:9000123:0:0:map:0"])
        self.assertFalse(data["failures"]["spawns"])
        self.assertEqual(self.build(packet)[20]["s:spawns"], data["spawns"])

    def test_real_shattrath_summon_keeps_city_map_context_and_its_own_height(self):
        rows = [action(0, 19270, 13, 80, 1927000),
                action(9, 1927000, 0, 12, 19228, target=8,
                       target_x=-1747.62, target_y=5126.94, target_z=-35.788),
                action(0, 19228, 1, 53, 1, 19228)]
        parent = {"id": 19270, "guid": 68835, "map": 530, "zoneId": 3703, "phaseMask": 1,
                  "position_x": -1751.44, "position_y": 5167.03, "position_z": -37.2049}
        paths = {19228: [{"pointid": 1, "position_x": -1748.81, "position_y": 5131.2, "position_z": -35.7738},
                         {"pointid": 2, "position_x": -1749.06, "position_y": 5132.2, "position_z": -36.0238}]}
        packet = scripts.collect(rows, {19270: [parent]}, {68835: parent},
                                 {i: {"AIName": "SmartAI", "ScriptName": ""} for i in (19270, 19228)},
                                 reader.parse_zone_maps(ADDON_ROOT), paths)
        data = packet["entries"]["19228"]
        self.assertEqual(data["spawns"], audit.typed({3703: [[77.19, 31.43]]}))
        self.assertEqual(data["waypoints"], audit.typed({3703: [[[76.87, 31.56], [76.79, 31.59]]]}))
        self.assertNotIn("n:8", data["spawns"]["n:3703"]["n:1"])

    def test_future_source_moves_paths_and_deletions_refresh_without_legacy_fallback(self):
        rows, creatures, templates, paths = self.fixture()
        original = self.build(self.collect(rows, creatures, templates, paths))
        rows[2]["target_x"] = 35
        paths[7][1]["position_y"] = 43
        fresh = self.build(self.collect(rows, creatures, templates, paths))
        self.assertNotEqual(original, fresh)
        self.assertEqual(fresh[20]["s:spawns"], audit.typed({12: [[35, 40]]}))
        self.assertEqual(fresh[20]["s:waypoints"], audit.typed({12: [[[31, 41], [32, 43]]]}))
        rows.remove(rows[2])
        deleted = self.build(self.collect(rows, creatures, templates, paths))
        self.assertEqual(deleted[20]["s:spawns"], {})
        self.assertEqual(deleted[20]["s:waypoints"], {})

    def test_unsupported_summon_changes_block_opted_in_entries(self):
        for mutation in (lambda r, c, t, p: r[2].update(target_type=1),
                         lambda r, c, t, p: r[2].update(action_param6=1),
                         lambda r, c, t, p: r[2].update(target_x=999),
                         lambda r, c, t, p: r[0].update(target_type=19),
                         lambda r, c, t, p: c[10][0].update(phaseMask=4),
                         lambda r, c, t, p: t[20].update(ScriptName="custom"),
                         lambda r, c, t, p: t[10].update(AIName=""),
                         lambda r, c, t, p: r.append(action(0, 20, 8, 44, 4)),
                         lambda r, c, t, p: r.append(action(9, 501, 8, 62, 1))):
            fixture = self.fixture()
            mutation(*fixture)
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "requires review"):
                self.build(self.collect(*fixture))

    def test_ambiguous_maps_and_cyclic_or_unknown_callers_are_not_inferred(self):
        rows, creatures, templates, paths = self.fixture()
        creatures[30] = [dict(creatures[10][0], guid=12, id=30, map=1)]
        rows.append(action(0, 30, 0, 80, 501))
        packet = self.collect(rows, creatures, templates, paths)
        self.assertTrue(packet["entries"]["20"]["failures"]["spawns"])
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            self.build(packet)
        rows.pop()
        rows[0] = action(9, 9000123, 3, 80, 501)
        with self.assertRaisesRegex(ValueError, "cyclic"):
            self.build(self.collect(rows, creatures, templates, paths))
        rows[0] = action(1, 10, 0, 80, 501)
        with self.assertRaisesRegex(ValueError, "supported creature caller"):
            self.build(self.collect(rows, creatures, templates, paths))

    def test_unmapped_path_blocks_only_waypoint_opt_in_and_static_gaps_remain_errors(self):
        rows, creatures, templates, paths = self.fixture()
        paths[7][1]["position_x"] = 999
        packet = self.collect(rows, creatures, templates, paths)
        with self.assertRaisesRegex(ValueError, "path does not map"):
            self.build(packet)
        policy = {"slots": {}, "sourceScripted": True}
        spawns, _ = base.add_scripted_geometry(policy, {}, {}, packet, 20, "spawns")
        self.assertEqual(spawns, audit.typed({12: [[30, 40]]}))
        with self.assertRaisesRegex(ValueError, "Static geometry"):
            base.add_scripted_geometry(policy, base.shared.ABSENT, {}, packet, 20, "spawns")

    def test_metadata_and_source_identity_required_and_supplements_rejected(self):
        packet = self.collect(*self.fixture())
        with self.assertRaisesRegex(ValueError, "refresh the source model"):
            self.build({})
        broken = copy.deepcopy(packet)
        broken["entries"]["20"]["origins"] = {}
        with self.assertRaisesRegex(ValueError, "lacks source identities"):
            self.build(broken)
        policy = {"slots": {"n:12": {"n:1": {"value": audit.typed([90, 90])}}}, "sourceScripted": True}
        with self.assertRaisesRegex(ValueError, "pure source policy"):
            base.add_scripted_geometry(policy, {}, {}, packet, 20, "spawns")

    def test_static_source_and_identities_remain_and_coincident_summons_do_not_duplicate(self):
        packet = self.collect(*self.fixture())
        policy = {"slots": {}, "sourceScripted": True}
        original = audit.typed({12: [[30, 40]], 40: [[50, 60]]})
        origins = {"n:12": {"n:1": ["creature:100:entry:20"]}, "n:40": {"n:1": ["creature:200:entry:20"]}}
        saved = copy.deepcopy((original, origins))
        result, identities = base.add_scripted_geometry(policy, original, origins, packet, 20, "spawns")
        self.assertEqual(result, original)
        self.assertEqual((original, origins), saved)
        self.assertEqual(len(identities["n:12"]["n:1"]), 2)
        self.assertEqual(identities["n:40"]["n:1"], ["creature:200:entry:20"])


if __name__ == "__main__":
    unittest.main()
