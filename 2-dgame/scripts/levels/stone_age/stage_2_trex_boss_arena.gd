class_name Stage2TrexBossArena
extends Node2D

## res://scripts/levels/stone_age/stage_2_trex_boss_arena.gd
## 1. Bölüm — 2. Aşama: Siber Anne T-Rex Boss Arenası
## - 3 Fazlı Boss savaşı (Saldırılar: Isırık, Siber Ağız Lazeri, Zemin Sarsıntısı).
## - Kaçınma için yüksek kaya platformları.
## - Karşılaşma diyalogu (trex_encounter) ve zafer diyalogu (trex_victory).
## - T-Rex yenildiğinde "Dünyanın Kalbi" kristal parçasının kılıca çekilmesi.
## - Bölüm 2'ye (Eflak Seferi) açılan Zaman Yarığı portalı.

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

var _player_camera: Camera2D = null
var _boss_intro_played: bool = false
var _boss_defeated: bool = false

const StoryDataLoaderScript = preload("res://scripts/autoloads/story_data_loader.gd")
const NEXT_CHAPTER_PATH: String = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"


func _ready() -> void:
	StoryDataLoaderScript.load_chapter_data(StoryDataLoaderScript.CHAPTER_1_PATH)

	# Kalp kristali başlangıçta gizli
	if heart_piece:
		heart_piece.visible = false

	# Çıkış zaman yarığı başlangıçta gizli
	if time_rift_exit:
		time_rift_exit.visible = false

	# Oyuncu hazırlığı
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
			_player_camera.limit_right = 1600
			_player_camera.limit_top = -140
			_player_camera.limit_bottom = 630

	_play_fade_in()
	_setup_boss_signals()

	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
		# Karşılaşma diyalogunu başlat
		get_tree().create_timer(0.6).timeout.connect(func():
			if not _boss_intro_played:
				_boss_intro_played = true
				dialogue_box.start_dialogue_from_data("trex_encounter", trex_boss)
		)

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"PATRON DÖVÜŞÜ: SİBER T-REX",
			"Dev Mecha-Tyrant",
			"Lazerden ve yer sarsıntılarından kaçmak için yüksek platformlara tırman!"
		)


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

	# Boss panelini yavaşça gizle
	if boss_panel:
		var tw_hp: Tween = create_tween()
		tw_hp.tween_property(boss_panel, "modulate:a", 0.0, 1.0)

	# Dünyanın Kalbi parçasını göster ve animasyonla oyuncuya çek
	if heart_piece:
		heart_piece.visible = true
		if is_instance_valid(trex_boss):
			heart_piece.global_position = trex_boss.global_position + Vector2(0, -90)
		else:
			heart_piece.global_position = Vector2(920, 480)

		var tw_heart: Tween = create_tween()
		tw_heart.tween_interval(1.2)
		tw_heart.tween_property(heart_piece, "global_position", player.global_position + Vector2(0, -25), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_heart.tween_callback(func():
			heart_piece.visible = false
			var game_state: Node = get_node_or_null("/root/GameState")
			if game_state:
				game_state.current_heart_pieces = 1
			# Zafer diyalogunu başlat
			if dialogue_box:
				dialogue_box.start_dialogue_from_data("trex_victory", player)
			# Çıkış portalını aç
			_reveal_exit_portal()
		)


func _reveal_exit_portal() -> void:
	if time_rift_exit:
		time_rift_exit.visible = true
		time_rift_exit.modulate.a = 0.0
		var tw_rift: Tween = create_tween()
		tw_rift.tween_property(time_rift_exit, "modulate:a", 1.0, 1.0)

		# Portal tetikleyicisi
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
