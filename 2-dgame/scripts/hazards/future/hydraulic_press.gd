class_name HydraulicPress
extends Node2D

## res://scripts/hazards/future/hydraulic_press.gd
## Ritmik hidrolik pres (Epic 2D-158): yukarıda bekler -> sarı uyarı ışığı (telegraph) -> iner
## (ezme penceresi) -> kalkar. Altındaki oyuncu ezme anında ağır hasar alır ve itilir; Kan Sisi
## Atılması ezilmeyi engeller. Pres kafası bir platformdur (StaticBody2D): yukarıdayken üstüne
## basılabilir. EMP presi kısa süre havada kilitler; terminal (set_powered) kalıcı durdurur.

signal slammed(position: Vector2)

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const TEX: String = "res://assets/objects/future/trap_hydraulic_press.png"

@export var travel: float = 120.0
@export var damage: int = 34
@export var up_time: float = 1.4
@export var warn_time: float = 0.5
@export var down_time: float = 0.45
@export var start_offset: float = 0.0
@export var powered: bool = true

enum Phase { UP, WARN, SLAM, DOWN, RISE }

var phase: Phase = Phase.UP
var _t: float = 0.0
var _emp_until: int = 0
var head: AnimatableBody2D = null
var _crush: Area2D = null
var _warn: Sprite2D = null
var _hit_this_cycle: bool = false


func _ready() -> void:
	add_to_group(FutureFx.EMP_GROUP)
	_t = start_offset
	head = AnimatableBody2D.new()
	head.collision_layer = 1
	head.collision_mask = 0
	head.sync_to_physics = false # pres kafası _physics_process içinde taşınıyor; senkron gerekmez
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(100.0, 26.0)
	cs.shape = rect
	head.add_child(cs)
	if ResourceLoader.exists(TEX):
		var spr: Sprite2D = Sprite2D.new()
		spr.texture = load(TEX) as Texture2D
		spr.offset = Vector2(0.0, -85.0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		head.add_child(spr)
	_crush = Area2D.new()
	_crush.collision_layer = 0
	_crush.collision_mask = 1
	var cs2: CollisionShape2D = CollisionShape2D.new()
	var r2: RectangleShape2D = RectangleShape2D.new()
	r2.size = Vector2(90.0, 18.0)
	cs2.shape = r2
	cs2.position = Vector2(0.0, 20.0)
	_crush.add_child(cs2)
	head.add_child(_crush)
	add_child(head)
	_warn = Sprite2D.new()
	_warn.texture = load("res://assets/effects/future/neon_spark.png") as Texture2D
	_warn.modulate = Color(1.0, 0.7, 0.2, 0.0)
	_warn.scale = Vector2(3.0, 3.0)
	_warn.position = Vector2(0.0, -24.0)
	add_child(_warn)


func is_running() -> bool:
	return powered and Time.get_ticks_msec() >= _emp_until


func _physics_process(delta: float) -> void:
	if not is_running():
		return
	_t += delta
	match phase:
		Phase.UP:
			_warn.modulate.a = 0.0
			if _t >= up_time:
				_set_phase(Phase.WARN)
		Phase.WARN:
			_warn.modulate.a = 0.5 + 0.5 * sin(_t * 30.0)
			if _t >= warn_time:
				_set_phase(Phase.SLAM)
				_hit_this_cycle = false
		Phase.SLAM:
			head.position.y = minf(travel, head.position.y + travel / 0.12 * delta)
			_check_crush()
			if head.position.y >= travel:
				slammed.emit(head.global_position)
				FutureFx.sfx(self, "sfx_hydraulic_stomp", head.global_position, -4.0)
				FutureFx.shake(self, 3.0, 0.15, "future_press")
				_set_phase(Phase.DOWN)
		Phase.DOWN:
			_check_crush()
			if _t >= down_time:
				_set_phase(Phase.RISE)
		Phase.RISE:
			head.position.y = maxf(0.0, head.position.y - travel / 0.8 * delta)
			if head.position.y <= 0.0:
				_set_phase(Phase.UP)


func _set_phase(p: Phase) -> void:
	phase = p
	_t = 0.0


func is_crushing() -> bool:
	return phase == Phase.SLAM or (phase == Phase.DOWN and _t < 0.1)


func _check_crush() -> void:
	if _hit_this_cycle or not is_crushing():
		return
	for body: Node2D in _crush.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			if "is_blood_mist_dashing" in body and bool(body.is_blood_mist_dashing):
				continue
			_hit_this_cycle = true
			body.take_damage(damage, head.global_position + Vector2(0.0, -30.0))


func set_powered(value: bool) -> void:
	powered = value


func on_emp(duration: float) -> void:
	_emp_until = Time.get_ticks_msec() + int(duration * 1000.0)
