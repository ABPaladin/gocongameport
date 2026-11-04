class_name GameEvent
extends MapActor
var event_id = 0
var data: Dictionary = {}
var active_page: Dictionary = {}
var page_index = -1
var runner
var autonomous_ticks = 0
var locked = false
var prelock_direction = 2

func lock(facing: int) -> void:
	if locked: return
	locked = true
	prelock_direction = direction
	if not direction_fix: direction = facing

func unlock() -> void:
	if not locked: return
	locked = false
	if not direction_fix: direction = prelock_direction

func setup(event_data: Dictionary, _y_offset: int = 0) -> void:
	data = event_data
	event_id = int(data.id)
	locate(Vector2i(int(data.x), int(data.y)))
	refresh_page()

func refresh_page() -> void:
	var next = -1
	var pages: Array = data.get("pages", [])
	for i in range(pages.size() - 1, -1, -1):
		if conditions_met(pages[i].get("conditions", {})):
			next = i
			break
	if next == page_index: return
	page_index = next
	if runner != null: runner.cancel()
	runner = null
	active_page = {} if next < 0 else pages[next]
	if active_page.is_empty():
		sprite.texture = null
		through = true
		return
	set_graphic(active_page.image)
	move_speed = int(active_page.moveSpeed)
	priority = int(active_page.priorityType)
	through = bool(active_page.through)
	direction_fix = bool(active_page.directionFix)
	walking = bool(active_page.walkAnime)
	stepping = bool(active_page.stepAnime)
	route = active_page.moveRoute.duplicate(true) if int(active_page.moveType) == 3 else {}
	route_index = 0
	route_forced = false
	z_index = 2 if priority == 2 else (-1 if priority == 0 else 0)

func conditions_met(cond: Dictionary) -> bool:
	if cond.has("switch1Id") and not GameState.get_switch(int(cond.switch1Id)): return false
	if cond.has("switch2Id") and not GameState.get_switch(int(cond.switch2Id)): return false
	if cond.has("selfSwitchCh") and not GameState.get_self_switch(world.map_id, event_id, cond.selfSwitchCh): return false
	if cond.has("variableId") and GameState.get_variable(int(cond.variableId)) < cond.variableValue: return false
	if cond.has("itemId") and GameState.item_count(int(cond.itemId)) == 0: return false
	if cond.has("actorId") and int(cond.actorId) != 1: return false
	return true

func trigger_type() -> int: return int(active_page.get("trigger", -1))
func command_list() -> Array: return active_page.get("list", [])

func tick() -> void:
	var was_moving = moving()
	super.tick()
	if was_moving: autonomous_ticks = 0
	if active_page.is_empty() or moving() or route_forced or route_wait > 0: return
	if locked or (world.foreground_runner != null and world.foreground_runner.event == self): return
	autonomous_ticks += 1
	if autonomous_ticks <= (5 - int(active_page.moveFrequency)) * 30: return
	match int(active_page.moveType):
		1:
			match GameState.rng.randi_range(0,5):
				0,1: step([2,4,6,8][GameState.rng.randi_range(0,3)])
				2,3,4: step(direction)
				5: autonomous_ticks = 0
		2:
			var difference = world.player.tile - tile
			if abs(difference.x) > abs(difference.y): step(6 if difference.x > 0 else 4)
			else: step(2 if difference.y > 0 else 8)
		3: route_tick()
