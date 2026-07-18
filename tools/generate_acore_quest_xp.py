import argparse
import csv
import sys
from pathlib import Path


sys.dont_write_bytecode = True
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_acore_quest_metadata import load_acore_sql_table  # noqa: E402


CSV_COLUMNS = ["ID", *[f"Difficulty_{index}" for index in range(1, 11)]]
DEFAULT_OUTPUT = Path("Database/QuestXP/DB/xpDB-azerothcore-wotlk.lua")
QUEST_XP_AURA = 291
ITEM_SPELLTRIGGER_ON_EQUIP = 1


def parse_int(value, label):
    try:
        return int(value)
    except (TypeError, ValueError) as error:
        raise ValueError(f"{label} must be an integer, got {value!r}") from error


def load_quest_xp_csv(path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != CSV_COLUMNS:
            raise ValueError(
                f"{path} must have columns {', '.join(CSV_COLUMNS)}; "
                f"got {', '.join(reader.fieldnames or [])}"
            )

        xp_by_level = {}
        for line_number, row in enumerate(reader, start=2):
            level = parse_int(row["ID"], f"{path}:{line_number} ID")
            if level <= 0:
                raise ValueError(f"{path}:{line_number} ID must be positive")
            if level in xp_by_level:
                raise ValueError(f"{path}:{line_number} duplicates level {level}")

            rewards = []
            for index in range(1, 11):
                reward = parse_int(
                    row[f"Difficulty_{index}"],
                    f"{path}:{line_number} Difficulty_{index}",
                )
                if reward < 0:
                    raise ValueError(
                        f"{path}:{line_number} Difficulty_{index} must not be negative"
                    )
                rewards.append(reward)

            xp_by_level[level] = rewards

    if not xp_by_level:
        raise ValueError(f"{path} contains no XP rows")

    expected_levels = set(range(1, max(xp_by_level) + 1))
    missing_levels = sorted(expected_levels - set(xp_by_level))
    if missing_levels:
        raise ValueError(f"{path} is missing levels: {missing_levels}")

    return xp_by_level


def load_acore_quests(source_root):
    quest_template = (
        source_root / "data" / "sql" / "base" / "db_world" / "quest_template.sql"
    )
    if not quest_template.is_file():
        raise ValueError(f"Could not find AzerothCore quest_template at {quest_template}")

    raw_rows = load_acore_sql_table(
        source_root,
        "quest_template",
        include_modules=True,
    )
    if not raw_rows:
        raise ValueError(f"No AzerothCore quest_template rows were loaded from {source_root}")

    quests = {}
    for quest_id, row in raw_rows.items():
        quest_id = parse_int(quest_id, "quest_template ID")
        quest_level = parse_int(row.get("QuestLevel"), f"quest {quest_id} QuestLevel")
        reward_difficulty = parse_int(
            row.get("RewardXPDifficulty"),
            f"quest {quest_id} RewardXPDifficulty",
        )

        if not 0 <= reward_difficulty <= 9:
            raise ValueError(
                f"quest {quest_id} has unsupported RewardXPDifficulty "
                f"{reward_difficulty}; expected 0 through 9"
            )

        quests[quest_id] = (quest_level, reward_difficulty)

    return quests


def load_item_quest_xp_bonuses(source_root, spell_sql, spell_table):
    if not spell_sql.is_file():
        raise ValueError(f"Could not find the Spell.dbc SQL export at {spell_sql}")

    item_rows = load_acore_sql_table(
        source_root,
        "item_template",
        key_column="entry",
        include_modules=True,
    )
    if not item_rows:
        raise ValueError(f"No AzerothCore item_template rows were loaded from {source_root}")

    item_equip_spells = {}
    equip_spell_ids = set()
    for item_id, row in item_rows.items():
        spells = []
        for index in range(1, 6):
            spell_id = parse_int(
                row.get(f"spellid_{index}") or 0,
                f"item {item_id} spellid_{index}",
            )
            spell_trigger = parse_int(
                row.get(f"spelltrigger_{index}") or 0,
                f"item {item_id} spelltrigger_{index}",
            )
            if spell_id > 0 and spell_trigger == ITEM_SPELLTRIGGER_ON_EQUIP:
                spells.append(spell_id)
                equip_spell_ids.add(spell_id)

        if spells:
            item_equip_spells[parse_int(item_id, "item_template entry")] = spells

    spell_rows = load_acore_sql_table(
        source_root,
        spell_table,
        base_file_override=spell_sql,
        wanted_keys=equip_spell_ids,
    )

    bonuses_by_spell = {}
    for spell_id, row in spell_rows.items():
        bonuses = []
        for index in range(1, 4):
            aura_type = parse_int(
                row.get(f"EffectApplyAuraName{index}") or 0,
                f"spell {spell_id} EffectApplyAuraName{index}",
            )
            if aura_type != QUEST_XP_AURA:
                continue

            effect_type = parse_int(
                row.get(f"Effect{index}") or 0,
                f"spell {spell_id} Effect{index}",
            )
            points_per_level = float(row.get(f"EffectRealPointsPerLevel{index}") or 0)
            die_sides = parse_int(
                row.get(f"EffectDieSides{index}") or 0,
                f"spell {spell_id} EffectDieSides{index}",
            )
            if effect_type != 6 or points_per_level != 0 or die_sides not in (0, 1):
                raise ValueError(
                    f"spell {spell_id} has an unsupported dynamic quest XP aura "
                    f"in effect {index}"
                )

            # Fixed-value Spell.dbc effects store their displayed amount as
            # EffectBasePoints + 1.
            bonus = parse_int(
                row.get(f"EffectBasePoints{index}") or 0,
                f"spell {spell_id} EffectBasePoints{index}",
            ) + 1
            if bonus <= 0:
                raise ValueError(
                    f"spell {spell_id} effect {index} has unsupported quest XP bonus {bonus}"
                )
            bonuses.append(bonus)

        if bonuses:
            bonuses_by_spell[parse_int(spell_id, f"{spell_table} ID")] = bonuses

    item_bonuses = {}
    for item_id, spell_ids in item_equip_spells.items():
        bonuses = []
        for spell_id in spell_ids:
            bonuses.extend(bonuses_by_spell.get(spell_id, ()))
        if bonuses:
            item_bonuses[item_id] = bonuses

    if not item_bonuses:
        raise ValueError(
            f"No equipped items using SPELL_AURA_MOD_XP_QUEST_PCT were found in {spell_sql}"
        )

    return item_bonuses


def build_lua(quests, xp_by_level, item_bonuses):
    lines = [
        "--! This file is automatically generated. Do not modify.",
        "-- Generated by tools/generate_acore_quest_xp.py from AzerothCore",
        "-- quest_template/item_template data and WotLK DBC exports.",
        "",
        "---@type QuestXP",
        'local QuestXP = QuestieLoader:ImportModule("QuestXP")',
        "",
        "-- questId = {QuestLevel, RewardXPDifficulty}",
        "QuestXP.db = {",
    ]

    for quest_id in sorted(quests):
        quest_level, reward_difficulty = quests[quest_id]
        lines.append(f"    [{quest_id}] = {{{quest_level}, {reward_difficulty}}},")

    lines.extend([
        "}",
        "",
        "-- QuestXP.dbc rows. Lua index 1 corresponds to RewardXPDifficulty 0.",
        "QuestXP.xpByLevel = {",
    ])

    for level in sorted(xp_by_level):
        rewards = ", ".join(str(reward) for reward in xp_by_level[level])
        lines.append(f"    [{level}] = {{{rewards}}},")

    lines.extend([
        "}",
        "",
        "-- itemId = {quest XP bonus percentages from equipped item spells}",
        "QuestXP.itemQuestXPBonuses = {",
    ])

    for item_id in sorted(item_bonuses):
        bonuses = ", ".join(str(bonus) for bonus in item_bonuses[item_id])
        lines.append(f"    [{item_id}] = {{{bonuses}}},")

    lines.extend(["}", ""])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate AzerothCore WotLK quest XP data for Questie 335."
    )
    parser.add_argument(
        "--acore-source",
        required=True,
        type=Path,
        help="Path to the AzerothCore source tree.",
    )
    parser.add_argument(
        "--quest-xp-csv",
        required=True,
        type=Path,
        help="CSV export of the WotLK QuestXP.dbc table.",
    )
    parser.add_argument(
        "--spell-sql",
        required=True,
        type=Path,
        help="SQL export of the WotLK Spell.dbc table.",
    )
    parser.add_argument(
        "--spell-table",
        default="spell",
        help="Table name inside --spell-sql (default: spell).",
    )
    parser.add_argument(
        "--output",
        default=DEFAULT_OUTPUT,
        type=Path,
        help=f"Generated Lua output (default: {DEFAULT_OUTPUT}).",
    )
    args = parser.parse_args()

    xp_by_level = load_quest_xp_csv(args.quest_xp_csv)
    quests = load_acore_quests(args.acore_source)
    item_bonuses = load_item_quest_xp_bonuses(
        args.acore_source,
        args.spell_sql,
        args.spell_table,
    )
    output = build_lua(quests, xp_by_level, item_bonuses)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output, encoding="utf-8", newline="\n")

    dynamic_quests = sum(level == -1 for level, _ in quests.values())
    print(
        f"Wrote {args.output} with {len(quests)} quests, "
        f"{dynamic_quests} dynamic quests, {len(xp_by_level)} XP levels, "
        f"and {len(item_bonuses)} quest XP bonus items."
    )


if __name__ == "__main__":
    main()
