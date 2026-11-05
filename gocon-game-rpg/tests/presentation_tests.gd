extends Node
## Deterministic renderer fixtures. Included only by the validation export preset.
func _ready() -> void:
	call_deferred("snapshot")

func snapshot() -> void:
	AudioManager.playback_enabled = false
	var main = load("res://Main.tscn").instantiate()
	add_child(main)
	GameState.new_game()
	var scenario = "qte"
	if OS.has_feature("web"):
		scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('snapshot') || 'qte'"))
	var map_id = {"qte":7,"projectiles":8,"ending":13,"credits":12,"edge":6}.get(scenario,7)
	var at = Vector2i(16,28) if map_id == 7 else (Vector2i(16,20) if map_id == 8 else Vector2i(11,16 if map_id == 13 else 17))
	if map_id == 6: at = Vector2i(3,3)
	SceneManager.load_map(map_id,at,2)
	var world = SceneManager.current_map
	world.set_physics_process(false)
	PictureManager.set_physics_process(false)
	if map_id == 7:
		for command in world.character(2,null).data.pages[0].list:
			if int(command.code) == 231: PictureManager.show_picture(command.parameters)
	elif map_id == 8:
		GameState.set_switch(10,true)
		for event in world.events: event.refresh_page()
		for command in world.character(1,null).data.pages[0].list:
			if int(command.code) == 203:
				var p = command.parameters
				world.character(int(p[0]),null).locate(Vector2i(int(p[2]),int(p[3])))
		GameState.timer_running = true
		GameState.timer_frames = 1200
		world.camera.zoom = Vector2.ONE
	elif map_id in [12,13]:
		GameState.transparent = true
		world.player.visible = false
		for command in world.character(1,null).data.pages[0].list:
			if int(command.code) == 231: PictureManager.show_picture(command.parameters)
			if int(command.code) == 356:
				var runner = EventRunner.new(world,world.character(1,null))
				runner.plugin_command(str(command.parameters[0]))
	for event in world.events: event.update_frame()
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.migrationSnapshotReady = " + JSON.stringify({"scenario":scenario,"map":map_id,"zoom":world.camera.zoom.x}))
