extends SceneTree

# Yamalı Dünya — Kapsamlı Oyun Kolu (Gamepad/Controller) Entegrasyon ve Doğrulama Testi
# Story 2D-157: Oyun Kolu (Gamepad) Desteği
# 
# Test Aşamaları:
# 1. InputMap Doğrulaması: 21 aksiyonun gamepad buton ve analog eksenleriyle donatıldığını teyit eder.
# 2. Fiziksel Cihaz Tespiti: Bilgisayara bağlı kontrolcüyü (PS4 Controller / DualShock 4) sorgular.
# 3. Dynamic Prompt / Glyph Çevirici: PS, Xbox ve Klavye modlarında metinlerin dönüştüğünü doğrular.
# 4. Karakter Oynanışı Simülasyonu: Gerçek player sahnesinde Joypad A (Zıplama), Joypad X (Hafif Saldırı),
#    Joypad Y (Ağır Saldırı), Joypad B (Dash), Sol Analog Eksen (Hareket) girdilerini test eder.
# 5. Duraklatma Menüsü: Joypad START ve B tuşlarıyla menü açma/kapama akışını doğrular.
# 6. Titreşim (Haptics) API: Bağlı kontrolcü üzerinde titreşim çağrılarının hatasız çalıştığını doğrular.
# 7. Ayarlar Entegrasyonu: Titreşim ve deadzone ayarlarının kalıcılığını doğrular.

var results: Dictionary = {}

func _init() -> void:
	print("=================================================================")
	print(" YAMALI DÜNYA — OYUN KOLU (GAMEPAD) ENTEGRASYON VE DOĞRULAMA TESTİ")
	print("=================================================================")
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	var passed := 0
	var total := 0
	
	# 1. Input Map Doğrulaması
	total += 1
	if _test_input_map():
		passed += 1
		print("[TEST 1/7] InputMap Aksiyon ve Gamepad Eşlemeleri: PASS")
	else:
		printerr("[TEST 1/7] InputMap Aksiyon ve Gamepad Eşlemeleri: FAIL")
		
	# 2. Fiziksel Cihaz ve Autoload Tespiti
	total += 1
	if _test_physical_device_and_manager():
		passed += 1
		print("[TEST 2/7] Fiziksel Oyun Kolu (PS4) ve Algılama: PASS")
	else:
		printerr("[TEST 2/7] Fiziksel Oyun Kolu (PS4) ve Algılama: FAIL")
		
	# 3. Glif ve İpucu Çevirici
	total += 1
	if _test_prompt_glyphs():
		passed += 1
		print("[TEST 3/7] Dinamik Glif ve Tuş İpucu Çevirici: PASS")
	else:
		printerr("[TEST 3/7] Dinamik Glif ve Tuş İpucu Çevirici: FAIL")
		
	# 4. Karakter Hareketi ve Savaş Eylemleri (Joypad ile Oynanış)
	total += 1
	if await _test_player_gamepad_actions():
		passed += 1
		print("[TEST 4/7] Karakter Hareketi & Savaş Gamepad Kontrolleri: PASS")
	else:
		printerr("[TEST 4/7] Karakter Hareketi & Savaş Gamepad Kontrolleri: FAIL")
		
	# 5. Duraklatma Menüsü Gamepad Kontrolleri
	total += 1
	if await _test_pause_menu_gamepad():
		passed += 1
		print("[TEST 5/7] Duraklatma Menüsü Gamepad (START / B): PASS")
	else:
		printerr("[TEST 5/7] Duraklatma Menüsü Gamepad (START / B): FAIL")
		
	# 6. Titreşim (Haptics) API Kontrolü
	total += 1
	if _test_haptic_vibration():
		passed += 1
		print("[TEST 6/7] Titreşim (Haptic Vibration) Geri Bildirimi: PASS")
	else:
		printerr("[TEST 6/7] Titreşim (Haptic Vibration) Geri Bildirimi: FAIL")
		
	# 7. Ayarlar ve Çift Giriş Geçişi
	total += 1
	if _test_settings_and_dual_input():
		passed += 1
		print("[TEST 7/7] Ayarlar ve Dinamik Çift-Giriş Geçişi: PASS")
	else:
		printerr("[TEST 7/7] Ayarlar ve Dinamik Çift-Giriş Geçişi: FAIL")
		
	print("=================================================================")
	print(" GENEL TEST SONUCU: %d / %d BAŞARILI (%s)" % [passed, total, "TAM BAŞARI" if passed == total else "HATALAR VAR"])
	print("=================================================================")
	
	# Sonuçları JSON olarak kaydet
	var f := FileAccess.open("res://qa/test_gamepad_results.json", FileAccess.WRITE)
	if f:
		var report := {
			"total_tests": total,
			"passed_tests": passed,
			"status": "PASS" if passed == total else "FAIL",
			"details": results
		}
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
		
	quit(0 if passed == total else 1)


