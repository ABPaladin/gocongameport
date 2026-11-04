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

    def test_critical_references(self):
        manifest = read(DATA / 'assets.json')
        def asset(category, name, location):
            if name:
                self.assertIn(category + '/' + name, manifest, location)
        for actor in read(DATA / 'actors.json').values():
            asset('characters', actor['characterName'], 'actor')
        tilesets = read(DATA / 'tilesets.json')
        for source in (DATA / 'maps').glob('map*.json'):
            world = read(source)
            flags = tilesets[str(world['tilesetId'])]['flags']
            self.assertTrue(all(0 <= tile < len(flags) for layer in world['layers'] for tile in layer), source.name)
            asset('bgm', world['bgm']['name'], source.name)
            for overlay in ['ground','par']:
                asset('parallaxes', world['overlays'][overlay].removesuffix('.png'), source.name)
            for event in world['events']:
                for page in event['pages']:
                    asset('characters',page['image']['characterName'],source.name)
                    for command in page['list']:
                        code, p = command['code'], command['parameters']
                        if code == 101: asset('faces',p[0],source.name)
                        if code == 231: asset('pictures',p[1],source.name)
                        if code in (241,250): asset('bgm' if code == 241 else 'se',p[0]['name'],source.name)
                        if code == 201 and p[0] == 0:
                            self.assertTrue((DATA / 'maps' / ('map%03d.json' % p[1])).exists(),source.name)

if __name__ == '__main__':
    unittest.main()
