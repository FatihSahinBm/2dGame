class_name EmpGrenade
extends Node2D

## res://scripts/objects/future/emp_grenade.gd
## EMP El Bombası (Epic 2D-158): parabolik yayla fırlatılır, zemine değince veya fitil bitince
## elektromanyetik darbe yayar. Mekanik düşmanlara (grup "mechanical") çift hasar ve sersemletme,
## "emp_receivers" grubundaki kalkan/taret/lazer kapılarına on_emp() uygular.
## current_attack_type = "emp": AEGIS kalkanı ve zırhlı muhafızlar bu türü tanır.

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const TEX: Texture2D = preload("res://assets/items/future/emp_grenade.png")

@export var throw_velocity: Vector2 = Vector2(280.0, -330.0)
@export var gravity: float = 900.0
@export var fuse_time: float = 1.5
@export var damage: int = 35
@export var radius: float = 110.0
@export var stun_time: float = 2.5

var current_attack_type: String = "emp"
var velocity: Vector2 = Vector2.ZERO
var is_exploded: bool = false
var _t: float = 0.0


func _ready() -> void:
	velocity = throw_velocity
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.7, 0.7)
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if is_exploded:
		return
	_t += delta
	velocity.y += gravity * delta
	var step: Vector2 = velocity * delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
	var hit: Dictionary = space.intersect_ray(query) if space else {}
	if not hit.is_empty():
		global_position = hit["position"]
		detonate()
		return
	global_position += step
	rotation += delta * 8.0 * signf(velocity.x)
	if _t >= fuse_time:
		detonate()


func detonate() -> int:
	if is_exploded:
		return 0
	is_exploded = true
	var hits: int = FutureFx.emp_burst(get_parent(), global_position, radius, damage, stun_time, self)
	queue_free()
	return hits