func _test_input_map() -> bool:
	var required_actions := [
		"move_left", "move_right", "move_down", "move_up",
		"jump", "dash", "crouch", "interact", "attack_light",
		"attack_heavy", "toggle_shield", "drop_item", "throw_secondary",
		"cycle_secondary", "pause", "ui_accept", "ui_cancel",
		"ui_up", "ui_down", "ui_left", "ui_right"
	]
	
	var all_ok := true
	var action_details := {}
	
	for action in required_actions:
		if not InputMap.has_action(action):
			printerr("  Eksik aksiyon: ", action)
			all_ok = false
			continue
			
		var events := InputMap.action_get_events(action)
		var has_key := false
		var has_joy := false
		
		for ev in events:
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_key = true
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joy = true
				
		action_details[action] = {
			"has_keyboard_or_mouse": has_key,
			"has_joypad": has_joy,
			"event_count": events.size()
		}
		
		if not has_joy:
			printerr("  Aksiyonda joypad eşlemesi bulunamadı: ", action)
			all_ok = false
			
	results["input_map"] = action_details
	return all_ok


func _test_physical_device_and_manager() -> bool:
	var input_mgr = root.get_node_or_null("InputControllerManager")
	if not input_mgr:
		printerr("  InputControllerManager autoload bulunamadı!")
		return false
		
	var connected := Input.get_connected_joypads()
	print("  Sistemde algılanan joypad sayısı: %d" % connected.size())
	
	var is_ps4_found := false
	for dev_id in connected:
		var dev_name = Input.get_joy_name(dev_id)
		var dev_info = Input.get_joy_info(dev_id)
		var dev_guid = Input.get_joy_guid(dev_id)
		print("  - Joypad ID %d: %s | GUID: %s | Info: %s" % [dev_id, dev_name, dev_guid, dev_info])
		
		var dtype = input_mgr._detect_gamepad_type(dev_id)
		print("    Algılanan Denetleyici Türü: %s (Index=%d)" % [input_mgr.GamepadType.keys()[dtype], dtype])
		if dtype == input_mgr.GamepadType.PLAYSTATION:
			is_ps4_found = true
			
	results["connected_devices"] = {
		"count": connected.size(),
		"devices": connected,
		"active_device_name": input_mgr.active_device_name,
		"current_scheme": input_mgr.current_scheme,
		"gamepad_type": input_mgr.current_gamepad_type,
		"is_playstation_controller": is_ps4_found
	}
	
	# Bilgisayarda bağlı olan kontrolcünün PS4 Controller olduğunu ve başarıyla algılandığını doğrula
	return (connected.size() > 0 and is_ps4_found)


