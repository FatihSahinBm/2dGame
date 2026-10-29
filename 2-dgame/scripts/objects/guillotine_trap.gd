class_name GuillotineTrap
extends Node2D

## res://scripts/objects/guillotine_trap.gd
## Story 2D-132: Târgovişte Sarkaç Giyotin Bıçağı (Swinging Guillotine Trap)
##
## Başarı Kriterleri:
## 1. Sarkaç hareket dinamiği (swing_speed, max_angle_deg).
## 2. Hasar bekleme süresi (damage_interval = 0.75s): Tek temasta spam hasarı engeller.
## 3. Savurma yönüne bağlı geri tepme (Knockback).
## 4. Oyuncu ve düşman filtreleme (affects_player, affects_enemies, affects_allies).
## 5. Duraklatma (set_paused) ve yeniden başlatma desteği.

signal target_hit(target: Node2D, damage: int)
signal blade_swung(angle: float)

@export var swing_speed: float = 2.4
@export var max_angle_deg: float = 65.0
@export var damage: int = 25
@export var initial_phase: float = 0.0
@export var damage_interval: float = 0.75 ## Aynı hedefe tekrar hasar verme aralığı
@export var knockback_force: float = 260.0
@export var affects_player: bool = true
@export var affects_enemies: bool = true
@export var affects_allies: bool = false
@export var is_paused: bool = false

var _time_passed: float = 0.0
var _target_cooldowns: Dictionary = {} # target -> float kalan süre
var _last_swing_dir: float = 0.0

# Düğüm Referansları
var arm: Node2D = null
var blade_area: Area2D = null
var blade_node: Node2D = null


func _ready() -> void:
	add_to_group("traps")
	add_to_group("hazards")
	_time_passed = initial_phase

	_setup_internal_nodes()


func _setup_internal_nodes() -> void:
	arm = get_node_or_null("Arm") as Node2D
	if not arm:
		arm = Node2D.new()
		arm.name = "Arm"
		add_child(arm)

	blade_node = arm.get_node_or_null("Blade") as Node2D
	if not blade_node:
		blade_node = Node2D.new()
		blade_node.name = "Blade"
		blade_node.position = Vector2(0, 120)
		arm.add_child(blade_node)

	blade_area = blade_node.get_node_or_null("HitArea") as Area2D
	if not blade_area:
		blade_area = Area2D.new()
		blade_area.name = "HitArea"
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48.0, 64.0)
		col.shape = rect
		col.position = Vector2(0, 10)
		blade_area.add_child(col)
		blade_node.add_child(blade_area)

	# Çarpışma Katmanları
	blade_area.collision_layer = 0
	var mask: int = 0
	if affects_player:
		mask |= 1
	if affects_enemies:
		mask |= 2
	blade_area.collision_mask = mask if mask > 0 else 3

	if not blade_area.body_entered.is_connected(_on_blade_hit):
		blade_area.body_entered.connect(_on_blade_hit)


func _physics_process(delta: float) -> void:
	# 1. Bekleme sürelerini güncelle
	_update_damage_cooldowns(delta)

	if is_paused:
		return

	# 2. Sarkaç Salınım Hareketi
	_time_passed += delta * swing_speed
	var current_angle: float = deg_to_rad(sin(_time_passed) * max_angle_deg)
	if arm:
		arm.rotation = current_angle

	# Savurma yönü değişimi (tepe noktalarından geçiş)
	var swing_dir := signf(cos(_time_passed))
	if swing_dir != _last_swing_dir and absf(current_angle) < deg_to_rad(15.0):
		_last_swing_dir = swing_dir
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("guillotine_swing", -4.0)
		blade_swung.emit(current_angle)

	# 3. Bıçak alanındaki hedefleri kontrol et
	if blade_area:
		for body in blade_area.get_overlapping_bodies():
			_try_damage_target(body)


func _update_damage_cooldowns(delta: float) -> void:
	var keys_to_remove: Array = []
	for body in _target_cooldowns.keys():
		if not is_instance_valid(body):
			keys_to_remove.append(body)
			continue
		var rem: float = _target_cooldowns[body] - delta
		if rem <= 0.0:
			keys_to_remove.append(body)
		else:
			_target_cooldowns[body] = rem

	for k in keys_to_remove:
		_target_cooldowns.erase(k)


func _on_blade_hit(body: Node2D) -> void:
	_try_damage_target(body)


func _try_damage_target(body: Node2D) -> bool:
	if not _is_valid_target(body):
		return false

	if _target_cooldowns.has(body):
		return false

	# Hasar bekleme süresi kaydı (Spam hasarı önler)
	_target_cooldowns[body] = damage_interval

	# Savurma yönüne bağlı itme (Knockback)
	var swing_dir: float = signf(cos(_time_passed))
	if swing_dir == 0.0:
		swing_dir = 1.0
	var knockback_vec := Vector2(swing_dir * knockback_force, -knockback_force * 0.4)

	if "velocity" in body and body is CharacterBody2D:
		body.velocity = knockback_vec

	# Hasar verme
	if body.has_method("take_damage"):
		var takes_attacker: bool = false
		for m in body.get_method_list():
			if m.get("name") == "take_damage" and m.get("args", []).size() >= 2:
				takes_attacker = true
				break
		if takes_attacker:
			body.take_damage(damage, self)
		else:
			body.take_damage(damage)
	elif body.has_method("hit"):
		body.hit(damage)

	target_hit.emit(body, damage)
	return true


func _is_valid_target(body: Node) -> bool:
	if not body or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false

	# Ölü gövdeleri yoksay
	if "is_dead" in body and body.is_dead:
		return false
	if body.get("is_dead") == true:
		return false

	# Sinematik durumundaki oyuncuyu koru
	var gs = get_node_or_null("/root/GameState")
	if gs and "is_in_cinematic" in gs and gs.is_in_cinematic:
		if body.is_in_group("player"):
			return false

	var is_player: bool = body.is_in_group("player") or body.name.to_lower().contains("player")
	var is_enemy: bool = body.is_in_group("enemies") and not is_player
	var is_ally: bool = body.is_in_group("allies")

	if is_player and not affects_player:
		return false
	if is_enemy and not affects_enemies:
		return false
	if is_ally and not affects_allies:
		return false

	return body.has_method("take_damage") or body.has_method("hit")


## Bıçağın hareketini durdurur veya devam ettirir
func set_paused(paused: bool) -> void:
	is_paused = paused
