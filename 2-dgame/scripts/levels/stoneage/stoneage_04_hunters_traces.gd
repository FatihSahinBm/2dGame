class_name Stoneage04HuntersTraces
extends Node2D

## res://scripts/levels/stoneage/stoneage_04_hunters_traces.gd
## Taş Devri — Bölüm 04: Avcıların İzleri (Stone Age Level 04)
## - Kırık Geçit kanyonundan çıkan şövalyenin ulaştığı nemli, karanlık ve tehditkâr ilkel orman
## - Çevresel Hikâye Anlatımı: Dev ayak izleri, sürüklenme olukları, 3 metre yükseklikten kırılmış gövdeler
## - T-Rex Doğrudan Gösterilmez: Tehlike varlığı çevre ipuçları, belirsiz gölge ve zemin sarsıntısıyla hissettirilir
## - Kontrollü Çevresel Tehlike: Telegraflı devrilen/çöken dengesiz kütük engeli
## - Level 05 (Zamandan Kopan Parçalar) için hazır geçiş çıkışı (ExitZone)

signal level_started()
signal observation_made(clue_name: String)
signal hazard_triggered(hazard_name: String)
signal distant_presence_sensed()
signal level_exit_reached(player_node: CharacterBody2D)

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var exit_zone: Area2D = $Environment/ExitZone
@onready var obs_zone_footprint: Area2D = $Environment/ObservationZoneFootprint
@onready var obs_zone_trunk: Area2D = $Environment/ObservationZoneTrunk
@onready var hazard_zone_deadfall: Area2D = $Environment/HazardZoneDeadfall
@onready var obs_zone_presence: Area2D = $Environment/ObservationZonePresence

@onready var deadfall_hazard_node: Node2D = $Hazards/UnstableDeadfallHazard
@onready var shadow_silhouette: Sprite2D = $DistantShadowPresence/ApexDistantShadow
@onready var leaves_particles: CPUParticles2D = $AtmosphericLeaves

var _player_camera: Camera2D = null
var _exit_triggered: bool = false
var _seen_footprint: bool = false
var _seen_trunk: bool = false
var _deadfall_activated: bool = false
var _seen_presence: bool = false


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
	if not obs_zone_footprint:
		obs_zone_footprint = get_node_or_null("Environment/ObservationZoneFootprint") as Area2D
	if not obs_zone_trunk:
		obs_zone_trunk = get_node_or_null("Environment/ObservationZoneTrunk") as Area2D
	if not hazard_zone_deadfall:
		hazard_zone_deadfall = get_node_or_null("Environment/HazardZoneDeadfall") as Area2D
	if not obs_zone_presence:
		obs_zone_presence = get_node_or_null("Environment/ObservationZonePresence") as Area2D
	if not deadfall_hazard_node:
		deadfall_hazard_node = get_node_or_null("Hazards/UnstableDeadfallHazard") as Node2D
	if not shadow_silhouette:
		shadow_silhouette = get_node_or_null("DistantShadowPresence/ApexDistantShadow") as Sprite2D
	if not leaves_particles:
		leaves_particles = get_node_or_null("AtmosphericLeaves") as CPUParticles2D


func _setup_player() -> void:
	if not player:
		return

	# Oyuncu kılıç kuşanmış olarak seviyeye başlar
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
	if obs_zone_footprint and not obs_zone_footprint.body_entered.is_connected(_on_footprint_zone_body_entered):
		obs_zone_footprint.body_entered.connect(_on_footprint_zone_body_entered)
	if obs_zone_trunk and not obs_zone_trunk.body_entered.is_connected(_on_trunk_zone_body_entered):
		obs_zone_trunk.body_entered.connect(_on_trunk_zone_body_entered)
	if hazard_zone_deadfall and not hazard_zone_deadfall.body_entered.is_connected(_on_deadfall_hazard_body_entered):
		hazard_zone_deadfall.body_entered.connect(_on_deadfall_hazard_body_entered)
	if obs_zone_presence and not obs_zone_presence.body_entered.is_connected(_on_presence_zone_body_entered):
		obs_zone_presence.body_entered.connect(_on_presence_zone_body_entered)


func _on_footprint_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_footprint:
		_seen_footprint = true
		observation_made.emit("first_giant_footprint")
		_pulse_environmental_vignette(Color(0.2, 0.4, 0.25, 0.25), 0.5)


func _on_trunk_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_trunk:
		_seen_trunk = true
		observation_made.emit("shattered_canopy_trunk")
		_pulse_environmental_vignette(Color(0.4, 0.35, 0.2, 0.25), 0.5)


func _on_deadfall_hazard_body_entered(body: Node2D) -> void:
	if body == player and not _deadfall_activated:
		_deadfall_activated = true
		hazard_triggered.emit("unstable_deadfall")
		_trigger_deadfall_sequence()


func _trigger_deadfall_sequence() -> void:
	# 1. Telegraf: Yapraklar dökülür ve kamera hafifçe titrer
	if leaves_particles:
		leaves_particles.amount = 75
		leaves_particles.speed_scale = 1.6

	_apply_camera_shake(2.5, 0.45)

	# 2. Fiziksel Kütük Hareketi: 0.2 saniye gecikmeyle hafifçe çöker / eğilir
	if deadfall_hazard_node and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_interval(0.2)
		tw.tween_property(deadfall_hazard_node, "position:y", deadfall_hazard_node.position.y + 18.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(deadfall_hazard_node, "rotation_degrees", 4.0, 0.35)


func _on_presence_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_presence:
		_seen_presence = true
		distant_presence_sensed.emit()
		_trigger_apex_tension_climax()


func _trigger_apex_tension_climax() -> void:
	# Yaratığın yakında olduğunu hissettiren gerilim zirvesi
	# Ağır adım sarsıntısı: Kamera belirgin biçimde sarsılır
	_apply_camera_shake(4.0, 0.8)

	if leaves_particles:
		leaves_particles.amount = 90
		leaves_particles.speed_scale = 2.0

	# Uzak gölge ağaçların arasından hafifçe süzülür ve sise karışır
	if shadow_silhouette and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(shadow_silhouette, "position:x", shadow_silhouette.position.x + 80.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(shadow_silhouette, "modulate:a", 0.0, 1.4)


func _apply_camera_shake(intensity: float, duration: float) -> void:
	if not _player_camera or not is_inside_tree():
		return
	var tw: Tween = create_tween()
	var steps: int = int(duration / 0.05)
	for i in range(steps):
		var offset_vec: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity * 0.6, intensity * 0.6))
		tw.tween_property(_player_camera, "offset", offset_vec, 0.05)
	tw.tween_property(_player_camera, "offset", Vector2.ZERO, 0.05)


func _pulse_environmental_vignette(color: Color, duration: float) -> void:
	if not is_inside_tree():
		return
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 85
	canvas.add_child(rect)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(rect, "color:a", color.a, duration * 0.4)
	tw.tween_property(rect, "color:a", 0.0, duration * 0.6)
	tw.tween_callback(canvas.queue_free)


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body == player and not _exit_triggered:
		_exit_triggered = true
		level_exit_reached.emit(player)
		_handle_level_exit()


func _handle_level_exit() -> void:
	if not is_inside_tree():
		return

	# Level 05 (Zamandan Kopan Parçalar) sahnesine geçiş
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
		get_tree().change_scene_to_file("res://scenes/levels/stoneage/stoneage_05_temporal_fragments.tscn")
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
