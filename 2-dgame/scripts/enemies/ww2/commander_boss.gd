class_name CommanderBoss
extends Ww2BossBase

## res://scripts/enemies/ww2/commander_boss.gd
## Cani Komutan — Bölüm 4 ana boss'u, 3 form (Epic 2D-144). Form tanımları
## commander_boss_phases.gd, saldırı tehlikeleri commander_boss_attacks.gd içindedir.
## Form geçişinde boss durur, phase_transition oynar ve sheet/aura değişir; seviye taunt
## diyaloğunu oynatıp on_cinematic_ended() çağırır. Can 0'a inince özel ölüm sekansı
## (çekirdek çöküşü) oynar ve ardından boss_defeated yayılır.

signal form_changed(new_form: int)
signal attack_started(attack_name: String)
signal artillery_requested(count: int)
signal turret_support_requested(active: bool)
signal arena_shrink_requested(amount: float)
signal summon_requested(count: int)
signal shield_changed(current: float, maximum: float)
signal boss_defeated()

enum State { IDLE, MOVE, TELEGRAPH, CHARGE, LEAP, RECOVER, GROGGY, TRANSITION, DYING }

const Phases = preload("res://scripts/enemies/ww2/commander_boss_phases.gd")
const Attacks = preload("res://scripts/enemies/ww2/commander_boss_attacks.gd")

@export var bayonet_damage: int = 20
@export var punch_damage: int = 24
@export var radio_shells: int = 4
@export var death_sequence_time: float = 1.8

var form: int = 1
var state: State = State.IDLE
var shield_poise: float = Phases.SHIELD_MAX
var alive_minions: int = 0
var _timer: float = 0.0
var _attack_cd: float = 1.4
var _since_special: float = 0.0
var _pending: String = ""
var _melee_hit: bool = false

@onready var aura: AnimatedSprite2D = get_node_or_null("Visual/Aura") as AnimatedSprite2D


func _boss_ready() -> void:
	_apply_form_visuals()


func _think(delta: float) -> void:
	_timer -= delta
	_since_special += delta
	if hovering:
		var target_y: float = ground_y - Phases.HOVER_HEIGHT
		velocity.y = (target_y - global_position.y) * 4.0
	match state:
		State.IDLE, State.MOVE:
			_process_move(delta)
		State.TELEGRAPH:
			velocity.x = 0.0
			if _timer <= 0.0:
				_execute(_pending)
		State.CHARGE:
			velocity.x = float(facing) * move_speed * 4.0
			_check_melee(bayonet_damage, 60.0)
			if _timer <= 0.0:
				_recover(0.9)
		State.LEAP:
			if is_on_floor() and _timer <= 0.0:
				Attacks.shock_waves(get_parent(), Vector2(global_position.x, ground_y), arena_bounds)
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
	if dist > 260.0:
		desired = float(facing) * move_speed
	elif dist < 110.0 and form != 2:
		desired = -float(facing) * move_speed * 0.7
	velocity.x = move_toward(velocity.x, desired, 400.0 * delta)
	play_anim(&"move" if absf(velocity.x) > 5.0 else &"idle")
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		start_attack(Attacks.choose_attack(form, dist, alive_minions, _since_special))


## Telegraph animasyonuyla saldırı hazırlığı; hasar telegraph'tan sonra gelir
func start_attack(attack_name: String) -> void:
	if is_dead or state == State.TRANSITION:
		return
	_pending = attack_name
	state = State.TELEGRAPH
	_timer = 0.35 if attack_name in ["punch", "bayonet"] else 0.6
	velocity.x = 0.0
	play_anim(&"telegraph", true)
	attack_started.emit(attack_name)


func _execute(attack_name: String) -> void:
	var player: Node2D = find_player()
	var px: Vector2 = player.global_position if player else global_position
	var host: Node = get_parent() if get_parent() else self
	_attack_cd = float(Phases.get_form(form).get("attack_interval", 1.8))
	match attack_name:
		"sniper":
			play_anim(&"attack_1", true)
			Attacks.sniper_shot(host, global_position + Vector2(float(facing) * 40.0, -90.0), px + Vector2(0.0, -24.0))
			_recover(Attacks.SNIPER_TELEGRAPH + 0.5)
		"bayonet":
			play_anim(&"attack_2", true)
			_melee_hit = false
			state = State.CHARGE
			_timer = 0.45
		"radio":
			play_anim(&"attack_3", true)
			sfx("radio_static")
			_since_special = 0.0
			artillery_requested.emit(radio_shells)
			_recover(1.0)
		"leap":
			play_anim(&"attack_1", true)
			state = State.LEAP
			_timer = 0.25
			velocity = Vector2(clampf((px.x - global_position.x) * 1.6, -520.0, 520.0), -520.0)
		"punch":
			play_anim(&"attack_2", true)
			_melee_hit = false
			_check_melee(punch_damage, 80.0)
			_recover(0.8)
		"turrets":
			play_anim(&"attack_3", true)
			_since_special = 0.0
			turret_support_requested.emit(true)
			_recover(0.9)
		"beams":
			play_anim(&"attack_1", true)
			Attacks.occult_beams(host, global_position + Vector2(0.0, -70.0), arena_bounds, ground_y)
			_recover(Attacks.BEAM_TELEGRAPH + Attacks.BEAM_ACTIVE)
		"shrink":
			play_anim(&"attack_2", true)
			arena_shrink_requested.emit(60.0)
			_recover(0.8)
		"summon":
			play_anim(&"attack_3", true)
			_since_special = 0.0
			summon_requested.emit(2)
			_recover(1.0)


