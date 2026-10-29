class_name Stage2TrexBossArena
extends Node2D

## res://scripts/levels/stone_age/stage_2_trex_boss_arena.gd
## 1. Bölüm: Tarih Öncesi İlkel Vadi & Siber Anne T-Rex Boss Arenası
## - Çok aşamalı 2D platform keşfi ve savaş ilerlemesi (Bölüm A -> F)
## - İlk düşman karşılaşmaları (Goblin, Spor Mantarı, Uçan Göz)
## - Kırılabilir antik barikat ve çöken kaya platformları
## - Siber enkaz ve yer sarsıntısı ön uyarı alanı
## - 3 Fazlı Mecha-Tyrant Boss savaşı, Kalp Parçası ve Eflak Seferi Geçidi

@onready var player: CharacterBody2D = $CombatPlayer
@onready var trex_boss: CharacterBody2D = $TrexBoss
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var heart_piece: Node2D = $HeartPieceVisual
@onready var time_rift_exit: Node2D = $DimensionalTimeRiftExit

# Üst Boss Can Barı Düğümleri
@onready var boss_panel: PanelContainer = $UI/BossHealthPanel
@onready var boss_hp_bar: ProgressBar = $UI/BossHealthPanel/VBox/HealthBar
@onready var boss_hp_text: Label = $UI/BossHealthPanel/VBox/HPText
@onready var boss_phase_label: Label = $UI/BossHealthPanel/VBox/PhaseLabel

# Çevresel Alanlar
@onready var boss_trigger_area: Area2D = $Environment/BossTriggerArea
@onready var barricade_hint_zone: Area2D = $Environment/BarricadeHintZone
@onready var tremor_zone: Area2D = $Environment/TremorZone

var _player_camera: Camera2D = null
var _intro_dialogue_played: bool = false
var _barricade_hint_played: bool = false
var _tremor_played: bool = false
var _boss_fight_started: bool = false
var _boss_defeated: bool = false

const StoryDataLoaderScript = preload("res://scripts/autoloads/story_data_loader.gd")
const NEXT_CHAPTER_PATH: String = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"


func _ready() -> void:
	StoryDataLoaderScript.load_chapter_data(StoryDataLoaderScript.CHAPTER_1_PATH)

	# Kalp kristali ve çıkış zaman yarığı başlangıçta gizli
	if heart_piece:
		heart_piece.visible = false
	if time_rift_exit:
		time_rift_exit.visible = false

	# Boss can paneli oyuncu arenaya girene kadar gizli
	if boss_panel:
		boss_panel.modulate.a = 0.0

	# Oyuncu hazırlığı ve kamera sınırları (Tam bölüm genişliği: 0 - 5500 px)
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
			_player_camera.limit_right = 5500
			_player_camera.limit_top = -220
			_player_camera.limit_bottom = 650

	_play_fade_in()
	_setup_boss_signals()
	_connect_level_triggers()

	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
		# Başlangıç uyanış diyalogunu oynat
		get_tree().create_timer(0.6).timeout.connect(func():
			if not _intro_dialogue_played:
				_intro_dialogue_played = true
				dialogue_box.start_dialogue_from_data("intro_awakening", player)
		)

	_setup_initial_hud()


func _setup_initial_hud() -> void:
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Bölüm 1: Taş Devri",
			"Tarih Öncesi Vadi & Siber Tyrant'ın İzi",
			"Hareket: [A / D]  |  Zıplama: [Space]  |  Çift Zıplama: [Space x2]  |  Saldırı: [Sol Tık / J]"
		)


func _connect_level_triggers() -> void:
	if barricade_hint_zone:
		barricade_hint_zone.body_entered.connect(_on_barricade_zone_entered)
	if tremor_zone:
		tremor_zone.body_entered.connect(_on_tremor_zone_entered)
	if boss_trigger_area:
		boss_trigger_area.body_entered.connect(_on_boss_trigger_entered)


func _on_barricade_zone_entered(body: Node2D) -> void:
	if body == player and not _barricade_hint_played:
		_barricade_hint_played = true
		if dialogue_box:
			dialogue_box.start_dialogue_from_data("barricade_hint", player)


func _on_tremor_zone_entered(body: Node2D) -> void:
	if body == player and not _tremor_played:
		_tremor_played = true
		_trigger_ambient_tremor()


func _trigger_ambient_tremor() -> void:
	if _player_camera:
		if _player_camera.has_method("apply_shake"):
			_player_camera.apply_shake(12.0, 2, 0.35, 20.0, "ambient_tremor")
		else:
			var tw_cam: Tween = create_tween()
			tw_cam.tween_property(_player_camera, "offset:y", 12.0, 0.08)
			tw_cam.tween_property(_player_camera, "offset:y", -10.0, 0.08)
			tw_cam.tween_property(_player_camera, "offset:y", 6.0, 0.08)
			tw_cam.tween_property(_player_camera, "offset:y", 0.0, 0.1)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"UYARI: ANORMAL TİTREŞİMLER",
			"Geleceğe Ait Siber Sinyaller",
			"Kopmuş devasa sibernetik pençeler... Canavar çok yakında!"
		)


