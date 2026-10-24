import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import acore_npc_health as health
import db_snapshot


class NpcHealthTests(unittest.TestCase):
    def default_hp_rate_source(self):
        return '\n'.join(
            f'SetConfigValue<float>({rank}, "{name}", 1.0f);'
            for rank, name in (
                ("RATE_CREATURE_NORMAL_HP", "Rate.Creature.Normal.HP"),
                ("RATE_CREATURE_ELITE_ELITE_HP", "Rate.Creature.Elite.Elite.HP"),
                ("RATE_CREATURE_ELITE_RAREELITE_HP", "Rate.Creature.Elite.RAREELITE.HP"),
                ("RATE_CREATURE_ELITE_WORLDBOSS_HP", "Rate.Creature.Elite.WORLDBOSS.HP"),
                ("RATE_CREATURE_ELITE_RARE_HP", "Rate.Creature.Elite.RARE.HP"),
            ))

    def template(self):
        return dict(entry=1, minlevel=5, maxlevel=6, unit_class=1, exp=0,
                    HealthModifier=1)

    def stats(self, level, values=(100, 200, 300), cls=1):
        return dict(level=level, **{'class': cls}, **dict(zip(('basehp0', 'basehp1', 'basehp2'), values)))

    def run_health(self, template=None, rows=None):
        return health.collect([template or self.template()], rows or [self.stats(5), self.stats(6, (120, 240, 360))])

    def test_template_endpoints_use_class_and_expansion(self):
        t = self.template()
        t.update(exp=2, unit_class=8, minlevel=6, maxlevel=5, HealthModifier=1.5)
        values, gaps = self.run_health(t, [self.stats(5, (10, 20, 30), 8), self.stats(6, (12, 24, 36), 8)])
        self.assertEqual(values[1], {'minLevelHealth': 45, 'maxLevelHealth': 54})
        self.assertFalse(any(gaps.values()))

    def test_float32_product_avoids_python_double_ceil_error(self):
        t = self.template()
        t['HealthModifier'] = 1.1
        values, _ = self.run_health(t)
        self.assertEqual(values[1]['minLevelHealth'], 110)

    def test_missing_expansion_stats_inherit_previous_expansion(self):
        t = self.template()
        t['exp'] = 2
        values, _ = self.run_health(t, [self.stats(5, (123, 1, 0)), self.stats(6, (234, 300, 1))])
        self.assertEqual(list(values[1].values()), [123, 300])

    def test_zero_modifier_and_missing_stats_match_core_defaults(self):
        t = self.template()
        t['HealthModifier'] = 0
        values, gaps = self.run_health(t, [self.stats(5)])
        self.assertEqual(list(values[1].values()), [1, 1])
        self.assertEqual(gaps['missingBaseStats'], [{'entry': 1, 'level': 6, 'class': 1}])

    def test_invalid_class_and_expansion_use_core_normalization(self):
        t = self.template()
        t.update(unit_class=3, exp=5)
        values, gaps = self.run_health(t)
        self.assertEqual(list(values[1].values()), [100, 120])
        self.assertEqual(gaps['normalizedClasses'], [1])
        self.assertEqual(gaps['normalizedExpansions'], [1])

    def test_bad_modifiers_and_overflow_fail(self):
        for modifier in (-1, float('nan'), float('inf'), 1e30):
            with self.subTest(modifier=modifier), self.assertRaises(ValueError):
                t = self.template()
                t['HealthModifier'] = modifier
                self.run_health(t)

    def test_source_guard_rejects_unknown_formula(self):
        with db_snapshot.temporary_directory(pathlib.Path(__file__).resolve().parents[1] / 'reports') as directory:
            root = pathlib.Path(directory)
            for file in health.SOURCE_FILES:
                path = root / file
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('unknown', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'review source changes'):
                health.validate_source(root)

    def test_default_hp_rates_accept_standard_source(self):
        health._validate_default_hp_rates(self.default_hp_rate_source())
        self.assertIn("src/server/game/World/WorldConfig.cpp", health.SOURCE_FILES)

    def test_each_changed_default_hp_rate_requires_review(self):
        lines = self.default_hp_rate_source().splitlines()
        for index in range(len(lines)):
            with self.subTest(rank=index), self.assertRaisesRegex(ValueError, 'default HP rate'):
                changed = lines.copy()
                changed[index] = changed[index].replace('1.0f', '2.0f')
                health._validate_default_hp_rates('\n'.join(changed))

    def test_missing_or_duplicate_default_hp_rate_requires_review(self):
        lines = self.default_hp_rate_source().splitlines()
        for changed in (lines[:-1], lines + [lines[0]]):
            with self.subTest(lines=changed), self.assertRaisesRegex(ValueError, 'default HP rate'):
                health._validate_default_hp_rates('\n'.join(changed))


if __name__ == '__main__':
    unittest.main()
