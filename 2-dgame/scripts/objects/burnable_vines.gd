class_name BurnableVines
extends StaticBody2D

## res://scripts/objects/burnable_vines.gd
## Meşale veya ateşli mermilerle yakılarak geçit açılmasını sağlayan sarmaşık ve ahşap engelleri.

signal ignited()
signal destroyed()
signal damaged(current_hp: int, max_hp: int)

@export var max_health: int = 30
@export var current_health: int = 30

var is_burning: bool = false
var is_destroyed: bool = false

@onready var visual: Node2D = get_node_or_null("Visual")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")


func _ready() -> void:
	add_to_group("burnable")
	add_to_group("damageable")
	add_to_group("barricades")
	current_health = max_health


func ignite(fire_damage: int = 30) -> void:
	if is_destroyed:
		return

	is_burning = true
	ignited.emit()

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("torch_burn", -2.0)

	_spawn_burn_particles()
	take_damage(fire_damage)


func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if is_destroyed:
		return

	current_health -= amount
	damaged.emit(current_health, max_health)

	if visual:
		var tw = create_tween()
		tw.tween_property(visual, "modulate", Color(2.0, 1.2, 0.6, 1.0), 0.05)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.1)

	if current_health <= 0:
		_destroy()


func hit(amount: int) -> void:
	take_damage(amount)


func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	destroyed.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hurtbox:
		var col = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col:
			col.set_deferred("disabled", true)

	var parent_scene = get_parent()
	if parent_scene:
		var msg = Label.new()
		msg.text = "🌿🔥 SARMAŞIKLAR YANDI!"
		msg.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))
		msg.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 1.0))
		msg.add_theme_constant_override("outline_size", 4)
		msg.add_theme_font_size_override("font_size", 12)
		msg.global_position = global_position + Vector2(-50.0, -40.0)
		parent_scene.add_child(msg)
		var tw = msg.create_tween()
		tw.tween_property(msg, "global_position:y", msg.global_position.y - 25.0, 0.6)
		tw.parallel().tween_property(msg, "modulate:a", 0.0, 0.6)
		tw.tween_callback(msg.queue_free)

	_spawn_burn_particles()
	visible = false
	get_tree().create_timer(0.3).timeout.connect(queue_free)


func _spawn_burn_particles() -> void:
	var parent_scene = get_parent()
	if not parent_scene:
		return

	var fire: CPUParticles2D = CPUParticles2D.new()
	fire.emitting = true
	fire.one_shot = true
	fire.amount = 20
	fire.lifetime = 0.5
	fire.spread = 180.0
	fire.gravity = Vector2(0, -160)
	fire.initial_velocity_min = 30.0
	fire.initial_velocity_max = 80.0
	fire.color = Color(1.0, 0.55, 0.1, 1.0)
	fire.global_position = global_position
	parent_scene.add_child(fire)
	fire.finished.connect(fire.queue_free)

