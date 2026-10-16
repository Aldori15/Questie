# Database comparison harness

Use this before consolidating corrections or replacing the inherited base files.
The snapshot is a reference for behavior, not a claim that every current value
matches AzerothCore. Intentional correctness fixes still need source validation
and an explanation of the expected differences.

## Requirements

Run the Python commands from the addon root. Capture requires Python 3.11+ and a
Lua executable (Lua 5.1 or 5.2+). Set `QUESTIE_TEST_LUA` or pass `--lua` with the
executable path. Comparison uses only Python's standard library; Lua is not
needed to read or compare existing snapshots.

## Capture a reference before editing

```powershell
python tools/db_snapshot.py capture --lua "C:/path/to/lua.exe" --output tools/reports/db-before.jsonl.gz
```

This runs four contexts: Alliance and Horde, each with Quel'Danas phases 1 and 9.
Every context starts with a fresh environment. For a quicker exploratory capture:

```powershell
python tools/db_snapshot.py capture --lua "C:/path/to/lua.exe" --factions Alliance --isle-phases 1 --output tools/reports/db-quick.jsonl.gz
```

Use the same factions/phases for the reference and candidate. `--isle-phases`
accepts any of phases 1 through 9. Existing snapshots are protected from overwrite;
use another filename or explicitly pass `--force`.

## Capture and compare a candidate

After making a database change, capture to a new path and compare:

```powershell
python tools/db_snapshot.py capture --lua "C:/path/to/lua.exe" --output tools/reports/db-after.jsonl.gz
python tools/db_snapshot.py compare tools/reports/db-before.jsonl.gz tools/reports/db-after.jsonl.gz --report tools/reports/db-differences.jsonl
```

`--repo` can point capture at a different checkout. The harness beside the Python
script is used to evaluate that checkout's TOC, source files, and pipeline.

Comparison exits with **0** for equal data, **1** for differences, or **2** for an
error. A missing footer, wrong checksum, incompatible contexts, or invalid record
order is an error. `--limit` controls printed examples only; all records are
checked and all differences are included in the report.

Differences identify the context, section, entity ID, and nested field path, for
example `questData[2].reputationReward[1][2]` or `itemData[1307].startQuest`.
An empty report with exit code 0 means the captured data matches. Source hashes,
Git revisions, and dirty-file metadata can differ without making data unequal.

## What capture evaluates

- The active TOC/XML order for database files, Compat corrections, and the
  professions, phasing, and Quel'Danas support modules.
- The production correction registry, `QuestieInit:LoadBaseDB()`, and
  `QuestieCorrections:Initialize()`. Python does not reinterpret correction tables
  or reproduce their overwrite rules.
- All four corrected database tables, with named top-level fields, plus schema
  keys/compiler types/compiler order.
- Faction overrides and every non-function public correction value, including
  blacklists, tooltip hints, and objective ordering/target tables.
- A separate fresh-module `MinimalInit()` pass representing cached startup's
  correction state, without rerunning base loading or static correction application.
- Quest availability conditions, reputation rates, and static event quest data.
- The production Darkmoon NPC override setter for Mulgore, Elwynn, and Terokkar,
  followed by reset. Its query adapters read the corrected tables and overrides.

Lua table keys retain their type (`n:1` versus `s:1`), and sparse indices are kept.
Missing fields, `false`, zero, and empty tables remain different. Array order,
coordinate precision, and duplicate list entries are not normalized away.

Capture stops **before localization, townsfolk initialization, gathering-node
removal, waypoint optimization, and binary compilation**. Localization calls in
corrections use enUS source text. No live server, player inventory, calendar
timers, client UI, or binary-cache decoding is simulated. This is a comparison of
the correction pipeline and selected runtime overrides; retain existing compiler
tests and in-game checks for behavior outside that boundary.

Small adapters extract the production registry/base-loader blocks because their
containing files also initialize unrelated client APIs. If those blocks move, the
harness fails explicitly and its adapters must be updated. New executable inline
database XML scripts also require adapter support.

## Generation provenance

Each header records the Git revision/status, Lua version, ordered loaded files,
SHA-256 source hashes, harness hashes, context list, and scope. Capture rejects
source changes detected while it is running and publishes the output atomically.

The snapshot uses the checked-in/generated Lua output; it does **not** rerun any
AzerothCore generator. Optional `--input` arguments record hashes of external
inputs so the generation process can be traced later:

```powershell
python tools/db_snapshot.py capture --lua "C:/path/to/lua.exe" --output tools/reports/db-before.jsonl.gz --input "E:/exports/creature.sql" --input "E:/exports/creature_multispawn.sql" --input "E:/exports/gameobject.sql" --input "E:/exports/QuestXP.csv"
```

Record the exact AzerothCore revision, generator commands/options, and any other
inputs (Spell.dbc exports, MapDifficulty/DBC data, and WDM geometry) alongside the
generation run. Hashing an export identifies its bytes; it does not establish
that it matches the current server database or source revision.

## Tests

```powershell
python -B -m unittest discover -s tools/tests -p test_db_snapshot.py
```

The Python suite covers typed values, sparse tables, readable field differences,
record additions/removals, metadata compatibility, and truncated/corrupt snapshots.
When Lua is available it also captures the real pipeline for both factions and
checks representative rewards, item starts, cached/fresh overrides, and Darkmoon
override restoration. CI supplies Lua through `QUESTIE_TEST_LUA` and also runs
`tools/tests/test_db_snapshot.lua` on its supported Lua versions.
