class_name ThrowableProjectile
extends Area2D

## res://scripts/projectiles/throwable_projectile.gd
## Fırlatılabilir İkincil Eşyalar (Bıçak, Meşale, Kutsal Su) için temel mermi sınıfı.
## Parabolik yörünge, tür bazlı çarpışma ve hedef filtreleme kurallarını yönetir.

enum ProjectileType {
	KNIFE,
	TORCH,
	HOLY_WATER
}

signal impacted(target: Node2D, hit_position: Vector2)
signal solid_hit(surface: Node2D, hit_position: Vector2)
signal expired()

@export var projectile_type: ProjectileType = ProjectileType.KNIFE
@export var damage: int = 25
@export var lifetime: float = 4.0
@export var arc_gravity: float = 500.0
@export var initial_horizontal_speed: float = 450.0
@export var initial_vertical_speed: float = -120.0
@export var rotation_speed: float = 0.0 # rad/s (meşale ve şişe için dönme)
@export var stick_on_solid: bool = false # Bıçak duvara saplanabilir
@export var creates_ground_hazard: bool = false # Meşale ve Kutsal Su yer alanı oluşturur
@export var ground_hazard_duration: float = 2.5
@export var ground_hazard_dps: int = 15
@export var supported_unholy_groups: Array[String] = ["unholy", "undead", "vampires"]

var velocity: Vector2 = Vector2.ZERO
var direction_x: float = 1.0
var thrower: Node2D = null
var is_spent: bool = false
var is_stuck: bool = false
var _time_alive: float = 0.0

@onready var visual: Node2D = get_node_or_null("Visual")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var trail_particles: CPUParticles2D = get_node_or_null("TrailParticles") as CPUParticles2D


func _ready() -> void:
	# Mermi grupları
	add_to_group("throwable_projectiles")
	add_to_group("player_projectiles")

	# Çarpışma dinleyicileri
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func launch(start_pos: Vector2, facing_dir: float, custom_vel: Vector2 = Vector2.ZERO, shooter: Node2D = null) -> void:
	global_position = start_pos
	direction_x = 1.0 if facing_dir >= 0.0 else -1.0
	thrower = shooter

	if custom_vel != Vector2.ZERO:
		velocity = custom_vel
	else:
		velocity = Vector2(direction_x * initial_horizontal_speed, initial_vertical_speed)

	# Bıçak başlangıç açısı
	if projectile_type == ProjectileType.KNIFE:
		rotation = velocity.angle()
	elif visual:
		visual.scale.x = direction_x

	# Ses
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("throw_item", -2.0)


func _physics_process(delta: float) -> void:
	if is_stuck or is_spent:
		return

	# Parabolik hareket & yerçekimi
	velocity.y += arc_gravity * delta
	global_position += velocity * delta

	# Rotasyon yönetimi
	if projectile_type == ProjectileType.KNIFE:
		rotation = velocity.angle()
	else:
		rotation += rotation_speed * direction_x * delta

	# Yaşam süresi kontrolü
	_time_alive += delta
	if _time_alive >= lifetime or global_position.y > 4000.0:
		_expire()


func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	_handle_collision(area)


func _handle_collision(collider: Node2D) -> void:
	if is_spent or is_stuck:
		return
	if not is_instance_valid(collider):
		return
	if collider == self or collider == thrower:
		return
	if collider.is_in_group("allies") or collider.is_in_group("throwable_projectiles"):
		return

	# Hedef hasar alabilir mi / yanabilir nesne mi?
	var can_damage_target = _can_target_receive_damage(collider)
	var is_burnable_obj = collider.is_in_group("burnable") or collider.is_in_group("barricades")

	if can_damage_target or (projectile_type == ProjectileType.TORCH and is_burnable_obj):
		_apply_target_hit(collider)
		return

	# Katı dünya yüzeyi (Duvar / Zemin / Platform)
	if collider is StaticBody2D or collider is TileMap or collider.get_class() == "TileMapLayer":
		_apply_solid_hit(collider)


func _can_target_receive_damage(node: Node2D) -> bool:
	if node.is_in_group("damageable") or node.is_in_group("enemies"):
		return true
	if node.has_method("take_damage") or node.has_method("hit") or node.has_method("ignite"):
		return true
	return false


