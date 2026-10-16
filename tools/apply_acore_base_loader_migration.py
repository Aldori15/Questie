#!/usr/bin/env python3
"""Guarded PR #166 stage-two loader migration for Questie 3.3.5.

Usage (at clean refactor/db-restructure repository root):
    python tools/apply_acore_base_loader_migration.py --check
    python tools/apply_acore_base_loader_migration.py --apply

Uses the existing four complete snapshot-backed acore*DB.lua files. Retains
legacy correction modules for the faction-specific overrides used by fresh and
cached startup. Deliberately does not migrate the maintenance generators.
"""
from __future__ import annotations
import argparse
import re
import subprocess
from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[1]

OLD_BASES = {
    "Database\\Wotlk\\wotlkItemDB.lua": "Database\\AzerothCore\\acoreItemDB.lua",
    "Database\\Wotlk\\wotlkNpcDB.lua": "Database\\AzerothCore\\acoreNpcDB.lua",
    "Database\\Wotlk\\wotlkObjectDB.lua": "Database\\AzerothCore\\acoreObjectDB.lua",
    "Database\\Wotlk\\wotlkQuestDB.lua": "Database\\AzerothCore\\acoreQuestDB.lua",
}
OLD_REGISTRATIONS = (
    '    <Script file="AzerothCoreQuestCorrections.lua"/>\n',
    '    <Script file="AzerothCoreItemCorrections.lua"/>\n',
    '    <Script file="AzerothCoreNPCCorrections.lua"/>\n',
    '    <Script file="AzerothCoreObjectCorrections.lua"/>\n',
)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    matches = text.count(old)
    if matches != 1:
        raise ValueError(f"{label}: expected exactly one occurrence, found {matches}")
    return text.replace(old, new, 1)


def command(*args):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise ValueError(f"Command failed: {' '.join(args)}\n{result.stderr}")
    return result.stdout.strip()


def require_clean_branch():
    if not (ROOT / ".git").exists():
        raise ValueError("Run this script from a Git checkout, not from the ZIP folder")
    branch = command("git", "branch", "--show-current")
    if branch != "refactor/db-restructure":
        raise ValueError(f"Wrong branch: {branch!r}; expected 'refactor/db-restructure'")
    # This migration script is *copied into the checkout*, so it is untracked.
    # Reject tracked changes but allow our own untracked migration script.
    tracked = command("git", "diff", "--name-only", "HEAD", "--")
    if tracked:
        raise ValueError("Commit/stash tracked modifications first:\n" + tracked)
    missing = [v for v in OLD_BASES.values() if not (ROOT / v.replace('\\', '/')).is_file()]
    if missing:
        raise ValueError("Missing staged complete base file(s): " + ', '.join(missing))
    for name, field in (("acoreQuestDB.lua", "questData"), ("acoreNpcDB.lua", "npcData"),
                        ("acoreObjectDB.lua", "objectData"), ("acoreItemDB.lua", "itemData")):
        data = (ROOT / "Database/AzerothCore" / name).read_text(encoding="utf-8")
        if f'QuestieDB.{field} = [====[return {{' not in data:
            raise ValueError(f"Unexpected base format in {name}")


def patch_toc(s):
    for old, new in OLD_BASES.items():
        s = replace_once(s, old, new, "TOC " + old)
    return s


def patch_xml(s):
    for line in OLD_REGISTRATIONS:
        s = replace_once(s, line, "", "XML " + line.strip())
    s = replace_once(s,
        '    <!-- Register callbacks now; QuestieCorrections applies them after expansion fixes. -->',
        '    <!-- Separate non-base server metadata: the four static databases load in Questie-335.toc. -->',
        "XML comment")
    return s


def patch_corrections(s):
    # Keep runtime / faction-only MinimalInit() and all post-processing intact.
    # The generated bases already represent the effective state *after* the old
    # static correction chain, including Compat and AzerothCore callbacks.
    begin = 'function QuestieCorrections:Initialize(validationTables)\n'
    end = '    local patchCount = 0\n'
    a = s.find(begin)
    if a < 0 or s.find(begin, a+1) >= 0:
        raise ValueError("Cannot locate a unique correction initializer")
    b = s.find(end, a + len(begin))
    if b < 0 or s.find(end, b+1) >= 0:
        raise ValueError("Cannot locate a unique derived-data boundary")
    old = s[a+len(begin):b]
    expected_fragments = (
        'QuestieQuestFixes:Load()', 'QuestieTBCQuestFixes:Load()',
        'QuestieWotlkQuestFixes:Load()', 'QuestieItemStartFixes:LoadAutomaticQuestStarts()',
        'QuestieCompat.LoadCorrections(_LoadCorrections, validationTables)',
    )
    if not all(fragment in old for fragment in expected_fragments):
        raise ValueError("Unexpected static-correction pipeline; refuse to patch")
    new = '''    -- PR #166: the acore*DB.lua bases contain the complete corrected static
    -- database captured after the former Classic/TBC/WotLK, Compat and AC
    -- correction layers. Reapplying those patches would change their values.
    -- Faction overrides/blacklists still initialize in MinimalInit() below,
    -- on both fresh compile and cached startup. Keep the old fix modules loaded
    -- for those runtime methods until Manual335 migration is complete.
    -- This step does not change required-race inference or other derived data.

'''
    return s[:a+len(begin)] + new + s[b:]


