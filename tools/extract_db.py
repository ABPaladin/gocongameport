"""
Phase 1 - Database extraction.

Converts the RPG Maker MV "database" JSON files into clean, id-keyed JSON that
the Godot `GameDatabase` autoload can load directly.

This particular game is tiny: 1 actor, 1 class, 2 items, and no skills /
weapons / armors / enemies / troops / states. The extractors below are still
written generically (they'd handle a fuller database), but for the empty
tables they simply produce `{}`.

For each record we keep the fields that are meaningful to the port and drop
pure engine cruft. Where a table is empty we still emit the file so the Godot
side can load a consistent set of files.

Run:  python tools/extract_db.py
"""

from rmmv_common import load_rm, save_out, keyed_by_id


def actor(a):
    return {
        "id": a["id"],
        "name": a["name"],
        "nickname": a.get("nickname", ""),
        "classId": a["classId"],
        "initialLevel": a.get("initialLevel", 1),
        "maxLevel": a.get("maxLevel", 99),
        # Sprite / portrait references (used to draw the actor on maps + menus)
        "characterName": a.get("characterName", ""),
        "characterIndex": a.get("characterIndex", 0),
        "faceName": a.get("faceName", ""),
        "faceIndex": a.get("faceIndex", 0),
        "battlerName": a.get("battlerName", ""),
        "equips": a.get("equips", []),
        "traits": a.get("traits", []),
        "profile": a.get("profile", ""),
        "note": a.get("note", ""),
    }


def klass(c):
    return {
        "id": c["id"],
        "name": c["name"],
        # params is [8][maxLevel+1]: [mhp, mmp, atk, def, mat, mdf, agi, luk]
        "params": c.get("params", []),
        "expParams": c.get("expParams", []),
        "learnings": c.get("learnings", []),
        "traits": c.get("traits", []),
        "note": c.get("note", ""),
    }


def item(i):
    return {
        "id": i["id"],
        "name": i["name"],
        "description": i.get("description", ""),
        "iconIndex": i.get("iconIndex", 0),
        "itypeId": i.get("itypeId", 1),      # 1 = regular, 2 = key item
        "price": i.get("price", 0),
        "consumable": i.get("consumable", True),
        "scope": i.get("scope", 0),
        "occasion": i.get("occasion", 0),
        "effects": i.get("effects", []),
        "damage": i.get("damage", {}),
        "note": i.get("note", ""),
    }


def skill(s):
    return {
        "id": s["id"],
        "name": s["name"],
        "description": s.get("description", ""),
        "iconIndex": s.get("iconIndex", 0),
        "stypeId": s.get("stypeId", 0),
        "mpCost": s.get("mpCost", 0),
        "tpCost": s.get("tpCost", 0),
        "scope": s.get("scope", 0),
        "occasion": s.get("occasion", 0),
        "damage": s.get("damage", {}),
        "effects": s.get("effects", []),
        "note": s.get("note", ""),
    }


def equip(e):
    """Weapons and armors share the fields we care about."""
    out = {
        "id": e["id"],
        "name": e["name"],
        "description": e.get("description", ""),
        "iconIndex": e.get("iconIndex", 0),
        "price": e.get("price", 0),
        "params": e.get("params", []),
        "traits": e.get("traits", []),
        "note": e.get("note", ""),
    }
    if "wtypeId" in e:
        out["wtypeId"] = e["wtypeId"]
    if "atypeId" in e:
        out["atypeId"] = e["atypeId"]
        out["etypeId"] = e.get("etypeId", 0)
    return out


def enemy(e):
    return {
        "id": e["id"],
        "name": e["name"],
        "battlerName": e.get("battlerName", ""),
        "params": e.get("params", []),
        "exp": e.get("exp", 0),
        "gold": e.get("gold", 0),
        "actions": e.get("actions", []),
        "dropItems": e.get("dropItems", []),
        "traits": e.get("traits", []),
        "note": e.get("note", ""),
    }


def troop(t):
    return {
        "id": t["id"],
        "name": t["name"],
        "members": t.get("members", []),
        "pages": t.get("pages", []),
    }


def state(s):
    return {
        "id": s["id"],
        "name": s["name"],
        "iconIndex": s.get("iconIndex", 0),
        "restriction": s.get("restriction", 0),
        "priority": s.get("priority", 50),
        "motion": s.get("motion", 0),
        "traits": s.get("traits", []),
        "note": s.get("note", ""),
    }


# (raw filename, output filename, picker)
TABLES = [
    ("Actors.json", "actors.json", actor),
    ("Classes.json", "classes.json", klass),
    ("Items.json", "items.json", item),
    ("Skills.json", "skills.json", skill),
    ("Weapons.json", "weapons.json", equip),
    ("Armors.json", "armors.json", equip),
    ("Enemies.json", "enemies.json", enemy),
    ("Troops.json", "troops.json", troop),
    ("States.json", "states.json", state),
]


def main():
    print("Phase 1 - extracting database tables")
    for raw_name, out_name, picker in TABLES:
        data = keyed_by_id(load_rm(raw_name), picker)
        save_out(out_name, data)
        print(f"  {raw_name:16} -> data/{out_name:16} ({len(data)} records)")

    # System.json: keep just the bits the port needs (start pos, party, terms,
    # switch/variable names, the item/skill/etc. type names, title/game over).
    sysj = load_rm("System.json")
    system = {
        "gameTitle": sysj.get("gameTitle", ""),
        "locale": sysj.get("locale", "en_US"),
        "currencyUnit": sysj.get("currencyUnit", ""),
        "startMapId": sysj.get("startMapId", 1),
        "startX": sysj.get("startX", 0),
        "startY": sysj.get("startY", 0),
        "partyMembers": sysj.get("partyMembers", []),
        # switch/variable NAMES, keyed by id (drop the empty ones). Handy for
        # debugging events later since the game names its switches.
        "switches": {str(i): n for i, n in enumerate(sysj.get("switches", [])) if n},
        "variables": {str(i): n for i, n in enumerate(sysj.get("variables", [])) if n},
        "terms": sysj.get("terms", {}),
        "title1Name": sysj.get("title1Name", ""),
        "title2Name": sysj.get("title2Name", ""),
        "gameoverMe": sysj.get("gameoverMe", {}),
        "titleBgm": sysj.get("titleBgm", {}),
    }
    save_out("system.json", system)
    print(f"  System.json      -> data/system.json      "
          f"({len(system['switches'])} named switches, "
          f"{len(system['variables'])} named variables)")

    # Common events: keep condition + trigger + command list.
    commons = {}
    for ce in load_rm("CommonEvents.json"):
        if not ce:
            continue
        commons[str(ce["id"])] = {
            "id": ce["id"],
            "name": ce.get("name", ""),
            "trigger": ce.get("trigger", 0),   # 0 none, 1 autorun, 2 parallel
            "switchId": ce.get("switchId", 0),
            "list": ce.get("list", []),
        }
    save_out("common_events.json", commons)
    print(f"  CommonEvents.json -> data/common_events.json ({len(commons)} events)")


if __name__ == "__main__":
    main()
