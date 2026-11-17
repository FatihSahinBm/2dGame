class_name TrenchOfficer
extends Ww2BossBase

## res://scripts/enemies/ww2/trench_officer.gd
## Mini-Boss 1 — Alev Makineli Ağır Siper Subayı (Epic 2D-144).
## - Yüksek duruşlu ön zırh: önden gelen vuruşlar yalnızca %15 hasar verir (armor_blocked).
## - Alev konisi süpürmesi: telegraph (0.8 sn) → 1.6 sn süpürme, önündeki alanda tık hasarı.
## - Sırt tankı: arkadan vuruş, dalış saldırısı (plunge) veya el bombası tankı yıpratır;
##   tank patlayınca groggy (savunmasız) pencere açılır ve tüm hasar katlanır.

signal tank_burst()
signal armor_blocked()

enum State { MOVE, TELEGRAPH, FLAME, RECOVER, GROGGY }

const FLAME_TEX: Texture2D = preload("res://assets/effects/ww2/flame_particle.png")

@export var armor_front_factor: float = 0.15
@export var tank_max_hp: int = 70
@export var groggy_time: float = 4.0
@export var groggy_damage_mult: float = 1.6
@export var flame_damage: int = 8
@export var flame_range: float = 170.0
@export var attack_interval: float = 2.6

var state: State = State.MOVE
var tank_hp: int = 70
var blocked_hits: int = 0
var _timer: float = 0.0
var _attack_cd: float = 1.5
var _tick: float = 0.0
var _flame: CPUParticles2D = null


func _boss_ready() -> void:
	tank_hp = tank_max_hp
	_flame = CPUParticles2D.new()
	_flame.texture = FLAME_TEX
	_flame.amount = 48
	_flame.lifetime = 0.5
	_flame.emitting = false
	_flame.direction = Vector2.RIGHT
	_flame.spread = 18.0
	_flame.initial_velocity_min = 260.0
	_flame.initial_velocity_max = 330.0
	_flame.scale_amount_min = 1.5
	_flame.scale_amount_max = 3.0
	_flame.position = Vector2(34.0, -46.0)
	if visual:
		visual.add_child(_flame)


func _think(delta: float) -> void:
	_timer -= delta
	match state:
		State.MOVE:
			face_target()
			var dist: float = distance_to_target()
			var desired: float = float(facing) * move_speed if dist > 120.0 else 0.0
			velocity.x = move_toward(velocity.x, desired, 400.0 * delta)
			play_anim(&"walk" if absf(velocity.x) > 5.0 else &"idle")
			_attack_cd -= delta
			if _attack_cd <= 0.0 and dist < 260.0:
				_begin_telegraph()
		State.TELEGRAPH:
			velocity.x = 0.0
			if _timer <= 0.0:
				_begin_flame()
		State.FLAME:
			velocity.x = 0.0
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.3
				if is_target_in_flame():
					hurt_player(flame_damage)
			if _timer <= 0.0:
				_end_flame(State.RECOVER, 0.9)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _timer <= 0.0:
				state = State.MOVE
		State.GROGGY:
			velocity.x = 0.0
			if _timer <= 0.0:
				tank_hp = tank_max_hp
				state = State.MOVE
				_attack_cd = 1.2


func _begin_telegraph() -> void:
	state = State.TELEGRAPH
	_timer = 0.8
	play_anim(&"telegraph", true)


func _begin_flame() -> void:
	state = State.FLAME
	_timer = 1.6
	_tick = 0.0
	play_anim(&"flame_sweep", true)
	if _flame:
		_flame.emitting = true
	sfx("flamethrower_burst")


func _end_flame(next: State, duration: float) -> void:
	state = next
	_timer = duration
	_attack_cd = attack_interval
	if _flame:
		_flame.emitting = false


## Oyuncu alev konisinin içinde mi (önde, menzil içinde, dikeyde yakın)
func is_target_in_flame() -> bool:
	var player: Node2D = find_player()
	if player == null:
		return false
	var dx: float = (player.global_position.x - global_position.x) * float(facing)
	return dx > 0.0 and dx <= flame_range and absf(player.global_position.y - global_position.y) < 70.0


func is_groggy() -> bool:
	return state == State.GROGGY


func _modify_damage(amount: int, attacker: Variant) -> int:
	if state == State.GROGGY:
		return int(round(float(amount) * groggy_damage_mult))
	var kind: String = attack_type_of(attacker)
	if kind == "plunge" or kind == "grenade" or is_hit_from_behind(attacker):
		damage_tank(amount)
		return maxi(1, int(round(float(amount) * 0.5)))
	blocked_hits += 1
	armor_blocked.emit()
	damage_blocked.emit("armor")
	if blocked_hits % 3 == 1:
		float_text("WW2_FLOAT_ARMOR", Color(0.7, 0.8, 1.0))
	return maxi(1, int(round(float(amount) * armor_front_factor)))


## Sırt tankına hasar; tank patlarsa groggy penceresi açılır
func damage_tank(amount: int) -> bool:
	if state == State.GROGGY or is_dead:
		return false
	tank_hp = maxi(0, tank_hp - amount)
	if tank_hp > 0:
		return false
	_end_flame(State.GROGGY, groggy_time)
	play_anim(&"groggy", true)
	sfx("grenade_blast")
	float_text("WW2_FLOAT_TANK_BURST", Color(1.0, 0.6, 0.2))
	tank_burst.emit()
	return true


func _on_death() -> void:
	if _flame:
		_flame.emitting = false
