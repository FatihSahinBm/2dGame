class_name Ww2AlarmLight
extends PointLight2D

## res://scripts/effects/ww2_alarm_light.gd
## Dinamik ortam ışığı (Epic 2D-144): sığınak alarm lambası (dönerek yanıp söner),
## laboratuvar okült tüp ışığı (yavaş nabız) veya projektör sıcaklığı (hafif titreme).
## Reduce-flashing erişilebilirlik ayarı açıksa yanıp sönme yumuşatılır.

@export_enum("alarm", "occult_pulse", "flicker") var mode: String = "alarm"
@export var base_energy: float = 0.9
@export var speed: float = 3.0

var _t: float = 0.0


func _ready() -> void:
	if texture == null:
		texture = load("res://assets/effects/lighting/light_radial_falloff.png") as Texture2D
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * speed
	var reduce: bool = false
	var cm: Node = get_node_or_null("/root/CinematicManager")
	if cm and "reduce_flashing" in cm:
		reduce = bool(cm.reduce_flashing)
	match mode:
		"alarm":
			var pulse: float = 0.5 + 0.5 * sin(_t)
			energy = base_energy * (0.5 + 0.5 * pulse if reduce else pulse * pulse)
		"occult_pulse":
			energy = base_energy * (0.7 + 0.3 * sin(_t * 0.6))
		_:
			energy = base_energy * (0.9 + (0.03 if reduce else 0.12) * sin(_t * 7.3) * sin(_t * 3.1))
