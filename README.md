# Gocon Game — RPG Maker MV → Godot 4 port

A phase-by-phase migration of the RPG Maker MV project in `legacy/` to a
maintainable Godot 4 project in `godot_project/`.

## What this game actually is (key findings)

- **Exploration / dialogue game, no battles.** The database has 1 actor
  (Go-Chan), 1 class, 2 items (Stamp, QuestList) and **zero** skills, enemies,
  troops, weapons, armors or states. There is no RPG Maker battle system in use.
- **Parallax-mapped.** The visible art is *not* in tiles. Each map's picture is
  hand-painted in `img/parallaxes/!ground<id>.png` (drawn below the player) and
  `!par<id>.png` (drawn above the player). The RPG Maker tile layers are an
  **invisible collision map** — walls are painted with an impassable autotile,
  floor with a passable one. So the Godot side renders sprite layers, not a
  visible TileMap, and derives a collision grid from the tile passability flags.
- **32×32 tiles** (the "Change Tile Size" plugin overrides the default 48), with
  a **2× camera zoom** (SRD_CameraCore). Character sprites keep their native
  48×48 frames, so characters are ~1.5 tiles tall.
- **Three languages:** English (authoring language) + Russian + Romanian, via
  SRD_TranslationEngine, which matches the full English message block and swaps
  it. `translations.json` preserves that model.
- Maps 12 & 13 are **ending/credits screens** driven by parallel events that
  show a full-screen picture; they aren't walkable.

See the Phase 0 report in the conversation for the full plugin/asset breakdown.

## Repository layout

```
legacy/                     the original RPG Maker MV project (untouched)
tools/                      Python extraction + baking scripts (Phase 1/2)
  rmmv_common.py            shared load/save helpers
  extract_db.py            → data/*.json  (actors, items, system, ...)
  extract_maps.py          → data/maps/*.json (+ collision, overlays)
  extract_translations.py  → data/translations.json
  bake_tileset.py          → assets/tilesets/ + data/tile_atlas.json (collision ref)
  preview_map.py            dev-only: renders a reference PNG of a map
godot_project/              the Godot 4 project
  data/                     extracted, Godot-ready JSON (loaded at runtime)
  assets/                   img + audio copied from legacy (ogg only)
  autoload/                 GameDatabase, GameState (singletons)
  scripts/                  CharacterSprite, GameEvent, Player, GameMap
  scenes/                   main.tscn / main.gd (entry point)
```

## Re-running the extraction

Requires Python 3 + Pillow (`pip install pillow`). From the repo root:

```
python tools/extract_db.py
python tools/extract_maps.py
python tools/extract_translations.py
python tools/bake_tileset.py
python tools/preview_map.py 6      # optional: reference render of map 6
```

All scripts read from `legacy/data` and write into `godot_project/data`
(or `assets`). They're safe to re-run; output is deterministic.

## Opening in Godot

Targets **Godot 4.3+** (uses the `gl_compatibility` renderer and modern
Camera2D API). Open `godot_project/project.godot` and press Play. First open
will import the PNG/OGG assets.

- Move: arrow keys. Interact: Space / Enter / Z. Menu: Esc / X (menu is Phase 3).

## Phase status

- **Phase 0** — investigation + plan. ✅
- **Phase 1** — data extraction (db, maps+collision, translations). ✅
- **Phase 2** — Godot scaffold, GameDatabase autoload, assets, parallax map
  rendering, walkable collision. ✅
- **Phase 3** — event runner: dialogue + faces + EN/RU/RO, choices, conditional
  branches, switches/variables/self-switches, items, common events, transfers,
  SE/wait; action + player-touch + autorun triggers. ✅
- **Handed off** to hand-authoring — see **[HANDOFF.md](HANDOFF.md)** for the
  full developer guide (data format, runtime architecture, how to extend the
  event runner, what's stubbed, and gotchas).

### Not yet built (see HANDOFF.md §6–7 for how to add them)
- Move routes (205) / set-event-location (203) — cutscene movement.
- Parallel events run only their first pass.
- Pause menu, in-game language switch, save/load, title screen.
- Pictures/balloons/screen effects; the custom "kyriu" dodge sequence.
- Script (355) and plugin/camera (356) commands are ignored.

> **`HANDOFF.md` is the primary doc going forward.** This README is just the
> quick overview.
