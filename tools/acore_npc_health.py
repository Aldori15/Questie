"""Derive default template health, before scripts and server-configured HP rates.

The displayed endpoints describe the base template, not live encounter scaling or
difficulty substitutions. Float operations mirror AC's single-precision product.
"""
import math
from pathlib import Path
import re
import struct


SOURCE_FILES = (
    "src/server/game/Entities/Creature/CreatureData.h",
    "src/server/game/Entities/Creature/Creature.cpp",
    "src/server/game/Globals/ObjectMgr.cpp",
    "src/server/shared/SharedDefines.h",
    "src/server/game/World/WorldConfig.cpp",
)
VALID_CLASSES = {1, 2, 4, 8}


def _code(text):
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    return re.sub(r"\s+", "", text)


def _validate_default_hp_rates(text):
    """The generated template health assumes AC's standard 1.0 HP rates."""
    text = _code(text)
    for rank, name in (
        ("NORMAL", "Normal"),
        ("ELITE_ELITE", "Elite.Elite"),
        ("ELITE_RAREELITE", "Elite.RAREELITE"),
        ("ELITE_WORLDBOSS", "Elite.WORLDBOSS"),
        ("ELITE_RARE", "Elite.RARE"),
    ):
        definitions = re.findall(
            rf'SetConfigValue<float>\(RATE_CREATURE_{rank}_HP,"([^"]+)",([^)]*)\);', text)
        if definitions != [(f"Rate.Creature.{name}.HP", "1.0f")]:
            raise ValueError("Unsupported AC default HP rate in WorldConfig.cpp; review source changes")


def validate_source(source_root):
    """Fail closed when the core formulas or normalization rules change."""
    texts = {name: _code((Path(source_root) / name).read_text(encoding="utf-8"))
             for name in SOURCE_FILES}
    _validate_default_hp_rates(texts[SOURCE_FILES[4]])
    requirements = {
        SOURCE_FILES[0]: (
            "uint32 GenerateHealth(CreatureTemplate const* info) const { return uint32(std::ceil(BaseHealth[info->expansion] * info->ModHealth)); }",
        ),
        SOURCE_FILES[1]: (
            "uint8 minlevel = std::min(cInfo->maxlevel, cInfo->minlevel); uint8 maxlevel = std::max(cInfo->maxlevel, cInfo->minlevel);",
            "CreatureBaseStats const* stats = sObjectMgr->GetCreatureBaseStats(level, cInfo->unit_class); float healthmod = _GetHealthMod(rank); uint32 basehp = std::max<uint32>(1, stats->GenerateHealth(cInfo)); uint32 health = uint32(basehp * healthmod); SetCreateHealth(health); SetMaxHealth(health); SetHealth(health);",
        ),
        SOURCE_FILES[2]: (
            "if (!cInfo->unit_class || ((1 << (cInfo->unit_class - 1)) & CLASSMASK_ALL_CREATURES) == 0)",
            "const_cast<CreatureTemplate*>(cInfo)->unit_class = CLASS_WARRIOR;",
            "if (cInfo->expansion > (MAX_EXPANSIONS - 1))",
            "const_cast<CreatureTemplate*>(cInfo)->expansion = 0;",
            "if (stats.BaseHealth[i] == 0)",
            "stats.BaseHealth[i] = 1;",
            "if (stats.BaseHealth[i] <= 1) { for (uint8 j = i; j > 0;) { --j; if (stats.BaseHealth[j] > 1) { stats.BaseHealth[i] = stats.BaseHealth[j]; break; } } }",
            "BaseHealth[j] = 1;",
        ),
        SOURCE_FILES[3]: (
            "#define CLASSMASK_ALL_CREATURES ((1<<(CLASS_WARRIOR-1)) | (1<<(CLASS_PALADIN-1)) | (1<<(CLASS_ROGUE-1)) | (1<<(CLASS_MAGE-1)))",
            "MAX_EXPANSIONS = 3",
        ),
    }
    for name, fragments in requirements.items():
        for fragment in fragments:
            if _code(fragment) not in texts[name]:
                raise ValueError(f"Unsupported AC default-health calculation in {name}; review source changes")


def _float32(value):
    try:
        result = struct.unpack("f", struct.pack("f", float(value)))[0]
    except (ValueError, TypeError, OverflowError) as exc:
        raise ValueError("Invalid AC health modifier/product") from exc
    if not math.isfinite(result):
        raise ValueError("Non-finite AC health modifier/product")
    return result


def collect(template_rows, stats_rows):
    """Return fields keyed by integer NPC ID, plus explicit normalization gaps.

    Missing class/level stats use AC's base-HP=1 default and are reported. Invalid
    classes and expansions use the same template normalization as ObjectMgr.
    """
    stats = {}
    for row in stats_rows:
        key = (int(row["level"]), int(row["class"]))
        if key in stats:
            raise ValueError(f"Duplicate AC class/level health row {key}")
        values = []
        for expansion in range(3):
            value = int(row[f"basehp{expansion}"])
            if value < 0 or value > 0xFFFFFFFF:
                raise ValueError(f"Invalid AC base health for {key}")
            value = max(1, value)
            if value <= 1:
                value = next((v for v in reversed(values) if v > 1), value)
            values.append(value)
        stats[key] = values
    fields, diagnostics = {}, {"missingBaseStats": [], "normalizedClasses": [], "normalizedExpansions": []}
    for row in template_rows:
        entry = int(row["entry"])
        if entry in fields:
            raise ValueError(f"Duplicate AC health template {entry}")
        unit_class, expansion = int(row["unit_class"]), int(row["exp"])
        if unit_class not in VALID_CLASSES:
            diagnostics["normalizedClasses"].append(entry)
            unit_class = 1
        if expansion not in range(3):
            diagnostics["normalizedExpansions"].append(entry)
            expansion = 0
        modifier = _float32(row["HealthModifier"])
        if modifier < 0:
            raise ValueError(f"NPC {entry} has unsupported negative health modifier")
        endpoints = []
        for level in sorted((int(row["minlevel"]), int(row["maxlevel"]))):
            if not 0 <= level <= 255:
                raise ValueError(f"NPC {entry} has unsupported health level {level}")
            key = (level, unit_class)
            if key not in stats:
                gap = {"entry": entry, "level": level, "class": unit_class}
                if gap not in diagnostics["missingBaseStats"]:
                    diagnostics["missingBaseStats"].append(gap)
            base = stats.get(key, (1, 1, 1))[expansion]
            product = _float32(_float32(base) * modifier)
            health = max(1, math.ceil(product))
            if health > 0xFFFFFFFF:
                raise ValueError(f"NPC {entry} health exceeds uint32")
            # SelectLevel multiplies the integer base HP by a float HP rate (1.0
            # for the default rates), rounding large integers to float32 first.
            health = int(_float32(health))
            if health > 0xFFFFFFFF:
                raise ValueError(f"NPC {entry} default-rate health exceeds uint32")
            endpoints.append(health)
        fields[entry] = dict(zip(("minLevelHealth", "maxLevelHealth"), endpoints))
    return fields, diagnostics
