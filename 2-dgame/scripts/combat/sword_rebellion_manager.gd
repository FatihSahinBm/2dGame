class_name SwordRebellionManager
extends Node

## res://scripts/combat/sword_rebellion_manager.gd
## Story 2D-125: Yüksek Yozlaşmada Kılıç İsyanı
## Yozlaşma belirli seviyeleri aştığında Kılıç Ruhu'nun oyuncunun eylemlerine karşı koyabildiği,
## kontrollü, anlaşılır ve güvenli bir oynanış tepkisi uygular.

signal rebellion_applied(stagger_duration: float)
signal rebellion_interrupted_attack()

# --- Yozlaşma ve İsyan Eşikleri ---
const CORRUPTION_THRESHOLD_HIGH: int = 50        # Yüksek yozlaşma alt eşiği (İsyan riski başlar)
const CORRUPTION_THRESHOLD_EXTREME: int = 75     # Aşırı yozlaşma alt eşiği (Daha sık ve şiddetli isyan)

const REBELLION_CHANCE_HIGH: float = 0.35        # Yüksek yozlaşmada saldırı isyan olasılığı (%35)
const REBELLION_CHANCE_EXTREME: float = 0.65     # Aşırı yozlaşmada saldırı isyan olasılığı (%65)

const COOLDOWN_HIGH_CORRUPTION: float = 3.5      # Yüksek yozlaşmada iki isyan arası minimum süre (sn)
const COOLDOWN_EXTREME_CORRUPTION: float = 2.0   # Aşırı yozlaşmada iki isyan arası minimum süre (sn)

const REBELLION_STAGGER_DURATION: float = 0.40   # Kılıcın direnmesi ve saldırının kesilme süresi (sn)
const LABEL_COOLDOWN: float = 2.2                # Görsel metin spam engelleme süresi (sn) (2s görünürlük + 0.5s fade)

@export var shake_intensity: float = 12.0
@export var sluggish_duration: float = 1.5

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

var _player_ref: CharacterBody2D = null
var _audio_screech: AudioStreamPlayer = null
var _last_text_index: int = -1
var _last_label_time: float = -99.0
var _last_rebellion_time: float = -99.0
var _is_rebelling: bool = false

# Test ve deterministik doğrulama modu
var _test_deterministic_mode: bool = false
var _test_attack_counter: int = 0
var _test_trigger_interval: int = 2


func _ready() -> void:
	_player_ref = get_parent() as CharacterBody2D
	_setup_audio()

	# Autoload sinyaline bağlan
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_signal("sword_rebellion_triggered"):
		if not game_state.sword_rebellion_triggered.is_connected(_on_game_state_rebellion_signal):
			game_state.sword_rebellion_triggered.connect(_on_game_state_rebellion_signal)


func _setup_audio() -> void:
	_audio_screech = AudioStreamPlayer.new()
	_audio_screech.bus = "SFX"
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.35
	_audio_screech.stream = gen
	_audio_screech.volume_db = -4.0
	add_child(_audio_screech)


func _on_game_state_rebellion_signal() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and "corruption_score" in game_state:
		# Yalnızca yüksek yozlaşma eşiğine ulaşılmışsa veya aşılmışsa tepki ver
		if game_state.corruption_score >= CORRUPTION_THRESHOLD_HIGH:
			trigger_rebellion(false, "high_corruption_threshold")


