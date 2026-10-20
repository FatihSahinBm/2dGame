class_name StoneAge08FirstHeartFragment
extends Node2D

## res://scripts/levels/stoneage/stoneage_08_first_heart_fragment.gd
## Taş Devri — Bölüm 08: İlk Kalp Parçası (The First Heart Fragment)
##
## Dev Anne T-Rex boss savaşının ardından gelen final hikâye ve çağ geçişi seviyesi.
## - Boss arenası savaş sonrası sessizlik ve yıkım durumundadır (yenilmiş T-Rex enkazı).
## - İlk Kalp Parçası (World Heart Fragment) toplanabilir bir oyun nesnesidir.
## - Toplandığında: Parça animasyonu, GameState güncellemesi ve ilk Flashback sekansı tetiklenir.
## - Flashback: 1462 Eflak Seferi orman kampı ve kılıç ruhunun kadim anısı.
## - Zaman Yırtığı (Dimensional Time Rift) açılır ve sonraki çağa (Vlad / Eflak) geçişi sağlar.

signal heart_fragment_picked_up
signal flashback_started
signal flashback_ended
signal time_rift_opened
signal time_rift_entered(player: Node2D)

@export var next_era_scene_path: String = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
@export var camera_limits: Rect2i = Rect2i(0, 0, 2400, 720)

@onready var player: Node2D = get_node_or_null("CombatPlayer")
@onready var hud: CanvasLayer = get_node_or_null("FantasyHUD")
@onready var heart_node: Node2D = get_node_or_null("HeartFragment")
@onready var heart_sprite: Sprite2D = get_node_or_null("HeartFragment/HeartSprite")
@onready var heart_glow: Sprite2D = get_node_or_null("HeartFragment/GlowSprite")
@onready var heart_particles: CPUParticles2D = get_node_or_null("HeartFragment/PickupParticles")
@onready var time_rift: Node2D = get_node_or_null("TemporalTimeRift")
@onready var time_rift_sprite: Sprite2D = get_node_or_null("TemporalTimeRift/RiftSprite")
@onready var time_rift_particles: CPUParticles2D = get_node_or_null("TemporalTimeRift/RiftParticles")
@onready var flashback_canvas: CanvasLayer = get_node_or_null("FlashbackSequence")

var _player_camera: Camera2D = null
var _fragment_collected: bool = false
var _flashback_active: bool = false
var _rift_active: bool = false
var _transition_triggered: bool = false
var _hover_time: float = 0.0
var _base_heart_y: float = 460.0


func _ready() -> void:
	_ensure_node_refs()
	_setup_player()
	_setup_camera()
	_setup_initial_states()
	_play_fade_in()


func _ensure_node_refs() -> void:
	if not player:
		player = get_node_or_null("CombatPlayer")
	if not hud:
		hud = get_node_or_null("FantasyHUD")
	if not heart_node:
		heart_node = get_node_or_null("HeartFragment")
	if not heart_sprite:
		heart_sprite = get_node_or_null("HeartFragment/HeartSprite") as Sprite2D
	if not heart_glow:
		heart_glow = get_node_or_null("HeartFragment/GlowSprite") as Sprite2D
	if not heart_particles:
		heart_particles = get_node_or_null("HeartFragment/PickupParticles") as CPUParticles2D
	if not time_rift:
		time_rift = get_node_or_null("TemporalTimeRift")
	if not time_rift_sprite:
		time_rift_sprite = get_node_or_null("TemporalTimeRift/RiftSprite") as Sprite2D
	if not time_rift_particles:
		time_rift_particles = get_node_or_null("TemporalTimeRift/RiftParticles") as CPUParticles2D
	if not flashback_canvas:
		flashback_canvas = get_node_or_null("FlashbackSequence") as CanvasLayer


func _setup_player() -> void:
	if not player:
		return
	if "has_sword" in player:
		player.has_sword = true
	if "is_armed" in player:
		player.is_armed = true


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


