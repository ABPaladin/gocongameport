"""
Phase 1 - Map extraction.

Converts each `MapXXX.json` into a Godot-friendly shape:

  * Tile data is un-flattened. RPG Maker MV stores a map's tiles as one flat
    array of length width*height*6. Those 6 "z planes" are:
        plane 0..3 : the four tile layers (lower -> upper)
        plane 4    : shadow-pen bits (the little half-tile shadows)
        plane 5    : region ids (the coloured 1..255 overlay used by events
                     and by YEP_RegionRestrictions)
    We split them into 4 tile layers + a shadow plane + a region plane, each a
    flat row-major array of length width*height (index = y*width + x). Flat
    arrays keep the JSON small and are trivial to index from GDScript.

  * Events are simplified: each page keeps only its *active* conditions, its
    trigger/priority/movement flags, its graphic, its move route, and its
    command list (code + indent + parameters, untouched, so the event runner
    has everything it needs).

Also writes `map_index.json` from MapInfos.json (id -> name / tree order).

Run:  python tools/extract_maps.py
"""

import glob
import os

from rmmv_common import load_rm, save_out, LEGACY_DATA, REPO_ROOT

# The engine uses a 32x32 tile grid (RPG Maker's default 48 is overridden by
# the "Change Tile Size" plugin, param Tile Size = 32).
TILE_SIZE = 32

# --- Collision -------------------------------------------------------------
# This game is PARALLAX-MAPPED: the visible art lives in img/parallaxes/
# (!ground<id>.png below the player, !par<id>.png above). The four tile layers
# are an *invisible* collision map - the author paints walls with an impassable
# autotile and floor with a passable one. So we don't render the tile layers;
# we turn them into a walkable/blocked grid using the tileset passability flags,
# exactly the way RPG Maker's Game_Map.checkPassage does.
#
# Passage flag bits (per tile, from Tilesets.json "flags"):
#   0x01 down  0x02 left  0x04 right  0x08 up   (set = blocked in that dir)
#   0x10 = "star" (draw above; no effect on passage)
# checkPassage walks the 4 tiles at a cell from the top layer down, skips star
# tiles, and the first tile that is clearly passable/impassable decides it.
# In this project every collision tile is either 0x00 (open) or 0x0f (solid),
# so the per-direction result collapses to a single blocked/open boolean.
PASS_STAR = 0x10


def load_tileset_flags():
    for t in load_rm("Tilesets.json"):
        if t:                       # single tileset in this game
            return t["flags"]
    return []


def cell_blocked(layers, flags, x, y, w, h, bit=0x01):
    """Port of Game_Map.checkPassage for one cell; True == cannot walk here."""
    for z in range(3, -1, -1):      # upper layer first: z3, z2, z1, z0
        tid = layers[z][y * w + x]
        flag = flags[tid] if tid < len(flags) else 0
        if flag & PASS_STAR:
            continue                # [*] no effect on passage
        if (flag & bit) == 0:
            return False            # [o] passable
        if (flag & bit) == bit:
            return True             # [x] impassable
    return True                     # nothing decided -> treat as blocked


def unflatten_tiles(data, w, h):
    """Split the flat width*height*6 array into named planes."""
    plane = w * h
    layers = [data[i * plane:(i + 1) * plane] for i in range(4)]
    shadow = data[4 * plane:5 * plane]
    regions = data[5 * plane:6 * plane]
    return layers, shadow, regions


def active_conditions(c):
    """Collapse RM's parallel *Valid flags into just the conditions in force."""
    out = {}
    if c.get("switch1Valid"):
        out["switch1Id"] = c["switch1Id"]
    if c.get("switch2Valid"):
        out["switch2Id"] = c["switch2Id"]
    if c.get("variableValid"):
        out["variableId"] = c["variableId"]
        out["variableValue"] = c["variableValue"]
    if c.get("selfSwitchValid"):
        out["selfSwitchCh"] = c["selfSwitchCh"]
    if c.get("itemValid"):
        out["itemId"] = c["itemId"]
    if c.get("actorValid"):
        out["actorId"] = c["actorId"]
    return out


def simplify_move_route(mr):
    if not mr:
        return None
    return {
        "repeat": mr.get("repeat", True),
        "skippable": mr.get("skippable", False),
        "wait": mr.get("wait", False),
        # Each entry is {code, parameters?}; we drop the always-null "indent".
        "list": [
            {"code": step["code"], "parameters": step.get("parameters", [])}
            for step in mr.get("list", [])
        ],
    }


