# Gocon Game — Godot migration

The original RPG Maker MV game is preserved in `legacy/`. The playable port is
`gocon-game-rpg/project.godot`, using GDScript, GL Compatibility rendering,
816×624 presentation, a 32-pixel movement grid, and native-size painted maps.

Implementation and validation are ongoing; this is not yet a release parity claim.
See [TEST_REPORT.md](TEST_REPORT.md), [COMPATIBILITY_MATRIX.md](COMPATIBILITY_MATRIX.md)
and [MIGRATION_PROGRESS.md](MIGRATION_PROGRESS.md) for evidence and outstanding work.

## Run

Open `gocon-game-rpg/project.godot` in Godot 4.7.2 and press F6 on Main.tscn,
or F5. The installed version used for validation is 4.7.2.stable.steam.ed1daf0bf.
Choose New Game; the original Map006 introduction starts at (14,41).
Arrow keys move; Shift dashes where permitted; Enter/Space/Z interact;
Escape/X opens the pause menu. Click-to-move and touch buttons are implemented.
Gamepad bindings exist but hardware verification remains pending.

The menu exposes English/Romanian/Russian, music/sound volume, fullscreen,
inventory, and checkpoint saving. Saves use Godot's application user-data
directory; browser saves use browser persistent storage. Save outside dialogue,
movement, and minigames. Original RPG Maker saves are not imported.

## Validate and export

From this repository, with Python 3 and Godot installed:

```powershell
python -B -m unittest discover -s tests
python -B tools/godot_check.py
python -B tools/godot_check.py res://tests/runtime_tests.tscn
python -B tools/build_exports.py
python -B tools/export_smoke.py
python -B tools/browser_smoke.py
```

Set `GODOT_BIN` if Godot is not at the Steam path used by tools/godot_check.py.
Browser testing additionally requires Playwright and installed Edge; the current
workspace has isolated, ignored dependencies in `.test-deps/`.
Builds are ignored: `builds/windows/GoconGame.exe` and `builds/web/index.html`.
Run the EXE directly; serve Web over HTTP, for example
`python -m http.server 8000 --directory builds/web`, then open localhost:8000.
Opening the HTML with a file URL is unsupported.

## Content and architecture

`tools/prepare_runtime.py` deterministically regenerates JSON under
`gocon-game-rpg/data/` and resolves byte-identical assets by manifest. It never
rewrites hand-authored scripts/scenes or legacy files. Maps retain original
event command lists, IDs, tile layers, region data, and page conditions.
The runtime interprets this project's commands; it is not a universal MV engine.
There is no battle system to migrate.

[ARCHITECTURE.md](ARCHITECTURE.md) describes runtime ownership.
[HANDOFF.md](HANDOFF.md) contains continuation instructions.
The bundled Godot MCP editor plugin is disabled in this project's configuration
because the available MCP connection belongs to Cassette-LD60. That unrelated
project has not been changed. Use the CLI until correct-project binding is verified.

Asset and third-party plugin redistribution rights remain a release prerequisite;
existing files are not evidence of permission to release them under another engine.
