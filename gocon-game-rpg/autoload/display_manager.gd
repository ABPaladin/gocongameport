extends Node
## DisplayManager — DEZACTIVAT momentan.
##
## Jocul rulează la rezoluţia fixă 816×624 (ca originalul), fără scalare.
## Tot codul de mai jos e comentat, ca să-l poţi reactiva când vrei.
##
## ============================ CUM ÎL REACTIVEZI ============================
## 1. Decomentează codul de mai jos (selectezi tot şi Ctrl+K → Ctrl+U în Godot).
## 2. Project Settings → Autoload → adaugă `res://autoload/display_manager.gd`
##    cu numele `DisplayManager`.
## 3. Project Settings → Display → Window → Stretch → Scale Mode = `integer`
##    (obligatoriu pentru fullscreen curat la pixel art).
##
## Ce oferea: F11 = fullscreen, +/− = mărire/micşorare pe multipli întregi
## (1×, 2×, 3×), cu salvarea preferinţei în user://settings.cfg.
## ===========================================================================


#const BASE_SIZE := Vector2i(816, 624)
#const SETTINGS_PATH := "user://settings.cfg"
#
#signal display_changed
#
#var scale_factor: int = 1
#var is_fullscreen: bool = false
#
#
#func _ready() -> void:
	#_register_actions()
	#_load_settings()
	#apply()
#
#
#func _register_actions() -> void:
	#_ensure_action("toggle_fullscreen", [KEY_F11])
	#_ensure_action("window_bigger", [KEY_EQUAL, KEY_KP_ADD])
	#_ensure_action("window_smaller", [KEY_MINUS, KEY_KP_SUBTRACT])
#
#
#func _ensure_action(action_name: StringName, keys: Array) -> void:
	#if InputMap.has_action(action_name):
		#return
	#InputMap.add_action(action_name)
	#for k in keys:
		#var ev := InputEventKey.new()
		#ev.physical_keycode = k
		#InputMap.action_add_event(action_name, ev)
#
#
#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("toggle_fullscreen"):
		#toggle_fullscreen()
		#get_viewport().set_input_as_handled()
	#elif event.is_action_pressed("window_bigger"):
		#set_window_scale(scale_factor + 1)
		#get_viewport().set_input_as_handled()
	#elif event.is_action_pressed("window_smaller"):
		#set_window_scale(scale_factor - 1)
		#get_viewport().set_input_as_handled()
#
#
### Cea mai mare scalare întreagă care încape pe ecranul curent.
#func max_scale() -> int:
	#var screen := DisplayServer.screen_get_usable_rect(
		#DisplayServer.window_get_current_screen()).size
	#var fit := mini(screen.x / BASE_SIZE.x, screen.y / BASE_SIZE.y)
	#return maxi(1, fit)
#
#
### Setează fereastra la BASE_SIZE × n (n întreg, limitat la ecran).
#func set_window_scale(n: int) -> void:
	#scale_factor = clampi(n, 1, max_scale())
	#is_fullscreen = false
	#apply()
	#_save_settings()
#
#
#func toggle_fullscreen() -> void:
	#is_fullscreen = not is_fullscreen
	#apply()
	#_save_settings()
#
#
### Aplică efectiv starea curentă pe fereastră.
#func apply() -> void:
	#if is_fullscreen:
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	#else:
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		#DisplayServer.window_set_size(BASE_SIZE * scale_factor)
		#_center_window()
	#display_changed.emit()
#
#
#func _center_window() -> void:
	#var screen := DisplayServer.screen_get_usable_rect(
		#DisplayServer.window_get_current_screen())
	#var win := DisplayServer.window_get_size()
	#DisplayServer.window_set_position(
		#screen.position + (screen.size - win) / 2)
#
#
#func _save_settings() -> void:
	#var cfg := ConfigFile.new()
	#cfg.set_value("display", "scale", scale_factor)
	#cfg.set_value("display", "fullscreen", is_fullscreen)
	#cfg.save(SETTINGS_PATH)
#
#
#func _load_settings() -> void:
	#var cfg := ConfigFile.new()
	#if cfg.load(SETTINGS_PATH) != OK:
		#scale_factor = 1
		#return
	#scale_factor = int(cfg.get_value("display", "scale", 1))
	#is_fullscreen = bool(cfg.get_value("display", "fullscreen", false))
