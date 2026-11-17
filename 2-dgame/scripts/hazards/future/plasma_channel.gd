class_name PlasmaChannel
extends Area2D

## res://scripts/hazards/future/plasma_channel.gd
## Zemin plazma kanalı (Epic 2D-158): belirli aralıklarla plazma püskürtür. Püskürme sırasında
## kanalın üstünde duran oyuncu enerji hasarı alır (Kan Sisi: hasar yok, Faz Kalkanı: yarı hasar).
## Püskürme öncesi kanal titreşir (telegraph). EMP / terminal kanalı söndürür.

const FutureInventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")
const TEX: String = "res://assets/objects/future/trap_plasma_channel.png"
const SPARK: Texture2D = preload("res://assets/effects/future/magenta_spark.png")

@export var width: float = 128.0
@export var damage: int = 14
@export var idle_time: float = 1.8
@export var burst_time: float = 1.0
@export var start_offset: float = 0.0
@export var powered: bool = true

var bursting: bool = false
var _t: float = 0.0
var _tick: float = 0.0
var _emp_until: int = 0
var _fx: CPUParticles2D = null
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group(FutureFx.EMP_GROUP)
	collision_layer = 0
	collision_mask = 1
	_t = start_offset
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(width, 40.0)
	cs.shape = rect
	cs.position = Vector2(0.0, -20.0)
	add_child(cs)
	if ResourceLoader.exists(TEX):
		_sprite = Sprite2D.new()
		_sprite.texture = load(TEX) as Texture2D
		_sprite.scale = Vector2(width / 128.0, 1.0)
		_sprite.position = Vector2(0.0, -6.0)
		add_child(_sprite)
	_fx = CPUParticles2D.new()
	_fx.texture = SPARK
	_fx.amount = 40
	_fx.lifetime = 0.5
	_fx.emitting = false
	_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fx.emission_rect_extents = Vector2(width * 0.5, 4.0)
	_fx.direction = Vector2.UP
	_fx.spread = 12.0
	_fx.initial_velocity_min = 120.0
	_fx.initial_velocity_max = 200.0
	_fx.gravity = Vector2(0.0, 120.0)
	_fx.color = Color(1.0, 0.4, 0.9, 1.0)
	add_child(_fx)


func is_running() -> bool:
	return powered and Time.get_ticks_msec() >= _emp_until


func _physics_process(delta: float) -> void:
	if not is_running():
		bursting = false
		_fx.emitting = false
		return
	_t += delta
	var period: float = idle_time + burst_time
	var local: float = fmod(_t, period)
	var was: bool = bursting
	bursting = local >= idle_time
	_fx.emitting = bursting
	if _sprite:
		_sprite.modulate = Color(1.6, 1.0, 1.6) if bursting else (Color(1.2, 1.0, 1.2) if local > idle_time - 0.4 else Color.WHITE)
	if bursting and not was:
		FutureFx.sfx(self, "sfx_cyber_laser_fire", global_position, -10.0)
	_tick -= delta
	if bursting and _tick <= 0.0:
		for body: Node2D in get_overlapping_bodies():
			if body.is_in_group("player") and FutureInventory.apply_energy_damage(body, damage, global_position):
				_tick = 0.45


func set_powered(value: bool) -> void:
	powered = value


func on_emp(duration: float) -> void:
	_emp_until = Time.get_ticks_msec() + int(duration * 1000.0)
