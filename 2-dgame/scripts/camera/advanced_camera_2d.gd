class_name AdvancedCamera2D
extends Camera2D

## res://scripts/camera/advanced_camera_2d.gd
## Story 2D-147: Gelişmiş Kamera Takibi, Sarsıntı ve Boss Arenası Yönetimi
## - Camera2D yumuşatma (smoothing), deadzone ve yönsel look-ahead (sağ/sol ve düşüşte görüş alanı)
## - Hızlı yön değişimlerinde kontrolsüz titremeyi (jitter) önleyen histeresis ve sönümleme
## - Boss arenalarında uygun görünüm ölçeğine (zoom) geçiş ve arena sınırları
## - Birden fazla sarsıntının öncelik ve üst sınırla birleştirilmesi (multi-shake combiner)
## - Ekran sarsıntısı ve CinematicManager erişilebilirlik entegrasyonu (yüzde 0 veya reduce_motion'da devre dışı)

enum ShakePriority {
	LOW = 0,       ## Küçük vuruşlar, adım sesleri, hafif çevre etkileri
	MEDIUM = 1,    ## Normal silah vuruşları, düşman hasar alma
	HIGH = 2,      ## Boss zemin darbeleri, lazerler, kılıç isyanı
	CRITICAL = 3   ## Faz geçişleri, sinematik yıkımlar, ulu çan
}

# ---------------------------------------------------------------------------
# Dışa Aktarılan Yapılandırma
# ---------------------------------------------------------------------------
@export_group("Temel Konum ve Takip")
@export var base_offset_position: Vector2 = Vector2(0, -20)
@export var tracking_smoothing_speed: float = 8.0

@export_group("Yönsel Look-Ahead ve Deadzone")
@export var look_ahead_distance_x: float = 54.0
@export var look_ahead_distance_y: float = 48.0
@export var deadzone_speed_x: float = 28.0
@export var deadzone_distance: float = 6.0
@export var fall_speed_threshold: float = 160.0
@export var look_ahead_speed: float = 3.2
@export var direction_switch_delay: float = 0.12

@export_group("Boss Arenası ve Görünüm Ölçeği")
@export var default_zoom: Vector2 = Vector2.ONE
@export var boss_arena_zoom: Vector2 = Vector2(0.82, 0.82)
@export var zoom_transition_speed: float = 3.2

@export_group("Sarsıntı Birleştirme (Multi-Shake)")
@export var max_shake_intensity: float = 24.0

# ---------------------------------------------------------------------------
# İç Durum Değişkenleri
# ---------------------------------------------------------------------------
var _target_look_ahead: Vector2 = Vector2.ZERO
var _current_look_ahead: Vector2 = Vector2.ZERO
var _current_facing: float = 1.0
var _candidate_facing: float = 1.0
var _candidate_timer: float = 0.0

var _in_boss_arena: bool = false
var _target_zoom: Vector2 = Vector2.ONE
var _arena_bounds: Rect2 = Rect2()
var _saved_limits: Dictionary = {}

var _active_shakes: Array[Dictionary] = []
var _parent_body: CharacterBody2D = null

var _cinematic_base_offset: Vector2 = Vector2.ZERO
var _had_shakes_last_frame: bool = false


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = tracking_smoothing_speed
	position = base_offset_position
	_target_zoom = default_zoom
	zoom = default_zoom

	_parent_body = get_parent() as CharacterBody2D

	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("register_camera"):
		cm.register_camera(self)


func _exit_tree() -> void:
	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("unregister_camera"):
		cm.unregister_camera(self)


func _process(delta: float) -> void:
	_update_parent_tracking(delta)
	_update_zoom(delta)
	_update_shakes(delta)


