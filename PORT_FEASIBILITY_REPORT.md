# RPG Maker Port Feasibility Report

Analysis date: 2026-11-03. Workspace: `C:/Users/alexa/Downloads/rpg maker to godot`.

**Scope:** read-only static inspection of the existing game, existing partial port, and existing conversion scripts; read-only MCP diagnostics; current official documentation research. No game was launched, built, imported, converted, or modified. Only this report is a deliverable. Behavioral claims below distinguish source evidence from runtime verification.

## 1. Executive Summary

**Recommendation: use Godot 4 with GDScript, a game-specific event interpreter, and native implementations of the small number of plugin features this game actually needs.** Reuse and audit the existing `gocon-game-rpg/` scaffold rather than assuming it is a working port. Preserve RPG Maker as the behavior reference. Do not commission a universal RPG Maker compatibility engine.

The original is **RPG Maker MV runtime 1.6.1**, an exploration/dialogue convention game with stamp collection and several event-driven minigames. It is not a conventional battle RPG. There are 13 maps, 156 map events, 173 event pages, 183 message-start commands, 27 choice commands, and 66 transfer commands. There is one actor, one class, two items, no populated battle database, and one empty common event. This makes a focused migration realistic, but parallel event timing, picture-based QTE logic, projectile encounters, localization, and plugin initialization prevent a trivial asset-and-dialogue port.

Key findings:

- Much visible map art is painted parallax imagery; the tiles primarily encode collision. A wholesale visual TileMap conversion is unnecessary.
- Existing conversion output preserves the command lists of all 13 maps exactly in a structural comparison. This is useful reusable data, not proof of runtime parity.
- Existing documentation overstates implementation. The actual event runner, game-data loader, scene manager, audio manager, and pause-menu script are stubs. Main.tscn is an empty root. The current dialogue reader collects text from all branches without interpreting them.
- An extractor comment incorrectly says the foreground switch is never enabled. OrangeOverlay's enabled Quick Start explicitly enables switches 1–4 on new game.
- Godot MCP responds and reports an editor connection, but its root is the **unrelated Cassette project**. It is not currently verified against this RPG project. Runtime bridge is unavailable.
- Phaser is viable for a browser-first product but will not run the active RPG Maker plugins unchanged. Most customization is coupled to RPG Maker globals and prototype patches; there is no substantial independent JavaScript game-logic library to transplant.
- Retaining and modernizing MV is the least costly release path. Porting is justified by future development workflow, editor ownership, native exports, and maintainability—not by demonstrated performance problems.

Planning estimate for a faithful Godot completion: **43–81 person-days base, approximately 54–109 with contingency**, assuming one experienced full-time developer, existing licensed art, no major redesign, and Windows plus browser delivery. Treat this as a planning range, not a quotation.

## 2. Project Overview and Inspection Coverage

### Engine identification

`legacy/js/rpg_core.js:173` declares MV; line 183 declares runtime version `1.6.1`. The exact RPG Maker authoring application patch version is **Unknown / Requires Verification**: no .rpgproject editor marker was found. Runtime version is not necessarily the installed editor version.

`legacy/index.html` loads Pixi, six MV core modules, the plugin configuration, and main.js. `legacy/js/libs/pixi.js:8261` identifies PixiJS 4.5.4. The original is readable JavaScript and JSON with unencrypted PNG/OGG/M4A resources. `legacy/package.json` is an NW.js-style application manifest, not a dependency-managed Phaser project. `legacy/START.bat` invokes browser-sync; no dependency installation or execution was attempted.

### Recursive inventory

Initial recursive inventory: **895 files, 52,060,379 bytes**, including Godot import/editor caches, duplicate assets, previews, and existing Python bytecode. This is workspace size, not shipping-game size.

| Location | Role and findings |
|---|---|
| `legacy/js/rpg_{core,managers,objects,scenes,sprites,windows}.js` | Six engine modules; rendering/input, managers, model/interpreter, scenes, sprites, windows |
| `legacy/js/main.js`, `plugins.js` | Bootstrap and ordered plugin activation |
| `legacy/js/plugins/` | 26 JS files: 21 active substantive plugins, one separator file, four unregistered files |
| `legacy/js/libs/` | PixiJS, pixi-tilemap, pixi-picture, lz-string, fpsmeter, iphone-inline-video |
| `legacy/data/` | 13 maps, MapInfos, database, translations, HUD/editor metadata |
| `legacy/img/` | 12 character sheets, 1 face sheet, 19 parallaxes, 2 tilesets, 24 pictures, 16 system images, 16 VirtualButtons images, 1 title image |
| `legacy/audio/` | 3 BGM tracks and 10 SE stems, each with OGG and M4A: 26 files total |
| `legacy/fonts/` | gamefont.css and mplus-1m-regular.ttf |
| `legacy/supertoolsengine.html`, `translationengine.html` | SRD authoring/editor interfaces |
| `tools/` | Six pre-existing Python extraction/baking/preview scripts; images and bytecode also present |
| `gocon-game-rpg/` | Existing Godot scaffold, scenes, scripts, renamed assets, 13 extracted map JSONs |
| `gocon-game-rpg/addons/` | godot-mcp editor/runtime scripts; psx_shader addon with example, models and five shaders |
| `README.md`, `HANDOFF.md`, `ARCHITECTURE.md` | Historical claims/design guidance; inconsistent with current source |
| `.claude/`, Godot caches | Workspace/editor metadata, not evidence of shipped gameplay |

No AGENTS.md was found. Every map's event/page command list was scanned; plugin registration, API-hook references, key custom implementations, database contents, source entry points, and Godot scripts were inspected in multiple passes. This was not a formal line-by-line audit of all bundled libraries. No pristine MV checksum baseline was available, so unmarked edits inside engine modules remain **Unknown / Requires Verification**.

### Map inventory

All filenames below are under `legacy/data/`; event/page counts exclude null event slots.

