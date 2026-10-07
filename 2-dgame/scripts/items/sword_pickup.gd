extends Area2D
class_name SwordPickup

## Yerde duran veya fırlatılan kılıç eşyası

@export var float_amplitude: float = 4.0
@export var float_speed: float = 3.5
@export var fall_gravity: float = 900.0

var velocity: Vector2 = Vector2.ZERO
var is_in_air: bool = false
var pickup_cooldown: float = 0.0
var _time_passed: float = 0.0
var _base_y: float = 0.0
var _player_nearby: CharacterBody2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Node2D = $Prompt
@onready var floor_ray: RayCast2D = $FloorRay

func _ready() -> void:
	_base_y = position.y
	if prompt:
		prompt.visible = false
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown -= delta

	# Fırlatılma / Düşme hareketi
	if is_in_air:
		velocity.y += fall_gravity * delta
		position += velocity * delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

		# Zemine çarpma kontrolü
		if floor_ray and floor_ray.is_colliding():
			var collision_point = floor_ray.get_collision_point()
			if position.y >= collision_point.y - 4.0:
				position.y = collision_point.y - 4.0
				velocity = Vector2.ZERO
				is_in_air = false
				_base_y = position.y
	else:
		# Yerde hafif süzülme (bobbing) efekti
		_time_passed += delta * float_speed
		if sprite:
			sprite.position.y = sin(_time_passed) * float_amplitude

	# Prompt görünürlüğü güncelle
	_update_prompt_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or pickup_cooldown > 0.0:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_try_pickup()

func _try_pickup() -> void:
	if _player_nearby and _player_nearby.has_method("pickup_sword"):
		if not _player_nearby.has_sword:
			_player_nearby.pickup_sword()
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("pickup_sword"):
		_player_nearby = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null

func _update_prompt_visibility() -> void:
	if prompt:
		var can_pickup = (_player_nearby != null and pickup_cooldown <= 0.0 and not _player_nearby.has_sword)
		prompt.visible = can_pickup

## Kılıç fırlatıldığında/bırakıldığında çağrılır
func launch(start_pos: Vector2, initial_vel: Vector2, cooldown: float = 0.4) -> void:
	global_position = start_pos
	velocity = initial_vel
	is_in_air = true
	pickup_cooldown = cooldown
	_base_y = start_pos.y