def patch_schema_version(s):
    s = replace_once(s,
        '-- Bump when field types/order or generated visibility coverage change to invalidate cached DB blobs.',
        '-- Bump for schema or base-database migration changes to invalidate cached DB blobs.',
        'compiler schema note')
    return replace_once(s, 'QuestieDBCompiler.compiledSchemaVersion = 64',
                        'QuestieDBCompiler.compiledSchemaVersion = 65', 'compiler cache version')


def patch_snapshot_test(s):
    old = '''        self.assertLess(paths.index("Compat/Corrections.lua"), paths.index("Database/AzerothCore/AzerothCoreQuestCorrections.lua"))
        self.assertLess(paths.index("Database/AzerothCore/AzerothCoreQuestCorrections.lua"), paths.index("Database/QuestieDB.lua"))'''
    new = '''        self.assertLess(paths.index("Compat/Corrections.lua"), paths.index("Database/AzerothCore/acoreQuestDB.lua"))
        self.assertLess(paths.index("Database/AzerothCore/acoreQuestDB.lua"), paths.index("Database/QuestieDB.lua"))
        for kind in ("Item", "Npc", "Object", "Quest"):
            self.assertIn(f"Database/AzerothCore/acore{kind}DB.lua", paths)
        self.assertNotIn("Database/AzerothCore/AzerothCoreQuestCorrections.lua", paths)'''
    return replace_once(s, old, new, 'snapshot TOC assertions')


def patch_acore_path_test(s):
    s = replace_once(s, '        self.assertEqual(scripts, DATA_FILES)',
        '        self.assertEqual(scripts, DATA_FILES[:2])\n'
        '        # The original correction generators remain maintenance tools, not live layers.\n'
        '        for kind in ("Item", "Npc", "Object", "Quest"):\n'
        '            base = f"Database/AzerothCore/acore{kind}DB.lua"\n'
        '            self.assertIn(base, entries)\n'
        '            self.assertTrue((ADDON_ROOT / base).is_file())\n'
        '        for original in ("Item", "Npc", "Object", "Quest"):\n'
        '            self.assertNotIn(f"Database/AzerothCore/AzerothCore{original}Corrections.lua",\n'
        '                             [f"Database/AzerothCore/{name}" for name in scripts])',
        'AC manifest expectations')
    return s


