class_name FutureLaserTrap
extends Node2D

## res://scripts/hazards/future/future_laser_trap.gd
## Yatay tarama lazeri tuzağı (Epic 2D-158). Bölüm 1'deki CyberLaserSystem'i (T-Rex lazeri)
## olduğu gibi kullanır, böylece siper kuralı tüm lazer tuzaklarında aynıdır: ObstacleRay
## (RayCast2D) ilk dünya engelinde ışını keser; arkasındaki oyuncu hasar almaz.
## Döngü: bekleme -> telegraph (kırmızı nişan çizgisi) -> ateş -> toparlanma.
## Kan Sisi Atılması sırasında oyuncu hasar almaz (oyuncunun take_damage kuralı); Faz Kalkanı
## Kapsülü hasarı yarıya indirir. EMP ve EMP terminali tuzağı kapatır.

signal fired(direction: int, actual_range: float)

const LaserScene: PackedScene = preload("res://scenes/enemies/cyber_laser_system.tscn")
const FutureInventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export_range(-1, 1, 2) var direction: int = 1
@export var max_range: float = 480.0
@export var damage: int = 26
@export var idle_time: float = 1.6
@export var start_delay: float = 0.0
@export var powered: bool = true

var laser: CyberLaserSystem = null
var _timer: float = 0.0
var _phase: int = 0 # 0 bekleme, 1 telegraph, 2 ateş/toparlanma
var _emp_until: int = 0


func _ready() -> void:
	add_to_group(FutureFx.EMP_GROUP)
	laser = LaserScene.instantiate() as CyberLaserSystem
	laser.max_range = max_range
	laser.base_damage = damage
	add_child(laser)
	var shape_node: CollisionShape2D = laser.get_node_or_null("LaserHitbox/CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate() # her tuzak kendi menziline göre boyutlanır
	laser.laser_completed.connect(func() -> void:
		_phase = 0
		_timer = idle_time
	)
	_timer = idle_time + start_delay
	_add_emitter_sprite()


func _physics_process(delta: float) -> void:
	if not is_active():
		return
	_timer -= delta
	if _phase == 0 and _timer <= 0.0:
		_phase = 1
		_timer = laser.telegraph_duration
		laser.start_telegraph(direction)
		FutureFx.sfx(self, "sfx_cyber_laser_charge", global_position, -8.0)
	elif _phase == 1 and _timer <= 0.0:
		_phase = 2
		fire()


func is_active() -> bool:
	return powered and Time.get_ticks_msec() >= _emp_until and laser != null


## Ateş anında Faz Kalkanı çarpanı uygulanır (CyberLaserSystem hasarı kendi verir)
func fire() -> void:
	var player: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var dmg: int = maxi(1, int(round(float(damage) * FutureInventory.energy_damage_factor(player))))
	laser.fire_laser(direction, dmg)
	FutureFx.sfx(self, "sfx_cyber_laser_fire", global_position, -6.0)
	fired.emit(direction, laser.current_actual_range)


## EMP terminali / güç yönlendirme bulmacası
func set_powered(value: bool) -> void:
	powered = value
	if not powered and laser:
		laser.stop_laser()
		laser._reset_all()
		_phase = 0
		_timer = idle_time


func on_emp(duration: float) -> void:
	_emp_until = Time.get_ticks_msec() + int(duration * 1000.0)
	if laser:
		laser.stop_laser()
		laser._reset_all()
	_phase = 0
	_timer = idle_time


func _add_emitter_sprite() -> void:
	var path: String = "res://assets/objects/future/trap_laser_gate.png"
	if not ResourceLoader.exists(path):
		return
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = load(path) as Texture2D
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.5, 0.3)
	spr.position = Vector2(-6.0 * float(direction), 0.0)
	add_child(spr)
	move_child(spr, 0)
