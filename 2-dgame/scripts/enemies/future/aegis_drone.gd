class_name AegisDrone
extends Ww2BossBase

## res://scripts/enemies/future/aegis_drone.gd
## AEGIS-09 ikiz dronlarından biri (Epic 2D-158). Çekirdeğin etrafında senkronize yörüngede
## süzülür, çekirdeğe kalkan enerjisi sağlar ve oyuncuya ışın kilidi (kırmızı nişan çizgisi ->
## enerji ışını; siper arkası güvenli) atar. EMP dronları kısa süre sersemletir ve kalkan
## beslemesini keser. Yok edilince çekirdek kalkanı zayıflar.

signal beam_fired()

const FutureAttacks = preload("res://scripts/enemies/future/future_attacks.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export var orbit_radius: float = 150.0
@export var orbit_speed: float = 0.9
@export var phase_offset: float = 0.0
@export var beam_damage: int = 16
@export var beam_interval: float = 3.2

var core: Node2D = null
var _angle: float = 0.0
var _beam_cd: float = 1.5
var _stun_until: int = 0


func _boss_ready() -> void:
	hovering = true
	add_to_group("aegis_drones")
	add_to_group(FutureFx.MECHANICAL_GROUP)
	_angle = phase_offset
	_beam_cd = 1.2 + phase_offset * 0.4


func is_feeding_shield() -> bool:
	return not is_dead and Time.get_ticks_msec() >= _stun_until


func _think(delta: float) -> void:
	if Time.get_ticks_msec() < _stun_until:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		return
	_angle += orbit_speed * delta
	var center: Vector2 = core.global_position if is_instance_valid(core) else global_position
	var goal: Vector2 = center + Vector2(cos(_angle) * orbit_radius, sin(_angle) * orbit_radius * 0.45 - 40.0)
	velocity = (goal - global_position) * 4.0
	face_target()
	play_anim(&"drone_fly" if absf(velocity.x) > 60.0 else &"drone_idle")
	_beam_cd -= delta
	if _beam_cd <= 0.0 and is_instance_valid(_target):
		_beam_cd = beam_interval
		fire_beam()


func fire_beam() -> Line2D:
	play_anim(&"drone_beam_lock", true)
	var a: Vector2 = global_position + Vector2(float(facing) * 20.0, -30.0)
	var b: Vector2 = _target.global_position + Vector2(0.0, -20.0) if is_instance_valid(_target) else a + Vector2(float(facing) * 300.0, 0.0)
	var line: Line2D = FutureAttacks.aim_beam(self, a, a + (b - a).normalized() * 620.0, 0.7, beam_damage)
	beam_fired.emit()
	return line


## Dronun kendi physics döngüsü: hovering olduğu için yerçekimi uygulanmaz
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += gravity * delta
		move_and_slide()
		return
	super._physics_process(delta)


func emp_stun(duration: float) -> void:
	_stun_until = Time.get_ticks_msec() + int(duration * 1000.0)
	_flash(Color(0.6, 1.4, 2.0))


func _on_damaged(_dmg: int, _attacker: Variant) -> void:
	play_anim(&"hurt", true)


func _on_death() -> void:
	hovering = false
	play_anim(&"drone_death", true)
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_EMP, global_position + Vector2(0.0, -30.0), 0.6)
	sfx("sfx_emp_detonate", -6.0)
