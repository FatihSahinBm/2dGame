extends PanelContainer

## res://scripts/ui/settings_dialog.gd
## Ayarlar Menüsü (Ses, Ekran ve Kontroller)

signal closed()

@onready var master_slider: HSlider = $Margin/VBox/Grid/MasterSlider
@onready var music_slider: HSlider = $Margin/VBox/Grid/MusicSlider
@onready var sfx_slider: HSlider = $Margin/VBox/Grid/SfxSlider
@onready var fullscreen_check: CheckBox = $Margin/VBox/Grid/FullscreenCheck
@onready var back_button: Button = $Margin/VBox/BackButton


func _ready() -> void:
	if master_slider:
		master_slider.value_changed.connect(_on_master_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	hide()


func open() -> void:
	_sync_current_values()
	show()
	if master_slider and master_slider.is_inside_tree():
		master_slider.grab_focus()


func _sync_current_values() -> void:
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
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


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


func _on_back_pressed() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
