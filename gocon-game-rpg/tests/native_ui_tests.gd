extends Node
## Runs the normal UI in a rendered Windows validation export. Input is simulated
## inside Godot; no OS input injection or physical-device claim is made.
var failures: Array[String] = []
var main
var output: String

func _ready() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func check(condition: bool, message: String) -> void:
	print("CHECK ",message,": ",condition)
	if not condition: failures.append(message)

func focus_button(text: String) -> void:
	for button in main.menu.find_children("*","Button",true,false):
		if button.text == text:
			button.grab_focus()
			return
	failures.append("Button missing: " + text)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var picture = get_viewport().get_texture().get_image()
	check(picture.save_png(output.path_join(name + ".png")) == OK,"Capture " + name)

func run() -> void:
	output = OS.get_executable_path().get_base_dir()
	SaveManager.save_path = "user://migration_native_checkpoint.json"
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await frames(10)
	check(SceneManager.screen == "title","Native title")
	var reload_only = "--continue-only" in OS.get_cmdline_user_args()
	if not reload_only:
		await capture("title")
		await tap(KEY_ENTER)
		await frames(40)
		check(SceneManager.screen == "game" and GameState.map_id == 6,"New Game through title input")
		for frame in 1800:
			if GameState.get_self_switch(6,12,"A") and SceneManager.current_map.foreground_runner == null: break
			if frame % 20 == 0: key(KEY_ENTER,true)
			if frame % 20 == 2: key(KEY_ENTER,false)
			await frames(1)
		key(KEY_ENTER,false)
		check(GameState.get_self_switch(6,12,"A"),"Intro through dialogue input")
		check(GameState.player_tile == Vector2i(14,39),"Intro destination")
		key(KEY_LEFT,true)
		await frames(20)
		key(KEY_LEFT,false)
		await frames(20)
		check(GameState.player_tile.x < 14,"Native keyboard movement")
		await tap(KEY_ESCAPE)
		check(SceneManager.paused,"Pause input")
		await tap(KEY_DOWN)
		await tap(KEY_ENTER)
		check(not SaveManager.read_save().is_empty(),"Save through pause UI")
		await capture("saved")
		focus_button("Return to title")
		await tap(KEY_ENTER)
		check(SceneManager.screen == "title","Return to title UI")
	var checkpoint = SaveManager.read_save()
	check(not checkpoint.is_empty(),"Persistent checkpoint exists")
	focus_button("Continue")
	await tap(KEY_ENTER)
	await frames(12)
	check(SceneManager.screen == "game" and GameState.map_id == 6,"Continue through title UI")
	check(GameState.player_tile.x < 14 and GameState.player_tile.y == 39,"Continue restores movement")
	check(GameState.get_self_switch(6,12,"A"),"Continue retains intro completion")
	await capture("continued_after_restart" if reload_only else "continued")
	var report = {"mode":"restart" if reload_only else "gameplay","failures":failures,"map":GameState.map_id,"x":GameState.player_tile.x,"y":GameState.player_tile.y,"renderer":RenderingServer.get_video_adapter_name()}
	var file = FileAccess.open(output.path_join("restart.json" if reload_only else "gameplay.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	if reload_only and failures.is_empty(): DirAccess.remove_absolute(SaveManager.save_path)
	SceneManager.title()
	AudioManager.stop_se()
	await frames(15)
	print("NATIVE UI FAILURES: ",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
