class_name BunkerTurret
extends StaticBody2D

## res://scripts/objects/ww2/bunker_turret.gd
## Sığınak tareti (Epic 2D-144): Komutan Form 2'de "taret desteği" çağırınca etkinleşir
## ve oyuncuya kısa seri mermi atar (her mermi önceden nişan parlamasıyla telegraph'lanır).
## Vurularak susturulabilir (damageable); susturulan taret o savaşta yeniden açılmaz.

signal destroyed(turret: BunkerTurret)
signal fired(at: Vector2)

const TEX: Texture2D = preload("res://assets/objects/ww2/bunker_turret.png")
const BULLET_SPEED: float = 420.0

@export var max_health: int = 80
@export var fire_interval: float = 1.8
@export var bullet_damage: int = 9
@export var active: bool = false

var current_health: int = 80
var is_destroyed: bool = false
var _cd: float = 1.0
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("ww2_turrets")
	collision_layer = 4
	collision_mask = 0
	current_health = max_health
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0.0, -32.0)
	add_child(_sprite)
	if get_node_or_null("CollisionShape2D") == null:
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(60.0, 40.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -20.0)
		add_child(shape)
	set_active(active)


func set_active(value: bool) -> void:
	active = value and not is_destroyed
	_cd = 1.0
	if _sprite:
		_sprite.modulate = Color(1.2, 0.9, 0.9) if active else Color(0.7, 0.7, 0.75)


func _process(delta: float) -> void:
	if not active:
		return
	_cd -= delta
	if _cd <= 0.0:
		_cd = fire_interval
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player:
			fire_at(player.global_position + Vector2(0.0, -24.0))


func fire_at(target: Vector2) -> Node2D:
	var muzzle: Vector2 = global_position + Vector2(0.0, -30.0)
	var bullet: Area2D = Area2D.new()
	bullet.collision_layer = 0
	bullet.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	bullet.add_child(shape)
	var dot: Polygon2D = Polygon2D.new()
	dot.polygon = PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(5, 2), Vector2(-5, 2)])
	dot.color = Color(1.0, 0.85, 0.4)
	bullet.add_child(dot)
	var dir: Vector2 = (target - muzzle).normalized()
	bullet.rotation = dir.angle()
	get_parent().add_child(bullet)
	bullet.global_position = muzzle
	var damage: int = bullet_damage
	bullet.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(damage, bullet.global_position)
		if b.is_in_group("player") or b is StaticBody2D or b is TileMapLayer:
			bullet.queue_free()
	)
	var tw: Tween = bullet.create_tween()
	tw.tween_property(bullet, "global_position", muzzle + dir * 900.0, 900.0 / BULLET_SPEED)
	tw.tween_callback(bullet.queue_free)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("turret_fire", global_position, null, -6.0, 1200.0)
	fired.emit(target)
	return bullet


func take_damage(amount: int, _source: Variant = null) -> void:
	if is_destroyed:
		return
	current_health = maxi(0, current_health - maxi(1, amount))
	if _sprite:
		_sprite.modulate = Color(2.0, 1.2, 1.2)
		create_tween().tween_property(_sprite, "modulate", Color(1.2, 0.9, 0.9) if active else Color(0.7, 0.7, 0.75), 0.15)
	if current_health <= 0:
		is_destroyed = true
		set_active(false)
		remove_from_group("damageable")
		if _sprite:
			_sprite.modulate = Color(0.3, 0.3, 0.3)
		destroyed.emit(self)
