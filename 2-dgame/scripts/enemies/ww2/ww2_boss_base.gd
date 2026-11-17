class_name Ww2BossBase
extends CharacterBody2D

## res://scripts/enemies/ww2/ww2_boss_base.gd
## Bölüm 4 boss / mini-boss ortak tabanı (Epic 2D-144): can, hasar boru hattı, Codex kaydı,
## yüzleşme, animasyon ve ölüm. Alt sınıflar _think() (yapay zekâ), _modify_damage()
## (zırh/kalkan/sırt kuralı), _on_damaged() ve _on_death() kancalarını yazar.
## Sinematik/diyalog sırasında is_active false'tur; seviye on_cinematic_ended() çağırır.

signal health_changed(current_hp: int, max_hp: int)
signal damage_blocked(reason: String)
signal defeated()

@export var max_health: int = 400
@export var codex_id: String = ""
@export var boss_group: String = "mini_boss"
@export var move_speed: float = 60.0
@export var gravity: float = 1200.0
@export var arena_bounds: Vector2 = Vector2(0.0, 1600.0)
@export var ground_y: float = 560.0

var current_health: int = 400
var is_dead: bool = false
var is_active: bool = false
var hovering: bool = false
var facing: int = -1
var _target: Node2D = null

@onready var anim: AnimatedSprite2D = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
@onready var visual: Node2D = get_node_or_null("Visual") as Node2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	add_to_group(boss_group)
	current_health = max_health
	_boss_ready()
	play_anim(&"idle")


## Alt sınıf kurulum kancası
func _boss_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not hovering and not is_on_floor():
		velocity.y += gravity * delta
	if is_dead or not is_active:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if hovering:
			velocity.y = move_toward(velocity.y, 0.0, 600.0 * delta)
		move_and_slide()
		return
	_target = find_player()
	_think(delta)
	global_position.x = clampf(global_position.x, arena_bounds.x + 30.0, arena_bounds.y - 30.0)
	move_and_slide()


## Alt sınıf yapay zekâ kancası (her fizik karesi, yalnızca aktifken)
func _think(_delta: float) -> void:
	pass


func take_damage(amount: int, attacker: Variant = null) -> void:
	if is_dead:
		return
	var dmg: int = _modify_damage(maxi(1, amount), attacker)
	if dmg <= 0:
		_flash(Color(0.6, 0.8, 1.6))
		return
	current_health = clampi(current_health - dmg, 0, max_health)
	health_changed.emit(current_health, max_health)
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("record_encounter") and not codex_id.is_empty():
		codex.record_encounter(codex_id)
	_flash(Color(2.2, 1.3, 1.1))
	if current_health <= 0:
		die()
		return
	_on_damaged(dmg, attacker)


## Zırh / kalkan kuralı: verilecek gerçek hasarı döndürür (0 = engellendi)
func _modify_damage(amount: int, _attacker: Variant) -> int:
	return amount


func _on_damaged(_dmg: int, _attacker: Variant) -> void:
	pass


func _on_death() -> void:
	pass


func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_active = false
	velocity = Vector2.ZERO
	set_collision_layer_value(2, false)
	remove_from_group("damageable")
	play_anim(&"death", true)
	var codex: Node = get_node_or_null("/root/CodexManager")
	if codex and codex.has_method("record_kill") and not codex_id.is_empty():
		codex.record_kill(codex_id)
	_on_death()
	defeated.emit()


func on_cinematic_ended() -> void:
	if not is_dead:
		is_active = true


## Saldıranın saldırı türü ("light", "heavy", "plunge", "grenade"...). Bilinmiyorsa oyuncudan okunur.
func attack_type_of(attacker: Variant) -> String:
	if attacker is Object and is_instance_valid(attacker) and "current_attack_type" in attacker:
		return str(attacker.current_attack_type)
	var player: Node = find_player()
	if player and "current_attack_type" in player:
		return str(player.current_attack_type)
	return ""


## Darbe boss'un arkasından mı geldi (yüzü dönük olduğu tarafın tersi)
func is_hit_from_behind(attacker: Variant) -> bool:
	var src: Vector2 = Vector2.INF
	if attacker is Node2D and is_instance_valid(attacker):
		src = (attacker as Node2D).global_position
	elif attacker is Vector2:
		src = attacker
	else:
		var player: Node2D = find_player()
		if player:
			src = player.global_position
	if src == Vector2.INF:
		return false
	var side: int = 1 if src.x >= global_position.x else -1
	return side != facing


func face_target() -> void:
	if not is_instance_valid(_target):
		return
	facing = 1 if _target.global_position.x >= global_position.x else -1
	if visual:
		visual.scale.x = absf(visual.scale.x) * float(facing)


func distance_to_target() -> float:
	return absf(_target.global_position.x - global_position.x) if is_instance_valid(_target) else INF


func play_anim(base: StringName, force: bool = false) -> void:
	if not anim or not anim.sprite_frames or not anim.sprite_frames.has_animation(base):
		return
	if force or anim.animation != base or not anim.is_playing():
		anim.play(base)


func find_player() -> Node2D:
	if is_instance_valid(_target):
		return _target
	return get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null


func sfx(key: String, volume_db: float = -2.0) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d(key, global_position, null, volume_db, 1400.0)


func float_text(text_key: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = tr(text_key)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 11)
	label.z_index = 50
	add_child(label)
	label.position = Vector2(-40.0, -130.0)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "position:y", -160.0, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tw.tween_callback(label.queue_free)


func _flash(color: Color) -> void:
	if anim:
		anim.modulate = color
		create_tween().tween_property(anim, "modulate", Color.WHITE, 0.15)


## Oyuncuya bir kez hasar uygular (dokunulmazlık kuralları oyuncudadır)
func hurt_player(amount: int) -> bool:
	var player: Node2D = find_player()
	if player and player.has_method("take_damage"):
		player.take_damage(amount, global_position)
		return true
	return false
