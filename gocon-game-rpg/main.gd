extends Node
var ui: CanvasLayer
var menu: Control
var hud: Label
var virtual_controls: Control

func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(610, 15)
	hud.add_theme_font_size_override("font_size", 24)
	ui.add_child(hud)
	virtual_controls = Control.new()
	ui.add_child(virtual_controls)
	for entry in [["<", "ui_left", Vector2(20,500)], [">", "ui_right", Vector2(150,500)], ["^", "ui_up", Vector2(85,435)], ["v", "ui_down", Vector2(85,565)], ["OK", "interact", Vector2(720,500)]]:
		var button = Button.new()
		button.text = entry[0]
		button.position = entry[2]
		button.size = Vector2(60,55)
		virtual_controls.add_child(button)
		button.button_down.connect(Input.action_press.bind(entry[1]))
		button.button_up.connect(Input.action_release.bind(entry[1]))
	SceneManager.screen_changed.connect(rebuild_menu)
	SaveManager.load_settings()
	SceneManager.bind(self)

func _process(_delta: float) -> void:
	hud.visible = SceneManager.screen == "game"
	hud.text = "Stamp x %d" % GameState.item_count(1)
	if GameState.timer_running: hud.text += "   %02d" % ceili(GameState.timer_frames / 60.0)
	virtual_controls.visible = SceneManager.screen == "game" and not SceneManager.paused and GameState.virtual_visible and DisplayServer.is_touchscreen_available()

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
			title.text = "Saved" if ok else SaveManager.last_error)
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
				AudioManager.music_volume = value
				AudioManager.bgm.volume_db = linear_to_db(maxf(value, 0.0001))
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
