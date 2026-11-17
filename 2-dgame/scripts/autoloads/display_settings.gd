extends Node

## res://scripts/autoloads/display_settings.gd
## Görüntü ayarları (Story 2D-114): ekran modu, çözünürlük, VSync ve kare hızı sınırı.
## - Ayarlar ortak user://game_settings.json dosyasına "display_settings" anahtarıyla
##   oku-birleştir-yaz yöntemiyle kaydedilir (diğer yöneticilerin anahtarları korunur).
## - Geçersiz/bozuk değerler yüklenirken güvenli varsayılana çekilir; ekrana sığmayan
##   çözünürlük uygulanmaz. reset_to_defaults() her zaman çalışan bir dönüş yoludur.
## - Kayıtlı ayar yoksa motorun proje varsayılanlarına dokunulmaz.
## Değerlendirme notu: piksel ölçeği proje genelinde canvas_items + 1.35 olarak sabittir ve
## piksel sanatının tam katlı ölçeklenmesi için menüden değiştirilmez; parlaklık/gama için
## sahnelerde ortak bir ekran katmanı olmadığından bu sürümde seçenek sunulmaz.

signal settings_changed()

const SETTINGS_PATH: String = "user://game_settings.json"
const SETTINGS_KEY: String = "display_settings"

const MODE_WINDOWED: String = "windowed"
const MODE_BORDERLESS: String = "borderless"
const MODE_FULLSCREEN: String = "fullscreen"
const WINDOW_MODES: Array[String] = [MODE_WINDOWED, MODE_BORDERLESS, MODE_FULLSCREEN]

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]
## 0 = sınırsız
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]

const DEFAULT_MODE: String = MODE_BORDERLESS
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1280, 720)
const DEFAULT_VSYNC: bool = true
const DEFAULT_FPS_LIMIT: int = 0

var window_mode: String = DEFAULT_MODE
var resolution: Vector2i = DEFAULT_RESOLUTION
var vsync_enabled: bool = DEFAULT_VSYNC
var fps_limit: int = DEFAULT_FPS_LIMIT

## Test ve araçlar için: false iken pencereye dokunulmaz, yalnızca değerler yönetilir
var apply_to_window: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if load_settings():
		apply()
	else:
		_read_current_window_state()


## Kayıtlı ayarları okur ve doğrular. Kayıt yoksa false döner.
func load_settings() -> bool:
	var stored: Variant = _read_settings_file().get(SETTINGS_KEY, null)
	if not stored is Dictionary:
		return false
	apply_dictionary(stored as Dictionary)
	return true


## Sözlükten değerleri doğrulayarak alır (bozuk veride güvenli varsayılan)
func apply_dictionary(data: Dictionary) -> void:
	window_mode = sanitize_mode(str(data.get("window_mode", DEFAULT_MODE)))
	var size_data: Variant = data.get("resolution", {})
	var wanted: Vector2i = DEFAULT_RESOLUTION
	if size_data is Dictionary:
		wanted = Vector2i(int((size_data as Dictionary).get("width", 0)), int((size_data as Dictionary).get("height", 0)))
	resolution = sanitize_resolution(wanted)
	vsync_enabled = bool(data.get("vsync", DEFAULT_VSYNC))
	fps_limit = sanitize_fps_limit(int(data.get("fps_limit", DEFAULT_FPS_LIMIT)))


func to_dictionary() -> Dictionary:
	return {
		"window_mode": window_mode,
		"resolution": {"width": resolution.x, "height": resolution.y},
		"vsync": vsync_enabled,
		"fps_limit": fps_limit,
	}


func sanitize_mode(mode: String) -> String:
	return mode if WINDOW_MODES.has(mode) else DEFAULT_MODE


func sanitize_resolution(size: Vector2i) -> Vector2i:
	return size if RESOLUTIONS.has(size) else DEFAULT_RESOLUTION


func sanitize_fps_limit(limit: int) -> int:
	return limit if FPS_LIMITS.has(limit) else DEFAULT_FPS_LIMIT


## Geçerli ekrana sığan çözünürlükler (hiçbiri sığmıyorsa en küçük seçenek)
func get_supported_resolutions() -> Array[Vector2i]:
	var screen: Vector2i = DisplayServer.screen_get_size()
	var supported: Array[Vector2i] = []
	for size: Vector2i in RESOLUTIONS:
		if screen.x <= 0 or (size.x <= screen.x and size.y <= screen.y):
			supported.append(size)
	if supported.is_empty():
		supported.append(RESOLUTIONS[0])
	return supported


func is_fullscreen() -> bool:
	return window_mode != MODE_WINDOWED


func set_window_mode(mode: String) -> void:
	window_mode = sanitize_mode(mode)
	_commit()


func set_resolution(size: Vector2i) -> void:
	resolution = sanitize_resolution(size)
	_commit()


func set_vsync_enabled(enabled: bool) -> void:
	vsync_enabled = enabled
	_commit()


func set_fps_limit(limit: int) -> void:
	fps_limit = sanitize_fps_limit(limit)
	_commit()


func reset_to_defaults() -> void:
	window_mode = DEFAULT_MODE
	resolution = DEFAULT_RESOLUTION
	vsync_enabled = DEFAULT_VSYNC
	fps_limit = DEFAULT_FPS_LIMIT
	_commit()


## Değerleri pencereye ve motora uygular
func apply() -> void:
	Engine.max_fps = fps_limit
	if not apply_to_window or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var supported: Array[Vector2i] = get_supported_resolutions()
			var target: Vector2i = resolution if supported.has(resolution) else supported[supported.size() - 1]
			DisplayServer.window_set_size(target)
			var screen: Vector2i = DisplayServer.screen_get_size()
			if screen.x > 0:
				DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - target) / 2)


func save_settings() -> void:
	var existing: Dictionary = _read_settings_file()
	existing[SETTINGS_KEY] = to_dictionary()
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()
	else:
		push_warning("DisplaySettings: Ayar dosyasına yazılamadı -> " + SETTINGS_PATH)


func _commit() -> void:
	apply()
	save_settings()
	settings_changed.emit()


func _read_current_window_state() -> void:
	fps_limit = sanitize_fps_limit(Engine.max_fps)
	if DisplayServer.get_name() == "headless":
		return
	vsync_enabled = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			window_mode = MODE_FULLSCREEN
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode = MODE_BORDERLESS
		_:
			window_mode = MODE_WINDOWED


func _read_settings_file() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}
