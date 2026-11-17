class_name EnergyTube
extends StaticBody2D

## res://scripts/objects/ww2/energy_tube.gd
## Okült enerji tüpü / enerji sütunu (Epic 2D-144). Vurularak kırılır; kırılınca
## `broken` yayar ve kırık dokuya geçer. Mini-Boss 2'de Başhekim'in okült kalkanını,
## Komutan savaşında (Form 3) boss'u sersemleten enerji sütunlarını besler.

signal broken(tube: EnergyTube)

const TEX_INTACT: Texture2D = preload("res://assets/objects/ww2/energy_tube_intact.png")
const TEX_BROKEN: Texture2D = preload("res://assets/objects/ww2/energy_tube_broken.png")

@export var max_health: int = 40

var current_health: int = 40
var is_broken: bool = false
var _sprite: Sprite2D = null
var _glow: PointLight2D = null


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("ww2_energy_tubes")
	collision_layer = 4
	collision_mask = 0
	current_health = max_health
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_glow = get_node_or_null("Glow") as PointLight2D
	if _sprite:
		_sprite.texture = TEX_INTACT


func take_damage(amount: int, _source: Variant = null) -> void:
	if is_broken:
		return
	current_health = maxi(0, current_health - maxi(1, amount))
	if _sprite:
		_sprite.modulate = Color(2.0, 1.4, 1.4)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if current_health <= 0:
		shatter()


func shatter() -> void:
	if is_broken:
		return
	is_broken = true
	current_health = 0
	remove_from_group("damageable")
	if _sprite:
		_sprite.texture = TEX_BROKEN
	if _glow:
		create_tween().tween_property(_glow, "energy", 0.0, 0.4)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("energy_tube_break", global_position, null, -2.0, 1000.0)
	broken.emit(self)


## Tüpü yeniden doldurur (boss sütunları faz başında yenilenir)
func restore() -> void:
	is_broken = false
	current_health = max_health
	add_to_group("damageable")
	if _sprite:
		_sprite.texture = TEX_INTACT
	if _glow:
		_glow.energy = 0.9
