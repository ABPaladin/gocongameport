class_name Player
extends Node2D
## Mișcare grid-based în stil RPG Maker: se deplasează exact o dală o dată,
## aliniat la grilă, cu tween între celule. Coliziunile sunt verificate cu un
## RayCast2D, deci funcționează cu orice zid fizic pe care îl pui tu manual.
##
## Structura de noduri așteptată:
##   Player (Node2D)          <- scriptul ăsta
##   ├── AnimatedSprite2D     (animații: idle_down/left/right/up, walk_down/...)
##   └── RayCast2D            (Collision Mask = layer-ul zidurilor)

@export var tile_size: int = 32          ## dimensiunea unei dale
@export var step_time: float = 0.15      ## secunde per pas (mai mic = mai rapid)

# Direcțiile mapate pe acțiunile default din Godot (săgețile).
const INPUTS := {
	"ui_up":    Vector2.UP,
	"ui_down":  Vector2.DOWN,
	"ui_left":  Vector2.LEFT,
	"ui_right": Vector2.RIGHT,
}

var is_moving: bool = false              ## true cât timp alunecă între dale
var facing: Vector2 = Vector2.DOWN       ## direcția în care privește

@onready var ray: RayCast2D = $RayCast2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Aliniem poziția de start exact pe grilă (în caz că am pus-o „pe ochi").
	position = position.snapped(Vector2(tile_size, tile_size))
	_play_anim("idle")


func _process(_delta: float) -> void:
	# Cât timp se mișcă sau rulează un dialog, ignorăm input-ul.
	if is_moving or DialogueManager.is_busy:
		return

	# Vorbim cu evenimentul din fața noastră.
	if Input.is_action_just_pressed("interact"):
		_try_interact()
		return

	# Verificăm direcțiile; prima tastă apăsată câștigă.
	for action in INPUTS:
		if Input.is_action_pressed(action):
			_try_move(INPUTS[action])
			return

	# Nicio tastă apăsată → stăm pe loc, în animația idle.
	_play_anim("idle")


## Încearcă un pas într-o direcție. Se întoarce spre acolo chiar dacă e blocat
## (exact ca în RPG Maker: te rotești pe loc dacă dai în perete).
func _try_move(dir: Vector2) -> void:
	facing = dir
	_play_anim("walk")

	# RayCast-ul „privește" o dală în direcția aleasă.
	ray.target_position = dir * tile_size
	ray.force_raycast_update()
	if ray.is_colliding():
		# Blocat. Poate e un eveniment de tip „atingere" (Totoro, Titanul):
		# alea blochează, deci nu poți păși pe ele — le declanșezi lovindu-le.
		var t := _my_tile()
		_trigger_event_at(t.x + int(dir.x), t.y + int(dir.y), 1)
		return

	_slide_to(position + dir * tile_size)


## Alunecă lin până la dala următoare.
func _slide_to(target: Vector2) -> void:
	is_moving = true
	var tween := create_tween()
	tween.tween_property(self, "position", target, step_time)
	await tween.finished
	is_moving = false
	# Am ajuns pe o dală nouă: dacă are un eveniment de tip „atingere" care NU
	# blochează (priority 0/2), se declanșează acum.
	var t := _my_tile()
	_trigger_event_at(t.x, t.y, 1)
	# Dacă mai ții tasta apăsată, _process pornește imediat pasul următor.


## Dala pe care stăm (nodul e în colțul stânga-sus al dalei).
func _my_tile() -> Vector2i:
	return Vector2i(
		int(round(position.x / tile_size)),
		int(round(position.y / tile_size)))


## Apeși Z → vorbește cu evenimentul din față (doar tipul „apeși Z").
func _try_interact() -> void:
	var t := _my_tile()
	_trigger_event_at(t.x + int(facing.x), t.y + int(facing.y), 0)


## Pornește evenimentul de pe dala (x, y), dacă are tipul de declanșare cerut.
##   wanted_trigger: 0 = apeși Z, 1 = atingere
func _trigger_event_at(x: int, y: int, wanted_trigger: int) -> void:
	if DialogueManager.is_busy:
		return
	var map := get_tree().get_first_node_in_group("game_map")
	if map == null:
		return
	var ev = map.event_at(x, y)
	if ev == null or ev.trigger_type() != wanted_trigger:
		return

	_play_anim("idle")
	await DialogueManager.run_event_commands(ev.command_list())


## Alege animația corectă în funcție de stare ("idle"/"walk") și direcție.
func _play_anim(state: String) -> void:
	var dir_name := "down"
	if facing == Vector2.UP:
		dir_name = "up"
	elif facing == Vector2.LEFT:
		dir_name = "left"
	elif facing == Vector2.RIGHT:
		dir_name = "right"

	var anim := "%s_%s" % [state, dir_name]   # ex. "walk_left"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
