# Migration progress

Baseline: b9d94901a8f15f4374bda5fc464b51529ddf44ac
Branch: feature/godot-complete-port
Original legacy/ remains unchanged; pre-existing .claude/ remains untouched.

## Checkpoints

- 621d82d — deterministic content preparation and integrity tests.
- bb92eed — map runtime, bounded event VM and gameplay regression suite.
- Next checkpoint — presentation/persistence fixes, original reward/ending validation,
  Windows/Web exports and browser evidence; commit hash to be recorded after commit.

## Implemented

A: title/new game/bootstrap, all autoloads.
B: all 13 painted maps, passage/occupancy/region rules, grid movement and routes.
C: handlers for all 35 observed command IDs, foreground/parallel scheduling,
page refresh, waits, choices/branches, transfer cancellation and continuation.
D: source full-message EN/RO/RU translation, faces, speaker labels, choices.
E: actual six stamp reward paths and progression gate; item IDs preserved.
F: source-driven QTE, RPS and projectile/timer game; no duplicate native controllers.
G: camera, picture IDs/blends, overlay startup, animations/balloons, audio.
H: native title/pause/settings/inventory/touch UI and versioned checkpoint.
I: deterministic source extraction, asset deduplication/provenance, reference tests.
J: 215 runtime assertions and 5 Python tests passing; broader parity testing continues.
K: Windows and Web exports built. Web intro/movement/save/reload/Continue tested.
Windows actual exported title startup tested headless.

Implementation status does not imply complete behavioral/visual parity.
See COMPATIBILITY_MATRIX.md and TEST_REPORT.md for specific limits.

## Current evidence and fixes

- Original MV browser runtime works, enabling real screenshot references.
- Settled Map006 framing matches. Dialogue/HUD positioning and arrow corrected.
- All reward paths reach the ending under source-command simulation.
- Projectile progression test fires at moving targets without injected hit flags.
- Save schema includes current-map event positions/facing and camera zoom.
- Active QTE checkpoint rejected; mid-step save refusal no longer breaks menu layout.
- NPC interaction locks autonomous motion and restores original facing.
- Web IndexedDB checkpoint persists across reload; Continue restores gameplay.
- Browser AudioContext runs with nonzero measured output after user activation.
- Source pan is always zero. Nonzero-pan compatibility is not claimed.
- MCP still identifies Cassette-LD60. No mutation was sent. Bundled plugin disabled
  only in this project to avoid port collision; CLI validation succeeds.

## Git / delivery

Push after bb92eed was attempted and rejected by GitHub Internal Server Error
(request 5F8B:BDDAC:4E51A13:6D4966F:6AEB098D). Retry feature branch push.
Do not push main or force push. Builds/artifacts/.test-deps are ignored.
Two pre-existing tracked pyc files should be removed from the index without
deleting local source or changing legacy.

## Next tasks

Romanian/Russian intro screenshots reviewed: both display the selected translation.
Add remaining minigame retry/lifecycle tests and broader visual comparisons.
Exercise Windows gameplay/persistence and remaining input/platform behavior.
Rebuild after runtime changes, update evidence, commit and push validated progress.
The overall migration is not yet declared complete.
