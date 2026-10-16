class_name SwordRebellionManager
extends Node

## res://scripts/combat/sword_rebellion_manager.gd
## Oyuncu masum/müttefik bir askere saldırdığında veya canını sömürdüğünde
## kılıcın (mahpus büyücünün) verdiği fiziksel ve mekanik direnç tepkileri.

signal rebellion_applied(sluggish_duration: float)

@export var shake_intensity: float = 12.0
@export var sluggish_duration: float = 1.5

var _player_ref: CharacterBody2D = null
var _audio_screech: AudioStreamPlayer = null


func _ready() -> void:
	_player_ref = get_parent() as CharacterBody2D
	_setup_audio()
	
	# Autoload sinyaline bağlan
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_signal("sword_rebellion_triggered"):
		game_state.sword_rebellion_triggered.connect(trigger_rebellion)


func _setup_audio() -> void:
	_audio_screech = AudioStreamPlayer.new()
	_audio_screech.bus = "Master"
	add_child(_audio_screech)


## Kılıç isyanını tetikler: Ekran sarsıntısı, kılıç titremesi/kararması, hareket yavaşlaması
func trigger_rebellion() -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		return

	# 1. Ekran Sarsıntısı (Kamerayı sars)
	var cam: Camera2D = _player_ref.get_node_or_null("Camera2D") as Camera2D
	if cam:
		_apply_camera_shake(cam)

	# 2. Kılıç Kararması ve Titreme (Görsel Tepki)
	var visual: Node2D = _player_ref.get_node_or_null("Visual") as Node2D
	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color(0.25, 0.05, 0.1, 1.0), 0.08)
		tw.tween_property(visual, "position:x", visual.position.x + 5.0, 0.04)
		tw.tween_property(visual, "position:x", visual.position.x - 5.0, 0.04)
		tw.tween_property(visual, "position:x", 0.0, 0.04)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.4)

	# 3. Kılıç Ağırlığı ve Vuruş Yavaşlatması (Mekanik Ceza)
	if "attack_cooldown_penalty" in _player_ref:
		_player_ref.attack_cooldown_penalty = 1.6
		get_tree().create_timer(sluggish_duration).timeout.connect(func():
			if is_instance_valid(_player_ref) and "attack_cooldown_penalty" in _player_ref:
				_player_ref.attack_cooldown_penalty = 1.0
		)

	# 4. Kılıçtan Yükselen Madeni Çığlık ve Görsel Bildirim
	_spawn_rebellion_label()
	rebellion_applied.emit(sluggish_duration)


func _apply_camera_shake(cam: Camera2D) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(cam, "offset", Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity)), 0.04)
	tw.tween_property(cam, "offset", Vector2(randf_range(-shake_intensity * 0.5, shake_intensity * 0.5), randf_range(-shake_intensity * 0.5, shake_intensity * 0.5)), 0.05)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.08)


func _spawn_rebellion_label() -> void:
	if not _player_ref:
		return
	var label: Label = Label.new()
	label.text = "⚡ KILIÇ DİRENİYOR! (Ağırlaştı)"
	label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 13)
	label.global_position = _player_ref.global_position + Vector2(-60.0, -55.0)

	var parent_scene: Node = _player_ref.get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 0.6)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
		tw.tween_callback(label.queue_free)
