import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'gocon-game-rpg/data'
def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

class ContentTests(unittest.TestCase):
    def test_legacy_hashes(self):
        for name, expected in read(DATA / 'source_hashes.json').items():
            self.assertEqual(hashlib.sha256((ROOT / 'legacy' / name).read_bytes()).hexdigest(), expected, name)

    def test_maps_commands_and_planes(self):
        self.assertEqual(len(list((DATA / 'maps').glob('map*.json'))), 13)
        for source in sorted((ROOT / 'legacy/data').glob('Map[0-9]*.json')):
            raw = read(source)
            out = read(DATA / 'maps' / (source.stem.lower() + '.json'))
            self.assertEqual([p['list'] for e in raw['events'] if e for p in e['pages']],
                             [p['list'] for e in out['events'] for p in e['pages']])
            self.assertEqual(sum(out['layers'], []) + out['shadow'] + out['regions'], raw['data'])

    def test_assets_exist(self):
        for name, resource in read(DATA / 'assets.json').items():
            self.assertTrue((ROOT / 'gocon-game-rpg' / resource.removeprefix('res://')).is_file(), name)

    def test_translations(self):
        original = read(ROOT / 'legacy/data/Translations.json')
        out = read(DATA / 'translations.json')
        for section in ['msg', 'cmd', 'custom']:
            self.assertEqual(original[section], out[section])

if __name__ == '__main__':
    unittest.main()
