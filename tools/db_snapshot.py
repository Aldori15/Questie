"""Capture Questie's Lua correction pipeline and compare effective database snapshots."""
import argparse
from collections import Counter
from contextlib import contextmanager, ExitStack
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from uuid import uuid4


ROOT = Path(__file__).resolve().parents[1]
FORMAT = "questie-db-snapshot"
VERSION = 1
SUPPORT_MODULES = {
    "Modules/Phasing.lua",
    "Modules/QuestieProfessions.lua",
    "Modules/Quest/IsleOfQuelDanas.lua",
}
EXCLUDED_DATABASES = ("Database/QuestXP/", "Database/DropTables/")
MISSING = object()


def json_line(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n"


def source_files(root):
    """Preserve active TOC/XML order, including registration before schema loading."""
    root = Path(root).resolve()
    selected, manifests = [], []

    def visit(path, ancestors=()):
        path = path.resolve()
        if not path.is_relative_to(root):
            raise ValueError(f"Manifest references a file outside the addon: {path}")
        if path in ancestors:
            raise ValueError(f"Circular manifest include: {path}")
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8-sig")
        if path.suffix.lower() == ".toc":
            manifests.append(relative)
            for line in text.splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    visit(path.parent / line.replace("\\", "/"), ancestors + (path,))
        elif path.suffix.lower() == ".xml":
            manifests.append(relative)
            text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
            if relative.startswith("Database/"):
                for inline in re.findall(r"<Script\b(?![^>]*\bfile\s*=)[^>]*>(.*?)</Script>", text, re.S):
                    if inline.strip() and not re.fullmatch(r"QuestieLoader:StampLoadBoundary\([^;\n]+\)\s*;?", inline.strip()):
                        raise ValueError(f"Unsupported inline database script in {relative}; update the capture adapter")
            for reference in re.findall(r'''<(?:Script|Include)\b[^>]*\bfile\s*=\s*["']([^"']+)["']''', text):
                visit(path.parent / reference.replace("\\", "/"), ancestors + (path,))
        elif relative in SUPPORT_MODULES or relative == "Compat/Corrections.lua" or (
            relative.startswith("Database/")
            and relative != "Database/compiler.lua"
            and not relative.startswith(EXCLUDED_DATABASES)
        ):
            selected.append(relative)

    visit(root / "Questie-335.toc")
    if not SUPPORT_MODULES.issubset(selected):
        raise ValueError("Required support modules are absent from the TOC; update the capture adapter")
    return selected, list(dict.fromkeys(manifests + selected + [
        "Questie.lua", "Compat/Compat.lua", "Modules/QuestieInit.lua", "Database/compiler.lua",
    ]))


def lua_executable(explicit=None):
    choices = [explicit] if explicit else [
        os.environ.get("QUESTIE_TEST_LUA"), "lua5.1", "lua5.2", "lua5.3", "lua5.4", "lua",
    ]
    for choice in filter(None, choices):
        found = shutil.which(choice)
        if found:
            return found
    raise ValueError("Lua is required for capture. Supply --lua PATH or set QUESTIE_TEST_LUA.")


def file_hash(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git_info(root):
    def run(*args):
        try:
            result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, encoding="utf-8")
        except FileNotFoundError:
            return None
        return result.stdout.strip() if result.returncode == 0 else None
    return {"commit": run("rev-parse", "HEAD"), "status": run("status", "--porcelain")}


def lua_string(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"').replace("\r", "\\r").replace("\n", "\\n") + '"'


def record_key(record):
    if set(record) != {"context", "section", "id", "value"}:
        raise ValueError("Invalid snapshot record fields")
    if not isinstance(record["context"], str) or not isinstance(record["section"], str):
        raise ValueError("Invalid snapshot context or section")
    entity_id = record["id"]
    if type(entity_id) not in (int, str):
        raise ValueError("Snapshot record IDs must be integers or strings")
    return record["context"], record["section"], 0 if isinstance(entity_id, int) else 1, entity_id


def open_snapshot(path, mode):
    opener = gzip.open if str(path).endswith(".gz") else open
    return opener(path, mode + "t", encoding="utf-8", newline="\n")


@contextmanager
def temporary_directory(parent):
    # Inherit the output directory's ACL on Windows. Python 3.13's mkdtemp
    # owner-only ACL can exclude restricted execution tokens used by tooling.
    parent = Path(parent).resolve()
    parent.mkdir(parents=True, exist_ok=True)
    path = parent / ("questie-snapshot-" + uuid4().hex)
    path.mkdir(mode=0o755)
    try:
        yield path
    finally:
        if path.is_symlink() or path.resolve().parent != parent:
            raise ValueError("Temporary capture directory no longer resolves under its parent")
        shutil.rmtree(path)


class SnapshotWriter:
    def __init__(self, stream, metadata):
        self.stream, self.digest, self.count = stream, hashlib.sha256(), 0
        self.previous = None
        self.contexts, self.seen = set(metadata["contexts"]), set()
        stream.write(json_line({"kind": "header", "format": FORMAT, "version": VERSION, "metadata": metadata}))

    def add(self, record):
        key = record_key(record)
        if record["context"] not in self.contexts:
            raise ValueError("Unexpected capture context: " + record["context"])
        if self.previous is not None and key <= self.previous:
            raise ValueError("Duplicate or unsorted snapshot record: " + repr(key))
        line = json_line(record)
        self.stream.write(line)
        self.digest.update(line.encode("utf-8"))
        self.count += 1
        self.seen.add(record["context"])
        self.previous = key

    def finish(self):
        if self.seen != self.contexts:
            raise ValueError("Capture did not produce every requested context")
        self.stream.write(json_line({"kind": "footer", "records": self.count, "sha256": self.digest.hexdigest()}))


def read_header(stream):
    try:
        header = json.loads(next(stream))
    except (StopIteration, json.JSONDecodeError) as exc:
        raise ValueError("Missing or invalid snapshot header") from exc
    if not isinstance(header, dict) or header.get("kind") != "header" or header.get("format") != FORMAT or header.get("version") != VERSION:
        raise ValueError("Unsupported snapshot format/version")
    if not isinstance(header.get("metadata"), dict):
        raise ValueError("Missing snapshot contexts")
    contexts = header["metadata"].get("contexts")
    if not isinstance(contexts, list) or not contexts or any(not isinstance(item, str) for item in contexts) or len(contexts) != len(set(contexts)):
        raise ValueError("Invalid snapshot contexts")
    return header


def read_records(stream, contexts):
    digest, count, previous, seen = hashlib.sha256(), 0, None, set()
    for line in stream:
        record = json.loads(line)
        if not isinstance(record, dict):
            raise ValueError("Snapshot lines must be JSON objects")
        if record.get("kind") == "footer":
            if record.get("records") != count or record.get("sha256") != digest.hexdigest():
                raise ValueError("Snapshot footer checksum/count mismatch")
            if seen != set(contexts):
                raise ValueError("Snapshot is missing a requested context")
            if next(stream, None) is not None:
                raise ValueError("Unexpected data after snapshot footer")
            return
        key = record_key(record)
        if record["context"] not in contexts or (previous is not None and key <= previous):
            raise ValueError("Invalid context, duplicate, or unsorted snapshot record")
        digest.update(line.encode("utf-8"))
        count += 1
        previous = key
        seen.add(record["context"])
        yield record
    raise ValueError("Incomplete snapshot: missing footer")


def capture(args):
    root, output = args.repo.resolve(), args.output.resolve()
    if output.exists() and not args.force:
        raise ValueError(f"Snapshot already exists: {output}. Use a new name or --force.")
    executable = lua_executable(args.lua)
    files, dependencies = source_files(root)
    contexts = sorted({f"{faction}/isle-{phase}": {"name": f"{faction}/isle-{phase}", "faction": faction, "islePhase": phase}
                       for faction in args.factions for phase in args.isle_phases}.values(), key=lambda item: item["name"])
    hashes = {path: file_hash(root / path) for path in dependencies}
    inputs = {str(path.resolve()): file_hash(path) for path in args.input}
    harness = Path(__file__).with_suffix(".lua")
    runtime = subprocess.run([executable, "-v"], capture_output=True, text=True)
    if runtime.returncode:
        raise ValueError("Could not identify Lua runtime")
    metadata = {
        "contexts": [item["name"] for item in contexts], "locale": "enUS",
        "scope": "post-corrections-pre-localization-v1", "repo": str(root), "git": git_info(root),
        "lua": (runtime.stdout + runtime.stderr).strip(), "load_order": files, "sources": hashes,
        "inputs": inputs, "harness": {"python": file_hash(__file__), "lua": file_hash(harness)},
    }
    plan = "return {root=" + lua_string(root.as_posix()) + ",files={" + ",".join(map(lua_string, files)) + "},contexts={"
    plan += ",".join("{name=" + lua_string(item["name"]) + ",faction=" + lua_string(item["faction"])
                     + ",islePhase=" + str(item["islePhase"]) + "}" for item in contexts) + "}}\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    print(f"Capturing {len(contexts)} contexts using {metadata['lua']}...", flush=True)
    # The candidate is published only after Lua exits successfully, all records
    # validate, and source/input hashes are unchanged throughout the capture.
    with temporary_directory(output.parent) as temporary:
        plan_path = temporary / "plan.lua"
        plan_path.write_text(plan, encoding="utf-8")
        candidate = temporary / ("snapshot.jsonl.gz" if str(output).endswith(".gz") else "snapshot.jsonl")
        with open_snapshot(candidate, "w") as stream, (temporary / "stderr.log").open("w+b") as errors:
            writer = SnapshotWriter(stream, metadata)
            with subprocess.Popen([executable, str(harness), "--capture", str(plan_path)], stdout=subprocess.PIPE, stderr=errors) as process:
                try:
                    for line in process.stdout:
                        writer.add(json.loads(line.decode("utf-8")))
                    returncode = process.wait()
                    errors.seek(0)
                    diagnostic = errors.read().decode("utf-8", errors="replace")
                    if returncode:
                        raise ValueError("Lua capture failed:\n" + diagnostic)
                    print(diagnostic.rstrip())
                except BaseException:
                    process.kill()
                    process.wait()
                    raise
            if not writer.count:
                raise ValueError("Lua capture produced no records")
            if hashes != {path: file_hash(root / path) for path in dependencies} or inputs != {path: file_hash(path) for path in inputs}:
                raise ValueError("Capture inputs changed while Lua was running; retry the capture")
            if metadata["harness"] != {"python": file_hash(__file__), "lua": file_hash(harness)}:
                raise ValueError("The capture harness changed while Lua was running; retry the capture")
            writer.finish()
        os.replace(candidate, output)
    print(f"Captured {writer.count} records across {len(contexts)} contexts: {output}")
    return 0


def display_key(key):
    if key.startswith("n:"):
        return "[" + key[2:] + "]"
    if key.startswith("s:"):
        key = key[2:]
        if key.isidentifier():
            return "." + key
    return "[" + json.dumps(key, ensure_ascii=False) + "]"


def differences(before, after, path=""):
    if before is MISSING or after is MISSING:
        yield path, before, after
    elif isinstance(before, dict) and isinstance(after, dict):
        for key in sorted(before.keys() | after.keys()):
            yield from differences(before.get(key, MISSING), after.get(key, MISSING), path + display_key(key))
    else:
        before_number = type(before) in (int, float)
        after_number = type(after) in (int, float)
        if before != after or (type(before) is not type(after) and not (before_number and after_number)):
            yield path, before, after


def short_value(value):
    if value is MISSING:
        return "<absent>"
    text = json.dumps(value, ensure_ascii=False)
    return text if len(text) <= 160 else text[:157] + "..."


def compare(args):
    if args.report and args.report.resolve() in {args.before.resolve(), args.after.resolve()}:
        raise ValueError("The report must not overwrite an input snapshot")
    with ExitStack() as resources, open_snapshot(args.before, "r") as left, open_snapshot(args.after, "r") as right:
        a_header, b_header = read_header(left), read_header(right)
        for field in ("contexts", "locale", "scope"):
            if a_header["metadata"].get(field) != b_header["metadata"].get(field):
                raise ValueError(f"Snapshot {field} differ; capture matching contexts and scope")
        contexts = a_header["metadata"]["contexts"]
        a_iter, b_iter = read_records(left, contexts), read_records(right, contexts)
        a, b = next(a_iter, None), next(b_iter, None)
        count, summary = 0, Counter()
        report = None
        try:
            if args.report:
                args.report.parent.mkdir(parents=True, exist_ok=True)
                report_path = resources.enter_context(temporary_directory(args.report.parent)) / "differences.jsonl"
                report = report_path.open("w", encoding="utf-8", newline="\n")
            while a is not None or b is not None:
                a_key, b_key = record_key(a) if a else None, record_key(b) if b else None
                if b is None or (a is not None and a_key < b_key):
                    current, old, new = a, a["value"], MISSING
                    a = next(a_iter, None)
                elif a is None or b_key < a_key:
                    current, old, new = b, MISSING, b["value"]
                    b = next(b_iter, None)
                else:
                    current, old, new = a, a["value"], b["value"]
                    a, b = next(a_iter, None), next(b_iter, None)
                for path, old_value, new_value in differences(old, new):
                    count += 1
                    summary[current["section"]] += 1
                    change = {"context": current["context"], "section": current["section"], "id": current["id"],
                              "path": path, "change": "added" if old_value is MISSING else "removed" if new_value is MISSING else "changed"}
                    if old_value is not MISSING:
                        change["before"] = old_value
                    if new_value is not MISSING:
                        change["after"] = new_value
                    if report:
                        report.write(json_line(change))
                    if count <= args.limit:
                        print(f"{current['context']} {current['section']}[{current['id']}]{path}: "
                              f"{short_value(old_value)} -> {short_value(new_value)}")
        finally:
            if report:
                report.close()
        if report:
            os.replace(report_path, args.report)
    print(f"Differences: {count}")
    for section, total in sorted(summary.items()):
        print(f"  {section}: {total}")
    return 1 if count else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    take = commands.add_parser("capture", help="Run the actual Lua correction pipeline and freeze its effective data")
    take.add_argument("--repo", type=Path, default=ROOT)
    take.add_argument("--lua", help="Lua executable (or set QUESTIE_TEST_LUA)")
    take.add_argument("--output", type=Path, required=True)
    take.add_argument("--factions", nargs="+", choices=("Alliance", "Horde"), default=["Alliance", "Horde"])
    take.add_argument("--isle-phases", nargs="+", type=int, choices=range(1, 10), default=[1, 9])
    take.add_argument("--input", type=Path, action="append", default=[], help="Optional external generation input to hash; repeat per export/DBC/CSV")
    take.add_argument("--force", action="store_true", help="Replace an existing snapshot")
    take.set_defaults(action=capture)
    diff = commands.add_parser("compare", help="Compare snapshots; exit 0 for equal, 1 for changes, 2 for errors")
    diff.add_argument("before", type=Path)
    diff.add_argument("after", type=Path)
    diff.add_argument("--report", type=Path, help="Write all differences as JSON Lines")
    diff.add_argument("--limit", type=int, default=20, help="Maximum differences printed (all are still checked)")
    diff.set_defaults(action=compare)
    args = parser.parse_args(argv)
    try:
        return args.action(args)
    except (ValueError, OSError, EOFError) as exc:
        parser.exit(2, f"error: {exc}\n")


if __name__ == "__main__":
    sys.exit(main())
