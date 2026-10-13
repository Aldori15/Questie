import argparse
import json
import re
from pathlib import Path

from validate_reverse_quest_links import (
    LuaTableParser,
    extract_named_tables,
    split_top_level_lua_table,
    strip_lua_comments,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = REPO_ROOT / "tools" / "reports"

DEFAULT_BASE_DB = {
    "quest": REPO_ROOT / "Database" / "Wotlk" / "wotlkQuestDB.lua",
    "npc": REPO_ROOT / "Database" / "Wotlk" / "wotlkNpcDB.lua",
    "object": REPO_ROOT / "Database" / "Wotlk" / "wotlkObjectDB.lua",
    "item": REPO_ROOT / "Database" / "Wotlk" / "wotlkItemDB.lua",
}

DEFAULT_ACORE_CORRECTIONS = {
    "quest": REPO_ROOT / "Database" / "AzerothCore" / "AzerothCoreQuestCorrections.lua",
    "npc": REPO_ROOT / "Database" / "AzerothCore" / "AzerothCoreNPCCorrections.lua",
    "object": REPO_ROOT / "Database" / "AzerothCore" / "AzerothCoreObjectCorrections.lua",
    "item": REPO_ROOT / "Database" / "AzerothCore" / "AzerothCoreItemCorrections.lua",
}
DEFAULT_ITEM_START_FIXES = REPO_ROOT / "Database" / "Corrections" / "Automatic" / "itemStartFixes.lua"

QUEST_ENTRY_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*\})$", re.DOTALL)
QUEST_FIELD_RE = re.compile(
    r"^\[(questKeys\.(?:startedBy|finishedBy|requiredSourceItems))\]\s*=\s*(.+)$",
    re.DOTALL,
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Report AzerothCore correction IDs missing from the base WotLK DB."
    )
    parser.add_argument(
        "--json-report",
        type=Path,
        default=REPORT_DIR / "acore_custom_ids_report.json",
        help="JSON report output path.",
    )
    parser.add_argument(
        "--markdown-report",
        type=Path,
        default=REPORT_DIR / "acore_custom_ids_report.md",
        help="Markdown summary output path.",
    )
    parser.add_argument(
        "--no-write",
        action="store_true",
        help="Print summary only; do not write report files.",
    )
    return parser.parse_args()


def load_top_level_ids_from_lines(path):
    ids = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*\[(\d+)\]\s*=", line)
        if match:
            ids.add(int(match.group(1)))
    return ids


def load_correction_ids(path, markers):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    ids = set()

    for table_text in extract_named_tables(text, markers):
        for entry in split_top_level_lua_table(table_text):
            match = re.match(r"^\[(\d+)\]\s*=", entry.strip(), re.DOTALL)
            if match:
                ids.add(int(match.group(1)))

    return ids


def parse_optional_id_list(value):
    if not isinstance(value, list):
        return set()
    return {int(entry) for entry in value if isinstance(entry, int)}


def parse_relation_ids(value):
    result = {"npc": set(), "object": set(), "item": set()}
    if not isinstance(value, list):
        return result

    if len(value) > 0:
        result["npc"] = parse_optional_id_list(value[0])
    if len(value) > 1:
        result["object"] = parse_optional_id_list(value[1])
    if len(value) > 2:
        result["item"] = parse_optional_id_list(value[2])

    return result


def add_reference(references, quest_id, field_name, entity_kind, entity_id):
    references.append(
        {
            "questId": quest_id,
            "field": field_name,
            "entityKind": entity_kind,
            "entityId": entity_id,
        }
    )


def load_acore_quest_references(path):
    text = strip_lua_comments(path.read_text(encoding="utf-8"))
    references = []
    markers = ["local relationCorrections = ", "local metadataCorrections = "]

    for table_text in extract_named_tables(text, markers):
        for entry in split_top_level_lua_table(table_text):
            match = QUEST_ENTRY_RE.match(entry.strip())
            if not match:
                continue

            quest_id = int(match.group(1))
            body = match.group(2)

            for field in split_top_level_lua_table(body):
                field_match = QUEST_FIELD_RE.match(field.strip())
                if not field_match:
                    continue

                field_name = field_match.group(1)
                field_value = field_match.group(2).strip()
                if field_value == "nil":
                    continue

                parsed = LuaTableParser(field_value).parse()
                if field_name in {"questKeys.startedBy", "questKeys.finishedBy"}:
                    relation_ids = parse_relation_ids(parsed)
                    for entity_kind, entity_ids in relation_ids.items():
                        for entity_id in entity_ids:
                            add_reference(references, quest_id, field_name, entity_kind, entity_id)
                elif field_name == "questKeys.requiredSourceItems":
                    for item_id in parse_optional_id_list(parsed):
                        add_reference(references, quest_id, field_name, "item", item_id)

    return references


