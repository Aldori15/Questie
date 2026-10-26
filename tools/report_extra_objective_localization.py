"""Report extra-objective translation consumers without deleting translations.

Run after generating acoreQuestDB.lua. Unused candidates require manual review:
arbitrary dynamic string construction and future generator coverage are not proof
of use or disuse. This tool never executes addon Lua or changes addon sources.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re

from generate_acore_npc_corrections import LuaParser
from questie_base import base_text, parse_keys


ROOT = Path(__file__).resolve().parents[1]
TRANSLATION_DIRECTORY = Path("Localization/Translations/ExtraObjectives")
TRANSLATION_FILE = Path("Localization/Translations/ExtraObjectives.lua")
BASE_FILES = re.compile(r"acore(?:Item|Npc|Object|Quest)DB\.lua$")
LONG_OPEN = re.compile(r"\[(=*)\[")


class StringParser(LuaParser):
    """Extend the maintained literal parser for Lua byte and control escapes."""

    identifier = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*")

    def try_parse_identifier(self):
        self.skip_ws()
        match = self.identifier.match(self.text, self.index)
        if not match:
            return None
        self.index = match.end()
        return match.group(0)

    def parse_string(self):
        quote = self.peek()
        self.index += 1
        output = bytearray()
        escapes = {"a": 7, "b": 8, "f": 12, "n": 10, "r": 13, "t": 9, "v": 11}
        while self.index < self.length:
            char = self.text[self.index]
            self.index += 1
            if char == quote:
                return output.decode("utf-8", errors="surrogateescape")
            if char != "\\":
                output.extend(char.encode("utf-8"))
                continue
            if self.index >= self.length:
                break
            escaped = self.text[self.index]
            self.index += 1
            if escaped.isascii() and escaped.isdigit():
                digits = escaped
                while len(digits) < 3 and self.index < self.length and self.text[self.index].isascii() and self.text[self.index].isdigit():
                    digits += self.text[self.index]
                    self.index += 1
                value = int(digits)
                if value > 255:
                    raise ValueError("Lua byte escape exceeds 255")
                output.append(value)
            elif escaped in escapes:
                output.append(escapes[escaped])
            elif escaped in "\r\n":
                if self.index < self.length and self.text[self.index] in "\r\n" and self.text[self.index] != escaped:
                    self.index += 1
                output.append(10)
            else:
                # Lua 5.1 preserves an escaped quote/backslash or other character.
                output.extend(escaped.encode("utf-8"))
        raise ValueError("Unterminated Lua string")


def lua_strings(text):
    """Yield decoded literal strings and source locations, excluding comments."""
    index, line = 0, 1
    while index < len(text):
        start, first_line = index, line
        if text.startswith("--", index):
            index += 2
            opening = LONG_OPEN.match(text, index)
            if opening:
                closing = "]" + opening.group(1) + "]"
                end = text.find(closing, opening.end())
                if end < 0:
                    raise ValueError(f"Unterminated Lua comment at line {line}")
                index = end + len(closing)
            else:
                end = text.find("\n", index)
                index = len(text) if end < 0 else end
        elif text[index] in "\"'":
            parser = StringParser(text)
            parser.index = index
            value = parser.parse_string()
            index = parser.index
            yield {"value": value, "line": first_line, "start": start, "end": index}
        else:
            opening = LONG_OPEN.match(text, index)
            if opening:
                closing = "]" + opening.group(1) + "]"
                end = text.find(closing, opening.end())
                if end < 0:
                    raise ValueError(f"Unterminated Lua long string at line {line}")
                value = text[opening.end():end]
                if value.startswith("\r\n"):
                    value = value[2:]
                elif value.startswith(("\n", "\r")):
                    value = value[1:]
                index = end + len(closing)
                yield {"value": value, "line": first_line, "start": start, "end": index}
            else:
                index += 1
        line += text.count("\n", start, index)


def translation_definitions(root):
    definitions = defaultdict(list)
    paths = sorted((root / TRANSLATION_DIRECTORY).glob("*.lua"))
    if (root / TRANSLATION_FILE).is_file():
        paths.append(root / TRANSLATION_FILE)
    if not paths:
        raise ValueError("ExtraObjectives translation dictionaries are missing")
    for path in paths:
        text = path.read_text(encoding="utf-8-sig")
        for token in lua_strings(text):
            prefix = text[text.rfind("\n", 0, token["start"]) + 1:token["start"]]
            if re.fullmatch(r"\s*\[\s*", prefix) and re.match(r"\s*\]\s*=\s*\{", text[token["end"]:]):
                definitions[token["value"]].append({"file": path.relative_to(root).as_posix(), "line": token["line"]})
    return definitions, paths


def at(value, index):
    if isinstance(value, dict):
        return value.get(index)
    if isinstance(value, list) and index <= len(value):
        return value[index - 1]
    return None


def values(value):
    return value.values() if isinstance(value, dict) else value or []


def generated_guide_consumers(root, quest_db):
    # The generated header is authoritative and has no nested-table comments.
    # The legacy schema file contains braces in comments which are not fields.
    key = parse_keys(quest_db, "quest")["extraObjectives"]
    quests = StringParser(base_text(quest_db)).parse()
    if not isinstance(quests, dict):
        raise ValueError("Expected quest records keyed by quest ID")
    consumers = defaultdict(list)
    for quest_id, row in sorted(quests.items()):
        for index, guide in enumerate(values(at(row, key)), 1):
            description = at(guide, 3)
            if isinstance(description, str):
                consumers[description].append({"questId": quest_id, "guideIndex": index})
    return consumers


def runtime_files(root):
    # Keep references from every maintained runtime source, even inactive branches.
    # Translation definitions, localized lookup data and development artifacts do
    # not establish a runtime translation consumer.
    paths = set(root.glob("*.lua"))
    for directory in ("Database", "Modules", "Compat"):
        paths.update((root / directory).rglob("*.lua"))
    paths.add(root / "Localization/l10n.lua")
    return sorted(path for path in paths if path.is_file() and not BASE_FILES.fullmatch(path.name))


def audit(root, quest_db=None):
    root = Path(root).resolve()
    quest_db = Path(quest_db or root / "Database/AzerothCore/acoreQuestDB.lua").resolve()
    definitions, dictionaries = translation_definitions(root)
    generated = generated_guide_consumers(root, quest_db)
    runtime = defaultdict(list)
    paths = runtime_files(root)
    for path in paths:
        for token in lua_strings(path.read_text(encoding="utf-8-sig")):
            if token["value"] in definitions:
                runtime[token["value"]].append({"file": path.relative_to(root).as_posix(), "line": token["line"]})
    used, unused = [], []
    for key in sorted(definitions):
        entry = {"key": key, "definitions": definitions[key]}
        if generated[key] or runtime[key]:
            entry.update({"usedByGeneratedGuides": generated[key], "usedByRuntimeLiterals": runtime[key]})
            used.append(entry)
        else:
            unused.append(entry)
    return {
        "summary": {"translationKeys": len(definitions), "translationDefinitions": sum(map(len, definitions.values())),
                    "usedKeys": len(used), "unusedCandidates": len(unused), "runtimeFilesScanned": len(paths)},
        "scope": "Current unlocalized base extraObjectives and exact Lua literals in maintained runtime sources.",
        "reviewRequired": True,
        "limitations": ["A literal reference may be an inactive producer; references are retained conservatively.",
                        "Arbitrary dynamic string construction and future generator outputs are not resolved.",
                        "Unused candidates are not approved deletions. Review recovered flight guides and shared keys first."],
        "questBase": {"path": str(quest_db), "sha256": hashlib.sha256(quest_db.read_bytes()).hexdigest()},
        "dictionaries": [{"file": path.relative_to(root).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                         for path in dictionaries],
        "used": used,
        "unusedCandidates": unused,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon-root", type=Path, default=ROOT)
    parser.add_argument("--quest-db", type=Path, help="Generated unlocalized quest base; defaults to the addon base")
    parser.add_argument("--report", type=Path, default=Path("tools/reports/extra_objective_localization.json"))
    args = parser.parse_args(argv)
    root = args.addon_root.resolve()
    quest_db = root / args.quest_db if args.quest_db else None
    report = audit(root, quest_db)
    output = (root / args.report).resolve()
    if not output.is_relative_to(root / "tools/reports") or output.suffix != ".json":
        raise ValueError("Localization report must be a .json file under tools/reports")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=True) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(output), **report["summary"], "reviewRequired": True}, indent=2))


if __name__ == "__main__":
    main()
