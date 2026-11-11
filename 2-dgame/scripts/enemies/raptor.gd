class_name RaptorEnemy
extends CharacterBody2D

## res://scripts/enemies/raptor.gd - Taş Devri Vadi Raptoru (Çevik Yakın Dövüş Minyonu)

signal health_changed(current_hp: int, max_hp: int)
signal enemy_died(enemy_instance: Node2D)
signal attack_hit(target: Node2D)

enum State { PATROL, DETECT, APPROACH, TELEGRAPH, ATTACK, RETREAT, HURT, DEAD }

@export_group("Monster Profile")
@export var monster_name: String = "Vadi Raptoru"
@export var max_health: int = 110
@export var current_health: int = 110

@export_group("Movement")
@export var speed: float = 85.0
@export var chase_speed: float = 175.0
@export var retreat_speed: float = 145.0
@export var gravity: float = 1200.0
@export var direction: int = -1
@export var turn_at_ledges: bool = true
@export var turn_at_walls: bool = true

@export_group("Combat & AI")
@export var attack_damage: int = 18
@export var attack_range: float = 85.0
@export var detection_range: float = 340.0
@export var telegraph_duration: float = 0.35
@export var retreat_duration: float = 0.90
@export var attack_cooldown: float = 1.30
@export var knockback_resistance: float = 0.40

var current_state: State = State.PATROL
var is_dead: bool = false
var _attack_timer: float = 0.0
var _retreat_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _hurt_timer: float = 0.0
var _target_node: Node2D = null

@onready var visual_node: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hitbox_area: Area2D = $Visual/Hitbox
@onready var hurtbox_area: Area2D = $Hurtbox
@onready var detection_area: Area2D = $DetectionArea
@onready var ledge_ray: RayCast2D = $Visual/LedgeRay
@onready var telegraph_light: PointLight2D = get_node_or_null("Visual/TelegraphLight")
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var damage_numbers: Node2D = $UI/DamageNumbers

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	current_health = max_health
	if telegraph_light: telegraph_light.enabled = false
	if hitbox_area:
		hitbox_area.monitoring = false
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)
	if hurtbox_area: hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	_update_facing()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		_process_dead(delta)
		return
	if not is_on_floor(): velocity.y += gravity * delta
	if _attack_timer > 0.0: _attack_timer -= delta

	match current_state:
		State.PATROL: _process_patrol(delta)
		State.DETECT: _process_detect(delta)
		State.APPROACH: _process_approach(delta)
		State.TELEGRAPH: _process_telegraph(delta)
		State.ATTACK: _process_attack(delta)
		State.RETREAT: _process_retreat(delta)
		State.HURT: _process_hurt(delta)
	move_and_slide()

func _process_patrol(_delta: float) -> void:
	if _can_see_target():
		current_state = State.APPROACH
		return
	if (turn_at_walls and is_on_wall()) or (turn_at_ledges and is_on_floor() and ledge_ray and not ledge_ray.is_colliding()):
		direction = -direction
		_update_facing()
		return
	velocity.x = float(direction) * speed
	if anim_sprite and anim_sprite.animation != "hurt": anim_sprite.play("walk")

func _process_detect(_delta: float) -> void:
	current_state = State.APPROACH

func _process_approach(delta: float) -> void:
	if not _is_target_valid():
		current_state = State.PATROL
		return
	var to_target: Vector2 = _target_node.global_position - global_position
	var dist: float = to_target.length()
	if dist > detection_range * 1.35:
		_target_node = null
		current_state = State.PATROL
		return
	var target_dir: int = 1 if to_target.x > 0 else -1
	if target_dir != direction:
		direction = target_dir
		_update_facing()
	var desired_vx: float = (float(direction) * chase_speed) + _calculate_flocking_separation_x()
	if turn_at_ledges and is_on_floor() and ledge_ray and not ledge_ray.is_colliding():
		velocity.x = 0.0
		if anim_sprite: anim_sprite.play("idle")
		return
	velocity.x = move_toward(velocity.x, desired_vx, 650.0 * delta)
	if anim_sprite and anim_sprite.animation != "hurt": anim_sprite.play("run")
	if dist <= attack_range and _attack_timer <= 0.0: _start_telegraph()