func _on_boss_trigger_entered(body: Node2D) -> void:
	if body == player and not _boss_fight_started:
		_boss_fight_started = true
		_start_boss_fight()


func _start_boss_fight() -> void:
	# Kamerayı Boss Arenası içine kilitle (4300 - 5500 px) ve geniş görünüm ölçeğine geçir
	if _player_camera:
		if _player_camera.has_method("enter_boss_arena"):
			_player_camera.enter_boss_arena(Rect2(4300, -220, 1200, 870), Vector2(0.82, 0.82))
		else:
			_player_camera.limit_left = 4300
			_player_camera.limit_right = 5500

	# Boss panelini animasyonla aç
	if boss_panel:
		var tw_panel: Tween = create_tween()
		tw_panel.tween_property(boss_panel, "modulate:a", 1.0, 0.6)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"PATRON DÖVÜŞÜ: SİBER T-REX",
			"Dev Mecha-Tyrant",
			"Lazerden ve yer sarsıntılarından kaçmak için yüksek platformlara tırman!"
		)

	# Karşılaşma diyalogunu başlat
	if dialogue_box and is_instance_valid(trex_boss):
		dialogue_box.start_dialogue_from_data("trex_encounter", trex_boss)


func _setup_boss_signals() -> void:
	if not trex_boss:
		return

	if trex_boss.has_signal("health_changed"):
		trex_boss.health_changed.connect(_on_boss_health_changed)
	if trex_boss.has_signal("phase_changed"):
		trex_boss.phase_changed.connect(_on_boss_phase_changed)
	if trex_boss.has_signal("enemy_died"):
		trex_boss.enemy_died.connect(_on_boss_died)

	_update_boss_ui(trex_boss.current_health, trex_boss.max_health)


func _on_boss_health_changed(current_hp: int, max_hp: int) -> void:
	_update_boss_ui(current_hp, max_hp)
	if current_hp <= 0 and not _boss_defeated:
		_on_boss_died(trex_boss)


func _on_boss_phase_changed(new_phase: int) -> void:
	if not boss_phase_label:
		return
	match new_phase:
		1:
			boss_phase_label.text = "[ FAZ 1: STANDART ]"
			boss_phase_label.modulate = Color(0.2, 0.85, 1.0)
		2:
			boss_phase_label.text = "[ FAZ 2: OVERDRIVE - HIZ VE SALDIRI ARTTI ]"
			boss_phase_label.modulate = Color(1.0, 0.7, 0.2)
			_flash_boss_panel()
		3:
			boss_phase_label.text = "[ FAZ 3: MELTDOWN - ÖLÜMCÜL LAZER ]"
			boss_phase_label.modulate = Color(1.0, 0.2, 0.2)
			_flash_boss_panel()


func _flash_boss_panel() -> void:
	if not boss_panel:
		return
	var tw: Tween = create_tween()
	tw.tween_property(boss_panel, "modulate", Color(1.5, 0.5, 0.5, 1), 0.15)
	tw.tween_property(boss_panel, "modulate", Color(1, 1, 1, 1), 0.25)


func _update_boss_ui(current_hp: int, max_hp: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = current_hp
	if boss_hp_text:
		boss_hp_text.text = "%d / %d HP" % [max(0, current_hp), max_hp]


func _on_boss_died(_boss_ref: Node2D) -> void:
	if _boss_defeated:
		return
	_boss_defeated = true

	if boss_panel:
		var tw_hp: Tween = create_tween()
		tw_hp.tween_property(boss_panel, "modulate:a", 0.0, 1.0)

	# Level 08 — İlk Kalp Parçası ve Boss Sonrası Hikâye Sahnesine Geçiş
	var tw_trans: Tween = create_tween()
	tw_trans.tween_interval(1.8)
	tw_trans.tween_callback(func():
		var fade_overlay: ColorRect = ColorRect.new()
		fade_overlay.color = Color(0, 0, 0, 0)
		fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var canvas: CanvasLayer = CanvasLayer.new()
		canvas.layer = 100
		canvas.add_child(fade_overlay)
		add_child(canvas)

		var tw_fade: Tween = create_tween()
		tw_fade.tween_property(fade_overlay, "color:a", 1.0, 0.8)
		tw_fade.tween_callback(func():
			get_tree().change_scene_to_file("res://scenes/levels/stoneage/stoneage_08_first_heart_fragment.tscn")
		)
	)


func _reveal_exit_portal() -> void:
	if time_rift_exit:
		time_rift_exit.visible = true
		time_rift_exit.modulate.a = 0.0
		var tw_rift: Tween = create_tween()
		tw_rift.tween_property(time_rift_exit, "modulate:a", 1.0, 1.0)

		var rift_area: Area2D = time_rift_exit.get_node_or_null("Area2D") as Area2D
		if rift_area:
			rift_area.body_entered.connect(func(body: Node2D):
				if body == player:
					_transition_to_next_chapter()
			)


func _on_dialogue_completed() -> void:
	pass


func _transition_to_next_chapter() -> void:
	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		get_tree().change_scene_to_file(NEXT_CHAPTER_PATH)
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
