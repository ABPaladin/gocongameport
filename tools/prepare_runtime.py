"""Regenerate data only; never edits legacy, scenes or hand-authored scripts.

Reuses extract_maps/extract_db/extract_translations. Asset manifest resolves
original names to existing byte-identical assets; missing assets are copied.
"""
import hashlib
import json
from pathlib import Path
import shutil
import extract_maps
import extract_db
import extract_translations
from rmmv_common import save_out, load_rm

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'gocon-game-rpg'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    extract_maps.main()
    extract_db.main()
    extract_translations.main()
    save_out('tilesets.json', {str(t['id']): t for t in load_rm('Tilesets.json') if t})
    assets = {}
    hashes = {}
    for p in sorted((PROJECT / 'assets').rglob('*')):
        if p.is_file() and p.suffix in ('.png', '.ogg', '.ttf'):
            hashes.setdefault(digest(p), p)
    for category in ['characters', 'faces', 'parallaxes', 'pictures', 'system', 'titles1', 'VirtualButtons']:
        for p in sorted((ROOT / 'legacy/img' / category).glob('*.png')):
            sha = digest(p)
            target = hashes.get(sha)
            if target is None:
                target = PROJECT / 'assets/source' / category / p.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(p, target)
                hashes[sha] = target
            assets[category + '/' + p.stem] = 'res://' + target.relative_to(PROJECT).as_posix()
    for category in ['bgm', 'se']:
        for p in sorted((ROOT / 'legacy/audio' / category).glob('*.ogg')):
            target = hashes.get(digest(p))
            if target is None:
                target = PROJECT / 'assets/source/audio' / category / p.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(p, target)
            assets[category + '/' + p.stem] = 'res://' + target.relative_to(PROJECT).as_posix()
    save_out('assets.json', assets)
    save_out('source_hashes.json', {p.relative_to(ROOT / 'legacy').as_posix(): digest(p)
                                  for p in sorted((ROOT / 'legacy').rglob('*')) if p.is_file()})
    print(f'Asset manifest: {len(assets)} references')

if __name__ == '__main__':
    main()
