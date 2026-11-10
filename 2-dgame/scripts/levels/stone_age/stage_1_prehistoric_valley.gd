class_name Stage1PrehistoricValley
extends Node2D

## res://scripts/levels/stone_age/stage_1_prehistoric_valley.gd
## 1. Bölüm — 1. Aşama: Tarih Öncesi Vadi & Zaman Yarığı İnişi
## - Karakter zaman yarığından ilkel kanyona düşer.
## - Kılıç ruhunun uyanış rezonansı ve giriş diyalogu (intro_awakening).
## - Çöken kaya platformları ve zıplama parkuru (kesintisiz zemin geçişleri).
## - Çukur kanyon tehlikesi ve güvenli sıfırlama (softlock önleme).
## - Kılıçla parçalanabilir fosil/kütük barikatı ve ipucu diyalogu.
## - Siber T-Rex Arenası geçit tetikleyicisi.

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var exit_gate: Area2D = $ExitGate
@onready var pit_hazard: Area2D = get_node_or_null("Environment/CanyonPitHazard") as Area2D
@onready var sword_awakening_fx: CPUParticles2D = get_node_or_null("Effects/SwordAwakeningFX") as CPUParticles2D

var _player_camera: Camera2D = null
var _intro_dialogue_played: bool = false
var _barricade_hint_played: bool = false

const StoryDataLoaderScript = preload("res://scripts/autoloads/story_data_loader.gd")
const STAGE_2_ARENA_PATH: String = "res://scenes/levels/stone_age/stage_2_trex_boss_arena.tscn"
const RESPAWN_POINT: Vector2 = Vector2(480.0, 530.0)


func _ready() -> void:
	StoryDataLoaderScript.load_chapter_data(StoryDataLoaderScript.CHAPTER_1_PATH)

	if player:
		if not player.has_sword and player.has_method("pickup_sword"):
			player.pickup_sword()
		elif not player.is_armed:
			player.is_armed = true
			if player.has_method("_emit_weapon_state"):
				player._emit_weapon_state()

		_player_camera = player.get_node_or_null("Camera2D") as Camera2D
		if _player_camera:
			_player_camera.limit_left = 0
			_player_camera.limit_right = 2200
			_player_camera.limit_top = -180
			_player_camera.limit_bottom = 650

	_play_fade_in()

	if dialogue_box and not dialogue_box.dialogue_completed.is_connected(_on_dialogue_completed):
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)

	if pit_hazard and not pit_hazard.body_entered.is_connected(_on_pit_hazard_entered):
		pit_hazard.body_entered.connect(_on_pit_hazard_entered)

	if exit_gate and not exit_gate.body_entered.is_connected(_on_exit_gate_body_entered):
		exit_gate.body_entered.connect(_on_exit_gate_body_entered)

	_setup_tutorial_hud()

	# Kılıcın ilk uyanış sekansını 0.4 saniye sonra başlat
	get_tree().create_timer(0.4).timeout.connect(_trigger_sword_awakening)


func _setup_tutorial_hud() -> void:
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Bölüm 1: Taş Devri",
			"Tarih Öncesi Kanyon",
			"Hareket: [A / D]  |  Zıplama: [Space]  |  Çift Zıplama: [Space x2]  |  Saldırı: [Sol Tık / J]"
		)


func _trigger_sword_awakening() -> void:
	if _intro_dialogue_played:
		return

	# Kılıç uyanış parçacığı ve hafif rezonans sarsıntısı
	if sword_awakening_fx and player:
		sword_awakening_fx.global_position = player.global_position + Vector2(0, -20)
		sword_awakening_fx.restart()
		sword_awakening_fx.emitting = true

	if _player_camera:
		var tw_cam: Tween = create_tween()
		tw_cam.tween_property(_player_camera, "offset:y", 4.0, 0.08)
		tw_cam.tween_property(_player_camera, "offset:y", -3.0, 0.08)
		tw_cam.tween_property(_player_camera, "offset:y", 0.0, 0.08)

	# 0.3 saniye sonra diyalog penceresini aç
	get_tree().create_timer(0.3).timeout.connect(func():
		if not _intro_dialogue_played and dialogue_box:
			_intro_dialogue_played = true
			dialogue_box.start_dialogue_from_data("intro_awakening", player)
	)


func _on_dialogue_completed() -> void:
	# Diyalog tamamlandığında kontrol ve kameranın kilitsiz olduğunu doğrula
	if player and is_instance_valid(player):
		player.can_move = true

	# İlk oynanış hedefini HUD üzerinden açıkça belirt
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"GÖREV: KANYONU GEÇ",
			"Kadim Kılıcın Uyanışı",
			"Platformları aş, kılıcınla antik barikatı parçala ve vadi geçidine ulaş!"
		)


func _on_pit_hazard_entered(body: Node2D) -> void:
	if body != player or not is_instance_valid(player):
		return

	# Çukura düşüldüğünde küçük hasar ver ve son güvenli platforma sıfırla
	if player.has_method("take_damage"):
		player.take_damage(10)
	elif "current_health" in player:
		player.current_health = maxi(1, player.current_health - 10)
		if player.has_signal("player_damaged"):
			player.player_damaged.emit(player.current_health, player.max_health)

	if _player_camera:
		var tw_rumble: Tween = create_tween()
		tw_rumble.tween_property(_player_camera, "offset:y", 6.0, 0.06)
		tw_rumble.tween_property(_player_camera, "offset:y", -5.0, 0.06)
		tw_rumble.tween_property(_player_camera, "offset:y", 0.0, 0.08)

	player.global_position = RESPAWN_POINT
	player.velocity = Vector2.ZERO


func _on_barricade_zone_entered(body: Node2D) -> void:
	if body == player and not _barricade_hint_played:
		_barricade_hint_played = true
		if dialogue_box:
			dialogue_box.start_dialogue_from_data("barricade_hint", player)


func _on_exit_gate_body_entered(body: Node2D) -> void:
	if body == player:
		_transition_to_boss_arena()


func _transition_to_boss_arena() -> void:
	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		get_tree().change_scene_to_file(STAGE_2_ARENA_PATH)
	)


func _play_fade_in() -> void:
	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 0.0, 0.7)
	tw.tween_callback(canvas.queue_free)