def simplify_page(p):
    return {
        "conditions": active_conditions(p["conditions"]),
        "image": {
            "characterName": p["image"]["characterName"],
            "characterIndex": p["image"]["characterIndex"],
            "direction": p["image"]["direction"],
            "pattern": p["image"]["pattern"],
            "tileId": p["image"]["tileId"],
        },
        "trigger": p["trigger"],            # 0 action, 1 player-touch,
                                            # 2 event-touch, 3 autorun, 4 parallel
        "priorityType": p["priorityType"],  # 0 below, 1 same, 2 above player
        "walkAnime": p["walkAnime"],
        "stepAnime": p["stepAnime"],
        "directionFix": p["directionFix"],
        "through": p["through"],
        "moveType": p["moveType"],          # 0 fixed, 1 random, 2 approach, 3 custom
        "moveSpeed": p["moveSpeed"],
        "moveFrequency": p["moveFrequency"],
        "moveRoute": simplify_move_route(p.get("moveRoute")),
        # Command list kept verbatim (code + indent + parameters).
        "list": [
            {"code": cmd["code"], "indent": cmd.get("indent", 0),
             "parameters": cmd["parameters"]}
            for cmd in p["list"]
        ],
    }


def simplify_event(e):
    return {
        "id": e["id"],
        "name": e["name"],
        "x": e["x"],
        "y": e["y"],
        "note": e.get("note", ""),
        "pages": [simplify_page(p) for p in e["pages"]],
    }


def extract_map(raw_name, map_id, flags):
    d = load_rm(raw_name)
    w, h = d["width"], d["height"]
    layers, shadow, regions = unflatten_tiles(d["data"], w, h)
    events = [simplify_event(e) for e in d["events"] if e]

    # Collision grid: 1 == blocked, 0 == walkable (row-major, index = y*w + x).
    collision = [
        1 if cell_blocked(layers, flags, x, y, w, h) else 0
        for y in range(h) for x in range(w)
    ]

    # Parallax art for this map. OrangeOverlay only shows an overlay if the
    # map's NOTE contains the matching tag (<ground>/<par>) or <all>; otherwise
    # the file on disk is ignored. The `par` layer is additionally gated behind
    # a switch (OrangeOverlay "Parallax Switch ID" = 3): it's only visible while
    # that switch is ON. OrangeOverlay Quick Start enables switches 1-4 in
    # DataManager.setupNewGame; the native GameState must reproduce this.
    par_dir = os.path.join(REPO_ROOT, "legacy", "img", "parallaxes")
    note = d.get("note", "")
    has_all = "<all>" in note

    def overlay_for(tag: str, fname: str) -> str:
        enabled = has_all or ("<%s>" % tag) in note
        exists = os.path.exists(os.path.join(par_dir, fname))
        return fname if (enabled and exists) else ""

    overlays = {
        "ground": overlay_for("ground", f"!ground{map_id}.png"),
        "par": overlay_for("par", f"!par{map_id}.png"),
        "parSwitch": 3,   # par hidden unless this game switch is ON
    }

    return {
        "id": map_id,
        "width": w,
        "height": h,
        "tileSize": TILE_SIZE,
        "tilesetId": d["tilesetId"],
        "displayName": d.get("displayName", ""),
        "scrollType": d.get("scrollType", 0),
        "disableDashing": d.get("disableDashing", False),
        # Background music: autoplay + the actual track.
        "autoplayBgm": d.get("autoplayBgm", False),
        "bgm": d.get("bgm", {}),
        "note": d.get("note", ""),
        # Parallax-map art (rendered instead of the tile layers).
        "overlays": overlays,
        # Collision derived from the tile layers (the layers themselves are
        # invisible in this game; kept below for debugging/reference).
        "collision": collision,
        "regions": regions,   # flat array of region ids (0..255)
        # Raw tile planes kept for reference / future use.
        "layers": layers,     # 4 flat arrays, row-major
        "shadow": shadow,     # flat array of shadow-pen bitmasks
        # Events
        "events": events,
    }


def main():
    print("Phase 1 - extracting maps")
    flags = load_tileset_flags()
    map_files = sorted(glob.glob(os.path.join(LEGACY_DATA, "Map[0-9]*.json")))
    for mf in map_files:
        raw_name = os.path.basename(mf)               # e.g. "Map006.json"
        map_id = int(raw_name[3:6])                   # 6
        out = extract_map(raw_name, map_id, flags)
        out_name = f"maps/map{map_id:03d}.json"
        save_out(out_name, out)
        n_ev = len(out["events"])
        n_blocked = sum(out["collision"])
        ov = "+".join(k for k, v in out["overlays"].items() if v) or "none"
        print(f"  {raw_name:14} -> data/{out_name:18} "
              f"{out['width']}x{out['height']}, {n_ev:3d} events, "
              f"{n_blocked:4d} blocked cells, art={ov}")

    # Map index from MapInfos.json
    index = {}
    for m in load_rm("MapInfos.json"):
        if not m:
            continue
        index[str(m["id"])] = {
            "id": m["id"],
            "name": m["name"],
            "parentId": m.get("parentId", 0),
            "order": m.get("order", 0),
        }
    save_out("map_index.json", index)
    print(f"  MapInfos.json  -> data/map_index.json ({len(index)} maps)")


if __name__ == "__main__":
    main()
