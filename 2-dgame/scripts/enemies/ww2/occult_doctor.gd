class_name OccultDoctor
extends Ww2BossBase

## res://scripts/enemies/ww2/occult_doctor.gd
## Mini-Boss 2a — Okült Başhekim (Epic 2D-144). Enerji tüpleri sağlam kaldıkça okült kalkanı
## tüm hasarı engeller (seviye set_shielded(false) çağırır). Mesafesini korur ve oyuncuya
## telegraph'lı okült küreler fırlatır. Partneri (Başarısız Deney) ölürse öfkelenir.

signal shield_changed(shielded: bool)
signal bolt_cast(target: Vector2)

enum State { MOVE, CAST, RECOVER }

const LIGHT_TEX: Texture2D = preload("res://assets/effects/lighting/light_radial_falloff.png")

@export var bolt_damage: int = 12
@export var bolt_speed: float = 230.0
@export var cast_interval: float = 2.4

var shielded: bool = true
var enraged: bool = false
var state: State = State.MOVE
var _timer: float = 0.0
var _cast_cd: float = 1.5
var _shield_fx: Polygon2D = null


func _boss_ready() -> void:
	_shield_fx = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = float(i) / 24.0 * TAU
		pts.append(Vector2(cos(a) * 38.0, -50.0 + sin(a) * 52.0))
	_shield_fx.polygon = pts
	_shield_fx.color = Color(1.0, 0.25, 0.3, 0.28)
	add_child(_shield_fx)
	var glow: PointLight2D = PointLight2D.new()
	glow.texture = LIGHT_TEX
	glow.color = Color(1.0, 0.3, 0.35)
	glow.energy = 0.7
	glow.position = Vector2(0.0, -50.0)
	add_child(glow)
	set_shielded(shielded)


func set_shielded(value: bool) -> void:
	shielded = value
	if _shield_fx:
		_shield_fx.visible = value
	shield_changed.emit(value)


func set_enraged() -> void:
	enraged = true
	cast_interval *= 0.6
	move_speed *= 1.3


func _think(delta: float) -> void:
	_timer -= delta
	face_target()
	match state:
		State.MOVE:
			var dist: float = distance_to_target()
			var desired: float = 0.0
			if dist < 180.0:
				desired = -float(facing) * move_speed
			elif dist > 360.0:
				desired = float(facing) * move_speed
			velocity.x = move_toward(velocity.x, desired, 400.0 * delta)
			play_anim(&"walk" if absf(velocity.x) > 5.0 else &"idle")
			_cast_cd -= delta
			if _cast_cd <= 0.0:
				state = State.CAST
				_timer = 0.6
				velocity.x = 0.0
				play_anim(&"cast", true)
		State.CAST:
			velocity.x = 0.0
			if _timer <= 0.0:
				cast_bolt()
				state = State.RECOVER
				_timer = 0.6
				_cast_cd = cast_interval
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _timer <= 0.0:
				state = State.MOVE


## Oyuncuya doğru okült küre (duvara veya oyuncuya çarpınca söner)
func cast_bolt() -> Area2D:
	var player: Node2D = find_player()
	var target: Vector2 = player.global_position + Vector2(0.0, -24.0) if player else global_position + Vector2(float(facing) * 200.0, 0.0)
	var origin: Vector2 = global_position + Vector2(float(facing) * 20.0, -60.0)
	var bolt: Area2D = Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	bolt.add_child(shape)
	var orb: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		pts.append(Vector2(cos(float(i) / 10.0 * TAU), sin(float(i) / 10.0 * TAU)) * 8.0)
	orb.polygon = pts
	orb.color = Color(1.0, 0.3, 0.35)
	bolt.add_child(orb)
	get_parent().add_child(bolt)
	bolt.global_position = origin
	var dmg: int = bolt_damage
	bolt.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(dmg, bolt.global_position)
		if b.is_in_group("player") or b is StaticBody2D:
			bolt.queue_free()
	)
	var dir: Vector2 = (target - origin).normalized()
	var tw: Tween = bolt.create_tween()
	tw.tween_property(bolt, "global_position", origin + dir * 800.0, 800.0 / bolt_speed)
	tw.tween_callback(bolt.queue_free)
	sfx("occult_beam", -8.0)
	bolt_cast.emit(target)
	return bolt


func _modify_damage(amount: int, _attacker: Variant) -> int:
	if shielded:
		damage_blocked.emit("shield")
		float_text("WW2_FLOAT_SHIELD", Color(1.0, 0.4, 0.45))
		return 0
	return amount


func _on_death() -> void:
	if _shield_fx:
		_shield_fx.visible = false
