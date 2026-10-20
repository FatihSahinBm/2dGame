class_name Stoneage01TimeRiftFall
extends Node2D

## res://scripts/levels/stoneage/stoneage_01_time_rift_fall.gd
## Taş Devri — Bölüm 01: Zaman Yarığından Düşüş (Stone Age Level 01)
## - Zamansal yarık açılışı ve oyuncunun yarıktan düşüş sekansı
## - Sert yere iniş darbesi, kamera sarsıntısı ve parçacık efektleri
## - Yarığın kararsızlaşıp küçülerek geride artık enerji bırakması
## - Oyuncuya güvenilir, doğal biçimde kontrollerin iade edilmesi
## - Level 02'ye (Sessiz Vadi) bağlanmaya hazır sağ çıkış tetikleyicisi (ExitZone)

signal sequence_started()
signal player_landed()
signal controls_enabled()
signal level_exit_reached(player_node: CharacterBody2D)

@onready var player: CharacterBody2D = $CombatPlayer
@onready var rift: Node2D = $TemporalTimeRift
@onready var rift_sprite: Sprite2D = $TemporalTimeRift/RiftSprite
@onready var rift_particles: CPUParticles2D = $TemporalTimeRift/RiftParticles
@onready var impact_dust: CPUParticles2D = $Effects/ImpactDustParticles
@onready var impact_debris: CPUParticles2D = $Effects/ImpactDebrisParticles
@onready var exit_zone: Area2D = $Environment/ExitZone
@onready var hud: CanvasLayer = $FantasyHUD

var _player_camera: Camera2D = null
var _is_falling_sequence: bool = false
var _fall_velocity: Vector2 = Vector2(28.0, 0.0)
var _sequence_finished: bool = false
var _exit_triggered: bool = false


func _ready() -> void:
	_ensure_node_refs()

	# Oyuncunun kılıç kuşanmasını sağla
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
			_player_camera.limit_right = 2400
			_player_camera.limit_top = -220
			_player_camera.limit_bottom = 650

	_setup_exit_zone()
	_start_entry_sequence()


func _ensure_node_refs() -> void:
	if not player:
		player = get_node_or_null("CombatPlayer") as CharacterBody2D
	if not rift:
		rift = get_node_or_null("TemporalTimeRift")
	if not rift_sprite and rift:
		rift_sprite = rift.get_node_or_null("RiftSprite") as Sprite2D
	if not rift_particles and rift:
		rift_particles = rift.get_node_or_null("RiftParticles") as CPUParticles2D
	if not impact_dust:
		impact_dust = get_node_or_null("Effects/ImpactDustParticles") as CPUParticles2D
	if not impact_debris:
		impact_debris = get_node_or_null("Effects/ImpactDebrisParticles") as CPUParticles2D
	if not exit_zone:
		exit_zone = get_node_or_null("Environment/ExitZone") as Area2D
	if not hud:
		hud = get_node_or_null("FantasyHUD") as CanvasLayer


func _setup_exit_zone() -> void:
	if exit_zone and not exit_zone.body_entered.is_connected(_on_exit_zone_body_entered):
		exit_zone.body_entered.connect(_on_exit_zone_body_entered)


func _start_entry_sequence() -> void:
	_ensure_node_refs()
	sequence_started.emit()

	# Karakteri yarığın merkezine yerleştir ve kontrolleri geçici olarak devral
	if player and rift:
		player.global_position = rift.global_position + Vector2(0, 15)
		player.set_physics_process(false)
		_is_falling_sequence = true
		_fall_velocity = Vector2(35.0, 40.0)

	# Yarığın kararsız enerji titreşimi
	if rift_sprite and is_inside_tree():
		rift_sprite.scale = Vector2(0.3, 0.3)
		rift_sprite.modulate = Color(2.0, 1.8, 3.0, 1.0)
		var tw_rift: Tween = create_tween()
		tw_rift.tween_property(rift_sprite, "scale", Vector2(1.25, 1.25), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_rift.tween_property(rift_sprite, "scale", Vector2(1.0, 1.0), 0.25)
		tw_rift.parallel().tween_property(rift_sprite, "modulate", Color.WHITE, 0.3)


func _physics_process(delta: float) -> void:
	if not _is_falling_sequence or not player:
		return

	# Fiziksel yerçekimi ivmesi
	_fall_velocity.y += 980.0 * delta
	player.velocity = _fall_velocity
	player.move_and_slide()

	# Düşüş animasyonu
	if player.anim_sprite:
		var anim_name: String = "fall_armed" if player.is_armed else "fall"
		if player.anim_sprite.animation != anim_name:
			player.anim_sprite.play(anim_name)

	# Yere temas kontrolü
	if player.is_on_floor():
		_is_falling_sequence = false
		_handle_ground_landing()


func _handle_ground_landing() -> void:
	_ensure_node_refs()
	player_landed.emit()

	# 1. Yere Çarpma Kamera Sarsıntısı
	if _player_camera and is_inside_tree():
		var tw_cam: Tween = create_tween()
		tw_cam.tween_property(_player_camera, "offset:y", 9.0, 0.05)
		tw_cam.tween_property(_player_camera, "offset:y", -7.0, 0.06)
		tw_cam.tween_property(_player_camera, "offset:y", 4.0, 0.06)
		tw_cam.tween_property(_player_camera, "offset:y", 0.0, 0.08)

	# 2. Darbe Parçacıkları (Toz ve Taş Parçaları)
	if player:
		var land_pos: Vector2 = player.global_position
		if impact_dust:
			impact_dust.global_position = land_pos + Vector2(0, -4)
			impact_dust.restart()
			impact_dust.emitting = true
		if impact_debris:
			impact_debris.global_position = land_pos + Vector2(0, -4)
			impact_debris.restart()
			impact_debris.emitting = true

	# 3. Şövalyenin Darbe Emme Duruşu (Crouch Recovery)
	if player and player.anim_sprite:
		var crouch_anim: String = "crouch_armed" if player.is_armed else "crouch"
		player.anim_sprite.play(crouch_anim)

	# 4. Yarığın Kararsız Titreşimi ve Küçülerek Artık Enerji Bırakması
	if rift_sprite and is_inside_tree():
		var tw_rift_close: Tween = create_tween()
		tw_rift_close.tween_property(rift_sprite, "scale", Vector2(1.3, 0.7), 0.1)
		tw_rift_close.tween_property(rift_sprite, "scale", Vector2(0.45, 0.45), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_rift_close.parallel().tween_property(rift_sprite, "modulate:a", 0.55, 0.45)

	# 5. Kontrolün Doğal Biçimde İadesi (0.35 saniye sonra)
	if is_inside_tree():
		get_tree().create_timer(0.35).timeout.connect(func():
			_restore_player_control()
		)
	else:
		_restore_player_control()


func _restore_player_control() -> void:
	if player and is_instance_valid(player):
		player.set_physics_process(true)
		_sequence_finished = true
		controls_enabled.emit()
		if player.anim_sprite:
			var idle_anim: String = "idle_armed" if player.is_armed else "idle"
			player.anim_sprite.play(idle_anim)


const NEXT_LEVEL_PATH: String = "res://scenes/levels/stoneage/stoneage_02_silent_valley.tscn"


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body == player and not _exit_triggered:
		_exit_triggered = true
		level_exit_reached.emit(player)
		_handle_level_exit()


func _handle_level_exit() -> void:
	if not is_inside_tree():
		return
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
		get_tree().change_scene_to_file(NEXT_LEVEL_PATH)
	)
