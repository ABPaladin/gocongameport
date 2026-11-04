class_name EventRunner
extends RefCounted
## One VM per foreground/parallel event. No coroutine survives a map cancellation.
const SUPPORTED = [0,101,102,108,111,112,113,121,122,123,124,126,201,203,205,211,213,230,231,232,235,236,241,242,250,251,353,356,401,402,404,411,412,413,505]
var world
var event
var commands: Array
var pc = 0
var branch: Dictionary = {}
var wait_frames = 0
var wait_actor
var wait_balloon = false
var dialogue_ticket = -1
var choice_indent = -1
var done = false
var page_index = -1
var source_map_id = 0
var source_event_id = 0
var diagnostics: Array = []

func _init(map_node, source_event, list: Array = []) -> void:
	world = map_node
	event = source_event
	page_index = event.page_index if event != null else -1
	source_map_id = world.map_id
	source_event_id = event.event_id if event != null else 0
	commands = list if not list.is_empty() else event.command_list()

func cancel() -> void: done = true

func fail(message: String) -> void:
	var location = "map=%d event=%d page=%d command=%d" % [world.map_id, event.event_id if event != null else 0, page_index + 1, pc]
	diagnostics.append(location + ": " + message)
	push_error(diagnostics.back())
	done = true

func skip_branch(indent: int) -> void:
	while pc + 1 < commands.size() and int(commands[pc + 1].indent) > indent: pc += 1

func tick() -> void:
	if done: return
	if wait_frames > 0:
		wait_frames -= 1
		return
	if is_instance_valid(wait_actor):
		if wait_actor.balloon_frames > 0 if wait_balloon else wait_actor.route_forced: return
		wait_actor = null
	if dialogue_ticket >= 0:
		if not DialogueManager.completed.has(dialogue_ticket): return
		if choice_indent >= 0: branch[choice_indent] = DialogueManager.completed[dialogue_ticket]
		DialogueManager.completed.erase(dialogue_ticket)
		dialogue_ticket = -1
		choice_indent = -1
	for _budget in range(100):
		if pc >= commands.size():
			done = true
			return
		var c: Dictionary = commands[pc]
		var p: Array = c.parameters
		var code = int(c.code)
		var indent = int(c.indent)
		match code:
			0,108,401,404,412,505: pass
			101:
				if DialogueManager.is_busy: return
				var lines: Array[String] = []
				while pc + 1 < commands.size() and int(commands[pc + 1].code) == 401:
					pc += 1
					lines.append(str(commands[pc].parameters[0]))
				dialogue_ticket = DialogueManager.message("\n".join(lines), p)
			102:
				if DialogueManager.is_busy: return
				dialogue_ticket = DialogueManager.choices(p)
				choice_indent = indent
			402:
				if branch.get(indent, -999) != int(p[0]): skip_branch(indent)
			111:
				branch[indent] = condition(p)
				if not branch[indent]: skip_branch(indent)
			411:
				if branch.get(indent, false): skip_branch(indent)
			112: pass
			413:
				pc -= 1
				while pc >= 0 and int(commands[pc].indent) != indent: pc -= 1
			113:
				var depth = 0
				while pc + 1 < commands.size():
					pc += 1
					if int(commands[pc].code) == 112: depth += 1
					if int(commands[pc].code) == 413:
						if depth == 0: break
						depth -= 1
			121:
				for id in range(int(p[0]), int(p[1]) + 1): GameState.set_switch(id, int(p[2]) == 0)
			122: control_variables(p)
			123: GameState.set_self_switch(source_map_id, source_event_id, str(p[0]), int(p[1]) == 0)
			124:
				GameState.timer_running = int(p[0]) == 0
				if GameState.timer_running: GameState.timer_frames = int(p[1]) * 60
			126:
				var amount = int(p[3]) if int(p[2]) == 0 else int(GameState.get_variable(int(p[3])))
				GameState.gain_item(int(p[0]), amount if int(p[1]) == 0 else -amount)
			201:
				var mid = int(p[1]) if int(p[0]) == 0 else int(GameState.get_variable(int(p[1])))
				var x = int(p[2]) if int(p[0]) == 0 else int(GameState.get_variable(int(p[2])))
				var y = int(p[3]) if int(p[0]) == 0 else int(GameState.get_variable(int(p[3])))
				var continuation = {"commands":commands, "pc":pc + 1, "branch":branch.duplicate(), "map":source_map_id, "event":source_event_id, "page":page_index}
				SceneManager.transfer(mid, Vector2i(x, y), int(p[4]), int(p[5]), continuation)
				done = true
			203:
				var actor = world.character(int(p[0]), event)
				if actor != null:
					if int(p[1]) == 2:
						var other = world.character(int(p[2]), event)
						if other != null:
							var original = actor.tile
							actor.locate(other.tile, int(p[4]))
							other.locate(original)
					else:
						var at = Vector2i(int(p[2]), int(p[3])) if int(p[1]) == 0 else Vector2i(int(GameState.get_variable(int(p[2]))), int(GameState.get_variable(int(p[3]))))
						actor.locate(at, int(p[4]))
			205:
				var actor = world.character(int(p[0]), event)
				if actor != null:
					actor.force_route(p[1])
					if p[1].get("wait", false):
						wait_actor = actor
						wait_balloon = false
			211: GameState.transparent = int(p[0]) == 0
			213:
				var actor = world.character(int(p[0]), event)
				if actor != null:
					actor.balloon(int(p[1]))
					if p.size() > 2 and p[2]:
						wait_actor = actor
						wait_balloon = true
			230: wait_frames = int(p[0])
			231: PictureManager.show_picture(p)
			232:
				PictureManager.move_picture(p)
				if p[11]: wait_frames = int(p[10])
			235: PictureManager.erase_picture(int(p[0]))
			236:
				PictureManager.weather(p)
				if p[3]: wait_frames = int(p[2])
			241: AudioManager.play_bgm(p[0])
			242: AudioManager.fade_bgm(float(p[0]))
			250: AudioManager.play_se(p[0])
			251: AudioManager.stop_se()
			353:
				SceneManager.game_over()
				done = true
			356: plugin_command(str(p[0]))
			_: fail("Unsupported opcode %d" % code)
		pc += 1
		if done or wait_frames > 0 or is_instance_valid(wait_actor) or dialogue_ticket >= 0: return
	# A loop budget yields; subsequent simulation ticks continue the same VM.

