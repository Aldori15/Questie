# Database maintenance tools

Run these tools from the addon directory, outside WoW. The addon loads generated
Lua databases; it does not load Python tools, tests, manifests or reports.

Use Python 3.13 and Lua 5.2. Database tools and Python tests use the standard
library. The separate Windows utility `generate_exploration_masks.py` also needs
Pillow and StormLib.

## Tool roles

- `generate_acore_{item,npc,object,quest}_base.py generate`: update base data.
- `generate_acore_{item,npc,object}_corrections.py`: shared reader/helper modules;
  keep them, but do not run their retired correction-generation commands.
- `audit_acore_*_sources.py`: source models and coverage reports. Changed source
  inputs or readers invalidate caches automatically.
- `tools/data/acore_*_compatibility.json`: maintained generation policies.
- `generate_acore_full_base.py`: shared serializer and migration utilities;
  snapshot export and `bootstrap` are not routine update steps.
- `db_snapshot.py`: effective base data across both factions and Isle stages
  1/9; excludes auxiliary datasets and live server state.
- `run_regressions.py`: shared local/CI test runner.
- `acore_quest*_guides.py`: source-backed guidance, including optional flight
  hints. These do not establish live flight availability.
- `report_extra_objective_localization.py`: translation usage audit. Use
  `--quest-db` for candidates; review unused keys before deleting them. Active
  translations live in `Localization/Translations/ExtraObjectives.lua`.

## Regression checks before pushing

```powershell
$env:QUESTIE_TEST_LUA = "C:\path\to\lua52\lua.exe"
python -B tools/run_regressions.py
if ($LASTEXITCODE -ne 0) { throw "Regression checks failed" }
```

The runner discovers Lua suites and Python tests, stopping on failure. Missing
local tools are reported as skipped. CI uses `--ci` and requires all tools.
Optional executable overrides:

- `QUESTIE_TEST_LUA51`: Lua 5.1 for suites declaring Lua 5.1 support.
- `QUESTIE_TEST_LUAC`: Lua 5.1 compiler for addon syntax checks.
- `QUESTIE_TEST_LUAC52`: Lua 5.2 compiler for regression-suite syntax checks.

## Database update workflow

These commands overwrite generated Lua files. Review changes before committing;
use `--output tools/reports/<candidate>.lua` to stage a generator's output first.
Do not recreate the retired static correction layer from validator suggestions.

### Inputs and failure handling

Replace placeholder paths and use matching source, world exports and client
data. Run the workflow as one `.ps1` script or inside one `& { ... }` block so a
thrown error stops subsequent commands. Choose fresh snapshot filenames below
to retain evidence from previous updates.

```powershell
$acoreSource = "C:\path\to\azerothcore-wotlk"
$spellSql = "C:\path\to\exports\spell.sql"
$creatureSql = "C:\path\to\exports\creature.sql"
$creatureMultispawnSql = "C:\path\to\exports\creature_multispawn.sql"
$gameobjectSql = "C:\path\to\exports\gameobject.sql"
$mapDifficultyDbc = "C:\path\to\dbc\MapDifficulty.dbc"
$wdmRoot = "C:\path\to\wdm"
$questXpCsv = "C:\path\to\exports\QuestXP.csv"
$env:QUESTIE_TEST_LUA = "C:\path\to\lua52\lua.exe"

function Invoke-QuestiePython {
    & python -B @args
    if ($LASTEXITCODE -ne 0) {
        throw "Questie command failed with exit code $LASTEXITCODE"
    }
}

Invoke-QuestiePython tools/db_snapshot.py capture `
    --output tools/reports/db-before-update.jsonl.gz
```

Review changed proofs, unsupported SQL, unresolved references and size-limit
failures. Do not bypass them by increasing budgets or replacing proof hashes.
Normal base generation replaces outputs atomically; it does not need `--force`.

### 1. Item base

```powershell
Invoke-QuestiePython tools/generate_acore_item_base.py generate `
    --acore-source $acoreSource --spell-sql $spellSql
```

### 2. NPC base

