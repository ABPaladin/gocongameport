"""
Phase 2 - Tileset atlas baker.

RPG Maker MV does not store tiles as a simple grid. Its "A" tilesheets are
*autotiles*: each map tile id encodes an autotile KIND (which block of the
sheet) and a SHAPE (0..47) that says how to composite four 16x16 quarter-tiles
into the final tile. Regular tiles (the B/C/D/E and A5 sheets) are a direct
grid crop. Godot's TileSet wants a plain atlas, so we pre-bake every tile the
maps actually use into one flat atlas PNG here, in Python, once.

The compositing logic below is a faithful port of `Tilemap._drawAutotile` /
`_drawNormalTile` and the autotile tables from the game's own
`legacy/js/rpg_core.js`, so the result matches what the original engine drew.

Two details specific to THIS project:
  * "Change Tile Size" plugin -> tiles are 32x32 (quarter-tiles are 16x16).
  * The maps only use A2 autotiles (2 kinds) + one B tile, and no "table"
    (counter) tiles, so the wall / A1-water / table-edge paths are included
    for completeness but aren't exercised here.

Outputs:
  godot_project/assets/tilesets/tileset_atlas.png   - the baked atlas
  godot_project/data/tile_atlas.json                - tileId -> [col,row] map

Run:  python tools/bake_tileset.py
"""

import glob
import json
import os

from PIL import Image

from rmmv_common import load_rm, LEGACY_DATA, OUT_DATA, REPO_ROOT

TILE = 32          # full tile size (px), from the Change Tile Size plugin
Q = TILE // 2      # quarter-tile size (16)

# --- Tile id ranges (from rpg_core.js) ---------------------------------------
TILE_ID_A5 = 1536
TILE_ID_A1 = 2048
TILE_ID_A2 = 2816
TILE_ID_A3 = 4352
TILE_ID_A4 = 5888
TILE_ID_MAX = 8192

# --- Autotile shape -> quarter-tile source offsets (from rpg_core.js) --------
FLOOR_AUTOTILE_TABLE = [
    [[2,4],[1,4],[2,3],[1,3]],[[2,0],[1,4],[2,3],[1,3]],
    [[2,4],[3,0],[2,3],[1,3]],[[2,0],[3,0],[2,3],[1,3]],
    [[2,4],[1,4],[2,3],[3,1]],[[2,0],[1,4],[2,3],[3,1]],
    [[2,4],[3,0],[2,3],[3,1]],[[2,0],[3,0],[2,3],[3,1]],
    [[2,4],[1,4],[2,1],[1,3]],[[2,0],[1,4],[2,1],[1,3]],
    [[2,4],[3,0],[2,1],[1,3]],[[2,0],[3,0],[2,1],[1,3]],
    [[2,4],[1,4],[2,1],[3,1]],[[2,0],[1,4],[2,1],[3,1]],
    [[2,4],[3,0],[2,1],[3,1]],[[2,0],[3,0],[2,1],[3,1]],
    [[0,4],[1,4],[0,3],[1,3]],[[0,4],[3,0],[0,3],[1,3]],
    [[0,4],[1,4],[0,3],[3,1]],[[0,4],[3,0],[0,3],[3,1]],
    [[2,2],[1,2],[2,3],[1,3]],[[2,2],[1,2],[2,3],[3,1]],
    [[2,2],[1,2],[2,1],[1,3]],[[2,2],[1,2],[2,1],[3,1]],
    [[2,4],[3,4],[2,3],[3,3]],[[2,4],[3,4],[2,1],[3,3]],
    [[2,0],[3,4],[2,3],[3,3]],[[2,0],[3,4],[2,1],[3,3]],
    [[2,4],[1,4],[2,5],[1,5]],[[2,0],[1,4],[2,5],[1,5]],
    [[2,4],[3,0],[2,5],[1,5]],[[2,0],[3,0],[2,5],[1,5]],
    [[0,4],[3,4],[0,3],[3,3]],[[2,2],[1,2],[2,5],[1,5]],
    [[0,2],[1,2],[0,3],[1,3]],[[0,2],[1,2],[0,3],[3,1]],
    [[2,2],[3,2],[2,3],[3,3]],[[2,2],[3,2],[2,1],[3,3]],
    [[2,4],[3,4],[2,5],[3,5]],[[2,0],[3,4],[2,5],[3,5]],
    [[0,4],[1,4],[0,5],[1,5]],[[0,4],[3,0],[0,5],[1,5]],
    [[0,2],[3,2],[0,3],[3,3]],[[0,2],[1,2],[0,5],[1,5]],
    [[0,4],[3,4],[0,5],[3,5]],[[2,2],[3,2],[2,5],[3,5]],
    [[0,2],[3,2],[0,5],[3,5]],[[0,0],[1,0],[0,1],[1,1]],
]

WALL_AUTOTILE_TABLE = [
    [[2,2],[1,2],[2,1],[1,1]],[[0,2],[1,2],[0,1],[1,1]],
    [[2,0],[1,0],[2,1],[1,1]],[[0,0],[1,0],[0,1],[1,1]],
    [[2,2],[3,2],[2,1],[3,1]],[[0,2],[3,2],[0,1],[3,1]],
    [[2,0],[3,0],[2,1],[3,1]],[[0,0],[3,0],[0,1],[3,1]],
    [[2,2],[1,2],[2,3],[1,3]],[[0,2],[1,2],[0,3],[1,3]],
    [[2,0],[1,0],[2,3],[1,3]],[[0,0],[1,0],[0,3],[1,3]],
    [[2,2],[3,2],[2,3],[3,3]],[[0,2],[3,2],[0,3],[3,3]],
    [[2,0],[3,0],[2,3],[3,3]],[[0,0],[3,0],[0,3],[3,3]],
]


