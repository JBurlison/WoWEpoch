"""Controller input corpus coverage, Unicode property data and offline release checks."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('controller_unicode_builder', ROOT / 'tools/build_controller_unicode.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class ControllerUnicodeDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua = LuaRuntime()
        cls.env = cls.lua.table()
        for name in ('ControllerUnicodeData.lua', 'ControllerChinese.lua'):
            cls.lua.execute((ROOT / 'MyEpoch' / name).read_text(encoding='utf-8'), 'MyEpoch', cls.env)

    def test_source_and_generated_artifacts_are_pinned(self):
        manifest = builder.check()
        self.assertEqual(manifest['unicode_version'], '17.0.0')
        self.assertEqual(manifest['sources']['Unihan.zip']['sha256'],
                         'f7a48b2b545acfaa77b2d607ae28747404ce02baefee16396c5d2d7a8ef34b5e')
        self.assertIn('UNICODE LICENSE V3', (ROOT / 'MyEpoch/Licenses/Unicode.txt').read_text(encoding='utf-8'))

    def test_package_check_is_offline_and_detects_corruption(self):
        manifest = json.loads((ROOT / 'tools/controller-unicode-sources.json').read_text(encoding='utf-8'))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in [*manifest['outputs'], 'tools/controller-unicode-sources.json']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / name).read_bytes())
            cache = root / 'absent-cache'
            builder.check(root, cache)
            self.assertFalse(cache.exists(), 'offline verification must not download sources')
            (root / 'MyEpoch/ControllerChinese.lua').write_text('-- truncated dictionary', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'stale'):
                builder.check(root, cache)

    def test_actual_chinese_words_and_tones_remain_selectable(self):
        data = self.env.ControllerChinese
        self.assertEqual(data.version, '17.0.0')
        expected = {'ni3': '你', 'hao3': '好', 'long2': '龙龍', 'ma5': '吗嗎', 'nv3': '女', 'lv4': '绿綠'}
        for query, characters in expected.items():
            with self.subTest(query=query):
                for character in characters:
                    self.assertIn(character, data.readings[query])
                    self.assertIn(character, data.readings[query[:-1]])
        self.assertEqual(data.readings['ni3'][0], '你')
        self.assertEqual(data.readings['hao3'][0], '好')
        self.assertIn('龙', data.simplified)
        self.assertIn('龍', data.traditional)
        self.assertNotIn('你', data.simplified + data.traditional, 'shared characters retain ordinary rank')
        self.assertFalse(set(data.simplified) & set(data.traditional))
        self.assertGreater(len(list(data.readings)), 2000, 'ship the actual corpus, not a small demonstration list')
        for query, packed in data.readings.items():
            self.assertEqual(len(packed), len(set(packed)), query)

    def test_pinyin_source_forms_have_the_expected_keys(self):
        for text, expected in [('lǜ', 'lv4'), ('nǚ', 'nv3'), ('ma', 'ma5'), ('hǎo', 'hao3'), ('nǐ', 'ni3')]:
            self.assertEqual(builder.pinyin_key(text), expected)

    def test_unicode_ranges_cover_script_and_emoji_boundaries(self):
        data = self.env.ControllerUnicodeData
        def contains(ranges, point):
            return any(ranges[index] <= point <= ranges[index + 1] for index in range(1, len(ranges) + 1, 2))
        self.assertTrue(contains(data.gcb.Extend, 0x0301))
        self.assertTrue(contains(data.gcb.ZWJ, 0x200D))
        self.assertTrue(contains(data.gcb.Regional_Indicator, 0x1F1FA))
        self.assertTrue(contains(data.gcb.L, 0x1100))
        self.assertTrue(contains(data.gcb.LV, 0xAC00))
        self.assertTrue(contains(data.gcb.LVT, 0xAC01))
        self.assertTrue(contains(data.extendedPictographic, 0x1F469))
        self.assertTrue(contains(data.incb.Linker, 0x094D))
        self.assertTrue(contains(data.incb.Consonant, 0x0915))
        for family in (data.gcb, data.incb):
            for name, ranges in family.items():
                self.assertEqual(len(ranges) % 2, 0, name)
                last = -1
                for index in range(1, len(ranges) + 1, 2):
                    self.assertGreater(ranges[index], last, name)
                    self.assertGreaterEqual(ranges[index + 1], ranges[index], name)
                    last = ranges[index + 1]


if __name__ == '__main__':
    unittest.main()
