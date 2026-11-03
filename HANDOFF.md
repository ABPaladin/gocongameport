# Developer Guide / Handoff

Everything you need to take this RPG Maker MV → Godot 4 port into your own hands.
It explains how the data is shaped, how the Godot runtime is wired, how to extend
it (with a full worked example), what's already done, what's stubbed, and the
gotchas that will bite you if you don't know them.

> If you only read one section, read **§6 (Extending the event runner)** and
> **§8 (Gotchas)**.

---

## 1. What this game actually is

- **Exploration / dialogue game, no battles.** 1 actor (Go-Chan), 2 items
  (Stamp, QuestList), no skills/enemies/troops/weapons/armors/states. The goal
  (from the intro on Map 6): *collect all 6 stamps from people at the
  convention, redeem at the Gachapon machine.*
- **Parallax-mapped.** The visible art is NOT tiles. Each map is a painted
  image: `img/parallaxes/!ground<id>.png` (drawn under the player) and
  `!par<id>.png` (drawn over the player). The RPG Maker tile layers are an
  **invisible collision map** — walls are an impassable autotile, floor a
  passable one.
- **32×32 tiles** (the "Change Tile Size" plugin overrides the default 48),
  **2× camera zoom** (SRD_CameraCore). Character sprites keep their native
  48×48 frames (so a character is ~1.5 tiles tall), anchored at the feet.
- **Three languages:** English (base) + Russian + Romanian (SRD_TranslationEngine).

---

## 2. Repository layout

```
legacy/                 the original RPG Maker MV project (never modified)
tools/                  Python extraction pipeline (run these to (re)build data)
godot_project/          the Godot 4 project you open and run
  project.godot
  data/                 extracted, Godot-ready JSON (loaded at runtime)
  assets/               img + audio copied from legacy (ogg only)
  autoload/             GameDatabase.gd, GameState.gd  (singletons)
  scripts/              CharacterSprite, GameEvent, Player, GameMap,
                        DialogueBox, EventRunner
  scenes/               main.tscn / main.gd  (entry point)
README.md               short overview + phase status
HANDOFF.md              this file
```

---

## 3. The data pipeline (tools/)

All scripts read `legacy/data/*` and write `godot_project/data/*`. They're
deterministic and safe to re-run. Requires Python 3 + Pillow (`pip install pillow`).

| Script | Produces | Notes |
|---|---|---|
| `rmmv_common.py` | — | shared load/save helpers (paths, UTF-8, drop null-0, key by id) |
| `extract_db.py` | `actors/classes/items/skills/weapons/armors/enemies/troops/states.json`, `system.json`, `common_events.json` | keyed by string id |
| `extract_maps.py` | `maps/map###.json`, `map_index.json` | unflattens tile layers → collision grid; records overlays |
| `extract_translations.py` | `translations.json` | EN source → {Russian, Romanian} |
| `bake_tileset.py` | `assets/tilesets/tileset_atlas.png`, `tile_atlas.json` | collision-tile reference; **not used for rendering** (maps are parallax) |
| `preview_map.py <id>` | `tools/preview_map###.png` | dev-only reference render (ground + npc sprites + red collision wash). `preview_map.py 6 nopar` to hide the foreground. |

To rebuild everything after editing the legacy project:

```
python tools/extract_db.py
python tools/extract_maps.py
python tools/extract_translations.py
```

> **`data/sprite_offsets.json` is hand-maintained** — it is NOT produced by the
> pipeline, so re-running extraction won't overwrite it.

---

## 4. Data format reference

Every id-keyed file is `{ "1": {...}, "2": {...} }` (RPG Maker's null index-0
placeholder is dropped).

