"""
Shared helpers for the RPG Maker MV -> Godot 4 extraction scripts.

The whole extraction pipeline lives in `tools/`. Each script reads the raw
RPG Maker MV JSON from `legacy/data/` and writes clean, Godot-ready JSON into
`gocon-game-rpg/data/`.

Design notes (why things are the way they are):
  * RPG Maker arrays are 1-indexed: element 0 is always `null` (a placeholder
    so that `id` == array index). We drop that placeholder and key everything
    by the real `id` instead, as strings ("1", "2", ...) because JSON object
    keys are strings and GDScript dictionaries loaded from JSON will have
    string keys anyway.
  * We always read/write UTF-8 with `ensure_ascii=False` so the Russian and
    Romanian translation text survives round-tripping.
"""

import json
import os

# Resolve paths relative to the repo root (the parent of this tools/ folder),
# so the scripts work no matter what directory you run them from.
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(TOOLS_DIR)
LEGACY_DATA = os.path.join(REPO_ROOT, "legacy", "data")
# Proiectul Godot activ (cel construit manual). Scripturile scriu aici.
OUT_DATA = os.path.join(REPO_ROOT, "gocon-game-rpg", "data")


def load_rm(name):
    """Load a raw RPG Maker MV data file, e.g. load_rm('Actors.json')."""
    path = os.path.join(LEGACY_DATA, name)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_out(rel_path, obj):
    """Write `obj` as pretty UTF-8 JSON into gocon-game-rpg/data/<rel_path>."""
    path = os.path.join(OUT_DATA, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2, sort_keys=False)
    return path


def keyed_by_id(rm_array, pick):
    """
    Turn a 1-indexed RPG Maker array into a dict keyed by string id.

    `pick(entry)` returns the trimmed dict we actually want to keep for one
    entry. The null placeholder at index 0 (and any other null gaps) is skipped.
    """
    out = {}
    for entry in rm_array:
        if not entry:
            continue
        out[str(entry["id"])] = pick(entry)
    return out
