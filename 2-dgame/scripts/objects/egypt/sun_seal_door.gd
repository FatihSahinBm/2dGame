class_name SunSealDoor
extends StaticBody2D

## res://scripts/objects/egypt/sun_seal_door.gd
## Güneş Mührü kapısı (Epic 2D-143): gerekli tüm mühür anahtarları toplandığında açılır.
## Seviye anahtar toplandığında try_open() çağırır; açık durum kalıcıdır.

signal opened()

const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
const SEAL_EVENT_PREFIX: String = "egypt_seal_key|"

@export var required_keys: PackedStringArray = PackedStringArray(["seal_east", "seal_west"])

var is_open: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if WorldObjectState.is_set(self, "opened"):
		_apply_open(true)


func get_collected_count() -> int:
	var gs: Node = get_node_or_null("/root/GameState") if is_inside_tree() else null
	if gs == null or not gs.has_method("is_event_completed"):
		return 0
	var count: int = 0
	for key_id: String in required_keys:
		if gs.is_event_completed(SEAL_EVENT_PREFIX + key_id):
			count += 1
	return count


func can_open() -> bool:
	return get_collected_count() >= required_keys.size()


## Anahtarlar tamamsa kapıyı açar; açıldıysa true döner
func try_open() -> bool:
	if is_open:
		return true
	if not can_open():
		return false
	_apply_open(false)
	WorldObjectState.mark(self, "opened")
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("gate_break", global_position, null, -2.0, 1200.0)
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
	tw.tween_property(self, "position:y", position.y - 220.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 1.2)