### `maps/map###.json`
```jsonc
{
  "id": 6,
  "width": 60, "height": 60, "tileSize": 32,
  "displayName": "", "tilesetId": 1,
  "autoplayBgm": true, "bgm": {"name": "map 3", "volume": 90, "pitch": 100, "pan": 0},
  "overlays": { "ground": "!ground6.png", "par": "!par6.png", "parSwitch": 3 },
  "collision": [0,0,1,...],   // flat, row-major, index = y*width + x; 1 = blocked
  "regions":   [0,1,0,...],   // region ids (mostly unused here)
  "layers":    [[...],[...],[...],[...]],  // raw RM tile planes (kept for reference)
  "shadow":    [...],
  "events": [ {
    "id": 1, "name": "EV001", "x": 36, "y": 21, "note": "",
    "pages": [ {
      "conditions": { "switch1Id": 10, "selfSwitchCh": "A", ... },  // only ACTIVE conditions
      "image": { "characterName": "Actor3", "characterIndex": 6, "direction": 2, "pattern": 1, "tileId": 0 },
      "trigger": 0,        // 0 action, 1 player-touch, 2 event-touch, 3 autorun, 4 parallel
      "priorityType": 1,   // 0 below, 1 same (blocks), 2 above
      "moveType": 0, "moveSpeed": 3, "moveFrequency": 3,
      "moveRoute": { "repeat": true, "skippable": false, "wait": false, "list": [ {"code": 1, "parameters": []}, ... ] },
      "list": [ {"code": 101, "indent": 0, "parameters": ["", 0, 0, 2]}, {"code": 401, "indent": 0, "parameters": ["Hello!"]}, ... ]
    } ]
  } ]
}
```

### `translations.json`
```jsonc
{
  "languages": ["English", "Romanian", "Russian"],
  "msg":    { "<english message block>": {"Russian": "...", "Romanian": "..."} },
  "cmd":    { "<english choice text>":   {"Russian": "...", "Romanian": "..."} },
  "custom": { "Russian": {term: "..."}, "Romanian": {term: "..."} }
}
```
The key is the **full English message block** (all consecutive 401 lines joined
with `\n`). The dialogue box looks up that exact string.

### `sprite_offsets.json` (hand-maintained)
```jsonc
{ "6": { "6": -8, "8": -8, "9": -8 } }   // mapId -> eventId -> pixels (negative = up)
```
Purely visual nudge for NPCs standing behind foreground props. No effect on
collision or interaction.

---

## 5. Runtime architecture

### Autoloads
- **`GameDatabase`** — on startup loads every `data/*.json` into dictionaries.
  `get_map(id)` loads + caches a map. Convenience: `actor(id)`, `item(id)`,
  `map_name(id)`.
- **`GameState`** — mutable state that persists across maps and (eventually)
  into saves: `switches`, `variables`, `self_switches`, `party`, `items_held`,
  `gold`, `language`, and the player's `current_map_id / player_x / player_y /
  player_direction`. Also registers the `interact` and `open_menu` input actions.

### Scene flow
```
Main (scenes/main.gd)
 ├── DialogueBox            (persistent message window, CanvasLayer)
 └── GameMap (rebuilt per map)
      ├── Ground  Sprite2D  (z -10)
      ├── Entities Node2D   (y-sorted)
      │    ├── GameEvent … (each with a CharacterSprite child)
      │    └── Player        (with a Camera2D child, 2× zoom)
      └── Par     Sprite2D  (z 100, foreground)
