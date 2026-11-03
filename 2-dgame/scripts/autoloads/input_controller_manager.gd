extends Node

## res://scripts/autoloads/input_controller_manager.gd
## Yamalı Dünya — Merkezi Oyun Kolu ve Giriş Yöneticisi (InputControllerManager)
## Story 2D-157: Oyun Kolu (Gamepad/Controller) Desteği
## - Xbox, PlayStation (PS4/PS5 DualShock/DualSense), Steam Deck ve Nintendo tespiti
## - Klavye/Fare ve Oyun Kolu arasında dinamik çift-giriş (Dual-Input) geçişi
## - Sol analog ve D-pad hareket desteği, ölü bölge (Deadzone) yönetimi
## - Titreşim (Haptic Vibration) geri bildirimi ve ayarlar entegrasyonu
## - Arayüz tuş ipucu (Prompt/Glyph) dinamik çevirisi
## - Kontrolcü takılma/çıkarılma olaylarında hata korumalı pürüzsüz çalışma

signal input_scheme_changed(scheme: int, device_name: String)
signal gamepad_type_changed(gamepad_type: int)
signal gamepad_connected(device_id: int, device_name: String)
signal gamepad_disconnected(device_id: int)
signal vibration_setting_changed(enabled: bool)

enum InputScheme {
	KEYBOARD_MOUSE = 0,
	GAMEPAD = 1
}

enum GamepadType {
	KEYBOARD_MOUSE = 0,
	XBOX = 1,
	PLAYSTATION = 2,
	STEAM_DECK = 3,
	NINTENDO = 4,
	GENERIC = 5
}

const SETTINGS_PATH: String = "user://game_settings.json"

@export var stick_deadzone: float = 0.18
@export var trigger_deadzone: float = 0.15
@export var vibration_enabled: bool = true
@export var vibration_strength_multiplier: float = 1.0

var current_scheme: InputScheme = InputScheme.KEYBOARD_MOUSE
var current_gamepad_type: GamepadType = GamepadType.KEYBOARD_MOUSE
var active_device_id: int = -1
var active_device_name: String = ""

# Bildirim afişi (Toast)
var _toast_label: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_ensure_input_map_actions()
	
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Başlangıçta bağlı oyun kolu var mı denetle
	var connected_pads := Input.get_connected_joypads()
	if not connected_pads.is_empty():
		active_device_id = connected_pads[0]
		active_device_name = Input.get_joy_name(active_device_id)
		current_gamepad_type = _detect_gamepad_type(active_device_id)
		current_scheme = InputScheme.GAMEPAD
		print("[InputManager] Başlangıçta oyun kolu algılandı: ID=%d, İsim=%s, Tip=%s" % [active_device_id, active_device_name, GamepadType.keys()[current_gamepad_type]])
	else:
		current_scheme = InputScheme.KEYBOARD_MOUSE
		current_gamepad_type = GamepadType.KEYBOARD_MOUSE
		print("[InputManager] Giriş modu: Klavye ve Fare")


func _input(event: InputEvent) -> void:
	# 1. Klavye veya Fare faaliyeti
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion:
		if event.relative.length_squared() > 25.0:
			_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
	
	# 2. Oyun Kolu faaliyeti
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			_on_joypad_activity(event.device)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > stick_deadzone:
			_on_joypad_activity(event.device)


func _on_joypad_activity(device_id: int) -> void:
	active_device_id = device_id
	active_device_name = Input.get_joy_name(device_id)
	var detected = _detect_gamepad_type(device_id)
	if current_gamepad_type != detected or current_scheme != InputScheme.GAMEPAD:
		current_gamepad_type = detected
		_set_input_scheme(InputScheme.GAMEPAD)


