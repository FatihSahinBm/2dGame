class_name Stoneage06BeastsDomain
extends Node2D

## res://scripts/levels/stoneage/stoneage_06_beasts_domain.gd
## Taş Devri — Bölüm 06: Dev Yaratığın Bölgesi (The Beast's Domain)
##
## Bu bölüm, Stone Age serisinde Level 07 (Dev Anne T-Rex Boss Karşılaşması) öncesi
## son keşif, çevresel hikâye anlatımı ve gerilim inşa seviyesidir.
##
## Çevresel Anlatım ve Boss Gösterim Sınırları:
## - T-Rex'in tam bedeni, net sprite'ı veya boss savaşı ASLA gösterilmez.
## - Yaratığın devasa boyutları; kırılmış dev ağaçlar (12-15m), derin 3 parmaklı ayak izleri,
##   ve devasa fosil kemik kümeleriyle hissettirilir.
## - Level 05'teki mekanik kalıntıların devamı olarak kayalara saplanmış ağır titanyum
##   pençe zırhı ve bükülmüş omurga desteği yer alır.
## - Devasa yuva çukuru yaklaşımında uzaktan gölge geçişi ve yer sarsıntısı tetiklenir.
## - Çıkış alanı, Level 07 için karanlık mağara/in ağzına sinematik geçiş hazırlar.

signal footprint_tremor_triggered
signal mechanical_claw_observed
signal distant_beast_movement_observed
signal nest_depression_reached
signal level_exit_reached(player: Node2D)

@export var camera_limits: Rect2i = Rect2i(0, 0, 4200, 720)

@onready var player: Node2D = get_node_or_null("CombatPlayer")
@onready var hud: CanvasLayer = get_node_or_null("FantasyHUD")
@onready var claw_sheath_prop: Sprite2D = get_node_or_null("MechanicalRemnants/HeavyClawSheath")
@onready var spine_strut_prop: Sprite2D = get_node_or_null("MechanicalRemnants/ReinforcingSpineStrut")
@onready var dust_particles: CPUParticles2D = get_node_or_null("AtmosphericEffects/GroundDustParticles")
@onready var spore_particles: CPUParticles2D = get_node_or_null("AtmosphericEffects/SporeMoteParticles")

var _player_camera: Camera2D = null
var _seen_footprint: bool = false
var _seen_claw: bool = false
var _seen_nest: bool = false
var _exit_triggered: bool = false


func _ready() -> void:
	_ensure_node_refs()
	_setup_player()
	_setup_camera()
	_setup_triggers()
	_play_fade_in()


func _ensure_node_refs() -> void:
	if not player:
		player = get_node_or_null("CombatPlayer")
	if not hud:
		hud = get_node_or_null("FantasyHUD")
	if not claw_sheath_prop:
		claw_sheath_prop = get_node_or_null("MechanicalRemnants/HeavyClawSheath") as Sprite2D
	if not spine_strut_prop:
		spine_strut_prop = get_node_or_null("MechanicalRemnants/ReinforcingSpineStrut") as Sprite2D
	if not dust_particles:
		dust_particles = get_node_or_null("AtmosphericEffects/GroundDustParticles") as CPUParticles2D
	if not spore_particles:
		spore_particles = get_node_or_null("AtmosphericEffects/SporeMoteParticles") as CPUParticles2D


func _setup_player() -> void:
	if not player:
		return
	if player.has_signal("player_died"):
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)


func _setup_camera() -> void:
	if not player:
		return
	_player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if not _player_camera:
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.position_smoothing_enabled = true
		player.add_child(cam)
		_player_camera = cam

	_player_camera.limit_left = camera_limits.position.x
	_player_camera.limit_top = camera_limits.position.y
	_player_camera.limit_right = camera_limits.end.x
	_player_camera.limit_bottom = camera_limits.end.y


func _setup_triggers() -> void:
	var fp_zone = get_node_or_null("Environment/FootprintTremorZone") as Area2D
	if fp_zone and not fp_zone.body_entered.is_connected(_on_footprint_zone_body_entered):
		fp_zone.body_entered.connect(_on_footprint_zone_body_entered)

	var claw_zone = get_node_or_null("Environment/ObservationZoneClaw") as Area2D
	if claw_zone and not claw_zone.body_entered.is_connected(_on_claw_zone_body_entered):
		claw_zone.body_entered.connect(_on_claw_zone_body_entered)

	var nest_zone = get_node_or_null("Environment/NestDepressionZone") as Area2D
	if nest_zone and not nest_zone.body_entered.is_connected(_on_nest_zone_body_entered):
		nest_zone.body_entered.connect(_on_nest_zone_body_entered)

	var exit_zone = get_node_or_null("Environment/ExitZone") as Area2D
	if exit_zone and not exit_zone.body_entered.is_connected(_on_exit_zone_body_entered):
		exit_zone.body_entered.connect(_on_exit_zone_body_entered)


