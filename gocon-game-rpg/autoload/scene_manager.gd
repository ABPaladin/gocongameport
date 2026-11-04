extends Node
signal screen_changed
var current_map
var host: Node
var paused = false
var screen = "title"
var transition = false
var transitions_enabled = true
var transition_generation = 0
var fade_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.visible = false
	fade_layer.add_child(fade_rect)

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

func transfer(id: int, at: Vector2i, direction: int = 0, fade_type: int = 0, continuation: Dictionary = {}) -> void:
	if transition: return
	transition = true
	current_map.cancel_events()
	transition_generation += 1
	if transitions_enabled and fade_type != 2:
		_fade_transfer(id, at, direction, fade_type, continuation, transition_generation)
	else: call_deferred("load_map", id, at, direction, continuation)

func _fade_transfer(id: int, at: Vector2i, direction: int, fade_type: int, continuation: Dictionary, epoch: int) -> void:
	fade_rect.color = Color.WHITE if fade_type == 1 else Color.BLACK
	fade_rect.modulate.a = 0
	fade_rect.visible = true
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 24.0 / 60)
	await tween.finished
	if epoch != transition_generation: return
	load_map(id, at, direction, continuation)
	transition = true
	current_map.transfer_pending = true
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 24.0 / 60)
	await tween.finished
	if epoch != transition_generation: return
	fade_rect.visible = false
	transition = false
	current_map.transfer_pending = false

func title() -> void:
	transition_generation += 1
	transition = false
	fade_rect.visible = false
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
