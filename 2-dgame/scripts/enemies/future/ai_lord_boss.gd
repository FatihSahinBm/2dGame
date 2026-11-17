class_name AiLordBoss
extends Ww2BossBase

## res://scripts/enemies/future/ai_lord_boss.gd
## AI Lord (Yapay Zekâ Lordu) — Bölüm 5 ana boss'u, 3 form (Epic 2D-158).
## Form tanımları ai_lord_phases.gd, saldırı tehlikeleri ai_lord_attacks.gd, yankı klonu
## ai_lord_echo.gd içindedir. Form geçişinde boss durur, phase_transition oynar ve sheet değişir;
## seviye taunt diyaloğunu oynatıp on_cinematic_ended() çağırır. Can 0'a inince collapse_death
## (göğüsteki 5. Kalp Parçasının sökülüşü ve kabuğun çöküşü) oynar, ardından boss_defeated yayılır.
## Siber-Ağ Kesintisi tamamlandıysa Form 1 dron çağrısı ve Form 2 taret desteği %50 azalır.

signal form_changed(new_form: int)
signal attack_started(attack_name: String)
signal drones_requested(count: int)
signal turret_support_requested(count: int, active: bool)
signal shield_changed(current: float, maximum: float)
signal echo_spawned(echo: Node2D)
signal boss_defeated()

enum State { IDLE, MOVE, TELEGRAPH, LEAP, RECOVER, GROGGY, TRANSITION, DYING }

const Phases = preload("res://scripts/enemies/future/ai_lord_phases.gd")
const Attacks = preload("res://scripts/enemies/future/ai_lord_attacks.gd")
const FutureAttacks = preload("res://scripts/enemies/future/future_attacks.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export var beam_damage: int = 20
@export var cannon_damage: int = 30
@export var shock_damage: int = 22

var form: int = 1
var state: State = State.IDLE
var shield_poise: float = Phases.SHIELD_MAX
var turn: int = 0
var last_attack: String = ""
var _timer: float = 0.0
var _attack_cd: float = 1.4
var _pending: String = ""


func _boss_ready() -> void:
	add_to_group(FutureFx.MECHANICAL_GROUP)
	_apply_form_visuals()


func _think(delta: float) -> void:
	_timer -= delta
	if hovering:
		velocity.y = (ground_y - Phases.HOVER_HEIGHT - global_position.y) * 4.0
	match state:
		State.IDLE, State.MOVE:
			_process_move(delta)
		State.TELEGRAPH:
			velocity.x = 0.0
			if _timer <= 0.0:
				_execute(_pending)
		State.LEAP:
			if is_on_floor() and _timer <= 0.0:
				FutureAttacks.shock_waves(self, Vector2(global_position.x, ground_y), arena_bounds, shock_damage)
				_recover(1.0)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if _timer <= 0.0:
				state = State.MOVE
		State.GROGGY:
			velocity.x = 0.0
			if _timer <= 0.0:
				shield_poise = Phases.SHIELD_MAX
				shield_changed.emit(shield_poise, Phases.SHIELD_MAX)
				hovering = bool(Phases.get_form(form).get("hover", false))
				state = State.MOVE


func _process_move(delta: float) -> void:
	face_target()
	var dist: float = distance_to_target()
	var desired: float = 0.0
	if dist > 240.0:
		desired = float(facing) * move_speed
	elif dist < 100.0 and form != 2:
		desired = -float(facing) * move_speed * 0.7
	velocity.x = move_toward(velocity.x, desired, 400.0 * delta)
	play_anim(Phases.get_form(form).get("move_anim", &"idle") if absf(velocity.x) > 5.0 else &"idle")
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		start_attack(Phases.choose_attack(form, dist, turn))
		turn += 1


## Telegraph animasyonuyla saldırı hazırlığı; tehlike telegraph'tan sonra gelir
func start_attack(attack_name: String) -> void:
	if is_dead or attack_name.is_empty() or state == State.TRANSITION or state == State.DYING:
		return
	_pending = attack_name
	last_attack = attack_name
	state = State.TELEGRAPH
	_timer = 0.5
	velocity.x = 0.0
	play_anim(Phases.get_form(form).get("telegraph_anim", &"idle"), true)
	sfx("sfx_ai_lord_glitch_voice", -8.0)
	attack_started.emit(attack_name)


func _execute(attack_name: String) -> void:
	var player: Node2D = find_player()
	var ppos: Vector2 = player.global_position if player else global_position
	_attack_cd = float(Phases.get_form(form).get("attack_interval", 1.8))
	match attack_name:
		"lattice":
			play_anim(&"laser_lattice_attack", true)
			Attacks.lattice(self, arena_bounds, ground_y, beam_damage, turn)
			_recover(1.4)
		"drones":
			play_anim(&"drone_summon", true)
			drones_requested.emit(Attacks.drone_count(self))
			_recover(1.0)
		"blink":
			blink_to(Attacks.blink_target(ppos, arena_bounds, turn))
			_recover(0.6)
		"cannon":
			play_anim(&"shoulder_cannon_blast", true)
			Attacks.shoulder_cannon(self, global_position + Vector2(float(facing) * 50.0, -150.0), facing, arena_bounds, cannon_damage)
			_recover(1.3)
		"leap":
			play_anim(&"leap", true)
			face_target()
			velocity = Vector2(clampf(ppos.x - global_position.x, -420.0, 420.0) * 1.4, -560.0)
			state = State.LEAP
			_timer = 0.3
		"turrets":
			play_anim(&"shield_block", true)
			turret_support_requested.emit(Attacks.turret_count(self), true)
			_recover(0.9)
		"freeze":
			play_anim(&"core_overdrive_beam", true)
			Attacks.freeze_field(self, ppos)
			FutureFx.play_vfx(get_parent(), FutureFx.VFX_TIME_FRACTURE, ppos + Vector2(0.0, -60.0), 1.2)
			_recover(0.9)
		"echo":
			play_anim(&"echo_slash_combo", true)
			var echo: Node2D = Attacks.spawn_echo(self, player)
			if echo:
				echo_spawned.emit(echo)
			_recover(1.0)
		"cross":
			play_anim(&"core_overdrive_beam", true)
			Attacks.cross_beams(self, global_position + Vector2(0.0, -120.0), arena_bounds, ground_y, beam_damage)
			_recover(1.4)


func blink_to(x: float) -> void:
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_TELEPORT, global_position + Vector2(0.0, -60.0), 1.0)
	global_position.x = clampf(x, arena_bounds.x + 40.0, arena_bounds.y - 40.0)
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_TELEPORT, global_position + Vector2(0.0, -60.0), 1.0)
	play_anim(&"blink" if form == 1 else &"time_blink", true)
	face_target()