| Map | Grid | Events | Pages | Ground/par note tags |
|---|---:|---:|---:|---|
| Map001.json | 30×30 | 20 | 22 | ground, par |
| Map002.json | 30×30 | 14 | 16 | ground |
| Map003.json | 40×40 | 10 | 10 | ground |
| Map004.json | 40×40 | 29 | 30 | ground, par |
| Map005.json | 40×40 | 21 | 21 | ground, par |
| Map006.json | 60×60 | 18 | 19 | ground, par |
| Map007.json | 40×40 | 15 | 19 | ground, par |
| Map008.json | 40×40 | 9 | 16 | ground |
| Map009.json | 40×40 | 9 | 9 | ground, par |
| Map010.json | 40×40 | 3 | 3 | ground |
| Map011.json | 40×40 | 6 | 6 | ground |
| Map012.json | 30×30 | 1 | 1 | none; picture sequence |
| Map013.json | 30×30 | 1 | 1 | none; picture/Thank You sequence |

System start is Map 6, tile (14,41), party actor 1; title is “Gocon Game Test.” Tile size is 32, configured by Change Tile Size. SRD_CameraCore default zoom is 2; picture zoom is enabled. Source window is 816×624.

Art dimensions do not necessarily equal grid dimensions: `!ground6.png` is 1752×1698 while its grid spans 1920×1920 pixels. `!ground1.png` is 903×1024 versus a 960×960 grid. Preserve original anchoring, cropping, camera limits and uncovered margins; do not stretch art to grid dimensions automatically.

## 3. System Inventory and Execution Architecture

| System | Actual source behavior / evidence | Migration classification |
|---|---|---|
| Startup | index.html → PluginManager.setup in main.js → SceneManager.run(Scene_Boot); MadeWithMv adds splash before title flow | Rebuild boot/title; preserve required attribution separately |
| Scene management | MV SceneManager and Scene_* stack in rpg_managers/rpg_scenes; plugin patches wrap scenes in activation order | Native scenes plus explicit transitions |
| Map loading | DataManager loads MapNNN.json; Game_Map builds Game_Event instances, coordinates, interpreter state | Convert data; replace runtime objects |
| Movement | Game_CharacterBase.canPass, rpg_objects.js:6391; grid passage and event occupancy, interpolation and movement routes | Reimplement grid semantics, not merely generic physics |
| Passage | Game_Map.checkPassage, rpg_objects.js:5911; upper-to-lower flag resolution with star skip; regions add NPC restrictions | Mostly automatable data; behavioral tests required |
| Events | Highest qualifying page, map interpreter, autorun and per-event parallel interpreters; executeCommand at rpg_objects.js:8923 | Focused command VM |
| Dialogue | 101/401 blocks, 102 choices, YEP escapes/name boxes, SRD translations | Reuse text/choices; recreate rendering and control flow |
| Cutscenes | Position commands, move routes, transparency, balloons, pictures, waits, camera command, weather/audio | Mixed conversion and native adapters |
| Progression | Stamp item 1, variable 1 “stemp,” switch/self-switch gating, six-stamp objective and ending flow | Preserve IDs and both representations until equivalence proven |
| Inventory | Stamp and QuestList; HUD directly reads Stamp item count | Small native inventory/HUD; no generic RPG inventory needed |
| Minigames | Map 7 picture/QTE and rock-paper-scissors; Map 8 timer/projectile/enemy-coordinate logic | Highest behavioral risk; native controllers or faithful VM |
| Combat | No skills, enemies, troops, equipment, states, or animations in database; no command 301 | No MV battle port required; minigame “enemies” are map events |
| Common events | CommonEvents.json contains one unnamed terminator-only event; no command 117 in map lists | Preserve structural support if useful, not a current workload |
| State | MV switches, variables, self-switches, party inventory, timer, screen/pictures, map/event state | Engine-independent schema needed |
| Menus | YEP menu configuration plus Hide_main_char, CustomMenu, OptionExit; status/gold hidden; Exit Menu added | Recreate actual small menu, not default MV menu |
| Input | MV keyboard/gamepad mappings; mouse/touch listeners; ALOE virtual controls and visibility commands | Godot InputMap/Control or Phaser input adapters |
| Assets/rendering | Pixi sprites/tile renderer, OrangeOverlay ground/foreground, pixel filtering patches, pictures/HUD | Images reusable subject to rights; renderer code replaced |
| Audio | MV AudioManager/WebAudio; paired codecs; volume/pitch/pan and BGM continuity | Native audio adapter with matching semantics |
| Persistence | DataManager/JsonEx/LZString/StorageManager; options persisted through ConfigManager | New save schema; optional legacy importer |
| Localization | Translations.json: 159 message keys, 29 command keys, empty terms, two custom-language groups; EN/Romanian/Russian | Preserve full source-string lookup initially |
| Tooling | SRD SuperTools/HUD/Translation editor utilities; Python data extraction; Godot MCP | Retain source data workflows, replace runtime editor dependencies |

### Interpreter workload

Page triggers: **138 action, 25 player-touch, 1 autorun, 9 parallel**. No event-touch pages were found. Page conditions include 15 switch1 flags and 10 self-switch flags; no variable/item/actor page-condition flags were active. Conditional branches still use variables, switches, self-switches, button state, item possession and timer.

Observed event codes and counts, including structural terminators/continuations:

```
0:322 101:183 102:27 108:119 111:55 112:1 113:1
121:22 122:40 123:30 124:3 126:8 201:66 203:16
205:5 211:2 213:11 230:2 231:5 232:2 235:18
236:1 241:1 242:1 250:12 251:1 353:2 356:12
401:318 402:89 404:27 411:4 412:55 413:1 505:31
```

There are **36 distinct codes**, including metadata and continuation codes. Do not estimate complexity by treating each as an equally costly function. Branch nesting, asynchronous waits and event lifecycle are shared infrastructure.

No map commands 355/655 (arbitrary script), branch type 12 (script condition), or battle processing were found. This strongly favors a bounded interpreter. It does **not** mean there is no JavaScript evaluation: HUD and plugin parameter formulas depend on MV objects.

