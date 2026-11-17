class_name Searchlight
extends Node2D

## res://scripts/hazards/ww2/searchlight.gd
## Hareketli projektör (Epic 2D-144): ışık konisi iki açı arasında tarar. Koni içinde kalan
## oyuncu "yakalanır" (player_spotted) — seviye alarm, takviye ya da topçu çağırır.
## Bir yakalamadan sonra `cooldown` süresince yeniden tetiklenmez. Kan Sisi Atılması
## sırasında oyuncu görünmez. Görsel: soluk koni dokusu + PointLight2D.

signal player_spotted(player: Node2D)

const CONE_TEX: Texture2D = preload("res://assets/effects/ww2/searchlight_cone.png")
const LAMP_TEX: Texture2D = preload("res://assets/objects/ww2/searchlight.png")

@export var sweep_from_deg: float = -35.0
@export var sweep_to_deg: float = 35.0
@export var sweep_speed: float = 0.5
@export var beam_length: float = 300.0
@export var beam_half_angle_deg: float = 11.0
@export var cooldown: float = 6.0
## true ise koni aşağı bakar (projektör yüksekte, zemini tarar)
@export var points_down: bool = true

var current_angle_deg: float = 0.0
var _phase: float = 0.0
var _cd: float = 0.0
var _cone: Sprite2D = null


func _ready() -> void:
	add_to_group("ww2_searchlights")
	var lamp: Sprite2D = Sprite2D.new()
	lamp.texture = LAMP_TEX
	lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lamp.offset = Vector2(0.0, -32.0)
	add_child(lamp)
	_cone = Sprite2D.new()
	_cone.texture = CONE_TEX
	_cone.centered = false
	_cone.offset = Vector2(-64.0, 0.0)
	_cone.scale = Vector2(1.0, beam_length / 256.0)
	_cone.position = Vector2(0.0, -48.0)
	_cone.z_index = 8
	_cone.modulate = Color(1.0, 1.0, 1.0, 0.85)
	add_child(_cone)
	_update_cone()


func _process(delta: float) -> void:
	_phase += delta * sweep_speed
	current_angle_deg = lerpf(sweep_from_deg, sweep_to_deg, 0.5 + 0.5 * sin(_phase))
	_update_cone()
	_cd = maxf(0.0, _cd - delta)
	if _cd <= 0.0:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player and is_point_lit(player.global_position + Vector2(0.0, -20.0)) and not _is_hidden(player):
			_cd = cooldown
			_cone.modulate = Color(1.6, 0.4, 0.35, 0.95)
			create_tween().tween_property(_cone, "modulate", Color(1.0, 1.0, 1.0, 0.85), 1.2)
			var am: Node = get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_sound_2d"):
				am.play_sound_2d("searchlight_alarm", global_position, null, -4.0, 1400.0)
			player_spotted.emit(player)


func _update_cone() -> void:
	if _cone:
		_cone.rotation = deg_to_rad(current_angle_deg) + (0.0 if points_down else PI)


## Koni yönü (dünya uzayında birim vektör)
func beam_direction() -> Vector2:
	return Vector2.DOWN.rotated(deg_to_rad(current_angle_deg) + (0.0 if points_down else PI))


func is_point_lit(world_point: Vector2) -> bool:
	var origin: Vector2 = global_position + Vector2(0.0, -48.0)
	var to_point: Vector2 = world_point - origin
	if to_point.length() > beam_length or to_point.length() < 1.0:
		return false
	return absf(rad_to_deg(beam_direction().angle_to(to_point))) <= beam_half_angle_deg


func _is_hidden(player: Node) -> bool:
	return "is_blood_mist_dashing" in player and bool(player.is_blood_mist_dashing)