# ---------------------------------------------------------------------------
# 1. Takip, Deadzone ve Yönsel Look-Ahead
# ---------------------------------------------------------------------------
func _update_parent_tracking(delta: float) -> void:
	if not _parent_body or not is_instance_valid(_parent_body):
		_parent_body = get_parent() as CharacterBody2D
		if not _parent_body:
			return

	var vx: float = _parent_body.velocity.x
	var vy: float = _parent_body.velocity.y
	var on_floor: bool = _parent_body.is_on_floor() if _parent_body.has_method("is_on_floor") else true
	var can_move: bool = _parent_body.can_move if "can_move" in _parent_body else true

	# Sinematik veya donma anında girdi ve hedef sıfırlanır
	if not can_move or _is_in_cinematic():
		_target_look_ahead = Vector2.ZERO
		_candidate_timer = 0.0
	else:
		# Deadzone ve histeresis kontrollü yatay yön algılama
		if absf(vx) >= deadzone_speed_x:
			var move_sign: float = 1.0 if vx > 0.0 else -1.0
			if not is_equal_approx(move_sign, _current_facing):
				if is_equal_approx(move_sign, _candidate_facing):
					_candidate_timer += delta
					if _candidate_timer >= direction_switch_delay:
						_current_facing = move_sign
						_candidate_timer = 0.0
				else:
					_candidate_facing = move_sign
					_candidate_timer = 0.0
			else:
				_candidate_facing = _current_facing
				_candidate_timer = 0.0

			_target_look_ahead.x = _current_facing * look_ahead_distance_x
		else:
			# Deadzone içinde micro-hareketler veya durma: yumuşak merkeze dönüş
			_candidate_timer = 0.0
			_target_look_ahead.x = 0.0

		# Düşüşte görüş alanı (aşağı bakış)
		if vy > fall_speed_threshold and not on_floor:
			var fall_ratio = clampf((vy - fall_speed_threshold) / 450.0, 0.0, 1.0)
			_target_look_ahead.y = fall_ratio * look_ahead_distance_y
		else:
			_target_look_ahead.y = 0.0

	# Yumuşak sönümlü enterpolasyon (Anti-jitter: hızlı yön geçişlerinde ani fırlamaları engeller)
	var t: float = clampf(look_ahead_speed * delta, 0.0, 1.0)
	_current_look_ahead = _current_look_ahead.lerp(_target_look_ahead, t)
	if _current_look_ahead.distance_to(_target_look_ahead) < 0.3:
		_current_look_ahead = _target_look_ahead
	position = base_offset_position + _current_look_ahead


func reset_look_ahead() -> void:
	_target_look_ahead = Vector2.ZERO
	_current_look_ahead = Vector2.ZERO
	_candidate_timer = 0.0
	position = base_offset_position


func get_current_look_ahead() -> Vector2:
	return _current_look_ahead


# ---------------------------------------------------------------------------
# 2. Boss Arenası Görünüm Ölçeği (Zoom) ve Sınırlar
# ---------------------------------------------------------------------------
func enter_boss_arena(arena_bounds: Rect2 = Rect2(), target_zoom: Vector2 = boss_arena_zoom, duration: float = 0.8) -> void:
	_in_boss_arena = true
	_target_zoom = target_zoom
	_arena_bounds = arena_bounds

	if arena_bounds.size != Vector2.ZERO:
		_saved_limits = {
			"left": limit_left,
			"right": limit_right,
			"top": limit_top,
			"bottom": limit_bottom
		}
		limit_left = int(arena_bounds.position.x)
		limit_right = int(arena_bounds.position.x + arena_bounds.size.x)
		limit_top = int(arena_bounds.position.y)
		limit_bottom = int(arena_bounds.position.y + arena_bounds.size.y)


func exit_boss_arena(_duration: float = 0.8) -> void:
	_in_boss_arena = false
	_target_zoom = default_zoom

	if not _saved_limits.is_empty():
		limit_left = int(_saved_limits.get("left", limit_left))
		limit_right = int(_saved_limits.get("right", limit_right))
		limit_top = int(_saved_limits.get("top", limit_top))
		limit_bottom = int(_saved_limits.get("bottom", limit_bottom))
		_saved_limits.clear()


func is_in_boss_arena() -> bool:
	return _in_boss_arena


func _update_zoom(delta: float) -> void:
	# Erişilebilirlik (reduce_motion): yumuşak geçiş yerine sabit ya da doğrudan geçiş
	if _is_reduce_motion_active():
		zoom = _target_zoom
		return

	if not zoom.is_equal_approx(_target_zoom):
		var z: float = clampf(zoom_transition_speed * delta, 0.0, 1.0)
		zoom = zoom.lerp(_target_zoom, z)
		if zoom.distance_to(_target_zoom) < 0.02:
			zoom = _target_zoom


