class_name FloatingPyramid
extends Sprite2D

## res://scripts/effects/floating_pyramid.gd
## Zaman kırılmasıyla havada asılı kalmış piramit (Epic 2D-143): yavaş süzülme, hafif dönme
## ve kaya tabanından dökülen kum zerreleri. Parallax derinliği için kamera ile kayar.

@export var bob_amplitude: float = 10.0
@export var bob_speed: float = 0.5
@export var sway_degrees: float = 2.0
@export_range(0.0, 1.0) var parallax_factor: float = 0.3

var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture == null:
		texture = load("res://assets/environment/egypt/floating_pyramid.png") as Texture2D
	_origin = position
	_t = randf() * TAU
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.texture = load("res://assets/effects/egypt/sand_grain.png") as Texture2D
	dust.position = Vector2(0.0, 40.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(18.0, 2.0)
	dust.amount = 10
	dust.lifetime = 2.2
	dust.gravity = Vector2(0.0, 60.0)
	dust.initial_velocity_min = 0.0
	dust.initial_velocity_max = 8.0
	dust.color = Color(0.85, 0.55, 0.35, 0.6)
	add_child(dust)


func _process(delta: float) -> void:
	_t += delta * bob_speed
	var cam_offset: Vector2 = Vector2.ZERO
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam:
		cam_offset = cam.get_screen_center_position() * parallax_factor
	position = _origin + cam_offset + Vector2(0.0, sin(_t) * bob_amplitude)
	rotation_degrees = sin(_t * 0.7) * sway_degrees
