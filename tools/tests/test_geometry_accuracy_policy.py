"""A completed audit cannot silently restore unverified map markers."""
import unittest

from _test_paths import ADDON_ROOT
import audit_acore_npc_sources as audit
import generate_acore_npc_base as npc
import generate_acore_object_base as obj


def fixture(kind="npc"):
    source = {1: {"s:name": "Source entity", "s:spawns": {}, "s:questStarts": {}, "s:questEnds": {}}}
    if kind == "npc":
        source[1].update({"s:minLevel": 1, "s:waypoints": {}})
        manifest = npc.upgrade_manifest(npc.make_manifest(source, source, {}, "snapshot", {}), source, {})
    else:
        manifest = obj.make_manifest(source, source, {}, {}, "snapshot", {})
    manifest["geometryPolicy"] = "verified-source-only-v1"
    manifest["geometryAudit"] = {"version": 1, "reviewedFields": {"1": ["spawns"]}}
    return source, manifest


class GeometryAccuracyPolicyTests(unittest.TestCase):
    def test_literal_markers_and_entrance_placeholders_cannot_reappear(self):
        for kind, exporter in (("npc", npc), ("object", obj)):
            for point in ([10, 20], [-1, -1]):
                source, manifest = fixture(kind)
                policy = {"slots": {"n:12": {"n:1": {"value": audit.typed(point)}}}}
                manifest["geometry"]["1"] = {"spawns": policy} if kind == "npc" else policy
                with self.subTest(kind=kind, point=point), self.assertRaisesRegex(ValueError, "Inherited.*prohibited"):
                    exporter.build_records(source, manifest, {})

    def test_missing_source_geometry_requires_coverage_review_even_without_bindings(self):
        for kind, exporter in (("npc", npc), ("object", obj)):
            source, manifest = fixture(kind)
            del source[1]["s:spawns"]
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "explicit coverage review"):
                exporter.build_records(source, manifest, {})

    def test_reviewed_partial_source_keeps_visibility_and_blocks_new_mapping_gaps(self):
        for kind, exporter in (("npc", npc), ("object", obj)):
            source, manifest = fixture(kind)
            del source[1]["s:spawns"]
            policy = {"slots": {}, "reviewedUnmappedGuids": [100]}
            manifest["geometry"]["1"] = {"spawns": policy} if kind == "npc" else policy
            point = audit.typed({12: [[10, 20, 4, 3, 0, 4, 12, 99]]})
            coverage = {"unmappedGuids": [100], "mapped": point, "origins": {"n:12": {"n:1": ["source:99"]}}}
            provenance = {"1": {"spawnCoverage": coverage}}
            self.assertEqual(exporter.build_records(source, manifest, provenance)[1]["s:spawns"], point)
            coverage["unmappedGuids"].append(101)
            with self.assertRaisesRegex(ValueError, "New unmapped spawn GUIDs"):
                exporter.build_records(source, manifest, provenance)

    def test_supplemental_ids_and_relations_remain_but_coordinates_are_rejected(self):
        for kind, exporter in (("npc", npc), ("object", obj)):
            source, manifest = fixture(kind)
            extra = {"s:name": "Client helper", "s:questStarts": {"n:1": 10}}
            manifest["scope"]["2"] = sum(1 << (exporter.KEYS[key] - 1) for key in extra)
            manifest["extraRecords"]["2"] = extra
            records = exporter.build_records(source, manifest, {})
            self.assertEqual(records[2], extra)
            extra["s:spawns"] = audit.typed({12: [[10, 20]]})
            manifest["scope"]["2"] |= 1 << (exporter.KEYS["s:spawns"] - 1)
            with self.assertRaisesRegex(ValueError, "supplemental.*prohibited"):
                exporter.build_records(source, manifest, {})

    def test_omission_report_is_separate_from_runtime_records_and_recovery_updates_it(self):
        source, manifest = fixture()
        records = npc.build_records(source, manifest, {})
        report = npc.geometry_audit_report(records, manifest, {})
        self.assertEqual(report["coverageGapRecords"], 1)
        self.assertNotIn("geometryAudit", records[1])
        source[1]["s:spawns"] = audit.typed({12: [[10, 20]]})
        recovered = npc.build_records(source, manifest, {})
        self.assertEqual(npc.geometry_audit_report(recovered, manifest, {})["coverageGapRecords"], 0)

    def test_cpp_coordinates_refresh_and_unsupported_source_fails_without_legacy_fallback(self):
        source, manifest = fixture()
        manifest["geometry"]["1"] = {"spawns": {"slots": {}, "sourceCpp": True}}
        data = {"spawns": audit.typed({12: [[30, 40]]}), "waypoints": {},
                "origins": {"spawns": {"n:12": {"n:1": ["cpp:declared-position"]}}},
                "failures": {"spawns": [], "waypoints": []}}
        provenance = {"cppGeometry": {"version": 1, "entries": {"1": data}}}
        self.assertEqual(npc.build_records(source, manifest, provenance)[1]["s:spawns"], data["spawns"])
        data["spawns"]["n:12"]["n:1"]["n:1"] = 35
        self.assertEqual(npc.build_records(source, manifest, provenance)[1]["s:spawns"]["n:12"]["n:1"]["n:1"], 35)
        data["failures"]["spawns"].append({"source": "cpp:declared-position", "reasons": ["unsupported source change"]})
        with self.assertRaisesRegex(ValueError, "requires review"):
            npc.build_records(source, manifest, provenance)
