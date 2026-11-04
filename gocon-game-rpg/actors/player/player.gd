class_name Player
extends MapActor
var was_moving = false
var click_target = Vector2i(-1, -1)

func tick() -> void:
	was_moving = moving()
	super.tick()
	visible = not GameState.transparent
	GameState.player_tile = tile
	GameState.facing = direction
	if was_moving and not moving(): world.trigger_at(tile, [1], false)
	if moving() or route_forced or world.input_locked(): return
	if Input.is_action_just_pressed("interact"):
		world.trigger_at(tile, [0], false)
		if not world.input_locked():
			world.trigger_at(world.wrap_tile(tile + DIRECTIONS[direction]), [0], true)
		return
	var dir = 0
	for pair in [["ui_down", 2], ["ui_left", 4], ["ui_right", 6], ["ui_up", 8]]:
		if Input.is_action_pressed(pair[0]):
			dir = pair[1]
			click_target = Vector2i(-1, -1)
	if dir == 0 and click_target.x >= 0:
		dir = world.path_direction(tile, click_target)
		if dir == 0: click_target = Vector2i(-1, -1)
	if dir != 0:
		move_speed = 5 if Input.is_action_pressed("dash") and not world.map_data.disableDashing else 4
		if not step(dir): world.trigger_at(world.wrap_tile(tile + DIRECTIONS[dir]), [1], true)
