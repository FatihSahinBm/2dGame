class_name PlasmaBolt
extends Node2D

## res://scripts/objects/future/plasma_bolt.gd
## Plazma Kesici Fişek (Epic 2D-158): düz hatta ilerleyen, düşmanları delip geçen (her hedefe
## bir kez) menzilli plazma atışı. Duvara çarpınca söner; "plasma_cuttable" grubundaki
## gizli panelleri (SecretBreakableWall) keser — current_attack_type = "plasma".

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const TEX: Texture2D = preload("res://assets/effects/future/magenta_spark.png")

@export var direction: float = 1.0
@export var speed: float = 620.0
@export var damage: int = 30
@export var max_distance: float = 520.0

var current_attack_type: String = "plasma"
var _travelled: float = 0.0
var _hit: Array[Node] = []


func _ready() -> void:
	add_to_group("player_projectiles")
	var core: Sprite2D = Sprite2D.new()
	core.texture = TEX
	core.scale = Vector2(2.6, 1.2)
	core.modulate = Color(1.4, 0.7, 1.5)
	add_child(core)
	var trail: CPUParticles2D = CPUParticles2D.new()
	trail.texture = TEX
	trail.amount = 18
	trail.lifetime = 0.25
	trail.direction = Vector2(-direction, 0.0)
	trail.initial_velocity_min = 30.0
	trail.initial_velocity_max = 60.0
	trail.gravity = Vector2.ZERO
	trail.color = Color(1.0, 0.4, 0.9, 0.8)
	add_child(trail)
	FutureFx.sfx(self, "sfx_cyber_laser_fire", global_position, -6.0)


func _physics_process(delta: float) -> void:
	var step: Vector2 = Vector2(direction * speed * delta, 0.0)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1 | 2 | 4)
	query.collide_with_areas = true
	var excluded: Array[RID] = []
	for _i: int in 4:
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query) if space else {}
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider")
		var target: Node = _resolve_target(collider)
		if target and not _hit.has(target):
			_hit.append(target)
			FutureFx.damage(target, damage, self)
		if collider is StaticBody2D and not (collider as Node).is_in_group("damageable"):
			queue_free()
			return
		excluded.append(hit.get("rid"))
	global_position += step
	_travelled += absf(step.x)
	if _travelled >= max_distance:
		queue_free()


## Hurtbox gibi alt alanlara çarpılırsa sahibini bulur; oyuncu ve müttefikler atlanır
func _resolve_target(collider: Object) -> Node:
	var node: Node = collider as Node
	while node and not node.has_method("take_damage"):
		node = node.get_parent()
	if node == null or node.is_in_group("player") or node.is_in_group("allies"):
		return null
	if "is_dead" in node and bool(node.is_dead):
		return null
	return node
