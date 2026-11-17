class_name PowerRelay
extends EgyptInteractable

## res://scripts/objects/ww2/power_relay.gd
## Güç rölesi / şalter (Epic 2D-144). [E] ile açılıp kapanır. Laboratuvar bulmacasında
## tüm rölelerin hedef konuma getirilmesi vantilatörleri çalıştırır (seviye denetler).
## Bulmaca çözülünce kilitlenir; çözülmüş durum kalıcıdır.

signal toggled(relay: PowerRelay, is_on: bool)

const TEX_OFF: Texture2D = preload("res://assets/objects/ww2/power_relay_off.png")
const TEX_ON: Texture2D = preload("res://assets/objects/ww2/power_relay_on.png")

@export var is_on: bool = false
@export var target_on: bool = true

var is_locked: bool = false
var _sprite: Sprite2D = null


func _interactable_ready() -> void:
	prompt_key = "PROMPT_WW2_RELAY"
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if is_persisted("solved"):
		is_on = target_on
		lock()
	_refresh()


func _on_interact() -> void:
	if is_locked:
		return
	set_on(not is_on)
	interaction_requested.emit(self)


func set_on(value: bool) -> void:
	is_on = value
	_refresh()
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("relay_switch", global_position, null, -2.0, 700.0)
	toggled.emit(self, is_on)


func is_correct() -> bool:
	return is_on == target_on


## Bulmaca çözüldü: röle sabitlenir ve durum kaydedilir
func lock() -> void:
	is_locked = true
	persist("solved")
	set_interaction_enabled(false)


func _refresh() -> void:
	if _sprite:
		_sprite.texture = TEX_ON if is_on else TEX_OFF
