class_name Stoneage03BrokenPass
extends Node2D

## res://scripts/levels/stoneage/stoneage_03_broken_pass.gd
## Taş Devri — Bölüm 03: Kırık Geçit (Stone Age Level 03)
## - Yüksek kanyonlar arasında parçalanmış ve aşınmış kaya geçidi
## - Gerçek platform akışı: Zıplama aralıkları, yükselti adımları ve telegraflı düşen kaya tehlikeleri
## - Oyuncu fiziği (jump_velocity: -600, speed: 260) ile tam uyumlu geometri
## - Level 02'den sorunsuz geçiş karşılama
## - Gelecekteki Level 04 (Avcıların İzleri) için hazır çıkış alanı (ExitZone)

signal level_started()
signal hazard_encountered(hazard_name: String)
signal chasm_cleared(section_name: String)
signal level_exit_reached(player_node: CharacterBody2D)

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var exit_zone: Area2D = $Environment/ExitZone
@onready var hazard1: Node2D = $Hazards/FallingRockHazard1
@onready var hazard2: Node2D = $Hazards/FallingRockHazard2
@onready var chasm_zone_bridge: Area2D = $Environment/ChasmZoneBridge
@onready var chasm_zone_final: Area2D = $Environment/ChasmZoneFinal

var _player_camera: Camera2D = null
var _exit_triggered: bool = false
var _seen_bridge_chasm: bool = false
var _seen_final_chasm: bool = false


func _ready() -> void:
	_ensure_node_refs()
	_setup_player()
	_setup_triggers()
	_play_fade_in()
	level_started.emit()


func _ensure_node_refs() -> void:
	if not player:
		player = get_node_or_null("CombatPlayer") as CharacterBody2D
	if not hud:
		hud = get_node_or_null("FantasyHUD") as CanvasLayer
	if not exit_zone:
		exit_zone = get_node_or_null("Environment/ExitZone") as Area2D
	if not hazard1:
		hazard1 = get_node_or_null("Hazards/FallingRockHazard1") as Node2D
	if not hazard2:
		hazard2 = get_node_or_null("Hazards/FallingRockHazard2") as Node2D
	if not chasm_zone_bridge:
		chasm_zone_bridge = get_node_or_null("Environment/ChasmZoneBridge") as Area2D
	if not chasm_zone_final:
		chasm_zone_final = get_node_or_null("Environment/ChasmZoneFinal") as Area2D


func _setup_player() -> void:
	if not player:
		return

	# Oyuncu kılıç kuşanmış olarak geçitte başlar
	if not player.has_sword and player.has_method("pickup_sword"):
		player.pickup_sword()
	elif not player.is_armed:
		player.is_armed = true
		if player.has_method("_emit_weapon_state"):
			player._emit_weapon_state()

	_player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if _player_camera:
		_player_camera.limit_left = 0
		_player_camera.limit_right = 4000
		_player_camera.limit_top = -220
		_player_camera.limit_bottom = 680


func _setup_triggers() -> void:
	if exit_zone and not exit_zone.body_entered.is_connected(_on_exit_zone_body_entered):
		exit_zone.body_entered.connect(_on_exit_zone_body_entered)
	if chasm_zone_bridge and not chasm_zone_bridge.body_entered.is_connected(_on_bridge_chasm_body_entered):
		chasm_zone_bridge.body_entered.connect(_on_bridge_chasm_body_entered)
	if chasm_zone_final and not chasm_zone_final.body_entered.is_connected(_on_final_chasm_body_entered):
		chasm_zone_final.body_entered.connect(_on_final_chasm_body_entered)

	if hazard1 and not hazard1.rock_triggered.is_connected(_on_hazard1_triggered):
		hazard1.rock_triggered.connect(_on_hazard1_triggered)
	if hazard2 and not hazard2.rock_triggered.is_connected(_on_hazard2_triggered):
		hazard2.rock_triggered.connect(_on_hazard2_triggered)


func _on_hazard1_triggered() -> void:
	hazard_encountered.emit("rock_fall_bridge")


func _on_hazard2_triggered() -> void:
	hazard_encountered.emit("rock_fall_defile")


func _on_bridge_chasm_body_entered(body: Node2D) -> void:
	if body == player and not _seen_bridge_chasm:
		_seen_bridge_chasm = true
		chasm_cleared.emit("shattered_bridge")


func _on_final_chasm_body_entered(body: Node2D) -> void:
	if body == player and not _seen_final_chasm:
		_seen_final_chasm = true
		chasm_cleared.emit("great_chasm")


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body == player and not _exit_triggered:
		_exit_triggered = true
		level_exit_reached.emit(player)
		_handle_level_exit()


func _handle_level_exit() -> void:
	if not is_inside_tree():
		return

	# Level 04 (Avcıların İzleri) sahnesine geçiş
	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 90
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/levels/stoneage/stoneage_04_hunters_traces.tscn")
	)


func _play_fade_in() -> void:
	if not is_inside_tree():
		return
	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 90
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 0.0, 0.6)
	tw.tween_callback(canvas.queue_free)