## Oyuncu saldırmaya kalkıştığında çağrılır.
## Yozlaşma düşükken (<50) ASLA tetiklenmez, doğrudan false döner.
## Yozlaşma yüksekken (>=50) kurallara göre isyanı tetikleyip saldırıyı keser (true döner).
func check_and_trigger_attack_rebellion() -> bool:
	if not _player_ref or not is_instance_valid(_player_ref):
		return false

	# Durum çakışmalarını önle: ölü, yaralı veya zaten isyandaysa tetikleme
	if _player_ref.get("is_dead") == true or _player_ref.get("is_hurt") == true or _is_rebelling:
		return false

	var game_state: Node = get_node_or_null("/root/GameState")
	if not game_state:
		return false

	var corruption: int = game_state.get("corruption_score") if "corruption_score" in game_state else 0

	# Kural 1: Düşük yozlaşmada istenmeyen isyan tetiklenmez!
	if corruption < CORRUPTION_THRESHOLD_HIGH:
		return false

	# Kural 2: Cooldown (bekleme süresi) kontrolü
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var required_cooldown: float = COOLDOWN_EXTREME_CORRUPTION if corruption >= CORRUPTION_THRESHOLD_EXTREME else COOLDOWN_HIGH_CORRUPTION
	if current_time - _last_rebellion_time < required_cooldown:
		return false

	# Kural 3: Olasılık veya deterministik test kuralı
	var should_trigger: bool = false
	if _test_deterministic_mode:
		_test_attack_counter += 1
		if _test_attack_counter % _test_trigger_interval == 0:
			should_trigger = true
	else:
		var chance: float = REBELLION_CHANCE_EXTREME if corruption >= CORRUPTION_THRESHOLD_EXTREME else REBELLION_CHANCE_HIGH
		should_trigger = (randf() <= chance)

	if should_trigger:
		trigger_rebellion(false, "attack_rebellion")
		rebellion_interrupted_attack.emit()
		return true

	return false


## Kılıç isyanını tetikler:
## 1. Saldırıyı derhal keser ve kısa kontrollü ara verir (0.4s).
## 2. Madeni feryat ses geri bildirimi çalar.
## 3. Ekran sarsıntısı ve kılıç titremesi/kızıllığı uygular.
## 4. Oyuncunun başı üzerinde okunaklı isyan metni gösterir.
## 5. Sonsuz kilitlenmeyi önlemek için zamanlayıcı ile durumu temizler.
func trigger_rebellion(forced: bool = false, _reason: String = "") -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		return

	if _player_ref.get("is_dead") == true:
		return

	# Eğer zaten isyandaysa üst üste kilitlenme yaratma
	if _is_rebelling and not forced:
		return

	_is_rebelling = true
	_last_rebellion_time = Time.get_ticks_msec() / 1000.0

	# Oyuncu üzerindeki isyan ve saldırı durumunu ayarla
	if "is_rebelling" in _player_ref:
		_player_ref.is_rebelling = true
	if "is_attacking" in _player_ref:
		_player_ref.is_attacking = false
	if "combo_step" in _player_ref:
		_player_ref.combo_step = 0
	if "combo_timer" in _player_ref:
		_player_ref.combo_timer = 0.0

	# Saldırı alanını derhal kapat (çakışmayı önle)
	var attack_area = _player_ref.get_node_or_null("Visual/AttackArea") as Area2D
	if attack_area:
		attack_area.monitoring = false

	# 1. Ses Geri Bildirimi (Madeni çığlık / rezonans)
	_play_screech_sound()

	# 2. Ekran Sarsıntısı (Kamerayı sars)
	var cam: Camera2D = _player_ref.get_node_or_null("Camera2D") as Camera2D
	if not cam and _player_ref.is_inside_tree() and _player_ref.get_viewport():
		cam = _player_ref.get_viewport().get_camera_2d()
	if cam:
		_apply_camera_shake(cam)

	# 3. Kılıç Kararması ve Titreme (Görsel Tepki)
	var visual: Node2D = _player_ref.get_node_or_null("Visual") as Node2D
	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color(0.85, 0.15, 0.25, 1.0), 0.08)
		tw.tween_property(visual, "position:x", visual.position.x + 6.0, 0.04)
		tw.tween_property(visual, "position:x", visual.position.x - 6.0, 0.04)
		tw.tween_property(visual, "position:x", 0.0, 0.04)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.3)

	# 4. Kılıç Ağırlığı ve Vuruş Yavaşlatması (Mekanik Ceza)
	if "attack_cooldown_penalty" in _player_ref:
		_player_ref.attack_cooldown_penalty = 1.6
		if is_inside_tree():
			get_tree().create_timer(sluggish_duration).timeout.connect(func():
				if is_instance_valid(_player_ref) and "attack_cooldown_penalty" in _player_ref:
					_player_ref.attack_cooldown_penalty = 1.0
			)

	# 5. Kılıçtan Yükselen Görsel Bildirim Metni
	_spawn_rebellion_label()
	rebellion_applied.emit(REBELLION_STAGGER_DURATION)

	# 6. Sonsuz Kilitlenmeyi Önleyen Durum Temizliği (Safety Timer)
	if is_inside_tree():
		get_tree().create_timer(REBELLION_STAGGER_DURATION).timeout.connect(_end_rebellion)
	else:
		_end_rebellion()


