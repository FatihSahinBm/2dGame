class_name CyberFlyingBug
extends CharacterBody2D

## res://scripts/enemies/cyber_flying_bug.gd - Taş Devri Siber Uçan Böcek (Menzilli Uçan Minyon)

signal health_changed(current_hp: int, max_hp: int)
signal enemy_died(enemy_instance: Node2D)
signal attacked(target: Node2D)

enum State { PATROL, HOVER_ENGAGE, TELEGRAPH, SHOOT, REPOSITION, HURT, DEAD }

const PROJECTILE_SCENE = preload("res://scenes/projectiles/cyber_energy_projectile.tscn")

@export_group("Monster Profile")
@export var monster_name: String = "Siber Uçan Böcek"
@export var max_health: int = 65
@export var current_health: int = 65

@export_group("Movement & Hover")
@export var hover_speed: float = 80.0
@export var kite_speed: float = 120.0
@export var hover_amplitude: float = 16.0
@export var hover_frequency: float = 3.2
@export var preferred_elevation: float = 75.0

@export_group("Combat & Ranged AI")
@export var detection_range: float = 380.0
@export var min_attack_range: float = 140.0
@export var max_attack_range: float = 270.0
@export var telegraph_duration: float = 0.45
@export var attack_cooldown: float = 2.2
@export var projectile_damage: int = 14

var current_state: State = State.PATROL
var is_dead: bool = false
var direction: int = -1
var _time_alive: float = 0.0
var _attack_timer: float = 0.0
var _reposition_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _hurt_timer: float = 0.0
var _target_node: Node2D = null
var _aim_direction: Vector2 = Vector2.ZERO

@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var laser_aim_line: Line2D = $Visual/LaserAimLine
@onready var optic_light: PointLight2D = $Visual/OpticLight
@onready var hurtbox_area: Area2D = $Hurtbox
@onready var detection_area: Area2D = $DetectionArea
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var damage_numbers: Node2D = $UI/DamageNumbers

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_health = max_health
	if laser_aim_line: laser_aim_line.visible = false
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if hurtbox_area: hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if is_dead:
		_process_dead(delta)
		return
	if _attack_timer > 0.0: _attack_timer -= delta

	match current_state:
		State.PATROL: _process_patrol(delta)
		State.HOVER_ENGAGE: _process_hover_engage(delta)
		State.TELEGRAPH: _process_telegraph(delta)
		State.SHOOT: _process_shoot(delta)
		State.REPOSITION: _process_reposition(delta)
		State.HURT: _process_hurt(delta)
	move_and_slide()

func _process_patrol(_delta: float) -> void:
	if _can_see_target():
		current_state = State.HOVER_ENGAGE
		return
	var hover_offset_y = sin(_time_alive * hover_frequency) * hover_amplitude
	velocity.x = float(direction) * (hover_speed * 0.6)
	velocity.y = hover_offset_y * 1.5
	if is_on_wall():
		direction = -direction
		_update_facing()
	if anim_sprite and anim_sprite.animation != "hit": anim_sprite.play("idle")

func _process_hover_engage(delta: float) -> void:
	if not _is_target_valid():
		current_state = State.PATROL
		return
	var to_player: Vector2 = _target_node.global_position - global_position
	var dist: float = to_player.length()
	if dist > detection_range * 1.3:
		_target_node = null
		current_state = State.PATROL
		return
	direction = 1 if to_player.x > 0 else -1
	_update_facing()
	var desired_y = _target_node.global_position.y - preferred_elevation
	var target_vel = Vector2.ZERO
	if dist < min_attack_range:
		target_vel.x = -direction * kite_speed
	elif dist > max_attack_range:
		target_vel.x = direction * hover_speed
	else:
		target_vel.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	var y_diff = desired_y - global_position.y
	target_vel.y = clampf(y_diff * 2.5, -hover_speed, hover_speed) + (sin(_time_alive * hover_frequency) * 20.0)
	target_vel += _calculate_flocking_separation()
	velocity = velocity.move_toward(target_vel, 400.0 * delta)
	if anim_sprite and anim_sprite.animation != "hit": anim_sprite.play("walk")
	if dist >= min_attack_range * 0.8 and dist <= max_attack_range * 1.15 and _attack_timer <= 0.0:
		_start_telegraph()

func _start_telegraph() -> void:
	current_state = State.TELEGRAPH
	_telegraph_timer = telegraph_duration
	velocity = Vector2.ZERO
	if _target_node:
		_aim_direction = (_target_node.global_position - global_position).normalized()
	if laser_aim_line and _target_node:
		laser_aim_line.visible = true
		laser_aim_line.clear_points()
		laser_aim_line.add_point(Vector2.ZERO)
		laser_aim_line.add_point(to_local(_target_node.global_position))
		laser_aim_line.default_color = Color(1.0, 0.2, 0.2, 0.8)
	if optic_light:
		optic_light.color = Color(1.0, 0.15, 0.15, 1.0)
		optic_light.energy = 2.2
	if anim_sprite: anim_sprite.play("attack")

