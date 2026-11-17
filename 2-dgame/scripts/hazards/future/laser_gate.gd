class_name LaserGate
extends Node2D

## res://scripts/hazards/future/laser_gate.gd
## Dikey lazer kapısı / ızgara (Epic 2D-158). Tavandaki yayıcıdan aşağı ışın iner; ışın boyu
## RayCast2D ile ilk dünya engeline göre hesaplanır (CyberLaserSystem ile aynı siper kuralı).
## Açık/kapalı döngü (cycle_on/cycle_off; cycle_off = 0 ise sürekli açık). Işına giren oyuncu
## enerji hasarı alır ve geri itilir; Kan Sisi Atılması ile hasarsız geçilir, Faz Kalkanı yarıya
## indirir. EMP / EMP terminali kapıyı söndürür.

signal player_burned(amount: int)

const FutureInventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export var beam_length: float = 200.0
@export var damage: int = 18
@export var cycle_on: float = 1.6
@export var cycle_off: float = 1.2
@export var start_offset: float = 0.0
@export var powered: bool = true
@export var beam_color: Color = Color(1.0, 0.18, 0.3, 1.0)

var beam_on: bool = true
var current_length: float = 200.0
var _t: float = 0.0
var _emp_until: int = 0
var _cooldown: float = 0.0
var _ray: RayCast2D = null
var _area: Area2D = null
var _shape: RectangleShape2D = null
var _beam: Line2D = null
var _core: Line2D = null


func _ready() -> void:
	add_to_group(FutureFx.EMP_GROUP)
	add_to_group("future_laser_gates")
	_t = start_offset
	_ray = RayCast2D.new()
	_ray.target_position = Vector2(0.0, beam_length)
	_ray.collision_mask = 1
	_ray.enabled = true
	add_child(_ray)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var cs: CollisionShape2D = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	cs.shape = _shape
	_area.add_child(cs)
	add_child(_area)
	_beam = _make_line(10.0, Color(beam_color, 0.45))
	_core = _make_line(3.0, Color(1.0, 0.85, 0.9, 1.0))
	var post: String = "res://assets/objects/future/trap_laser_gate.png"
	if ResourceLoader.exists(post):
		var spr: Sprite2D = Sprite2D.new()
		spr.texture = load(post) as Texture2D
		spr.scale = Vector2(0.9, 0.18)
		add_child(spr)
	_update_beam()


func _make_line(width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.z_index = 15
	add_child(line)
	return line


func is_active() -> bool:
	return powered and beam_on and Time.get_ticks_msec() >= _emp_until


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if cycle_off > 0.0:
		_t += delta
		var period: float = cycle_on + cycle_off
		beam_on = fmod(_t, period) < cycle_on
	_update_beam()
	if not is_active() or _cooldown > 0.0:
		return
	for body: Node2D in _area.get_overlapping_bodies():
		if body.is_in_group("player") and FutureInventory.apply_energy_damage(body, damage, global_position + Vector2(0.0, current_length * 0.5)):
			_cooldown = 0.6
			player_burned.emit(damage)
			FutureFx.sfx(self, "sfx_cyber_laser_fire", body.global_position, -8.0)


## Işın boyu siper kuralına göre (ilk engel) güncellenir
func _update_beam() -> void:
	current_length = beam_length
	if _ray and _ray.is_inside_tree():
		_ray.force_raycast_update()
		if _ray.is_colliding() and not (_ray.get_collider() as Node).is_in_group("player"):
			current_length = clampf(global_position.distance_to(_ray.get_collision_point()), 8.0, beam_length)
	var on: bool = is_active()
	for line: Line2D in [_beam, _core]:
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, current_length)])
		line.visible = on
	_shape.size = Vector2(14.0, current_length)
	(_area.get_child(0) as CollisionShape2D).position = Vector2(0.0, current_length * 0.5)
	_area.monitoring = on


func set_powered(value: bool) -> void:
	powered = value
	_update_beam()


func on_emp(duration: float) -> void:
	_emp_until = Time.get_ticks_msec() + int(duration * 1000.0)
	_update_beam()
