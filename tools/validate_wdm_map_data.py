import argparse
import csv
import math
import re
from pathlib import Path

from generate_acore_npc_corrections import parse_zone_maps


WDM_ROW_PATTERN = re.compile(
    r'^\s*\[(?P<ui_map_id>\d+)\]\s*=\s*\{\s*'
    r'(?P<width>-?[\d.]+),\s*(?P<height>-?[\d.]+),\s*'
    r'(?P<left>-?[\d.]+),\s*(?P<top>-?[\d.]+),.*?'
    r'parentMapID\s*=\s*(?P<parent_map_id>\d+),\s*'
    r'mapID\s*=\s*(?P<map_id>[\d.]+),\s*'
    r'instance\s*=\s*(?P<instance>\d+),\s*name\s*=\s*"(?P<name>[^"]+)"'
)
INSTANCE_SOURCE_PATTERN = re.compile(r"--\s*area\s+(?P<area_id>\d+)(?:,\s*floor\s+(?P<floor>\d+))?")

# WorldMapArea map 530 is stored in Outland/server coordinates. Questie's
# 3.3.5 map compatibility layer displays the blood elf and draenei zones in
# Eastern Kingdoms/Kalimdor world coordinates, so WDM children need the same
# Astrolabe offset transform as their parent zones.
TRANSFORMED_MAP_530_ROWS = {
    893: {"uiMapID": 467, "parentMapID": 1941, "instance": 0, "left": -2720.515732, "top": 8433.340089},
    894: {"uiMapID": 468, "parentMapID": 1943, "instance": 1, "left": 4785.503539, "top": 6735.485401},
    1041: {"uiMapID": 96, "parentMapID": 1942, "instance": 0, "left": -4517.181277, "top": 5310.017941},
    1042: {"uiMapID": 98, "parentMapID": 1943, "instance": 1, "left": 6231.085571, "top": 5699.651416},
    1043: {"uiMapID": 99, "parentMapID": 1943, "instance": 1, "left": 5352.530883, "top": 7330.481495},
}


def close_enough(actual, expected, tolerance=0.01):
    return math.isclose(actual, expected, rel_tol=0, abs_tol=tolerance)


def load_wdm_rows(ui_map_data_path, table_name="wdmWorldMapData"):
    text = ui_map_data_path.read_text(encoding="utf-8")
    start = text.index(f"local {table_name} = {{")
    end = text.index(f"\n}}\n\nfor uiMapID, data in pairs({table_name})", start)
    rows = {}
    for line in text[start:end].splitlines():
        match = WDM_ROW_PATTERN.search(line)
        if not match:
            continue
        values = match.groupdict()
        ui_map_id = int(values["ui_map_id"])
        rows[ui_map_id] = {
            "width": float(values["width"]),
            "height": float(values["height"]),
            "left": float(values["left"]),
            "top": float(values["top"]),
            "parentMapID": int(values["parent_map_id"]),
            "mapID": float(values["map_id"]),
            "instance": int(values["instance"]),
            "name": values["name"],
        }
        source_match = INSTANCE_SOURCE_PATTERN.search(line)
        if source_match:
            rows[ui_map_id]["areaID"] = int(source_match.group("area_id"))
            if source_match.group("floor"):
                rows[ui_map_id]["floor"] = int(source_match.group("floor"))
    return rows


def load_world_map_area_rows(csv_path):
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        return {int(row["ID"]): row for row in csv.DictReader(handle)}


def load_dungeon_map_rows(csv_path):
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        return {
            (int(row["MapID"]), int(row["FloorIndex"])): row
            for row in csv.DictReader(handle)
        }


def validate_rows(wdm_rows, source_rows):
    errors = []
    audited_map_530_ids = set()

    for ui_map_id, wdm in sorted(wdm_rows.items()):
        source_id = wdm["mapID"] - 1
        source = source_rows.get(source_id)
        if not source:
            errors.append(f"UiMapID {ui_map_id}: WorldMapArea {source_id} not found")
            continue

        expected_width = abs(float(source["LocLeft"]) - float(source["LocRight"]))
        expected_height = abs(float(source["LocTop"]) - float(source["LocBottom"]))
        if not close_enough(wdm["width"], expected_width):
            errors.append(f"UiMapID {ui_map_id}: width {wdm['width']} != {expected_width}")
        if not close_enough(wdm["height"], expected_height):
            errors.append(f"UiMapID {ui_map_id}: height {wdm['height']} != {expected_height}")

        source_instance = int(source["MapID"])
        if source_instance == 530:
            audited_map_530_ids.add(source_id)
            expected = TRANSFORMED_MAP_530_ROWS.get(source_id)
            if not expected:
                errors.append(f"UiMapID {ui_map_id}: unaudited map-530 WorldMapArea {source_id}")
                continue
            for field in ("uiMapID", "parentMapID", "instance"):
                actual = ui_map_id if field == "uiMapID" else wdm[field]
                if actual != expected[field]:
                    errors.append(f"UiMapID {ui_map_id}: {field} {actual} != {expected[field]}")
            for field in ("left", "top"):
                if not close_enough(wdm[field], expected[field]):
                    errors.append(f"UiMapID {ui_map_id}: {field} {wdm[field]} != {expected[field]}")
        else:
            if wdm["instance"] != source_instance:
                errors.append(
                    f"UiMapID {ui_map_id}: instance {wdm['instance']} != WorldMapArea map {source_instance}"
                )
            for field, source_field in (("left", "LocLeft"), ("top", "LocTop")):
                expected_value = float(source[source_field])
                if not close_enough(wdm[field], expected_value):
                    errors.append(f"UiMapID {ui_map_id}: {field} {wdm[field]} != {expected_value}")

    missing_map_530_rows = set(TRANSFORMED_MAP_530_ROWS) - audited_map_530_ids
    if missing_map_530_rows:
        errors.append(f"Configured map-530 rows missing from WDM data: {sorted(missing_map_530_rows)}")
    return errors


