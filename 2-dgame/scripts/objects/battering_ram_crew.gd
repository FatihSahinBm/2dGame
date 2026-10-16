class_name BatteringRamCrew
extends Node2D

## res://scripts/objects/battering_ram_crew.gd
## 1462 Târgovişte Köprü Kuşatması: Kale Kapısını Koçbaşı ile Parçalayan Yeniçeri Müfrezesi.
## Sinematik kamera yakınlaşması (zoom 1.55x), letterbox ve iki kademeli sarsıntılı darbe animasyonu.

signal sequence_completed()

@onready var carriers_root: Node2D = $Carriers
@onready var carrier_front: AnimatedSprite2D = $Carriers/CarrierFront
@onready var carrier_mid: AnimatedSprite2D = $Carriers/CarrierMid
@onready var carrier_rear: AnimatedSprite2D = $Carriers/CarrierRear
@onready var commander_sprite: AnimatedSprite2D = $Commander/AnimatedSprite2D
@onready var ram_visual: Node2D = $RamVisual

var _original_camera_zoom: Vector2 = Vector2.ONE
var _original_camera_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false


## Koçbaşı hücum ve kapı parçalama sekansını başlatır
func play_assault_sequence(gate_node: Node2D, player_node: CharacterBody2D, dialogue_box: CanvasLayer = null) -> void:
	visible = true
	var camera: Camera2D = null
	if player_node:
		camera = player_node.get_node_or_null("Camera2D") as Camera2D

	# 1. Oyuncunun kontrollerini dondur
	if player_node and "can_move" in player_node:
		player_node.can_move = false
		player_node.velocity.x = 0.0

	# 2. Letterbox açılışı (Üst ve alt 54px sinematik barlar)
	if dialogue_box and dialogue_box.has_method("set_letterbox"):
		dialogue_box.set_letterbox(true, 54.0)

	# 3. Kameranın kapıya odaklanması ve 1.55x dramatik zoom yapması
	if camera and is_instance_valid(camera) and player_node:
		_original_camera_zoom = camera.zoom
		_original_camera_offset = camera.offset

		var target_offset_x = (gate_node.global_position.x - player_node.global_position.x) - 100.0
		var tw_cam = create_tween().set_parallel(true)
		tw_cam.tween_property(camera, "offset:x", target_offset_x, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_cam.tween_property(camera, "offset:y", -30.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_cam.tween_property(camera, "zoom", Vector2(1.55, 1.55), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 4. Askerlerin koçbaşıyla koşarak kapı önüne girmesi
	_set_soldiers_animation("walk")
	global_position = Vector2(gate_node.global_position.x - 360.0, 560.0)

	var tw_run = create_tween()
	tw_run.tween_property(self, "global_position:x", gate_node.global_position.x - 100.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_run.tween_callback(func():
		_set_soldiers_animation("idle")
		_spawn_dust_burst(global_position + Vector2(40.0, 0.0))
		_play_commander_shout("BİR, İKİİİ... KOÇBAŞINI SAVURUN!")
		get_tree().create_timer(0.6).timeout.connect(func():
			_execute_first_ram_strike(gate_node, camera, player_node, dialogue_box)
		)
	)


## 1. Darbe (Ön Vuruş - Kapının sarsılması)
func _execute_first_ram_strike(gate_node: Node2D, camera: Camera2D, player_node: CharacterBody2D, dialogue_box: CanvasLayer) -> void:
	if not ram_visual:
		return

	# Geriye doğru çekilme (Anticipation)
	var tw_prep = create_tween().set_parallel(true)
	tw_prep.tween_property(ram_visual, "position:x", -35.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_prep.tween_property(ram_visual, "rotation_degrees", -3.0, 0.36)
	if carriers_root:
		tw_prep.tween_property(carriers_root, "rotation_degrees", -4.0, 0.36)

	tw_prep.chain().tween_callback(func():
		# Hızlı ileri fırlama (Slam)
		var tw_slam = create_tween().set_parallel(true)
		tw_slam.tween_property(ram_visual, "position:x", 42.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw_slam.tween_property(ram_visual, "rotation_degrees", 2.0, 0.12)
		if carriers_root:
			tw_slam.tween_property(carriers_root, "rotation_degrees", 3.0, 0.12)

		tw_slam.chain().tween_callback(func():
			# 💥 1. Darbe Etkisi (GÜÜÜM!)
			_apply_screen_shake(camera, 11.0, 0.25)
			_spawn_hit_spark(gate_node.global_position + Vector2(-16.0, 20.0), false)
			_spawn_floating_text("💥 GÜÜÜM!", gate_node.global_position + Vector2(-25.0, -80.0), Color(1.0, 0.5, 0.2, 1.0), 16)

			# Kapı sarsıntısı
			var tw_gate = create_tween()
			tw_gate.tween_property(gate_node, "position:x", gate_node.position.x + 8.0, 0.05)
			tw_gate.tween_property(gate_node, "position:x", gate_node.position.x, 0.08)

			# Geri sekme
			var tw_rebound = create_tween().set_parallel(true)
			tw_rebound.tween_property(ram_visual, "position:x", -15.0, 0.22).set_trans(Tween.TRANS_QUAD)
			tw_rebound.tween_property(ram_visual, "rotation_degrees", 0.0, 0.22)
			if carriers_root:
				tw_rebound.tween_property(carriers_root, "rotation_degrees", 0.0, 0.22)

			# Kumandan 2. darbe emri
			get_tree().create_timer(0.45).timeout.connect(func():
				_play_commander_shout("BİR DAHA! TÜM KUVVETİNİZLE! ALLAH ALLAH!")
				get_tree().create_timer(0.55).timeout.connect(func():
					_execute_second_ram_strike(gate_node, camera, player_node, dialogue_box)
				)
			)
		)
	)


## 2. Darbe (Nihai Vuruş - Devasa GÜÜÜÜÜM ve Kapının Parçalanması)
func _execute_second_ram_strike(gate_node: Node2D, camera: Camera2D, player_node: CharacterBody2D, dialogue_box: CanvasLayer) -> void:
	if not ram_visual:
		return

	# Derin geriye çekilme (Maksimum potansiyel enerji)
	var tw_prep = create_tween().set_parallel(true)
	tw_prep.tween_property(ram_visual, "position:x", -58.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_prep.tween_property(ram_visual, "rotation_degrees", -6.0, 0.48)
	if carriers_root:
		tw_prep.tween_property(carriers_root, "rotation_degrees", -7.0, 0.48)

	tw_prep.chain().tween_callback(func():
		# Maksimum hızla kapıya çakılma
		var tw_slam = create_tween().set_parallel(true)
		tw_slam.tween_property(ram_visual, "position:x", 65.0, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw_slam.tween_property(ram_visual, "rotation_degrees", 3.0, 0.13)
		if carriers_root:
			tw_slam.tween_property(carriers_root, "rotation_degrees", 4.0, 0.13)

		tw_slam.chain().tween_callback(func():
			# 💥💥 DEVAŞA GÜÜÜÜÜM!
			# Emil Kowalski Juice Kuralı: Maksimum etki için mikro hit-stop (0.08s)
			Engine.time_scale = 0.08
			get_tree().create_timer(0.08, true, false, true).timeout.connect(func():
				Engine.time_scale = 1.0
			)

			_apply_screen_shake(camera, 22.0, 0.55)
			_spawn_hit_spark(gate_node.global_position + Vector2(-16.0, 20.0), true)
			_spawn_splinters_explosion(gate_node.global_position + Vector2(0.0, 10.0))
			_spawn_dust_burst(gate_node.global_position + Vector2(0.0, 40.0), 32)
			_spawn_floating_text("💥💥 GÜÜÜÜÜÜMMM!", gate_node.global_position + Vector2(-40.0, -100.0), Color(1.0, 0.85, 0.2, 1.0), 22)

			# Kapı kanatlarının parçalanması ve içeri uçması
			_shatter_gate_visuals(gate_node)

			# Zafer sevinci
			_play_commander_shout("KAPI YIKILDI! YABANCI, MAHZENE DAL VE VLAD'I BUL!")
			_play_soldiers_cheer()

			# Sekans bitişi ve kameranın oyuncuya geri dönmesi
			get_tree().create_timer(1.4).timeout.connect(func():
				_conclude_sequence(camera, player_node, dialogue_box)
			)
		)
	)


## Kapının menteşelerinden koparak parçalanması animasyonu
func _shatter_gate_visuals(gate_node: Node2D) -> void:
	var portcullis: ColorRect = gate_node.get_node_or_null("PortcullisBars") as ColorRect
	if portcullis:
		var tw_port = create_tween().set_parallel(true)
		tw_port.tween_property(portcullis, "position:y", portcullis.position.y - 120.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw_port.tween_property(portcullis, "modulate:a", 0.0, 0.45)
		tw_port.tween_property(portcullis, "scale:x", 0.1, 0.45)

	var doors: Node2D = gate_node.get_node_or_null("WoodenDoors") as Node2D
	if doors:
		var tw_doors = create_tween().set_parallel(true)
		tw_doors.tween_property(doors, "scale:x", 0.05, 0.35)
		tw_doors.tween_property(doors, "modulate:a", 0.0, 0.4)

	# Kale kemerinden yayılan kızıl mahzen sisi efekti
	var mist: CPUParticles2D = CPUParticles2D.new()
	mist.emitting = true
	mist.amount = 28
	mist.lifetime = 1.4
	mist.speed_scale = 0.8
	mist.spread = 180.0
	mist.gravity = Vector2(-20, -10)
	mist.initial_velocity_min = 20.0
	mist.initial_velocity_max = 60.0
	mist.color = Color(0.7, 0.08, 0.15, 0.5)
	mist.scale_amount_min = 3.0
	mist.scale_amount_max = 8.0
	mist.global_position = gate_node.global_position + Vector2(0.0, 20.0)
	gate_node.add_child(mist)


## Sekansı tamamlar ve kamerayı oyuncuya pürüzsüz geri getirir
func _conclude_sequence(camera: Camera2D, player_node: CharacterBody2D, dialogue_box: CanvasLayer) -> void:
	if camera and is_instance_valid(camera):
		var tw_cam = create_tween().set_parallel(true)
		tw_cam.tween_property(camera, "offset", _original_camera_offset, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_cam.tween_property(camera, "zoom", _original_camera_zoom, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if dialogue_box and dialogue_box.has_method("set_letterbox"):
		dialogue_box.set_letterbox(false, 54.0)

	if player_node and "can_move" in player_node:
		player_node.can_move = true

	sequence_completed.emit()


func _set_soldiers_animation(anim_name: String) -> void:
	for sprite in [carrier_front, carrier_mid, carrier_rear, commander_sprite]:
		if sprite and is_instance_valid(sprite) and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)


func _play_soldiers_cheer() -> void:
	if ram_visual:
		var tw_rest = create_tween()
		tw_rest.tween_property(ram_visual, "position:y", ram_visual.position.y + 12.0, 0.2)

	_spawn_floating_text("ALLAH ALLAH!", global_position + Vector2(20.0, -60.0), Color(1.0, 0.9, 0.4, 1.0), 13)
	_spawn_floating_text("GAZA BİZİMDİR!", global_position + Vector2(-40.0, -75.0), Color(1.0, 0.85, 0.3, 1.0), 13)


func _play_commander_shout(text: String) -> void:
	_spawn_floating_text(text, global_position + Vector2(-110.0, -70.0), Color(1.0, 0.95, 0.45, 1.0), 13)


func _apply_screen_shake(camera: Camera2D, intensity: float, duration: float) -> void:
	if not camera or not is_instance_valid(camera):
		return
	var base_offset = camera.offset
	var steps = int(duration / 0.04)
	var tw = create_tween()
	for i in range(steps):
		var damp = 1.0 - (float(i) / float(steps))
		var shake = Vector2(randf_range(-intensity, intensity) * damp, randf_range(-intensity, intensity) * damp)
		tw.tween_property(camera, "offset", base_offset + shake, 0.04)
	tw.tween_property(camera, "offset", base_offset, 0.04)


func _spawn_floating_text(text: String, pos: Vector2, color: Color, size: int) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", size)
	label.global_position = pos

	var parent_scene = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 1.1)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 1.1)
		tw.tween_callback(label.queue_free)


func _spawn_hit_spark(pos: Vector2, is_massive: bool) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 32 if is_massive else 14
	particles.lifetime = 0.45 if is_massive else 0.25
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 80.0 if is_massive else 40.0
	particles.initial_velocity_max = 220.0 if is_massive else 110.0
	particles.color = Color(1.0, 0.8, 0.2, 1.0)
	particles.global_position = pos
	parent_scene.add_child(particles)
	particles.finished.connect(particles.queue_free)


func _spawn_splinters_explosion(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 0.65
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 260.0
	particles.color = Color(0.48, 0.3, 0.16, 1.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.global_position = pos
	parent_scene.add_child(particles)
	particles.finished.connect(particles.queue_free)


func _spawn_dust_burst(pos: Vector2, amount: int = 16) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var dust = CPUParticles2D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.amount = amount
	dust.lifetime = 0.7
	dust.explosiveness = 0.8
	dust.spread = 180.0
	dust.gravity = Vector2(0, -30)
	dust.initial_velocity_min = 25.0
	dust.initial_velocity_max = 80.0
	dust.color = Color(0.3, 0.28, 0.3, 0.6)
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 7.0
	dust.global_position = pos
	parent_scene.add_child(dust)
	dust.finished.connect(dust.queue_free)
