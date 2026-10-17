class_name OttomanArcher
extends CharacterBody2D

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://scripts/allies/ottoman_archer.gd
## Arka safta durup alevli oklar atan Osmanlı Kemankeşi.
## Düşük cana sahiptir; bencil oyuncular için en kolay sömürü (can çalma) hedefidir.

signal died()
signal drained_by_player()

@export var max_health: int = 45
@export var current_health: int = 45
@export var shoot_range: float = 450.0
@export var shoot_cooldown: float = 2.0
@export var arrow_scene: PackedScene = preload("res://scenes/projectiles/flaming_arrow.tscn")

var gravity: float = 980.0
var _target_enemy: Node2D = null
var _shoot_timer: float = 0.0
var _is_dead: bool = false
var _player_nearby: bool = false
var _player_ref: CharacterBody2D = null

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var shoot_point: Marker2D = $Visual/ShootPoint
@onready var interact_label: Label = $UI/InteractLabel
@onready var health_bar: ProgressBar = $UI/HealthBar


func _ready() -> void:
	add_to_group("allies")
	add_to_group("damageable")
	_setup_player_collision_exception()
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false
	if interact_label:
		interact_label.visible = false


func _setup_player_collision_exception() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject2D:
			add_collision_exception_with(p)
			p.add_collision_exception_with(self)


func on_cinematic_started() -> void:
	velocity.x = 0.0
	_target_enemy = null
	if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")


func on_cinematic_ended() -> void:
	pass


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	# Sinematik sırasında saldırı ve hareket kilitlenir
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		velocity.x = 0.0
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
		move_and_slide()
		return

	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_find_target()

	if _target_enemy and is_instance_valid(_target_enemy):
		var dir_x: float = signf(_target_enemy.global_position.x - global_position.x)
		if dir_x != 0.0:
			visual.scale.x = absf(visual.scale.x) * dir_x

		if _shoot_timer <= 0.0:
			_shoot_flaming_arrow()
	else:
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")

	move_and_slide()


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _find_target() -> void:
	# 1. Normal / Ana Bosslar önceliği (group "boss", örn. Vlad Boss)
	var bosses: Array[Node] = get_tree().get_nodes_in_group("boss")
	var closest_boss: Node2D = null
	var closest_boss_dist: float = shoot_range * 1.2
	for b in bosses:
		if b is Node2D and is_instance_valid(b) and not b.is_queued_for_deletion() and not ("is_dead" in b and b.is_dead):
			var d = global_position.distance_to(b.global_position)
			if d < closest_boss_dist:
				closest_boss_dist = d
				closest_boss = b as Node2D
	if closest_boss:
		_target_enemy = closest_boss
		return

	# 2. Standart düşmanlar (mini-boss HARİÇ)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest_dist: float = shoot_range
	var standard_target: Node2D = null
	var mini_boss_target: Node2D = null
	var mini_boss_dist: float = shoot_range

	for node in enemies:
		if node is Node2D and node != self and is_instance_valid(node) and not node.is_queued_for_deletion() and not ("is_dead" in node and node.is_dead):
			var d: float = global_position.distance_to(node.global_position)
			if node.is_in_group("mini_boss"):
				if d < mini_boss_dist:
					mini_boss_dist = d
					mini_boss_target = node
			else:
				if d < closest_dist:
					closest_dist = d
					standard_target = node

	if standard_target:
		_target_enemy = standard_target
		return

	# 3. Yalnızca başka düşman kalmadığında mini-boss'u hedef al
	_target_enemy = mini_boss_target


func _shoot_flaming_arrow() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		return

	if not _target_enemy or not is_instance_valid(_target_enemy) or not arrow_scene:
		return

	_shoot_timer = shoot_cooldown
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

	var spawn_pos: Vector2 = shoot_point.global_position if shoot_point else global_position + Vector2(signf(visual.scale.x) * 16, -20)
	var dir: Vector2 = (_target_enemy.global_position + Vector2(0, -15) - spawn_pos).normalized()

	var arrow = arrow_scene.instantiate()
	if arrow and arrow.has_method("setup"):
		arrow.setup(spawn_pos, dir)
		get_parent().add_child(arrow)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dead:
		return

	current_health -= amount
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

	if visual and is_instance_valid(visual):
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
		tw.tween_property(visual, "modulate", Color(0.9, 0.7, 0.4, 1.0), 0.12)

	if attacker and attacker.is_in_group("player"):
		_on_hit_by_player()

	if current_health <= 0:
		_die(attacker)


func _on_hit_by_player() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("add_corruption"):
		game_state.add_corruption(6)
	shout_reaction(true)


func _drain_archer() -> void:
	if _is_dead:
		return
	_is_dead = true

	var game_state: Node = get_node_or_null("/root/GameState")
	var heal_amount: int = 40
	if game_state and game_state.has_method("register_ally_sacrifice"):
		heal_amount = game_state.register_ally_sacrifice("archer")

	if _player_ref and _player_ref.has_method("heal"):
		_player_ref.heal(heal_amount)
	elif _player_ref and "current_health" in _player_ref and "max_health" in _player_ref:
		_player_ref.current_health = mini(_player_ref.max_health, _player_ref.current_health + heal_amount)

	_alert_nearby_allies()
	_spawn_drain_vfx()
	shout_reaction(true)
	drained_by_player.emit()
	died.emit()
	queue_free()


func _die(killer: Node2D = null) -> void:
	_is_dead = true
	if killer and killer.is_in_group("player"):
		var game_state: Node = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("register_ally_kill"):
			game_state.register_ally_kill("archer")
		_alert_nearby_allies()

	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
	died.emit()
	set_physics_process(false)
	get_tree().create_timer(1.2).timeout.connect(queue_free)


func shout_reaction(is_betrayal: bool) -> void:
	var text: String = StoryDataLoader.get_random_shout(is_betrayal)
	_spawn_chat_bubble(text, Color(1.0, 0.3, 0.3, 1.0) if is_betrayal else Color(1.0, 0.9, 0.5, 1.0))


func _alert_nearby_allies() -> void:
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if ally != self and ally is Node2D:
			if global_position.distance_to(ally.global_position) < 360.0:
				if ally.has_method("shout_reaction"):
					ally.shout_reaction(true)


func _spawn_chat_bubble(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 11)
	label.global_position = global_position + Vector2(-60.0, -50.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 1.4)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 1.4)
		tw.tween_callback(label.queue_free)


func _spawn_drain_vfx() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.6
	particles.color = Color(0.85, 0.05, 0.15, 0.9)
	particles.spread = 180.0
	particles.gravity = Vector2(0, -100)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 120.0
	particles.global_position = global_position
	parent_scene.add_child(particles)
	particles.finished.connect(particles.queue_free)


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_player_ref = body as CharacterBody2D
		if interact_label:
			interact_label.visible = false


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_player_ref = null
		if interact_label:
			interact_label.visible = false
