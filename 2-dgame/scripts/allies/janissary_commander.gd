class_name JanissaryCommander
extends CharacterBody2D

## res://scripts/allies/janissary_commander.gd
## Târgovişte Gece Baskını'nda pusuya düşen ve ana karakter tarafından kurtarılan
## Osmanlı Öncü Kumandanı (Yeniçeri Ağası).

signal rescued()
signal reached_sultan_tent()
signal died(death_pos: Vector2)

@export var max_health: int = 140
@export var current_health: int = 140
@export var speed: float = 85.0
@export var attack_damage: int = 24

var gravity: float = 980.0
var is_rescued: bool = false
var _is_dead: bool = false
var _target_enemy: Node2D = null
var _attack_timer: float = 0.0

@onready var visual: Node2D = $Visual
@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var attack_area: Area2D = $Visual/AttackArea
@onready var health_bar: ProgressBar = $UI/HealthBar


func _ready() -> void:
	add_to_group("allies")
	add_to_group("damageable")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	_attack_timer = maxf(0.0, _attack_timer - delta)

	if not is_rescued:
		_combat_logic(delta)
	else:
		# Kurtarıldıktan sonra otağa doğru ilerler
		move_and_slide()


func _combat_logic(delta: float) -> void:
	_find_nearby_enemy()
	if _target_enemy and is_instance_valid(_target_enemy):
		var dist: float = global_position.distance_to(_target_enemy.global_position)
		var dir_x: float = signf(_target_enemy.global_position.x - global_position.x)
		if dir_x != 0.0:
			visual.scale.x = absf(visual.scale.x) * dir_x

		if dist <= 50.0:
			velocity.x = 0.0
			if _attack_timer <= 0.0:
				_perform_attack()
		else:
			velocity.x = dir_x * speed
			if anim_sprite and anim_sprite.sprite_frames.has_animation("walk"):
				anim_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 2.0 * delta)
		if anim_sprite and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")

	move_and_slide()


func _find_nearby_enemy() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest_dist: float = 380.0
	_target_enemy = null

	for node in enemies:
		if node is Node2D and node != self and not ("is_dead" in node and node.is_dead):
			var d: float = global_position.distance_to(node.global_position)
			if d < closest_dist:
				closest_dist = d
				_target_enemy = node


func _perform_attack() -> void:
	_attack_timer = 1.1
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

	velocity.x = signf(visual.scale.x) * 45.0

	get_tree().create_timer(0.2).timeout.connect(func():
		if _is_dead or not attack_area:
			return
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(attack_damage)
	)


func mark_rescued() -> void:
	if is_rescued:
		return
	is_rescued = true
	rescued.emit()
	shout("Yiğit yabancı! Gel, seni derhal Hünkarımız Fatih Sultan Mehmet'in otağına götüreyim!")


func shout(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(-120.0, -55.0)

	var parent_scene: Node = get_parent()
	if parent_scene:
		parent_scene.add_child(label)
		var tw: Tween = label.create_tween()
		tw.tween_property(label, "global_position:y", label.global_position.y - 30.0, 2.2)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 2.2)
		tw.tween_callback(label.queue_free)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_dead:
		return
	current_health -= amount
	if health_bar:
		health_bar.value = current_health

	if visual and is_instance_valid(visual):
		var tw: Tween = create_tween()
		tw.tween_property(visual, "modulate", Color.RED, 0.08)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.12)

	if attacker and attacker.is_in_group("player"):
		var game_state: Node = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("add_corruption"):
			game_state.add_corruption(8)

	if current_health <= 0:
		_is_dead = true
		died.emit(global_position)
		if anim_sprite and anim_sprite.sprite_frames.has_animation("death"):
			anim_sprite.play("death")
		queue_free()
