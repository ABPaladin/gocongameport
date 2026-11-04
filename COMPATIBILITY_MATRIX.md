# Compatibility matrix

Source census: **35 distinct command IDs**, 13 maps, 156 events, 173 pages.
The feasibility report's count of 36 was incorrect; the preserved source lists
contain 35 including structural/continuation IDs. Runtime suite currently has
215 assertions. Implementation, test coverage and visual parity are distinct.

| Codes | Implemented behavior | Automated evidence | Remaining parity checks |
|---|---|---|---|
| 0,108,401,404,412,505 | Structural/comment/continuation handling; text consumed by 101 | Actual source lists execute | Exhaustive isolated structural variants |
| 101 | Full-message translation, portraits, speaker escape, async ticket | Intro/trivia/QTE/RPS/ending execute; Web intro renders | Every translated message layout |
| 102,402 | Default/cancel-aware choices and selected branch only | Synthetic branching and all trivia outcomes | Every cancel/default UI variant |
| 111,411 | Switch, variable comparisons, self-switch, timer, item, button | Branch tests, all reward paths and minigames | Every comparison operand isolated |
| 112,113,413 | Nested-loop scanning, break, bounded execution | Synthetic loop/break and actual projectile loop | None known for observed lists |
| 121 | Inclusive switch ranges and page refresh | Startup, projectile, event lifecycle | Full physical map tour |
| 122 | Constant/variable/random/character operands and arithmetic | RPS seeds, QTE cursor, projectile coordinates | All arithmetic variants isolated |
| 123 | Source-map/event self-switch identity retained after transfer | Reward gating, intro, continuation test | None known for observed lists |
| 124 | Fixed-60Hz timer start/stop | 1200-tick timeout/reset and win | Real-time low-FPS measurements |
| 126 | Add/remove items by constant/variable, 0–99 clamp | Six reward paths, duplicate gating | None known for observed reward lists |
| 201 | Direct/variable transfer, facing, black/white/no fade | Deferred continuation and ending chain | Visual fade timing against original |
| 203 | Direct/variable location and swap | Actual projectile start/reset/hits | Swap variant fixture |
| 205,505 | Forced routes, saved autonomous route, waits | Intro and projectile movement; synthetic restore | All timing against original |
| 211 | Player transparency | Ending assertion | Ending screenshot comparison |
| 213 | Balloon sheet and optional wait | Handler + source asset; runtime intro | Every balloon icon/timing |
| 230 | Tick wait | QTE, synthetic VM tests | Low-FPS timing comparison |
| 231,232,235 | Picture IDs, origin, constant/variable position, scale, opacity, movement | QTE and ending; explicit move/erase test | Every picture blend visual comparison |
| 236 | Weather type/power and duration | Handler; map source retained | Visual particle parity is approximate |
| 241,242 | BGM, parameter volume/pitch, fade | Resources load; browser audio test separate | Listening and fade quality review |
| 250,251 | Multiple SE voices and stop | Reward/source lists and resource loading | Listening review |
| 353 | Game Over cancels gameplay and exposes restart/title | Explicit runtime assertion | Exported UI screenshot |
| 356 | Project-specific commands below; unknowns diagnose | QTE/intro/ending/transfer | All commands verified statically |

Unsupported opcodes/conditions/plugin commands terminate the task with a diagnostic
containing map, event, page and command index. A declaration in SUPPORTED alone
does not constitute gameplay parity. Observed movement route codes:
0,2,3,4,15,17,18,29,31. These are implemented; extra simple route variants are
available but not a claim of universal RPG Maker compatibility.

## Plugin features

| Source feature | Replacement | Evidence / limits |
|---|---|---|
| Kaus overlays and QuickStart | Native-size ground/foreground, startup switches 1–4 | Source flags + matched Map006 screenshot; original startup corrected |
| Change Tile Size | 32px logical grid | All map planes preserved |
| SRD CameraCore | 2× default, reciprocal ZoomOut with duration | Transfer continuation zoom test; settled intro framing matches |
| YEP Region Restrictions | Region 1 NPC restriction | Directional, star-layer, occupancy and region fixtures pass |
| YEP MessageCore | Speaker escape and face display with original skin/font | Intro screenshot; exact skin composition remains approximate |
| SRD TranslationEngine | Full-message and choice-text lookup | Source dictionaries identical; English/Romanian/Russian intro screenshots reviewed |
| SRD HUDMaker | Stamp count at original placement/font | Intro screenshot; timer shown alongside |
| Action indicators | actionIcon comments → IconSet indicator | Implemented, no full-map screenshot tour |
| VirtualButtons/MobileUI | Conditional touch controls, ending hide | State assertions; device testing pending |
| AIVISIBILE FALSE | Intentional no-op matching misspelled source | Source spelling preserved |
| Custom menus/fullscreen | Native title/pause/settings/inventory UI | Web keyboard/menu/save/Continue exercised; layout is intentionally native |
| RPG Maker save serializer | Versioned Godot checkpoint | File/corruption tests + browser persistence; no MV save importer |
| Other inactive/unused RPG systems | Not ported | No combat data or arbitrary script commands in observed content |

All authored audio commands use pan=0. Nonzero stereo-pan compatibility is not
implemented or claimed. QuestList (item 2) has no acquisition or effect commands
in the source maps; its count is represented without inventing a quest subsystem.
Weather and native menu styling are documented presentation differences.

## Known source behavior retained

Map008's hit test compares variable 7 to itself for Y; only the X comparison
constrains the hit. This appears erroneous, but changing it would change the
original game's difficulty. The interpreter preserves the list literally.
The original AIVISIBILE typo also remains unchanged.
