class_name ArtilleryShell
extends Node2D

## res://scripts/hazards/ww2/artillery_shell.gd
## Tek topçu mermisi (Epic 2D-144): önce zemine kızıl hedef işareti düşer ve ıslık sesi
## gelir (telegraph — zararsız), süre dolunca patlar. Sığınaktaki ya da Kan Sisi
## Atılması yapan oyuncu etkilenmez. Patlamadan sonra kendini siler.

signal exploded(at: Vector2)

const Explosion = preload("res://scripts/hazards/ww2/ww2_explosion.gd")
const MARKER_TEX: Texture2D = preload("res://assets/effects/ww2/artillery_marker.png")

@export var damage: int = 22
@export var radius: float = 80.0
@export var telegraph_time: float = 1.1
@export var autostart: bool = true
@export var hits_enemies: bool = false

var is_exploded: bool = false
var _marker: Sprite2D = null
var _t: float = 0.0
var _armed: bool = false


func _ready() -> void:
	_marker = Sprite2D.new()
	_marker.texture = MARKER_TEX
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marker.z_index = 6
	_marker.scale = Vector2(radius / 64.0, 1.0)
	add_child(_marker)
	if autostart:
		arm()


## Telegraph'ı başlatır
func arm() -> void:
	if _armed:
		return
	_armed = true
	_t = 0.0
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("artillery_whistle", global_position, null, -6.0, 1600.0)


func _process(delta: float) -> void:
	if not _armed or is_exploded:
		return
	_t += delta
	if _marker:
		_marker.modulate.a = 0.45 + 0.55 * absf(sin(_t * 10.0))
	if _t >= telegraph_time:
		detonate()


func is_dangerous() -> bool:
	return is_exploded


func detonate() -> int:
	if is_exploded:
		return 0
	is_exploded = true
	var hits: int = Explosion.explode(get_parent() if get_parent() else self, global_position, radius, damage, true, hits_enemies, self)
	exploded.emit(global_position)
	queue_free()
	return hits
