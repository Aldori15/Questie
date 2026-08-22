import argparse
import csv
import math
import re
from pathlib import Path


WDM_ROW_PATTERN = re.compile(
    r'^\s*\[(?P<ui_map_id>\d+)\]\s*=\s*\{\s*'
    r'(?P<width>-?[\d.]+),\s*(?P<height>-?[\d.]+),\s*'
    r'(?P<left>-?[\d.]+),\s*(?P<top>-?[\d.]+),.*?'
    r'parentMapID\s*=\s*(?P<parent_map_id>\d+),\s*'
    r'mapID\s*=\s*(?P<map_id>[\d.]+),\s*'
    r'instance\s*=\s*(?P<instance>\d+),\s*name\s*=\s*"(?P<name>[^"]+)"'
)

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


def load_wdm_rows(ui_map_data_path):
    text = ui_map_data_path.read_text(encoding="utf-8")
    start = text.index("local wdmWorldMapData = {")
    end = text.index("\n}\n\nfor uiMapID", start)
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
            "mapID": int(float(values["map_id"])),
            "instance": int(values["instance"]),
            "name": values["name"],
        }
    return rows


def load_world_map_area_rows(csv_path):
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        return {int(row["ID"]): row for row in csv.DictReader(handle)}


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


def main():
    parser = argparse.ArgumentParser(description="Validate Questie's WDM UiMapData against WDM WorldMapArea exports.")
    parser.add_argument("--addon-root", default=Path("."), type=Path)
    parser.add_argument("--wdm-root", default=Path(r"E:\downloads\WDM stuff"), type=Path)
    args = parser.parse_args()

    ui_map_data_path = args.addon_root.resolve() / "Compat/UiMapData.lua"
    world_map_area_path = args.wdm_root.resolve() / "patch-enUS-N extracted/DBFilesClient/WorldMapArea.csv"
    wdm_rows = load_wdm_rows(ui_map_data_path)
    source_rows = load_world_map_area_rows(world_map_area_path)
    errors = validate_rows(wdm_rows, source_rows)

    print(
        f"Audited {len(wdm_rows)} WDM world/micro maps "
        f"({len(TRANSFORMED_MAP_530_ROWS)} transformed map-530 maps)."
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit(1)
    print("WDM map data is consistent with its source coordinate spaces.")


if __name__ == "__main__":
    main()