```

- **`Main`** creates the persistent `DialogueBox`, loads the start map, and on a
  transfer request frees the old `GameMap` and builds the new one.
- **`GameMap.build(id)`** loads the map data, draws the ground/par sprites,
  turns `collision` into `is_passable(x,y)`, spawns events + player + camera,
  plays BGM, then fires autorun events.
- **`GameEvent`** picks its active page (highest-index page whose conditions are
  met — see `refresh_page()`), shows that page's graphic, and exposes
  `trigger_type()`, `priority_type()`, `command_list()`.
- **`Player`** does grid movement + collision; pressing `interact` talks to the
  event it faces; bumping a blocking tile fires touch events there.
- **`GameMap._run_event(ev)`** locks the player, runs the event's command list
  through an `EventRunner`, then refreshes event pages and unlocks.

### Triggers (who starts an event)
- **action (0):** `Player._try_interact()` → `GameMap.action_event_at()`.
- **player-touch (1):** `Player` calls `GameMap.on_player_arrived()` (stepped
  onto) or `GameMap.try_touch()` (bumped a blocking one, e.g. doors).
- **autorun (3):** `GameMap._run_autorun_events()` after build and after each
  event finishes.
- **parallel (4):** *not yet run continuously* (see §7).

---

## 6. Extending the event runner  ⭐

`scripts/event_runner.gd` interprets a page's command `list`. It walks the list
with an index pointer; control-flow commands (conditionals, choices) use each
command's `indent` to know which block to skip via `_skip_branch()`.

**To add a new command code**, add a `case` in `_execute()` and a handler.
Handlers may `await` (for anything that waits on the player or a timer).

### Worked example: move routes (command 205) — the "girl walks to Go-Chan" cutscene

`205 SetMoveRoute` parameters are `[targetId, moveRoute]`:
- `targetId`: `-1` = the player, `0` = *this* event, `>0` = the event with that id.
- `moveRoute`: `{repeat, skippable, wait, list}` where each `list` entry is
  `{code, parameters}`. The movement codes you care about:
  `1` down, `2` left, `3` right, `4` up, `5` lower-left, `6` lower-right,
  `7` upper-left, `8` upper-right, `9` random, `10` toward player, `15` wait,
  `45` script. (Full list in RPG Maker docs; this game mostly uses 1–4.)

**Step 1 — give characters a "step one tile" method.** `Player` already tweens
between cells in `_step_to()`. Add a similar `step(dir)` to both `Player` and
`GameEvent` that moves one tile in a direction and returns when the tween ends
(so the runner can `await` it). Example for `GameEvent`:

```gdscript
# in game_event.gd
signal step_finished
const DIR_VEC := {2: Vector2i(0,1), 4: Vector2i(-1,0), 6: Vector2i(1,0), 8: Vector2i(0,-1)}

func step(dir: int, map) -> void:
    var d: Vector2i = DIR_VEC.get(dir, Vector2i.ZERO)
    var tx := grid_x + d.x
    var ty := grid_y + d.y
    if not map.is_passable(tx, ty):
        return                      # blocked: skip this step
    grid_x = tx; grid_y = ty
    var dest := Vector2(tx*TILE + TILE/2.0, ty*TILE + TILE)
    var tw := create_tween()
    tw.tween_property(self, "position", dest, 0.16)
    await tw.finished
```

**Step 2 — handle 205 in the runner.** Add to `_execute()`:

```gdscript
205: await _set_move_route(p)
```

and the handler:

```gdscript
func _set_move_route(p: Array) -> void:
    var target := _resolve_character(int(p[0]))     # player or an event node
    if target == null:
        return
    var route: Dictionary = p[1] if p.size() > 1 else {}
    var move_codes := {1:2, 2:4, 3:6, 4:8}          # RM move code -> our direction
    for cmd in route.get("list", []):
        var mc := int(cmd.get("code", 0))
        if move_codes.has(mc):
            await target.step(move_codes[mc], game_map)
        # else: handle 15 wait, 10 toward-player, etc. as needed

func _resolve_character(target_id: int):
    if target_id < 0:
        return game_map.player
    if target_id == 0:
        return event
    for ev in game_map.events:
        if ev.event_id == target_id:
            return ev
    return null