Command 122 operands include random values and character coordinates (Map008 event 2). Those are necessary for minigame logic. Forced movement 205 must honor wait/skippable/repeat flags and nested route commands; 505 is a continuation, not a second movement execution. Page move routes include left/right steps; actual execution also depends on moveType/frequency.

### Custom gameplay examples

- `Map007.json`, event 2 (“taser QTE”): pictures 1–3, cursor variables 2/3, directional input conditions, one-frame picture moves and reward gating. A dialogue-only port cannot reproduce this.
- `Map007.json`, event 46: randomized rock-paper-scissors branches, repeated possible reward paths and an already-received page. Validate all outcomes and prevention of duplicate stamps.
- `Map007.json`, event 5: Koi Koi dialogue and `ZoomOut 2 30`; associated map interactions need an end-to-end trace before labeling the entire minigame complete.
- `Map008.json`: event 1 starts a 20-second timer and resets positions; event 2 “fireball” reads character coordinates and moves; events 3–8 are kyriu slow/medium/fast actors with gated pages; event 9 checks win/loss and awards a stamp. This is a projectile/target minigame, not the built-in battle system.
- `Map012.json`, event 1: shows picture `!ground13`, hides virtual controls. Map013 shows `screen new` and “Thank You!”.
- `Map001.json`, event 16 uses `AIVISIBILE FALSE`; GALV implements `AIVISIBLE` (`GALV_ActionIndicators.js:94`). This appears to be a misspelled/no-op source command. Decide whether to preserve observed behavior or fix intent later.

## 4. Dependency Analysis

### Active plugin inventory

Activation order is defined by `legacy/js/plugins.js`, not simply directory presence. Nine separator entries are also enabled. All 21 substantive registrations are enabled.

| Plugin | Dependency / actual purpose | Port disposition |
|---|---|---|
| MadeWithMv | Scene_Boot/Scene_Splash/title and ImageManager | Native splash/title if desired/required |
| Change Tile Size | Game_Map, vehicles, ImageManager, boot | Configure 32-pixel grid; audit sheet dimensions independently |
| GALV_ActionIndicators | Game_Player, map refresh, Sprite_ActionIcon, interpreter plugin commands | Native interaction indicator |
| SRD_CameraCore | Game_Map/Screen, spritesets, Pixi, wait modes | Camera2D or Phaser camera + picture-coordinate policy |
| SRD_AutoCamera | CameraCore-related screen/region behavior | Port only configured/used behavior; region fields largely empty |
| OrangeOverlay | DataManager new-game hook, map notes, spritesets, Pixi blend modes | Native ground/foreground with startup switches |
| FixPixel | Replaces ImageManager.loadBitmap, forces smooth=false | Nearest sampling/import settings |
| TDDP_PixelPerfect | ConfigManager/options and pixel display behavior | Native scaling policy |
| ALOE_VirtualButtons | Input, TouchInput, Game_Player, scenes, choices, message windows | Native virtual buttons; match hide/show lifecycle |
| YEP_CoreEngine | Broad MV prototype changes, display and engine fixes | Behavior inventory, not wholesale translation |
| YEP_X_CoreUpdatesOpt | Broad MV/Pixi update and manager hooks | Do not transplant scheduler optimizations blindly |
| YEP_MessageCore | Game_Message, Window_Message/NameBox, escape processing | Explicit text token parser and native dialogue |
| YEP_MainMenuManager | Window_MenuCommand and Scene_Menu, formula parameters | Small declarative menu |
| YEP_RegionRestrictions | Game_CharacterBase/Event/Player passage | Region 1 restricts events; player restriction is 0 |
| Hide_main_char | Actually replaces menu creation; suppresses status | Preserve menu outcome; filename is misleading |
| CustomMenu | Centers commands, hides status/gold, adds Exit Menu | Native menu layout |
| OptionExit | Options handler, overrides processOk | Native back action and typed option controls |
| SRD_SuperToolsEngine | NW.js/editor utilities, database/windows hooks | Development tool, not a required runtime recreation |
| SRD_HUDMaker | SRD infrastructure, sprites, evaluated expressions | One native stamp-count label |
| SRD_TranslationEngine | Game_Message, command windows, ConfigManager, editor | Localized strings/options with fallback |
| SRD_FullscreenToggleOption | ConfigManager and Window_Options | Native display preference; browser gesture constraints |

Unregistered files: `CustomLogo.js`, `HideMobileControll.js`, `HIME_HidenChoiceConditions.js`, `MultiTochDisable.js`. They are not activated by the inspected manifest; do not include their advertised features in required scope without evidence of another loader.

`ALOE_VirtualButtons.js:1490` accepts both MobileUI and VirtualButtons case-insensitively, so Map012's MobileUI command is supported by the registered plugin, not evidence of a missing plugin.

`MapHUD.json` has one text widget whose expression reads `$gameParty.numItems($dataItems[1])`. `BattleHUD.json` is empty. `DataEX.json` and `Notes.json` contain empty groups; `Windows.json` stores menu layout coordinates. These are not a hidden battle/quest subsystem.

### Coupling and reuse boundary

Reusable: original map/event JSON, dialogue, translation mappings, numerical flags, art/audio subject to rights, gameplay specifications, portions of existing Python tooling and Godot visuals.

Not directly reusable in either new runtime: MV Window/Scene/Sprite subclasses, prototype aliases, $game*/$data* globals, JsonEx object restoration, Pixi-specific display patches, NW.js authoring windows. Phaser sharing JavaScript syntax does not supply these APIs.

No independent network service, external account integration or backend requirement was identified in the inspected game configuration. Exhaustive dynamic network behavior and exact provenance of modified core files remain **Unknown / Requires Verification**.

## 5. Godot 4 Porting Analysis

### Existing project: actual state

