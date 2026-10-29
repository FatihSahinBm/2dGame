extends PanelContainer

## res://scripts/ui/settings_dialog.gd
## Ayarlar Menüsü (Ses, Ekran ve Dil Seçimi) — Story 2D-119

signal closed()

@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var language_label: Label = find_child("LanguageLabel", true, false) as Label
@onready var language_option: OptionButton = find_child("LanguageOption", true, false) as OptionButton

@onready var master_label: Label = find_child("MasterLabel", true, false) as Label
@onready var master_slider: HSlider = find_child("MasterSlider", true, false) as HSlider

@onready var music_label: Label = find_child("MusicLabel", true, false) as Label
@onready var music_slider: HSlider = find_child("MusicSlider", true, false) as HSlider

@onready var sfx_label: Label = find_child("SfxLabel", true, false) as Label
@onready var sfx_slider: HSlider = find_child("SfxSlider", true, false) as HSlider

@onready var display_label: Label = find_child("DisplayLabel", true, false) as Label
@onready var fullscreen_check: CheckBox = find_child("FullscreenCheck", true, false) as CheckBox

@onready var reduce_motion_label: Label = find_child("ReduceMotionLabel", true, false) as Label
@onready var reduce_motion_check: CheckBox = find_child("ReduceMotionCheck", true, false) as CheckBox
@onready var reduce_flash_label: Label = find_child("ReduceFlashLabel", true, false) as Label
@onready var reduce_flash_check: CheckBox = find_child("ReduceFlashCheck", true, false) as CheckBox

@onready var back_button: Button = find_child("BackButton", true, false) as Button

var _signals_connected: bool = false


func _ready() -> void:
	_resolve_nodes()
	if not _signals_connected:
		_setup_signals()
		_signals_connected = true

	var loc_mgr = _get_autoload("LocalizationManager")
	if loc_mgr and loc_mgr.has_signal("locale_changed"):
		if not loc_mgr.locale_changed.is_connected(_on_locale_changed):
			loc_mgr.locale_changed.connect(_on_locale_changed)

	update_localized_texts()
	hide()


func _resolve_nodes() -> void:
	if not title_label:
		title_label = find_child("TitleLabel", true, false) as Label
	if not language_label:
		language_label = find_child("LanguageLabel", true, false) as Label
	if not language_option:
		language_option = find_child("LanguageOption", true, false) as OptionButton
	if not master_label:
		master_label = find_child("MasterLabel", true, false) as Label
	if not master_slider:
		master_slider = find_child("MasterSlider", true, false) as HSlider
	if not music_label:
		music_label = find_child("MusicLabel", true, false) as Label
	if not music_slider:
		music_slider = find_child("MusicSlider", true, false) as HSlider
	if not sfx_label:
		sfx_label = find_child("SfxLabel", true, false) as Label
	if not sfx_slider:
		sfx_slider = find_child("SfxSlider", true, false) as HSlider
	if not display_label:
		display_label = find_child("DisplayLabel", true, false) as Label
	if not fullscreen_check:
		fullscreen_check = find_child("FullscreenCheck", true, false) as CheckBox
	if not reduce_motion_label:
		reduce_motion_label = find_child("ReduceMotionLabel", true, false) as Label
	if not reduce_motion_check:
		reduce_motion_check = find_child("ReduceMotionCheck", true, false) as CheckBox
	if not reduce_flash_label:
		reduce_flash_label = find_child("ReduceFlashLabel", true, false) as Label
	if not reduce_flash_check:
		reduce_flash_check = find_child("ReduceFlashCheck", true, false) as CheckBox
	if not back_button:
		back_button = find_child("BackButton", true, false) as Button


func _setup_signals() -> void:
	if language_option and not language_option.item_selected.is_connected(_on_language_selected):
		language_option.item_selected.connect(_on_language_selected)
	if master_slider and not master_slider.value_changed.is_connected(_on_master_changed):
		master_slider.value_changed.connect(_on_master_changed)
	if music_slider and not music_slider.value_changed.is_connected(_on_music_changed):
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider and not sfx_slider.value_changed.is_connected(_on_sfx_changed):
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if fullscreen_check and not fullscreen_check.toggled.is_connected(_on_fullscreen_toggled):
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if reduce_motion_check and not reduce_motion_check.toggled.is_connected(_on_reduce_motion_toggled):
		reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	if reduce_flash_check and not reduce_flash_check.toggled.is_connected(_on_reduce_flash_toggled):
		reduce_flash_check.toggled.connect(_on_reduce_flash_toggled)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func _get_autoload(autoload_name: String) -> Node:
	var root_node: Node = null
	if is_inside_tree() and get_tree():
		root_node = get_tree().root
	elif Engine.get_main_loop() is SceneTree:
		root_node = (Engine.get_main_loop() as SceneTree).root
	elif get_parent():
		var p = get_parent()
		while p.get_parent():
			p = p.get_parent()
		root_node = p

	if root_node:
		return root_node.get_node_or_null(autoload_name)
	return null


