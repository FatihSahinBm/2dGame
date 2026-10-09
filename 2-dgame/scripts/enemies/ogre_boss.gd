extends "res://scripts/enemies/monster_enemy.gd"

## Ogre Boss - Devasa Boss Sınıfı
## Gelişmiş yer sarsıntısı, ağır balyoz/kulüp saldırısı ve devasa can barı

@export_group("Boss Features")
@export var screen_shake_intensity: float = 6.0
@export var ground_smash_delay: float = 1.75 # Frame 42 at 24 FPS (kulübün yere vurma anı)
@export var recovery_time: float = 1.05
@export var hitbox_offset_x: float = 80.0

var _camera_ref: Camera2D = null

func _ready() -> void:
	super._ready()
	# Kamerayı bul (ekran sarsıntısı için)
	_find_camera()

func _update_facing_direction() -> void:
	super._update_facing_direction()
	if hitbox_area:
		hitbox_area.position.x = hitbox_offset_x * float(direction)
	if ledge_ray:
		ledge_ray.position.x = 35.0 * float(direction)
		ledge_ray.force_raycast_update()

func _find_camera() -> void:
	var viewport = get_viewport()
	if viewport:
		_camera_ref = viewport.get_camera_2d()

func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = 0.0

	if anim_sprite:
		anim_sprite.play(&"attack")

	# Kulübü havaya kaldırıp yere indirme zamanlaması
	var tween: Tween = create_tween()
	# Frame 1 - 41: Havaya kaldırma ve savurma aşaması (1.75s)
	tween.tween_interval(ground_smash_delay)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_activate_hitbox()
			_trigger_ground_smash_impact()
	)
	# Frame 42 - 50: Yerdeki şok dalgası ve darbe anı (0.35s)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_deactivate_hitbox()
	)
	tween.tween_interval(recovery_time)
	tween.tween_callback(func():
		if current_state == State.ATTACK and not is_dead:
			_attack_timer = attack_cooldown
			current_state = State.CHASE if _target_node else State.PATROL
	)

func _trigger_ground_smash_impact() -> void:
	# 1. Ekran sarsıntısı
	if not _camera_ref:
		_find_camera()

	if _camera_ref:
		var cam_tween: Tween = create_tween()
		var orig_offset = _camera_ref.offset
		cam_tween.tween_property(_camera_ref, "offset", orig_offset + Vector2(0, screen_shake_intensity), 0.05)
		cam_tween.tween_property(_camera_ref, "offset", orig_offset + Vector2(0, -screen_shake_intensity * 0.7), 0.06)
		cam_tween.tween_property(_camera_ref, "offset", orig_offset + Vector2(0, screen_shake_intensity * 0.4), 0.05)
		cam_tween.tween_property(_camera_ref, "offset", orig_offset, 0.08)

	# 2. Yakındaki oyuncuya ek geri itme
	if _target_node and is_instance_valid(_target_node):
		var dist = global_position.distance_to(_target_node.global_position)
		if dist < attack_range * 1.5 and "velocity" in _target_node:
			var push_dir = signf(_target_node.global_position.x - global_position.x)
			if is_zero_approx(push_dir):
				push_dir = float(direction)
			_target_node.velocity.y = -180.0
			_target_node.velocity.x += push_dir * 160.0

## Ölüm anında ağır yıkılış
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	_deactivate_hitbox()

	enemy_died.emit(self)

	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)

	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false

	if health_bar:
		var bar_tween: Tween = create_tween()
		bar_tween.tween_property(health_bar, "modulate:a", 0.0, 0.4)

	# Ağır ölüm animasyonu (118 frame, 4.92s yere yığılış)
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(&"death"):
		anim_sprite.play(&"death")
		# 5.4 saniye: animasyon biter, ceset yerde durur, sonra kaybolur
		get_tree().create_timer(5.4).timeout.connect(_fade_and_free)
	else:
		_fade_and_free()
