# Implementation handoff

## Identity and safety

Repository: https://github.com/ABPaladin/gocongameport
Branch: feature/godot-complete-port
Baseline: b9d94901a8f15f4374bda5fc464b51529ddf44ac
Data checkpoint: 621d82d. Core runtime checkpoint: bb92eed.
Preserve legacy/ and pre-existing ignored .claude/. Never reset/clean user work.

The correct project is gocon-game-rpg/project.godot. Godot 4.7.2 Steam and matching
self-contained export templates are installed. GODOT_BIN can override the path.
The available Godot MCP server identifies Cassette-LD60; do not mutate it.
This project's bundled editor plugin is disabled to prevent its port colliding
with that server. No unrelated project configuration was changed.

## Implemented and tested

Read ARCHITECTURE.md for ownership and COMPATIBILITY_MATRIX.md for coverage.
All 13 maps load; source event commands drive the intro, dialogue/choices,
trivia, QTE, RPS, projectile game, rewards and ending. The runtime suite has 205
passing checks (now expanded to 215). The projectile game now wins by firing through the actual action
event at moving targets, without supplying hit flags in the progression test.
An earlier isolated win-result test still uses a fixture, explicitly documented.

Both Windows and Web exports build. Windows title startup has been tested headless.
The exported Web build has been driven through intro, movement, pause, checkpoint,
reload and Continue. Screenshots and JSON evidence are ignored under artifacts/browser.
The original MV browser runtime also launches for matching-state visual references.

## Exact continuation

1. Run git status/log and read MIGRATION_PROGRESS.md and TEST_REPORT.md; do not repeat
   completed migration or create a second project.
2. Check any currently running browser test; inspect its audio and localization
   results before making claims. Expand tests for remaining input/platform edges.
3. Finish movement/passage fixtures, unsupported parameter diagnostics and event
   lifecycle edge cases. Check QTE failure/retry and repeated projectile attempts.
4. Compare representative Map007, Map008 and ending screenshots to MV, including
   camera/picture layers; only Map006 has been visually compared so far.
5. Verify Windows interactive gameplay and persistence; hardware gamepad/touch
   remains unverified. Avoid claiming hardware tests from simulated inputs.
6. Keep docs truthful, rerun changed-system tests, rebuild exports after runtime edits,
   commit scoped validated progress and retry feature-branch push. Prior push failed
   with GitHub Internal Server Error, not an authentication denial.
7. Do not mark the overall goal complete until acceptance evidence is sufficient.

## Commands

See README.md for run/test/export commands. tools/prepare_runtime.py regenerates
only generated content/manifests. No dependency install is needed for normal runtime.
Browser tests use isolated .test-deps/ Playwright + installed Edge.
The accelerated runtime suite disables real audio mixing and transition fades;
it is not an audio/real-time timing test. Tests use a separate checkpoint filename,
never the player's normal save. Builds, screenshots, logs and caches stay ignored.
