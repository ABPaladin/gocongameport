class_name GameMap
extends Node2D
const DEFAULT_ZOOM = 2.0
@export var map_id = 6
@export var collision_layer = 1
@export var build_collision = true
@export var debug_show_event_ids = false
@export var debug_show_player_tile = false
var map_data: Dictionary = {}
var width = 0
var height = 0
var flags: Array = []
var events: Array = []
var player
var camera: Camera2D
var foreground_runner
var dirty_pages = true
var transfer_pending = false
var zoom_target = DEFAULT_ZOOM
var zoom_frames = 0
var indicator: Sprite2D

func _ready() -> void:
	add_to_group("game_map")
	map_data = GameData.maps[map_id]
	width = int(map_data.width)
	height = int(map_data.height)
	flags = GameData.tilesets[str(int(map_data.tilesetId))].flags
	for child in get_children():
		if child is Player: child.queue_free()
	var ground_name = str(map_data.overlays.ground).trim_suffix(".png")
	var foreground_name = str(map_data.overlays.par).trim_suffix(".png")
	$Ground.position = Vector2.ZERO
	$Foreground.position = Vector2.ZERO
	$Ground.texture = load(GameData.asset("parallaxes", ground_name)) if ground_name != "" else null
	$Foreground.texture = load(GameData.asset("parallaxes", foreground_name)) if foreground_name != "" else null
	for data in map_data.events:
		var event = GameEvent.new()
		event.world = self
		$Entities.add_child(event)
		event.setup(data)
		events.append(event)
	player = Player.new()
	player.world = self
	$Entities.add_child(player)
	var actor: Dictionary = GameData.actors["1"]
	player.set_graphic({"characterName":actor.characterName, "characterIndex":actor.characterIndex})
	player.locate(GameState.player_tile, GameState.facing)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * DEFAULT_ZOOM
	camera.position_smoothing_enabled = false
	add_child(camera)
	update_camera()
	indicator = Sprite2D.new()
	indicator.texture = load(GameData.asset("system", "IconSet"))
	indicator.region_enabled = true
	indicator.z_index = 110
	indicator.visible = false
	add_child(indicator)
	GameState.changed.connect(_state_changed)
	if map_data.autoplayBgm: AudioManager.play_bgm(map_data.bgm)

func _state_changed() -> void: dirty_pages = true
func input_locked() -> bool:
	return transfer_pending or foreground_runner != null or DialogueManager.is_busy or SceneManager.paused

func _physics_process(_delta: float) -> void:
	if SceneManager.paused or transfer_pending: return
	if dirty_pages:
		for event in events: event.refresh_page()
		dirty_pages = false
	$Foreground.visible = GameState.get_switch(int(map_data.overlays.parSwitch))
	if GameState.timer_running and GameState.timer_frames > 0: GameState.timer_frames -= 1
	if zoom_frames > 0:
		camera.zoom = (camera.zoom * (zoom_frames - 1) + Vector2.ONE * zoom_target) / zoom_frames
		zoom_frames -= 1
	for event in events: event.tick()
	player.tick()
	update_camera()
	update_indicator()
	if foreground_runner != null:
		foreground_runner.tick()
		if foreground_runner.done:
			if is_instance_valid(foreground_runner.event): foreground_runner.event.unlock()
			foreground_runner = null
	# State changes may invalidate an autorun page. Refresh before starting any
	# new task, otherwise the stale intro/reward page can restart in this tick.
	if dirty_pages:
		for event in events: event.refresh_page()
		dirty_pages = false
	for event in events:
		if event.trigger_type() == 4:
			if event.runner == null or event.runner.done:
				event.runner = EventRunner.new(self, event)
			event.runner.tick()
		elif event.trigger_type() == 3 and foreground_runner == null:
			foreground_runner = EventRunner.new(self, event)

