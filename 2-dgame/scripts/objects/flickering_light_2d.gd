class_name FlickeringLight2D
extends PointLight2D

## res://scripts/objects/flickering_light_2d.gd
## Meşale, kamp ateşi ve organik ışık kaynakları için dinamik 2D titreşim (flicker) kontrolcüsü.

@export var base_energy: float = 1.0
@export var energy_jitter: float = 0.16
@export var flicker_speed: float = 8.5
@export var base_scale: float = 1.6
@export var scale_jitter: float = 0.06
@export var pulse_color: bool = true
@export var base_color: Color = Color(1.0, 0.72, 0.35, 1.0)
@export var warm_color: Color = Color(1.0, 0.52, 0.18, 1.0)

var _time: float = 0.0
var _phase_offset: float = 0.0


func _ready() -> void:
	# Farklı ışıkların aynı anda birebir aynı titrememesi için rastgele faz ofseti
	_phase_offset = randf() * 100.0
	_time = _phase_offset
	if texture == null:
		texture = load("res://assets/effects/lighting/light_radial_falloff.png")
	color = base_color
	energy = base_energy
	texture_scale = base_scale


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	var n1: float = sin(_time)
	var n2: float = sin(_time * 2.37 + 1.1)
	var n3: float = sin(_time * 4.71 + 2.3)
	var blend: float = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2)

	energy = maxf(0.05, base_energy + blend * energy_jitter)
	texture_scale = maxf(0.1, base_scale + blend * scale_jitter)

	if pulse_color:
		var t: float = clampf(0.5 + blend * 0.5, 0.0, 1.0)
		color = base_color.lerp(warm_color, t * 0.45)