`gocon-game-rpg/project.godot` declares features 4.7 and GL Compatibility, viewport 816×624, nearest texture filtering, Main.tscn startup, and autoloads GameData, GameState, AudioManager, DialogueManager, SceneManager. It enables the godot-mcp editor plugin. This is the actual path; historical references to `godot_project/` are stale.

| Component | Verified implementation |
|---|---|
| Main.tscn | Root Node only; no attached main script or level instance |
| main.gd, game_data.gd, audio_manager.gd, scene_manager.gd | 11-line template stubs |
| events/event_runner.gd, ui/menu/pause_menu.gd | 11-line template stubs |
| GameState | Sparse switches/variables/self-switches, item counts, language field, keyboard action registration; no disk persistence |
| world/map.gd | Loads extracted map JSON, merges extra_collision, builds horizontal collision rectangles, spawns events and applies sprite offsets |
| actors/player/player.gd | Grid tween movement, RayCast2D collision, action/touch lookup; delegates to DialogueManager |
| events/event.gd:63 | Condition evaluation is only cond.is_empty(); conditional pages never qualify |
| autoload/dialogue_manager.gd:68 | Collects 401 text, flushes on other codes, displays all collected messages; ignores branches and choices |
| ui/dialogue/dialogue_box.gd | Substantial 411-line UI with skin, font, text presentation, sound and animation |
| world/levels/level01–13.tscn | Existing scene content; level06 references painted ground/foreground and player at (448,1312) |
| data/ | 13 maps, map_index, extra_collision, sprite_offsets; extracted DB/translation outputs claimed by docs are absent |
| display_manager.gd | Disabled/commented implementation, not an autoload |
| addons/psx_shader | Present addon/example; no shader/material references found in world scenes or Main.tscn search |

Therefore the current default entry scene does not itself load a playable level. No launch test was performed, and this report does not claim editor/runtime error-free status.

The old HANDOFF description of a working multi-command event runner is contradicted by current source. Treat the scaffold as useful movement/UI/map work, not “Phase 3 complete.”

### Recommended implementation

Use painted Sprite2D ground/foreground layers, y-sorted entities, Camera2D, CanvasLayer UI and a grid navigation model. Existing physical collision generation may be retained for editor visibility, but logical passage should govern movement so source/destination directional checks, dynamic occupancy, through flags and region rules are reproducible.

TileMapLayer is appropriate for collision editing/debugging or future actual tiled art. It is not necessary to redraw the painted maps. A general converter would split MV's flattened array into four tile planes plus shadow/region planes, map tile IDs to atlas coordinates, and reproduce autotile quadrants/animation rather than treating each ID as a whole image tile. Godot TileMapLayer represents one layer; multiple layers require multiple nodes. [Godot TileMapLayer documentation](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html).

The observed used tile flags are 16, 1536, 1551 and 3599. Their low directional bits are either fully open or fully blocked, supporting this project's boolean collision simplification. Higher bits still have meaning; do not generalize this shortcut to arbitrary MV projects. There are 78 region-1 cells, which restrict NPCs separately.

A compact interpreter should retain command code, parameters, indent and source location; dispatch commands to native services; track program counter, branch state, loops, event identity and waits. Refresh active pages on relevant state changes and cancel/restart parallel tasks according to MV behavior. Use a bounded per-frame execution budget to prevent tight event loops freezing the application.

Do not emit one independently running node per command. Event nodes should own presentation/position; the interpreter owns sequential control flow. Signals are suitable for dialogue completion, state changes, transfer completion and minigame results.

Use JSON for content during migration, optionally typed Resources for curated/native definitions later. Preserve source IDs and null/gap semantics. GDScript is preferred over C# for this project because browser delivery is plausible and official Godot documentation currently states that Godot 4 C# projects cannot export to web. [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

### Save design

MV `rpg_managers.js:370` serializes makeSaveContents through JsonEx; `:430` defines save contents; StorageManager at `:673` and `:722` compresses via LZString to local files or web storage. These are object graphs, not plain portable gameplay JSON.

The configured YEP Save menu entry is hidden/disabled, no command 352 occurs in map lists, and no save-file fixtures were found in the recursive file inventory. Existing user saves and practical access to saving are **Unknown / Requires Verification**. Continue support in the base title code does not prove users have saves.

Implement versioned plain-data saves containing switches, variables, self-switches, inventory, map/player coordinates and facing, relevant timers/minigame state, plus separate settings. Initially allow saves only at stable checkpoints. Arbitrary mid-interpreter saves require serializing waits, routes, picture state and interpreter stacks.

An optional offline legacy importer can decode LZString/JsonEx into a controlled intermediate schema and copy supported fields. Do not instantiate arbitrary saved classes or promise byte-for-byte compatibility. Obtain actual saves before budgeting this as required work.

## 6. Godot MCP Assessment

### Verified in this session

- `get_status({})` completed successfully.
- It reported **editor bridge connected (Godot 4.7.2)**, runtime bridge not running/enabled, and **386 tools in 30 categories**, including 235 file-path tools.
- Reported root: `C:/Users/alexa/Downloads/LUDUM DARE 60/Cassette/Cassette-LD60`.
- `read_project_config({})` successfully returned the unrelated “Cassete” project with scenes/game.tscn as its entry.
- This proves server/file-read functionality, and reports an editor connection. It does not verify scene creation, runtime input, screenshot capture or this RPG project's editor connection.
- No mutation, project switch, editor launch, runtime autoload change or build was requested.

### Capabilities documented by available tool schemas

| Operation | Documented tools | Verification level |
|---|---|---|
| Inspect projects/scenes/scripts | list_project_files, list_projects, list_scenes, read_scene, read_script, read_script_structure | Schemas inspected; RPG operations not executed |
| Create scene/node graph | create_scene, add_node, attach_script, connect_signal | Documented; mutation deliberately untested |
| Create/edit scripts/resources | write_script, write_resource, create_animation, set_keyframe | Documented; not executed |
| Tile resources | create_tileset, add_tileset_source | Documented; no verified bulk MV tile import |
| Configure input/audio/UI | write_input_action, add_input_binding, create_audio_bus_layout, set_stylebox | Documented; not executed |
| Validation | validate_project, validate_script | Advertised schemas; not a demonstrated full engine compile or gameplay test |
| Editor/runtime interaction | Status advertises editor ClassDB/live control and runtime bridge | Editor connection reported; runtime unavailable |

