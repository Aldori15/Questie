"""Syntax-check the addon's TOC/XML Lua files without loading the WoW client."""
import argparse
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def collect_lua_files(path, visited, lua_files):
    path = path.resolve()
    if path in visited:
        return
    visited.add(path)
    if path.suffix.lower() == ".lua":
        if not path.is_file():
            raise FileNotFoundError(path)
        lua_files.add(path)
    elif path.suffix.lower() == ".xml":
        # WoW XML can contain unbound xsi prefixes; only its file references are
        # needed here. Ignore commented-out includes, as the client does.
        text = re.sub(r"<!--.*?-->", "", path.read_text(encoding="utf-8-sig"), flags=re.S)
        for reference in re.findall(r'''<(?:Script|Include)\b[^>]*\bfile\s*=\s*["']([^"']+)["']''', text):
            collect_lua_files(path.parent / reference.replace("\\", "/"), visited, lua_files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luac", default="luac5.1", help="Lua compiler executable (syntax checks only)")
    args = parser.parse_args()
    visited, lua_files = set(), set()
    for line in (ROOT / "Questie-335.toc").read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            collect_lua_files(ROOT / line.replace("\\", "/"), visited, lua_files)
    for path in sorted(lua_files):
        subprocess.run([args.luac, "-p", str(path)], check=True)
    print(f"Lua syntax: {len(lua_files)} addon files passed")


if __name__ == "__main__":
    main()