def autotile_kind(tid):
    return (tid - TILE_ID_A1) // 48


def autotile_shape(tid):
    return (tid - TILE_ID_A1) % 48


def is_a1(t): return TILE_ID_A1 <= t < TILE_ID_A2
def is_a2(t): return TILE_ID_A2 <= t < TILE_ID_A3
def is_a3(t): return TILE_ID_A3 <= t < TILE_ID_A4
def is_a4(t): return TILE_ID_A4 <= t < TILE_ID_MAX
def is_a5(t): return TILE_ID_A5 <= t < TILE_ID_A1
def is_autotile(t): return t >= TILE_ID_A1


def load_tileset_bitmaps():
    """
    Return {setNumber: PIL.Image} for the slots this tileset fills.

    tilesetNames is [A1,A2,A3,A4,A5,B,C,D,E]; the index equals MV's setNumber.
    """
    ts = None
    for t in load_rm("Tilesets.json"):
        if t:
            ts = t          # this game has a single tileset (id 1)
            break
    bitmaps = {}
    folder = os.path.join(REPO_ROOT, "legacy", "img", "tilesets")
    for set_number, name in enumerate(ts["tilesetNames"]):
        if not name:
            continue
        path = os.path.join(folder, name + ".png")
        bitmaps[set_number] = Image.open(path).convert("RGBA")
    return ts, bitmaps


def bake_normal(tid, bitmaps):
    """Port of Tilemap._drawNormalTile (B/C/D/E/A5 grid crop)."""
    set_number = 4 if is_a5(tid) else 5 + tid // 256
    src = bitmaps.get(set_number)
    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    if src is None:
        return out
    sx = ((tid // 128) % 2 * 8 + tid % 8) * TILE
    sy = ((tid % 256) // 8 % 16) * TILE
    out.paste(src.crop((sx, sy, sx + TILE, sy + TILE)), (0, 0))
    return out


def bake_autotile(tid, bitmaps):
    """Port of Tilemap._drawAutotile (floor/wall). animationFrame fixed at 0."""
    table = FLOOR_AUTOTILE_TABLE
    kind = autotile_kind(tid)
    shape = autotile_shape(tid)
    tx, ty = kind % 8, kind // 8
    bx = by = 0
    set_number = 0

    if is_a1(tid):
        set_number = 0
        if kind == 0:      bx, by = 0, 0
        elif kind == 1:    bx, by = 0, 3
        elif kind == 2:    bx, by = 6, 0
        elif kind == 3:    bx, by = 6, 3
        else:
            bx = (tx // 4) * 8
            by = ty * 6 + (tx // 2) % 2 * 3
            if kind % 2 == 1:      # waterfall (frame 0)
                bx += 6
    elif is_a2(tid):
        set_number = 1
        bx, by = tx * 2, (ty - 2) * 3
    elif is_a3(tid):
        set_number, table = 2, WALL_AUTOTILE_TABLE
        bx, by = tx * 2, (ty - 6) * 2
    elif is_a4(tid):
        set_number = 3
        bx = tx * 2
        by = int((ty - 10) * 2.5 + (0.5 if ty % 2 == 1 else 0))
        if ty % 2 == 1:
            table = WALL_AUTOTILE_TABLE

    src = bitmaps.get(set_number)
    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    quads = table[shape] if shape < len(table) else None
    if src is None or quads is None:
        return out
    for i in range(4):
        qsx, qsy = quads[i]
        sx = (bx * 2 + qsx) * Q
        sy = (by * 2 + qsy) * Q
        piece = src.crop((sx, sy, sx + Q, sy + Q))
        out.paste(piece, ((i % 2) * Q, (i // 2) * Q), piece)
    return out


def bake_tile(tid, bitmaps):
    return bake_autotile(tid, bitmaps) if is_autotile(tid) else bake_normal(tid, bitmaps)


def collect_used_tile_ids():
    ids = set()
    for mf in glob.glob(os.path.join(OUT_DATA, "maps", "*.json")):
        with open(mf, encoding="utf-8") as f:
            d = json.load(f)
        for layer in d["layers"]:
            ids.update(t for t in layer if t)
    return sorted(ids)


def main():
    print("Phase 2 - baking tileset atlas")
    ts, bitmaps = load_tileset_bitmaps()
    print(f"  tileset '{ts['name']}' slots loaded: {sorted(bitmaps.keys())}")

    used = collect_used_tile_ids()
    print(f"  unique tile ids used across all maps: {len(used)}")

    # Pack into an atlas grid. 16 columns keeps the PNG small and square-ish.
    cols = 16
    rows = (len(used) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * TILE, rows * TILE), (0, 0, 0, 0))
    mapping = {}
    for i, tid in enumerate(used):
        col, row = i % cols, i // cols
        atlas.paste(bake_tile(tid, bitmaps), (col * TILE, row * TILE))
        mapping[str(tid)] = [col, row]

    out_png = os.path.join(OUT_DATA, "..", "assets", "tilesets", "tileset_atlas.png")
    out_png = os.path.normpath(out_png)
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    atlas.save(out_png)

    atlas_json = {
        "tileSize": TILE,
        "columns": cols,
        "rows": rows,
        "atlasImage": "res://assets/tilesets/tileset_atlas.png",
        "tiles": mapping,   # tileId -> [col, row] in the atlas
    }
    out_json = os.path.join(OUT_DATA, "tile_atlas.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(atlas_json, f, ensure_ascii=False, indent=2)

    print(f"  wrote {out_png}  ({atlas.width}x{atlas.height}, {cols}x{rows} grid)")
    print(f"  wrote {out_json}")


if __name__ == "__main__":
    main()
