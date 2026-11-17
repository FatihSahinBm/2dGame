class_name AegisCore
extends Ww2BossBase

## res://scripts/enemies/future/aegis_core.gd
## Mini-Boss 2 — AEGIS-09 Merkez Güvenlik Çekirdeği (Epic 2D-158).
## İki senkronize dron (AegisDrone) çekirdeğe kalkan sağlar: en az bir dron kalkanı
## besliyorsa çekirdek hasar almaz. Dronlar yok edilince ya da EMP El Bombası kalkanı
## düşürünce çekirdek aşırı ısınır (overheat_exposed) ve hasar alır; süre bitince kalkan
## yeniden kurulur ve yok edilen dronlar yeniden üretilir. Çekirdek periyodik kalkan
## nabzı (shield_pulse) ile yakındaki oyuncuyu iter.

signal shield_state_changed(shield_up: bool)
signal drones_spawned(drones: Array[AegisDrone])

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const DRONE_SCENE_PATH: String = "res://scenes/enemies/future/aegis_drone.tscn"

@export var expose_time: float = 6.0
@export var emp_expose_time: float = 5.0
@export var pulse_interval: float = 4.5
@export var pulse_radius: float = 120.0
@export var pulse_damage: int = 14

var drones: Array[AegisDrone] = []
var shield_up: bool = true
var _expose_until: int = 0
var _pulse_cd: float = 3.0
var _shield_sprite: Sprite2D = null


func _boss_ready() -> void:
	hovering = true
	add_to_group(FutureFx.EMP_GROUP)
	add_to_group(FutureFx.MECHANICAL_GROUP)
	_shield_sprite = get_node_or_null("Visual/Shield") as Sprite2D
	for child: Node in get_parent().get_children() if get_parent() else []:
		if child is AegisDrone:
			_adopt(child as AegisDrone)


func _adopt(drone: AegisDrone) -> void:
	if drones.has(drone):
		return
	drone.core = self
	drones.append(drone)
	drone.defeated.connect(_on_drone_defeated)


func on_cinematic_ended() -> void:
	super.on_cinematic_ended()
	for d: AegisDrone in drones:
		if is_instance_valid(d):
			d.on_cinematic_ended()


func alive_feeding_drones() -> int:
	var n: int = 0
	for d: AegisDrone in drones:
		if is_instance_valid(d) and d.is_feeding_shield():
			n += 1
	return n


func is_exposed() -> bool:
	return Time.get_ticks_msec() < _expose_until


func _think(delta: float) -> void:
	velocity.y = (ground_y - 130.0 - global_position.y) * 3.0
	velocity.x = 0.0
	face_target()
	if is_exposed():
		if shield_up:
			_set_shield(false)
	elif alive_feeding_drones() == 0 and shield_up:
		expose(expose_time) # dronlar az önce düştü
	elif not shield_up:
		respawn_missing_drones() # ısınma bitti: kalkan ve eksik dronlar yeniden kurulur
	play_anim(&"overheat_exposed" if is_exposed() else (&"shield_pulse" if _pulse_cd < 0.6 else &"core_idle"))
	_pulse_cd -= delta
	if _pulse_cd <= 0.0 and shield_up:
		_pulse_cd = pulse_interval
		shield_pulse()


func shield_pulse() -> void:
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_TIME_FRACTURE, global_position + Vector2(0.0, -30.0), 0.8)
	sfx("sfx_time_slow_warp", -6.0)
	var player: Node2D = find_player()
	if player and player.global_position.distance_to(global_position) <= pulse_radius:
		if not ("is_blood_mist_dashing" in player and bool(player.is_blood_mist_dashing)) and player.has_method("take_damage"):
			player.take_damage(pulse_damage, global_position)


## Kalkan düşer, çekirdek aşırı ısınır
func expose(duration: float) -> void:
	_expose_until = Time.get_ticks_msec() + int(duration * 1000.0)
	_set_shield(false)


func on_emp(_duration: float) -> void:
	expose(emp_expose_time)
	for d: AegisDrone in drones:
		if is_instance_valid(d) and not d.is_dead:
			d.emp_stun(emp_expose_time)


func emp_stun(duration: float) -> void:
	on_emp(duration)


func _set_shield(value: bool) -> void:
	shield_up = value
	if _shield_sprite:
		_shield_sprite.visible = value
	if not value:
		float_text("FUT_FLOAT_SHIELD_DOWN", Color(1.0, 0.7, 0.3))
	shield_state_changed.emit(value)


func _modify_damage(amount: int, attacker: Variant) -> int:
	if shield_up:
		if attack_type_of(attacker) == "emp":
			on_emp(emp_expose_time)
			return amount
		float_text("FUT_FLOAT_SHIELD_BLOCK", Color(0.6, 0.85, 1.0))
		damage_blocked.emit("shield")
		return 0
	return int(round(float(amount) * 1.25))


func _on_drone_defeated() -> void:
	if alive_feeding_drones() == 0 and not is_exposed():
		expose(expose_time)


## Kalkan yeniden kurulurken yok edilen dronlar yeniden üretilir
func respawn_missing_drones() -> Array[AegisDrone]:
	var spawned: Array[AegisDrone] = []
	drones = drones.filter(func(d: AegisDrone) -> bool: return is_instance_valid(d) and not d.is_dead)
	if is_dead or not ResourceLoader.exists(DRONE_SCENE_PATH):
		return spawned
	var packed: PackedScene = load(DRONE_SCENE_PATH) as PackedScene
	while drones.size() < 2:
		var drone: AegisDrone = packed.instantiate() as AegisDrone
		drone.phase_offset = PI * float(drones.size())
		get_parent().add_child(drone)
		drone.global_position = global_position + Vector2(0.0, -80.0)
		drone.ground_y = ground_y
		drone.arena_bounds = arena_bounds
		_adopt(drone)
		drone.on_cinematic_ended()
		FutureFx.play_vfx(get_parent(), FutureFx.VFX_TELEPORT, drone.global_position, 0.6)
		spawned.append(drone)
	_set_shield(true)
	drones_spawned.emit(spawned)
	return spawned


func _on_death() -> void:
	for d: AegisDrone in drones:
		if is_instance_valid(d) and not d.is_dead:
			d.die()
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_EMP, global_position, 1.6)
	sfx("sfx_emp_detonate")
