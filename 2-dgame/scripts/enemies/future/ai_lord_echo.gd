class_name AiLordEcho
extends CharacterBody2D

## res://scripts/enemies/future/ai_lord_echo.gd
## AI Lord Form 3 "dijital yankı" klonu (Epic 2D-158). Oyuncunun konumunu, yönünü, animasyonunu
## ve saldırı anlarını kaydeder; aynı hareketi `delay` saniye gecikmeyle yarı saydam bir
## glitch kopyası olarak tekrarlar. Kayıttaki an bir saldırıysa ve yankı oyuncuya yakınsa
## enerji hasarı verir. Kırılgandır (az can) ve `lifetime` sonunda dağılır.

signal echo_struck(damage: int)

const FutureInventory = preload("res://scripts/components/future_inventory.gd")
const FutureFx = preload("res://scripts/effects/future_fx.gd")

@export var delay: float = 0.8
@export var lifetime: float = 6.0
@export var damage: int = 14
@export var max_health: int = 40

var current_health: int = 40
var is_dead: bool = false
var player: Node2D = null
var _samples: Array[Dictionary] = []
var _t: float = 0.0
var _hit_cd: float = 0.0
var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	add_to_group("ai_lord_echoes")
	collision_layer = 2
	collision_mask = 0
	current_health = max_health
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(22.0, 40.0)
	cs.shape = rect
	cs.position = Vector2(0.0, -20.0)
	add_child(cs)
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Node2D
	_sprite = AnimatedSprite2D.new()
	_sprite.modulate = Color(0.4, 0.9, 1.6, 0.6)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var src: AnimatedSprite2D = player.get("anim_sprite") as AnimatedSprite2D if player and "anim_sprite" in player else null
	if src:
		_sprite.sprite_frames = src.sprite_frames
		_sprite.position = src.position + (src.get_parent() as Node2D).position if src.get_parent() is Node2D else src.position
	add_child(_sprite)
	(func() -> void: FutureFx.play_vfx(get_parent(), FutureFx.VFX_TELEPORT, global_position, 0.5)).call_deferred()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_t += delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if is_instance_valid(player):
		_samples.append(_record(player))
	var replay_index: int = _samples.size() - 1 - int(delay * Engine.physics_ticks_per_second)
	if replay_index >= 0:
		_apply(_samples[replay_index])
		if _samples.size() > 600:
			_samples = _samples.slice(_samples.size() - 300)
	_sprite.modulate.a = 0.45 + 0.2 * sin(_t * 22.0)
	if _t >= lifetime:
		dissolve()


func _record(p: Node2D) -> Dictionary:
	var src: AnimatedSprite2D = p.get("anim_sprite") as AnimatedSprite2D if "anim_sprite" in p else null
	return {
		"pos": p.global_position,
		"anim": src.animation if src else &"",
		"flip": src.flip_h if src else false,
		"attack": str(p.current_attack_type) if "current_attack_type" in p else "",
	}


func _apply(sample: Dictionary) -> void:
	global_position = sample["pos"]
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(sample["anim"]):
		if _sprite.animation != sample["anim"]:
			_sprite.play(sample["anim"])
	_sprite.flip_h = bool(sample["flip"])
	if not str(sample["attack"]).is_empty() and _hit_cd <= 0.0 and is_instance_valid(player):
		if player.global_position.distance_to(global_position) < 46.0:
			if FutureInventory.apply_energy_damage(player, damage, global_position):
				_hit_cd = 0.7
				echo_struck.emit(damage)


func take_damage(amount: int, _attacker: Variant = null) -> void:
	if is_dead:
		return
	current_health -= maxi(1, amount)
	if current_health <= 0:
		dissolve()


func dissolve() -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("damageable")
	FutureFx.play_vfx(get_parent(), FutureFx.VFX_TELEPORT, global_position, 0.5)
	var tw: Tween = create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