func _start_telegraph() -> void:
	current_state = State.TELEGRAPH
	_telegraph_timer = telegraph_duration
	velocity.x = 0.0
	if telegraph_light:
		telegraph_light.enabled = true
		telegraph_light.color = Color(1.0, 0.2, 0.1, 1.0)
		telegraph_light.energy = 2.0
	if visual_node:
		var tw = create_tween()
		tw.tween_property(visual_node, "modulate", Color(1.8, 0.3, 0.3, 1.0), 0.15)
		tw.tween_property(visual_node, "modulate", Color.WHITE, 0.18)
	if anim_sprite: anim_sprite.play("idle")

func _process_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if _telegraph_timer <= 0.0:
		if telegraph_light: telegraph_light.enabled = false
		_start_attack()

func _start_attack() -> void:
	current_state = State.ATTACK
	velocity.x = float(direction) * 250.0
	velocity.y = -90.0
	if anim_sprite: anim_sprite.play("attack_bite")
	if hitbox_area: hitbox_area.monitoring = true
	var tw = create_tween()
	tw.tween_interval(0.32)
	tw.tween_callback(func():
		if current_state == State.ATTACK:
			if hitbox_area: hitbox_area.monitoring = false
			_start_retreat()
	)

func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

func _start_retreat() -> void:
	current_state = State.RETREAT
	_retreat_timer = retreat_duration
	_attack_timer = attack_cooldown
	velocity.x = -float(direction) * retreat_speed
	velocity.y = -120.0
	if anim_sprite: anim_sprite.play("walk")

func _process_retreat(delta: float) -> void:
	_retreat_timer -= delta
	velocity.x = move_toward(velocity.x, -float(direction) * (retreat_speed * 0.4), 350.0 * delta)
	if _retreat_timer <= 0.0:
		current_state = State.APPROACH if _is_target_valid() else State.PATROL

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
	if _hurt_timer <= 0.0:
		current_state = State.APPROACH if _is_target_valid() else State.PATROL

func _process_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()

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
		_hurt_timer = 0.26
		velocity.x = -float(direction) * 160.0 * (1.0 - knockback_resistance)
		if anim_sprite: anim_sprite.play("hurt")

func _die() -> void:
	is_dead = true
	current_state = State.DEAD
	if hitbox_area: hitbox_area.monitoring = false
	if telegraph_light: telegraph_light.enabled = false
	if anim_sprite: anim_sprite.play("death")
	collision_layer = 0
	collision_mask = 1
	enemy_died.emit(self)
	var tw = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _calculate_flocking_separation_x() -> float:
	var sep_x: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e) and e is Node2D:
			var diff_x: float = global_position.x - (e as Node2D).global_position.x
			var dist: float = absf(diff_x)
			if dist < 48.0 and dist > 0.0:
				sep_x += signf(diff_x) * (48.0 - dist) * 2.0
	return clampf(sep_x, -chase_speed * 0.5, chase_speed * 0.5)

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
		tw.tween_property(visual_node, "modulate", Color.WHITE, 0.12)

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
	label.modulate = Color(1.0, 0.4, 0.3, 1.0)
	label.position = Vector2(-10, -90)
	damage_numbers.add_child(label)
	var tw = create_tween()
	tw.tween_property(label, "position:y", label.position.y - 25.0, 0.45)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tw.tween_callback(label.queue_free)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "CombatPlayer" or body.name == "TestPlayer":
		if body.has_method("take_damage"): body.take_damage(attack_damage)
		attack_hit.emit(body)

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "CombatPlayer" or body.name == "TestPlayer":
		_target_node = body

func _on_detection_body_exited(_body: Node2D) -> void:
	pass

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not is_dead and area.name == "AttackArea": take_damage(25)
