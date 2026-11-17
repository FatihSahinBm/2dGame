class_name ArmoredTrainCar
extends AnimatableBody2D

## res://scripts/objects/ww2/armored_train_car.gd
## Hareketli zırhlı tren vagonu (Epic 2D-144). Viyadük üzerinde iki x noktası arasında
## gidip gelir; çatısı taşıyıcı platformdur (oyuncu ve düşmanlar üzerinde durabilir).
## sync_to_physics sayesinde üzerindeki gövdeler vagonla birlikte taşınır.
## Uç noktalarda kısa duraklama ve vagon tokuşma sesi vardır.

signal reached_end(at_end: bool)

@export var x_from: float = 0.0
@export var x_to: float = 600.0
@export var travel_speed: float = 120.0
@export var pause_time: float = 1.2
@export var moving: bool = true

var direction: int = 1
var _pause: float = 0.0


func _ready() -> void:
	add_to_group("ww2_train_cars")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	if x_from == 0.0 and x_to == 600.0:
		x_from = position.x
		x_to = position.x + 600.0


func _physics_process(delta: float) -> void:
	if not moving:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var target: float = x_to if direction > 0 else x_from
	position.x = move_toward(position.x, target, travel_speed * delta)
	if is_equal_approx(position.x, target):
		direction = -direction
		_pause = pause_time
		reached_end.emit(direction < 0)
		var am: Node = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sound_2d"):
			am.play_sound_2d("train_car_clank", global_position, null, -4.0, 1100.0)