func _recover(duration: float) -> void:
	state = State.RECOVER
	_timer = duration


func _check_melee(damage: int, reach: float) -> void:
	if _melee_hit:
		return
	var player: Node2D = find_player()
	if player == null:
		return
	var dx: float = (player.global_position.x - global_position.x) * float(facing)
	if dx > -10.0 and dx < reach and absf(player.global_position.y - global_position.y) < 80.0:
		_melee_hit = hurt_player(damage)


# ---------------------------------------------------------------------------
# Hasar, duruş kalkanı (Form 2), sütun sersemletmesi (Form 3), form geçişi
# ---------------------------------------------------------------------------
func _modify_damage(amount: int, attacker: Variant) -> int:
	if state == State.TRANSITION or state == State.DYING:
		return 0
	if state == State.GROGGY:
		return int(round(float(amount) * Phases.GROGGY_DAMAGE_MULT))
	if form == 2:
		apply_shield_poise(Phases.shield_poise_for(attack_type_of(attacker)))
		if state != State.GROGGY:
			damage_blocked.emit("poise_shield")
			return maxi(1, int(round(float(amount) * Phases.SHIELD_DAMAGE_FACTOR)))
	return amount


## Form 2 duruş kalkanı; kırılınca groggy penceresi. Kırıldıysa true.
func apply_shield_poise(amount: float) -> bool:
	if form != 2 or state == State.GROGGY or is_dead:
		return false
	shield_poise = maxf(0.0, shield_poise - amount)
	shield_changed.emit(shield_poise, Phases.SHIELD_MAX)
	if shield_poise > 0.0:
		return false
	enter_groggy(Phases.GROGGY_TIME)
	float_text("WW2_FLOAT_POISE_BROKEN", Color(1.0, 0.85, 0.3))
	return true


## Savuşturma (ParryResolver) Form 2 kalkanını kırar; diğer formlarda bağışık
func on_parried(_duration: float = 0.9) -> void:
	apply_shield_poise(Phases.shield_poise_for("parry"))


func is_parry_immune() -> bool:
	return form != 2


## Form 3'te enerji sütunu kırılınca boss yere çakılır ve sersemler
func on_pillar_broken() -> void:
	if form == 3 and not is_dead and state != State.TRANSITION:
		enter_groggy(3.0)


func enter_groggy(duration: float) -> void:
	state = State.GROGGY
	_timer = duration
	hovering = false
	velocity = Vector2.ZERO
	play_anim(&"groggy", true)


func _on_damaged(_dmg: int, _attacker: Variant) -> void:
	var new_form: int = Phases.form_for_ratio(float(current_health) / float(max_health))
	if new_form > form:
		_change_form(new_form)


func _change_form(new_form: int) -> void:
	form = new_form
	is_active = false
	state = State.TRANSITION
	velocity = Vector2.ZERO
	shield_poise = Phases.SHIELD_MAX
	turret_support_requested.emit(false)
	play_anim(&"phase_transition", true)
	sfx("shock_wave")
	var tw: Tween = create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		_apply_form_visuals()
		state = State.MOVE
		_attack_cd = 1.2
		_since_special = 0.0
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
		play_anim(&"idle", true)
	if aura and aura.sprite_frames and aura.sprite_frames.has_animation(def.get("aura", &"smoke")):
		aura.play(def.get("aura", &"smoke"))


func on_cinematic_ended() -> void:
	if not is_dead and state != State.DYING:
		is_active = true
		if state == State.TRANSITION or state == State.IDLE:
			state = State.MOVE


func set_alive_minions(count: int) -> void:
	alive_minions = count


## Özel ölüm sekansı: çekirdek çöküşü (beyaz flaş + sarsıntı), ardından boss_defeated
func _on_death() -> void:
	state = State.DYING
	hovering = false
	turret_support_requested.emit(false)
	var cam: Node = get_node_or_null("/root/CameraManager")
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(9.0, 2, 0.8, 25.0, "ww2_commander_death")
	sfx("artillery_blast", 0.0)
	if aura:
		aura.play(&"core")
		var tw_aura: Tween = create_tween()
		tw_aura.tween_property(aura, "scale", Vector2(2.4, 2.4), death_sequence_time * 0.6)
		tw_aura.tween_property(aura, "modulate:a", 0.0, death_sequence_time * 0.4)
	var tw: Tween = create_tween()
	tw.tween_interval(death_sequence_time)
	tw.tween_callback(func() -> void: boss_defeated.emit())
