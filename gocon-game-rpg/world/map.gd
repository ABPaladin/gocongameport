class_name GameMap
extends Node2D
## Construiește automat coliziunile unei hărți din datele extrase din jocul
## RPG Maker original (data/maps/mapNNN.json → câmpul "collision").
##
## Grila de coliziune e un array plat: 1 = zid, 0 = liber, index = y*width + x.
## Ca să nu creăm mii de noduri, unim celulele blocate vecine pe orizontală
## într-un singur dreptunghi (ex. un zid de 30 de dale = 1 formă, nu 30).
##
## Structura de noduri așteptată:
##   Level06 (Node2D)        <- scriptul ăsta, cu map_id = 6
##   ├── Ground (Sprite2D)        (o pui tu: assets/maps/level06/ground.png)
##   ├── Entities (Node2D)        (y_sort_enabled = true; player + NPC-uri)
##   ├── Foreground (Sprite2D)    (assets/maps/level06/foreground.png)
##   └── Collisions (Node2D)      <- aici se generează zidurile (opțional)

const TILE := 32

## Ce hartă încarcă (6 = level06 → data/maps/map006.json).
@export var map_id: int = 1
## Pe ce layer fizic stau zidurile (RayCast2D-ul playerului trebuie să aibă
## același număr bifat la Mask).
@export var collision_layer: int = 1
## Poți dezactiva dacă vrei să desenezi coliziunile complet manual.
@export var build_collision: bool = true
## Afișează ID-ul fiecărui eveniment pe ecran (galben). Îl aprinzi ca să vezi
## ce numere să pui în data/sprite_offsets.json când reglezi înălțimile NPC-ilor.
@export var debug_show_event_ids: bool = false
## Afișează pe ecran dala pe care stă playerul. Îl aprinzi ca să afli
## coordonatele pe care să le pui în data/extra_collision.json.
@export var debug_show_player_tile: bool = false

var _tile_label: Label

var width: int = 0
var height: int = 0
var collision: Array = []       ## 1 = zid, 0 = liber
var map_data: Dictionary = {}


## Lista evenimentelor instanțiate (utilă mai târziu pentru dialoguri).
var events: Array[GameEvent] = []


func _ready() -> void:
	# Playerul găsește harta prin grupul ăsta (nu depinde de poziția în arbore).
	add_to_group("game_map")
	if not _load_data():
		return
	if build_collision:
		_build_collision()
	_spawn_events()
	if debug_show_player_tile:
		_build_tile_readout()


## Etichetă de debug: arată dala pe care stă playerul, în colţul ecranului.
func _build_tile_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_tile_label = Label.new()
	_tile_label.position = Vector2(8, 8)
	_tile_label.add_theme_font_size_override("font_size", 16)
	_tile_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_tile_label.add_theme_constant_override("outline_size", 4)
	_tile_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_tile_label)


func _process(_delta: float) -> void:
	if _tile_label == null:
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null:
		# fallback: căutăm playerul sub Entities
		var ent := get_node_or_null("Entities")
		if ent:
			for c in ent.get_children():
				if c is Player:
					pl = c
					break
	if pl:
		var tx := int(round(pl.position.x / TILE))
		var ty := int(round(pl.position.y / TILE))
		_tile_label.text = "dala: [%d, %d]" % [tx, ty]


