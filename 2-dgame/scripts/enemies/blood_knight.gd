class_name BloodKnight
extends CharacterBody2D

## res://scripts/enemies/blood_knight.gd
## 1. Sahne Sonu Mini-Boss: Eflak Kan Şövalyesi (Vlad'ın Elit Muhafızı).
## Ağır zırhlı, kırmızı auralı, kılıç savuran ve kan şoku fırlatan elit muhafız.

signal health_changed(curr: int, max_val: int)
signal enemy_died(inst: Node2D)
signal died()

@export var max_health: int = 220
@export var current_health: int = 220
@export var attack_damage: int = 18
@export var move_speed: float = 90.0
@export var attack_range: float = 65.0

var is_dead: bool = false
var _is_attacking: bool = false
var _attack_cooldown_timer: float = 0.0
var _target_player: CharacterBody2D = null
var _facing_dir: float = -1.0

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var attack_area: Area2D = $Visual/AttackArea
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var title_label: Label = $UI/TitleLabel


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	current_health = max_health

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if visual:
		visual.modulate = Color(1.8, 0.3, 0.35, 1.0) # Kızıl Kan Şövalyesi aurası


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += 980.0 * delta

	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)

	if not _target_player:
		_target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if _target_player and is_instance_valid(_target_player):
		var dist = global_position.distance_to(_target_player.global_position)
		var dir_x = signf(_target_player.global_position.x - global_position.x)
		if dir_x != 0.0 and not _is_attacking:
			_facing_dir = dir_x
			visual.scale.x = absf(visual.scale.x) * _facing_dir

		if dist <= attack_range and _attack_cooldown_timer <= 0.0 and not _is_attacking:
			_perform_blood_attack()
		elif not _is_attacking:
			velocity.x = _facing_dir * move_speed
			if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.play("walk")
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		velocity.x = 0.0

	move_and_slide()


func _perform_blood_attack() -> void:
	_is_attacking = true
	_attack_cooldown_timer = 2.2
	velocity.x = 0.0

	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	elif anim_sprite and anim_sprite.sprite_frames.has_animation("melee"):
		anim_sprite.play("melee")

	# Darbe anında hasar kontrolü
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_dead or not is_inside_tree():
			return
		if attack_area:
			for body in attack_area.get_overlapping_bodies():
				if body.is_in_group("player") and body.has_method("take_damage"):
					body.take_damage(attack_damage, global_position)
	)

	get_tree().create_timer(0.7).timeout.connect(func():
		_is_attacking = false
	)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if is_dead:
		return

	current_health -= amount
	health_changed.emit(current_health, max_health)

	if health_bar:
		health_bar.value = current_health

	# Darbe efekti (kızıl flaş)
	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color(2.5, 0.8, 0.8, 1.0), 0.06)
		tw.tween_property(visual, "modulate", Color(1.8, 0.3, 0.35, 1.0), 0.12)

	_spawn_damage_text(amount)

	if current_health <= 0:
		_die()


func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(randf_range(-15, 15), -55.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.6)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
		tw.tween_callback(label.queue_free)


func _die() -> void:
	is_dead = true
	died.emit()
	enemy_died.emit(self)

	if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
	elif anim_sprite and anim_sprite.sprite_frames.has_animation("hurt"):
		anim_sprite.play("hurt")

	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate:a", 0.0, 1.2)

	get_tree().create_timer(1.4).timeout.connect(queue_free)
