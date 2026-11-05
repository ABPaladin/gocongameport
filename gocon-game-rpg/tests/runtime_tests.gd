extends Node
var failures: Array[String] = []
var checks = 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error("TEST FAIL: " + description)

func _ready() -> void:
	call_deferred("run")

func command(code: int, p: Array = [], indent: int = 0) -> Dictionary:
	return {"code":code, "parameters":p, "indent":indent}

func test_passage() -> void:
	var fixture = GameMap.new()
	fixture.width = 3
	fixture.height = 3
	fixture.flags = [0,15,1,8,16]
	fixture.map_data = {"scrollType":0,"layers":[],"regions":[0,0,0,0,0,0,0,0,0]}
	for z in 4: fixture.map_data.layers.append([0,0,0,0,0,0,0,0,0])
	var player = MapActor.new()
	player.tile = Vector2i(1,1)
	fixture.player = player
	check(fixture.can_step(player,2),"Open tile passage")
	fixture.map_data.layers[3][4] = 2
	check(not fixture.can_step(player,2) and fixture.can_step(player,8),"Directional source passage")
	fixture.map_data.layers[3][4] = 0
	fixture.map_data.layers[3][7] = 3
	check(not fixture.can_step(player,2),"Reverse destination passage")
	player.through = true
	check(fixture.can_step(player,2),"Through bypasses passage")
	player.tile = Vector2i(1,2)
	check(not fixture.can_step(player,2),"Through still respects map bounds")
	player.through = false
	player.tile = Vector2i(1,1)
	fixture.map_data.layers[3][7] = 4
	fixture.map_data.layers[2][7] = 1
	check(not fixture.can_step(player,2),"Star tile defers to lower blocking layer")
	fixture.map_data.layers[2][7] = 0
	var npc = GameEvent.new()
	npc.tile = Vector2i(1,2)
	npc.active_page = {"trigger":0}
	fixture.events.append(npc)
	check(not fixture.can_step(player,2),"Normal event blocks player")
	npc.through = true
	check(fixture.can_step(player,2),"Through event does not block player")
	npc.through = false
	npc.tile = Vector2i(0,1)
	fixture.map_data.regions[6] = 1
	check(not fixture.can_step(npc,2),"NPC region restriction")
	check(not fixture.can_step(npc,6),"Player occupancy blocks NPC")
	npc.free()
	player.free()
	fixture.free()

func execute(list: Array, event = null, ticks: int = 1000):
	var world = SceneManager.current_map
	var runner = EventRunner.new(world, event, list)
	for i in ticks:
		runner.tick()
		for actor in world.events: actor.tick()
		world.player.tick()
		PictureManager._physics_process(1.0 / 60)
		if runner.done: break
	check(runner.done, "VM completes within budget")
	check(runner.diagnostics.is_empty(), "VM has no unsupported commands")
	return runner