## Citește data/maps/mapNNN.json. Întoarce false dacă lipsește.
func _load_data() -> bool:
	var path := "res://data/maps/map%03d.json" % map_id
	if not FileAccess.file_exists(path):
		push_warning("[GameMap] lipsește fișierul: " + path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[GameMap] JSON invalid: " + path)
		return false
	map_data = parsed
	width = int(map_data.get("width", 0))
	height = int(map_data.get("height", 0))
	collision = map_data.get("collision", [])
	_merge_extra_collision()
	return true


## Adaugă peste coliziunile din datele originale şi dalele generate din arta
## din `foreground` (baza tejghelelor, trunchiurilor, gardurilor).
##
## Jocul original nu le avea blocate, pentru că acolo stratul foreground nici
## nu se afişa. La noi se afişează, deci obiectele trebuie să fie solide —
## altfel intri cu playerul prin ele.
##
## Fişierul data/extra_collision.json e generat automat, dar îl poţi edita:
## ştergi perechi [x,y] ca să deblochezi, adaugi ca să blochezi.
func _merge_extra_collision() -> void:
	var path := "res://data/extra_collision.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var cells: Array = parsed.get(str(map_id), [])
	for c in cells:
		var x := int(c[0])
		var y := int(c[1])
		if x >= 0 and y >= 0 and x < width and y < height:
			collision[y * width + x] = 1


## Creează UN StaticBody2D cu mai multe dreptunghiuri de coliziune.
func _build_collision() -> void:
	if collision.is_empty():
		return

	var body := StaticBody2D.new()
	body.name = "GeneratedCollision"
	body.collision_layer = collision_layer
	body.collision_mask = 0          # zidurile nu trebuie să detecteze nimic
	# Dacă ai un nod "Collisions" în scenă, punem zidurile acolo; altfel direct.
	var parent: Node = get_node_or_null("Collisions")
	if parent == null:
		parent = self
	parent.add_child(body)

	var shapes := 0
	for y in height:
		var x := 0
		while x < width:
			if int(collision[y * width + x]) != 1:
				x += 1
				continue
			# Am găsit începutul unui zid: mergem cât ține pe orizontală.
			var start := x
			while x < width and int(collision[y * width + x]) == 1:
				x += 1
			var run := x - start            # câte dale are zidul ăsta

			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(run * TILE, TILE)
			cs.shape = rect
			# Poziția e CENTRUL dreptunghiului.
			cs.position = Vector2(start * TILE + run * TILE / 2.0, y * TILE + TILE / 2.0)
			body.add_child(cs)
			shapes += 1

	print("[GameMap] map %d: %d celule blocate → %d forme de coliziune"
		% [map_id, _count_blocked(), shapes])


## Creează câte un nod GameEvent pentru fiecare eveniment din datele hărții.
## Le punem sub "Entities" ca să intre în y-sort (cine e mai jos se desenează
## în față), împreună cu playerul.
func _spawn_events() -> void:
	var parent: Node = get_node_or_null("Entities")
	if parent == null:
		parent = self

	var offsets := _load_sprite_offsets()
	var blocking := 0
	for event_data in map_data.get("events", []):
		var ev := GameEvent.new()
		# Atenție: JSON poate întoarce id-ul ca float (6.0), iar str(6.0) NU e
		# egal cu cheia "6". De aceea normalizăm prin int().
		var eid := str(int(event_data.get("id", 0)))
		ev.name = "Event" + eid
		parent.add_child(ev)
		ev.setup(event_data, int(offsets.get(eid, 0)))
		if debug_show_event_ids:
			ev.show_debug_id()
		events.append(ev)
		if ev.body != null:
			blocking += 1

	print("[GameMap] map %d: %d evenimente (%d blochează)"
		% [map_id, events.size(), blocking])


## Citește decalajele vizuale pentru harta asta din data/sprite_offsets.json.
## Fișierul e opțional — dacă lipsește, toate evenimentele stau normal.
func _load_sprite_offsets() -> Dictionary:
	var path := "res://data/sprite_offsets.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed.get(str(map_id), {})


func _count_blocked() -> int:
	var n := 0
	for c in collision:
		if int(c) == 1:
			n += 1
	return n


## Evenimentul de pe dala (x, y), dacă există și are o pagină activă.
func event_at(x: int, y: int) -> GameEvent:
	for ev in events:
		if ev.grid_x == x and ev.grid_y == y and not ev.active_page.is_empty():
			return ev
	return null


## Utilitar: e liberă dala (x, y)? (folositor mai târziu pentru NPC-uri)
func is_passable(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	return int(collision[y * width + x]) != 1
