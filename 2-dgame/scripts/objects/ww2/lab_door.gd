class_name LabDoor
extends StaticBody2D

## res://scripts/objects/ww2/lab_door.gd
## Kilitli çelik kapı (Epic 2D-144): laboratuvar kapısı (röle bulmacası) ve sığınak arka
## kapısı (yetki kartı). open() çağrılınca yukarı kayıp kaybolur; açık durum kalıcıdır.

signal opened()

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")

## Boş değilse kapı yalnızca bu eşya envanterdeyken try_open() ile açılır
@export var required_item: String = ""

var is_open: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if WorldObjectState.is_set(self, "opened"):
		_apply_open(true)


func can_open() -> bool:
	if required_item.is_empty():
		return true
	var inv: GDScript = load("res://scripts/components/ww2_inventory.gd") as GDScript
	return inv.has_item(self, required_item)


func try_open() -> bool:
	return can_open() and open()


func open() -> bool:
	if is_open:
		return true
	_apply_open(false)
	WorldObjectState.mark(self, "opened")
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("gate_break", global_position, null, -4.0, 1200.0)
	opened.emit()
	return true


func _apply_open(instant: bool) -> void:
	is_open = true
	for child: Node in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	if instant:
		position.y -= 220.0
		modulate.a = 0.0
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "position:y", position.y - 220.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
