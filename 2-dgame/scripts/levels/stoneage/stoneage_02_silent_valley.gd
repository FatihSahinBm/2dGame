class_name Stoneage02SilentValley
extends Node2D

## res://scripts/levels/stoneage/stoneage_02_silent_valley.gd
## Taş Devri — Bölüm 02: Sessiz Vadi (Stone Age Level 02)
## - Geniş doğal vadi kompozisyonu ve keşif rotası
## - Tarih öncesi fosil kalıntıları, kırılmış kadim gövdeler ve dev pençe izleri
## - Oyuncu fiziği ve kamera uyumu (0 - 3800 px)
## - Level 01'den sorunsuz geçiş karşılama
## - Gelecekteki Level 03 (Kırık Geçit) için geçişe hazır çıkış alanı (ExitZone)

signal level_started()
signal observation_point_reached(point_name: String)
signal level_exit_reached(player_node: CharacterBody2D)

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var exit_zone: Area2D = $Environment/ExitZone
@onready var observation_zone_trunk: Area2D = $Environment/ObservationZoneTrunk
@onready var observation_zone_claws: Area2D = get_node_or_null("Environment/ObservationZoneClaws") as Area2D

var _player_camera: Camera2D = null
var _exit_triggered: bool = false
var _seen_trunk: bool = false
var _seen_claws: bool = false


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
	if not observation_zone_trunk:
		observation_zone_trunk = get_node_or_null("Environment/ObservationZoneTrunk") as Area2D
	if not observation_zone_claws:
		observation_zone_claws = get_node_or_null("Environment/ObservationZoneClaws") as Area2D


func _setup_player() -> void:
	if not player:
		return

	# Oyuncu kılıç kuşanmış olarak vadide başlar
	if not player.has_sword and player.has_method("pickup_sword"):
		player.pickup_sword()
	elif not player.is_armed:
		player.is_armed = true
		if player.has_method("_emit_weapon_state"):
			player._emit_weapon_state()

	_player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if _player_camera:
		_player_camera.limit_left = 0
		_player_camera.limit_right = 3800
		_player_camera.limit_top = -220
		_player_camera.limit_bottom = 650


func _setup_triggers() -> void:
	if exit_zone and not exit_zone.body_entered.is_connected(_on_exit_zone_body_entered):
		exit_zone.body_entered.connect(_on_exit_zone_body_entered)
	if observation_zone_trunk and not observation_zone_trunk.body_entered.is_connected(_on_trunk_zone_body_entered):
		observation_zone_trunk.body_entered.connect(_on_trunk_zone_body_entered)
	if observation_zone_claws and not observation_zone_claws.body_entered.is_connected(_on_claws_zone_body_entered):
		observation_zone_claws.body_entered.connect(_on_claws_zone_body_entered)


func _on_trunk_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_trunk:
		_seen_trunk = true
		observation_point_reached.emit("broken_trunk")


func _on_claws_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_claws:
		_seen_claws = true
		observation_point_reached.emit("claw_marks")


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body == player and not _exit_triggered:
		_exit_triggered = true
		level_exit_reached.emit(player)
		_handle_level_exit()


func _handle_level_exit() -> void:
	if not is_inside_tree():
		return

	# Level 03 (Kırık Geçit) için sinematik geçiş
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
		get_tree().change_scene_to_file("res://scenes/levels/stoneage/stoneage_03_broken_pass.tscn")
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
