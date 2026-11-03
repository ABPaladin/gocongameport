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

Current task: bootstrap and event runtime. No gameplay parity claimed yet.
Acceptance: all original command variants, all 13 maps, progression and platform testing.