func _set_input_scheme(scheme: InputScheme) -> void:
	if current_scheme == scheme:
		return
	current_scheme = scheme
	if scheme == InputScheme.KEYBOARD_MOUSE:
		current_gamepad_type = GamepadType.KEYBOARD_MOUSE
	else:
		if active_device_id >= 0:
			current_gamepad_type = _detect_gamepad_type(active_device_id)
		else:
			current_gamepad_type = GamepadType.XBOX
	
	input_scheme_changed.emit(current_scheme, active_device_name if current_scheme == InputScheme.GAMEPAD else "Klavye / Fare")
	gamepad_type_changed.emit(current_gamepad_type)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		active_device_id = device_id
		active_device_name = Input.get_joy_name(device_id)
		current_gamepad_type = _detect_gamepad_type(device_id)
		_set_input_scheme(InputScheme.GAMEPAD)
		gamepad_connected.emit(device_id, active_device_name)
		_show_controller_toast("🎮 Kontrolcü Bağlandı: %s" % active_device_name)
		vibrate(0.4, 0.4, 0.15)
		print("[InputManager] Kontrolcü Bağlandı -> ID: %d, İsim: %s" % [device_id, active_device_name])
	else:
		gamepad_disconnected.emit(device_id)
		print("[InputManager] Kontrolcü Çıkarıldı -> ID: %d" % device_id)
		var remaining := Input.get_connected_joypads()
		if remaining.is_empty():
			active_device_id = -1
			active_device_name = ""
			_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
			_show_controller_toast("⚠️ Kontrolcü Ayrıldı (Klavye Moduna Geçildi)")
		else:
			active_device_id = remaining[0]
			active_device_name = Input.get_joy_name(active_device_id)
			current_gamepad_type = _detect_gamepad_type(active_device_id)


func _detect_gamepad_type(device_id: int) -> GamepadType:
	var joy_name := Input.get_joy_name(device_id).to_lower()
	var joy_info := Input.get_joy_info(device_id)
	var raw_name: String = str(joy_info.get("raw_name", "")).to_lower()
	var vendor_id: int = int(joy_info.get("vendor_id", 0))
	var combined := joy_name + " " + raw_name
	
	# PlayStation (Sony: 0x054C / 1356)
	if vendor_id == 1356 or combined.contains("ps4") or combined.contains("ps5") \
			or combined.contains("dualshock") or combined.contains("dualsense") \
			or combined.contains("sony") or combined.contains("playstation"):
		return GamepadType.PLAYSTATION
		
	# Steam Deck / Valve (Valve: 0x28DE / 10462)
	if vendor_id == 10462 or combined.contains("steam deck") or combined.contains("steam controller") \
			or combined.contains("neptune") or combined.contains("valve"):
		return GamepadType.STEAM_DECK
		
	# Nintendo (Nintendo: 0x057E / 1406)
	if vendor_id == 1406 or combined.contains("nintendo") or combined.contains("switch") \
			or combined.contains("joy-con") or combined.contains("pro controller"):
		return GamepadType.NINTENDO
		
	# Xbox / Microsoft (0x045E / 1118)
	if vendor_id == 1118 or combined.contains("xbox") or combined.contains("xinput"):
		return GamepadType.XBOX
		
	return GamepadType.GENERIC


# ---------------------------------------------------------------------------
# Titreşim (Haptic Vibration) Sistemi
# ---------------------------------------------------------------------------
func vibrate(weak: float = 0.5, strong: float = 0.5, duration: float = 0.2) -> void:
	if not vibration_enabled or duration <= 0.0:
		return
	var w = clampf(weak * vibration_strength_multiplier, 0.0, 1.0)
	var s = clampf(strong * vibration_strength_multiplier, 0.0, 1.0)
	
	if active_device_id >= 0:
		Input.start_joy_vibration(active_device_id, w, s, duration)
	else:
		for dev in Input.get_connected_joypads():
			Input.start_joy_vibration(dev, w, s, duration)


func stop_vibration() -> void:
	if active_device_id >= 0:
		Input.stop_joy_vibration(active_device_id)
	for dev in Input.get_connected_joypads():
		Input.stop_joy_vibration(dev)


