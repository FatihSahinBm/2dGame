class_name ChronoWarden
extends Ww2BossBase

## res://scripts/enemies/future/chrono_warden.gd
## Mini-Boss 1 — Krono-Muhafız (Zaman-Yarığı Muhafızı), Epic 2D-158. Montaj hattı kapı kilidini korur.
## Saldırılar: koçbaşı hücumu (charge_ram), kol lazeri taraması (arm_laser_sweep — siper kuralı),
## omuz topu atışı (aim_beam) ve zamansal ezme (temporal_stomp — şok dalgaları).
## Zırh kuralı: önden gelen darbeler engellenir. Arkasındaki soğutma hücresine vurmak veya
## dalış saldırısı (plunge) ya da EMP groggy penceresi açar; groggy sırasında tüm darbeler işler.

signal armor_blocked()
signal groggy_started()

enum State { IDLE, MOVE, TELEGRAPH, CHARGE, RECOVER, GROGGY, DYING }

const FutureAttacks = preload("res://scripts/enemies/future/future_attacks.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")
const GROGGY_TIME: float = 3.2
const OPENER_TYPES: Array[String] = ["plunge", "emp"]

@export var ram_damage: int = 22
@export var cannon_damage: int = 18
@export var sweep_damage: int = 16
@export var stomp_damage: int = 18

var state: State = State.IDLE
var blocked_hits: int = 0
var _timer: float = 0.0
var _attack_cd: float = 1.6
var _pending: String = ""
var _ram_hit: bool = false
var _rotation: int = 0


func _boss_ready() -> void:
	add_to_group(FutureFx.MECHANICAL_GROUP)


func _think(delta: float) -> void:
	_timer -= delta
	match state:
		State.IDLE, State.MOVE:
			_process_move(delta)
		State.TELEGRAPH:
			velocity.x = 0.0
			if _timer <= 0.0:
				_execute(_pending)
		State.CHARGE:
			velocity.x = float(facing) * move_speed * 4.2
			if not _ram_hit and distance_to_target() < 56.0:
				_ram_hit = hurt_player(ram_damage)
			if _timer <= 0.0 or is_on_wall():
				_recover(1.0)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _timer <= 0.0:
				state = State.MOVE
		State.GROGGY:
			velocity.x = 0.0
			if _timer <= 0.0:
				state = State.MOVE
				play_anim(&"idle")


func _process_move(delta: float) -> void:
	face_target()
	var dist: float = distance_to_target()
	velocity.x = move_toward(velocity.x, float(facing) * move_speed if dist > 140.0 else 0.0, 400.0 * delta)
	play_anim(&"walk" if absf(velocity.x) > 5.0 else &"idle")
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		var order: Array[String] = ["ram", "sweep", "cannon", "stomp"]
		if dist < 120.0:
			order = ["stomp", "sweep", "ram", "cannon"]
		start_attack(order[_rotation % order.size()])
		_rotation += 1


func start_attack(attack_name: String) -> void:
	if is_dead:
		return
	_pending = attack_name
	state = State.TELEGRAPH
	_timer = 0.55
	velocity.x = 0.0
	play_anim(&"idle", true)
	_flash(Color(1.6, 1.3, 0.6))


func _execute(attack_name: String) -> void:
	_attack_cd = 1.9
	var player: Node2D = find_player()
	var origin: Vector2 = global_position + Vector2(float(facing) * 34.0, -70.0)
	match attack_name:
		"ram":
			play_anim(&"charge_ram", true)
			_ram_hit = false
			state = State.CHARGE
			_timer = 0.75
			sfx("sfx_hydraulic_stomp")
		"sweep":
			play_anim(&"arm_laser_sweep", true)
			var end: Vector2 = origin + Vector2(float(facing) * 420.0, 40.0)
			FutureAttacks.aim_beam(self, origin, end, 0.25, sweep_damage)
			_recover(0.9)
		"cannon":
			play_anim(&"arm_laser_sweep", true)
			var target: Vector2 = player.global_position + Vector2(0.0, -24.0) if player else origin + Vector2(float(facing) * 300.0, 0.0)
			var dir: Vector2 = (target - origin).normalized()
			FutureAttacks.aim_beam(self, origin, origin + dir * 560.0, 0.55, cannon_damage, Color(0.4, 0.9, 1.0, 1.0), 12.0)
			_recover(1.1)
		"stomp":
			play_anim(&"temporal_stomp", true)
			FutureAttacks.shock_waves(self, Vector2(global_position.x, ground_y), arena_bounds, stomp_damage)
			_recover(1.0)


func _recover(t: float) -> void:
	state = State.RECOVER
	_timer = t


## Zırh kuralı: önden hafif darbeler engellenir; arkadan / dalış / EMP / groggy geçer
func _modify_damage(amount: int, attacker: Variant) -> int:
	if state == State.GROGGY:
		return int(round(float(amount) * 1.4))
	var atk: String = attack_type_of(attacker)
	if OPENER_TYPES.has(atk) or is_hit_from_behind(attacker):
		start_groggy()
		return amount
	if atk == "heavy":
		return int(round(float(amount) * 0.35))
	blocked_hits += 1
	armor_blocked.emit()
	float_text("FUT_FLOAT_ARMOR_BLOCK", Color(0.6, 0.85, 1.0))
	return 0


func start_groggy() -> void:
	if is_dead or state == State.GROGGY:
		return
	state = State.GROGGY
	_timer = GROGGY_TIME
	velocity.x = 0.0
	play_anim(&"groggy", true)
	float_text("FUT_FLOAT_GROGGY", Color(1.0, 0.85, 0.4))
	sfx("energy_tube_break")
	groggy_started.emit()


func emp_stun(_duration: float) -> void:
	start_groggy()


func _on_damaged(_dmg: int, _attacker: Variant) -> void:
	if state != State.GROGGY and state != State.CHARGE:
		play_anim(&"hurt", true)


func _on_death() -> void:
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_EMP, global_position + Vector2(0.0, -60.0), 1.4)
	sfx("sfx_emp_detonate")
