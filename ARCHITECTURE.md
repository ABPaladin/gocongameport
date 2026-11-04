# Implemented architecture

All resource paths below are relative to `gocon-game-rpg/`. Source behavior is
defined by `legacy/data/` and the enabled MV 1.6.1 plugins. The earlier proposed
architecture and nonexistent project paths have been superseded.

## Runtime ownership

| Component | Responsibility |
|---|---|
| Main.tscn / main.gd | Title, pause/settings UI, HUD, touch buttons |
| autoload/game_data.gd | Validated JSON loading, original-ID dictionaries, asset manifest, full-message translation |
| autoload/game_state.gd | Switches, variables, self-switches, inventory, timer, language, input bindings |
| autoload/scene_manager.gd | Title/new game/game over, map lifecycle, transition fades and continuation |
| world/Map.tscn / map.gd | Painted layers, page refresh, foreground/parallel scheduling, passage and occupancy, camera |
| systems/map_actor.gd | Sheet-derived frames, grid interpolation, forced routes, animation, balloons |
| events/event.gd | Highest-valid-page selection and autonomous movement |
| actors/player/player.gd | Player input, movement, interaction and touch triggers |
| events/event_runner.gd | Bounded sequential command VM, branches/loops, waits, dialogue tickets, source identity |
| autoload/dialogue_manager.gd | Translation, text formatting, messages and choices; never interprets event lists |
| ui/dialogue/dialogue_box.gd | Original window skin/font, portrait, speaker box and typing |
| autoload/picture_manager.gd | Picture-ID ownership, screen coordinates, linear movement, blend modes, weather |
| autoload/audio_manager.gd | BGM/SE resources, pitch/volume, fade and cleanup |
| autoload/save_manager.gd | Versioned checkpoint/settings persistence and validation |

The older standalone menu scene is not the application menu; main.gd currently
owns that UI. Unused imported scenes/addons are not evidence of implemented features.

## Scheduling and transfer contract

The simulation is fixed at 60 physics ticks per second. An EventRunner holds
command list, PC, indent-keyed branches, waits, dialogue tickets, source map/event/
page identity and cancellation state. Loops scan the authoritative command list;
a 100-command per-tick budget prevents an infinite loop from freezing rendering.
Only one foreground runner exists per map. Each parallel event owns a runner.
State changes mark pages dirty; pages refresh before a stale autorun can restart.

Transfer cancels obsolete tasks and dialogue, then reconstructs the initiating
foreground continuation on the destination map. Its original identity remains
attached for self-switch writes after transfer. SceneManager owns 24-frame fades.
The accelerated test suite disables fades and explicitly steps map simulation.

## World and presentation

Ground and foreground images retain their pixel sizes and offsets; they are not
stretched into tile dimensions. Invisible tile flags determine four-direction
passage, including reverse-direction checks, boundaries, events and through flags.
Region 1 restricts NPC movement. Rendering uses nearest filtering and native
character frames derived from 3×4 or 12×8 sheet layouts, including exceptional sizes.
Default zoom is 2; the used ZoomOut command applies reciprocal zoom over its duration.

Pictures occupy a screen-space CanvasLayer. Blend 3 uses a screen-blend shader.
The source typo AIVISIBILE remains a no-op. No unrelated PSX effects are enabled.

## Checkpoints

Schema version 1 stores map/player position and facing, switch/variable/self-switch
dictionaries, item counts, language, current-map event positions/facing, and zoom.
Writes use a temporary file then rename. Corrupt or incompatible data is rejected.
Settings are separate. A checkpoint normalizes interpolation and restarts autonomous
event routes; it does not serialize active interpreter stacks or arbitrary pictures.
Active dialogue, foreground tasks, QTE, timer game and ending maps are disallowed.
Original RPG Maker save compatibility is not implemented.

## Generation contract

prepare_runtime.py reuses the existing extractors. Generated database/map JSON and
asset/hash manifests may be overwritten; scripts/scenes never are. Asset lookup
uses original names with SHA256 deduplication. legacy/ is read-only by project policy.
The generation pipeline and tests do not depend on the unrelated MCP connection.
