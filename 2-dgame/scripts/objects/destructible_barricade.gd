class_name DestructibleBarricade
extends StaticBody2D

## res://scripts/objects/destructible_barricade.gd
## Vlad'ın ordusu tarafından yolu kapatmak için kurulan yıkılabilir ahşap ve kazık barikatı.

signal destroyed()
signal damaged(current_hp: int, max_hp: int)

@export var max_health: int = 40
@export var current_health: int = 40

var _is_destroyed: bool = false

@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = get_node_or_null("UI/HealthBar") as ProgressBar


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("barricades")
	add_to_group("burnable")
	add_to_group("enemies")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false


func ignite(amount: int = 30) -> void:
	if _is_destroyed:
		return
	_spawn_fire_particles()
	take_damage(amount)


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
		tw.tween_property(visual, "position:x", visual.position.x + randf_range(-5, 5), 0.04)
		tw.tween_property(visual, "position:x", 0.0, 0.04)
		tw.parallel().tween_property(visual, "modulate", Color(2.0, 1.8, 1.4, 1.0), 0.04)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.08)

	_spawn_damage_text(amount)
	_spawn_splinters(false)

	if current_health <= 0:
		_destroy()


func hit(amount: int) -> void:
	take_damage(amount)


func _spawn_damage_text(amount: int) -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var label: Label = Label.new()
	label.text = "💥 -%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = global_position + Vector2(randf_range(-14, 14), -65.0)
	parent_scene.add_child(label)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 25.0, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


func _destroy() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	destroyed.emit()

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	var hurtbox_col = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	if hurtbox_col:
		hurtbox_col.set_deferred("disabled", true)

	var parent_scene: Node = get_parent()
	if parent_scene:
		var blast_label: Label = Label.new()
		blast_label.text = "🪵 BARİKAT YIKILDI!"
		blast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		blast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05, 1.0))
		blast_label.add_theme_constant_override("outline_size", 4)
		blast_label.add_theme_font_size_override("font_size", 13)
		blast_label.global_position = global_position + Vector2(-45.0, -80.0)
		parent_scene.add_child(blast_label)
		var tw: Tween = blast_label.create_tween()
		tw.tween_property(blast_label, "global_position:y", blast_label.global_position.y - 30.0, 0.8)
		tw.parallel().tween_property(blast_label, "modulate:a", 0.0, 0.8)
		tw.tween_callback(blast_label.queue_free)

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


func _spawn_fire_particles() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return

	var fire: CPUParticles2D = CPUParticles2D.new()
	fire.emitting = true
	fire.one_shot = true
	fire.amount = 16
	fire.lifetime = 0.5
	fire.explosiveness = 0.8
	fire.spread = 180.0
	fire.gravity = Vector2(0, -180)
	fire.initial_velocity_min = 40.0
	fire.initial_velocity_max = 90.0
	fire.color = Color(1.0, 0.5, 0.1, 1.0)
	fire.global_position = global_position + Vector2(0, -30.0)
	parent_scene.add_child(fire)
	fire.finished.connect(fire.queue_free)
