extends Node
signal changed
var switches: Dictionary = {}
var variables: Dictionary = {}
var self_switches: Dictionary = {}
var items_held: Dictionary = {}
var language = "English"
var map_id = 6
var player_tile = Vector2i(14, 41)
var facing = 2
var timer_frames = 0
var timer_running = false
var transparent = false
var virtual_visible = true
var indicators_visible = true
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for entry in [["interact", [KEY_ENTER, KEY_SPACE, KEY_Z], JOY_BUTTON_A], ["open_menu", [KEY_ESCAPE, KEY_X], JOY_BUTTON_B], ["dash", [KEY_SHIFT], JOY_BUTTON_X]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		for key in entry[1]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(entry[0], event)
		var joy = InputEventJoypadButton.new()
		joy.button_index = entry[2]
		InputMap.action_add_event(entry[0], joy)

func new_game() -> void:
	switches = {"1": true, "2": true, "3": true, "4": true}
	variables.clear()
	self_switches.clear()
	items_held.clear()
	map_id = int(GameData.system.startMapId)
	player_tile = Vector2i(int(GameData.system.startX), int(GameData.system.startY))
	facing = 2
	timer_frames = 0
	timer_running = false
	transparent = false
	virtual_visible = true
	indicators_visible = true
	changed.emit()

func get_switch(id: int) -> bool: return bool(switches.get(str(id), false))
func set_switch(id: int, value: bool) -> void:
	switches[str(id)] = value
	changed.emit()
func get_variable(id: int): return variables.get(str(id), 0)
func set_variable(id: int, value) -> void:
	variables[str(id)] = floor(value) if value is float else value
	changed.emit()
func get_self_switch(mid: int, eid: int, channel: String) -> bool:
	return bool(self_switches.get("%d,%d,%s" % [mid, eid, channel], false))
func set_self_switch(mid: int, eid: int, channel: String, value: bool) -> void:
	self_switches["%d,%d,%s" % [mid, eid, channel]] = value
	changed.emit()
func item_count(id: int) -> int: return int(items_held.get(str(id), 0))
func gain_item(id: int, amount: int) -> void:
	items_held[str(id)] = clampi(item_count(id) + amount, 0, 99)
	changed.emit()
