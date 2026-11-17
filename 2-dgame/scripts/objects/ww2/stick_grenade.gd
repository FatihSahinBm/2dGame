class_name StickGrenade
extends Node2D

## res://scripts/objects/ww2/stick_grenade.gd
## Saplı El Bombası (Epic 2D-144): parabolik yayla fırlatılır, zemine değince veya fitil
## bitince patlar. Alan hasarı verir; current_attack_type = "grenade" olduğu için
## gizli duvarları (SecretBreakableWall) ve zırhı kırabilir, mayınları zincirleme patlatır.

const Explosion = preload("res://scripts/hazards/ww2/ww2_explosion.gd")
const TEX: Texture2D = preload("res://assets/items/ww2/stick_grenade.png")

@export var throw_velocity: Vector2 = Vector2(260.0, -340.0)
@export var gravity: float = 900.0
@export var fuse_time: float = 1.6
@export var damage: int = 60
@export var radius: float = 90.0

## SecretBreakableWall / zırhlı düşmanlar saldırı türünü buradan okur
var current_attack_type: String = "grenade"
var velocity: Vector2 = Vector2.ZERO
var is_exploded: bool = false
var _t: float = 0.0


func _ready() -> void:
	velocity = throw_velocity
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.6, 0.6)
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
	rotation += delta * 9.0 * signf(velocity.x)
	if _t >= fuse_time:
		detonate()


func detonate() -> int:
	if is_exploded:
		return 0
	is_exploded = true
	var hits: int = Explosion.explode(get_parent(), global_position, radius, damage, false, true, self, "grenade_blast")
	queue_free()
	return hits
