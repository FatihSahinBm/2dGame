class_name CharacterLightingController
extends PointLight2D

## res://scripts/effects/character_lighting_controller.gd
## Karakter Işıklandırma Kontrolcüsü (Dinamik Çevre & Karanlık Ortam Adaptasyonu)
## - Yalnızca karanlık ortamlarda (CanvasModulate, zindan, gece, karanlık bölge) aktifleşir.
## - Aydınlık/gündüz veya çevre ışığı olan ortamlarda devre dışı kalır (aşırı parlamayı önler).
## - Yakında güçlü çevre ışığı (meşale, kamp ateşi) olduğunda karakter ışığını dinamik kısar.

signal darkness_state_changed(is_dark: bool, target_energy: float)

@export_group("Darkness Detection")
@export var darkness_threshold: float = 0.82
@export var max_dark_energy: float = 0.38
@export var min_dark_energy: float = 0.10
@export var transition_speed: float = 3.6
@export var proximity_dim_distance: float = 200.0

@export_group("Overrides")
@export var manual_override: bool = false
@export var override_is_dark: bool = false

var _is_dark_env: bool = false
var _target_energy: float = 0.0
var _check_timer: float = 0.0
var _cached_modulate: CanvasModulate = null


func _ready() -> void:
	enabled = false
	energy = 0.0
	_evaluate_environment(true)


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.05
		_evaluate_environment(false)
		
	if absf(energy - _target_energy) > 0.005:
		energy = move_toward(energy, _target_energy, transition_speed * delta)
		
	if energy <= 0.002:
		energy = 0.0
		if enabled and _target_energy <= 0.001:
			enabled = false
	else:
		if not enabled and _target_energy > 0.005:
			enabled = true


func _evaluate_environment(force_immediate: bool = false) -> void:
	if manual_override:
		_set_dark_state(override_is_dark, max_dark_energy if override_is_dark else 0.0, force_immediate)
		return

	var ambient_darkness: float = _get_ambient_darkness()
	var in_dark_zone: bool = _is_in_dark_zone()
	var level_explicit_dark: bool = _is_level_explicitly_dark()

	var is_dark: bool = (ambient_darkness > 0.0) or in_dark_zone or level_explicit_dark
	
	if not is_dark:
		_set_dark_state(false, 0.0, force_immediate)
		return

	var base_e: float = lerpf(min_dark_energy, max_dark_energy, clampf(ambient_darkness, 0.2, 1.0))
	if in_dark_zone or level_explicit_dark:
		base_e = maxf(base_e, max_dark_energy * 0.85)

	var env_light_factor: float = _calculate_nearby_light_factor()
	var final_energy: float = base_e * clampf(1.0 - (env_light_factor * 0.85), 0.0, 1.0)
	
	_set_dark_state(true, final_energy, force_immediate)


func _get_ambient_darkness() -> float:
	if not is_instance_valid(_cached_modulate) or not _cached_modulate.is_inside_tree():
		_cached_modulate = _find_canvas_modulate()

	if _cached_modulate and _cached_modulate.visible:
		var c: Color = _cached_modulate.color
		var lum: float = (c.r * 0.299) + (c.g * 0.587) + (c.b * 0.114)
		if lum < darkness_threshold:
			return clampf((darkness_threshold - lum) / darkness_threshold, 0.0, 1.0)
	return 0.0


func _find_canvas_modulate() -> CanvasModulate:
	var current: Node = self
	while current:
		for child: Node in current.get_children():
			if child is CanvasModulate:
				return child as CanvasModulate
		current = current.get_parent()
	return null


func _is_in_dark_zone() -> bool:
	var parent_node: Node = get_parent()
	if parent_node is Node2D:
		var zones: Array[Node] = get_tree().get_nodes_in_group("dark_zones")
		for z: Node in zones:
			if z is Area2D and is_instance_valid(z):
				if (z as Area2D).overlaps_body(parent_node) or (z as Area2D).overlaps_area(parent_node):
					return true
	return false


func _is_level_explicitly_dark() -> bool:
	var root_scene: Node = get_tree().current_scene
	if root_scene:
		if "is_dark_environment" in root_scene and root_scene.is_dark_environment:
			return true
		if root_scene.has_meta("is_dark_environment"):
			return bool(root_scene.get_meta("is_dark_environment"))
	return false


func _calculate_nearby_light_factor() -> float:
	var my_pos: Vector2 = global_position
	var total_intensity: float = 0.0
	var lights: Array[Node] = get_tree().get_nodes_in_group("environment_lights")
	for light: Node in lights:
		if light != self and is_instance_valid(light) and light is Light2D:
			if not (light as Light2D).enabled:
				continue
			var dist: float = my_pos.distance_to((light as Node2D).global_position)
			if dist < proximity_dim_distance:
				var prox: float = 1.0 - (dist / proximity_dim_distance)
				total_intensity += prox * ((light as Light2D).energy / 1.0)
	return clampf(total_intensity, 0.0, 1.0)


func _set_dark_state(dark: bool, target_e: float, immediate: bool) -> void:
	_is_dark_env = dark
	_target_energy = target_e
	if immediate:
		energy = _target_energy
		enabled = (_target_energy > 0.001)
	darkness_state_changed.emit(_is_dark_env, _target_energy)


func set_dark_environment(is_dark: bool) -> void:
	manual_override = true
	override_is_dark = is_dark
	_evaluate_environment(false)


func reset_override() -> void:
	manual_override = false
	_evaluate_environment(false)


func is_dark_active() -> bool:
	return _is_dark_env and enabled
