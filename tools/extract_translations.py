"""
Phase 1 - Translation extraction.

The game uses SRD_TranslationEngine. Its model is: the ENGLISH source string is
the key, and at display time the engine swaps it for the current language's
version. We keep exactly that model so the Godot dialogue system can do the same
lookup:

    display_text = translations["msg"].get(english_source, {}) \
                                      .get(current_language, english_source)

Output shape (godot_project/data/translations.json):
    {
      "languages": ["English", "Russian", "Romanian"],   # English is the base
      "msg":    { "<english>": {"Russian": "...", "Romanian": "..."} },
      "cmd":    { "<english>": {"Russian": "...", "Romanian": "..."} },
      "custom": { "Russian": {term: "..."}, "Romanian": {term: "..."} }
    }

Run:  python tools/extract_translations.py
"""

from rmmv_common import load_rm, save_out


def main():
    print("Phase 1 - extracting translations")
    t = load_rm("Translations.json")

    msg = t.get("msg", {})
    cmd = t.get("cmd", {})
    custom = t.get("custom", {})

    # Discover the set of target languages actually present in the data.
    langs = set()
    for table in (msg, cmd):
        for _src, per_lang in table.items():
            langs.update(per_lang.keys())
    langs.update(custom.keys())
    # English is the authoring language; put it first, then the rest sorted.
    ordered = ["English"] + sorted(l for l in langs if l != "English")

    out = {
        "languages": ordered,
        "msg": msg,
        "cmd": cmd,
        "custom": custom,
    }
    save_out("translations.json", out)
    print(f"  languages: {ordered}")
    print(f"  msg entries: {len(msg)}, cmd entries: {len(cmd)}, "
          f"custom langs: {list(custom.keys())}")


if __name__ == "__main__":
    main()
