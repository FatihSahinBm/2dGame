class_name ConveyorBelt
extends StaticBody2D

## res://scripts/hazards/future/conveyor_belt.gd
## Montaj hattı konveyör bandı (Epic 2D-158): üstünde duran gövdeleri (oyuncu, düşman) bant
## hızında taşır (StaticBody2D.constant_linear_velocity). Kontrol terminali reverse() ile
## yönü tersine çevirir; set_powered(false) bandı durdurur. 4 karelik bant dokusu akış yönünde döner.

signal direction_changed(new_direction: int)

@export var length: float = 256.0
@export var belt_speed: float = 70.0
@export_range(-1, 1, 2) var direction: int = 1
@export var powered: bool = true

var _sprites: Array[Sprite2D] = []
var _frames: Array[Texture2D] = []
var _anim_t: float = 0.0


func _ready() -> void:
	add_to_group("future_conveyors")
	collision_layer = 1
	collision_mask = 0
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(length, 20.0)
	cs.shape = rect
	cs.position = Vector2(0.0, 10.0)
	add_child(cs)
	for i: int in 4:
		var path: String = "res://assets/objects/future/obj_conveyor_belt_%d.png" % i
		if ResourceLoader.exists(path):
			_frames.append(load(path) as Texture2D)
	var count: int = int(ceil(length / 128.0))
	for i: int in count:
		var spr: Sprite2D = Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(-length * 0.5 + 64.0 + i * 128.0, 12.0)
		if not _frames.is_empty():
			spr.texture = _frames[0]
		add_child(spr)
		_sprites.append(spr)
	_apply_velocity()


func _process(delta: float) -> void:
	if not powered or _frames.is_empty():
		return
	_anim_t += delta * belt_speed / 40.0
	var idx: int = int(_anim_t) % _frames.size()
	if direction < 0:
		idx = _frames.size() - 1 - idx
	for spr: Sprite2D in _sprites:
		spr.texture = _frames[idx]


func reverse() -> void:
	direction = -direction
	_apply_velocity()
	direction_changed.emit(direction)


func set_powered(value: bool) -> void:
	powered = value
	_apply_velocity()


## Bandın oyuncuya uyguladığı yatay hız (testler ve terminal ipucu okur)
func get_surface_velocity() -> Vector2:
	return constant_linear_velocity


func _apply_velocity() -> void:
	constant_linear_velocity = Vector2(belt_speed * float(direction), 0.0) if powered else Vector2.ZERO