func trigger_at(at: Vector2i, triggers: Array, normal_priority: bool) -> void:
	if input_locked(): return
	for event in events:
		if event.tile == at and event.trigger_type() in triggers and (event.priority == 1) == normal_priority:
			event.lock(10 - player.direction)
			foreground_runner = EventRunner.new(self, event)
			return

func character(id: int, current_event):
	if id == -1: return player
	if id == 0: return current_event
	for event in events:
		if event.event_id == id: return event
	return null

func update_indicator() -> void:
	indicator.visible = false
	if input_locked() or not GameState.indicators_visible: return
	var target = wrap_tile(player.tile + MapActor.DIRECTIONS[player.direction])
	for event in events:
		if event.tile != target or event.trigger_type() != 0: continue
		for command in event.command_list():
			if int(command.code) != 108: continue
			var regex = RegEx.new()
			regex.compile("(?i)<actionIcon:\\s*(\\d+)>")
			var found = regex.search(str(command.parameters[0]))
			if found:
				var icon = int(found.get_string(1))
				indicator.region_rect = Rect2((icon % 16) * 32, int(icon / 16) * 32,32,32)
				indicator.position = event.position + Vector2(16,-40)
				indicator.visible = true
				return

func wrap_tile(at: Vector2i) -> Vector2i:
	var scroll = int(map_data.scrollType)
	return Vector2i(posmod(at.x, width) if scroll in [2,3] else at.x, posmod(at.y, height) if scroll in [1,3] else at.y)

func camera_center(at: Vector2) -> Vector2:
	# MV clamps its unzoomed 816x624 display rectangle, then CameraCore scales
	# around the screen center. Camera2D's zoom-dependent limits differ at edges.
	var center = at
	var scroll = int(map_data.scrollType)
	if scroll not in [2,3]: center.x = width * 16 if width * 32 < 816 else clampf(at.x,408,width * 32 - 408)
	if scroll not in [1,3]: center.y = height * 16 if height * 32 < 624 else clampf(at.y,312,height * 32 - 312)
	return center

func update_camera() -> void:
	camera.position = camera_center(player.position + Vector2(16,16))

func valid(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < width and at.y < height

func passage(at: Vector2i, bit: int) -> bool:
	if not valid(at): return false
	var index = at.y * width + at.x
	for z in range(3, -1, -1):
		var flag = int(flags[int(map_data.layers[z][index])])
		if flag & 16: continue
		if (flag & bit) == 0: return true
		if (flag & bit) == bit: return false
	return false

func can_step(actor, dir: int) -> bool:
	var dest = wrap_tile(actor.tile + MapActor.DIRECTIONS[dir])
	if not valid(dest): return false
	if actor.through: return true
	if actor != player and int(map_data.regions[dest.y * width + dest.x]) == 1: return false
	var bit = 1 << (int(dir / 2) - 1)
	var reverse = 1 << (int((10 - dir) / 2) - 1)
	if not passage(actor.tile, bit) or not passage(dest, reverse): return false
	for event in events:
		if event != actor and event.tile == dest and event.priority == 1 and not event.through and not event.active_page.is_empty(): return false
	if actor != player and actor.priority == 1 and player.tile == dest and not player.through: return false
	return true

func path_direction(start: Vector2i, goal: Vector2i) -> int:
	# Bounded BFS; uses the same occupancy rules as direct movement.
	if start == goal: return 0
	var queue = [start]
	var first = {start: 0}
	var original = player.tile
	var index = 0
	while index < queue.size() and index < 400:
		var at: Vector2i = queue[index]
		index += 1
		player.tile = at
		for dir in [2,4,6,8]:
			var next = wrap_tile(at + MapActor.DIRECTIONS[dir])
			if first.has(next) or not can_step(player, dir): continue
			first[next] = dir if at == start else first[at]
			if next == goal:
				player.tile = original
				return first[next]
			queue.append(next)
	player.tile = original
	return 0

func cancel_events() -> void:
	transfer_pending = true
	if foreground_runner != null: foreground_runner.cancel()
	for event in events:
		if event.runner != null: event.runner.cancel()
	DialogueManager.cancel()
