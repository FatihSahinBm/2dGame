class_name PharaohBoss
extends CharacterBody2D

## res://scripts/enemies/egypt/pharaoh_boss.gd
## Lanetli Firavun Kral — Bölüm 3 boss'u (Epic 2D-143).
## 1. faz: telegraph'lı güneş ışınları + asa darbesi.
## 2. faz (%66): çoklu ışın + kum tuzakları.
## 3. faz (%33): altın maske çatlar (enraged animasyonlar), dirilen mumya ordusu çağrılır.
## Her ışın sonrası kısa bir toparlanma penceresi oyuncuya saldırı fırsatı verir.
## Faz geçişlerinde boss durur; seviye taunt diyaloğunu oynatıp on_cinematic_ended() çağırır.

signal health_changed(current_hp: int, max_hp: int)
signal phase_changed(new_phase: int)
signal summon_requested(count: int)
signal attack_started(attack_name: String)
signal boss_defeated()

enum State { IDLE, MOVE, CAST, RECOVER, HURT, DEAD }

const Attacks = preload("res://scripts/enemies/egypt/pharaoh_attacks.gd")
const PHASE_2_RATIO: float = 0.66
const PHASE_3_RATIO: float = 0.33

@export var max_health: int = 900
@export var move_speed: float = 70.0
@export var staff_damage: int = 20
@export var attack_interval: float = 1.6
@export var recover_time: float = 1.1
@export var gravity: float = 1200.0
@export var arena_bounds: Vector2 = Vector2(0.0, 1600.0) # x min, x max
@export var ground_y: float = 560.0

var current_health: int = 900
var phase: int = 1
var state: State = State.IDLE
var is_active: bool = false
var is_dead: bool = false
var facing: int = -1
var alive_minions: int = 0
var _state_timer: float = 0.0
var _attack_cd: float = 1.0
var _since_summon: float = 99.0
var _pending_attack: String = ""
var _target: Node2D = null

@onready var anim: AnimatedSprite2D = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
@onready var staff_hitbox: Area2D = get_node_or_null("Visual/StaffHitbox") as Area2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	add_to_group("boss")
	current_health = max_health
	if staff_hitbox:
		staff_hitbox.monitoring = false
		staff_hitbox.body_entered.connect(_on_staff_hit)
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if is_dead or not is_active:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return
	_target = _find_player()
	_since_summon += delta
	_state_timer -= delta
	match state:
		State.IDLE, State.MOVE:
			_process_move(delta)
		State.CAST:
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_execute_attack(_pending_attack)
		State.RECOVER, State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _state_timer <= 0.0:
				state = State.MOVE
	global_position.x = clampf(global_position.x, arena_bounds.x + 30.0, arena_bounds.y - 30.0)
	move_and_slide()


func _process_move(delta: float) -> void:
	if not is_instance_valid(_target):
		velocity.x = 0.0
		_play_anim("idle")
		return
	var dx: float = _target.global_position.x - global_position.x
	facing = 1 if dx >= 0.0 else -1
	if anim:
		anim.flip_h = facing < 0
	# Firavun orta mesafeyi korur: çok yakınsa geri çekilir, uzaksa yaklaşır
	var dist: float = absf(dx)
	var desired: float = 0.0
	if dist > 320.0:
		desired = float(facing) * move_speed
	elif dist < 140.0 and dist > 70.0:
		desired = -float(facing) * move_speed * 0.8
	velocity.x = move_toward(velocity.x, desired, 400.0 * delta)
	_play_anim("walk" if absf(velocity.x) > 5.0 else "idle")
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		start_attack(Attacks.choose_attack(phase, dist, alive_minions, _since_summon))


## Saldırıyı hazırlık (cast) animasyonuyla başlatır; hasar telegraph'tan sonra gelir
func start_attack(attack_name: String) -> void:
	if is_dead:
		return
	_pending_attack = attack_name
	state = State.CAST
	_state_timer = 0.35 if attack_name == "staff" else 0.55
	velocity.x = 0.0
	_play_anim("summon" if attack_name == "summon" else "cast")
	attack_started.emit(attack_name)