func open() -> void:
	_resolve_nodes()
	_sync_current_values()
	update_localized_texts()
	show()
	if language_option and language_option.is_inside_tree():
		language_option.grab_focus()
	elif master_slider and master_slider.is_inside_tree():
		master_slider.grab_focus()


func update_localized_texts() -> void:
	if title_label:
		title_label.text = tr("SETTINGS_TITLE")
	if language_label:
		language_label.text = tr("SETTINGS_LANGUAGE")
	if master_label:
		master_label.text = tr("SETTINGS_MASTER_VOL")
	if music_label:
		music_label.text = tr("SETTINGS_MUSIC_VOL")
	if sfx_label:
		sfx_label.text = tr("SETTINGS_SFX_VOL")
	if display_label:
		display_label.text = tr("SETTINGS_FULLSCREEN")
	if fullscreen_check:
		fullscreen_check.text = "✓" if fullscreen_check.button_pressed else "✕"
	if reduce_motion_label:
		reduce_motion_label.text = tr("SETTINGS_REDUCE_MOTION")
	if reduce_flash_label:
		reduce_flash_label.text = tr("SETTINGS_REDUCE_FLASH")
	if reduce_motion_check:
		reduce_motion_check.text = "✓" if reduce_motion_check.button_pressed else "✕"
	if reduce_flash_check:
		reduce_flash_check.text = "✓" if reduce_flash_check.button_pressed else "✕"
	if back_button:
		back_button.text = tr("BTN_BACK")

	var loc_mgr = _get_autoload("LocalizationManager")
	var cur_loc = "tr"
	if loc_mgr and loc_mgr.has_method("get_current_locale"):
		cur_loc = loc_mgr.get_current_locale()
	elif TranslationServer.get_locale().begins_with("en"):
		cur_loc = "en"
	if language_option:
		language_option.selected = 1 if cur_loc == "en" else 0


func _on_locale_changed(_new_locale: String) -> void:
	update_localized_texts()


func _sync_current_values() -> void:
	# Dil ayarı senkronizasyonu
	var loc_mgr = _get_autoload("LocalizationManager")
	var cur_loc = "tr"
	if loc_mgr and loc_mgr.has_method("get_current_locale"):
		cur_loc = loc_mgr.get_current_locale()
	elif TranslationServer.get_locale().begins_with("en"):
		cur_loc = "en"

	if language_option:
		language_option.selected = 1 if cur_loc == "en" else 0

	# Ses otobüsleri
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1 and master_slider:
		var db_val = AudioServer.get_bus_volume_db(master_idx)
		master_slider.value = db_to_linear(db_val) * 100.0

	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1 and music_slider:
		var db_val = AudioServer.get_bus_volume_db(music_idx)
		music_slider.value = db_to_linear(db_val) * 100.0
	elif music_slider:
		music_slider.value = 80.0

	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1 and sfx_slider:
		var db_val = AudioServer.get_bus_volume_db(sfx_idx)
		sfx_slider.value = db_to_linear(db_val) * 100.0
	elif sfx_slider:
		sfx_slider.value = 80.0

	if fullscreen_check:
		var mode = DisplayServer.window_get_mode()
		var is_full = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		fullscreen_check.button_pressed = is_full
		fullscreen_check.text = "✓" if is_full else "✕"

	# Erişilebilirlik seçenekleri (CinematicManager)
	var cm = _get_autoload("CinematicManager")
	if cm:
		if reduce_motion_check:
			reduce_motion_check.set_pressed_no_signal(cm.reduce_motion)
			reduce_motion_check.text = "✓" if cm.reduce_motion else "✕"
		if reduce_flash_check:
			reduce_flash_check.set_pressed_no_signal(cm.reduce_flashing)
			reduce_flash_check.text = "✓" if cm.reduce_flashing else "✕"


func _on_reduce_motion_toggled(pressed: bool) -> void:
	var cm = _get_autoload("CinematicManager")
	if cm:
		cm.set_reduce_motion(pressed)
	if reduce_motion_check:
		reduce_motion_check.text = "✓" if pressed else "✕"


func _on_reduce_flash_toggled(pressed: bool) -> void:
	var cm = _get_autoload("CinematicManager")
	if cm:
		cm.set_reduce_flashing(pressed)
	if reduce_flash_check:
		reduce_flash_check.text = "✓" if pressed else "✕"


func _on_language_selected(index: int) -> void:
	var loc = "en" if index == 1 else "tr"
	var loc_mgr = _get_autoload("LocalizationManager")
	if loc_mgr and loc_mgr.has_method("set_locale"):
		loc_mgr.set_locale(loc)
	else:
		TranslationServer.set_locale(loc)
	update_localized_texts()


func _on_master_changed(val: float) -> void:
	var idx = AudioServer.get_bus_index("Master")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(val / 100.0, 0.0001)))


func _on_music_changed(val: float) -> void:
	var idx = AudioServer.get_bus_index("Music")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(val / 100.0, 0.0001)))


func _on_sfx_changed(val: float) -> void:
	var idx = AudioServer.get_bus_index("SFX")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(val / 100.0, 0.0001)))


func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if fullscreen_check:
		fullscreen_check.text = "✓" if is_fullscreen else "✕"


func _on_back_pressed() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
