class_name PositionalAudioEmitter2D
extends Node2D

## res://scripts/audio/positional_audio_emitter_2d.gd
## Story 2D-112: 2D Konumsal Ses ve Ortam Sesleri (Positional Audio Emitter)
## - Meşale, kamp ateşi, şelale, adımlar ve çevresel sesler için konuma bağlı ses yayımı
## - Mesafeye bağlı zayıflama (distance attenuation) ve stereo konumlandırma
## - Çift çalım/üst üste binmeyi önleyen koruma (Anti-overlap guard)
## - Uzak nesneler için işlemci tasarrufu sağlayan mesafe kırpma (distance culling)
## - Yumuşak fade-in / fade-out geçişleri

signal sound_started()
signal sound_finished()

@export var sound_key: String = "torch"
@export var custom_stream: AudioStream = null
@export var bus: String = "SFX"
@export var max_distance: float = 650.0
@export var attenuation: float = 1.0
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0
@export var pitch_randomness: float = 0.0
@export var loop: bool = true
@export var autoplay: bool = true
@export var enable_culling: bool = true
@export var cull_margin: float = 250.0

var _player: AudioStreamPlayer2D = null
var _tween: Tween = null
var _is_culled: bool = false
var _manual_stopped: bool = false
var custom_listener_node: Node2D = null


func _ready() -> void:
	_init_player()
	if autoplay and not sound_key.is_empty():
		play_sound()


func _init_player() -> void:
	if _player and is_instance_valid(_player):
		return

	_player = AudioStreamPlayer2D.new()
	_player.name = "PositionalPlayer2D"
	_player.bus = bus if AudioServer.get_bus_index(bus) != -1 else "SFX"
	_player.max_distance = max_distance
	_player.attenuation = attenuation
	_player.volume_db = volume_db
	_player.pitch_scale = pitch_scale
	_player.panning_strength = 1.0
	_player.finished.connect(_on_player_finished)
	add_child(_player)


func _process(_delta: float) -> void:
	if not enable_culling or _manual_stopped or not _player:
		return

	var listener_pos := _get_listener_position()
	var dist := global_position.distance_to(listener_pos)
	var cull_limit := max_distance + cull_margin

	if dist > cull_limit:
		if not _is_culled and _player.playing:
			_player.stream_paused = true
			_is_culled = true
	else:
		if _is_culled:
			_player.stream_paused = false
			_is_culled = false


func _get_listener_position() -> Vector2:
	if custom_listener_node and is_instance_valid(custom_listener_node):
		return custom_listener_node.global_position

	# 1. Oyuncu düğümü ara
	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	if player_node and is_instance_valid(player_node):
		return player_node.global_position

	# 2. Aktif Camera2D ara
	var viewport := get_viewport()
	if viewport:
		var camera := viewport.get_camera_2d()
		if camera and is_instance_valid(camera):
			return camera.global_position

	return Vector2.ZERO


func play_sound(fade_in_time: float = 0.0) -> void:
	_manual_stopped = false
	_is_culled = false
	if not _player:
		_init_player()

	# Üst üste binmeyi (duplicate overlapping) önle: Döngüsel ses zaten çalıyorsa yeniden başlatma
	if _player.playing and loop:
		return

	var stream: AudioStream = custom_stream
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if not stream and audio_mgr and audio_mgr.has_method("_resolve_stream"):
		stream = audio_mgr._resolve_stream(sound_key)

	if not stream:
		push_warning("PositionalAudioEmitter2D: Ses kaynağı çözülemedi -> " + sound_key)
		return

	_player.stream = stream
	_player.bus = bus if AudioServer.get_bus_index(bus) != -1 else "SFX"
	_player.max_distance = max_distance
	_player.attenuation = attenuation

	var p_scale := pitch_scale
	if pitch_randomness > 0.0:
		p_scale += randf_range(-pitch_randomness, pitch_randomness)
	_player.pitch_scale = clampf(p_scale, 0.2, 3.0)

	if _tween and is_instance_valid(_tween):
		_tween.kill()

	if fade_in_time > 0.05:
		_player.volume_db = -80.0
		_player.play()
		_fill_procedural_if_needed(_player, sound_key)
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", volume_db, fade_in_time)
	else:
		_player.volume_db = volume_db
		_player.play()
		_fill_procedural_if_needed(_player, sound_key)

	sound_started.emit()


func stop_sound(fade_out_time: float = 0.0) -> void:
	_manual_stopped = true
	if not _player or not _player.playing:
		return

	if _tween and is_instance_valid(_tween):
		_tween.kill()

	if fade_out_time > 0.05:
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", -80.0, fade_out_time)
		_tween.tween_callback(func():
			if _player:
				_player.stop()
				sound_finished.emit()
		)
	else:
		_player.stop()
		sound_finished.emit()


func _on_player_finished() -> void:
	if loop and not _manual_stopped and is_inside_tree():
		# Döngüsel ses: Anında ve kesintisiz tekrar çal
		play_sound()
	else:
		sound_finished.emit()


func is_playing() -> bool:
	return _player != null and _player.playing and not _is_culled and not _player.stream_paused


func is_culled() -> bool:
	return _is_culled


func set_sound_key(new_key: String, restart_if_playing: bool = true) -> void:
	sound_key = new_key
	if restart_if_playing and is_playing():
		play_sound()


func set_max_distance(dist: float) -> void:
	max_distance = dist
	if _player:
		_player.max_distance = dist


func get_player() -> AudioStreamPlayer2D:
	if not _player:
		_init_player()
	return _player


func _fill_procedural_if_needed(player_node: Node, key: String) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("_fill_procedural_if_needed"):
		audio_mgr._fill_procedural_if_needed(player_node, key)