func vibrate_light() -> void:
	vibrate(0.2, 0.1, 0.10)


func vibrate_medium() -> void:
	vibrate(0.4, 0.35, 0.16)


func vibrate_heavy() -> void:
	vibrate(0.85, 0.75, 0.25)


func vibrate_damage() -> void:
	vibrate(0.65, 0.90, 0.28)


func vibrate_parry() -> void:
	vibrate(1.0, 0.2, 0.12)


func set_vibration_enabled(enabled: bool) -> void:
	vibration_enabled = enabled
	vibration_setting_changed.emit(enabled)
	_save_settings()


func set_stick_deadzone(value: float) -> void:
	stick_deadzone = clampf(value, 0.05, 0.40)
	_save_settings()


# ---------------------------------------------------------------------------
# Karakter Hareketi & Analog Destek
# ---------------------------------------------------------------------------
func get_movement_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down", stick_deadzone)


func get_horizontal_axis() -> float:
	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) < stick_deadzone:
		return 0.0
	return axis


# ---------------------------------------------------------------------------
# Tuş İpucu ve Glif Çevirici (Prompt / Glyph Provider)
# ---------------------------------------------------------------------------
func get_action_prompt(action: String) -> String:
	if current_scheme == InputScheme.KEYBOARD_MOUSE:
		match action:
			"interact": return "[E]"
			"jump": return "[Boşluk]"
			"dash": return "[Shift]"
			"crouch": return "[Ctrl]"
			"attack_light": return "[Sol Tık / J]"
			"attack_heavy": return "[Sağ Tık / K]"
			"toggle_shield": return "[3]"
			"drop_item": return "[G]"
			"throw_secondary": return "[F]"
			"cycle_secondary": return "[Q]"
			"pause": return "[ESC]"
			_: return "[Tuş]"
	else:
		var is_ps := (current_gamepad_type == GamepadType.PLAYSTATION)
		var is_nintendo := (current_gamepad_type == GamepadType.NINTENDO)
		match action:
			"interact":
				return "[▢]" if is_ps else ("[Y]" if is_nintendo else "[X]")
			"jump":
				return "[✕]" if is_ps else ("[B]" if is_nintendo else "[A]")
			"dash":
				return "[◯]" if is_ps else ("[A]" if is_nintendo else "[B]")
			"crouch":
				return "[R3 / ↓]"
			"attack_light":
				return "[▢ / R1]" if is_ps else "[X / RB]"
			"attack_heavy":
				return "[△ / R2]" if is_ps else "[Y / RT]"
			"toggle_shield":
				return "[L1 / L2]" if is_ps else "[LB / LT]"
			"drop_item":
				return "[SHARE]" if is_ps else ("[MINUS]" if is_nintendo else "[VIEW]")
			"throw_secondary":
				return "[R2 / R1]" if is_ps else "[RT / RB]"
			"cycle_secondary":
				return "[D-Pad ↑]"
			"pause":
				return "[OPTIONS]" if is_ps else ("[PLUS]" if is_nintendo else "[MENU]")
			_:
				return "[Gamepad Tuşu]"