```powershell
Invoke-QuestiePython tools/generate_acore_npc_base.py generate `
    --acore-source $acoreSource `
    --creature-sql $creatureSql `
    --creature-multispawn-sql $creatureMultispawnSql `
    --map-difficulty-dbc $mapDifficultyDbc --wdm-root $wdmRoot
```

### 3. Object base

```powershell
Invoke-QuestiePython tools/generate_acore_object_base.py generate `
    --acore-source $acoreSource --gameobject-sql $gameobjectSql `
    --creature-sql $creatureSql `
    --creature-multispawn-sql $creatureMultispawnSql `
    --spell-sql $spellSql `
    --map-difficulty-dbc $mapDifficultyDbc --wdm-root $wdmRoot
```

### 4. Quest base

```powershell
Invoke-QuestiePython tools/generate_acore_quest_base.py generate `
    --acore-source $acoreSource --spell-sql $spellSql
```

### 5. Quest relation and metadata review

Relations identify possible questgivers, not currently active script/event
windows. Missing quest templates are reported in `sourceDiagnostics.orphanRelations`.
Metadata compares explicit race fields and source-proven tools; endpoint faction
hints are informational. Manifest tool candidates still require source proof.

Both validators return `0` for a match, `1` for mismatches and `2` for handled
errors. Review orphan diagnostics even when comparisons match.

```powershell
Invoke-QuestiePython tools/validate_acore_quest_relations.py `
    --acore-source $acoreSource `
    --report tools/reports/acore_relation_mismatches.json

Invoke-QuestiePython tools/validate_acore_quest_metadata.py `
    --acore-source $acoreSource --spell-sql $spellSql `
    --report tools/reports/acore_metadata_mismatches.json `
    --condition-report tools/reports/acore_quest_availability_conditions.json
```

### 6. Quest XP

```powershell
Invoke-QuestiePython tools/generate_acore_quest_xp.py `
    --acore-source $acoreSource `
    --quest-xp-csv $questXpCsv --spell-sql $spellSql
```

### 7. Quest availability conditions

```powershell
Invoke-QuestiePython tools/generate_acore_quest_availability_conditions.py `
    --acore-source $acoreSource
```

### 8. Creature drop data

```powershell
Invoke-QuestiePython tools/generate_acore_creature_drops.py `
    --acore-source $acoreSource `
    --item-db Database/AzerothCore/acoreItemDB.lua `
    --coverage-report tools/reports/acore_creature_drop_coverage.json
```

Review the coverage report for skipped SQL and missing creature-drop sources.
An item without creature drops may use another acquisition mechanism.

### 9. Blacklist and relationship audits

Review reports; these commands do not modify curated blacklists or fix links.

```powershell
Invoke-QuestiePython tools/report_acore_quest_blacklist.py `
    --acore-source $acoreSource --report tools/reports/acore_quest_blacklist.json

Invoke-QuestiePython tools/validate_reverse_quest_links.py `
    --report tools/reports/reverse_quest_links_report.json

Invoke-QuestiePython tools/validate_item_start_links.py `
    --report tools/reports/item_start_links_report.json
```

### 10. Reputation rates

```powershell
Invoke-QuestiePython tools/generate_acore_reputation_rates.py `
    --acore-source $acoreSource
```

### Final validation

```powershell
Invoke-QuestiePython tools/run_regressions.py
Invoke-QuestiePython tools/db_snapshot.py capture `
    --output tools/reports/db-after-update.jsonl.gz

python -B tools/db_snapshot.py compare `
    tools/reports/db-before-update.jsonl.gz `
    tools/reports/db-after-update.jsonl.gz `
    --report tools/reports/db-update-differences.jsonl
if ($LASTEXITCODE -gt 1) { throw "Snapshot comparison failed" }
```

Snapshot comparison returns `1` for differences and `2` for errors. Review the
differences, auxiliary outputs and coverage gaps. Check repeatable generation,
then recompile in-game and verify cached reload. Confirm CI before merging;
release version/schema bumps belong to the final migration step.

## Reports and packaging

`tools/reports/` is ignored except for `.gitignore`. Keep snapshots and coverage
evidence while a review is unfinished. Caches may be deleted; extraction reruns
when needed. Tests create their own fixtures and do not require saved reports.
