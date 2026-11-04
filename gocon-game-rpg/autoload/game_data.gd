extends Node
## Immutable generated content; original MV IDs and names remain public keys.
var system: Dictionary
var actors: Dictionary
var items: Dictionary
var tilesets: Dictionary
var translations: Dictionary
var assets: Dictionary
var maps: Dictionary = {}

func _ready() -> void:
	system = read_json("system")
	actors = read_json("actors")
	items = read_json("items")
	tilesets = read_json("tilesets")
	translations = read_json("translations")
	assets = read_json("assets")
	for id in range(1, 14):
		maps[id] = read_json("maps/map%03d" % id)

func read_json(name: String) -> Dictionary:
	var path = "res://data/%s.json" % name
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Invalid content: " + path)
		return {}
	return parsed

func asset(category: String, original_name: String) -> String:
	if original_name.is_empty(): return ""
	var key = category + "/" + original_name
	if not assets.has(key): push_error("Missing asset: " + key)
	return assets.get(key, "")

func translate(text: String, section: String = "msg") -> String:
	if GameState.language == "English": return text
	var translated = translations.get(section, {}).get(text, {}).get(GameState.language, "")
	return text if str(translated).is_empty() else str(translated)
