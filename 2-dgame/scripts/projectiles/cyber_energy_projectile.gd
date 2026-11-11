class_name CyberEnergyProjectile
extends Area2D

## res://scripts/projectiles/cyber_energy_projectile.gd
## Siber Uçan Böceğin ateşlediği yüksek hızlı siber enerji iğnesi / plazma mermisi.
## Kılıç darbesiyle (Parry) doğrudan düşmana geri yansıtılabilir (Reflectable).

signal projectile_hit(target: Node2D)
signal projectile_reflected(reflector: Node2D)

@export var speed: float = 320.0
@export var damage: int = 14
@export var lifetime: float = 3.5

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var is_bursting: bool = false
var _shooter: Node2D = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var light: PointLight2D = get_node_or_null("PointLight2D")
@onready var particles: CPUParticles2D = get_node_or_null("TrailParticles")


func _ready() -> void:
	add_to_group("reflectable_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Güvenlik zaman aşımı
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
	timer.timeout.connect(func():
		if is_instance_valid(self) and not is_bursting:
			_burst()
	)


func setup(spawn_pos: Vector2, target_dir: Vector2, shooter_node: Node2D = null, custom_damage: int = 14) -> void:
	global_position = spawn_pos
	direction = target_dir.normalized()
	rotation = direction.angle()
	_shooter = shooter_node
	damage = custom_damage


func _physics_process(delta: float) -> void:
	if is_bursting:
		return
	global_position += direction * speed * delta


func reflect(reflector: Node2D = null) -> void:
	if is_bursting or is_reflected:
		return
	is_reflected = true
	_shooter = reflector
	direction = -direction
	rotation = direction.angle()
	speed *= 1.45
	damage = int(damage * 1.8)
	
	# Yansıma rengi: Altın sarısı / turuncu siber darbe
	if anim_sprite:
		anim_sprite.modulate = Color(1.8, 1.2, 0.2, 1.0)
	if light:
		light.color = Color(1.0, 0.7, 0.2, 1.0)
		light.energy = 2.0
	
	# Düşman katmanına çarpacak şekilde maskeyi güncelle (Katman 2 = Enemies)
	collision_mask = 1 | 2
	projectile_reflected.emit(reflector)


func _on_body_entered(body: Node2D) -> void:
	if is_bursting or body == _shooter:
		return
	
	if not is_reflected:
		# Oyuncuya çarpış
		if body.is_in_group("player") or body.name == "CombatPlayer" or body.name == "TestPlayer":
			if body.has_method("take_damage"):
				body.take_damage(damage)
			projectile_hit.emit(body)
			_burst()
			return
	else:
		# Yansıtıldığında düşmanlara hasar ver
		if body.is_in_group("enemies") or body.is_in_group("damageable"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			projectile_hit.emit(body)
			_burst()
			return

	# Zemin veya duvara çarpma
	if body is TileMap or body is StaticBody2D or body.name.begins_with("Ground") or body.name.begins_with("Wall"):
		_burst()


func _on_area_entered(area: Area2D) -> void:
	if is_bursting:
		return
	# Oyuncu kılıç saldırı alanı (AttackArea) mermiye vurursa yansıt
	if not is_reflected and area.name == "AttackArea":
		var p = area.get_parent()
		if p and p.get_parent():
			reflect(p.get_parent() as Node2D)


func _burst() -> void:
	if is_bursting:
		return
	is_bursting = true
	speed = 0.0
	if col_shape:
		col_shape.set_deferred("disabled", true)
	if particles:
		particles.emitting = false
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("burst"):
		anim_sprite.play("burst")
		await anim_sprite.animation_finished
	queue_free()

