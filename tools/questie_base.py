"""Read shared database rows without executing Lua or consuming runtime metadata."""
import re
from pathlib import Path


def parse_keys(path, kind):
    text = Path(path).read_text(encoding="utf-8-sig")
    match = re.search(r"QuestieDB\." + kind + r"Keys\s*=\s*\{(.*?)\}", text, re.DOTALL)
    if not match:
        raise ValueError(f"{path}: missing {kind}Keys")
    return {name: int(value) for _, name, value in
            re.findall(r"\[([\"'])(.*?)\1\]\s*=\s*(\d+)", match.group(1))}


def base_text(path):
    text = Path(path).read_text(encoding="utf-8-sig")
    match = re.search(r"QuestieDB\.(?:item|npc|object|quest)Data\s*=", text)
    if not match:
        return text  # Plain-table fixtures and older input formats.
    return return_table(text, match.group(0))


def return_table(text, marker):
    """Return one merged table from the supported serialized source formats."""
    if marker not in text:
        raise ValueError(f"Could not find marker {marker!r}")
    start = text.index(marker) + len(marker)
    chunks = []
    seen = set()
    for match in re.finditer(r"\[(=*)\[(.*?)\]\1\]", text[start:], re.DOTALL):
        source = match.group(2).strip()
        if re.match(r"return\s*\{", source):
            body = source[source.index("{") + 1:].rstrip()
            if not body.endswith("}"):
                raise ValueError(f"Incomplete database source after {marker}")
            body = body[:-1].strip().rstrip(",")
            for row in re.finditer(r"^\s*\[(\d+)\]\s*=", body, re.MULTILINE):
                identifier = int(row.group(1))
                if identifier in seen:
                    raise ValueError(f"Duplicate database record {identifier}")
                seen.add(identifier)
            chunks.append(body)
    if not chunks:
        raise ValueError(f"Could not find database source after {marker}")
    return "{\n" + ",\n".join(chunks) + "\n}"


class LuaTableParser:
    def __init__(self, text: str):
        self.text = text
        self.length = len(text)
        self.index = 0

    def parse(self):
        value = self._parse_value()
        self._skip_ws()
        return value

    def _skip_ws(self):
        while self.index < self.length and self.text[self.index] in " \t\r\n":
            self.index += 1

    def _peek(self):
        return self.text[self.index] if self.index < self.length else ""

    def _parse_value(self):
        self._skip_ws()
        char = self._peek()
        if char == "{":
            return self._parse_table()
        if char == '"':
            return self._parse_string('"')
        if char == "'":
            return self._parse_string("'")
        if char == "-" or char.isdigit():
            return self._parse_number()
        if self.text.startswith("nil", self.index):
            self.index += 3
            return None
        if self.text.startswith("true", self.index):
            self.index += 4
            return True
        if self.text.startswith("false", self.index):
            self.index += 5
            return False
        raise ValueError(f"Unsupported Lua token near: {self.text[self.index:self.index + 32]!r}")

    def _parse_table(self):
        assert self._peek() == "{"
        self.index += 1
        items = {}
        next_index = 1

        while True:
            self._skip_ws()
            if self._peek() == "}":
                self.index += 1
                return [items.get(i) for i in range(1, max(items, default=0) + 1)]

            if self._peek() == "[":
                self.index += 1
                self._skip_ws()
                key = self._parse_number()
                if key < 1:
                    raise ValueError("Expected a positive array index")
                self._skip_ws()
                if self._peek() != "]":
                    raise ValueError("Missing closing array index")
                self.index += 1
                self._skip_ws()
                if self._peek() != "=":
                    raise ValueError("Missing array assignment")
                self.index += 1
                items[key] = self._parse_value()
            else:
                items[next_index] = self._parse_value()
                next_index += 1
            self._skip_ws()

            char = self._peek()
            if char == ",":
                self.index += 1
                continue
            if char == "}":
                self.index += 1
                return [items.get(i) for i in range(1, max(items, default=0) + 1)]
            raise ValueError(f"Unexpected character in Lua table: {char!r}")

    def _parse_string(self, delimiter):
        assert self._peek() == delimiter
        self.index += 1
        chars = []

        while self.index < self.length:
            char = self.text[self.index]
            self.index += 1
            if char == "\\":
                if self.index >= self.length:
                    break
                escaped = self.text[self.index]
                self.index += 1
                escape_map = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "'": "'", "\\": "\\"}
                chars.append(escape_map.get(escaped, escaped))
                continue
            if char == delimiter:
                return "".join(chars)
            chars.append(char)

        raise ValueError("Unterminated Lua string")

    def _parse_number(self):
        start = self.index
        if self._peek() == "-":
            self.index += 1
        while self.index < self.length and self.text[self.index].isdigit():
            self.index += 1
        return int(self.text[start:self.index])