# This test directly exercises the real four base files, their in-addon schema
# declarations, and the no-duplicate-correction rule. Separate snapshot tests
# already exercise the full production correction/cached override pipeline.
NEW_LUA_TEST = r'''-- PR #166 complete-base smoke test; run from addon root with Lua 5.1/5.2+.
local function read(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n"):gsub("^\239\187\191", "")
    f:close()
    return source
end
local function equal(actual, expected, name)
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
env.QuestieLoader = {
    ImportModule = function(_, name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end,
    StampLoadBoundary = function() end,
}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
local function compile(source, label)
    if setfenv then return setfenv(assert(loadstring(source, label)), env) end
    return assert(load(source, label, "t", env))
end
local function load(path) compile(read(path), "@" .. path)() end
env.bit = {band = function() return 0 end}
env.QuestieCompat = {}
env.Questie = {db = {profile = {isleOfQuelDanasPhase = 1}}}
env.QuestieDB = env.QuestieLoader:ImportModule("QuestieDB")
env.QuestieProfessions = env.QuestieLoader:ImportModule("QuestieProfessions")
env.QuestieCorrections = env.QuestieLoader:ImportModule("QuestieCorrections")
local registry = assert(read("Compat/Compat.lua"):match(
    "(local correctionsRegistry = {}.-)\nfunction QuestieCompat:ADDON_LOADED"))
compile(registry, "@Compat/Compat.lua")()
load("Compat/Corrections.lua")
local manifest = read("Database/AzerothCore/AzerothCore.xml")
local count = 0
for name in manifest:gmatch('<Script file="([^"]+)"') do
    load("Database/AzerothCore/" .. name)
    count = count + 1
end
equal(count, 2, "only server runtime metadata in early XML")
equal(env.QuestieCompat.AzerothCoreReputationRates[1090][1], 1.3, "reputation rates")
equal(env.QuestieCompat.AzerothCoreQuestAvailabilityConditions[308][1][1][2], 310, "availability")
for _, kind in ipairs({"item", "npc", "object", "quest"}) do
    load("Database/AzerothCore/acore" .. kind:sub(1,1):upper() .. kind:sub(2) .. "DB.lua")
end
for _, kind in ipairs({"quest", "npc", "item", "object"}) do
    load("Database/" .. kind .. "DB.lua")
end
-- Same enum strategy as the original data-loading test.
local function enum(declaration)
    local pattern = declaration:gsub("(%W)", "%%%1") .. " = %b{}"
    compile(assert(read("Database/QuestieDB.lua"):match(pattern), declaration), "@QuestieDB enum")()
end
for _, name in ipairs({"raceKeys", "classKeys", "specialFlags"}) do
    enum("QuestieDB." .. name)
end
local prof = read("Modules/QuestieProfessions.lua")
compile(assert(prof:match("QuestieProfessions%.professionKeys = %b{}")), "@prof enum")()
load("Database/Zones/zoneTables.lua")
modules.ZoneDB.zoneIDs = modules.ZoneDB.private.zoneIDs
local db = env.QuestieDB
for _, kind in ipairs({"quest", "npc", "object", "item"}) do
    local raw = assert(db[kind .. "Data"], kind .. " raw source missing")
    assert(type(raw) == "string", kind .. " base should be a Lua source string")
    db[kind .. "Data"] = compile(raw, "@acore " .. kind)()
    db[kind .. "DataOverrides"] = {}
end
local function noStatic() error("legacy static correction was applied", 2) end
local function empty() return {} end
for _, name in ipairs({"QuestieQuestFixes", "QuestieNPCFixes", "QuestieItemFixes", "QuestieObjectFixes",
    "QuestieTBCQuestFixes", "QuestieTBCNpcFixes", "QuestieTBCItemFixes", "QuestieTBCObjectFixes",
    "QuestieWotlkQuestFixes", "QuestieWotlkNpcFixes", "QuestieWotlkItemFixes", "QuestieWotlkObjectFixes",
    "QuestieItemStartFixes", "QuestieQuestBlacklist", "QuestieNPCBlacklist", "QuestieItemBlacklist"}) do
    local mod = env.QuestieLoader:ImportModule(name)
    for _, method in ipairs({"Load", "LoadAutomatics", "LoadReverseLinkFixes",
        "LoadReverseStartQuestFixes", "LoadAutomaticQuestStarts"}) do
        mod[method] = noStatic
    end
    mod.LoadFactionFixes = empty
    mod.LoadAutoBlacklistWotlk = empty
end
-- MinimalInit receives blank static blacklist modules and the real Compat
-- callback still contributes intentional true/false Questie blacklist entries.
modules.IsleOfQuelDanas = {MAX_ISLE_OF_QUEL_DANAS_PHASES = 9}
env.QuestieCompat.LoadCorrections = noStatic
load("Database/Corrections/QuestieCorrections.lua")
env.QuestieCorrections:Initialize()
equal(db.questData[12541][db.questKeys.parentQuest], 0, "quest zero correction baked into base")
equal(db.npcData[1][db.npcKeys.maxLevel], 80, "NPC max-level correction baked into base")
equal(db.itemData[25][db.itemKeys.npcDrops][1], 19994, "item drop baked into base")
equal(db.objectData[31][db.objectKeys.factionID], 84, "object faction baked into base")
for quest, reward in pairs({[2]=250,[6]=150,[7]=250}) do
    equal(db.questData[quest][db.questKeys.reputationReward][1][2], reward, "quest reputation " .. quest)
end
equal(env.QuestieCorrections.hiddenQuests[13240], false, "cached/fresh blacklist registration")
print("AzerothCore complete-base smoke test passed")
'''


def all_changes():
    results = {}
    specs = {
        'Questie-335.toc': patch_toc,
        'Database/AzerothCore/AzerothCore.xml': patch_xml,
        'Database/Corrections/QuestieCorrections.lua': patch_corrections,
        'Database/compiler.lua': patch_schema_version,
        'tools/tests/test_db_snapshot.py': patch_snapshot_test,
        'tools/tests/test_acore_data_paths.py': patch_acore_path_test,
    }
    for filename, fn in specs.items():
        path = ROOT / filename
        before = path.read_text(encoding='utf-8-sig')
        after = fn(before)
        if before == after:
            raise ValueError(f"No change produced for {filename}")
        results[path] = after
    lua_path = ROOT / 'tools/tests/test_acore_data_loading.lua'
    old_lua = lua_path.read_text(encoding='utf-8-sig')
    if 'production initializer applied registered data' not in old_lua:
        raise ValueError('Unexpected existing Lua data-loading test; refuse to overwrite')
    results[lua_path] = NEW_LUA_TEST
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--check', action='store_true', help='Validate branch/files and print planned changes')
    group.add_argument('--apply', action='store_true', help='Apply guarded migration in-place')
    opts = parser.parse_args()
    require_clean_branch()
    edits = all_changes()  # Validate ALL targets before writing ANY.
    print('PR #166 staged full-base loader migration')
    print('Expected files to change:')
    for path in edits:
        print(' -', path.relative_to(ROOT))
    if opts.check:
        print('CHECK PASSED: no changes written.')
        return 0
    for path, updated in edits.items():
        path.write_text(updated, encoding='utf-8', newline='\n')
    print('APPLIED. Run Python/Lua regression tests and a full before/after snapshot compare.')
    print('Do not commit/merge until effective snapshot differences are zero.')
    return 0

if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as exc:
        print('ERROR:', exc)
        raise SystemExit(2)