func _on_player_died() -> void:
	call_deferred("_restart_level")


func _restart_level() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


# -------------------------------------------------------------
# ÇEVRESEL HİKÂYE ANLATIMI VE GERİLİM OLAYLARI
# -------------------------------------------------------------

func _on_footprint_zone_body_entered(body: Node2D) -> void:
	var is_p = (body == player or (player != null and body.name == player.name))
	if is_p and not _seen_footprint:
		_seen_footprint = true
		footprint_tremor_triggered.emit()
		_trigger_footprint_tremor()


func _trigger_footprint_tremor() -> void:
	# İlk devasa ayak izine basıldığında hafif yer sarsıntısı ve kalkan toz
	_apply_camera_shake(1.8, 0.45)
	if dust_particles:
		dust_particles.position = Vector2(1080, 560)
		dust_particles.restart()
		dust_particles.emitting = true
	_pulse_environmental_vignette(Color(0.12, 0.08, 0.05, 0.25), 0.5)


func _on_claw_zone_body_entered(body: Node2D) -> void:
	var is_p = (body == player or (player != null and body.name == player.name))
	if is_p and not _seen_claw:
		_seen_claw = true
		mechanical_claw_observed.emit()
		_trigger_claw_observation()


func _trigger_claw_observation() -> void:
	# Kayaya saplanmış titanyum pençe kaplamasında hafif metalik titreşim ve vurgu
	_apply_camera_shake(1.2, 0.3)
	if claw_sheath_prop and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(claw_sheath_prop, "modulate", Color(1.3, 1.4, 1.7, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(claw_sheath_prop, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse_environmental_vignette(Color(0.2, 0.4, 0.65, 0.25), 0.6)


func _on_nest_zone_body_entered(body: Node2D) -> void:
	var is_p = (body == player or (player != null and body.name == player.name))
	if is_p and not _seen_nest:
		_seen_nest = true
		nest_depression_reached.emit()
		distant_beast_movement_observed.emit()
		_trigger_nest_tension_moment()


func _trigger_nest_tension_moment() -> void:
	# Yuva alanına ulaşıldığında derin gerilim: yer sarsıntısı, uzaktan gölge geçişi
	_apply_camera_shake(2.6, 0.7)
	_pulse_environmental_vignette(Color(0.08, 0.04, 0.03, 0.45), 1.0)

	# Uzak kanopi arkasından hızla süzülen gizemli devasa siluet gölgesi
	var shadow_sp: Sprite2D = get_node_or_null("Environment/DistantBeastSilhouette") as Sprite2D
	if shadow_sp and is_inside_tree():
		shadow_sp.visible = true
		shadow_sp.modulate.a = 0.0
		var tw_shadow: Tween = create_tween()
		tw_shadow.tween_property(shadow_sp, "modulate:a", 0.65, 0.4)
		tw_shadow.tween_property(shadow_sp, "position:x", shadow_sp.position.x + 350.0, 1.2)
		tw_shadow.parallel().tween_property(shadow_sp, "modulate:a", 0.0, 0.8)


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
	var is_p = (body == player or (player != null and body.name == player.name))
	if is_p and not _exit_triggered:
		_exit_triggered = true
		level_exit_reached.emit(player)
		_handle_level_exit()


func _handle_level_exit() -> void:
	if not is_inside_tree():
		return

	# Level 07 (Dev Anne T-Rex Lair/Boss Karşılaşması) için sinematik geçiş
	_apply_camera_shake(3.0, 0.8)
	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 90
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.8)
	# Gelecekteki Level 07 sahnesi henüz oluşturulmadığından çökmeyi engellemek için
	# dosyanın varlığını kontrol et; mevcut olduğunda doğrudan sahneye geç.
	tw.tween_callback(func():
		var l7_path = "res://scenes/levels/stoneage/stoneage_07_mother_trex.tscn"
		if ResourceLoader.exists(l7_path):
			get_tree().change_scene_to_file(l7_path)
		else:
			print("Level 06 Tamamlandı! Level 07 (Dev Anne T-Rex) henüz oluşturulmadı.")
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
