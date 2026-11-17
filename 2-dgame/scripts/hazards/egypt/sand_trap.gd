class_name SandTrap
extends Area2D

## res://scripts/hazards/egypt/sand_trap.gd
## Kum tuzağı / bataklık kum (Epic 2D-143). İçinde kalan oyuncuyu yavaşlatır, aşağı çeker ve
## aralıklı hasar verir. Firavun'un 2. fazında geçici (lifetime > 0) tuzak olarak da çağrılır.

signal player_trapped(player: Node2D)

const FRAMES: Array[Texture2D] = [
	preload("res://assets/objects/egypt/sand_trap_0.png"),
	preload("res://assets/objects/egypt/sand_trap_1.png"),
]

@export var damage_per_tick: int = 6
@export var tick_interval: float = 0.8
@export var slow_factor: float = 0.55
@export var lifetime: float = 0.0 # 0 = kalıcı
@export var width: float = 128.0

var _bodies: Array[Node2D] = []
var _tick_timer: float = 0.0
var _anim_t: float = 0.0
var _age: float = 0.0
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("egypt_hazards")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if get_node_or_null("CollisionShape2D") == null:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(width, 20.0)
		var col: CollisionShape2D = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		col.shape = shape
		col.position = Vector2(0.0, -8.0)
		add_child(col)
	_sprite = Sprite2D.new()
	_sprite.texture = FRAMES[0]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(width / 128.0, 1.0)
	_sprite.position = Vector2(0.0, -4.0)
	_sprite.z_index = -1
	add_child(_sprite)
	if lifetime > 0.0:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if _sprite:
		_sprite.texture = FRAMES[int(_anim_t * 4.0) % FRAMES.size()]
	if lifetime > 0.0:
		_age += delta
		if _age >= lifetime:
			set_physics_process(false)
			var tw: Tween = create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.4)
			tw.tween_callback(queue_free)
			return
	if _bodies.is_empty():
		return
	for body: Node2D in _bodies:
		if is_instance_valid(body) and "velocity" in body:
			body.velocity.x *= slow_factor
			if body.velocity.y > 0.0:
				body.velocity.y *= 0.6
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		for body: Node2D in _bodies:
			apply_tick(body)


## Tek hasar darbesi (testler ve fizik döngüsü kullanır)
func apply_tick(body: Node2D) -> void:
	if is_instance_valid(body) and body.has_method("take_damage") and not ("is_dead" in body and body.is_dead):
		body.take_damage(damage_per_tick, global_position)


func is_trapping(body: Node2D) -> bool:
	return _bodies.has(body)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _bodies.has(body):
		_bodies.append(body)
		_tick_timer = tick_interval * 0.5
		player_trapped.emit(body)
		var am: Node = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sound_2d"):
			am.play_sound_2d("sand_trap", global_position, null, -4.0, 700.0)


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
