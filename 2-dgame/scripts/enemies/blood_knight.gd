class_name BloodKnight
extends CharacterBody2D

## res://scripts/enemies/blood_knight.gd
## 1. Sahne Sonu Mini-Boss: Eflak Kan Şövalyesi (Vlad'ın Elit Muhafızı).
## Ağır zırhlı, kırmızı auralı, kılıç savuran ve kan şoku fırlatan elit muhafız.

signal health_changed(curr: int, max_val: int)
signal enemy_died(inst: Node2D)
signal died()

@export var max_health: int = 520
@export var current_health: int = 520
@export var attack_damage: int = 24
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
	add_to_group("mini_boss")
	add_to_group("damageable")
	current_health = max_health

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if visual:
		visual.modulate = Color.WHITE


func on_cinematic_started() -> void:
	_is_attacking = false
	velocity.x = 0.0
	if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")


func on_cinematic_ended() -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		velocity.x = 0.0
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
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
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.is_in_cinematic:
		return

	_is_attacking = true
	_attack_cooldown_timer = 2.2
	velocity.x = 0.0

	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
	elif anim_sprite and anim_sprite.sprite_frames.has_animation("melee"):
		anim_sprite.play("melee")

	# Darbe anında hasar ve kan yarığı efekti
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_dead or not is_inside_tree():
			return
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.is_in_cinematic:
			return
		_spawn_blood_slash_vfx()
		if attack_area:
			for body in attack_area.get_overlapping_bodies():
				if body.is_in_group("player") and body.has_method("take_damage"):
					body.take_damage(attack_damage, global_position)
	)

	get_tree().create_timer(0.75).timeout.connect(func():
		_is_attacking = false
		if not is_dead and anim_sprite:
			anim_sprite.play("idle")
	)


func _spawn_blood_slash_vfx() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var vfx: CPUParticles2D = CPUParticles2D.new()
	vfx.emitting = true
	vfx.one_shot = true
	vfx.amount = 24
	vfx.lifetime = 0.35
	vfx.explosiveness = 0.8
	vfx.spread = 70.0
	vfx.initial_velocity_min = 40.0
	vfx.initial_velocity_max = 120.0
	vfx.color = Color(0.9, 0.1, 0.18, 0.9)
	vfx.global_position = global_position + Vector2(25.0 * _facing_dir, -25.0)
	parent_scene.add_child(vfx)
	vfx.finished.connect(vfx.queue_free)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if is_dead:
		return

	# Mini-boss odaklı dövüş: Oyuncu bizzat savaşır, NPC müttefiklerin hasarı çok düşük tutulur
	if attacker and is_instance_valid(attacker) and attacker.is_in_group("allies"):
		amount = maxi(1, int(amount * 0.2))

	current_health -= amount
	health_changed.emit(current_health, max_health)

	if health_bar:
		health_bar.value = current_health

	# Darbe efekti (kızıl hasar flaşı)
	if visual and not is_dead:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.06)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.14)
		if not _is_attacking and anim_sprite and anim_sprite.sprite_frames.has_animation("hurt"):
			anim_sprite.play("hurt")
			get_tree().create_timer(0.25).timeout.connect(func():
				if not is_dead and not _is_attacking and anim_sprite:
					anim_sprite.play("idle")
			)

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