func _apply_target_hit(target: Node2D) -> void:
	is_spent = true
	var hit_pos = global_position
	impacted.emit(target, hit_pos)

	match projectile_type:
		ProjectileType.KNIFE:
			_process_knife_hit(target, hit_pos)
		ProjectileType.TORCH:
			_process_torch_hit(target, hit_pos)
		ProjectileType.HOLY_WATER:
			_process_holy_water_hit(target, hit_pos)


func _process_knife_hit(target: Node2D, hit_pos: Vector2) -> void:
	# Fırlatma Bıçağı: Doğrudan delici fiziksel hasar
	var applied_dmg = damage
	_deliver_damage(target, applied_dmg)

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("knife_hit", -1.0)

	_spawn_spark_particles(hit_pos)
	_cleanup()


func _process_torch_hit(target: Node2D, hit_pos: Vector2) -> void:
	# Meşale: Ateş hasarı ve yanabilir çevre nesnelerini tutuşturma
	var is_burnable = target.is_in_group("burnable") or target.is_in_group("barricades")
	var applied_dmg = int(damage * 1.5) if is_burnable else damage

	if target.has_method("ignite"):
		target.ignite(applied_dmg)
	else:
		_deliver_damage(target, applied_dmg)

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("torch_burn", -1.0)

	_spawn_fire_burst(hit_pos)
	if creates_ground_hazard:
		_spawn_ground_hazard(hit_pos)
	_cleanup()


func _process_holy_water_hit(target: Node2D, hit_pos: Vector2) -> void:
	# Kutsal Su: Yalnızca tasarımda belirlenmiş kutsal olmayan/hortlak düşmanlara etki eder
	var is_unholy = is_supported_holy_target(target)

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("holy_water_shatter", 0.0)

	if is_unholy:
		# Kutsal arınma hasarı
		var applied_dmg = damage
		_deliver_damage(target, applied_dmg)
		_spawn_holy_damage_text(hit_pos, applied_dmg)
		_spawn_holy_particles(hit_pos)
	else:
		# Kutsal olmayan/normal hedefler kutsal suya bağışık
		_spawn_immune_text(hit_pos)
		_spawn_water_splash(hit_pos)

	if creates_ground_hazard:
		_spawn_ground_hazard(hit_pos)
	_cleanup()


func _apply_solid_hit(surface: Node2D) -> void:
	var hit_pos = global_position
	solid_hit.emit(surface, hit_pos)

	if projectile_type == ProjectileType.KNIFE and stick_on_solid:
		is_stuck = true
		velocity = Vector2.ZERO
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("knife_hit", -3.0)
		_spawn_spark_particles(hit_pos)

		# Saplanıp 1.2 saniye sonra kaybolur
		var tw = create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_cleanup)
		return

	is_spent = true
	match projectile_type:
		ProjectileType.TORCH:
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("torch_burn", -2.0)
			_spawn_fire_burst(hit_pos)
			if creates_ground_hazard:
				_spawn_ground_hazard(hit_pos)
		ProjectileType.HOLY_WATER:
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("holy_water_shatter", 0.0)
			_spawn_holy_particles(hit_pos)
			if creates_ground_hazard:
				_spawn_ground_hazard(hit_pos)
		_:
			_spawn_spark_particles(hit_pos)

	_cleanup()


func _deliver_damage(target: Node2D, amount: int) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount)
	elif target.has_method("hit"):
		target.hit(amount)


