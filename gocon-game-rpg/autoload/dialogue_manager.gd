extends Node
## DialogueManager (autoload)
##
## Singurul loc prin care se pornesc dialoguri. Creează singur caseta la
## pornirea jocului, ca s-o ai disponibilă pe orice hartă, fără s-o pui în
## fiecare scenă.
##
## Folosire din orice script:
##     await DialogueManager.say("Salut!", "Go-Chan")
##     await DialogueManager.say_many(["Prima replică.", "A doua."])
##
## Ca să nu pornești două dialoguri suprapuse:
##     if DialogueManager.is_busy: return

const BOX_SCENE := "res://ui/dialogue/DialogueBox.tscn"
const FACES_DIR := "res://assets/faces/"

signal dialogue_started
signal dialogue_ended

var box: DialogueBox
var is_busy: bool = false        ## true cât timp rulează un dialog


func _ready() -> void:
	# Instanțiem caseta o singură dată și o ținem în viață tot jocul.
	if ResourceLoader.exists(BOX_SCENE):
		box = (load(BOX_SCENE) as PackedScene).instantiate()
		add_child(box)
	else:
		push_error("[DialogueManager] lipsește scena: " + BOX_SCENE)


## Un singur mesaj. `face` e numele fișierului din assets/faces/ (fără .png).
func say(text: String, speaker: String = "", face: String = "") -> void:
	await say_many([text], speaker, face)


## Mai multe mesaje la rând (jucătorul avansează prin fiecare).
func say_many(lines: Array, speaker: String = "", face: String = "") -> void:
	if box == null or is_busy:
		return
	is_busy = true
	dialogue_started.emit()

	var face_path := ""
	if face != "":
		face_path = FACES_DIR + face + ".png"

	for line in lines:
		await box.show_message(str(line), speaker, face_path)

	await box.hide_box()      # aşteptăm şi animaţia de coborâre
	# IMPORTANT: mică pauză înainte de a debloca playerul.
	# Tasta care tocmai a închis dialogul e încă „just_pressed" în frame-ul
	# curent, iar playerul citește input-ul prin polling în _process() — fără
	# pauza asta ar redeschide evenimentul instant și n-ai mai putea ieși.
	# (Atenție: `await get_tree().process_frame` NU e suficient, pentru că
	#  semnalul ăla se emite ÎNAINTE de _process, deci tot în același frame.)
	await get_tree().create_timer(0.1).timeout
	is_busy = false
	dialogue_ended.emit()


## Rulează lista de comenzi a unui eveniment RPG Maker.
## Deocamdată tratăm doar textul (codurile 101 = start mesaj, 401 = rând de
## text). Restul (alegeri, transferuri, switch-uri) le adăugăm pe rând.
func run_event_commands(commands: Array, speaker: String = "") -> void:
	var messages: Array = []
	var current: Array = []

	for cmd in commands:
		var code := int(cmd.get("code", 0))
		if code == 401:
			# Un rând de text din mesajul curent.
			var params: Array = cmd.get("parameters", [])
			current.append(str(params[0]) if params.size() > 0 else "")
		else:
			# Orice altă comandă închide mesajul curent (101 = începe unul nou).
			if not current.is_empty():
				messages.append("\n".join(current))
				current = []

	if not current.is_empty():
		messages.append("\n".join(current))

	if messages.is_empty():
		return
	await say_many(messages, speaker)
