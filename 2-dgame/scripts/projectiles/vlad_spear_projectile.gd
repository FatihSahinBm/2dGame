class_name VladSpearProjectile
extends Area2D

## res://scripts/projectiles/vlad_spear_projectile.gd
## Kazıklı Voyvoda Vlad'ın (İnsan Formu) yükseltilmiş platformlardaki oyuncuya karşı
## fırlattığı ağır demir uçlu mızrak.
## Belirgin telgraf ve doğrusal yörüngeye sahiptir. Oyuncu zıplayarak, takla/dash atarak
## veya kılıç/kalkan ile savuşturarak (parry) saldırıyı atlatabilir.

@export var speed: float = 460.0
@export var damage: int = 35
@export var lifetime: float = 2.8

var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _shooter: Node2D = null
var _is_broken: bool = false

@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var trail_particles: CPUParticles2D = get_node_or_null("TrailParticles") as CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	# Mask 1: Dünya/Platformlar, Mask 4: Oyuncu Hurtbox
	collision_mask = 1 | 4
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(spawn_pos: Vector2, shoot_dir: Vector2, custom_damage: int = 35, shooter_node: Node2D = null) -> void:
	global_position = spawn_pos
	direction = shoot_dir.normalized()
	rotation = direction.angle()
	damage = custom_damage
	_shooter = shooter_node


func _physics_process(delta: float) -> void:
	if _is_broken:
		return
	global_position += direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _is_broken or body == _shooter:
		return
	if body.is_in_group("enemies") and body != _shooter:
		return

	if body.is_in_group("player"):
		_hit_player(body)
		return

	# Zemin, duvar veya platform gibi statik engellere çarpma
	_shatter_on_impact()


func _on_area_entered(area: Area2D) -> void:
	if _is_broken:
		return
	var parent_node = area.get_parent()
	if parent_node == _shooter:
		return

	# Oyuncunun kılıç savurma alanı (AttackArea) ile savuşturma (Parry)
	if area.name == "AttackArea" or area.is_in_group("player_attack"):
		var player_node = parent_node
		if player_node and player_node.is_in_group("player") and player_node.has_method("can_parry_projectile") and player_node.can_parry_projectile():
			_parry_spear(player_node)
			return

	# Oyuncunun Hurtbox alanı
	if parent_node and parent_node.is_in_group("player"):
		_hit_player(parent_node)


func _hit_player(player_node: Node2D) -> void:
	if _is_broken:
		return
	_is_broken = true
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage, global_position)
	elif player_node.has_method("hit"):
		player_node.hit(damage)

	_spawn_impact_particles(Color(0.85, 0.15, 0.2, 0.9))
	queue_free()


func _parry_spear(player_node: Node2D) -> void:
	_is_broken = true
	if player_node.has_method("_play_parry_feedback"):
		player_node._play_parry_feedback(global_position)
	_spawn_impact_particles(Color(1.0, 0.9, 0.3, 1.0))
	queue_free()


func _shatter_on_impact() -> void:
	if _is_broken:
		return
	_is_broken = true
	_spawn_impact_particles(Color(0.7, 0.65, 0.6, 0.8))
	queue_free()


func _spawn_impact_particles(p_color: Color) -> void:
	var parent_scene: Node = get_parent()
	if not parent_scene:
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 10
	burst.lifetime = 0.3
	burst.explosiveness = 0.9
	burst.direction = -direction
	burst.spread = 45.0
	burst.gravity = Vector2(0, 220)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 100.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = p_color
	burst.global_position = global_position
	parent_scene.add_child(burst)
	burst.finished.connect(burst.queue_free)