## Verilen metin içerisindeki klavye ipuçlarını otomatik olarak aktif kontrolcüye uyarlar
func format_prompt(text: String) -> String:
	if current_scheme == InputScheme.KEYBOARD_MOUSE:
		return text
		
	var is_ps := (current_gamepad_type == GamepadType.PLAYSTATION)
	var formatted := text
	if is_ps:
		formatted = formatted.replace("[E]", "[▢]")
		formatted = formatted.replace("[Space]", "[✕]")
		formatted = formatted.replace("[Boşluk]", "[✕]")
		formatted = formatted.replace("[Shift]", "[◯]")
		formatted = formatted.replace("[Sol Tık]", "[▢ / R1]")
		formatted = formatted.replace("[Sağ Tık]", "[△ / R2]")
		formatted = formatted.replace("[Ctrl]", "[R3]")
		formatted = formatted.replace("[ESC]", "[OPTIONS]")
		formatted = formatted.replace("[G]", "[SHARE]")
		formatted = formatted.replace("[3]", "[L1]")
		formatted = formatted.replace("[F]", "[R2]")
		formatted = formatted.replace("[Q]", "[D-Pad ↑]")
	else:
		formatted = formatted.replace("[E]", "[X]")
		formatted = formatted.replace("[Space]", "[A]")
		formatted = formatted.replace("[Boşluk]", "[A]")
		formatted = formatted.replace("[Shift]", "[B]")
		formatted = formatted.replace("[Sol Tık]", "[X / RB]")
		formatted = formatted.replace("[Sağ Tık]", "[Y / RT]")
		formatted = formatted.replace("[Ctrl]", "[R3]")
		formatted = formatted.replace("[ESC]", "[START]")
		formatted = formatted.replace("[G]", "[VIEW]")
		formatted = formatted.replace("[3]", "[LB]")
		formatted = formatted.replace("[F]", "[RT]")
		formatted = formatted.replace("[Q]", "[D-Pad ↑]")
	return formatted


# ---------------------------------------------------------------------------
# Kontrolcü Bildirim Afişi (Toast Overlay)
# ---------------------------------------------------------------------------
func _show_controller_toast(message: String) -> void:
	var tree := get_tree()
	if not tree or not tree.root:
		return
		
	if not _toast_label or not is_instance_valid(_toast_label):
		_toast_label = Label.new()
		_toast_label.name = "ControllerToast"
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
		_toast_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 1.0))
		_toast_label.add_theme_constant_override("outline_size", 4)
		_toast_label.add_theme_font_size_override("font_size", 14)
		_toast_label.z_index = 2000
		tree.root.add_child(_toast_label)
		
	_toast_label.text = message
	_toast_label.modulate.a = 0.0
	_toast_label.position = Vector2(tree.root.size.x * 0.5 - 200, 36)
	_toast_label.size = Vector2(400, 30)
	
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
		
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------------------
# Kalıcılık (user://game_settings.json)
# ---------------------------------------------------------------------------
func _save_settings() -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var rf := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if rf:
			var json := JSON.new()
			if json.parse(rf.get_as_text()) == OK and json.data is Dictionary:
				existing = json.data
			rf.close()
			
	var controller_data := {
		"vibration_enabled": vibration_enabled,
		"stick_deadzone": stick_deadzone,
		"trigger_deadzone": trigger_deadzone,
		"vibration_strength": vibration_strength_multiplier
	}
	existing["controller_settings"] = controller_data
	
	var wf := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))
		wf.close()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		var ctrl: Dictionary = json.data.get("controller_settings", {})
		if ctrl.has("vibration_enabled"):
			vibration_enabled = bool(ctrl["vibration_enabled"])
		if ctrl.has("stick_deadzone"):
			stick_deadzone = clampf(float(ctrl["stick_deadzone"]), 0.05, 0.40)
		if ctrl.has("trigger_deadzone"):
			trigger_deadzone = clampf(float(ctrl["trigger_deadzone"]), 0.05, 0.40)
		if ctrl.has("vibration_strength"):
			vibration_strength_multiplier = clampf(float(ctrl["vibration_strength"]), 0.0, 2.0)
	f.close()


# ---------------------------------------------------------------------------
# Çalışma Zamanı InputMap Güvenlik Doğrulaması
# ---------------------------------------------------------------------------
func _ensure_input_map_actions() -> void:
	# Eğer çalışma zamanında InputMap aksiyonları eksik kalırsa tamamlar
	var required_actions: Array[String] = [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "dash", "crouch", "interact", "attack_light",
		"attack_heavy", "toggle_shield", "drop_item", "throw_secondary",
		"cycle_secondary", "pause", "ui_accept", "ui_cancel",
		"ui_up", "ui_down", "ui_left", "ui_right"
	]
	for action in required_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