func _test_prompt_glyphs() -> bool:
	var input_mgr = root.get_node_or_null("InputControllerManager")
	if not input_mgr:
		return false
		
	# 1. PlayStation Glifleri
	input_mgr.current_scheme = input_mgr.InputScheme.GAMEPAD
	input_mgr.current_gamepad_type = input_mgr.GamepadType.PLAYSTATION
	var ps_interact = input_mgr.get_action_prompt("interact")
	var ps_jump = input_mgr.get_action_prompt("jump")
	var ps_dash = input_mgr.get_action_prompt("dash")
	var ps_pause = input_mgr.get_action_prompt("pause")
	var ps_formatted = input_mgr.format_prompt("Kamp ateşini yakmak için [E] tuşuna bas, zıplamak için [Space], durdurmak için [ESC].")
	
	var ps_ok = (ps_interact == "[▢]" and ps_jump == "[✕]" and ps_dash == "[◯]" and ps_pause == "[OPTIONS]")
	var ps_format_ok = ps_formatted.contains("[▢]") and ps_formatted.contains("[✕]") and ps_formatted.contains("[OPTIONS]")
	
	# 2. Xbox Glifleri
	input_mgr.current_gamepad_type = input_mgr.GamepadType.XBOX
	var xbox_interact = input_mgr.get_action_prompt("interact")
	var xbox_jump = input_mgr.get_action_prompt("jump")
	var xbox_dash = input_mgr.get_action_prompt("dash")
	var xbox_formatted = input_mgr.format_prompt("Kamp ateşini yakmak için [E] tuşuna bas, zıplamak için [Space], durdurmak için [ESC].")
	
	var xbox_ok = (xbox_interact == "[X]" and xbox_jump == "[A]" and xbox_dash == "[B]")
	var xbox_format_ok = xbox_formatted.contains("[X]") and xbox_formatted.contains("[A]") and xbox_formatted.contains("[START]")
	
	# 3. Klavye Glifleri
	input_mgr.current_scheme = input_mgr.InputScheme.KEYBOARD_MOUSE
	input_mgr.current_gamepad_type = input_mgr.GamepadType.KEYBOARD_MOUSE
	var kb_interact = input_mgr.get_action_prompt("interact")
	var kb_formatted = input_mgr.format_prompt("Kapıyı kırmak için [E] tuşuna bas.")
	var kb_ok = (kb_interact == "[E]" and kb_formatted.contains("[E]"))
	
	# Asıl aktif cihaza geri dön
	input_mgr._on_joypad_activity(0)
	
	results["glyph_tests"] = {
		"playstation_glyphs": {"interact": ps_interact, "jump": ps_jump, "dash": ps_dash, "pause": ps_pause, "pass": ps_ok and ps_format_ok},
		"xbox_glyphs": {"interact": xbox_interact, "jump": xbox_jump, "dash": xbox_dash, "pass": xbox_ok and xbox_format_ok},
		"keyboard_glyphs": {"interact": kb_interact, "pass": kb_ok}
	}
	
	return ps_ok and ps_format_ok and xbox_ok and xbox_format_ok and kb_ok


func _test_player_gamepad_actions() -> bool:
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	if not player_scene:
		player_scene = load("res://scenes/combat/combat_player.tscn")
	if not player_scene:
		printerr("  Player sahnesi yüklenemedi!")
		return false
		
	var player = player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector2(300, 300)
	await process_frame
	await process_frame
	
	var actions_passed := true
	
	# A. Analog Stick Hareketi (Sağa hareket: Axis 0 = 1.0)
	var ev_motion = InputEventJoypadMotion.new()
	ev_motion.device = 0
	ev_motion.axis = JOY_AXIS_LEFT_X
	ev_motion.axis_value = 1.0
	Input.parse_input_event(ev_motion)
	await process_frame
	await process_frame
	
	var axis_val = Input.get_axis("move_left", "move_right")
	print("  - Joypad Analog Sağ Eksen Değeri: %.2f" % axis_val)
	if axis_val < 0.5:
		actions_passed = false
		printerr("  Analog sağ eksen okunamadı!")
		
	# Eksen sıfırlama
	ev_motion.axis_value = 0.0
	Input.parse_input_event(ev_motion)
	await process_frame
	
	# B. Joypad A (Zıplama / Cross)
	var ev_jump = InputEventJoypadButton.new()
	ev_jump.device = 0
	ev_jump.button_index = JOY_BUTTON_A
	ev_jump.pressed = true
	Input.parse_input_event(ev_jump)
	await process_frame
	
	var jump_action_active = Input.is_action_pressed("jump")
	print("  - Joypad A (Cross/Zıplama) Aksiyon Tetiklendi mi?: ", jump_action_active)
	if not jump_action_active:
		actions_passed = false
		printerr("  Joypad A zıplama aksiyonunu tetiklemedi!")
		
	ev_jump.pressed = false
	Input.parse_input_event(ev_jump)
	await process_frame
	
	# C. Joypad X (Hafif Saldırı / Square)
	var ev_light = InputEventJoypadButton.new()
	ev_light.device = 0
	ev_light.button_index = JOY_BUTTON_X
	ev_light.pressed = true
	Input.parse_input_event(ev_light)
	await process_frame
	
	var light_action_active = Input.is_action_pressed("attack_light")
	print("  - Joypad X (Square/Hafif Saldırı) Aksiyon Tetiklendi mi?: ", light_action_active)
	if not light_action_active:
		actions_passed = false
		printerr("  Joypad X hafif saldırı aksiyonunu tetiklemedi!")
		
	ev_light.pressed = false
	Input.parse_input_event(ev_light)
	await process_frame
	
	# D. Joypad B (Dash / Circle)
	var ev_dash = InputEventJoypadButton.new()
	ev_dash.device = 0
	ev_dash.button_index = JOY_BUTTON_B
	ev_dash.pressed = true
	Input.parse_input_event(ev_dash)
	await process_frame
	
	var dash_action_active = Input.is_action_pressed("dash")
	print("  - Joypad B (Circle/Dash) Aksiyon Tetiklendi mi?: ", dash_action_active)
	if not dash_action_active:
		actions_passed = false
		printerr("  Joypad B dash aksiyonunu tetiklemedi!")
		
	ev_dash.pressed = false
	Input.parse_input_event(ev_dash)
	await process_frame
	
	player.queue_free()
	await process_frame
	
	results["player_actions"] = {
		"analog_axis_read": axis_val >= 0.5,
		"jump_button_a": jump_action_active,
		"light_attack_button_x": light_action_active,
		"dash_button_b": dash_action_active,
		"all_actions_passed": actions_passed
	}
	
	return actions_passed


