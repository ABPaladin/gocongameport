# Implementation handoff

## Identity and safety

Repository: https://github.com/ABPaladin/gocongameport
Branch: feature/godot-complete-port
Baseline: b9d94901a8f15f4374bda5fc464b51529ddf44ac
Data checkpoint: 621d82d. Core runtime: bb92eed. Export checkpoint: b207ce1 (pushed).
Preserve legacy/ and pre-existing ignored .claude/. Never reset/clean user work.

The correct project is gocon-game-rpg/project.godot. Godot 4.7.2 Steam and matching
self-contained export templates are installed. GODOT_BIN can override the path.
The available Godot MCP server identifies Cassette-LD60; do not mutate it.
This project's bundled editor plugin is disabled to prevent its port colliding
with that server. No unrelated project configuration was changed.

## Implemented and tested

Read ARCHITECTURE.md for ownership and COMPATIBILITY_MATRIX.md for coverage.
All 13 maps load; source event commands drive the intro, dialogue/choices,
trivia, QTE, RPS, projectile game, rewards and ending. The runtime suite has 244
passing checks. The projectile game now wins by firing through the actual action
event at moving targets, without supplying hit flags in the progression test.
An earlier isolated win-result test still uses a fixture, explicitly documented.

Both Windows and Web exports build. Windows release title startup passes headless.
The Windows Validation export now passes normal rendered title/intro/movement,
pause/save/Continue and restoration after a second process launch. Evidence lives
under builds/windows-validation (JSON, logs and inspected PNGs); run
tools/native_ui_smoke.py. Input is simulated inside Godot, not a hardware test.
The exported Web build has been driven through intro, movement, pause, checkpoint,
reload and Continue. Screenshots and JSON evidence are ignored under artifacts/browser.
The original MV browser runtime also launches for matching-state visual references.

## Exact continuation

Latest input update: run tools/touch_smoke.py for actual exported browser touch
events and scaling. The checkpoint JSON verifies intro completion and movement.
Simulated gamepad mappings are in runtime_tests.gd. Touch dialogue uses _input
because GUI controls consumed taps before _unhandled_input. Source ALOE disables
map-tap navigation, now respected. Native Windows gameplay evidence is now recorded;
next prioritize dialogue/choice fidelity and the final acceptance audit.

1. Run git status/log and read MIGRATION_PROGRESS.md and TEST_REPORT.md; do not repeat
   completed migration or create a second project.
2. Check any currently running browser test; inspect its audio and localization
   results before making claims. Expand tests for remaining input/platform edges.
3. Finish movement/passage fixtures, unsupported parameter diagnostics and event
   lifecycle edge cases. Check QTE failure/retry and repeated projectile attempts.
4. Visual fixtures now cover Map007 QTE, Map008 projectiles, both ending pictures
   and Map006 edge framing. Continue with dialogue/choices, weather and runtime motion.
5. Windows rendered gameplay and cross-process persistence passed. Hardware
   gamepad/touch remains unverified. Avoid hardware claims from simulated inputs.
6. Keep docs truthful, rerun changed-system tests, rebuild exports after runtime edits,
   commit scoped validated progress and push the feature branch. Push through b207ce1 succeeded.
7. Do not mark the overall goal complete until acceptance evidence is sufficient.

## Commands

See README.md for run/test/export commands. tools/prepare_runtime.py regenerates
only generated content/manifests. No dependency install is needed for normal runtime.
Browser tests use isolated .test-deps/ Playwright + installed Edge.
The accelerated runtime suite disables real audio mixing and transition fades;
it is not an audio/real-time timing test. Tests use a separate checkpoint filename,
never the player's normal save. Builds, screenshots, logs and caches stay ignored.
