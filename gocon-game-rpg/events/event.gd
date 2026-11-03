class_name GameEvent
extends Node2D
## Un eveniment de pe hartă (NPC, obiect interactiv, ușă, declanșator invizibil).
##
## Se construiește complet din date (din data/maps/mapNNN.json), nu se pune
## nimic de mână în scenă. Face trei lucruri:
##   1. alege PAGINA activă (RPG Maker: câștigă pagina cu indexul cel mai mare
##      ale cărei condiții sunt îndeplinite);
##   2. afișează grafica paginii (dacă are) dintr-un spritesheet MV;
##   3. blochează playerul dacă pagina are priority = 1 ("same as player").
##
## Dialogul propriu-zis vine în pasul 2b (DialogueManager).

const TILE := 32
const FRAME := 48      ## un cadru de personaj MV are 48x48 px
const CHAR_DIR := "res://assets/characters/"

var event_id: int = 0
var grid_x: int = 0
var grid_y: int = 0
var data: Dictionary = {}          ## datele brute ale evenimentului
var active_page: Dictionary = {}   ## pagina aleasă acum
var page_index: int = -1

var sprite: Sprite2D
var body: StaticBody2D             ## există doar dacă evenimentul blochează

## Decalaj vizual pe verticală (px, negativ = mai sus). Vine din
## data/sprite_offsets.json. Ridică NPC-ii care stau în spatele tarabelor ca
## să li se vadă capul peste tejghea. Nu afectează coliziunea.
var sprite_y_offset: int = 0


## Construiește evenimentul din datele lui. Apelat de map.gd după add_child().
func setup(event_data: Dictionary, y_offset: int = 0) -> void:
	data = event_data
	sprite_y_offset = y_offset
	event_id = int(data.get("id", 0))
	grid_x = int(data.get("x", 0))
	grid_y = int(data.get("y", 0))
	# Poziționăm nodul în colțul stânga-sus al dalei (ca la player).
	position = Vector2(grid_x * TILE, grid_y * TILE)
	refresh_page()


## Re-evaluează ce pagină e activă. (De rechemat când se schimbă switch-urile.)
func refresh_page() -> void:
	active_page = {}
	page_index = -1
	var pages: Array = data.get("pages", [])
	# În RPG Maker câștigă ULTIMA pagină ale cărei condiții sunt îndeplinite.
	for i in range(pages.size() - 1, -1, -1):
		if _conditions_met(pages[i].get("conditions", {})):
			active_page = pages[i]
			page_index = i
			break
	_apply_graphic()
	_apply_collision()


## Deocamdată doar paginile fără condiții sunt active (nu avem încă switch-uri).
## În pasul 2b legăm asta de GameState.
func _conditions_met(cond: Dictionary) -> bool:
	return cond.is_empty()


# --- Grafică ---------------------------------------------------------------

func _apply_graphic() -> void:
	if sprite:
		sprite.queue_free()
		sprite = null
	if active_page.is_empty():
		return

	var image: Dictionary = active_page.get("image", {})
	var char_name := str(image.get("characterName", ""))
	if char_name == "":
		return                      # eveniment invizibil (declanșator/ușă)

	# În RPG Maker, prefixele "!" şi "$" sunt indicii pentru încărcător
	# (fără umbră / foaie cu un singur personaj), nu fac parte din nume.
	# La copierea asset-urilor le-am scos, deci le scoatem şi aici.
	var file_name := char_name.to_lower().lstrip("!$")
	var path := CHAR_DIR + file_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("[GameEvent %d] lipsește sprite-ul: %s" % [event_id, path])
		return

	sprite = Sprite2D.new()
	sprite.texture = load(path)
	sprite.region_enabled = true
	sprite.region_rect = _frame_rect(
		int(image.get("characterIndex", 0)),
		int(image.get("direction", 2)),
		1)                          # cadrul din mijloc = poziția „pe loc"
	# Același offset ca la player: sprite de 48px centrat pe dala de 32px, cu
	# picioarele pe marginea de jos. Plus decalajul vizual din sprite_offsets.
	sprite.offset = Vector2(16, 8 + sprite_y_offset)
	add_child(sprite)


## Calculează dreptunghiul unui cadru dintr-un spritesheet MV.
## Foaia are 4x2 personaje; fiecare personaj = 3 coloane (pași) x 4 rânduri
## (direcții: jos, stânga, dreapta, sus).
func _frame_rect(char_index: int, direction: int, pattern: int) -> Rect2:
	var block_x := (char_index % 4) * 3 * FRAME
	var block_y := int(char_index / 4.0) * 4 * FRAME
	var row := clampi(int(direction / 2.0) - 1, 0, 3)   # 2→0, 4→1, 6→2, 8→3
	var col := clampi(pattern, 0, 2)
	return Rect2(block_x + col * FRAME, block_y + row * FRAME, FRAME, FRAME)


# --- Coliziune -------------------------------------------------------------

## priority 1 = "same as player" → blochează. 0 (sub) și 2 (deasupra) → nu.
func _apply_collision() -> void:
	if body:
		body.queue_free()
		body = null
	if active_page.is_empty():
		return
	if int(active_page.get("priorityType", 0)) != 1:
		return

	body = StaticBody2D.new()
	body.collision_layer = 1        # același layer pe care îl vede RayCast-ul
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	cs.shape = rect
	cs.position = Vector2(TILE / 2.0, TILE / 2.0)   # centrul dalei
	body.add_child(cs)
	add_child(body)


# --- Utilitare pentru pasul 2b --------------------------------------------

## Afişează ID-ul evenimentului deasupra lui (mod debug).
## Îl foloseşti ca să ştii ce număr să pui în data/sprite_offsets.json.
func show_debug_id() -> void:
	var lbl := Label.new()
	lbl.text = str(event_id)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.position = Vector2(4, -22)
	lbl.z_index = 200            # peste stratul Foreground
	add_child(lbl)


func trigger_type() -> int:
	# 0 = apeși Z, 1 = atingere, 2 = contact, 3 = autorun, 4 = paralel
	return int(active_page.get("trigger", -1))


func command_list() -> Array:
	return active_page.get("list", [])
