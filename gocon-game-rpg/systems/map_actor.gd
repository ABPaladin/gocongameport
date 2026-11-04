class_name MapActor
extends Node2D
## Authoritative tile occupancy, interpolated at the fixed 60 Hz simulation rate.
const DIRECTIONS = {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}
var world
var tile = Vector2i.ZERO
var direction = 2
var move_speed = 4
var through = false
var direction_fix = false
var walking = true
var stepping = false
var priority = 1
var sprite: Sprite2D
var character_name = ""
var character_index = 0
var pattern = 1
var original_pattern = 1
var animation_tick = 0
var animation_phase = 1
var route: Dictionary = {}
var route_index = 0
var route_wait = 0
var route_forced = false
var original_route: Dictionary = {}
var original_route_index = 0
var balloon_frames = 0
var balloon_sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	add_child(sprite)
	balloon_sprite = Sprite2D.new()
	balloon_sprite.z_index = 120
	balloon_sprite.visible = false
	add_child(balloon_sprite)

func locate(at: Vector2i, facing_dir: int = 0) -> void:
	tile = at
	position = Vector2(tile * 32)
	if facing_dir != 0: direction = facing_dir

func moving() -> bool: return position.distance_to(Vector2(tile * 32)) > 0.01

func step(dir: int) -> bool:
	if not direction_fix: direction = dir
	if not world.can_step(self, dir): return false
	tile = world.wrap_tile(tile + DIRECTIONS[dir])
	return true

func set_graphic(image: Dictionary) -> void:
	character_name = str(image.get("characterName", ""))
	character_index = int(image.get("characterIndex", 0))
	direction = int(image.get("direction", 2))
	pattern = int(image.get("pattern", 1))
	original_pattern = pattern
	var path = GameData.asset("characters", character_name)
	sprite.texture = load(path) if not path.is_empty() else null
	update_frame()

func update_frame() -> void:
	if sprite.texture == null: return
	var single = character_name.contains("$")
	var size_px = sprite.texture.get_size() / Vector2(3 if single else 12, 4 if single else 8)
	var column = pattern + (0 if single else character_index % 4 * 3)
	var row = int(direction / 2) - 1 + (0 if single else int(character_index / 4) * 4)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(column, row) * size_px, size_px)
	var shift = 0 if character_name.contains("!") else 6
	sprite.position = Vector2(16, 32 - shift - size_px.y / 2)

func tick() -> void:
	var was_moving = moving()
	if was_moving:
		position = position.move_toward(Vector2(tile * 32), pow(2.0, move_speed) / 256.0 * 32.0)
	if (was_moving and walking) or stepping:
		animation_tick += 1
		if animation_tick >= (9 - move_speed) * 3:
			animation_tick = 0
			animation_phase = (animation_phase + 1) % 4
			pattern = [0, 1, 2, 1][animation_phase]
	else: pattern = original_pattern
	update_frame()
	if balloon_frames > 0:
		balloon_frames -= 1
		balloon_sprite.region_rect.position.x = mini(int((76 - balloon_frames) / 8), 7) * 48
		balloon_sprite.visible = balloon_frames > 0
	if route_wait > 0: route_wait -= 1
	elif not moving() and not route.is_empty() and route_forced: route_tick()

func force_route(value: Dictionary) -> void:
	if not route_forced:
		original_route = route
		original_route_index = route_index
	route = value.duplicate(true)
	route_index = 0
	route_forced = true
	route_wait = 0

func route_tick() -> void:
	var list: Array = route.get("list", [])
	if route_index >= list.size(): return
	var command: Dictionary = list[route_index]
	var code = int(command.code)
	var p: Array = command.get("parameters", [])
	var succeeded = true
	match code:
		0:
			if route.get("repeat", false): route_index = 0
			elif route_forced:
				route = original_route
				route_index = original_route_index
				route_forced = false
			else: route = {}
			return
		1, 2, 3, 4: succeeded = step([2, 4, 6, 8][code - 1])
		15: route_wait = int(p[0]) - 1
		16, 17, 18, 19: direction = [2, 4, 6, 8][code - 16]
		29: move_speed = int(p[0])
		31: walking = true
		32: walking = false
		33: stepping = true
		34: stepping = false
		35: direction_fix = true
		36: direction_fix = false
		37: through = true
		38: through = false
		39: visible = false
		40: visible = true
		41: set_graphic({"characterName": p[0], "characterIndex": p[1], "direction": direction})
		44: AudioManager.play_se(p[0])
		_:
			push_error("Unsupported route %d at index %d" % [code, route_index])
			route = {}
			route_forced = false
	if succeeded or route.get("skippable", false): route_index += 1

func balloon(id: int) -> void:
	balloon_sprite.texture = load(GameData.asset("system", "Balloon"))
	balloon_sprite.region_enabled = true
	balloon_sprite.region_rect = Rect2(0, (id - 1) * 48, 48, 48)
	balloon_sprite.position = Vector2(16, -32)
	balloon_frames = 76
