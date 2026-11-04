# Migration progress

Baseline: b9d94901a8f15f4374bda5fc464b51529ddf44ac
Branch: feature/godot-complete-port

Implementation in progress. No phase is yet claimed complete.
The pre-existing untracked .claude directory is left untouched.
legacy/ must remain byte-identical to baseline.
Godot MCP remains attached to Cassette; use filesystem editing and the Godot CLI only.

Data preparation validated: prepare_runtime.py reuses existing extractors,
deduplicates assets by SHA256, records original file hashes, and generates
database/localization/tileset/asset manifests. Four Python tests pass (source
hashes, all map command lists/planes, manifest paths, translation equality).
Godot CLI: 4.7.2.stable.steam.ed1daf0bf. Export templates not yet located.

Data checkpoint: 621d82d.

Runtime implemented: title/new game, all maps, source passage, actor routes,
event VM with choices/branches/parallel tasks, translated dialogue, pictures,
timers, basic audio/settings/checkpoint saving. Original data remains authoritative.
Godot startup smoke passes. Runtime suite: 151 checks passed, including actual
intro, transfer continuation, randomized RPS reward gating, projectile timeout
and win-result paths. Audio cleanup diagnostics are being resolved.
Not yet verified: interactive QTE/projectile play, saves/corruption tests,
visual fidelity, exports, complete journey and source runtime comparison.
Do not describe the full migration as complete.

2026-11-04: 166 runtime checks and 4 Python checks pass. QTE and save tests added.
Real-time audio and visual comparison remain pending. Correct export templates
were found in Steam's self-contained editor_data/export_templates/4.7.2.stable.

Current task: expand behavioral/visual validation, finish presentation/input
edge cases, configure/test exports, update docs and push the feature branch.
Acceptance: all original command variants, all 13 maps, progression and platform testing.
