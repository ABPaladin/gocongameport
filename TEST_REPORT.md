# Test report — updated 2026-11-05

## Current results

| Check | Actual result |
|---|---|
| Python content suite | 5 tests PASS |
| Headless Godot runtime suite | 241 assertions PASS, zero engine errors |
| Godot editor import / script parse | PASS with MCP addon disabled in this project |
| Windows release export | Built with installed 4.7.2 templates |
| Windows exported startup | PASS, headless title startup for 120 frames |
| Web release export | Built, single-threaded GL Compatibility |
| Original MV browser startup | PASS in installed Edge |
| Exported Web gameplay smoke | Intro via keyboard, movement, pause, checkpoint, reload, Continue exercised |
| Web persistent storage | checkpoint.json confirmed in IndexedDB after saving |
| Web audio | Running AudioContext and measured nonzero output peak 0.686; no audible-listening claim |
| Browser diagnostics | No page/console errors in tested original/export sessions |
| legacy/ integrity | SHA256 manifest tests and git diff against baseline PASS |

## Automated behavior coverage

The runtime suite loads all 13 maps and tests:
directional source/destination passage, star layers, bounds even with through,
event/player occupancy, NPC region restriction; initial state and Map006 spawn;
branch exclusion, selected choices, loops/breaks and bounded infinite loops;
forced-route waiting/restoration, pictures, timer, translation lookup and page conditions;
actual intro movement/dialogue/page refresh; transfer continuation retaining original
self-switch identity; RPS seeded win/loss/tie paths and duplicate reward prevention;
projectile start, 20-second timeout/reset and win/reward transfer;
timed-input QTE success and locked reward page; checkpoint replacement/restoration,
missing/corrupt/unknown-version rejection and active-QTE save rejection.

The progression test continues a QTE-earned checkpoint through three actual trivia
events (wrong, correct and repeat outcomes), RPS and the projectile game, obtaining
six matching item/variable stamps and traversing Map004 → Map013 → Map012.
The final projectile progression test repeatedly activates the actual firing event
while targets move and source coordinate comparisons run; it does not inject
defeated-target flags. An earlier isolated win-result test deliberately uses flags.
Game Over is separately asserted.

These are accelerated, deterministic executions of source event lists. They are not
a continuous human navigation playthrough or proof of every visual/timing detail.
The accelerated suite disables real audio mixing and fades; separate browser audio
measurement proves nonzero real-time Web output after a user gesture.

Python validates original hashes, all map command lists and planes, full translation
dictionaries, manifest files, critical command/character assets, tile flag bounds,
and direct transfer destinations.

## Visual inspection

Original and exported Map006 screenshots were synchronized at the settled first
intro message: tile (14,39), zoom 2. World/player framing and painted-layer placement
match visually. Initial mismatched screenshots were taken at different interpolation
times and were not treated as evidence of a camera bug.
HUD placement, dialogue height/padding, speaker-box size and unsupported advance
glyph were corrected. The original arrow is now taken from the window skin.
The window pattern and name color remain approximate; native menu design differs.

The Web Continue screenshot shows the player restored to the moved location without
replaying the intro. A first attempt tried saving mid-step, correctly refused, and
exposed a menu overflow; the error label was fixed. The passing persistence run
waits for movement to stop. Language selection screenshots are being reviewed;
corrected pointer selections now show Romanian "Salut!" and Russian "Привет!"
with rendered glyphs. Initial keyboard-selection screenshots were discarded as
locale evidence because the dropdown had not selected the intended row.

## Evidence

Ignored artifacts are intentionally not committed:

- artifacts/validation/runtime.log and import.log
- artifacts/browser/results.json
- artifacts/browser/original_new_game.png and godot_new_game.png
- artifacts/browser/godot_pause.png, godot_save.png, godot_reload_title.png, godot_continue.png
- artifacts/browser/godot_Romanian.png and godot_Russian.png (verify selected setting)
- builds/windows/export.log and startup.log
- builds/web/export.log

## Remaining verification

Latest additions: QTE decline and four early/wrong-key failures, cleanup and retry;
MV camera zoom multiplier and edge clamp; walking animation cadence; snow timing,
count and cleanup; checkpoint weather and inherited music restoration. Exported
Web mouse directional/cancel controls, save and Continue pass. Selected QTE,
projectile, ending, credits and edge artwork regions match reference screenshots
within two RGB channel values. See artifacts/visual-parity/ and tools/visual_parity.py.

The Windows export was launched through the computer-use skill. Window capture
failed twice (FrameArrived/window capture timeouts), so no native UI input or visual
success is claimed from that attempt. A later process query confirms it exited.

Windows interactive gameplay and persistence; Map007/Map008/ending visual comparisons;
QTE failure/retry edge cases; repeated projectile attempts; touch/gamepad hardware;
every translated message layout; real-time behavior across frame rates and resizing;
listening/fade quality; full uninterrupted end-to-end navigation.
No original MV save import exists. Licensing is not established by these tests.
No claim is made that all migration acceptance criteria are complete.