def classify_references(references, base_ids, correction_ids):
    result = {
        "base": [],
        "acoreCorrectionOnly": [],
        "otherKind": [],
        "missingBaseAndCorrection": [],
    }

    for reference in references:
        entity_kind = reference["entityKind"]
        entity_id = reference["entityId"]

        if entity_id in base_ids[entity_kind]:
            result["base"].append(reference)
        elif entity_id in correction_ids[entity_kind]:
            result["acoreCorrectionOnly"].append(reference)
        else:
            other_kinds = [
                kind
                for kind in sorted(base_ids)
                if kind != entity_kind and (entity_id in base_ids[kind] or entity_id in correction_ids[kind])
            ]
            if other_kinds:
                mismatched_reference = dict(reference)
                mismatched_reference["presentAsKinds"] = other_kinds
                result["otherKind"].append(mismatched_reference)
            else:
                result["missingBaseAndCorrection"].append(reference)

    return result


def compact_ids(ids, limit=80):
    ids = sorted(ids)
    if len(ids) <= limit:
        return ids
    return ids[:limit] + [f"... {len(ids) - limit} more"]


def write_markdown(path, report):
    lines = [
        "# AzerothCore custom ID report",
        "",
        "IDs listed here are diagnostics. AC-only IDs are not automatically bugs.",
        "",
        "## Correction IDs missing from base DB",
        "",
    ]

    for kind, section in report["correctionIds"].items():
        lines.append(f"- {kind}: {section['missingBaseCount']}")

    lines.extend(["", "## Quest references", ""])
    ref_summary = report["questReferences"]["summary"]
    lines.append(f"- base DB references: {ref_summary['base']}")
    lines.append(f"- AC correction-only references: {ref_summary['acoreCorrectionOnly']}")
    lines.append(f"- type-mismatched references: {ref_summary['otherKind']}")
    lines.append(f"- missing base and correction references: {ref_summary['missingBaseAndCorrection']}")

    other_kind = report["questReferences"]["otherKind"]
    if other_kind:
        lines.extend(["", "## Type-mismatched referenced entities", ""])
        for reference in other_kind[:100]:
            present_as = ", ".join(reference["presentAsKinds"])
            lines.append(
                f"- quest {reference['questId']} {reference['field']} "
                f"{reference['entityKind']} {reference['entityId']} present as {present_as}"
            )
        if len(other_kind) > 100:
            lines.append(f"- ... {len(other_kind) - 100} more")

    missing = report["questReferences"]["missingBaseAndCorrection"]
    if missing:
        lines.extend(["", "## Missing referenced entities", ""])
        for reference in missing[:100]:
            lines.append(
                f"- quest {reference['questId']} {reference['field']} "
                f"{reference['entityKind']} {reference['entityId']}"
            )
        if len(missing) > 100:
            lines.append(f"- ... {len(missing) - 100} more")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    args = parse_args()

    base_ids = {kind: load_top_level_ids_from_lines(path) for kind, path in DEFAULT_BASE_DB.items()}
    correction_ids = {
        "quest": load_correction_ids(
            DEFAULT_ACORE_CORRECTIONS["quest"],
            ["local relationCorrections = ", "local metadataCorrections = "],
        ),
        "npc": load_correction_ids(DEFAULT_ACORE_CORRECTIONS["npc"], ["return {"]),
        "object": load_correction_ids(DEFAULT_ACORE_CORRECTIONS["object"], ["return {"]),
        "item": load_correction_ids(DEFAULT_ACORE_CORRECTIONS["item"], ["return {"]),
    }
    supported_ids = {kind: set(ids) for kind, ids in correction_ids.items()}
    supported_ids["item"].update(load_correction_ids(DEFAULT_ITEM_START_FIXES, ["return {"]))

    correction_report = {}
    for kind in sorted(base_ids):
        missing_base = correction_ids[kind] - base_ids[kind]
        correction_report[kind] = {
            "baseCount": len(base_ids[kind]),
            "correctionCount": len(correction_ids[kind]),
            "missingBaseCount": len(missing_base),
            "missingBaseIds": compact_ids(missing_base),
        }

    references = load_acore_quest_references(DEFAULT_ACORE_CORRECTIONS["quest"])
    classified_references = classify_references(references, base_ids, supported_ids)
    quest_reference_report = {
        "summary": {key: len(value) for key, value in classified_references.items()},
        "base": classified_references["base"],
        "acoreCorrectionOnly": classified_references["acoreCorrectionOnly"],
        "otherKind": classified_references["otherKind"],
        "missingBaseAndCorrection": classified_references["missingBaseAndCorrection"],
    }

    report = {
        "correctionIds": correction_report,
        "questReferences": quest_reference_report,
    }

    print("AzerothCore custom ID report")
    for kind, section in correction_report.items():
        print(f"{kind}: {section['missingBaseCount']} correction IDs missing from base DB")
    print(
        "quest references missing base and correction:",
        quest_reference_report["summary"]["missingBaseAndCorrection"],
    )
    print("quest references with type mismatch:", quest_reference_report["summary"]["otherKind"])

    if not args.no_write:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        write_markdown(args.markdown_report, report)
        print("WROTE", args.json_report)
        print("WROTE", args.markdown_report)


if __name__ == "__main__":
    main()