```

That's the whole pattern: **resolve target → await its steps.** If the move
route has `wait == true`, the event pauses until it's done (which the `await`
already does). If `wait == false`, you'd want to run it without awaiting
(fire-and-forget) — start it with `_set_move_route(p)` and don't `await`.

> The same `step()` idea covers command **203 SetEventLocation** (teleport an
> event to x,y) and event **autonomous movement** (`page.moveType == 3` runs
> `page.moveRoute` on a loop).

### Other codes you may want next
| Code | What | Where the params live |
|---|---|---|
| 203 | Set event location | `[eventId, designation, x, y, direction]` |
| 213 | Show balloon icon | `[eventId, balloonId, wait]` |
| 231/232/235 | Show/move/erase picture | picture id + position |
| 355/655 | Script (JS) | you'll reimplement the intent in GDScript |
| parallel (trigger 4) | background loops | run in `GameMap` `_process`, not the runner |

---

## 7. What's done vs stubbed

**Done**
- Full data extraction (db, maps + collision, translations).
- Parallax map rendering (ground + foreground), 32px grid, 2× camera.
- Player grid movement + collision + event blocking.
- Event runner: text (101/401) with faces + EN/RU/RO lookup, choices
  (102/402/404), conditional branches (111/411/412 — switch/self-switch/variable/
  item), switches/variables/self-switches (121/122/123), items (126), common
  events (117), transfers (201), SE (250), wait (230), erase event (214).
- Triggers: action, player-touch (step + bump), autorun (once).

**Stubbed / not yet built**
- **Move routes (205)** and **set-event-location (203)** — cutscene movement
  doesn't play. (See §6 for exactly how to add it.)
- **Parallel events (trigger 4)** run only their first pass, not continuously.
- **Variable-designated transfers** (201 with param0 != 0).
- **Pictures (231/232/235), balloons (213), screen effects, weather.**
- **Pause menu** (party HP/MP/level + items) — not built; so no in-game
  **language switch** yet (defaults to English; change `GameState.language` to
  `"Russian"`/`"Romanian"` in code to test).
- **Save/load, title screen, the custom "kyriu" projectile-dodge sequence.**
- **Script calls (355/655)** and **plugin/camera commands (356/357)** are ignored.

Unhandled command codes are skipped safely and printed once to the Output panel
as `[EventRunner] unhandled command code: N` — a quick way to see what a given
scene needs.

---

## 8. Gotchas (learned the hard way)

1. **JSON ints can arrive as floats.** `str(6.0)` may not equal the `"6"` key in
   a dictionary. When using an id as a dictionary key, normalise:
   `str(int(id))`. (This silently broke `sprite_offsets` lookups once.)
2. **Don't name a method the same as a native Godot one.** `CharacterSprite`
   originally had `set_frame()`, which collides with `Sprite2D.set_frame(int)`
   and fails to parse (and cascades to every dependent script). It's now
   `set_char_frame()`.
3. **Avoid `\` line-continuations in GDScript.** They're fragile (a trailing
   space breaks them) and caused end-of-file parse errors. Put it on one line.
4. **Characters are 48×48 on a 32px grid**, anchored feet-to-cell-bottom-center
   (`CharacterSprite.offset = (0, -frame_h/2)`, node at `(x*32+16, y*32+32)`).
5. **`par` foreground is shown by choice.** The original OrangeOverlay plugin
   gates it behind a switch (3) that's never turned on, so technically it'd be
   hidden — but the map looks fuller with it, so `GameMap._build_par()` always
   shows a note-tagged par. Flip that line if you ever want strict fidelity.
6. **Audio: use `.ogg`.** The legacy project ships `.m4a` + `.ogg`; Godot can't
   import AAC/M4A. Only the `.ogg` copies were brought over.
7. **Overlays are gated by the map NOTE**, not just by the file existing. A map
   only shows `!ground`/`!par` if its note contains `<ground>`/`<par>`/`<all>`.
8. **Re-running extraction overwrites `data/` but not `sprite_offsets.json`.**

---

## 9. Handy references while working

- Profile which event codes a map uses:
  `python -c "import json,glob; from collections import Counter; c=Counter(x['code'] for f in glob.glob('godot_project/data/maps/*.json') for e in json.load(open(f,encoding='utf-8'))['events'] for p in e['pages'] for x in p['list']); print(c.most_common())"`
- The memory of key decisions/findings lives in the Claude memory folder
  (`rpgmv-godot-port.md`, `port-user-decisions.md`) if you resume with the
  assistant later.
- Target engine: **Godot 4.3+** (developed against 4.7), `gl_compatibility`
  renderer.

Good luck — the engine's solid; the rest is your game to tell.