func _process_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	velocity = Vector2.ZERO
	if _is_target_valid() and laser_aim_line:
		_aim_direction = (_target_node.global_position - global_position).normalized()
		laser_aim_line.set_point_position(1, to_local(_target_node.global_position))
	if _telegraph_timer <= 0.0:
		if laser_aim_line: laser_aim_line.visible = false
		current_state = State.SHOOT

func _process_shoot(_delta: float) -> void:
	_fire_cyber_projectile()
	_attack_timer = attack_cooldown
	_reposition_timer = 1.1
	current_state = State.REPOSITION

func _fire_cyber_projectile() -> void:
	var proj = PROJECTILE_SCENE.instantiate() as Area2D
	if not proj: return
	var spawn_pos = global_position + _aim_direction * 22.0
	get_parent().add_child(proj)
	proj.setup(spawn_pos, _aim_direction, self, projectile_damage)
	if optic_light:
		optic_light.color = Color(0.2, 0.9, 1.0, 1.0)
		optic_light.energy = 1.2
	if _target_node: attacked.emit(_target_node)

func _process_reposition(delta: float) -> void:
	_reposition_timer -= delta
	velocity.x = -direction * (hover_speed * 0.75)
	velocity.y = -hover_speed * 0.5 + (sin(_time_alive * 4.0) * 15.0)
	if anim_sprite and anim_sprite.animation != "hit": anim_sprite.play("idle")
	if _reposition_timer <= 0.0: current_state = State.HOVER_ENGAGE

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
	if laser_aim_line: laser_aim_line.visible = false
	if _hurt_timer <= 0.0:
		current_state = State.HOVER_ENGAGE if _is_target_valid() else State.PATROL

func _process_dead(delta: float) -> void:
	velocity.y += 850.0 * delta
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	move_and_slide()
	if is_on_floor(): velocity = Vector2.ZERO

func take_damage(amount: int) -> void:
	if is_dead: return
	var actual_dmg: int = maxi(1, amount)
	current_health = clampi(current_health - actual_dmg, 0, max_health)
	_update_health_bar()
	_spawn_damage_number(actual_dmg)
	_play_hit_feedback()
	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		_hurt_timer = 0.28
		if anim_sprite: anim_sprite.play("hit")

func _die() -> void:
	is_dead = true
	current_state = State.DEAD
	if laser_aim_line: laser_aim_line.visible = false
	if optic_light: optic_light.enabled = false
	if anim_sprite: anim_sprite.play("death")
	collision_layer = 0
	collision_mask = 1
	enemy_died.emit(self)
	var tw = create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _calculate_flocking_separation() -> Vector2:
	var separation = Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemies"):
		if n != self and is_instance_valid(n) and n is Node2D:
			var diff = global_position - (n as Node2D).global_position
			var d = diff.length()
			if d > 0.0 and d < 65.0:
				separation += (diff / d) * (65.0 - d) * 2.2
	return separation

func _can_see_target() -> bool:
	if _target_node and is_instance_valid(_target_node):
		return global_position.distance_to(_target_node.global_position) <= detection_range
	return false

func _is_target_valid() -> bool:
	return _target_node != null and is_instance_valid(_target_node)

func _update_facing() -> void:
	if visual_node: visual_node.scale.x = abs(visual_node.scale.x) * direction

func _play_hit_feedback() -> void:
	if visual_node:
		var tw = create_tween()
		tw.tween_property(visual_node, "modulate", Color(2.5, 0.4, 0.4, 1.0), 0.06)
		tw.tween_property(visual_node, "modulate", Color(0.85, 1.1, 1.25, 1.0), 0.12)

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = (current_health < max_health and not is_dead)
	health_changed.emit(current_health, max_health)

func _spawn_damage_number(amount: int) -> void:
	if not damage_numbers: return
	var label = Label.new()
	label.text = str(amount)
	label.modulate = Color(1.0, 0.35, 0.35, 1.0)
	label.position = Vector2(-10, -35)
	damage_numbers.add_child(label)
	var tw = create_tween()
	tw.tween_property(label, "position:y", label.position.y - 25.0, 0.45)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tw.tween_callback(label.queue_free)

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "CombatPlayer" or body.name == "TestPlayer":
		_target_node = body

func _on_detection_body_exited(_body: Node2D) -> void:
	pass

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not is_dead and area.name == "AttackArea":
		take_damage(25)
