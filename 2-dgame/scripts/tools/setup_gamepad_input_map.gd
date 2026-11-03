extends SceneTree

# Yamalı Dünya — Input Map Gamepad Konfigürasyon Aracı
# project.godot içerisindeki [input] aksiyonlarını klavye, fare ve oyun kolu (Xbox, PS4, PS5, Steam Deck)
# standartlarına uygun şekilde eksiksiz yapılandırır.

func _init() -> void:
	print("[InputSetup] Gamepad ve klavye giriş haritası yapılandırılıyor...")
	
	_setup_action("move_left", 0.2, [
		_key(KEY_A), _key(KEY_LEFT),
		_joy_motion(JOY_AXIS_LEFT_X, -1.0),
		_joy_button(JOY_BUTTON_DPAD_LEFT)
	])
	
	_setup_action("move_right", 0.2, [
		_key(KEY_D), _key(KEY_RIGHT),
		_joy_motion(JOY_AXIS_LEFT_X, 1.0),
		_joy_button(JOY_BUTTON_DPAD_RIGHT)
	])
	
	_setup_action("move_down", 0.2, [
		_key(KEY_S), _key(KEY_DOWN),
		_joy_motion(JOY_AXIS_LEFT_Y, 1.0),
		_joy_button(JOY_BUTTON_DPAD_DOWN)
	])
	
	_setup_action("move_up", 0.2, [
		_key(KEY_W), _key(KEY_UP),
		_joy_motion(JOY_AXIS_LEFT_Y, -1.0),
		_joy_button(JOY_BUTTON_DPAD_UP)
	])
	
	_setup_action("jump", 0.3, [
		_key(KEY_SPACE), _key(KEY_W), _key(KEY_UP),
		_joy_button(JOY_BUTTON_A) # Cross (PS) / A (Xbox)
	])
	
	_setup_action("crouch", 0.3, [
		_key(KEY_CTRL), _key(KEY_C),
		_joy_button(JOY_BUTTON_RIGHT_STICK), # R3
		_joy_button(JOY_BUTTON_DPAD_DOWN)
	])
	
	_setup_action("dash", 0.3, [
		_key(KEY_SHIFT),
		_joy_button(JOY_BUTTON_B), # Circle (PS) / B (Xbox)
		_joy_button(JOY_BUTTON_LEFT_STICK) # L3
	])
	
	_setup_action("interact", 0.3, [
		_key(KEY_E),
		_joy_button(JOY_BUTTON_X), # Square (PS) / X (Xbox)
		_joy_button(JOY_BUTTON_Y)  # Triangle (PS) / Y (Xbox)
	])
	
	_setup_action("attack_light", 0.3, [
		_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J),
		_joy_button(JOY_BUTTON_X), # Square (PS) / X (Xbox)
		_joy_button(JOY_BUTTON_RIGHT_SHOULDER) # R1 (PS) / RB (Xbox)
	])
	
	_setup_action("attack_heavy", 0.3, [
		_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K),
		_joy_button(JOY_BUTTON_Y), # Triangle (PS) / Y (Xbox)
		_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0) # R2 (PS) / RT (Xbox)
	])
	
	_setup_action("toggle_shield", 0.3, [
		_key(KEY_3), _key(KEY_KP_3),
		_joy_button(JOY_BUTTON_LEFT_SHOULDER), # L1 (PS) / LB (Xbox)
		_joy_motion(JOY_AXIS_TRIGGER_LEFT, 1.0)  # L2 (PS) / LT (Xbox)
	])
	
	_setup_action("drop_item", 0.3, [
		_key(KEY_G),
		_joy_button(JOY_BUTTON_BACK) # Share (PS) / View/Back (Xbox)
	])
	
	_setup_action("throw_secondary", 0.3, [
		_key(KEY_F),
		_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0),
		_joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	])
	
	_setup_action("cycle_secondary", 0.3, [
		_key(KEY_Q),
		_joy_button(JOY_BUTTON_DPAD_UP)
	])
	
	_setup_action("pause", 0.3, [
		_key(KEY_ESCAPE), _key(KEY_P),
		_joy_button(JOY_BUTTON_START) # Options (PS) / Menu (Xbox)
	])
	
	_setup_action("ui_accept", 0.3, [
		_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE),
		_joy_button(JOY_BUTTON_A)
	])
	
	_setup_action("ui_cancel", 0.3, [
		_key(KEY_ESCAPE),
		_joy_button(JOY_BUTTON_B)
	])
	
	_setup_action("ui_up", 0.2, [
		_key(KEY_UP), _key(KEY_W),
		_joy_button(JOY_BUTTON_DPAD_UP),
		_joy_motion(JOY_AXIS_LEFT_Y, -1.0)
	])
	
	_setup_action("ui_down", 0.2, [
		_key(KEY_DOWN), _key(KEY_S),
		_joy_button(JOY_BUTTON_DPAD_DOWN),
		_joy_motion(JOY_AXIS_LEFT_Y, 1.0)
	])
	
	_setup_action("ui_left", 0.2, [
		_key(KEY_LEFT), _key(KEY_A),
		_joy_button(JOY_BUTTON_DPAD_LEFT),
		_joy_motion(JOY_AXIS_LEFT_X, -1.0)
	])
	
	_setup_action("ui_right", 0.2, [
		_key(KEY_RIGHT), _key(KEY_D),
		_joy_button(JOY_BUTTON_DPAD_RIGHT),
		_joy_motion(JOY_AXIS_LEFT_X, 1.0)
	])
	
	var err = ProjectSettings.save()
	if err == OK:
		print("[InputSetup] project.godot başarıyla kaydedildi!")
	else:
		printerr("[InputSetup] project.godot kaydedilirken hata oluştu: ", err)
	quit(0)


func _setup_action(name: String, deadzone: float, events: Array) -> void:
	var setting_name = "input/" + name
	var action_dict = {
		"deadzone": deadzone,
		"events": events
	}
	ProjectSettings.set_setting(setting_name, action_dict)


func _key(code: Key) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.physical_keycode = code
	ev.device = -1
	return ev


func _mouse(btn: MouseButton) -> InputEventMouseButton:
	var ev = InputEventMouseButton.new()
	ev.button_index = btn
	ev.device = -1
	return ev


func _joy_button(btn: JoyButton) -> InputEventJoypadButton:
	var ev = InputEventJoypadButton.new()
	ev.button_index = btn
	ev.device = -1
	return ev


func _joy_motion(axis: JoyAxis, val: float) -> InputEventJoypadMotion:
	var ev = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = val
	ev.device = -1
	return ev