func _setup_initial_states() -> void:
	# Kalp parçası başlangıçta krater üzerinde parıldayarak havada durur
	if heart_node:
		heart_node.visible = true
		_base_heart_y = heart_node.position.y

	# Zaman yarığı başlangıçta kapalıdır; flashback sonrasında açılır
	if time_rift:
		time_rift.visible = false
		time_rift.modulate.a = 0.0

	# Flashback katmanı başlangıçta gizlidir
	if flashback_canvas:
		flashback_canvas.visible = false

	# Tetikleyicileri bağla
	var heart_area = get_node_or_null("HeartFragment/Area2D") as Area2D
	if heart_area and not heart_area.body_entered.is_connected(_on_heart_fragment_body_entered):
		heart_area.body_entered.connect(_on_heart_fragment_body_entered)

	var rift_area = get_node_or_null("TemporalTimeRift/Area2D") as Area2D
	if rift_area and not rift_area.body_entered.is_connected(_on_time_rift_body_entered):
		rift_area.body_entered.connect(_on_time_rift_body_entered)

	# HUD başlangıç metni
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"TAŞ DEVRİ — ZAFER VE HİKMET",
			"İlk Kalp Parçası",
			"Kraterdeki kadim Dünyanın Kalbi parçasına yaklaş ve kaderini öğren."
		)


func _process(delta: float) -> void:
	# Kalp Parçasının organik bekleme (idle) süzülme animasyonu
	if not _fragment_collected and heart_node and heart_node.visible:
		_hover_time += delta * 2.2
		heart_node.position.y = _base_heart_y + sin(_hover_time) * 6.0
		if heart_glow:
			var pulse: float = 0.85 + (sin(_hover_time * 1.8) * 0.25)
			heart_glow.scale = Vector2(pulse, pulse)
			heart_glow.modulate.a = 0.65 + (sin(_hover_time * 1.8) * 0.2)


# -------------------------------------------------------------
# 1. KALP PARÇASININ TOPLANMASI (PICKUP)
# -------------------------------------------------------------

func _on_heart_fragment_body_entered(body: Node2D) -> void:
	var is_p = (body == player or (player != null and body.name == player.name))
	if is_p and not _fragment_collected:
		_fragment_collected = true
		heart_fragment_picked_up.emit()
		_collect_heart_fragment()


func _collect_heart_fragment() -> void:
	# Toplanma animasyonu: Işık patlaması ve oyuncunun göğsüne doğru çekilme
	_apply_camera_shake(1.8, 0.4)
	if heart_particles:
		heart_particles.restart()
		heart_particles.emitting = true

	# Küresel GameState güncellemesi
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state:
		game_state.current_heart_pieces = 1
		if game_state.has_method("unlock_ability"):
			game_state.unlock_ability("heart_resonance")

	# Parçanın oyuncuya doğru süzülmesi
	if heart_node and is_inside_tree() and player:
		var target_pos = player.position + Vector2(0, -35)
		var tw: Tween = create_tween()
		tw.tween_property(heart_node, "position", target_pos, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(heart_node, "scale", Vector2(1.4, 1.4), 0.3)
		tw.tween_property(heart_node, "scale", Vector2(0.0, 0.0), 0.35)
		tw.tween_callback(func():
			if heart_node:
				heart_node.visible = false
			_start_first_flashback()
		)


# -------------------------------------------------------------
# 2. İLK FLASHBACK SEKANSI (1462 EFLAK VE KILIÇ RUHU ANISI)
# -------------------------------------------------------------

func _start_first_flashback() -> void:
	if _flashback_active or not is_inside_tree():
		return
	_flashback_active = true
	flashback_started.emit()

	# Oyuncu kontrolünü geçici durdur
	if player and "can_move" in player:
		player.can_move = false

	# HUD bildirim toast
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"GEÇMİŞİN YANKILARI — FLASHBACK",
			"M.S. 1462 / Eflak Seferi",
			"Kılıca mühürlenen ruhun anıları zihninde canlanıyor..."
		)

	# Flashback katmanını göster ve crossfade ile yumuşakça aç
	if flashback_canvas:
		flashback_canvas.visible = true
		var control = flashback_canvas.get_node_or_null("Control") as Control
		if control:
			control.modulate.a = 0.0
			var tw_flash: Tween = create_tween()
			tw_flash.tween_property(control, "modulate:a", 1.0, 0.8)

		# Spektral kılıç ruhunun nefes alma efekti
		var sword_sp: Sprite2D = flashback_canvas.get_node_or_null("Control/SpectralSword") as Sprite2D
		if sword_sp:
			var tw_sword: Tween = create_tween().set_loops(3)
			tw_sword.tween_property(sword_sp, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE)
			tw_sword.tween_property(sword_sp, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

	# Flashback süresi (4.0 saniye sonra ana oyuna yumuşak dönüş)
	get_tree().create_timer(4.2).timeout.connect(_end_first_flashback)


func _end_first_flashback() -> void:
	if not _flashback_active or not is_inside_tree():
		return
	_flashback_active = false
	flashback_ended.emit()

	# Flashback katmanını hemen kapat
	if flashback_canvas:
		flashback_canvas.visible = false

	# Oyuncu kontrolünü geri ver
	if player and "can_move" in player:
		player.can_move = true

	# Flashback sonrası Zaman Yırtığını aç!
	_open_time_rift()


# -------------------------------------------------------------
# 3. ZAMAN YIRTIĞININ AÇILMASI (TEMPORAL RIFT REVEAL)
# -------------------------------------------------------------

func _open_time_rift() -> void:
	if _rift_active or not is_inside_tree():
		return
	_rift_active = true
	time_rift_opened.emit()

	_apply_camera_shake(2.4, 0.8)
	_pulse_vignette(Color(0.2, 0.6, 0.9, 0.4), 0.9)

	if time_rift:
		time_rift.visible = true
		time_rift.scale = Vector2(0.05, 0.05)
		time_rift.modulate.a = 0.0

		var tw_rift: Tween = create_tween()
		tw_rift.tween_property(time_rift, "modulate:a", 1.0, 0.4)
		tw_rift.parallel().tween_property(time_rift, "scale", Vector2(1.15, 1.15), 0.7).set_trans(Tween.TRANS_BACK)
		tw_rift.tween_property(time_rift, "scale", Vector2(1.0, 1.0), 0.3)

		if time_rift_particles:
			time_rift_particles.emitting = true

	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"ZAMAN YIRTIĞI AÇILDI",
			"Geleceğe ve Geçmişe Açılan Geçit",
			"Yırtığa girerek Taş Devri'nden sonraki çağa (Eflak Seferi) adım at!"
		)


