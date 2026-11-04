extends Node
var bgm: AudioStreamPlayer
var effects: Array = []
var current_bgm = ""
var current_bgm_data: Dictionary = {}
var music_volume = 0.8
var sound_volume = 0.8
var fade: Tween
## Accelerated logic tests load audio resources but do not start a real mixer.
## Real-time audio smoke tests leave this enabled.
var playback_enabled = true

func _ready() -> void:
	bgm = AudioStreamPlayer.new()
	add_child(bgm)

func apply_audio(player: AudioStreamPlayer, data: Dictionary, volume: float) -> void:
	player.volume_db = linear_to_db(maxf(0.0001, float(data.get("volume", 90)) / 100.0 * volume))
	player.pitch_scale = maxf(0.01, float(data.get("pitch", 100)) / 100.0)

func play_bgm(data: Dictionary) -> void:
	current_bgm_data = data.duplicate()
	if is_instance_valid(fade): fade.kill()
	var name = str(data.get("name", ""))
	if name.is_empty():
		bgm.stop()
		bgm.stream = null
		current_bgm = ""
		return
	apply_audio(bgm, data, music_volume)
	if current_bgm == name and bgm.playing: return
	current_bgm = name
	bgm.stream = load(GameData.asset("bgm", name))
	if bgm.stream is AudioStreamOggVorbis: bgm.stream.loop = true
	if playback_enabled: bgm.play()

func set_music_volume(value: float) -> void:
	music_volume = value
	apply_audio(bgm, current_bgm_data, music_volume)

func play_se(data: Dictionary) -> void:
	if str(data.get("name", "")).is_empty(): return
	var player = AudioStreamPlayer.new()
	player.stream = load(GameData.asset("se", str(data.name)))
	apply_audio(player, data, sound_volume)
	add_child(player)
	effects.append(player)
	player.finished.connect(func():
		effects.erase(player)
		player.queue_free())
	if playback_enabled: player.play()
	else:
		effects.erase(player)
		player.queue_free()

func stop_se() -> void:
	for effect in effects:
		if is_instance_valid(effect):
			effect.stop()
			effect.stream = null
			effect.queue_free()
	effects.clear()

func fade_bgm(seconds: float) -> void:
	fade = create_tween()
	fade.tween_property(bgm, "volume_db", -80.0, maxf(seconds, 0.01))
	fade.tween_callback(bgm.stop)
