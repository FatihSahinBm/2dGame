extends Node

## res://scripts/autoloads/camera_manager.gd
## Story 2D-147: Gelişmiş Kamera Takibi, Sarsıntı ve Boss Arenası Yöneticisi
## - Aktif kamera kaydı ve merkezi erişim
## - Birden fazla sarsıntının öncelik ve üst sınırla birleştirilmesi
## - Ekran sarsıntısı yoğunluğu (0.0 - 1.0) ve kalıcılık (user://game_settings.json)
## - CinematicManager erişilebilirlik entegrasyonu (reduce_motion aktifken sarsıntı 0)
## - Boss arenası ölçekleme (zoom) ve sınır koordinasyonu

signal settings_changed()
signal boss_arena_entered(arena_bounds: Rect2, target_zoom: Vector2)
signal boss_arena_exited()

const SETTINGS_PATH: String = "user://game_settings.json"

enum ShakePriority {
	LOW = 0,       ## Küçük adım/darbe veya hafif çevre sarsıntıları
	MEDIUM = 1,    ## Normal silah saldırıları ve hasar vuruşları
	HIGH = 2,      ## Boss zemin darbeleri, lazerler, kılıç isyanı
	CRITICAL = 3   ## Faz geçişleri, sinematik yıkımlar, büyük çan
}

## 0.0 (kapalı) ile 1.0 (tam güç) arası ekran sarsıntısı çarpanı
var screen_shake_intensity: float = 1.0

var _active_camera: Camera2D = null
var _in_boss_arena: bool = false
var _current_arena_bounds: Rect2 = Rect2()
var _current_arena_zoom: Vector2 = Vector2(0.82, 0.82)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


# ---------------------------------------------------------------------------
# Aktif Kamera Yönetimi
# ---------------------------------------------------------------------------
func register_camera(cam: Camera2D) -> void:
	_active_camera = cam


func unregister_camera(cam: Camera2D) -> void:
	if _active_camera == cam:
		_active_camera = null


func get_active_camera() -> Camera2D:
	if _active_camera and is_instance_valid(_active_camera):
		return _active_camera
	var vp := get_viewport()
	if vp:
		return vp.get_camera_2d()
	return null


# ---------------------------------------------------------------------------
# Ekran Sarsıntısı Ayarları ve Erişilebilirlik
# ---------------------------------------------------------------------------
func set_screen_shake_intensity(val: float) -> void:
	screen_shake_intensity = clampf(val, 0.0, 1.0)
	save_settings()
	settings_changed.emit()


func get_screen_shake_intensity() -> float:
	return screen_shake_intensity


## Erişilebilirlik ve ayarları birleştiren etkin çarpan
func get_effective_shake_multiplier() -> float:
	# Ayar 0 ise doğrudan kapalı
	if screen_shake_intensity <= 0.0:
		return 0.0
	# CinematicManager reduce_motion aktifse sarsıntı tamamen devre dışı
	var cm := get_node_or_null("/root/CinematicManager")
	if cm and "reduce_motion" in cm and cm.reduce_motion:
		return 0.0
	return screen_shake_intensity


func is_shake_enabled() -> bool:
	return get_effective_shake_multiplier() > 0.0


# ---------------------------------------------------------------------------
# Merkezi Sarsıntı API'si
# ---------------------------------------------------------------------------
func apply_shake(intensity: float, priority: int = ShakePriority.MEDIUM, duration: float = 0.25, frequency: float = 25.0, source: String = "") -> void:
	if not is_shake_enabled() or intensity <= 0.0:
		return
	var cam := get_active_camera()
	if cam and cam.has_method("apply_shake"):
		cam.apply_shake(intensity, priority, duration, frequency, source)


func stop_all_shakes() -> void:
	var cam := get_active_camera()
	if cam and cam.has_method("stop_all_shakes"):
		cam.stop_all_shakes()


# ---------------------------------------------------------------------------
# Boss Arenası Görünüm Ölçeklemesi
# ---------------------------------------------------------------------------
func enter_boss_arena(arena_bounds: Rect2 = Rect2(), target_zoom: Vector2 = Vector2(0.82, 0.82), duration: float = 0.8) -> void:
	_in_boss_arena = true
	_current_arena_bounds = arena_bounds
	_current_arena_zoom = target_zoom
	boss_arena_entered.emit(arena_bounds, target_zoom)
	var cam := get_active_camera()
	if cam and cam.has_method("enter_boss_arena"):
		cam.enter_boss_arena(arena_bounds, target_zoom, duration)


func exit_boss_arena(duration: float = 0.8) -> void:
	_in_boss_arena = false
	_current_arena_bounds = Rect2()
	boss_arena_exited.emit()
	var cam := get_active_camera()
	if cam and cam.has_method("exit_boss_arena"):
		cam.exit_boss_arena(duration)


func is_in_boss_arena() -> bool:
	return _in_boss_arena


func get_arena_bounds() -> Rect2:
	return _current_arena_bounds


func get_arena_zoom() -> Vector2:
	return _current_arena_zoom


# ---------------------------------------------------------------------------
# Kalıcılık (user://game_settings.json)
# ---------------------------------------------------------------------------
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		if json.data.has("screen_shake_intensity"):
			screen_shake_intensity = clampf(float(json.data.get("screen_shake_intensity", 1.0)), 0.0, 1.0)
	f.close()


func save_settings() -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var rf := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if rf:
			var json := JSON.new()
			if json.parse(rf.get_as_text()) == OK and json.data is Dictionary:
				existing = json.data
			rf.close()
	existing["screen_shake_intensity"] = screen_shake_intensity
	var wf := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))
		wf.close()
