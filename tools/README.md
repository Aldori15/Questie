# Database maintenance tools

These tools run outside WoW. The addon loads the generated Lua databases, not
Python tools, tests, compatibility manifests, source caches, or reports.

Run commands from the addon directory. Use Python 3.13 and Lua 5.2 for the shared
regression runner. The Python regression tests and database maintenance tools use
the standard library. `generate_exploration_masks.py` is a separate Windows
utility that also requires Pillow and StormLib; normal database updates do not
use it.

## Tool roles

- `generate_acore_{item,npc,object,quest}_base.py` are the maintained base
  generation entry points. Use their `generate` subcommand for updates.
- `generate_acore_{item,npc,object}_corrections.py` retain shared SQL readers,
  parsers, geometry and comparison helpers. Their old correction-generation
  commands are retired. Keep these modules because the base generators import
  them.
- `audit_acore_{item,npc,object,quest}_sources.py` build validated source models
  and review reports. Cache signatures cover the relevant source inputs and
  readers; changed inputs cause extraction to run again.
- `tools/data/acore_*_compatibility.json` are maintained generation inputs.
  They hold reviewed scope and compatibility policies, not runtime caches.
- `generate_acore_full_base.py` provides the shared serializer/source-chunk
  writer. Its snapshot-export CLI and the base generators' `bootstrap`
  subcommands are migration tools, not routine update steps.
- `db_snapshot.py` compares effective corrected data across both factions and
  Isle stages 1/9. It does not cover XP/drop datasets or live server state.
- `run_regressions.py` is the shared local/CI test entry point.
- `acore_quest_guides.py` and `acore_quest_flight_guides.py` derive supported
  quest guidance. Flight hints follow quest-conditioned SmartAI gossip actions
  and player-targeted taxi instructions, rather than gossip labels. The quest
  base includes `questOptionalExtraObjectives` metadata so travel guidance does
  not become a completion requirement. This does not validate live flight
  availability or infer destination geometry.
- `report_extra_objective_localization.py` audits extra-objective translation
  keys against an unlocalized quest base and maintained runtime literals. Use
  `--quest-db` to review a candidate before promotion. Its unused candidates
  require review for dynamic consumers and future recovery; it deletes nothing.
  Active objective translations live in the shared
  `Localization/Translations/ExtraObjectives.lua` dictionary.

## Regression checks before pushing

```powershell
$env:QUESTIE_TEST_LUA = "$env:TEMP\questie-db-harness-lua52\lua.exe"
python -B tools/run_regressions.py
if ($LASTEXITCODE -ne 0) { throw "Regression checks failed" }
```

The runner discovers every `tools/tests/test_*.lua` suite before running Python
discovery. A failure stops the run. Local tools that are unavailable are reported
as skipped, not passed. CI runs `python -B tools/run_regressions.py --ci`, which
requires the complete toolchain. Optional executable overrides are:

- `QUESTIE_TEST_LUA51`: Lua 5.1 for suites declaring Lua 5.1 support.
- `QUESTIE_TEST_LUAC`: Lua 5.1 compiler for addon syntax checks.
- `QUESTIE_TEST_LUAC52`: Lua 5.2 compiler for regression-suite syntax checks.

## Replacement for the old PowerShell steps 1–10

This is the current command reference. The remaining PR migration checks still
need to validate the auxiliary datasets and repeatable generation workflow.
The commands below are for an intentional data update; they overwrite generated
Lua outputs. Review the resulting changes before committing them.

Do not run the retired item/NPC/object correction generators or the removed
quest-correction merge command. Relation/metadata suggestions are review aids;
they must not recreate a retired runtime correction layer.

### Inputs and failure handling

These example paths match the local migration inputs. Adjust them for another
checkout. Use a consistent AC revision and matching client/world exports.

```powershell
$acoreSource = "P:\AC\source"
$spellSql = "E:\downloads\murky_acoreworld\spell5duck\exported spell.dbc.sql"
$creatureSql = "E:\downloads\murky_acoreworld\creature export wth zoneId and areaId\creature.sql"
$creatureMultispawnSql = "E:\downloads\murky_acoreworld\creature export wth zoneId and areaId\creature_multispawn.sql"
$gameobjectSql = "E:\downloads\murky_acoreworld\gameobject export wth zoneId and areaId\gameobject.sql"
$mapDifficultyDbc = "P:\AC\build\bin\RelWithDebInfo\Data\dbc\MapDifficulty.dbc"
$wdmRoot = "E:\downloads\WDM stuff"
$questXpCsv = "E:\downloads\murky_acoreworld\QuestXP.csv"
$env:QUESTIE_TEST_LUA = "$env:TEMP\questie-db-harness-lua52\lua.exe"

function Invoke-QuestiePython {
    & python -B @args
    if ($LASTEXITCODE -ne 0) {
        throw "Questie command failed with exit code $LASTEXITCODE"
    }
}

Invoke-QuestiePython tools/db_snapshot.py capture `
    --output tools/reports/db-before-update.jsonl.gz --force
```

If generation reports changed source proofs, unsupported SQL, unresolved
references, or an output-size limit, stop and review the specific issue. Do not
increase budgets, replace proof hashes, or use `--force` to bypass that review.
For the base generators, `--force` belongs to migration-manifest setup; normal
generation already replaces its output atomically. `--output` can instead point
to a candidate under `tools/reports/` for review before updating the live base.

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

This replaces the old suggestion-merge step. Review mismatches and correct the
maintained source rules or justified policies; do not apply a generated static
correction file.

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
    --item-db Database/AzerothCore/acoreItemDB.lua
```

### 9. Blacklist and relationship audits

These commands report inconsistencies. They do not automatically modify curated
blacklists or resolve every intentional compatibility difference.

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
    --output tools/reports/db-after-update.jsonl.gz --force

python -B tools/db_snapshot.py compare `
    tools/reports/db-before-update.jsonl.gz `
    tools/reports/db-after-update.jsonl.gz `
    --report tools/reports/db-update-differences.jsonl
if ($LASTEXITCODE -gt 1) { throw "Snapshot comparison failed" }
```

Snapshot comparison returns `1` for data differences and `2` for errors. Review
expected differences, auxiliary dataset diffs, and remaining coverage gaps.
Confirm deterministic generation when required, then recompile the database
in-game and check cached reload behavior. Version/schema bumps belong to the
final migration release step. Confirm CI after pushing.

## Reports and packaging

`tools/reports/` is ignored except for its `.gitignore`. It contains disposable
reports, validated source caches, comparison snapshots, and local review notes.
Tests create their own temporary fixtures; they do not require old saved audit
payloads. Keep the baseline/current snapshots and coverage evidence needed for
an unfinished review. Source caches can be deleted, but extraction will run
again on the next update.

The repository currently distributes a source archive, with no separate release
packager. Developer tools may be present in that archive; no TOC/XML path loads
them in WoW. Generated reports remain excluded from commits and archives.
