class_name FlamingArrow
extends Area2D

## res://scripts/projectiles/flaming_arrow.gd
## Osmanlı Kemankeşlerinin fırlattığı alevli ok mermisi.
## Düşmanları yakar, sersemletir ve arkasında alev izi bırakır.

@export var speed: float = 520.0
@export var damage: int = 24
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Düşman katmanı
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func setup(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direction = dir.normalized()
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("hit"):
		body.hit(damage)

	_spawn_fire_burst()
	queue_free()


func _spawn_fire_burst() -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return

	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 12
	burst.lifetime = 0.35
	burst.explosiveness = 0.9
	burst.direction = -direction
	burst.spread = 45.0
	burst.gravity = Vector2(0, 120)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 140.0
	burst.color = Color(1.0, 0.45, 0.1, 1.0)
	burst.global_position = global_position
	parent_scene.add_child(burst)
	burst.finished.connect(burst.queue_free)