func _recover(t: float) -> void:
	state = State.RECOVER
	_timer = t


# ---------------------------------------------------------------------------
# Hasar, Form 2 enerji kalkanı, form geçişi, ölüm
# ---------------------------------------------------------------------------
func _modify_damage(amount: int, attacker: Variant) -> int:
	if state == State.TRANSITION or state == State.DYING:
		return 0
	if state == State.GROGGY:
		return int(round(float(amount) * Phases.GROGGY_DAMAGE_MULT))
	if form == 2:
		apply_shield_poise(Phases.shield_poise_for(attack_type_of(attacker)))
		if state != State.GROGGY:
			damage_blocked.emit("energy_shield")
			return maxi(1, int(round(float(amount) * Phases.SHIELD_DAMAGE_FACTOR)))
	return amount


## Form 2 enerji kalkanı; savuşturma / ağır saldırı / EMP ile kırılır. Kırıldıysa true.
func apply_shield_poise(amount: float) -> bool:
	if form != 2 or state == State.GROGGY or is_dead:
		return false
	shield_poise = maxf(0.0, shield_poise - amount)
	shield_changed.emit(shield_poise, Phases.SHIELD_MAX)
	if shield_poise > 0.0:
		return false
	enter_groggy(Phases.GROGGY_TIME)
	float_text("FUT_FLOAT_SHIELD_BROKEN", Color(1.0, 0.85, 0.3))
	return true


func on_parried(_duration: float = 0.9) -> void:
	apply_shield_poise(Phases.shield_poise_for("parry"))


func is_parry_immune() -> bool:
	return form != 2


func emp_stun(_duration: float) -> void:
	if form == 2:
		apply_shield_poise(Phases.shield_poise_for("emp"))


func enter_groggy(duration: float) -> void:
	state = State.GROGGY
	_timer = duration
	hovering = false
	velocity = Vector2.ZERO
	turret_support_requested.emit(0, false)
	play_anim(&"groggy" if form == 2 else &"hurt", true)


func _on_damaged(_dmg: int, _attacker: Variant) -> void:
	var new_form: int = Phases.form_for_ratio(float(current_health) / float(max_health))
	if new_form > form:
		_change_form(new_form)
	elif state == State.MOVE or state == State.IDLE:
		play_anim(&"hurt", true)


func _change_form(new_form: int) -> void:
	is_active = false
	state = State.TRANSITION
	velocity = Vector2.ZERO
	turret_support_requested.emit(0, false)
	play_anim(&"phase_transition", true)
	sfx("sfx_ai_lord_glitch_voice", 0.0)
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_TELEPORT, global_position + Vector2(0.0, -80.0), 1.6)
	FutureFx.shake(self, 6.0, 0.4, "ai_lord_transition")
	form = new_form
	shield_poise = Phases.SHIELD_MAX
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void:
		_apply_form_visuals()
		_attack_cd = 1.2
		form_changed.emit(form)
	)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("on_boss_phase_changed"):
		am.on_boss_phase_changed(int(Phases.get_form(form).get("music_phase", form)))


func _apply_form_visuals() -> void:
	var def: Dictionary = Phases.get_form(form)
	move_speed = float(def.get("speed", move_speed))
	hovering = bool(def.get("hover", false))
	var frames: SpriteFrames = Phases.load_frames(form)
	if anim and frames:
		anim.sprite_frames = frames
		anim.position.y = Phases.sprite_offset_y(form, absf(anim.scale.y)) # form sheet'inin FEET_Y çıpası
		play_anim(&"idle", true)


func on_cinematic_ended() -> void:
	if not is_dead and state != State.DYING:
		is_active = true
		if state == State.TRANSITION or state == State.IDLE:
			state = State.MOVE


## Özel ölüm sekansı: çekirdek tekilliği çöker; collapse_death (kalp parçası sökülür)
func _on_death() -> void:
	state = State.DYING
	hovering = false
	turret_support_requested.emit(0, false)
	for echo: Node in get_tree().get_nodes_in_group("ai_lord_echoes"):
		if echo.has_method("dissolve"):
			echo.dissolve()
	play_anim(&"collapse_death", true)
	FutureFx.shake(self, 9.0, 0.9, "ai_lord_death")
	sfx("sfx_ai_lord_glitch_voice", 2.0)
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_SIXTH_CORE, global_position + Vector2(0.0, -90.0), 1.4)
	var tw: Tween = create_tween()
	tw.tween_interval(Phases.DEATH_SEQUENCE_TIME)
	tw.tween_callback(func() -> void: boss_defeated.emit())
