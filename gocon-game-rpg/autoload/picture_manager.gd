extends CanvasLayer
## MV picture IDs live in screen space, above map sprites and below windows.
var pictures: Dictionary = {}
var weather_type = "none"
var weather_power = 0.0
var weather_target = 0.0
var weather_frames = 0
var weather_canvas: Node2D
var particles: Array = []
var weather_rng = RandomNumberGenerator.new()

func _ready() -> void:
	layer = 5
	weather_rng.randomize()
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
	weather_target = 0
	weather_frames = 0
	particles.clear()
	weather_canvas.queue_redraw()

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
	if weather_power <= 0: weather_type = "none"
	update_particles()
	weather_canvas.queue_redraw()

func weather(p: Array) -> void:
	if str(p[0]) != "none": weather_type = str(p[0])
	weather_target = 0.0 if str(p[0]) == "none" else float(p[1])
	weather_frames = int(p[2])
	if weather_frames == 0:
		weather_power = weather_target
		if weather_power == 0: weather_type = "none"

func weather_origin() -> Vector2:
	if is_instance_valid(SceneManager.current_map):
		return SceneManager.current_map.camera.position - Vector2(408,312)
	return Vector2.ZERO

func update_particles() -> void:
	var count = int(weather_power * 10)
	while particles.size() < count: particles.append({"at":Vector2.ZERO,"opacity":0.0})
	particles.resize(count)
	var speed = 3.0 if weather_type == "snow" else (8.0 if weather_type == "storm" else 6.0)
	var angle = PI / 8 if weather_type == "storm" else PI / 16
	for particle in particles:
		particle.at += Vector2(-sin(angle),cos(angle)) * speed
		particle.opacity -= speed
		if particle.opacity < 40:
			particle.at = weather_origin() + Vector2(weather_rng.randi_range(-100,815),weather_rng.randi_range(-200,623))
			particle.opacity = weather_rng.randi_range(160,219)

func _draw_weather() -> void:
	if weather_power <= 0: return
	weather_canvas.draw_rect(Rect2(0,0,816,624),Color(80.0/255,80.0/255,80.0/255,floor(weather_power * 6)/255))
	var zoom = SceneManager.current_map.camera.zoom.x if is_instance_valid(SceneManager.current_map) else 1.0
	for particle in particles:
		var at = (particle.at - weather_origin() - Vector2(408,312)) * zoom + Vector2(408,312)
		var color = Color(1,1,1,particle.opacity/255)
		if weather_type == "snow": weather_canvas.draw_circle(at + Vector2(4,4).rotated(PI / 16) * zoom,4 * zoom,color)
		else:
			var length_px = 100 if weather_type == "storm" else 60
			var angle = PI / 8 if weather_type == "storm" else PI / 16
			weather_canvas.draw_line(at,at + Vector2(-sin(angle),cos(angle)) * length_px * zoom,color,(2 if weather_type == "storm" else 1) * zoom)
