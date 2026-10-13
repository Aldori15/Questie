import argparse
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPO_ROOT / "Database" / "AzerothCore" / "AzerothCoreQuestCorrections.lua"
DEFAULT_QUESTIE_DB = REPO_ROOT / "Database" / "QuestieDB.lua"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert numeric quest specialFlags values to specialFlags expressions."
    )
    parser.add_argument(
        "source",
        nargs="?",
        type=Path,
        default=DEFAULT_SOURCE,
        help="Lua corrections file to convert. Defaults to Database/AzerothCore/AzerothCoreQuestCorrections.lua.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output file. Defaults to <source>.new.",
    )
    parser.add_argument(
        "--questie-db",
        type=Path,
        default=DEFAULT_QUESTIE_DB,
        help="QuestieDB.lua path used to read specialFlags.",
    )
    parser.add_argument(
        "--no-chain-output",
        action="store_true",
        help="Read from source even when the output file already exists.",
    )
    return parser.parse_args()


def output_path_for(source, output):
    return output if output else source.with_name(source.name + ".new")


def parse_key_mapping(questie_db, table_name):
    text = questie_db.read_text(encoding="utf-8")
    match = re.search(rf"QuestieDB\.{table_name}\s*=\s*\{{(.*?)\}}\s*", text, re.S)
    if not match:
        raise SystemExit(f"ERROR: failed to find {table_name} in {questie_db}")

    mapping = {}
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("--"):
            continue

        line_match = re.match(r"([A-Z0-9_]+)\s*=\s*(.+?),?$", line)
        if not line_match:
            continue

        name, expr = line_match.groups()
        nums = re.findall(r"(-?\d+)", expr.strip().rstrip(","))
        if nums:
            mapping[name] = int(nums[-1])

    if not mapping:
        raise SystemExit(f"ERROR: no {table_name} values parsed from {questie_db}")

    return mapping


def make_num_to_expr(mapping):
    base_flags = sorted(
        [(name, value) for name, value in mapping.items() if value > 0 and (value & (value - 1)) == 0],
        key=lambda item: -item[1],
    )
    inverse = {value: name for name, value in mapping.items()}

    def num_to_expr(num_str):
        num = int(num_str)
        if num == 0:
            return "specialFlags.NONE"
        if num in inverse:
            return f"specialFlags.{inverse[num]}"

        parts = []
        remainder = num
        for name, value in base_flags:
            if remainder & value:
                parts.append(f"specialFlags.{name}")
                remainder -= value

        if remainder != 0 and remainder in inverse:
            parts.append(f"specialFlags.{inverse[remainder]}")
            remainder = 0

        return " + ".join(parts) if remainder == 0 else str(num)

    return num_to_expr


def main():
    args = parse_args()
    source = args.source.resolve()
    questie_db = args.questie_db.resolve()
    output = output_path_for(source, args.output).resolve()

    if not source.exists():
        raise SystemExit(f"ERROR: source file not found: {source}")
    if not questie_db.exists():
        raise SystemExit(f"ERROR: QuestieDB.lua not found: {questie_db}")

    input_path = output if output.exists() and not args.no_chain_output else source
    mapping = parse_key_mapping(questie_db, "specialFlags")
    num_to_expr = make_num_to_expr(mapping)

    text = input_path.read_text(encoding="utf-8")
    pattern = re.compile(r"(\[questKeys\.specialFlags\]\s*=\s*)(\d+)(\s*,)")
    new_text = pattern.sub(lambda match: match.group(1) + num_to_expr(match.group(2)) + match.group(3), text)

    if new_text == text:
        print("No changes needed; no numeric specialFlags found to convert.")
        return

    output.write_text(new_text, encoding="utf-8")
    print("WROTE", output)


if __name__ == "__main__":
    main()