func _end_rebellion() -> void:
	_is_rebelling = false
	if is_instance_valid(_player_ref) and "is_rebelling" in _player_ref:
		_player_ref.is_rebelling = false


func _play_screech_sound() -> void:
	if not _audio_screech or not is_inside_tree():
		return
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sword_rebellion_whisper", -2.0)
	_audio_screech.play()
	var playback: AudioStreamGeneratorPlayback = _audio_screech.get_stream_playback()
	if playback:
		var sample_count = int(22050.0 * 0.25)
		for i in range(sample_count):
			var t: float = float(i) / 22050.0
			var decay: float = exp(-t * 9.0)
			# Madeni feryat harmonikleri: 880Hz + 1320Hz + 1760Hz
			var sample: float = (sin(t * 880.0 * TAU) * 0.35 + sin(t * 1320.0 * TAU) * 0.25 + sin(t * 1760.0 * TAU) * 0.15) * decay
			playback.push_frame(Vector2(sample, sample))


func _apply_camera_shake(cam: Camera2D) -> void:
	if not cam:
		return
	if cam.has_method("apply_shake"):
		cam.apply_shake(shake_intensity, 2, 0.25, 28.0, "sword_rebellion")
		return
	var tw: Tween = create_tween()
	tw.tween_property(cam, "offset", Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity)), 0.04)
	tw.tween_property(cam, "offset", Vector2(randf_range(-shake_intensity * 0.5, shake_intensity * 0.5), randf_range(-shake_intensity * 0.5, shake_intensity * 0.5)), 0.05)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.08)


func _spawn_rebellion_label() -> void:
	if not _player_ref:
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_label_time < LABEL_COOLDOWN:
		return
	_last_label_time = current_time

	var text: String = StoryDataLoader.get_random_sword_rebellion_text()
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.35, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(360.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.global_position = _player_ref.global_position + Vector2(-180.0, -75.0)

	var parent_scene: Node = _player_ref.get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 18.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_interval(2.0)
		tw.tween_property(label, "modulate:a", 0.0, 0.6)
		tw.parallel().tween_property(label, "global_position:y", label.global_position.y - 36.0, 0.6)
		tw.tween_callback(label.queue_free)


# --- Yardımcı ve Sorgulama Metotları ---

func is_rebelling() -> bool:
	return _is_rebelling


func get_corruption_score() -> int:
	var game_state: Node = get_node_or_null("/root/GameState")
	return game_state.corruption_score if game_state and "corruption_score" in game_state else 0


func get_corruption_tier() -> String:
	var score = get_corruption_score()
	if score >= CORRUPTION_THRESHOLD_EXTREME:
		return "extreme"
	elif score >= CORRUPTION_THRESHOLD_HIGH:
		return "high"
	return "low"


func set_test_deterministic_mode(enabled: bool, trigger_every_n: int = 2) -> void:
	_test_deterministic_mode = enabled
	_test_trigger_interval = trigger_every_n
	_test_attack_counter = 0


func reset_cooldown() -> void:
	_last_rebellion_time = -99.0
