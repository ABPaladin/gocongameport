class_name DialogueBox
extends CanvasLayer
## Caseta de dialog în stilul original RPG Maker.
##
## Folosește window-skin-ul MV (assets/ui/system/window.png) tăiat în 9 felii,
## plus: nameplate separat pentru vorbitor, indicator ▼ clipitor, sunet la
## scriere și animație de apariție.
##
## Nodurile suplimentare (nameplate, săgeata) se creează din cod — tu nu
## trebuie să adaugi nimic în scenă. Structura minimă rămâne:
##   DialogueBox (CanvasLayer)
##   └── Root (Control, Full Rect)
##       └── Panel (PanelContainer)
##           └── HBox
##               ├── Portrait (TextureRect)
##               └── VBox
##                   ├── NameLabel (Label)   <- ascuns, îl înlocuiește nameplate-ul
##                   └── Text (RichTextLabel)

signal finished          ## utilizatorul a terminat de citit mesajul curent

## --- Window-skin RPG Maker MV (192x192) ---
## Aşa e împărţită imaginea în motorul original:
const SKIN_PATH := "res://assets/ui/system/window.png"
const BG_REGION := Rect2i(0, 0, 96, 96)       ## fundalul (culoare plată)
const PATTERN_REGION := Rect2i(0, 96, 96, 96) ## textura de linii, se repetă
const FRAME_REGION := Rect2i(96, 0, 96, 96)   ## rama (9 felii)
const FRAME_MARGIN := 24                      ## cât de mari sunt colţurile ramei

## Suprapune textura de linii peste fundal (aspectul autentic MV).
@export var use_pattern: bool = true

## Opacitatea fundalului casetei.
## Skin-ul RPG Maker vine cu 0.78 (aşa erau ferestrele semi-transparente în
## original). 1.0 = complet opac, nu se mai vede harta prin casetă.
@export_range(0.0, 1.0) var background_opacity: float = 0.78

const TYPE_SFX := "res://assets/audio/se/text_1.ogg"
const FONT_PATH := "res://assets/fonts/mplus-1m-regular.ttf"

## Tonul ferestrei din jocul original (System.json → windowTone).
## Se adună la culoarea fundalului: (42,37,43) + (-255,68,102) = (0,105,145).
const WINDOW_TONE := Vector3(-255, 68, 102)
## Culoarea 14 din paleta skin-ului — galbenul folosit pentru numele vorbitorului.
const NAME_COLOR := Color8(255, 204, 32)

@export var chars_per_second: float = 45.0
@export var sfx_every_n_chars: int = 3       ## la câte litere se aude un beep

## Mărimea textului. 28 = valoarea din jocul original (YEP: Font Size).
@export var font_size: int = 28
## Grosimea conturului negru din jurul literelor (MV foloseşte 4 → ~2 aici).
@export var outline_size: int = 2

@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var portrait: TextureRect = $Root/Panel/HBox/Portrait
@onready var name_label: Label = $Root/Panel/HBox/VBox/NameLabel
@onready var text_label: RichTextLabel = $Root/Panel/HBox/VBox/Text

var _is_typing: bool = false
var _is_open: bool = false

# Noduri create din cod
var _nameplate: PanelContainer
var _nameplate_label: Label
var _arrow: TextureRect
var _sfx: AudioStreamPlayer


func _ready() -> void:
	layer = 10
	_build_skin()
	_build_font()
	_build_nameplate()
	_build_arrow()
	_build_sfx()
	name_label.visible = false          # îl înlocuiește nameplate-ul de deasupra
	_reset_state()                      # ascundem direct, fără animație


# --- Construcţia aspectului -----------------------------------------------

