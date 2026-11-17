class_name SandstormOverlay
extends CanvasLayer

## res://scripts/effects/sandstorm_overlay.gd
## Kızıl kum fırtınası overlay'i (Epic 2D-143): ekran boyu savrulan kum zerreleri ve kızıl
## sis katmanı. "Hareketi azalt" açıksa partikül yoğunluğu düşer, yalnızca sis kalır.

@export_range(0.0, 1.0) var intensity: float = 0.6
@export var tint: Color = Color(0.75, 0.22, 0.12, 0.16)
@export var wind_direction: Vector2 = Vector2(-1.0, 0.15)

const GRAIN_TEX: Texture2D = preload("res://assets/effects/egypt/sand_grain.png")
const VIEW_SIZE: Vector2 = Vector2(1280.0, 720.0)

var _haze: ColorRect = null
var _grains: CPUParticles2D = null
var _gust_t: float = 0.0


func _ready() -> void:
	layer = 5
	_haze = ColorRect.new()
	_haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.color = tint
	add_child(_haze)
	_grains = CPUParticles2D.new()
	_grains.texture = GRAIN_TEX
	_grains.position = Vector2(VIEW_SIZE.x + 40.0, VIEW_SIZE.y * 0.5)
	_grains.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_grains.emission_rect_extents = Vector2(20.0, VIEW_SIZE.y * 0.6)
	_grains.direction = wind_direction
	_grains.spread = 8.0
	_grains.gravity = Vector2.ZERO
	_grains.initial_velocity_min = 520.0
	_grains.initial_velocity_max = 860.0
	_grains.lifetime = 2.6
	_grains.scale_amount_min = 0.8
	_grains.scale_amount_max = 2.2
	_grains.color = Color(0.95, 0.55, 0.32, 0.7)
	add_child(_grains)
	set_intensity(intensity)


func _process(delta: float) -> void:
	_gust_t += delta
	if _haze:
		_haze.color.a = tint.a * (0.8 + 0.25 * sin(_gust_t * 0.7)) * (0.5 + intensity)


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	var cm: Node = get_node_or_null("/root/CinematicManager") if is_inside_tree() else null
	var calm: bool = cm != null and "reduce_motion" in cm and bool(cm.reduce_motion)
	if _grains:
		_grains.amount = maxi(8, int((40 if calm else 160) * intensity))
		_grains.emitting = intensity > 0.0


func get_particle_amount() -> int:
	return _grains.amount if _grains else 0
