class_name Stoneage05TemporalFragments
extends Node2D

## res://scripts/levels/stoneage/stoneage_05_temporal_fragments.gd
## Taş Devri — Bölüm 05: Zamandan Kopan Parçalar (Stone Age Level 05)
## - Avcıların İzleri'ni takip eden şövalyenin ulaştığı sarp, kayalık bazalt fay kanyonu
## - Çevresel Hikâye Anlatımı: Taş Devri jeolojisine yabancı eskimiş metal plakalar,
##   kopmuş mekanik eklemler, hidrolik piston kovanı ve devasa bir robotik omuz soketi
## - Gelecekteki Dev Anne T-Rex boss'unun mekanik uzuvlarını kademeli olarak hissettirir;
##   ancak boss'un tam bedenini veya savaşını açığa çıkarmaz
## - Soğuk zamansal enerji arkları ve rezonans titreşimleri
## - Gelecek Level 06 (Dev Yaratığın Bölgesi) için hazır çıkış alanı (ExitZone)

signal level_started()
signal remnant_discovered(remnant_type: String)
signal temporal_resonance_triggered()
signal massive_socket_observed()
signal level_exit_reached(player_node: CharacterBody2D)

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var exit_zone: Area2D = $Environment/ExitZone
@onready var obs_zone_plates: Area2D = $Environment/ObservationZonePlates
@onready var obs_zone_joint: Area2D = $Environment/ObservationZoneJoint
@onready var resonance_zone: Area2D = $Environment/TemporalResonanceZone
@onready var obs_zone_socket: Area2D = $Environment/ObservationZoneSocket

@onready var socket_prop: Sprite2D = $MechanicalRemnants/MassiveArmatureSocket
@onready var temporal_arcs: CPUParticles2D = $AtmosphericEffects/TemporalArcParticles
@onready var temporal_motes: CPUParticles2D = $AtmosphericEffects/TemporalMoteParticles

var _player_camera: Camera2D = null
var _exit_triggered: bool = false
var _seen_plates: bool = false
var _seen_joint: bool = false
var _seen_resonance: bool = false
var _seen_socket: bool = false


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
	if not obs_zone_plates:
		obs_zone_plates = get_node_or_null("Environment/ObservationZonePlates") as Area2D
	if not obs_zone_joint:
		obs_zone_joint = get_node_or_null("Environment/ObservationZoneJoint") as Area2D
	if not resonance_zone:
		resonance_zone = get_node_or_null("Environment/TemporalResonanceZone") as Area2D
	if not obs_zone_socket:
		obs_zone_socket = get_node_or_null("Environment/ObservationZoneSocket") as Area2D
	if not socket_prop:
		socket_prop = get_node_or_null("MechanicalRemnants/MassiveArmatureSocket") as Sprite2D
	if not temporal_arcs:
		temporal_arcs = get_node_or_null("AtmosphericEffects/TemporalArcParticles") as CPUParticles2D
	if not temporal_motes:
		temporal_motes = get_node_or_null("AtmosphericEffects/TemporalMoteParticles") as CPUParticles2D


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
	if obs_zone_plates and not obs_zone_plates.body_entered.is_connected(_on_plates_zone_body_entered):
		obs_zone_plates.body_entered.connect(_on_plates_zone_body_entered)
	if obs_zone_joint and not obs_zone_joint.body_entered.is_connected(_on_joint_zone_body_entered):
		obs_zone_joint.body_entered.connect(_on_joint_zone_body_entered)
	if resonance_zone and not resonance_zone.body_entered.is_connected(_on_resonance_zone_body_entered):
		resonance_zone.body_entered.connect(_on_resonance_zone_body_entered)
	if obs_zone_socket and not obs_zone_socket.body_entered.is_connected(_on_socket_zone_body_entered):
		obs_zone_socket.body_entered.connect(_on_socket_zone_body_entered)


func _on_plates_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_plates:
		_seen_plates = true
		remnant_discovered.emit("embedded_alloy_plates")
		_pulse_environmental_vignette(Color(0.2, 0.35, 0.55, 0.22), 0.5)


func _on_joint_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_joint:
		_seen_joint = true
		remnant_discovered.emit("severed_mechanical_joint")
		_pulse_environmental_vignette(Color(0.25, 0.4, 0.6, 0.25), 0.5)


func _on_resonance_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_resonance:
		_seen_resonance = true
		temporal_resonance_triggered.emit()
		_trigger_temporal_resonance_event()


func _trigger_temporal_resonance_event() -> void:
	# Metal kalıntıların arasında yankılanan hafif zamansal enerji rezonansı
	if temporal_arcs:
		temporal_arcs.amount = 25
		temporal_arcs.emitting = true

	if temporal_motes:
		temporal_motes.amount = 45

	_apply_camera_shake(1.8, 0.45)
	_pulse_environmental_vignette(Color(0.35, 0.5, 0.85, 0.3), 0.6)


func _on_socket_zone_body_entered(body: Node2D) -> void:
	if body == player and not _seen_socket:
		_seen_socket = true
		massive_socket_observed.emit()
		_trigger_massive_socket_climax()


func _trigger_massive_socket_climax() -> void:
	# Devasa soket alanında derin zamansal nabız ve görsel vurgu
	_apply_camera_shake(2.8, 0.6)
	_pulse_environmental_vignette(Color(0.3, 0.55, 0.95, 0.35), 0.8)

	if socket_prop and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(socket_prop, "modulate", Color(1.3, 1.4, 1.8, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(socket_prop, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


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

	# Level 06 (Dev Yaratığın Bölgesi) sahnesine geçiş
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
		get_tree().change_scene_to_file("res://scenes/levels/stoneage/stoneage_06_beasts_domain.tscn")
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