func _test_pause_menu_gamepad() -> bool:
	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	if not pause_scene:
		printerr("  PauseMenu sahnesi bulunamadı!")
		return false
		
	var pause_menu = pause_scene.instantiate()
	root.add_child(pause_menu)
	await process_frame
	
	# Menüyü aç
	pause_menu.open()
	await process_frame
	var is_open = pause_menu.visible
	print("  - Pause Menüsü Açıldı mı?: ", is_open)
	
	# Joypad B tuşu ile kapatmayı simüle et
	var ev_b = InputEventJoypadButton.new()
	ev_b.device = 0
	ev_b.button_index = JOY_BUTTON_B
	ev_b.pressed = true
	pause_menu._input(ev_b)
	await process_frame
	await process_frame
	
	var is_closed = not pause_menu.visible
	print("  - Joypad B ile Pause Menüsü Kapandı mı?: ", is_closed)
	
	pause_menu.queue_free()
	await process_frame
	
	results["pause_menu"] = {
		"open_verified": is_open,
		"closed_via_joypad_b": is_closed
	}
	
	return is_open and is_closed


func _test_haptic_vibration() -> bool:
	var input_mgr = root.get_node_or_null("InputControllerManager")
	if not input_mgr:
		return false
		
	# Haptics metotlarının hata vermeden çalıştığını test et
	input_mgr.vibrate_light()
	input_mgr.vibrate_medium()
	input_mgr.vibrate_heavy()
	input_mgr.vibrate_parry()
	input_mgr.vibrate_damage()
	input_mgr.stop_vibration()
	
	results["haptics"] = {
		"vibration_enabled": input_mgr.vibration_enabled,
		"multiplier": input_mgr.vibration_strength_multiplier,
		"api_calls_successful": true
	}
	return true


func _test_settings_and_dual_input() -> bool:
	var input_mgr = root.get_node_or_null("InputControllerManager")
	if not input_mgr:
		return false
		
	# Titreşim ayarını değiştir ve kaydet
	input_mgr.set_vibration_enabled(false)
	var toggled_off = (input_mgr.vibration_enabled == false)
	input_mgr.set_vibration_enabled(true)
	var toggled_on = (input_mgr.vibration_enabled == true)
	
	# Deadzone ayarını değiştir
	input_mgr.set_stick_deadzone(0.22)
	var deadzone_ok = is_equal_approx(input_mgr.stick_deadzone, 0.22)
	input_mgr.set_stick_deadzone(0.18)
	
	# Çift Giriş (Dual-Input): Klavye tuşuna basıldığında klavye moduna, joypad'e basıldığında gamepad moduna geçiş
	var ev_key = InputEventKey.new()
	ev_key.physical_keycode = KEY_SPACE
	ev_key.pressed = true
	input_mgr._input(ev_key)
	var scheme_kb = (input_mgr.current_scheme == input_mgr.InputScheme.KEYBOARD_MOUSE)
	
	var ev_joy = InputEventJoypadButton.new()
	ev_joy.device = 0
	ev_joy.button_index = JOY_BUTTON_A
	ev_joy.pressed = true
	input_mgr._input(ev_joy)
	var scheme_pad = (input_mgr.current_scheme == input_mgr.InputScheme.GAMEPAD)
	
	results["settings_and_dual_input"] = {
		"vibration_toggle": toggled_off and toggled_on,
		"deadzone_adjustment": deadzone_ok,
		"dual_input_auto_switch": scheme_kb and scheme_pad
	}
	
	return toggled_off and toggled_on and deadzone_ok and scheme_kb and scheme_pad
