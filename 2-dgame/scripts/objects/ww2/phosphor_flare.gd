class_name PhosphorFlare
extends Node2D

## res://scripts/objects/ww2/phosphor_flare.gd
## Fosfor İşaret Fişeği (Epic 2D-144): yerleştirildiği yerde `duration` boyunca güçlü beyaz
## ışık yayar (karanlık sığınak/laboratuvar köşelerini aydınlatır) ve yakındaki düşmanlara
## bir kez yakma hasarı verir; yanabilir nesneleri (burnable) tutuşturur.

const LIGHT_TEX: Texture2D = preload("res://assets/effects/lighting/light_radial_falloff.png")
const FLAME_TEX: Texture2D = preload("res://assets/effects/ww2/flame_particle.png")

@export var duration: float = 10.0
@export var burn_damage: int = 25
@export var burn_radius: float = 110.0

var burned: int = 0
var light: PointLight2D = null


func _ready() -> void:
	add_to_group("ww2_flares")
	light = PointLight2D.new()
	light.texture = LIGHT_TEX
	light.color = Color(1.0, 0.95, 0.85)
	light.energy = 1.6
	light.texture_scale = 3.0
	add_child(light)
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.texture = FLAME_TEX
	sparks.amount = 20
	sparks.lifetime = 0.6
	sparks.direction = Vector2.UP
	sparks.spread = 40.0
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 70.0
	sparks.gravity = Vector2(0.0, 120.0)
	sparks.color = Color(1.0, 1.0, 0.9)
	add_child(sparks)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("flare_ignite", global_position, null, -3.0, 900.0)
	burn_nearby()
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(0.1, duration - 1.0))
	tw.tween_property(light, "energy", 0.0, 1.0)
	tw.tween_callback(queue_free)


func burn_nearby() -> int:
	burned = 0
	if not is_inside_tree():
		return 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and (node as Node2D).global_position.distance_to(global_position) <= burn_radius:
			if node.has_method("ignite"):
				node.ignite(burn_damage)
			elif node.has_method("take_damage") and not ("is_dead" in node and bool(node.is_dead)):
				node.take_damage(burn_damage)
			burned += 1
	return burned