func is_supported_holy_target(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false

	# 1. Grup kontrolleri
	for grp in supported_unholy_groups:
		if target.is_in_group(grp):
			return true

	# 2. Dinamik özellik kontrolü
	if target.get("is_unholy") == true or target.get("is_undead") == true or target.get("is_vampire") == true:
		return true

	# 3. İsim ve sınıf eşleşmeleri (Vlad, Vampir Şövalyesi, Necromancer, Yarasa)
	var t_name = target.name.to_lower()
	var script_name = ""
	if target.get_script() and target.get_script().resource_path:
		script_name = target.get_script().resource_path.to_lower()

	var unholy_keywords = ["vlad", "blood_knight", "necromancer", "bat", "lurker", "undead", "vampire"]
	for kw in unholy_keywords:
		if kw in t_name or kw in script_name:
			return true

	return false


func _spawn_ground_hazard(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return

	var hazard: Area2D = Area2D.new()
	hazard.collision_layer = 0
	hazard.collision_mask = 2 | 4 # Düşman ve barikat katmanı
	hazard.global_position = pos

	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 42.0
	shape.shape = circle
	hazard.add_child(shape)

	# Görsel gösterge
	var indicator: CPUParticles2D = CPUParticles2D.new()
	indicator.emitting = true
	indicator.amount = 24
	indicator.lifetime = 0.5
	indicator.spread = 180.0
	indicator.gravity = Vector2(0, -90)
	indicator.initial_velocity_min = 15.0
	indicator.initial_velocity_max = 40.0

	if projectile_type == ProjectileType.TORCH:
		hazard.name = "GroundFireHazard"
		indicator.color = Color(1.0, 0.5, 0.1, 0.8)
	else:
		hazard.name = "HolyConsecratedHazard"
		indicator.color = Color(0.4, 0.8, 1.0, 0.85)

	hazard.add_child(indicator)
	parent_scene.add_child(hazard)

	# Periyodik hasar döngüsü (Tick)
	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.5
	tick_timer.autostart = true
	hazard.add_child(tick_timer)

	var p_type = projectile_type
	var dps = ground_hazard_dps

	tick_timer.timeout.connect(func():
		var overlapping_bodies = hazard.get_overlapping_bodies()
		var overlapping_areas = hazard.get_overlapping_areas()
		var all_targets = overlapping_bodies + overlapping_areas

		for tgt in all_targets:
			if not is_instance_valid(tgt) or tgt == thrower or tgt.is_in_group("allies"):
				continue

			if p_type == ProjectileType.TORCH:
				if tgt.is_in_group("burnable") or tgt.is_in_group("barricades"):
					if tgt.has_method("ignite"):
						tgt.ignite(dps)
					elif tgt.has_method("take_damage"):
						tgt.take_damage(dps)
				elif tgt.has_method("take_damage"):
					tgt.take_damage(dps)
			elif p_type == ProjectileType.HOLY_WATER:
				if is_supported_holy_target(tgt):
					if tgt.has_method("take_damage"):
						tgt.take_damage(dps)
	)

	# Yaşam süresi sonunda temizle
	var tw = hazard.create_tween()
	tw.tween_interval(ground_hazard_duration)
	tw.tween_property(indicator, "modulate:a", 0.0, 0.4)
	tw.tween_callback(hazard.queue_free)


func _spawn_spark_particles(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.25
	p.spread = 180.0
	p.gravity = Vector2(0, 180)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.color = Color(1.0, 0.9, 0.4, 1.0)
	p.global_position = pos
	parent_scene.add_child(p)
	p.finished.connect(p.queue_free)


func _spawn_fire_burst(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector2(0, -140)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.color = Color(1.0, 0.5, 0.1, 1.0)
	p.global_position = pos
	parent_scene.add_child(p)
	p.finished.connect(p.queue_free)


func _spawn_holy_particles(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 26
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2(0, -90)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.color = Color(0.4, 0.85, 1.0, 1.0)
	p.global_position = pos
	parent_scene.add_child(p)
	p.finished.connect(p.queue_free)


func _spawn_water_splash(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.3
	p.spread = 180.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.color = Color(0.7, 0.9, 1.0, 0.8)
	p.global_position = pos
	parent_scene.add_child(p)
	p.finished.connect(p.queue_free)


func _spawn_holy_damage_text(pos: Vector2, amt: int) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var lbl = Label.new()
	lbl.text = "✨ KUTSAL ARINMA! -%d" % amt
	lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.global_position = pos + Vector2(-45.0, -25.0)
	parent_scene.add_child(lbl)
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 30.0, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)


func _spawn_immune_text(pos: Vector2) -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return
	var lbl = Label.new()
	lbl.text = "🛡️ BAĞIŞIK (Kutsal Değil)"
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.global_position = pos + Vector2(-55.0, -20.0)
	parent_scene.add_child(lbl)
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 25.0, 0.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _expire() -> void:
	if is_spent:
		return
	is_spent = true
	expired.emit()
	_cleanup()


func _cleanup() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	visible = false
	get_tree().create_timer(0.15).timeout.connect(queue_free)
