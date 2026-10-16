class_name DestructibleBarricade
extends StaticBody2D

## res://scripts/objects/destructible_barricade.gd
## Vlad'ın ordusu tarafından yolu kapatmak için kurulan yıkılabilir ahşap ve kazık barikatı.

signal destroyed()
signal damaged(current_hp: int, max_hp: int)

@export var max_health: int = 50
@export var current_health: int = 50

var _is_destroyed: bool = false

@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("UI/HealthBar") as ProgressBar


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("barricades")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false


func take_damage(amount: int, _attacker: Node2D = null) -> void:
	if _is_destroyed:
		return

	current_health -= amount
	damaged.emit(current_health, max_health)

	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

	# Darbe tepkisi (Sallanma ve beyaz flaş)
	if visual:
		var tw: Tween = create_tween()
		tw.tween_property(visual, "position:x", visual.position.x + randf_range(-4, 4), 0.04)
		tw.tween_property(visual, "position:x", 0.0, 0.04)
		tw.parallel().tween_property(visual, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.04)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.08)

	_spawn_splinters(false)

	if current_health <= 0:
		_destroy()


func hit(amount: int) -> void:
	take_damage(amount)


func _destroy() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	destroyed.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	_spawn_splinters(true)
	visible = false
	get_tree().create_timer(0.4).timeout.connect(queue_free)


func _spawn_splinters(is_explosion: bool) -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24 if is_explosion else 8
	particles.lifetime = 0.55 if is_explosion else 0.3
	particles.explosiveness = 0.85
	particles.spread = 180.0
	particles.gravity = Vector2(0, 350)
	particles.initial_velocity_min = 60.0 if is_explosion else 25.0
	particles.initial_velocity_max = 160.0 if is_explosion else 70.0
	particles.color = Color(0.45, 0.28, 0.18, 1.0) # Ahşap kıymık rengi
	particles.global_position = global_position
	parent_scene.add_child(particles)
	particles.finished.connect(particles.queue_free)