The existing RPG project has both `addons/godot-mcp/plugin.gd` and `runtime_bridge.gd`, but its project.godot does not register the runtime bridge autoload. Plugin files alone do not prove an active bridge.

After migration approval, bind the server to the correct project and verify status plus a known scene read before editing. Rebinding is a prerequisite, not a reason to abandon Godot.

**MCP advantage:** reduced editor setup, repeatable scene inspection, scripted resource creation and iterative diagnostics within the user's existing workflow. **MCP limitation:** it does not infer event semantics, resolve licensing, reconstruct minigames, translate plugin APIs, or validate behavioral parity automatically. Bulk extraction/asset manifests belong in deterministic conversion tools; MCP is an orchestration and inspection aid. No percentage productivity saving is claimed.

## 7. Phaser Porting Analysis

Phaser can implement this game's small 2D world with painted image layers, sprite sheets, cameras, input and a custom event scheduler. It is browser-oriented, uses JavaScript/TypeScript, and relies on third-party tools for desktop/native-mobile packaging. [Official Phaser overview](https://docs.phaser.io/phaser/getting-started/what-is-phaser).

| Area | Practical approach for this game |
|---|---|
| Code reuse | Reuse JSON, event definitions and selected pure algorithms; wrap or rewrite MV-dependent logic |
| Plugins | Reimplement selected behavior; Phaser has no Game_Interpreter, Window_Message or MV Game_Map |
| Maps | Ground/foreground images + collision array; optional generated Phaser tile layers for debug/editing |
| Scenes | Boot/load, title, world and UI scenes; scene transitions must not destroy global quest state |
| Events | Same bounded VM as Godot, but TypeScript; preserve asynchronous waits, branches and page lifecycle |
| Dialogue/UI | Phaser objects or DOM overlay; explicitly parse MV escapes and multilingual text; choose one consistent focus/layout policy |
| Sprites | Extract frames using dimensions and prefix conventions; preserve feet anchors and ordering |
| Movement | Custom grid stepping and occupancy; Arcade Physics alone will not reproduce MV passage |
| Audio | Phaser sound layer with codec selection, gesture unlocking, loop/pitch/volume validation |
| State | Typed plain objects, item/switch/self-switch storage and change notifications |
| Saves | Versioned JSON in browser storage/IndexedDB; desktop adapter if packaged; storage eviction/private-mode tests |
| Web | Natural fit for the existing browser workflow and DOM integration; benchmark startup and texture memory |
| Desktop/mobile | Wrapper lifecycle, platform toolchains, persistence paths, input/resume/audio behavior add work |