func _execute_attack(attack_name: String) -> void:
	var px: float = _target.global_position.x if is_instance_valid(_target) else global_position.x
	var host: Node = get_parent() if get_parent() else self
	match attack_name:
		"beam":
			_play_anim("beam")
			Attacks.cast_sun_beams(host, Attacks.beam_targets(phase, px, arena_bounds), ground_y, phase)
		"sand":
			Attacks.spawn_sand_traps(host, px, ground_y, 2 + phase - 1, arena_bounds)
		"summon":
			_since_summon = 0.0
			summon_requested.emit(2 if phase < 3 else 3)
		"staff":
			_swing_staff()
	state = State.RECOVER
	_state_timer = recover_time if attack_name == "beam" else recover_time * 0.6
	_attack_cd = attack_interval * (1.0 - 0.15 * float(phase - 1))


func _swing_staff() -> void:
	if not staff_hitbox:
		return
	staff_hitbox.position.x = absf(staff_hitbox.position.x) * float(facing)
	staff_hitbox.monitoring = true
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(staff_hitbox):
			staff_hitbox.set_deferred("monitoring", false)
	)


func _on_staff_hit(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(staff_damage, global_position)


func take_damage(amount: int, _attacker: Variant = null) -> void:
	if is_dead:
		return
	current_health = clampi(current_health - maxi(1, amount), 0, max_health)
	health_changed.emit(current_health, max_health)
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("record_encounter"):
		codex.record_encounter("pharaoh_king")
	if anim:
		anim.modulate = Color(2.2, 1.4, 0.8)
		create_tween().tween_property(anim, "modulate", Color.WHITE, 0.15)
	if current_health <= 0:
		_die()
		return
	_check_phase()


func _check_phase() -> void:
	var ratio: float = float(current_health) / float(max_health)
	var new_phase: int = 3 if ratio <= PHASE_3_RATIO else (2 if ratio <= PHASE_2_RATIO else 1)
	if new_phase <= phase:
		return
	phase = new_phase
	# Faz geçişi: seviye taunt diyaloğunu oynatana kadar boss durur
	is_active = false
	state = State.HURT
	_state_timer = 0.6
	_attack_cd = 1.2
	_play_anim("hurt")
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("on_boss_phase_changed"):
		am.on_boss_phase_changed(phase)
	phase_changed.emit(phase)


func _die() -> void:
	is_dead = true
	is_active = false
	state = State.DEAD
	velocity = Vector2.ZERO
	if staff_hitbox:
		staff_hitbox.set_deferred("monitoring", false)
	set_collision_layer_value(2, false)
	remove_from_group("damageable")
	_play_anim("death", true)
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("record_kill"):
		codex.record_kill("pharaoh_king")
	boss_defeated.emit()


## Sinematik/diyalog bitti: savaş (yeniden) başlar
func on_cinematic_ended() -> void:
	if not is_dead:
		is_active = true
		state = State.MOVE


func set_alive_minions(count: int) -> void:
	alive_minions = count


func reset_boss() -> void:
	current_health = max_health
	phase = 1
	is_dead = false
	is_active = false
	state = State.IDLE
	_since_summon = 99.0
	set_collision_layer_value(2, true)
	add_to_group("damageable")
	_play_anim("idle")
	health_changed.emit(current_health, max_health)


## 3. fazda maske çatlak: "_enraged" animasyon setine geçilir
func _play_anim(base: String, force: bool = false) -> void:
	if not anim or not anim.sprite_frames:
		return
	var name_enraged: String = base + "_enraged"
	var target: String = name_enraged if phase >= 3 and anim.sprite_frames.has_animation(name_enraged) else base
	if anim.sprite_frames.has_animation(target) and (force or anim.animation != StringName(target)):
		anim.play(StringName(target))


func _find_player() -> Node2D:
	if is_instance_valid(_target):
		return _target
	return get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
