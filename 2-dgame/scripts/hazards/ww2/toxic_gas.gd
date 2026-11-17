class_name ToxicGas
extends Area2D

## res://scripts/hazards/ww2/toxic_gas.gd
## Zehirli gaz bulutu / koridoru (Epic 2D-144). İçindeki oyuncu aralıklarla zehir hasarı alır.
## Gaz Maskesi Filtresi (Ww2Inventory) veya Kan Sisi Atılması hasarı engeller.
## set_active(false) ile kapatılır (laboratuvar vantilatörleri / röle bulmacası).
## lifetime > 0 ise geçicidir (Gaz Maskeli Lağımcı ölüm bulutu).

signal gas_state_changed(active: bool)

const Inventory = preload("res://scripts/components/ww2_inventory.gd")
const PUFF_TEX: Texture2D = preload("res://assets/effects/ww2/gas_puff.png")

@export var size: Vector2 = Vector2(260.0, 120.0)
@export var damage_per_tick: int = 6
@export var tick_interval: float = 0.5
@export var lifetime: float = 0.0
@export var active: bool = true

var _player: Node2D = null
var _tick: float = 0.0
var _particles: CPUParticles2D = null


func _ready() -> void:
	add_to_group("ww2_hazards")
	add_to_group("ww2_gas")
	collision_layer = 0
	collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0.0, -size.y * 0.5)
	add_child(shape)
	_particles = CPUParticles2D.new()
	_particles.texture = PUFF_TEX
	_particles.amount = int(clampf(size.x * size.y / 900.0, 8.0, 48.0))
	_particles.lifetime = 2.4
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = size * 0.5
	_particles.position = Vector2(0.0, -size.y * 0.5)
	_particles.gravity = Vector2(0.0, -8.0)
	_particles.initial_velocity_min = 4.0
	_particles.initial_velocity_max = 14.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.0
	_particles.color = Color(0.7, 1.0, 0.45, 0.8)
	add_child(_particles)
	body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_player = b
			_tick = 0.2
	)
	body_exited.connect(func(b: Node2D) -> void:
		if b == _player:
			_player = null
	)
	set_active(active)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(_player):
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		apply_tick(_player)


## Tek zehir tıkı; filtre veya kan sisi varsa hasar yok (testler doğrudan çağırır)
func apply_tick(target: Node) -> bool:
	if not active or not is_instance_valid(target) or not target.has_method("take_damage"):
		return false
	if Inventory.is_gas_immune(target) or ("is_blood_mist_dashing" in target and bool(target.is_blood_mist_dashing)):
		return false
	target.take_damage(damage_per_tick, global_position)
	return true


func set_active(value: bool) -> void:
	active = value
	if _particles:
		_particles.emitting = value
	monitoring = value
	gas_state_changed.emit(value)


func _expire() -> void:
	if not is_inside_tree():
		return
	set_active(false)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
