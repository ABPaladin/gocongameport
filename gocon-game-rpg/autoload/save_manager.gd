extends Node
const SAVE_PATH = "user://checkpoint.json"
var save_path = SAVE_PATH
const SETTINGS_PATH = "user://settings.json"
const VERSION = 1
var last_error = ""

func checkpoint_allowed() -> bool:
	var map = SceneManager.current_map
	# Active QTE pages contain transient pictures/waits that are not serialized.
	if GameState.map_id == 7 and GameState.get_self_switch(7,2,"A") and not GameState.get_self_switch(7,2,"D"): return false
	return is_instance_valid(map) and not SceneManager.transition and not DialogueManager.is_busy and map.foreground_runner == null and not GameState.timer_running and GameState.map_id not in [8,12,13] and not map.player.moving()

func save_checkpoint() -> bool:
	if not checkpoint_allowed():
		last_error = "Save at a quiet checkpoint outside a minigame."
		return false
	var data = {"version":VERSION, "map":GameState.map_id, "x":GameState.player_tile.x, "y":GameState.player_tile.y, "direction":GameState.facing, "switches":GameState.switches, "variables":GameState.variables, "self_switches":GameState.self_switches, "items":GameState.items_held, "language":GameState.language}
	data.events = {}
	for event in SceneManager.current_map.events:
		data.events[str(event.event_id)] = {"x":event.tile.x,"y":event.tile.y,"direction":event.direction}
	data.zoom = SceneManager.current_map.camera.zoom.x
	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write save: %s" % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	last_error = "" if error == OK else "Cannot finalize save: %s" % error
	return error == OK

func read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path): return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK: return {}
	var data = parser.data
	if not data is Dictionary or int(data.get("version", -1)) != VERSION: return {}
	for key in ["switches","variables","self_switches","items"]:
		if not data.get(key) is Dictionary: return {}
	for key in ["map", "x", "y", "direction", "version"]:
		if not data.get(key) is float and not data.get(key) is int: return {}
	for section in ["switches", "self_switches"]:
		for value in data[section].values():
			if not value is bool: return {}
	for section in ["variables", "items"]:
		for value in data[section].values():
			if not value is float and not value is int: return {}
	if data.get("language", "") not in ["English","Romanian","Russian"]: return {}
	if not GameData.maps.has(int(data.get("map", 0))): return {}
	var map: Dictionary = GameData.maps[int(data.map)]
	if int(data.get("x", -1)) < 0 or int(data.x) >= int(map.width): return {}
	if int(data.get("y", -1)) < 0 or int(data.y) >= int(map.height): return {}
	if int(data.get("direction", 0)) not in [2,4,6,8]: return {}
	if data.has("events"):
		if not data.events is Dictionary: return {}
		for event in data.events.values():
			if not event is Dictionary: return {}
			for key in ["x","y","direction"]:
				if not event.get(key) is float and not event.get(key) is int: return {}
			if int(event.direction) not in [2,4,6,8]: return {}
			if int(event.x) < 0 or int(event.y) < 0 or int(event.x) >= int(map.width) or int(event.y) >= int(map.height): return {}
	if data.has("zoom"):
		if not data.zoom is float and not data.zoom is int: return {}
		if float(data.zoom) <= 0 or float(data.zoom) > 10: return {}
	return data

func load_checkpoint() -> bool:
	var data = read_save()
	if data.is_empty():
		last_error = "No compatible checkpoint found."
		return false
	GameState.new_game()
	GameState.switches = data.switches
	GameState.variables = data.variables
	GameState.self_switches = data.self_switches
	GameState.items_held = data.items
	GameState.language = str(data.get("language", "English"))
	PictureManager.clear()
	SceneManager.load_map(int(data.map), Vector2i(int(data.x), int(data.y)), int(data.direction))
	for key in data.get("events", {}):
		var event = SceneManager.current_map.character(int(key), null)
		var saved: Dictionary = data.events[key]
		if event != null: event.locate(Vector2i(int(saved.x),int(saved.y)),int(saved.direction))
	SceneManager.current_map.camera.zoom = Vector2.ONE * float(data.get("zoom",2))
	return true

func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"language":GameState.language, "music":AudioManager.music_volume, "sound":AudioManager.sound_volume}))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not data is Dictionary: return
	if data.get("language", "") in ["English","Romanian","Russian"]: GameState.language = data.language
	AudioManager.music_volume = clampf(float(data.get("music", 0.8)), 0, 1)
	AudioManager.sound_volume = clampf(float(data.get("sound", 0.8)), 0, 1)
