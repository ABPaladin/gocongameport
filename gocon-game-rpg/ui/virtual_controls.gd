extends Control
## Original ALOE button artwork and positions. Mouse and touch share GUI input.
var held: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dpad = load(GameData.asset("VirtualButtons","JoystickBase_Arrows_00"))
	for entry in [["ui_up",Vector2i(1,0)],["ui_left",Vector2i(0,1)],["ui_right",Vector2i(2,1)],["ui_down",Vector2i(1,2)]]:
		var atlas = AtlasTexture.new()
		atlas.atlas = dpad
		atlas.region = Rect2(Vector2(entry[1] * 64),Vector2(64,64))
		add_button(entry[0],atlas,atlas,Vector2(16,404) + Vector2(entry[1] * 64))
	add_button("interact",load(GameData.asset("VirtualButtons","JButton_A_01")),load(GameData.asset("VirtualButtons","JButton_A_00")),Vector2(616,424))
	add_button("open_menu",load(GameData.asset("VirtualButtons","JButton_B_00")),load(GameData.asset("VirtualButtons","JButton_B_01")),Vector2(716,474))
	visibility_changed.connect(func():
		if not visible:
			for action in held.keys(): send_action(action,false))

func add_button(action: String, normal: Texture2D, pressed: Texture2D, at: Vector2) -> void:
	var button = TextureButton.new()
	button.texture_normal = normal
	button.texture_pressed = pressed
	button.position = at
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	button.button_down.connect(send_action.bind(action,true))
	button.button_up.connect(send_action.bind(action,false))

func send_action(action: String, pressed: bool) -> void:
	if pressed: held[action] = true
	else: held.erase(action)
	var event = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
