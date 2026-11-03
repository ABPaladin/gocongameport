extends Node
## GameState (autoload)
##
## Starea mutabilă a jocului: switch-uri, variabile, inventar, limbă, poziția
## jucătorului. Tot ce intră într-un save mai târziu stă aici.
## Tot aici înregistrăm acțiunile de input proprii jocului.

# Switch-urile și variabilele din RPG Maker (sparse: ținem doar ce s-a setat).
var switches: Dictionary = {}
var variables: Dictionary = {}
## Self-switch-uri, cheie "mapId,eventId,canal" (A/B/C/D) -> bool
var self_switches: Dictionary = {}

var items_held: Dictionary = {}      ## itemId -> cantitate
var language: String = "English"


func _ready() -> void:
	_register_input_actions()


## Adăugăm acțiunile care nu există implicit în Godot.
## (ui_up/down/left/right există deja, pe săgeți.)
func _register_input_actions() -> void:
	_ensure_action("interact", [KEY_ENTER, KEY_SPACE, KEY_Z])
	_ensure_action("open_menu", [KEY_ESCAPE, KEY_X])


func _ensure_action(action_name: StringName, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return                       # deja definită (ex. din Project Settings)
	InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)


# --- Switch-uri / variabile ------------------------------------------------

func get_switch(id: int) -> bool:
	return bool(switches.get(id, false))

func set_switch(id: int, value: bool) -> void:
	switches[id] = value

func get_variable(id: int):
	return variables.get(id, 0)

func set_variable(id: int, value) -> void:
	variables[id] = value

func get_self_switch(map_id: int, event_id: int, channel: String) -> bool:
	return bool(self_switches.get("%d,%d,%s" % [map_id, event_id, channel], false))

func set_self_switch(map_id: int, event_id: int, channel: String, value: bool) -> void:
	self_switches["%d,%d,%s" % [map_id, event_id, channel]] = value


# --- Inventar --------------------------------------------------------------

func item_count(item_id: int) -> int:
	return int(items_held.get(item_id, 0))

func gain_item(item_id: int, amount: int) -> void:
	var n := item_count(item_id) + amount
	if n <= 0:
		items_held.erase(item_id)
	else:
		items_held[item_id] = n
