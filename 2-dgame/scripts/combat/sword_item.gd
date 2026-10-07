extends Area2D

## res://scripts/combat/sword_item.gd
## Bağımsız (Decoupled) Kılıç Eşyası: Yerden alınabilir ve fırlatılabilir.

signal picked_up(by_body: Node2D)
signal landed_on_ground()

@export var float_amplitude: float = 3.5
@export var float_speed: float = 3.0
@export var fall_gravity: float = 850.0

var velocity: Vector2 = Vector2.ZERO
var is_in_air: bool = false
var pickup_cooldown: float = 0.0
var _time_passed: float = 0.0
var _base_y: float = 0.0
var _target_body: Node2D = null

@onready var visual_sprite: Sprite2D = $Visual
@onready var prompt_node: Node2D = $Prompt
@onready var floor_ray: RayCast2D = $FloorRay

func _ready() -> void:
	_base_y = position.y
	if prompt_node:
		prompt_node.visible = false
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown -= delta

	# Havada fırlatılma / düşme durumu
	if is_in_air:
		velocity.y += fall_gravity * delta
		position += velocity * delta
		velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
		
		# Havada süzülürken hafif dönüş efekti
		if visual_sprite:
			visual_sprite.rotation += delta * 6.0

		if floor_ray and floor_ray.is_colliding():
			var hit_pos = floor_ray.get_collision_point()
			if position.y >= hit_pos.y - 6.0:
				position.y = hit_pos.y - 6.0
				velocity = Vector2.ZERO
				is_in_air = false
				_base_y = position.y
				if visual_sprite:
					visual_sprite.rotation = 0.0
				landed_on_ground.emit()
	else:
		# Yerde hafif süzülme (bobbing)
		_time_passed += delta * float_speed
		if visual_sprite:
			visual_sprite.position.y = sin(_time_passed) * float_amplitude

	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not _target_body or pickup_cooldown > 0.0:
		return

	var is_e_pressed = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		is_e_pressed = true
	elif event.is_action_pressed("interact"):
		is_e_pressed = true

	if is_e_pressed:
		_try_pickup()

func _try_pickup() -> void:
	if not _target_body or pickup_cooldown > 0.0:
		return

	# Duck typing: hedef gövde kılıç alabiliyor mu?
	var can_take = false
	if _target_body.has_method("can_pickup_weapon"):
		can_take = _target_body.can_pickup_weapon()
	elif "has_sword" in _target_body:
		can_take = not _target_body.has_sword
	else:
		can_take = true

	if can_take:
		if _target_body.has_method("pickup_weapon"):
			_target_body.pickup_weapon(self)
		elif _target_body.has_method("pickup_sword"):
			_target_body.pickup_sword()
		elif "has_sword" in _target_body:
			_target_body.has_sword = true

		picked_up.emit(_target_body)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Karakter duck typing kontrolü
	if body.has_method("pickup_weapon") or body.has_method("pickup_sword") or ("has_sword" in body):
		_target_body = body

func _on_body_exited(body: Node2D) -> void:
	if body == _target_body:
		_target_body = null

func _update_prompt() -> void:
	if not prompt_node:
		return

	var can_show = false
	if _target_body and pickup_cooldown <= 0.0:
		if _target_body.has_method("can_pickup_weapon"):
			can_show = _target_body.can_pickup_weapon()
		elif "has_sword" in _target_body:
			can_show = not _target_body.has_sword
		else:
			can_show = true

	prompt_node.visible = can_show

## Kılıcı belirli bir noktadan belirli bir hızla fırlatır
func launch(start_pos: Vector2, initial_vel: Vector2, cooldown: float = 0.35) -> void:
	global_position = start_pos
	velocity = initial_vel
	is_in_air = true
	pickup_cooldown = cooldown
	_base_y = start_pos.y