Phaser Scenes have their own lifecycle and scene-level services; they are not drop-in replacements for MV scenes. [Phaser scene documentation](https://docs.phaser.io/phaser/concepts/scenes).

A limited MV command interpreter in TypeScript is realistic because no arbitrary map-script commands were observed. A full plugin-compatible implementation would need MV objects, windows, message parsing, managers, Pixi-facing APIs, prototype behavior and save reconstruction. That approaches maintaining a second RPG Maker runtime.

Retaining MV model/interpreter code with a Phaser rendering facade is technically conceivable but has high coupling and rights-review costs. Running both rendering runtimes or embedding the original game in a wrapper preserves much of the original dependency stack; this is packaging/containment, not a clean engine migration.

Choose Phaser if browser embedding and JavaScript ownership become decisive product requirements. Shared language alone is insufficient to prefer it.

## 8. Godot vs. Phaser Comparison

| Criterion | Godot 4 | Phaser |
|---|---|---|
| Migration difficulty | Moderate-high; existing scaffold helps, interpreter still missing | Moderate-high; same semantic work plus new scaffold |
| Existing code reuse | Python/data/assets and selected current GDScript; MV JS rewritten | Same data/assets; some algorithm reuse, very little unchanged plugin reuse |
| Asset compatibility | PNG/OGG/font reuse with import settings; audit unusual sheets | PNG/OGG/M4A/font reuse with loader/browser testing |
| RPG Maker event conversion | Focused GDScript VM for 36 observed code types | Focused TypeScript VM; syntax advantage does not solve scheduling |
| Automation potential | High data/scene generation; behavioral conversion partial | High JSON/manifests; behavioral conversion partial |
| AI-assisted development | Existing scenes and MCP fit user's workflow | Text-code/tooling workflow; no verified Phaser integration in this task |
| Godot MCP advantage | Real but currently bound to another project | No direct benefit |
| Performance | Small maps likely manageable; no benchmark evidence | Small maps likely manageable; no benchmark evidence |
| Desktop support | Integrated export workflow | Third-party wrapper/build workflow |
| Browser support | Compatibility renderer/WebAssembly; browser-specific testing | Primary design target |
| Mobile support | Native exports plus web, platform setup still required | Mobile browsers plus third-party native packaging |
| Maintenance complexity | Native services + bounded VM; clear data boundary | Typed services + bounded VM; wrapper maintenance if desktop |
| Future scalability | Good fit for editor-driven expansion and richer native scenes | Good fit for expanded 2D/browser integrations |
| Development effort | Lower expected cost here because of existing work and user workflow | Competitive for browser-first redesign, not automatically cheaper |
| Fidelity risk | Timing, movement, picture coordinates and dialogue semantics | Same fidelity risks; MV/Pixi patches still incompatible |
| Existing port value | Movement, map collision and custom dialogue UI can be retained after audit | Mostly data/assets/tooling transfer; Godot UI investment lost |

Performance comparisons are architectural expectations, not measured results. A 60×60 maximum map is not intrinsically demanding; active event loops, image lifetime, fonts and platform audio deserve measurement before engine performance drives the decision.

Alternative choices:

1. **Complete native Godot rewrite:** cleanest eventual authoring model; manually translating all 173 pages increases regression risk.
2. **Godot native services + game-specific VM:** recommended; retains content while replacing platform dependencies.
3. **Phaser + game-specific VM:** sensible browser-first alternative.
4. **Universal MV compatibility layer:** disproportionate scope for 13 maps; not recommended.
5. **Retain MV and modernize selectively:** best near-term release economics; preserve plugin order and test upgrades separately.
6. **Wrap existing MV web game:** fastest packaging approach if rights and runtime compatibility allow; no inherent modernization of gameplay architecture.

## 9. Conversion and Automation Opportunities

“Complete” below means deterministic structural conversion after input validation, not automatic proof of gameplay equivalence. None of these proposed changes was implemented or executed.

| Opportunity | Inputs → outputs | Method and dependencies | Automation / limits | MCP role |
|---|---|---|---|---|
| Database conversion | MV database JSON → ID-keyed JSON/Resources | Preserve IDs, defaults, notes and needed fields; existing extract_db.py is a starting point | Complete for validated fields; pruning may lose future data | Inspect/load generated resources |
| Maps/tile IDs | Map arrays + Tilesets flags → grid, region/shadow planes, atlas mapping | Decode index (z*h+y)*w+x; map A-tile quadrants if visible tiles needed | Complete structural split; passage/terrain behavior needs tests | Create TileSet/atlas resources; no verified bulk importer |
| Scene generation | Map metadata + asset manifest → 13 scenes | Template layers/entities/camera with stable source IDs | Mostly complete scaffolding; art offsets and visual parity partial | create_scene/add_node/attach_script documented |
| Event representation | Event pages/routes → normalized command IR | Retain code, indent, parameters and provenance | Complete; existing 13 map command lists match source | Inspect scripts/nodes |
| Common commands | Observed opcode corpus → VM dispatch and support matrix | Implement waits, branches, loops, choices and state ops once | Partial behavior automation; do not silently skip unsupported codes | Write/inspect scripts after approval |
| Paths/references | Original filenames and renamed Godot assets → manifest | Exact case-aware mapping, existence checks, collision detection | Mostly complete; artistic variants require choices | Resource inspection |
| Sprite/animation recreation | Sheets, page graphics, routes → frames/animation definitions | Derive dimensions; !/$ conventions; preserve anchors and step cadence | Partial; unusual assets need metadata | Animation/resource tools |
| UI/localization | Message/choice/translation/HUD data → native dialogue/options/HUD | Source-text lookup first; later stable localization keys with aliases | Partial; escape tokens, fonts and layout need human review | Native Control scene scaffolding |
| Gameplay generation | Commands + minigame rules → services/controllers | Explicit adapters for picture QTE, timer and projectile targets | Partial; arbitrary JS-to-GDScript translation impractical | Boilerplate/inspection, not semantic conversion |
| Unsupported detection | Full event corpus + plugin manifest → compatibility diagnostics | Scan nested routes, parameter variants, eval-bearing fields and unknown commands | High static coverage; dynamic plugin behavior cannot be fully inferred | Diagnostics aggregation |
| Validation | Original/generated data + later recorded traces → parity results | Structural hashes, branch fixtures, state snapshots, screenshots, movement graph comparison | Structural complete; behavioral partial | Editor diagnostics/runtime automation only after correct binding |

Existing tools:

- `tools/rmmv_common.py:27` writes to gocon-game-rpg/data, despite obsolete comments.
- `extract_maps.py` preserves event lists, splits layers, derives boolean collision and overlay paths. It assumes the first tileset and uses one direction bit; valid only after the current flag-pattern check and continued scope constraints.
- `extract_translations.py` preserves message/command/custom mappings; verify escape handling and empty/missing translation fallback.
- `extract_db.py` selects fields; review rather than assuming it is lossless.
- `bake_tileset.py`, `preview_map.py` are existing art/debug utilities; unnecessary for rendering painted maps unless used as validation aids.
- The false foreground initialization comment at `extract_maps.py:174` must be corrected in a later approved implementation. Output gate metadata alone is not wrong; missing native startup initialization would be wrong.

Validation should compare all four directional passages, map boundaries, event occupancy and region restrictions—not just the boolean collision arrays. Compare translations by entire source message blocks, preserving whitespace and escape sequences. Verify exported filename case on a case-sensitive target.

## 10. Compatibility and Risk Matrix

| Issue | Evidence/status | Severity | Mitigation |
|---|---|---|---|
| MCP points to Cassette | Confirmed by two read-only calls | Critical operational prerequisite | Rebind and verify before any migration mutation |
| Existing port lacks core execution | Confirmed stubs and empty Main.tscn | High | Re-estimate from actual source; build vertical slice |
| Dialogue flattens all branches | Confirmed dialogue_manager.gd:68 | High | Replace with interpreter-controlled message calls |
| Conditional pages rejected | Confirmed event.gd:63 | High | Implement page conditions and refresh notifications |
| Overlay startup assumption wrong | Confirmed OrangeOverlay.js:214–232 | High | Initialize switches 1–4 consistently; validate tagged layers |
| Parallel timing/minigames | Confirmed nine parallel pages, picture QTE and timed projectile logic | High | Fixed semantic tick policy, explicit waits and replay fixtures |
| Region/through/occupancy mismatch | Region 1 used; current simplified Godot collision lacks full MV semantics | High | Authoritative grid rules and dynamic actor state |
| Asset geometry variation | !Other2 is 576×768; koi_projectile is 48×48; native code fixes FRAME=48 | High visual risk | Per-sheet layout metadata; inspect actual referenced frames |
| Map art != grid dimensions | Confirmed PNG headers | Medium-high | Preserve offsets and viewport reference captures |
| Plugin API dependence | Confirmed broad prototype hooks | High | Native behavior adapters; avoid blanket transpilation |
| Legacy save incompatibility | Format confirmed; actual user-save requirement unknown | Medium, high if mandatory | Versioned saves; fixture-based optional importer |
| Asset/plugin rights | Provenance and licenses not supplied for every asset/plugin | Potential release blocker | Rights manifest; identify stock/commissioned/DLC/fan assets; replace or obtain permission |
| Translation fidelity | Tables present, port output absent; YEP formatting used | Medium-high | EN/RU/RO branch tests, glyph/line-wrap checks |
| Source typo | AIVISIBILE versus implemented AIVISIBLE | Medium | Record baseline no-op; approve intent change separately |
| Options semantics | OptionExit uses boolean negation for non-exit values; later plugin overrides may alter result | Potential medium | Verify effective chain and numeric volume controls |
| Core modifications | No pristine comparison baseline | Unknown | Compare against licensed matching MV runtime later |
| GPU/shader behavior | Original Pixi blend/camera behavior; unrelated PSX addon present | Medium | Match required 2D effects; exclude unused addon from shipping scope after review |
| Platform persistence/audio | Not tested | Medium-high | Browser gesture, storage, suspend/resume and device tests |
| Performance | No measured problem or benchmark | Unknown | Profile representative maps/minigames before optimization |

Rights are **not cleared by technical importability**. The official MV EULA page inspected contains restrictions on company materials in third-party tools; applicable amendments, permissions, asset-specific terms and ownership must be verified for this project's exact assets. Do not infer that every PNG is forbidden or that every purchased asset is portable. Engine code reuse and plugin licenses need their own review. [Official RPG Maker EULA, MV section](https://www.rpgmakerweb.com/eula).

## 11. Proposed Migration Architecture

Keep the existing folder layout where useful; the following is a responsibility plan, not a restructuring performed by this analysis.

- **GameData:** immutable validated map/database/localization data, original IDs, explicit asset manifest.
- **GameState:** switches, variables, self-switches, items, player location, progression; change notifications.
- **SceneManager:** title/new-game, map transitions, load lifecycle and input locks.
- **EventScheduler/EventRunner:** foreground interpreter plus per-event parallel tasks; cancellation, waits, branch/loop state, command-budget guard.
- **GameMap/GameEvent:** world presentation, active page, sprite, grid position, movement route, dynamic collision and indicators.
- **DialogueManager:** message/choice presentation only; no control-flow interpretation inside the view.
- **Picture/Camera service:** picture IDs, blend modes, transforms and camera zoom with source-compatible coordinates.
- **AudioManager:** BGM continuity and SE volume/pitch/pan.
- **Minigame controllers:** optional native QTE/projectile implementations with explicit start/result contracts and original reward IDs.
- **SaveService/Settings:** schema versioning and platform-independent state with platform storage adapters.

Prefer one ownership model for the minigames: either execute their original event pages faithfully or replace the entire minigame with a native controller and documented entry/exit state. Do not run both simultaneously.

Retain the original as the content source of truth initially. Store deliberate gameplay fixes separately from parity corrections. No need for battle actors, equipment trees, damage formulas, or a generalized quest framework in the first release.

## 12. Step-by-Step Migration Roadmap

All phases below require a subsequent implementation authorization. Days are person-days, not calendar promises.

| Phase | Objectives and dependencies | Deliverables / automation | Main risks | Acceptance criteria | Base effort |
|---|---|---|---|---|---:|
| A — Preparation | Freeze reference, obtain backup, confirm platforms/rights; audit existing scaffold and correct MCP target | Source/asset manifest, support matrix, chosen Godot version, architecture and baseline capture plan; automate inventories | Stale docs, wrong project target, unavailable rights/reference saves | Correct MCP project read verified; all inputs accounted for; exclusions explicit | 3–5 days |
| B — Minimal prototype | Depends on A; use Map006 intro plus representative NPC/door/reward interaction | Boot to map, grid movement, camera, foreground, native dialogue and one transfer; reuse scene/data scaffold | Empty entry scene, art offsets, page condition mistakes | Start at (14,41); walls/foreground match; dialogue blocks movement; choice changes state; transfer works once | 4–7 days |
| C — Core systems | Depends on B; implement used VM semantics and services | Branches/loops/pages/parallel scheduler, movement routes, pictures, timers, audio, localization, menu/HUD, checkpoint saves | Timing deadlocks, duplicate rewards, input focus | All used opcode/parameter families have defined behavior; unsupported commands fail visibly; QTE and projectile spike pass | 14–26 days |
| D — Content migration | Depends on stable C and asset manifest | All 13 maps, events, translations, minigames, endings; deterministic regeneration where suitable | Inconsistent renamed assets; source quirks; hidden branches | Six-stamp progression and each ending reachable; all reward branches and translations covered; no missing refs | 8–16 days |
| E — Validation | Depends on D; original trace/reference access | Structural comparisons, movement graphs, state snapshots, screenshot/audio/input checks and full playthroughs | Source bugs mistaken for target bugs; timing variation | No progression blockers, repeat-reward exploits or unexplained branch divergence; reset/transfer/load edge cases pass | 9–18 days |
| F — Optimization/export | Depends on E; target tooling/certificates | Profiled Windows/web builds, trimmed resources, export notes; mobile only if scoped | Browser audio/storage, case sensitivity, addon bloat | Clean install/playthrough; reload persistence; acceptable loading/memory/frame budget on named devices | 5–9 days |

Prototype selection matters: Map006 validates the entry and largest environment, but a beautiful walkable map alone is insufficient. Before committing to full migration, spike Map007 event 2 and Map008 timer/projectile behavior; these determine interpreter feasibility.

Suggested validation cases:

1. New game enables required overlay switches; ground-only maps do not display untagged foregrounds.
2. Highest valid page wins after every switch/self-switch change, including leaving and revisiting a map.
3. Player touch occurs on the correct side of collision; NPC region-1 restriction does not incorrectly block the player.
4. Choice cancellation/default indices, nested branches and loops yield the same state.
5. Random rock-paper-scissors fixtures cover tie/loss/win and prevent repeated rewards.
6. QTE at low/high display refresh rates has the intended simulation timing and wrong-button handling.
7. Map008 win, timeout, reset, repeated entry and projectile waits remain consistent.
8. Stamp variable and item count remain synchronized where the source expects it; final transition conditions are correct.
9. EN/RU/RO dialogue, name escapes, choices, fonts and options render without missing glyphs.
10. Transfer during active tasks cancels old-map work; no callbacks modify freed event nodes.
11. Save/load at approved checkpoints restores inventory, pages, map and settings; malformed/old schema handling is explicit.
12. Browser gesture audio, focus loss, virtual controls, gamepad navigation and persistent storage are exercised.

Export recommendation: first Windows and browser with Compatibility renderer/GDScript; use a single-threaded web baseline unless profiling justifies threads. Godot's official web guidance documents WebGL 2.0/WebAssembly requirements, single-thread support and cross-origin isolation requirements for threaded exports. Native Android/iOS require a separate device/toolchain scope. [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## 13. Effort Assessment

| Approach | Base effort | With uncertainty allowance | Interpretation |
|---|---:|---:|---|
| Recommended Godot + bounded VM | 43–81 days | 54–109 days | Includes scaffold audit, 13 maps, minigames, localization, basic saves, Windows/web QA |
| Phaser + bounded VM | 48–90 days | 60–122 days | Similar semantics, less existing UI/runtime reuse; browser-first scope can narrow packaging work |
| Fully native Godot content rewrite | 50–95 days | 63–128 days | More manual reconstruction of pages/branches; possible long-term authoring benefits |
| Selective MV modernization | 8–20 days | 10–27 days | Bounded fixes, compatibility testing and packaging; not a redesign or full framework upgrade |
| Universal MV/plugin compatibility | Not responsibly estimated here | Separate discovery project | Far beyond this game's required feature subset |

These are engineering estimates derived from the observed scope, not benchmarked productivity data. Contingency is roughly 25–35%, rounded. One person at five productive days/week implies roughly 11–22 weeks for the recommended contingency range; review/asset/legal waits can extend calendar time.

Assumptions: an experienced developer; rapid product decisions; original can be played as reference later; no replacement-art production; no new combat/quests; three existing languages; checkpoint saves rather than arbitrary suspended-interpreter saves; one primary desktop OS and a specified browser/device matrix. AI/MCP support is assumed to help routine work, but no automatic reduction is deducted.

Optional additions: legacy save importer 3–10 days after fixtures; native mobile packaging/device QA 5–12 days per platform; extra desktop platform QA/signing 2–5 days each. New artwork/licensing remediation, content rewriting, extensive accessibility redesign and universal plugin support are excluded. Re-estimate after Phase B and the minigame spike; current confidence is medium for structural scope and low-to-medium for timing parity.

## 14. Final Recommendation

For long-term engine ownership and the user's existing Godot workflow, choose **Godot 4/GDScript with native services and a narrowly scoped MV-event interpreter**. Keep painted map layers, preserve IDs and command data, and audit the existing movement/dialogue scaffold rather than restarting automatically.

The MCP workflow strengthens this recommendation through available editor/file tooling, but the current connection must be corrected before use. MCP does not make this an automated one-click port. The strongest technical reason the migration is feasible is the small, inspectable event-driven scope with no conventional battle subsystem and no arbitrary map-script commands.

Choose Phaser instead if browser integration becomes the dominant requirement and the team prefers owning a TypeScript runtime. Choose retained MV if releasing the existing experience soon matters more than changing engine. Do not port solely because modern engines are presumed faster: no performance evidence supports that motivation yet.

## 15. Recommended Next Actions

1. Approve an approach and target platform priorities; no migration implementation has been started by this analysis.
2. Resolve asset/plugin provenance and the need for importing existing user saves.
3. After approval, verify MCP against gocon-game-rpg and capture original gameplay reference traces.
4. Audit/reuse current map and dialogue visuals; implement a real entry flow and event/page semantics.
5. Test Map006 plus the Map007 QTE and Map008 timed projectile sequence before committing to full production.
6. Re-estimate from measured prototype parity and maintain a compatibility matrix covering every observed command and plugin feature.

### Remaining Unknown / Requires Verification

Exact installed MV editor version; unmarked core modifications versus pristine 1.6.1; actual original gameplay bugs and reachability; runtime stability of the existing Godot scenes; complete translation coverage and visual parity; full asset ownership/permissions; actual user saves; target device/browser matrix; performance measurements; Godot MCP creation/runtime behavior against this RPG project. These require follow-up evidence, not assumptions.

### Evidence reference guide

- Engine/runtime: `legacy/js/rpg_core.js:173,183`; `legacy/js/libs/pixi.js:8261`.
- Startup/load order: `legacy/index.html`, `legacy/js/main.js`, `legacy/js/plugins.js`.
- Passage/events: `legacy/js/rpg_objects.js:5911,6113,6391,8610,8871,8923`.
- Saves: `legacy/js/rpg_managers.js:370,430,673,722`.
- Inputs: `legacy/js/rpg_core.js:3002,3036,3689`.
- Overlay initialization: `legacy/js/plugins/OrangeOverlay.js:214`.
- Virtual commands: `legacy/js/plugins/ALOE_VirtualButtons.js:1490`.
- Action indicator typo comparison: `legacy/data/Map001.json` event 16 and `legacy/js/plugins/GALV_ActionIndicators.js:94`.
- Original content: `legacy/data/Map001.json` through `Map013.json`, `System.json`, `Items.json`, `Translations.json`, `MapHUD.json`.
- Port gaps: `gocon-game-rpg/Main.tscn`, `events/event_runner.gd`, `events/event.gd:63`, `autoload/dialogue_manager.gd:68`.
- Extraction assumptions: `tools/extract_maps.py:174`, `tools/rmmv_common.py:27`.
- External platform/rights claims: official links inline above, consulted 2026-11-03. Local source and direct tool responses take precedence over historical workspace documentation for implementation status.