func run() -> void:
	test_passage()
	var pad_button = InputEventJoypadButton.new()
	pad_button.button_index = JOY_BUTTON_A
	pad_button.pressed = true
	Input.parse_input_event(pad_button.duplicate())
	Input.flush_buffered_events()
	check(Input.is_action_pressed("interact"),"Gamepad A maps to interaction")
	pad_button.pressed = false
	Input.parse_input_event(pad_button.duplicate())
	Input.flush_buffered_events()
	pad_button.button_index = JOY_BUTTON_DPAD_LEFT
	pad_button.pressed = true
	Input.parse_input_event(pad_button.duplicate())
	Input.flush_buffered_events()
	check(Input.is_action_pressed("ui_left"),"Gamepad D-pad maps to movement")
	pad_button.pressed = false
	Input.parse_input_event(pad_button.duplicate())
	Input.flush_buffered_events()
	var stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	Input.parse_input_event(stick.duplicate())
	Input.flush_buffered_events()
	check(Input.is_action_pressed("ui_left"),"Gamepad analog stick maps to movement")
	stick.axis_value = 0
	Input.parse_input_event(stick.duplicate())
	Input.flush_buffered_events()
	SceneManager.transitions_enabled = false
	AudioManager.playback_enabled = false
	DialogueManager.automation = true
	# Advance simulation explicitly, including maps created by deferred transfers.
	SceneManager.screen_changed.connect(func():
		if is_instance_valid(SceneManager.current_map): SceneManager.current_map.set_physics_process(false))
	SceneManager.bind(self)
	SceneManager.new_game()
	var world = SceneManager.current_map
	world.set_physics_process(false)
	check(world.map_id == 6 and world.player.tile == Vector2i(14,41), "New game map/start")
	check(world.camera_center(Vector2(112,112)) == Vector2(408,312),"MV camera uses unzoomed viewport at map boundary")
	world.player.step(8)
	for tick in 10: world.player.tick()
	check(world.player.pattern == 2,"Walking animation uses MV 1.5 counter increment")
	for tick in 22: world.player.tick()
	check(world.player.pattern == 1 and not world.player.moving(),"Walking animation settles to original frame")
	for id in range(1,5): check(GameState.get_switch(id), "Overlay startup switch %d" % id)
	for id in range(1,14):
		SceneManager.load_map(id, Vector2i(14,14))
		world = SceneManager.current_map
		world.set_physics_process(false)
		check(world.events.size() == GameData.maps[id].events.size(), "Map %d events instantiate" % id)
	SceneManager.load_map(6, Vector2i(14,41))
	world = SceneManager.current_map
	world.set_physics_process(false)
	execute([command(122,[1,1,0,0,4]), command(111,[1,1,0,4,0]),
		command(126,[1,0,0,1],1), command(411), command(126,[1,0,0,10],1),
		command(412), command(0)])
	check(GameState.item_count(1) == 1, "Conditional excludes else reward")
	DialogueManager.automated_choice = 1
	execute([command(102,[["A","B"],1,0,2,0]), command(402,[0,"A"]),
		command(122,[9,9,0,0,10],1),command(402,[1,"B"]),
		command(122,[9,9,0,0,20],1),command(404),command(0)])
	check(GameState.get_variable(9) == 20, "Choice executes selected branch only")
	execute([command(112),command(122,[9,9,1,0,1],1),command(111,[1,9,0,23,0],1),
		command(113,[],2),command(412,[],1),command(413),command(0)])
	check(GameState.get_variable(9) == 23, "Loop and nested break")
	var endless = EventRunner.new(world, null, [command(112),command(413)])
	endless.tick()
	check(not endless.done, "Infinite loop yields without freezing")
	endless.cancel()
	check(endless.done, "VM cancellation")
	var route = {"list":[{"code":29,"parameters":[3]},{"code":15,"parameters":[2]},{"code":18},{"code":0}], "repeat":false,"skippable":false,"wait":true}
	execute([command(205,[-1,route]),command(122,[10,10,0,0,1]),command(0)])
	check(world.player.direction == 6 and not world.player.route_forced, "Forced route wait/restore")
	execute([command(231,[1,"bare",1,0,10,20,100,100,255,0]),
		command(232,[1,0,1,0,30,40,100,100,128,0,4,true]),command(0)])
	check(PictureManager.pictures[1].sprite.position == Vector2(30,40), "Picture movement completes")
	execute([command(235,[1]),command(124,[0,20]),command(0)])
	check(not PictureManager.pictures.has(1) and GameState.timer_frames == 1200, "Erase and timer start")
	GameState.timer_running = false
	PictureManager.weather(["snow",9,60,false])
	for tick in 60: PictureManager._physics_process(1.0/60)
	check(is_equal_approx(PictureManager.weather_power,9) and PictureManager.particles.size() == 90,"Source snow reaches power and particle count after 60 ticks")
	PictureManager.clear()
	check(PictureManager.particles.is_empty() and PictureManager.weather_frames == 0,"New game/picture clear cancels weather transition")
	for language in ["English","Romanian","Russian"]:
		GameState.language = language
		var source = GameData.translations.msg.keys()[0]
		check(not GameData.translate(source).is_empty(), "Translation available " + language)
	var event = world.events[0]
	GameState.set_self_switch(6,event.event_id,"A",true)
	check(event.conditions_met({"selfSwitchCh":"A"}), "Self switch page condition")
	check(not event.conditions_met({"switch1Id":999}), "False switch excludes page")
	var all_codes: Dictionary = {}
	for map in GameData.maps.values():
		for ev in map.events:
			for page in ev.pages:
				for c in page.list: all_codes[int(c.code)] = true
	for code in all_codes: check(code in EventRunner.SUPPORTED, "Observed opcode %d declared" % code)
	# Execute the actual intro with forced player/NPC movement and page refresh.
	GameState.new_game()
	SceneManager.load_map(6, Vector2i(14,41))
	world = SceneManager.current_map
	world.set_physics_process(false)
	for tick in 2000:
		world._physics_process(1.0 / 60)
		if GameState.get_self_switch(6,12,"A") and world.foreground_runner == null: break
	check(GameState.get_self_switch(6,12,"A"), "Original intro completes all movement/dialogue")
	check(world.player.tile == Vector2i(14,39), "Intro moved player two tiles north")
	check(GameState.virtual_visible, "Intro restores virtual buttons")
	# Transfer continuation must retain the original self-switch identity.
	var continuation_event = world.character(12, null)
	execute([command(201,[0,7,16,20,0,2]),command(123,["D",0]),command(356,["ZoomOut 2 30"]),command(0)], continuation_event)
	await get_tree().process_frame
	world = SceneManager.current_map
	world.set_physics_process(false)
	for tick in 35: world._physics_process(1.0 / 60)
	check(world.map_id == 7 and GameState.get_self_switch(6,12,"D"), "Transfer preserves source continuation identity")
	check(world.camera.zoom.is_equal_approx(Vector2.ONE), "Camera command uses reciprocal factor times default zoom")
	# Actual randomized rock-paper-scissors: repeat seeds until all outcomes occur.
	var outcomes = {}
	for seed_value in range(20):
		GameState.self_switches.erase("7,46,A")
		GameState.items_held.clear()
		GameState.variables.clear()
		GameState.rng.seed = seed_value
		var rps = world.character(46,null)
		rps.refresh_page()
		DialogueManager.automated_choice = 0
		execute(rps.command_list(), rps)
		outcomes[int(GameState.get_variable(2))] = true
		if GameState.item_count(1) > 0:
			rps.refresh_page()
			execute(rps.command_list(), rps)
			check(GameState.item_count(1) == 1, "RPS reward cannot repeat")
	check(outcomes.size() == 3, "RPS random win/loss/tie variants")
	GameState.new_game()
	SceneManager.load_map(8,Vector2i(16,20))
	world = SceneManager.current_map
	world.set_physics_process(false)
	DialogueManager.automated_choice = 0
	execute(world.character(1,null).command_list(), world.character(1,null))
	check(GameState.timer_frames == 1200 and GameState.get_switch(10), "Original projectile game start")
	for tick in 1201: world._physics_process(1.0 / 60)
	for tick in 5: world._physics_process(1.0 / 60)
	check(not GameState.timer_running and not GameState.get_switch(10), "Original projectile timeout/reset")
	# Win result uses original six nested switch checks and reward path.
	execute(world.character(1,null).data.pages[0].list, world.character(1,null))
	for id in range(12,18): GameState.set_switch(id,true)
	for tick in 10:
		world._physics_process(1.0 / 60)
		if world.transfer_pending: break
	await get_tree().process_frame
	check(GameState.item_count(1) == 1 and SceneManager.current_map.map_id == 7, "Projectile win rewards and transfers")
	# Actual QTE: press during the cursor movement wait, after the early failure checks.
	GameState.new_game()
	SceneManager.load_map(7,Vector2i(16,28))
	world = SceneManager.current_map
	world.set_physics_process(false)
	var qte = world.character(2,null)
	DialogueManager.automated_choice = 1
	execute(qte.command_list(),qte)
	check(not GameState.get_self_switch(7,2,"A") and PictureManager.pictures.is_empty(),"QTE decline leaves no active state")
	DialogueManager.automated_choice = 0
	for action in ["ui_up","ui_right","ui_left","ui_down"]:
		execute(qte.command_list(),qte)
		Input.action_press(action)
		world._physics_process(1.0 / 60)
		Input.action_release(action)
		for tick in 3: world._physics_process(1.0 / 60)
		check(qte.page_index == 0 and not GameState.get_self_switch(7,2,"A"),"QTE failure resets page: " + action)
		check(GameState.item_count(1) == 0 and PictureManager.pictures.is_empty(),"QTE failure clears pictures without reward: " + action)
	execute(qte.command_list(),qte)
	qte.refresh_page()
	check(qte.page_index == 1, "QTE switches to active parallel page")
	check(not SaveManager.checkpoint_allowed(), "Active QTE cannot save transient interpreter state")
	for tick in 1000:
		world._physics_process(1.0 / 60)
		if qte.runner != null and qte.runner.wait_frames > 0 and GameState.get_variable(2) >= 450 and GameState.get_variable(2) < 500:
			Input.action_press("ui_up")
			for press_tick in 3: world._physics_process(1.0 / 60)
			Input.action_release("ui_up")
			break
	for tick in 20: world._physics_process(1.0 / 60)
	check(GameState.item_count(1) == 1 and GameState.get_variable(1) == 1, "Original QTE success grants matching stamp states")
	check(qte.page_index == 2, "QTE success selects received-reward page")
	execute(qte.command_list(),qte)
	check(GameState.item_count(1) == 1, "QTE cannot award again")
	# Save tests use a dedicated disposable filename, never the player's checkpoint.
	GameState.timer_running = false
	world.foreground_runner = null
	world.player.locate(Vector2i(16,28))
	GameState.player_tile = world.player.tile
	SaveManager.save_path = "user://migration_test_checkpoint.json"
	PictureManager.weather(["snow",9,0,false])
	AudioManager.play_bgm(GameData.maps[6].bgm)
	var saved_bgm = AudioManager.current_bgm
	check(SaveManager.save_checkpoint(), "Checkpoint writes")
	GameState.gain_item(1,5)
	check(SaveManager.load_checkpoint(), "Checkpoint loads")
	check(GameState.item_count(1) == 1 and GameState.get_self_switch(7,2,"D"), "Checkpoint restores inventory and event pages")
	check(PictureManager.weather_type == "snow" and PictureManager.weather_power == 9,"Checkpoint restores weather")
	check(AudioManager.current_bgm == saved_bgm,"Checkpoint restores inherited BGM")
	check(SaveManager.save_checkpoint(), "Checkpoint replaces existing save atomically")
	var fixture = FileAccess.open(SaveManager.save_path,FileAccess.WRITE)
	fixture.store_string("{broken")
	fixture.close()
	check(SaveManager.read_save().is_empty(), "Corrupt save rejected")
	fixture = FileAccess.open(SaveManager.save_path,FileAccess.WRITE)
	fixture.store_string('{"version":999}')
	fixture.close()
	check(SaveManager.read_save().is_empty(), "Unknown save version rejected")
	DirAccess.remove_absolute(SaveManager.save_path)
	check(SaveManager.read_save().is_empty(), "Missing save handled")
	SaveManager.save_path = SaveManager.SAVE_PATH
	# Continue the earned QTE checkpoint through the three real trivia rewards.
	for entry in [[1,5,2],[2,1,0],[4,3,1]]:
		SceneManager.load_map(entry[0],Vector2i(10,10))
		world = SceneManager.current_map
		world.set_physics_process(false)
		var npc = world.character(entry[1],null)
		var before = GameState.item_count(1)
		DialogueManager.automated_choice = (entry[2] + 1) % 3
		execute(npc.command_list(),npc)
		check(GameState.item_count(1) == before,"Trivia wrong answer does not reward map %d" % entry[0])
		DialogueManager.automated_choice = entry[2]
		execute(npc.command_list(),npc)
		npc.refresh_page()
		execute(npc.command_list(),npc)
		check(GameState.item_count(1) == before + 1,"Trivia correct answer rewards once map %d" % entry[0])
	SceneManager.load_map(7,Vector2i(16,20))
	world = SceneManager.current_map
	world.set_physics_process(false)
	DialogueManager.automated_choice = 0
	for seed_value in 20:
		GameState.rng.seed = seed_value
		var rps = world.character(46,null)
		execute(rps.command_list(),rps)
		rps.refresh_page()
		if GameState.get_self_switch(7,46,"A"): break
	check(GameState.item_count(1) == 5,"Five rewards earned from actual QTE/trivia/RPS lists")
	SceneManager.load_map(8,Vector2i(16,20))
	world = SceneManager.current_map
	world.set_physics_process(false)
	execute(world.character(1,null).command_list(),world.character(1,null))
	# Fire through the real action event; moving targets and coordinate tests
	# produce all hit flags without injected wins or target repositioning.
	for tick in 1200:
		if not GameState.get_switch(11) and not world.input_locked():
			world.trigger_at(Vector2i(16,19),[0],true)
		world._physics_process(1.0 / 60)
		if world.transfer_pending: break
	await get_tree().process_frame
	check(GameState.item_count(1) == 6 and GameState.get_variable(1) == 6,"All six reward paths synchronize item and progression variable")
	SceneManager.load_map(4,Vector2i(10,10))
	world = SceneManager.current_map
	world.set_physics_process(false)
	execute(world.character(16,null).command_list(),world.character(16,null))
	await get_tree().process_frame
	check(SceneManager.current_map.map_id == 13,"Six-stamp gate reaches ending")
	world = SceneManager.current_map
	world.set_physics_process(false)
	for tick in 10:
		world._physics_process(1.0 / 60)
		if world.transfer_pending: break
	await get_tree().process_frame
	world = SceneManager.current_map
	world.set_physics_process(false)
	for tick in 3: world._physics_process(1.0 / 60)
	check(world.map_id == 12 and GameState.transparent and not GameState.virtual_visible,"Ending reaches final picture and hides player/controls")
	check(PictureManager.pictures.has(1),"Ending picture exists")
	execute([command(353),command(0)])
	check(SceneManager.screen == "game_over" and SceneManager.paused,"Game Over stops gameplay")
	print("RUNTIME TESTS: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("FAIL: " + failure)
	SceneManager.title()
	AudioManager.stop_se()
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
