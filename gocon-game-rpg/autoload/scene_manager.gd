extends Node
signal screen_changed
var current_map
var host: Node
var paused = false
var screen = "title"
var transition = false

func bind(root: Node) -> void:
	host = root
	screen_changed.emit()

func new_game() -> void:
	GameState.new_game()
	PictureManager.clear()
	load_map(GameState.map_id, GameState.player_tile, GameState.facing)

func load_map(id: int, at: Vector2i, direction: int = 0, continuation: Dictionary = {}) -> void:
	if not GameData.maps.has(id):
		push_error("Invalid map ID: %d" % id)
		return
	if is_instance_valid(current_map):
		current_map.cancel_events()
		current_map.get_parent().remove_child(current_map)
		current_map.queue_free()
	GameState.map_id = id
	GameState.player_tile = at
	if direction != 0: GameState.facing = direction
	current_map = load("res://world/Map.tscn").instantiate()
	current_map.map_id = id
	host.add_child(current_map)
	if not continuation.is_empty():
		var runner = EventRunner.new(current_map, null, continuation.commands)
		runner.pc = int(continuation.pc)
		runner.branch = continuation.branch
		runner.source_map_id = int(continuation.map)
		runner.source_event_id = int(continuation.event)
		runner.page_index = int(continuation.page)
		current_map.foreground_runner = runner
	screen = "game"
	paused = false
	transition = false
	screen_changed.emit()

func transfer(id: int, at: Vector2i, direction: int = 0, _fade: int = 0, continuation: Dictionary = {}) -> void:
	if transition: return
	transition = true
	current_map.cancel_events()
	call_deferred("load_map", id, at, direction, continuation)

func title() -> void:
	if is_instance_valid(current_map):
		current_map.cancel_events()
		current_map.queue_free()
	current_map = null
	PictureManager.clear()
	AudioManager.play_bgm({})
	screen = "title"
	paused = false
	screen_changed.emit()

func game_over() -> void:
	if is_instance_valid(current_map): current_map.cancel_events()
	DialogueManager.cancel()
	screen = "game_over"
	paused = true
	screen_changed.emit()

func toggle_pause() -> void:
	if screen != "game" or DialogueManager.is_busy: return
	if current_map.foreground_runner != null: return
	paused = not paused
	screen_changed.emit()