func condition(p: Array) -> bool:
	match int(p[0]):
		0: return GameState.get_switch(int(p[1])) == (int(p[2]) == 0)
		1:
			var a = GameState.get_variable(int(p[1]))
			var b = p[3] if int(p[2]) == 0 else GameState.get_variable(int(p[3]))
			match int(p[4]):
				0: return a == b
				1: return a >= b
				2: return a <= b
				3: return a > b
				4: return a < b
				5: return a != b
		2: return GameState.get_self_switch(source_map_id, source_event_id, str(p[1])) == (int(p[2]) == 0)
		3:
			if not GameState.timer_running: return false
			var seconds = int(GameState.timer_frames / 60)
			return seconds >= int(p[1]) if int(p[2]) == 0 else seconds <= int(p[1])
		8: return GameState.item_count(int(p[1])) > 0
		11:
			var action = {"up":"ui_up","down":"ui_down","left":"ui_left","right":"ui_right","ok":"interact","cancel":"open_menu"}.get(str(p[1]), "")
			if action == "": fail("Unsupported button " + str(p[1]))
			return action != "" and Input.is_action_pressed(action)
	fail("Unsupported condition parameters " + str(p))
	return false

func control_variables(p: Array) -> void:
	var value = 0
	match int(p[3]):
		0: value = p[4]
		1: value = GameState.get_variable(int(p[4]))
		2: pass
		3:
			if int(p[4]) != 5 or int(p[6]) not in [0,1,2]:
				fail("Unsupported game-data operand " + str(p))
				return
			var actor = world.character(int(p[5]), event)
			if actor != null: value = [actor.tile.x, actor.tile.y, actor.direction][int(p[6])]
		_:
			fail("Unsupported variable operand " + str(p))
			return
	for id in range(int(p[0]), int(p[1]) + 1):
		if int(p[3]) == 2: value = GameState.rng.randi_range(int(p[4]), int(p[5]))
		var old = GameState.get_variable(id)
		match int(p[2]):
			0: GameState.set_variable(id, value)
			1: GameState.set_variable(id, old + value)
			2: GameState.set_variable(id, old - value)
			3: GameState.set_variable(id, old * value)
			4: GameState.set_variable(id, floor(float(old) / value) if value != 0 else 0)
			5: GameState.set_variable(id, fmod(old, value) if value != 0 else 0)
			_: fail("Unsupported variable operation " + str(p))

func plugin_command(text: String) -> void:
	var parts = text.split(" ", false)
	match parts[0].to_lower():
		"virtualbuttons", "mobileui":
			if parts.size() == 3 and parts[2].to_lower() == "all" and parts[1].to_lower() in ["show","hide"]:
				GameState.virtual_visible = parts[1].to_lower() == "show"
			else: fail("Unsupported virtual button command " + text)
		"zoomout":
			world.zoom_target = 1.0 / float(parts[1])
			world.zoom_frames = int(parts[2])
		"aivisibile":
			# Original misspelling is an intentional compatibility no-op.
			pass
		"aivisible": GameState.indicators_visible = parts[1].to_lower() == "true"
		_: fail("Unsupported plugin command " + text)
