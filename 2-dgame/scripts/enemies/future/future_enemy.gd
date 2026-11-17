extends "res://scripts/enemies/monster_enemy.gd"

## res://scripts/enemies/future/future_enemy.gd
## Bölüm 5 standart düşmanları (Epic 2D-158): MonsterEnemy yapay zekâsı + türe özgü davranış.
## Hepsi mekaniktir ("mechanical" grubu): EMP El Bombası çift hasar ve sersemletme uygular.
##   shield — Neon Devriye Androidi: önden gelen hafif darbeleri kalkanla keser (arkadan, ağır,
##            dalış, EMP ve plazma geçer).
##   pulse  — Zaman-Bükücü Dron: oyuncunun bulunduğu yere zaman yavaşlatma alanı atar.
##   heavy  — Ağır Hidrolik Yıkıcı: yüksek poise, sendelemez; piston darbesi şok dalgası yayar
##            ve ardından kısa bir buhar (savunmasızlık) penceresi açılır.
##   pounce — Mekanik Tazı: menzile girince oyuncuya doğru sıçrar.

signal shield_blocked()
signal pulse_cast(field: Area2D)

const FutureAttacks = preload("res://scripts/enemies/future/future_attacks.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")
const BREAK_SHIELD: Array[String] = ["heavy", "plunge", "emp", "plasma", "grenade"]

@export_enum("none", "shield", "pulse", "heavy", "pounce") var behavior: String = "none"
@export var pulse_cooldown: float = 6.0
@export var pulse_range: float = 260.0
@export var pounce_range: float = 190.0
@export var steam_window: float = 1.2
@export var arena_bounds: Vector2 = Vector2(-100000.0, 100000.0)

var blocked_hits: int = 0
var _pulse_cd: float = 2.0
var _steam_until: int = 0
var _pouncing: bool = false
var _pounce_cd: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(FutureFx.MECHANICAL_GROUP)
	add_to_group("future_enemies")
	if behavior == "heavy":
		knockback_resistance = 1.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead:
		return
	match behavior:
		"pulse":
			_process_pulse(delta)
		"pounce":
			_process_pounce(delta)


# ---------------------------------------------------------------------------
# Hasar kuralları
# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return
	if behavior == "shield" and _is_frontal_block():
		blocked_hits += 1
		if anim_sprite:
			anim_sprite.play(&"block")
		_flash_block()
		shield_blocked.emit()
		return
	if behavior == "heavy" and Time.get_ticks_msec() < _steam_until:
		amount = int(round(float(amount) * 1.5))
	super.take_damage(amount)
	# Ağır yıkıcı darbelerle sendelemez (buhar penceresi dışında)
	if behavior == "heavy" and not is_dead and current_state == State.HURT and Time.get_ticks_msec() >= _steam_until:
		current_state = State.CHASE if _target_node else State.PATROL


func _is_frontal_block() -> bool:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if player == null:
		return false
	var attack_type: String = str(player.current_attack_type) if "current_attack_type" in player else ""
	if BREAK_SHIELD.has(attack_type) or current_state == State.HURT:
		return false
	var side: int = 1 if player.global_position.x >= global_position.x else -1
	return side == direction


func _flash_block() -> void:
	if anim_sprite:
		anim_sprite.modulate = Color(0.6, 0.9, 1.8)
		create_tween().tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
	FutureFx.sfx(self, "shield_block" if _has_sound("shield_block") else "item_equip", global_position, -6.0)


func _has_sound(key: String) -> bool:
	var am: Node = get_node_or_null("/root/AudioManager")
	return am != null and am.has_method("has_sound") and bool(am.has_sound(key))


## EMP sersemletmesi: HURT durumunda bekletir (kendiliğinden çıkar)
func emp_stun(duration: float) -> void:
	if is_dead:
		return
	current_state = State.HURT
	_hurt_timer = maxf(_hurt_timer, duration)
	_deactivate_hitbox()
	if anim_sprite:
		anim_sprite.play(&"hit")
		anim_sprite.modulate = Color(0.6, 1.4, 2.0)
		create_tween().tween_property(anim_sprite, "modulate", Color.WHITE, duration)


# ---------------------------------------------------------------------------
# Davranışlar
# ---------------------------------------------------------------------------
func _start_attack() -> void:
	super._start_attack()
	if behavior == "heavy" and anim_sprite:
		anim_sprite.play(&"piston_smash")
		get_tree().create_timer(0.45).timeout.connect(_piston_impact)
	elif behavior == "shield" and anim_sprite and anim_sprite.sprite_frames.has_animation(&"slash_combo"):
		anim_sprite.play(&"slash_combo")


func _piston_impact() -> void:
	if is_dead or not is_inside_tree():
		return
	FutureAttacks.shock_waves(self, global_position, Vector2(global_position.x - 260.0, global_position.x + 260.0), 16)
	_steam_until = Time.get_ticks_msec() + int(steam_window * 1000.0)


func _process_pulse(delta: float) -> void:
	_pulse_cd -= delta
	if _pulse_cd > 0.0 or not is_instance_valid(_target_node) or current_state == State.HURT:
		return
	if global_position.distance_to(_target_node.global_position) > pulse_range:
		return
	_pulse_cd = pulse_cooldown
	cast_pulse(_target_node.global_position)


func cast_pulse(at: Vector2) -> Area2D:
	if anim_sprite:
		anim_sprite.play(&"pulse_cast")
	var field: Area2D = FutureAttacks.slow_field(self, at + Vector2(0.0, 4.0), "slow", Vector2(170.0, 130.0), 3.0)
	pulse_cast.emit(field)
	return field


func _process_pounce(delta: float) -> void:
	_pounce_cd -= delta
	if _pouncing:
		if is_on_floor() and velocity.y >= 0.0:
			_pouncing = false
			_deactivate_hitbox()
			current_state = State.HURT
			_hurt_timer = 0.5 # iniş sonrası savunmasızlık
		return
	if _pounce_cd > 0.0 or not is_instance_valid(_target_node) or current_state != State.CHASE or not is_on_floor():
		return
	var dx: float = _target_node.global_position.x - global_position.x
	if absf(dx) > pounce_range or absf(dx) < 50.0:
		return
	pounce(signf(dx))


func pounce(dir: float) -> void:
	_pouncing = true
	_pounce_cd = 2.4
	direction = int(dir)
	_update_facing_direction()
	velocity = Vector2(dir * 340.0, -330.0)
	if anim_sprite:
		anim_sprite.play(&"pounce")
	_activate_hitbox()
