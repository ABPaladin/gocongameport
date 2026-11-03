"""
Dev tool - render a reference preview of a map (NOT part of the game).

Because the person building this port can't open the Godot editor from here,
this script composites what one map *should* look like using the same rules
the Godot GameMap uses:
  * !ground<id> at the top-left (0,0),
  * event character sprites at their cells (bottom-centre anchored),
  * !par<id> overlay on top,
  * a translucent red wash over blocked collision cells,
  * a marker at the player start.
Use it to eyeball-verify positioning/collision before/after checking Godot.

Run:  python tools/preview_map.py 6
"""

import json
import os
import sys

from PIL import Image, ImageDraw

from rmmv_common import OUT_DATA, REPO_ROOT

TILE = 32
CHAR_DIR = os.path.join(REPO_ROOT, "legacy", "img", "characters")
PAR_DIR = os.path.join(REPO_ROOT, "legacy", "img", "parallaxes")


def char_frame(name, index, direction, pattern=1):
    """Slice one 48x48 (or big) frame from an MV character sheet."""
    path = os.path.join(CHAR_DIR, name + ".png")
    if not os.path.exists(path):
        return None
    sheet = Image.open(path).convert("RGBA")
    big = name.startswith("$")
    if big:
        fw, fh = sheet.width // 3, sheet.height // 4
        bx, by = 0, 0
    else:
        fw, fh = sheet.width // 12, sheet.height // 8
        bx, by = (index % 4) * 3 * fw, (index // 4) * 4 * fh
    row = direction // 2 - 1
    col = max(0, min(2, pattern))
    return sheet.crop((bx + col * fw, by + row * fh, bx + col * fw + fw, by + row * fh + fh))


def main():
    map_id = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    with open(os.path.join(OUT_DATA, "maps", "map%03d.json" % map_id), encoding="utf-8") as f:
        d = json.load(f)
    w, h = d["width"], d["height"]

    # Canvas covers both the tile grid and any larger ground image.
    ground_img = None
    gname = d["overlays"].get("ground", "")
    if gname:
        ground_img = Image.open(os.path.join(PAR_DIR, gname)).convert("RGBA")
    cw = max(w * TILE, ground_img.width if ground_img else 0)
    ch = max(h * TILE, ground_img.height if ground_img else 0)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 255))

    # Ground (top-left at 0,0)
    if ground_img:
        canvas.alpha_composite(ground_img, (0, 0))

    # Collision wash
    wash = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    for y in range(h):
        for x in range(w):
            if d["collision"][y * w + x]:
                wd.rectangle([x * TILE, y * TILE, x * TILE + TILE - 1, y * TILE + TILE - 1],
                             fill=(255, 0, 0, 60))
    canvas.alpha_composite(wash)

    # Per-event visual Y nudges (same data the Godot side uses).
    offsets = {}
    off_path = os.path.join(OUT_DATA, "sprite_offsets.json")
    if os.path.exists(off_path):
        with open(off_path, encoding="utf-8") as f:
            offsets = json.load(f).get(str(map_id), {})

    # Event sprites (active-ish: just use page 0's graphic for the preview)
    for e in d["events"]:
        page = e["pages"][0]
        img = page["image"]
        if img["characterName"]:
            frame = char_frame(img["characterName"], img["characterIndex"],
                               img["direction"], img["pattern"])
            if frame:
                y_off = int(offsets.get(str(e["id"]), 0))
                fx = e["x"] * TILE + TILE // 2 - frame.width // 2
                fy = e["y"] * TILE + TILE - frame.height + y_off
                canvas.alpha_composite(frame, (fx, fy))

    # Par overlay (the raised foreground props), drawn above everything. We
    # show it by project preference (it makes the map look fuller). Pass
    # "nopar" to hide it.
    pname = d["overlays"].get("par", "")
    if pname and not (len(sys.argv) > 2 and sys.argv[2] == "nopar"):
        par = Image.open(os.path.join(PAR_DIR, pname)).convert("RGBA")
        canvas.alpha_composite(par, (0, 0))

    out = os.path.join(REPO_ROOT, "tools", "preview_map%03d.png" % map_id)
    canvas.convert("RGB").save(out)
    print("wrote", out, "(%dx%d)" % (cw, ch))


if __name__ == "__main__":
    main()
