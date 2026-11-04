extends Node
const SAVE_PATH = "user://checkpoint.json"
var save_path = SAVE_PATH
const SETTINGS_PATH = "user://settings.json"
const VERSION = 1
var last_error = ""

func checkpoint_allowed() -> bool:
	var map = SceneManager.current_map
	return is_instance_valid(map) and not SceneManager.transition and not DialogueManager.is_busy and map.foreground_runner == null and not GameState.timer_running and GameState.map_id not in [8,12,13] and not map.player.moving()

func save_checkpoint() -> bool:
	if not checkpoint_allowed():
		last_error = "Save at a quiet checkpoint outside a minigame."
		return false
	var data = {"version":VERSION, "map":GameState.map_id, "x":GameState.player_tile.x, "y":GameState.player_tile.y, "direction":GameState.facing, "switches":GameState.switches, "variables":GameState.variables, "self_switches":GameState.self_switches, "items":GameState.items_held, "language":GameState.language}
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
