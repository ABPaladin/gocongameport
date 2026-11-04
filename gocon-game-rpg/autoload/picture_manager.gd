extends CanvasLayer
## MV picture IDs live in screen space, above map sprites and below windows.
var pictures: Dictionary = {}
var weather_type = "none"
var weather_power = 0.0
var weather_target = 0.0
var weather_frames = 0
var weather_canvas: Node2D

func _ready() -> void:
	layer = 5
	weather_canvas = Node2D.new()
	add_child(weather_canvas)
	weather_canvas.draw.connect(_draw_weather)

func show_picture(p: Array) -> void:
	erase_picture(int(p[0]))
	var sprite = Sprite2D.new()
	sprite.texture = load(GameData.asset("pictures", str(p[1])))
	sprite.z_index = int(p[0])
	add_child(sprite)
	pictures[int(p[0])] = {"sprite":sprite, "frames":0}
	apply(sprite, p)

func apply(sprite: Sprite2D, p: Array) -> void:
	sprite.centered = int(p[2]) == 1
	sprite.position = coordinates(p)
	sprite.scale = Vector2(float(p[6]), float(p[7])) / 100.0
	sprite.modulate.a = float(p[8]) / 255.0
	var material = CanvasItemMaterial.new()
	material.blend_mode = [CanvasItemMaterial.BLEND_MODE_MIX, CanvasItemMaterial.BLEND_MODE_ADD, CanvasItemMaterial.BLEND_MODE_MUL, CanvasItemMaterial.BLEND_MODE_MIX][clampi(int(p[9]), 0, 3)]
	sprite.material = material
	if int(p[9]) == 3:
		var screen_material = ShaderMaterial.new()
		screen_material.shader = load("res://systems/picture_screen.gdshader")
		sprite.material = screen_material

func coordinates(p: Array) -> Vector2:
	return Vector2(float(p[4]), float(p[5])) if int(p[3]) == 0 else Vector2(float(GameState.get_variable(int(p[4]))), float(GameState.get_variable(int(p[5]))))

func move_picture(p: Array) -> void:
	if not pictures.has(int(p[0])): return
	var data: Dictionary = pictures[int(p[0])]
	data.sprite.centered = int(p[2]) == 1
	data.target = coordinates(p)
	data.scale = Vector2(float(p[6]), float(p[7])) / 100.0
	data.opacity = float(p[8]) / 255.0
	data.frames = int(p[10])
	if data.frames <= 0: apply(data.sprite, p)

func erase_picture(id: int) -> void:
	if pictures.has(id):
		pictures[id].sprite.queue_free()
		pictures.erase(id)

func clear() -> void:
	for id in pictures.keys(): erase_picture(id)
	weather_type = "none"
	weather_power = 0

func _physics_process(_delta: float) -> void:
	if SceneManager.paused: return
	for data in pictures.values():
		var n = int(data.frames)
		if n <= 0: continue
		data.sprite.position = (data.sprite.position * (n - 1) + data.target) / n
		data.sprite.scale = (data.sprite.scale * (n - 1) + data.scale) / n
		data.sprite.modulate.a = (data.sprite.modulate.a * (n - 1) + data.opacity) / n
		data.frames -= 1
	if weather_frames > 0:
		weather_power = (weather_power * (weather_frames - 1) + weather_target) / weather_frames
		weather_frames -= 1
	weather_canvas.queue_redraw()

func weather(p: Array) -> void:
	weather_type = str(p[0])
	weather_target = 0.0 if weather_type == "none" else float(p[1])
	weather_frames = int(p[2])
	if weather_frames == 0: weather_power = weather_target

func _draw_weather() -> void:
	if weather_power <= 0: return
	var tick = Engine.get_physics_frames()
	for i in int(weather_power * 10):
		var at = Vector2(posmod(i * 137 + tick * 2, 816), posmod(i * 73 + tick * 7, 624))
		if weather_type == "snow": weather_canvas.draw_circle(at, 2, Color(1,1,1,0.7))
		else: weather_canvas.draw_line(at, at + Vector2(-3,12), Color(0.8,0.9,1,0.6), 1)