## Compune o textură care conţine fundalul MV + rama peste el, apoi o
## foloseşte ca StyleBox cu 9 felii.
##
## De ce compunem: un StyleBox poate avea o singură textură. Dacă am folosi
## direct regiunea ramei, centrul ei (unde sunt săgeţile din skin) s-ar întinde
## peste tot fundalul. Aşa copiem întâi fundalul, apoi lipim DOAR marginile
## ramei — iar tăierea în 9 felii se comportă exact cum trebuie: colţurile
## rămân intacte, muchiile se întind, centrul (fundalul) se întinde.
func _build_skin() -> void:
	var style: StyleBox
	if ResourceLoader.exists(SKIN_PATH):
		var skin: Texture2D = load(SKIN_PATH)
		var src: Image = skin.get_image()
		var size := BG_REGION.size
		var composed := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

		# 1) fundalul (culoare plată) + textura de linii peste el
		composed.blit_rect(src, BG_REGION, Vector2i.ZERO)
		# Aplicăm TONUL ferestrei din jocul original + opacitatea dorită.
		# În RPG Maker, windowTone se adaugă la culoarea fundalului din skin —
		# aşa obţinem albastrul caracteristic al jocului, nu gri-violetul brut.
		for y in size.y:
			for x in size.x:
				var c := composed.get_pixel(x, y)
				c.r = clampf(c.r + WINDOW_TONE.x / 255.0, 0.0, 1.0)
				c.g = clampf(c.g + WINDOW_TONE.y / 255.0, 0.0, 1.0)
				c.b = clampf(c.b + WINDOW_TONE.z / 255.0, 0.0, 1.0)
				c.a = background_opacity
				composed.set_pixel(x, y, c)
		if use_pattern:
			composed.blend_rect(src, PATTERN_REGION, Vector2i.ZERO)

		# 2) tăiem tot ce ar rămâne ÎN AFARA ramei rotunjite, ca la colţuri să
		#    nu iasă fundalul pătrat de sub conturul alb.
		_cut_outside(composed, src)

		# 3) rama: doar cele 8 felii de margine (sărim centrul)
		var m := FRAME_MARGIN
		var f := FRAME_REGION.position
		var s := BG_REGION.size
		var inner_w := s.x - m * 2
		var inner_h := s.y - m * 2
		# colţuri
		composed.blend_rect(src, Rect2i(f.x, f.y, m, m), Vector2i(0, 0))
		composed.blend_rect(src, Rect2i(f.x + s.x - m, f.y, m, m), Vector2i(s.x - m, 0))
		composed.blend_rect(src, Rect2i(f.x, f.y + s.y - m, m, m), Vector2i(0, s.y - m))
		composed.blend_rect(src, Rect2i(f.x + s.x - m, f.y + s.y - m, m, m), Vector2i(s.x - m, s.y - m))
		# muchii
		composed.blend_rect(src, Rect2i(f.x + m, f.y, inner_w, m), Vector2i(m, 0))
		composed.blend_rect(src, Rect2i(f.x + m, f.y + s.y - m, inner_w, m), Vector2i(m, s.y - m))
		composed.blend_rect(src, Rect2i(f.x, f.y + m, m, inner_h), Vector2i(0, m))
		composed.blend_rect(src, Rect2i(f.x + s.x - m, f.y + m, m, inner_h), Vector2i(s.x - m, m))

		var tex := ImageTexture.create_from_image(composed)
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = m
		sb.texture_margin_top = m
		sb.texture_margin_right = m
		sb.texture_margin_bottom = m
		# spaţiul dintre ramă şi conţinut
		sb.content_margin_left = 18
		sb.content_margin_top = m - 6
		sb.content_margin_right = 18
		sb.content_margin_bottom = m - 6
		# Repetăm textura în loc s-o întindem: fundalul e o culoare plată, iar
		# liniile sunt de 1px — aşa rămân crocante la orice mărime a casetei.
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style = sb
	else:
		# Rezervă, dacă lipseşte skin-ul.
		push_warning("[DialogueBox] lipseşte " + SKIN_PATH + " — folosesc un stil simplu")
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.09, 0.09, 0.14, 0.92)
		flat.border_color = Color(1, 1, 1, 0.9)
		flat.set_border_width_all(3)
		flat.set_corner_radius_all(6)
		flat.set_content_margin_all(18)
		style = flat

	panel.add_theme_stylebox_override("panel", style)