# -------------------------------------------------------------
# 4. SONRAKİ ÇAĞA GEÇİŞ (TRANSITION TO NEXT ERA)
# -------------------------------------------------------------

func _on_time_rift_body_entered(body: Node2D) -> void:
	var is_p = (body == player or (player != null and body.name == player.name))
	if is_p and _rift_active and not _transition_triggered:
		_transition_triggered = true
		time_rift_entered.emit(player)
		_execute_era_transition()


func _execute_era_transition() -> void:
	if not is_inside_tree():
		return

	# Oyuncuyu girdaba çeken ve sahneyi karartan sinematik geçiş
	_apply_camera_shake(3.0, 0.9)
	if player and "can_move" in player:
		player.can_move = false

	if player and time_rift:
		var tw_player: Tween = create_tween()
		tw_player.tween_property(player, "global_position", time_rift.global_position, 0.6).set_trans(Tween.TRANS_QUAD)
		tw_player.parallel().tween_property(player, "scale", Vector2(0.1, 0.1), 0.6)
		tw_player.parallel().tween_property(player, "modulate:a", 0.0, 0.6)

	var fade_overlay: ColorRect = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(fade_overlay)
	add_child(canvas)

	var tw_fade: Tween = create_tween()
	tw_fade.tween_interval(0.3)
	tw_fade.tween_property(fade_overlay, "color:a", 1.0, 0.8)
	tw_fade.tween_callback(func():
		if ResourceLoader.exists(next_era_scene_path):
			get_tree().change_scene_to_file(next_era_scene_path)
		else:
			print("Level 08 Tamamlandı! Sonraki çağ sahnesi (%s) henüz mevcut değil." % next_era_scene_path)
	)


# -------------------------------------------------------------
# YARDIMCI VE EFEKT FONKSİYONLARI
# -------------------------------------------------------------

func _apply_camera_shake(intensity: float, duration: float) -> void:
	if not _player_camera or not is_inside_tree():
		return
	var tw: Tween = create_tween()
	var steps: int = int(duration / 0.05)
	for i in range(steps):
		var offset_vec: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity * 0.6, intensity * 0.6))
		tw.tween_property(_player_camera, "offset", offset_vec, 0.05)
	tw.tween_property(_player_camera, "offset", Vector2.ZERO, 0.05)


func _pulse_vignette(color: Color, duration: float) -> void:
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
	tw.tween_property(rect, "color:a", color.a, duration * 0.35)
	tw.tween_property(rect, "color:a", 0.0, duration * 0.65)
	tw.tween_callback(canvas.queue_free)


func _play_fade_in() -> void:
	if not is_inside_tree():
		return
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
