class_name SandbagCover
extends StaticBody2D

## res://scripts/objects/ww2/sandbag_cover.gd
## Yıkılabilir siper bariyeri (Epic 2D-144): Komutan'ın keskin nişancı atışını üzerine
## çeker (ww2_cover grubu) ve hasar alarak yıkılır. Oyuncu da kılıçla yıkabilir.
## Yıkılınca çarpışma kapanır ve parçalanma efekti oynar.

signal destroyed(cover: SandbagCover)

const TEX: Texture2D = preload("res://assets/objects/ww2/sandbag_barrier.png")

@export var max_health: int = 70

var current_health: int = 70
var _is_destroyed: bool = false
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("ww2_cover")
	add_to_group("damageable")
	collision_layer = 1
	collision_mask = 0
	current_health = max_health
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0.0, -64.0)
	add_child(_sprite)
	if get_node_or_null("CollisionShape2D") == null:
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(70.0, 60.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -30.0)
		add_child(shape)


func is_destroyed() -> bool:
	return _is_destroyed


func take_damage(amount: int, _source: Variant = null) -> void:
	if _is_destroyed:
		return
	current_health = maxi(0, current_health - maxi(1, amount))
	if _sprite:
		_sprite.modulate = Color(1.8, 1.5, 1.2)
		create_tween().tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.4 + 0.6 * float(current_health) / float(max_health)), 0.15)
	if current_health <= 0:
		_is_destroyed = true
		remove_from_group("damageable")
		remove_from_group("ww2_cover")
		for child: Node in get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)
		var am: Node = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sound_2d"):
			am.play_sound_2d("gate_break", global_position, null, -4.0, 1000.0)
		if _sprite:
			var tw: Tween = create_tween()
			tw.tween_property(_sprite, "scale", Vector2(1.2, 0.3), 0.25)
			tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.4)
		destroyed.emit(self)