## Aplică fontul original al jocului (M+ 1m) cu setările din RPG Maker:
## mărime 28 şi contur negru — aşa se citeşte textul peste fereastra
## semi-transparentă, exact ca în original (YEP_MessageCore: Font Size 28,
## Font Outline 4).
func _build_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("[DialogueBox] lipseşte fontul: " + FONT_PATH)
		return
	var font: Font = load(FONT_PATH)

	text_label.add_theme_font_override("normal_font", font)
	text_label.add_theme_font_override("bold_font", font)
	text_label.add_theme_font_size_override("normal_font_size", font_size)
	text_label.add_theme_font_size_override("bold_font_size", font_size)
	text_label.add_theme_color_override("default_color", Color.WHITE)
	# Conturul: în MV e o linie de 4px trasă pe mijlocul literei, deci în Godot
	# jumătate din valoare arată la fel.
	text_label.add_theme_constant_override("outline_size", outline_size)
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	# Distanţa dintre rânduri (MV: lineHeight 36 la font 28).
	text_label.add_theme_constant_override("line_separation", 6)


## Face transparent tot ce se află ÎN AFARA conturului ramei.
##
## Rama din skin e un contur rotunjit subţire: şi exteriorul, şi interiorul ei
## sunt transparente. Fundalul nostru e însă un pătrat plin, aşa că la colţuri
## ar ieşi de sub arcul rotunjit. Nu putem folosi direct transparenţa ramei ca
## mască (interiorul e şi el transparent, dar acolo fundalul TREBUIE să rămână).
##
## Soluţia: pornim de pe marginile imaginii şi ne răspândim prin pixelii unde
## rama e transparentă. Ne oprim când dăm de contur. Tot ce am atins e "afară"
## → îl ştergem. Interiorul, fiind închis de contur, rămâne neatins.
func _cut_outside(composed: Image, src: Image) -> void:
	var w := BG_REGION.size.x
	var h := BG_REGION.size.y
	var f := FRAME_REGION.position

	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []

	# Punctele de pornire: pixelii de pe marginea imaginii, unde rama lipseşte.
	for x in w:
		for y in [0, h - 1]:
			if src.get_pixel(f.x + x, f.y + y).a == 0.0:
				stack.append(Vector2i(x, y))
	for y in h:
		for x in [0, w - 1]:
			if src.get_pixel(f.x + x, f.y + y).a == 0.0:
				stack.append(Vector2i(x, y))

	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if visited[i] == 1:
			continue
		if src.get_pixel(f.x + p.x, f.y + p.y).a > 0.0:
			continue                       # am dat de contur → ne oprim aici
		visited[i] = 1
		composed.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))


## Căsuţa cu numele vorbitorului, lipită deasupra casetei mari.
func _build_nameplate() -> void:
	_nameplate = PanelContainer.new()
	_nameplate.add_theme_stylebox_override(
		"panel", panel.get_theme_stylebox("panel").duplicate())
	# Ancorat jos-stânga, imediat deasupra panoului principal. Citim înălţimea
	# panoului din scenă (offset_top e negativ, ex. -170), ca nameplate-ul să
	# rămână lipit de el chiar dacă schimbi mărimea casetei.
	var panel_top: float = panel.offset_top
	_nameplate.anchor_left = 0.0
	_nameplate.anchor_right = 0.0
	_nameplate.anchor_top = 1.0
	_nameplate.anchor_bottom = 1.0
	_nameplate.offset_left = 8
	_nameplate.offset_top = panel_top - 52
	_nameplate.offset_bottom = panel_top + 2
	root.add_child(_nameplate)

	_nameplate_label = Label.new()
	_nameplate_label.add_theme_font_size_override("font_size", font_size)
	# Numele e galben, ca în jocul original (culoarea 14 din paleta skin-ului).
	_nameplate_label.add_theme_color_override("font_color", NAME_COLOR)
	_nameplate_label.add_theme_constant_override("outline_size", outline_size)
	_nameplate_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(FONT_PATH):
		_nameplate_label.add_theme_font_override("font", load(FONT_PATH))
	_nameplate.add_child(_nameplate_label)
	_nameplate.visible = false


## Săgeata ▼ care clipeşte când mesajul s-a terminat de scris.
func _build_arrow() -> void:
	_arrow = TextureRect.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = load(SKIN_PATH)
	atlas.region = Rect2(144, 108, 24, 12)
	_arrow.texture = atlas
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	# Centrat jos, ca în jocul original.
	_arrow.anchor_left = 0.0
	_arrow.anchor_right = 1.0
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = 0
	_arrow.offset_right = 0
	_arrow.offset_top = -34
	_arrow.offset_bottom = -6
	root.add_child(_arrow)
	_arrow.visible = false