def normalized_name(value):
    return re.sub(r"[^a-z0-9]", "", value.lower())


def validate_instance_rows(
    wdm_rows,
    world_map_area_rows,
    dungeon_map_rows,
    area_to_ui,
    dungeon_parent_by_area,
):
    errors = []
    sources_by_instance_area = {
        (int(row["MapID"]), int(row["AreaID"])): row
        for row in world_map_area_rows.values()
    }

    for ui_map_id, wdm in sorted(wdm_rows.items()):
        area_id = wdm.get("areaID")
        if not area_id:
            errors.append(f"UiMapID {ui_map_id}: missing generated area source comment")
            continue

        source = sources_by_instance_area.get((wdm["instance"], area_id))
        if not source:
            errors.append(
                f"UiMapID {ui_map_id}: WorldMapArea for instance {wdm['instance']} area {area_id} not found"
            )
            continue

        floor = wdm.get("floor")
        expected_map_id = int(source["ID"]) + 1 + ((floor or 0) / 10)
        if not close_enough(wdm["mapID"], expected_map_id, tolerance=0.0001):
            errors.append(f"UiMapID {ui_map_id}: mapID {wdm['mapID']} != {expected_map_id}")

        if normalized_name(wdm["name"]) != normalized_name(source["AreaName"]):
            errors.append(f"UiMapID {ui_map_id}: name {wdm['name']!r} != {source['AreaName']!r}")

        if floor:
            geometry_source = dungeon_map_rows.get((wdm["instance"], floor))
            if not geometry_source:
                errors.append(
                    f"UiMapID {ui_map_id}: DungeonMap instance {wdm['instance']} floor {floor} not found"
                )
                continue
            expected_width = abs(float(geometry_source["MaxX"]) - float(geometry_source["MinX"]))
            expected_height = abs(float(geometry_source["MaxY"]) - float(geometry_source["MinY"]))
            expected_left = float(geometry_source["MaxX"])
            expected_top = float(geometry_source["MaxY"])
            parent_source_id = int(geometry_source["ParentWorldMapID"])
        else:
            expected_width = abs(float(source["LocLeft"]) - float(source["LocRight"]))
            expected_height = abs(float(source["LocTop"]) - float(source["LocBottom"]))
            expected_left = float(source["LocLeft"])
            expected_top = float(source["LocTop"])
            parent_source_id = int(source["ParentWorldMapID"])

        for field, actual, expected in (
            ("width", wdm["width"], expected_width),
            ("height", wdm["height"], expected_height),
            ("left", wdm["left"], expected_left),
            ("top", wdm["top"], expected_top),
        ):
            if not close_enough(actual, expected):
                errors.append(f"UiMapID {ui_map_id}: {field} {actual} != {expected}")

        expected_parent_ui_ids = set()
        parent_source = world_map_area_rows.get(parent_source_id)
        if parent_source:
            parent_ui_id = area_to_ui.get(int(parent_source["AreaID"]))
            if parent_ui_id:
                expected_parent_ui_ids.add(parent_ui_id)
        dungeon_parent_area = dungeon_parent_by_area.get(area_id)
        if dungeon_parent_area:
            parent_ui_id = area_to_ui.get(dungeon_parent_area)
            if parent_ui_id:
                expected_parent_ui_ids.add(parent_ui_id)

        if not expected_parent_ui_ids:
            errors.append(
                f"UiMapID {ui_map_id}: cannot resolve a parent UiMapID for instance area {area_id}"
            )
        elif wdm["parentMapID"] not in expected_parent_ui_ids:
            errors.append(
                f"UiMapID {ui_map_id}: parentMapID {wdm['parentMapID']} not in {sorted(expected_parent_ui_ids)}"
            )

    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate Questie's WDM UiMapData against WDM WorldMapArea exports.")
    parser.add_argument("--addon-root", default=Path("."), type=Path)
    parser.add_argument("--wdm-root", default=Path(r"E:\downloads\WDM stuff"), type=Path)
    args = parser.parse_args()

    ui_map_data_path = args.addon_root.resolve() / "Compat/UiMapData.lua"
    world_map_area_path = args.wdm_root.resolve() / "patch-enUS-N extracted/DBFilesClient/WorldMapArea.csv"
    dungeon_map_path = args.wdm_root.resolve() / "patch-enUS-M extracted/DBFilesClient/DungeonMap.csv"
    world_rows = load_wdm_rows(ui_map_data_path, "wdmWorldMapData")
    instance_rows = load_wdm_rows(ui_map_data_path, "wdmInstanceMapData")
    source_rows = load_world_map_area_rows(world_map_area_path)
    dungeon_rows = load_dungeon_map_rows(dungeon_map_path)
    zone_maps = parse_zone_maps(args.addon_root.resolve())
    errors = validate_rows(world_rows, source_rows)
    errors.extend(
        validate_instance_rows(
            instance_rows,
            source_rows,
            dungeon_rows,
            zone_maps["area_to_ui"],
            zone_maps["dungeon_parent_by_area"],
        )
    )

    print(
        f"Audited {len(world_rows)} WDM world/micro maps "
        f"({len(TRANSFORMED_MAP_530_ROWS)} transformed map-530 maps) and "
        f"{len(instance_rows)} WDM instance maps."
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit(1)
    print("WDM map data is consistent with its source coordinate spaces.")


if __name__ == "__main__":
    main()
