import argparse
import json
import re
import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_acore_quest_metadata import load_acore_sql_table
from validate_acore_quest_relations import load_disabled_quest_ids


DISABLES_SECTION_START = "-- AzerothCore quests disabled by the final `disables` SQL state."
DISABLES_SECTION_END = "-- Automatic overrides"

BLACKLIST_VALUE_PATTERN = re.compile(
    r"^\s*\[(?P<quest_id>\d+)\]\s*=\s*(?P<value>[^,\r\n]+)",
    re.MULTILINE,
)

FULL_WOTLK_BLACKLIST_VALUES = {
    "true",
    "QuestieCorrections.WOTLK_ONLY",
    "QuestieCorrections.TBC_AND_WOTLK",
}


def extract_between(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise ValueError(f"Missing section marker: {start_marker}")

    end = text.find(end_marker, start)
    if end < 0:
        raise ValueError(f"Missing section marker: {end_marker}")

    return text[start:end]


def extract_function_body(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise ValueError(f"Missing function marker: {start_marker}")

    end = text.find(end_marker, start)
    if end < 0:
        raise ValueError(f"Missing function marker: {end_marker}")

    return text[start:end]


def parse_blacklist_entries(text: str):
    return {
        int(match.group("quest_id")): match.group("value").strip()
        for match in BLACKLIST_VALUE_PATTERN.finditer(text)
    }


def is_fully_blacklisted_in_wotlk(value: str) -> bool:
    return value in FULL_WOTLK_BLACKLIST_VALUES


def get_quest_names(acore_source: Path):
    rows = load_acore_sql_table(
        acore_source,
        "quest_template",
        key_column="ID",
    )
    return {
        int(quest_id): str(row.get("LogTitle") or "")
        for quest_id, row in rows.items()
    }


def describe_quest(quest_id: int, quest_names) -> str:
    name = quest_names.get(quest_id)
    if name:
        return f"{quest_id}: {name}"
    return f"{quest_id}: <not present in final quest_template>"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Compare Questie's curated AzerothCore-disabled blacklist section "
            "with AzerothCore's final disables SQL state."
        )
    )
    parser.add_argument(
        "--acore-source",
        required=True,
        type=Path,
        help="Path to the AzerothCore source tree",
    )
    parser.add_argument(
        "--blacklist",
        type=Path,
        default=Path("Database/Corrections/QuestieQuestBlacklist.lua"),
        help="Path to QuestieQuestBlacklist.lua",
    )
    parser.add_argument(
        "--report",
        type=Path,
        help="Optional path for a JSON copy of the report",
    )
    args = parser.parse_args()

    acore_source = args.acore_source.resolve()
    blacklist_path = args.blacklist.resolve()

    if not acore_source.is_dir():
        parser.error(f"AzerothCore source directory does not exist: {acore_source}")
    if not blacklist_path.is_file():
        parser.error(f"Questie blacklist file does not exist: {blacklist_path}")

    blacklist_text = blacklist_path.read_text(encoding="utf-8")
    load_body = extract_function_body(
        blacklist_text,
        "function QuestieQuestBlacklist:Load()",
        "QuestieQuestBlacklist.AQWarEffortQuests",
    )
    auto_start = blacklist_text.find(
        "function QuestieQuestBlacklist.LoadAutoBlacklistWotlk()"
    )
    if auto_start < 0:
        raise ValueError(
            "Missing function marker: "
            "function QuestieQuestBlacklist.LoadAutoBlacklistWotlk()"
        )
    auto_body = blacklist_text[auto_start:]
    disables_body = extract_between(
        load_body,
        DISABLES_SECTION_START,
        DISABLES_SECTION_END,
    )

    static_entries = parse_blacklist_entries(load_body)
    auto_entries = parse_blacklist_entries(auto_body)
    disables_section_entries = parse_blacklist_entries(disables_body)

    effective_entries = dict(static_entries)
    for quest_id, value in auto_entries.items():
        effective_entries.setdefault(quest_id, value)

    acore_disabled = load_disabled_quest_ids(acore_source)
    section_ids = {
        quest_id
        for quest_id, value in disables_section_entries.items()
        if is_fully_blacklisted_in_wotlk(value)
    }
    fully_blacklisted_ids = {
        quest_id
        for quest_id, value in effective_entries.items()
        if is_fully_blacklisted_in_wotlk(value)
    }

    missing_from_section = acore_disabled - section_ids
    add_ids = missing_from_section - fully_blacklisted_ids
    move_ids = missing_from_section & fully_blacklisted_ids
    stale_section_ids = section_ids - acore_disabled

    quest_names = get_quest_names(acore_source)

    report = {
        "summary": {
            "acoreDisabledQuests": len(acore_disabled),
            "questieDisablesSectionQuests": len(section_ids),
            "add": len(add_ids),
            "moveIntoDisablesSection": len(move_ids),
            "removeOrReclassify": len(stale_section_ids),
            "changesRequired": len(add_ids) + len(move_ids) + len(stale_section_ids),
        },
        "add": [
            {"questId": quest_id, "name": quest_names.get(quest_id)}
            for quest_id in sorted(add_ids)
        ],
        "moveIntoDisablesSection": [
            {"questId": quest_id, "name": quest_names.get(quest_id)}
            for quest_id in sorted(move_ids)
        ],
        "removeOrReclassify": [
            {"questId": quest_id, "name": quest_names.get(quest_id)}
            for quest_id in sorted(stale_section_ids)
        ],
    }

    print("AzerothCore quest blacklist audit")
    print(f"  AzerothCore disabled quests:       {len(acore_disabled)}")
    print(f"  Questie disables-section quests:   {len(section_ids)}")
    print(f"  Add to Questie blacklist:          {len(add_ids)}")
    print(f"  Move into AC disables section:     {len(move_ids)}")
    print(f"  Remove/reclassify from AC section: {len(stale_section_ids)}")
    print(f"  Changes required:                  {report['summary']['changesRequired']}")

    if add_ids:
        print("\nADD: disabled by AzerothCore but not fully blacklisted by Questie")
        for quest_id in sorted(add_ids):
            print(f"  {describe_quest(quest_id, quest_names)}")

    if move_ids:
        print("\nMOVE: already blacklisted elsewhere; move into the AC disables section")
        for quest_id in sorted(move_ids):
            print(f"  {describe_quest(quest_id, quest_names)}")

    if stale_section_ids:
        print(
            "\nREMOVE/RECLASSIFY: no longer disabled by AzerothCore; "
            "remove from this section or retain elsewhere only with another reason"
        )
        for quest_id in sorted(stale_section_ids):
            print(f"  {describe_quest(quest_id, quest_names)}")

    if report["summary"]["changesRequired"] == 0:
        print("\nOK: Questie's AzerothCore disables section matches the final SQL state.")

    if args.report:
        report_path = args.report.resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"JSON report written to {report_path}")

    return 1 if report["summary"]["changesRequired"] else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
