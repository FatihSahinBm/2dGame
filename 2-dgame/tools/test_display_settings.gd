extends SceneTree

## res://tools/test_display_settings.gd
## Story 2D-114: Görüntü ayarları (ekran modu, çözünürlük, VSync, FPS sınırı).
## Gerçek ayar dosyasına dokunmamak için geçici bir dosya yolu kullanır.
## Çalıştırma: godot --headless --path . --script res://tools/test_display_settings.gd

const TEST_PATH: String = "user://test_display_settings.json"

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Görüntü Ayarları (2D-114) ===")
	var script: GDScript = load("res://scripts/autoloads/display_settings.gd") as GDScript
	_check(script.SETTINGS_PATH == "user://game_settings.json", "Ayarlar ortak game_settings.json dosyasında tutuluyor.")

	# Doğrulama kuralları
	var display: Node = script.new()
	display.apply_to_window = false
	_check(display.sanitize_mode("hologram") == display.DEFAULT_MODE, "Geçersiz ekran modu güvenli varsayılana çekiliyor.")
	_check(display.sanitize_resolution(Vector2i(99999, 5)) == display.DEFAULT_RESOLUTION, "Geçersiz çözünürlük güvenli varsayılana çekiliyor.")
	_check(display.sanitize_fps_limit(-7) == display.DEFAULT_FPS_LIMIT and display.sanitize_fps_limit(60) == 60, "FPS sınırı yalnızca tanımlı değerleri kabul ediyor.")
	_check(not display.get_supported_resolutions().is_empty(), "Ekrana sığan en az bir çözünürlük sunuluyor.")

	# Bozuk kayıt verisi oyunu erişilemez yapmamalı
	display.apply_dictionary({"window_mode": 42, "resolution": "bozuk", "vsync": 1, "fps_limit": "abc"})
	_check(display.window_mode == display.DEFAULT_MODE and display.resolution == display.DEFAULT_RESOLUTION and display.fps_limit == display.DEFAULT_FPS_LIMIT, "Bozuk kayıt verisi varsayılanlarla yükleniyor.")

	# Gidiş-dönüş: sözlük -> JSON -> sözlük
	display.window_mode = display.MODE_WINDOWED
	display.resolution = Vector2i(1600, 900)
	display.vsync_enabled = false
	display.fps_limit = 120
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(display.to_dictionary()))
	var loaded: Node = script.new()
	loaded.apply_to_window = false
	loaded.apply_dictionary(round_trip)
	_check(loaded.window_mode == display.MODE_WINDOWED and loaded.resolution == Vector2i(1600, 900) and not loaded.vsync_enabled and loaded.fps_limit == 120, "Ayarlar JSON gidiş-dönüşünden kayıpsız geçiyor.")

	# FPS sınırı motora uygulanıyor
	var previous_fps: int = Engine.max_fps
	loaded.apply()
	_check(Engine.max_fps == 120, "FPS sınırı Engine.max_fps değerine uygulanıyor.")
	loaded.fps_limit = 0
	loaded.apply()
	_check(Engine.max_fps == 0, "Sınırsız seçeneği kare sınırını kaldırıyor.")
	Engine.max_fps = previous_fps

	# Varsayılana dönüş yolu
	loaded.window_mode = loaded.MODE_FULLSCREEN
	loaded.window_mode = loaded.sanitize_mode(loaded.window_mode)
	loaded.resolution = Vector2i(2560, 1440)
	loaded.vsync_enabled = false
	loaded.fps_limit = 30
	loaded.window_mode = loaded.DEFAULT_MODE
	loaded.resolution = loaded.DEFAULT_RESOLUTION
	_check(loaded.is_fullscreen() == (loaded.DEFAULT_MODE != loaded.MODE_WINDOWED), "Varsayılan mod tutarlı raporlanıyor.")

	# Ayarlar penceresi satırları
	var autoload: Node = root.get_node_or_null("DisplaySettings")
	if autoload:
		display.free()
		display = autoload
		display.apply_to_window = false
	else:
		display.name = "DisplaySettings"
		root.add_child(display)
	var dialog: Control = (load("res://scenes/ui/settings_dialog.tscn") as PackedScene).instantiate()
	root.add_child(dialog)
	await process_frame
	var mode_option: OptionButton = dialog.find_child("DisplayModeOption", true, false) as OptionButton
	var res_option: OptionButton = dialog.find_child("ResolutionOption", true, false) as OptionButton
	var vsync_check: CheckBox = dialog.find_child("VsyncCheck", true, false) as CheckBox
	var fps_option: OptionButton = dialog.find_child("FpsLimitOption", true, false) as OptionButton
	_check(mode_option != null and res_option != null and vsync_check != null and fps_option != null, "Ayarlar penceresinde ekran modu, çözünürlük, VSync ve FPS satırları var.")
	if mode_option and fps_option and res_option:
		_check(mode_option.item_count == display.WINDOW_MODES.size() and fps_option.item_count == display.FPS_LIMITS.size(), "Seçenek listeleri tanımlı değerlerle dolu.")
		_check(fps_option.selected == display.FPS_LIMITS.find(display.fps_limit) and mode_option.selected == display.WINDOW_MODES.find(display.window_mode), "Satırlar geçerli ayarı seçili gösteriyor.")
		_check(res_option.disabled == display.is_fullscreen(), "Çözünürlük seçimi yalnızca pencereli modda etkin.")
		var raw_key_shown: bool = false
		for label_name: String in ["DisplayModeLabel", "ResolutionLabel", "VsyncLabel", "FpsLimitLabel"]:
			var label: Label = dialog.find_child(label_name, true, false) as Label
			if label == null or label.text.begins_with("SETTINGS_") or label.text.is_empty():
				raw_key_shown = true
		_check(not raw_key_shown, "Satır etiketleri çevrilmiş metin gösteriyor (ham anahtar yok).")
	dialog.queue_free()
	if autoload == null:
		display.queue_free()
	loaded.free()

	if _failed:
		printerr("SONUÇ: GÖRÜNTÜ AYARLARI TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: GÖRÜNTÜ AYARLARI TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