func _build_sfx() -> void:
	_sfx = AudioStreamPlayer.new()
	if ResourceLoader.exists(TYPE_SFX):
		_sfx.stream = load(TYPE_SFX)
	_sfx.volume_db = -12.0
	add_child(_sfx)


func _process(_delta: float) -> void:
	# Clipirea săgeţii (doar când aşteptăm confirmarea).
	if _arrow != null and _arrow.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_arrow.modulate.a = 0.35 + 0.65 * abs(sin(t * 3.0))


# --- Afişare ---------------------------------------------------------------

## Afişează un mesaj şi aşteaptă (cu `await`) până când jucătorul îl închide.
func show_message(text: String, speaker: String = "", portrait_path: String = "", face_index: int = 0, message_position: int = 2) -> void:
	var was_closed := not _is_open
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = [0.0, 222.0, 444.0][clampi(message_position, 0, 2)]
	panel.offset_bottom = panel.offset_top + 180.0
	_nameplate.anchor_top = 0
	_nameplate.anchor_bottom = 0
	_nameplate.offset_left = 0
	_nameplate.offset_top = panel.offset_top - 72 if message_position > 0 else 180
	_nameplate.offset_bottom = _nameplate.offset_top + 70
	_is_open = true

	# IMPORTANT: pregătim conţinutul ÎNAINTE de a arăta caseta.
	# Altfel, cât durează animaţia de apariţie (~0.2s) s-ar vedea încă replica
	# personajului anterior, care rămăsese în etichetă.
	_arrow.visible = false
	text_label.text = text
	text_label.visible_characters = 0

	visible = true

	# Nameplate
	if speaker != "":
		_nameplate_label.text = speaker
		_nameplate.visible = true
		# lăţimea se potriveşte pe text
		var w: float = maxf(150, _nameplate.get_combined_minimum_size().x)
		_nameplate.offset_right = _nameplate.offset_left + w
	else:
		_nameplate.visible = false

	# Portret
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(portrait_path)
		atlas.region = Rect2((face_index % 4) * 144, int(face_index / 4) * 144, 144, 144)
		portrait.texture = atlas
		portrait.visible = true
	else:
		portrait.visible = false

	# Animaţia de apariţie (doar la primul mesaj, nu între replici)
	if was_closed:
		await _animate_in()

	# Typewriter (textul e deja pus mai sus, cu 0 caractere vizibile)
	_is_typing = true

	var total := text_label.get_total_character_count()
	var elapsed := 0.0
	var last_sfx := 0
	while _is_typing and text_label.visible_characters < total:
		elapsed += get_process_delta_time()
		var shown := int(elapsed * chars_per_second)
		text_label.visible_characters = shown
		# beep discret la fiecare câteva litere
		if _sfx.stream != null and shown - last_sfx >= sfx_every_n_chars:
			last_sfx = shown
			_sfx.play()
		await get_tree().process_frame
	text_label.visible_characters = -1
	_is_typing = false

	# Aşteptăm confirmarea; săgeata clipeşte între timp.
	_arrow.visible = true
	await finished
	_arrow.visible = false
	_is_open = false


## Urcă lin caseta de jos + fade in.
func _animate_in() -> void:
	offset = Vector2(0, 40)
	root.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "offset", Vector2.ZERO, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 1.0, 0.18)
	await tw.finished


## Coboară lin + fade out, apoi ascunde.
func hide_box() -> void:
	if not visible:
		_reset_state()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "offset", Vector2(0, 40), 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "modulate:a", 0.0, 0.14)
	await tw.finished
	_reset_state()


func _reset_state() -> void:
	visible = false
	offset = Vector2.ZERO
	root.modulate.a = 1.0
	_is_open = false
	_is_typing = false
	_arrow.visible = false
	_nameplate.visible = false
	# Golim conţinutul, ca la următoarea deschidere să nu apară nimic vechi.
	text_label.text = ""
	_nameplate_label.text = ""


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	# A real touch also generates an emulated mouse event; consume it only once.
	if event is InputEventMouseButton and event.device == -1: return
	if not event.is_action_pressed("interact") and not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) and not (event is InputEventScreenTouch and event.pressed):
		return
	get_viewport().set_input_as_handled()

	if _is_typing:
		_is_typing = false       # prima apăsare: arată tot textul instant
	else:
		finished.emit()          # a doua apăsare: mesajul următor