# ---------------------------------------------------------------------------
# 3. Birden Fazla Sarsıntının Öncelik ve Üst Sınırla Birleştirilmesi
# ---------------------------------------------------------------------------
func apply_shake(intensity: float, priority: int = ShakePriority.MEDIUM, duration: float = 0.25, frequency: float = 25.0, source: String = "") -> void:
	var mult: float = _get_effective_multiplier()
	if mult <= 0.0 or intensity <= 0.0:
		return

	var scaled_intensity: float = clampf(intensity * mult, 0.0, max_shake_intensity)

	if not source.is_empty():
		for s in _active_shakes:
			if s.get("source", "") == source:
				s["intensity"] = maxf(float(s["intensity"]), scaled_intensity)
				s["duration"] = maxf(float(s["duration"]), duration)
				s["elapsed"] = 0.0
				s["priority"] = maxi(int(s["priority"]), priority)
				s["frequency"] = frequency
				return

	_active_shakes.append({
		"intensity": scaled_intensity,
		"duration": maxf(duration, 0.05),
		"elapsed": 0.0,
		"priority": priority,
		"frequency": frequency,
		"phase_x": randf() * TAU,
		"phase_y": randf() * TAU,
		"source": source
	})


func stop_all_shakes() -> void:
	_active_shakes.clear()
	if not _is_in_cinematic():
		offset = Vector2.ZERO
	else:
		offset = _cinematic_base_offset
	_had_shakes_last_frame = false


func get_active_shake_count() -> int:
	return _active_shakes.size()


func _update_shakes(delta: float) -> void:
	if _active_shakes.is_empty():
		if _had_shakes_last_frame:
			if not _is_in_cinematic():
				offset = Vector2.ZERO
			else:
				offset = _cinematic_base_offset
			_had_shakes_last_frame = false
		return

	if not _had_shakes_last_frame and _is_in_cinematic():
		_cinematic_base_offset = offset
	_had_shakes_last_frame = true

	# En yüksek önceliği bul
	var max_prio: int = 0
	for s in _active_shakes:
		max_prio = maxi(max_prio, int(s["priority"]))

	var combined_offset: Vector2 = Vector2.ZERO
	var i: int = _active_shakes.size() - 1

	while i >= 0:
		var s: Dictionary = _active_shakes[i]
		s["elapsed"] = float(s["elapsed"]) + delta
		var dur: float = maxf(float(s["duration"]), 0.001)

		if float(s["elapsed"]) >= dur:
			_active_shakes.remove_at(i)
			i -= 1
			continue

		var progress: float = clampf(float(s["elapsed"]) / dur, 0.0, 1.0)
		var decay: float = (1.0 - progress) * (1.0 - progress)
		var cur_amp: float = float(s["intensity"]) * decay

		# Öncelik ağırlığı: En yüksek öncelik 1.0, alt öncelikler orantılı katkı verir
		var prio_diff: int = max_prio - int(s["priority"])
		var prio_weight: float = 1.0 / (1.0 + float(prio_diff) * 0.75)

		var t: float = float(s["elapsed"]) * float(s["frequency"]) * TAU
		var dir: Vector2 = Vector2(sin(t + float(s["phase_x"])), cos(t * 1.37 + float(s["phase_y"])))
		combined_offset += dir * (cur_amp * prio_weight)
		i -= 1

	# Üst sınır kısıtlaması (max_shake_intensity)
	if combined_offset.length() > max_shake_intensity:
		combined_offset = combined_offset.normalized() * max_shake_intensity

	if _is_in_cinematic():
		offset = _cinematic_base_offset + combined_offset
	else:
		offset = combined_offset

	if _active_shakes.is_empty():
		if not _is_in_cinematic():
			offset = Vector2.ZERO
		else:
			offset = _cinematic_base_offset
		_had_shakes_last_frame = false


# ---------------------------------------------------------------------------
# Yardımcı Kontroller ve Erişilebilirlik
# ---------------------------------------------------------------------------
func _get_effective_multiplier() -> float:
	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("get_effective_shake_multiplier"):
		return cm.get_effective_shake_multiplier()

	# Fallback (CameraManager doğrudan mevcut değilse)
	var cin = get_node_or_null("/root/CinematicManager")
	if cin and "reduce_motion" in cin and cin.reduce_motion:
		return 0.0
	return 1.0


func _is_reduce_motion_active() -> bool:
	var cin = get_node_or_null("/root/CinematicManager")
	return cin != null and "reduce_motion" in cin and cin.reduce_motion


func _is_in_cinematic() -> bool:
	var cin = get_node_or_null("/root/CinematicManager")
	return cin != null and cin.has_method("is_active") and cin.is_active()
