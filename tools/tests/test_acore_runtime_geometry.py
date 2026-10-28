"""Runtime geometry follows actual fair membership and fixed AC summon events."""
import unittest

from _test_paths import ADDON_ROOT
import acore_runtime_geometry as runtime
import generate_acore_npc_corrections as reader


class RuntimeGeometryTests(unittest.TestCase):
    def setUp(self):
        self.creatures, self.memberships = [], []
        for location, (event, zone) in runtime.DARKMOON_LOCATIONS.items():
            for entry in sorted(runtime.DARKMOON_NPCS):
                guid = location * 100000 + entry
                self.creatures.append({"guid": guid, "id1": entry, "zoneId": zone,
                                       "position_x": location, "position_y": entry,
                                       "phaseMask": 3})
                self.memberships.append({"eventEntry": event, "guid": guid})
        self.events = [{"id": event, "command": 10, "datalong": row[0],
                        "x": 1, "y": 2, "z": 0} for event, row in runtime.SUMMON_EVENTS.items()]

    @staticmethod
    def project(row, maps):
        point = [row["position_x"], row["position_y"]]
        if row.get("guid"):
            point += [None, row["phaseMask"], 0, 1, 0, row["guid"]]
        return row["zoneId"], point

    def collect(self):
        return runtime.collect(self.events, self.creatures, self.memberships, {}, self.project)

    def test_fair_membership_filters_setup_spawns_and_keeps_phase_identity(self):
        setup = dict(self.creatures[0], guid=999999, position_x=99)
        self.creatures.append(setup)
        self.memberships.append({"eventEntry": 23, "guid": 999999})
        packet = self.collect()
        point = packet["darkmoon"]["1"][str(setup["id1"])]["s:spawns"]["n:215"]["n:1"]
        self.assertEqual(point["n:1"], 1)
        self.assertEqual(point["n:4"], 3)
        self.assertEqual(point["n:8"], self.creatures[0]["guid"])
        self.assertNotIn("n:3", point)
        self.assertEqual(packet["darkmoon"]["2"]["14828"]["s:zoneID"], 12)

    def test_source_relocations_and_new_active_spawns_refresh_without_old_coordinates(self):
        row = self.creatures[0]
        row["position_x"] = 7
        extra = dict(row, guid=999999, position_x=8)
        self.creatures.append(extra)
        self.memberships.append({"eventEntry": 5, "guid": extra["guid"]})
        values = self.collect()["darkmoon"]["1"][str(row["id1"])]["s:spawns"]["n:215"]
        self.assertEqual([v["n:1"] for v in values.values()], [7, 8])

    def test_missing_fair_placement_and_wrong_zone_require_review(self):
        self.memberships.pop()
        with self.assertRaisesRegex(ValueError, "Missing Darkmoon"):
            self.collect()
        self.setUp()
        self.creatures[0]["zoneId"] = 267
        with self.assertRaisesRegex(ValueError, "map review"):
            self.collect()

    def test_summon_map_bindings_refresh_source_xyz_without_assigning_a_db_guid(self):
        self.events[0]["x"] = 45
        packet = self.collect()
        point = packet["faction"]["Alliance"]["5676"]["s:spawns"]["n:1519"]["n:1"]
        self.assertEqual(point, {"n:1": 45, "n:2": 2})
        self.assertNotIn("12144", packet["faction"]["Alliance"])
        self.assertNotIn("13778", packet["faction"]["Horde"])
        self.assertEqual(packet["faction"]["Horde"]["5676"]["s:zoneID"], 1637)

    def test_unknown_or_missing_fixed_summon_event_requires_review(self):
        self.events[0]["id"] = 123456
        with self.assertRaisesRegex(ValueError, "Unreviewed fixed summon"):
            self.collect()
        self.setUp()
        self.events.pop()
        with self.assertRaisesRegex(ValueError, "Missing reviewed summon"):
            self.collect()

    def test_fixed_summon_coordinates_and_actual_native_map_transform(self):
        zones = reader.parse_zone_maps(ADDON_ROOT)
        source = {"map": 530, "zoneId": 3433, "position_x": 7931.42,
                  "position_y": -6174.3, "position_z": 40.92}
        self.assertEqual(reader.resolve_coordinate_zone(source, zones), (3433, [27.0, 15.24]))
        self.events[0]["z"] = float('nan')
        with self.assertRaisesRegex(ValueError, "absolute source"):
            self.collect()

    def test_disjoint_event51_subqueries_are_reviewed_but_new_mutations_fail(self):
        statements = [
            "DELETE FROM `game_event_creature` WHERE (`eventEntry` = 51) AND (`guid` IN (SELECT `guid` FROM `creature` WHERE `id1` IN (34382)))",
            "INSERT INTO `game_event_creature` (SELECT 51, `guid` FROM `creature` WHERE `id1` IN (34383))",
            "INSERT INTO `game_event_creature` (`eventEntry`, `guid`) (SELECT 51, `guid` FROM `creature` WHERE `id1` IN (34435,34476))",
        ]
        self.assertEqual(runtime.review_membership_skips(statements), statements)
        self.assertTrue(all(runtime.ignore_unrelated_membership_statement(s) for s in statements))
        for statement in [statements[0].replace('34382', '14828'), statements[1].replace('51', '4'),
                          'UPDATE game_event_creature SET eventEntry=5', statements[2].replace('34435,34476', '')]:
            with self.subTest(statement=statement), self.assertRaises(ValueError):
                runtime.review_membership_skips([statement])
            self.assertFalse(runtime.ignore_unrelated_membership_statement(statement))

    def test_fair_routes_follow_active_guids_and_keep_cross_zone_segments(self):
        packet = self.collect()
        source = {entry: {"s:waypoints": {}} for entry in runtime.DARKMOON_NPCS}
        active_guid = packet["selectedGuids"]["1"]["14828"][0]
        path = {"n:1": {"n:1": 20, "n:2": 30}, "n:2": {"n:1": 21, "n:2": 31}}
        source[14828]["s:waypoints"] = {"n:215": {"n:1": path, "n:2": {"n:1": {"n:1": 99, "n:2": 99}}},
                                           "n:1638": {"n:1": {"n:1": {"n:1": 5, "n:2": 6}}}}
        origins = {"14828": {"waypoints": {
            "n:215": {"n:1": [f"waypoint_data:8:addon:{active_guid}:map-spawn:{active_guid}:entry:14828:segment:1"],
                      "n:2": ["waypoint_data:9:addon:99999:map-spawn:99999:entry:14828"]},
            "n:1638": {"n:1": [f"waypoint_data:8:template-addon:14828:map-spawn:{active_guid}:entry:14828:segment:3"]}}}}
        result = runtime.select_darkmoon_waypoints(packet, source, origins)
        selected = result["darkmoon"]["1"]["14828"]["s:waypoints"]
        self.assertEqual(selected["n:215"], {"n:1": path})
        self.assertIn("n:1638", selected)
        self.assertEqual(result["darkmoon"]["2"]["14828"]["s:waypoints"], {})
        self.assertEqual(packet["darkmoon"]["1"]["14828"]["s:waypoints"], {})

    def test_fair_partial_routes_use_mapped_coverage_and_report_unknown_origins(self):
        packet = self.collect()
        guid = packet["selectedGuids"]["3"]["14849"][0]
        point = {"n:1": {"n:1": 3, "n:2": 4}}
        source = {entry: {"s:waypoints": {}} for entry in runtime.DARKMOON_NPCS}
        source[14849] = {}
        metadata = {"14849": {"waypointCoverage": {
            "unmappedPaths": ["bad-source-path"], "mapped": {"n:3519": {"n:1": point, "n:2": point}},
            "origins": {"n:3519": {"n:1": [f"waypoints:8:smart:14849:map-spawn:{guid}:entry:14849"],
                                   "n:2": ["waypoints:8:smart:14849"]}}}}}
        selected = runtime.select_darkmoon_waypoints(packet, source, metadata)
        self.assertEqual(selected["darkmoon"]["3"]["14849"]["s:waypoints"], {"n:3519": {"n:1": point}})
        self.assertTrue(any(row.get("npc") == 14849 and row.get("slot") == "n:2"
                            for row in selected["runtimeOmissions"]))
        with self.assertRaisesRegex(ValueError, "source placement identities"):
            runtime.select_darkmoon_waypoints({"version": 1}, source, metadata)


if __name__ == '__main__':
    unittest.main()
