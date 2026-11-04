extends Node
signal dialogue_started
signal dialogue_ended
var box: DialogueBox
var is_busy = false
var completed: Dictionary = {}
var serial = 0
var generation = 0
var choice_layer: CanvasLayer
var choice_cancel = -1
var choice_ticket = -1
var automation = false
var automated_choice = 0
var history: Array = []

func _ready() -> void:
	box = load("res://ui/dialogue/DialogueBox.tscn").instantiate()
	add_child(box)
	choice_layer = CanvasLayer.new()
	choice_layer.layer = 20
	add_child(choice_layer)

func message(source: String, parameters: Array) -> int:
	serial += 1
	var ticket = serial
	is_busy = true
	dialogue_started.emit()
	var text = GameData.translate(source)
	history.append(text)
	if automation:
		completed[ticket] = 0
		is_busy = false
	else: _present(ticket, generation, text, parameters)
	return ticket

func format_text(text: String) -> Dictionary:
	var speaker = ""
	var regex = RegEx.new()
	regex.compile("(?i)\\\\n<([^>]+)>")
	var found = regex.search(text)
	if found:
		speaker = found.get_string(1)
		text = regex.sub(text, "", true)
	regex.compile("(?i)\\\\V\\[(\\d+)\\]")
	for match_result in regex.search_all(text):
		text = text.replace(match_result.get_string(), str(GameState.get_variable(int(match_result.get_string(1)))))
	regex.compile("(?i)\\\\N\\[(\\d+)\\]")
	for match_result in regex.search_all(text):
		text = text.replace(match_result.get_string(), str(GameData.actors.get(match_result.get_string(1), {}).get("name", "")))
	return {"text":text, "speaker":speaker}

func _present(ticket: int, epoch: int, text: String, parameters: Array) -> void:
	var formatted = format_text(text)
	var face = GameData.asset("faces", str(parameters[0]))
	await box.show_message(formatted.text, formatted.speaker, face, int(parameters[1]), int(parameters[3]))
	if epoch != generation: return
	await box.hide_box()
	completed[ticket] = 0
	is_busy = false
	dialogue_ended.emit()

func choices(parameters: Array) -> int:
	serial += 1
	choice_ticket = serial
	is_busy = true
	choice_cancel = int(parameters[1])
	if automation:
		_select(clampi(automated_choice, 0, parameters[0].size() - 1))
		return serial
	var panel = PanelContainer.new()
	panel.position = Vector2(490, 230)
	panel.custom_minimum_size = Vector2(300, 0)
	choice_layer.add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	for i in parameters[0].size():
		var button = Button.new()
		button.text = GameData.translate(str(parameters[0][i]), "cmd")
		button.custom_minimum_size.y = 42
		column.add_child(button)
		button.pressed.connect(_select.bind(i))
	var initial = clampi(int(parameters[2]), 0, column.get_child_count() - 1)
	column.get_child(initial).grab_focus()
	return serial

func _select(index: int) -> void:
	if choice_ticket < 0: return
	completed[choice_ticket] = index
	choice_ticket = -1
	for child in choice_layer.get_children(): child.queue_free()
	is_busy = false
	dialogue_ended.emit()

func _unhandled_input(event: InputEvent) -> void:
	if choice_ticket >= 0 and event.is_action_pressed("open_menu") and choice_cancel != -1:
		_select(choice_cancel)
		get_viewport().set_input_as_handled()

func cancel() -> void:
	generation += 1
	choice_ticket = -1
	for child in choice_layer.get_children(): child.queue_free()
	if box._is_open: box.finished.emit()
	box._reset_state()
	is_busy = false
	completed.clear()
