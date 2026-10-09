extends Area2D

## DarkMagicProjectile - Necromancer Kara Büyü Mermisi
## Uçan mor karanlık büyü küresi, oyuncuya veya dünyaya çarptığında patlar

@export var speed: float = 340.0
@export var damage: int = 30
@export var lifetime: float = 4.0
@export var knockback_force: float = 180.0

@export var homing_strength: float = 2.4 # Engellerin etrafından kavis alarak hedefe yönelme gücü

var direction: Vector2 = Vector2.RIGHT
var is_bursting: bool = false
var _caster: Node2D = null
var _target_node: Node2D = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play(&"travel")

	# Ömür sayacı (boşluğa uçup gitmesin)
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(self) and not is_bursting:
			_trigger_burst()
	)

func setup(spawn_pos: Vector2, target_dir: Vector2, caster_node: Node2D = null, custom_damage: int = 30, target_node: Node2D = null) -> void:
	global_position = spawn_pos
	direction = target_dir.normalized()
	_caster = caster_node
	_target_node = target_node
	damage = custom_damage
	
	# Mermiyi hareket yönüne göre çevir
	if direction.x < 0:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)

func _physics_process(delta: float) -> void:
	if is_bursting:
		return
	
	# Kavisli Homing Takibi (Büyücünün kara büyüsü engellerin etrafından oyuncuyu takip eder)
	if _target_node and is_instance_valid(_target_node):
		var target_center = _target_node.global_position + Vector2(0, -18.0)
		var desired_dir = (target_center - global_position).normalized()
		direction = direction.slerp(desired_dir, homing_strength * delta)
		if direction.x < 0:
			scale.x = -abs(scale.x)
		else:
			scale.x = abs(scale.x)

	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if is_bursting or body == _caster or body == self:
		return

	# Düşmanların birbirini vurmasını engelle (Necromancer dost canavarları vurmasın)
	if body.is_in_group("enemies") and body != _caster:
		return

	# Oyuncuya veya hasar alabilen hedefe hasar ver
	var hit_target: bool = false
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_target = true
	elif body.has_method("hit"):
		body.hit(damage)
		hit_target = true

	# Geri itme kuvveti
	if hit_target and "velocity" in body:
		body.velocity.x += direction.x * knockback_force
		body.velocity.y = -120.0

	_trigger_burst()

func _on_area_entered(area: Area2D) -> void:
	if is_bursting:
		return
	# Oyuncunun Hurtbox'ına veya kalkanına çarptıysa
	var parent_body = area.get_parent()
	if parent_body and parent_body.is_in_group("player"):
		if parent_body.has_method("take_damage"):
			parent_body.take_damage(damage)
			if "velocity" in parent_body:
				parent_body.velocity.x += direction.x * knockback_force
				parent_body.velocity.y = -120.0
		_trigger_burst()

func _trigger_burst() -> void:
	if is_bursting:
		return
	is_bursting = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if col_shape:
		col_shape.set_deferred("disabled", true)

	if anim_sprite:
		anim_sprite.play(&"burst")
	else:
		queue_free()

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation == &"burst":
		queue_free()
