extends Node
var ui: CanvasLayer
var menu: Control
var hud: Label
var timer_label: Label
var virtual_controls: Control

func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(639, 34)
	hud.add_theme_font_override("font", load("res://assets/fonts/mplus-1m-regular.ttf"))
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_constant_override("outline_size", 4)
	hud.add_theme_color_override("font_outline_color", Color(0,0,0,0.5))
	ui.add_child(hud)
	timer_label = Label.new()
	timer_label.position = Vector2(720,0)
	timer_label.custom_minimum_size = Vector2(96,48)
	timer_label.add_theme_font_override("font",load("res://assets/fonts/mplus-1m-regular.ttf"))
	timer_label.add_theme_font_size_override("font_size",32)
	timer_label.add_theme_constant_override("outline_size",4)
	timer_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.5))
	ui.add_child(timer_label)
	virtual_controls = load("res://ui/virtual_controls.gd").new()
	ui.add_child(virtual_controls)
	SceneManager.screen_changed.connect(rebuild_menu)
	SaveManager.load_settings()
	SceneManager.bind(self)

func _process(_delta: float) -> void:
	hud.visible = SceneManager.screen == "game"
	hud.text = "Stamp x %d" % GameState.item_count(1)
	hud.modulate.a = 0.5 if DialogueManager.is_busy else 1.0
	timer_label.visible = SceneManager.screen == "game" and GameState.timer_running
	var seconds = int(GameState.timer_frames / 60)
	timer_label.text = "%02d:%02d" % [int(seconds / 60),seconds % 60]
	virtual_controls.visible = SceneManager.screen == "game" and not SceneManager.paused and not DialogueManager.is_busy and GameState.virtual_visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		SceneManager.toggle_pause()
		get_viewport().set_input_as_handled()

func rebuild_menu() -> void:
	if is_instance_valid(menu):
		ui.remove_child(menu)
		menu.queue_free()
	menu = null
	if SceneManager.screen == "game" and not SceneManager.paused: return
	var background = ColorRect.new()
	background.color = Color(0.02,0.04,0.08,0.92)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(background)
	menu = background
	if SceneManager.screen == "title":
		var art = TextureRect.new()
		art.texture = load(GameData.asset("titles1", str(GameData.system.title1Name)))
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(art)
	var panel = VBoxContainer.new()
	panel.position = Vector2(250,130)
	panel.custom_minimum_size = Vector2(316,0)
	menu.add_child(panel)
	var title = Label.new()
	title.text = "Gocon Game" if SceneManager.screen == "title" else ("Game Over" if SceneManager.screen == "game_over" else "Paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	panel.add_child(title)
	if SceneManager.screen == "title":
		add_button(panel, "New Game", SceneManager.new_game)
		var continue_button = add_button(panel, "Continue", SaveManager.load_checkpoint)
		continue_button.disabled = SaveManager.read_save().is_empty()
	elif SceneManager.screen == "game":
		add_button(panel, "Resume", SceneManager.toggle_pause)
		add_button(panel, "Save checkpoint", func():
			var ok = SaveManager.save_checkpoint()
			title.text = "Saved" if ok else "Save unavailable"
			title.tooltip_text = SaveManager.last_error)
		add_button(panel, "Inventory", func(): title.text = "Stamp: %d  QuestList: %d" % [GameState.item_count(1), GameState.item_count(2)])
		add_button(panel, "Return to title", SceneManager.title)
	else:
		add_button(panel, "New Game", SceneManager.new_game)
		add_button(panel, "Title", SceneManager.title)
	var language = OptionButton.new()
	for name in ["English","Romanian","Russian"]: language.add_item(name)
	language.select(["English","Romanian","Russian"].find(GameState.language))
	language.item_selected.connect(func(index):
		GameState.language = ["English","Romanian","Russian"][index]
		SaveManager.save_settings())
	panel.add_child(language)
	for kind in ["Music", "Sound"]:
		var label = Label.new()
		label.text = kind
		panel.add_child(label)
		var slider = HSlider.new()
		slider.max_value = 1
		slider.step = 0.05
		slider.value = AudioManager.music_volume if kind == "Music" else AudioManager.sound_volume
		slider.value_changed.connect(func(value):
			if kind == "Music":
				AudioManager.set_music_volume(value)
			else: AudioManager.sound_volume = value
			SaveManager.save_settings())
		panel.add_child(slider)
	add_button(panel, "Fullscreen", func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	panel.get_child(1).grab_focus()

func add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
