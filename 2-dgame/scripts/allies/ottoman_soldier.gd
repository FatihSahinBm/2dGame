class_name OttomanSoldier
extends CharacterBody2D

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

## res://scripts/allies/ottoman_soldier.gd
## Ön safta Vlad'ın yaratıklarıyla çarpışan Yakın Dövüş Yeniçerisi.
## Dost ateşi açıktır ve oyuncu tarafından bencilce canı sömürülebilir.

signal died()
signal drained_by_player()

@export var max_health: int = 90
@export var current_health: int = 90
@export var speed: float = 85.0
@export var attack_damage: int = 18
@export var attack_range: float = 48.0
@export var attack_cooldown: float = 1.2

var gravity: float = 980.0
var _target_enemy: Node2D = null
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _player_nearby: bool = false
var _player_ref: CharacterBody2D = null

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var attack_area: Area2D = $Visual/AttackArea
@onready var interact_label: Label = $UI/InteractLabel
@onready var health_bar: ProgressBar = $UI/HealthBar


func _ready() -> void:
	add_to_group("allies")
	add_to_group("damageable")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false
	if interact_label:
		interact_label.visible = false


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_find_nearest_enemy()

	if _target_enemy and is_instance_valid(_target_enemy):
		var dist: float = global_position.distance_to(_target_enemy.global_position)
		var dir_x: float = signf(_target_enemy.global_position.x - global_position.x)
		if dir_x != 0.0:
			visual.scale.x = absf(visual.scale.x) * dir_x

		if dist <= attack_range:
			velocity.x = 0.0
			if _attack_timer <= 0.0:
				_perform_melee_attack()
		else:
			velocity.x = dir_x * speed
			if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 2.0 * delta)
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead or not _player_nearby or not _player_ref:
		return
	# [E] tuşu ile yaralı veya müttefik askeri kurban etme (Aktif Sömürü)
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_drain_soldier()


func _find_nearest_enemy() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest_dist: float = 650.0
	_target_enemy = null

	for node in enemies:
		if node is Node2D and node != self and not ("is_dead" in node and node.is_dead):
			var d: float = global_position.distance_to(node.global_position)
			if d < closest_dist:
				closest_dist = d
				_target_enemy = node


func _perform_melee_attack() -> void:
	_attack_timer = attack_cooldown
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

	# Kısa atılma
	velocity.x = signf(visual.scale.x) * 40.0

	get_tree().create_timer(0.2).timeout.connect(func():
		if _is_dead or not attack_area:
			return
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(attack_damage)
	)


## Hasar alma (Düşmanlardan VEYA Oyuncudan - Dost Ateşi)
func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dead:
		return

	current_health -= amount
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

	# Görsel hasar flaşı
	if visual and is_instance_valid(visual):
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color.RED, 0.08)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.12)

	# Eğer hasar oyuncudan geldiyse dost ateşi / ihanet uyarısı ver
	if attacker and attacker.is_in_group("player"):
		_on_hit_by_player()

	if current_health <= 0:
		_die(attacker)


func _on_hit_by_player() -> void:
	# Kılıç isyanı
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("add_corruption"):
		game_state.add_corruption(5)

	shout_reaction(true)


## Aktif sömürü: Oyuncu askerin canını kendine çeker
func _drain_soldier() -> void:
	if _is_dead:
		return
	_is_dead = true

	var game_state: Node = get_node_or_null("/root/GameState")
	var heal_amount: int = 40
	if game_state and game_state.has_method("register_ally_sacrifice"):
		heal_amount = game_state.register_ally_sacrifice("janissary")

	if _player_ref and _player_ref.has_method("heal"):
		_player_ref.heal(heal_amount)
	elif _player_ref and "current_health" in _player_ref and "max_health" in _player_ref:
		_player_ref.current_health = mini(_player_ref.max_health, _player_ref.current_health + heal_amount)

	# Çevredeki askerlerin korku tepkisi
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
			game_state.register_ally_kill("janissary")
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
			if global_position.distance_to(ally.global_position) < 320.0:
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
			interact_label.visible = true
			interact_label.text = "[E] Kanını Sömür"


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_player_ref = null
		if interact_label:
			interact_label.visible = false
