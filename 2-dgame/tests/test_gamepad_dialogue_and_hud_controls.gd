extends SceneTree

# Yamalı Dünya — Kapsamlı Gamepad Diyalog, Ara Sahne ve HUD Kontrolleri Doğrulama Testi
# Story 2D-157 / Joypad Button Mapping QA

var passed_count := 0
var total_count := 0

func _init() -> void:
	process_frame.connect(_on_first_frame)


func _on_first_frame() -> void:
	process_frame.disconnect(_on_first_frame)
	_run_suite()


func _run_suite() -> void:
	print("\n=================================================================")
	print(" YAMALI DÜNYA — GAMEPAD DİYALOG, SEÇENEK, ARA SAHNE & HUD TESTİ")
	print("=================================================================")
	
	await _test_dialogue_box_advance_and_choices()
	await _test_dialogue_box_skip()
	await _test_dialogue_box_prompts_and_glyphs()
	await _test_flashback_overlay_advance_and_skip()
	await _test_hud_potions_and_shortcuts()
	await _test_dialogs_tab_switching()
	await _test_player_weapon_draw_sheathe()
	
	print("\n=================================================================")
	if passed_count == total_count:
		print(" TEST SONUCU: TÜM KONTROLLER BAŞARILI! (%d / %d PASS)" % [passed_count, total_count])
		print("=================================================================\n")
		quit(0)
	else:
		printerr(" TEST SONUCU: BAZI TESTLER BAŞARISIZ! (%d / %d)" % [passed_count, total_count])
		print("=================================================================\n")
		quit(1)


func _test_dialogue_box_advance_and_choices() -> void:
	total_count += 1
	print("\n[TEST 1/7] DialogueBox: Joypad ile İlerleme ve Seçenek Seçimi")
	
	var dbox_scene = load("res://scenes/ui/dialogue_box.tscn")
	if not dbox_scene:
		printerr("  FAIL: dialogue_box.tscn yüklenemedi!")
		return
	var dbox = dbox_scene.instantiate()
	root.add_child(dbox)
	await process_frame
	
	var test_state := {"choice_action": ""}
	dbox.choice_selected.connect(func(act: String): test_state["choice_action"] = act)
	
	var entries: Array = [
		{
			"speaker": "Kumandan",
			"text": "Düşman surları aşıyor! Karar ver!",
			"choices": [
				{"text": "[1] Savunmaya Geç", "action": "defend"},
				{"text": "[2] Hücum Et", "action": "charge"}
			]
		}
	]
	dbox.start_dialogue(entries)
	await process_frame
	
	# Typewriter devam ederken Square (JOY_BUTTON_X) basılır -> Yazı anında tamamlanmalı
	var btn_square = InputEventJoypadButton.new()
	btn_square.button_index = JOY_BUTTON_X
	btn_square.pressed = true
	dbox._input(btn_square)
	await process_frame
	
	# Şimdi seçenekler aktif: Triangle (JOY_BUTTON_Y) basılır -> 2. Seçenek ('charge') seçilmeli
	var btn_triangle = InputEventJoypadButton.new()
	btn_triangle.button_index = JOY_BUTTON_Y
	btn_triangle.pressed = true
	dbox._input(btn_triangle)
	await process_frame
	
	if test_state["choice_action"] == "charge":
		print("  PASS: Joypad Square ile yazı tamamlandı, Triangle ile 2. seçenek ('charge') seçildi!")
		passed_count += 1
	else:
		printerr("  FAIL: Seçenek tetiklenmedi! Beklenen='charge', Alınan='%s'" % test_state["choice_action"])
		
	dbox.queue_free()
	await process_frame


func _test_dialogue_box_skip() -> void:
	total_count += 1
	print("\n[TEST 2/7] DialogueBox: Joypad ile Tamamen Atlama (SHARE / START)")
	
	var dbox_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dbox = dbox_scene.instantiate()
	root.add_child(dbox)
	await process_frame
	
	var test_state := {"dialogue_ended": false}
	dbox.dialogue_completed.connect(func(): test_state["dialogue_ended"] = true)
	
	var entries: Array = [
		{"speaker": "Fatih", "text": "Konuşma 1"},
		{"speaker": "Fatih", "text": "Konuşma 2"},
		{"speaker": "Fatih", "text": "Konuşma 3"}
	]
	dbox.start_dialogue(entries)
	await process_frame
	
	# SHARE (JOY_BUTTON_BACK) basarak tüm konuşmayı atla
	var btn_share = InputEventJoypadButton.new()
	btn_share.button_index = JOY_BUTTON_BACK
	btn_share.pressed = true
	dbox._input(btn_share)
	await process_frame
	
	if test_state["dialogue_ended"] and not dbox.is_dialogue_active():
		print("  PASS: Joypad SHARE (JOY_BUTTON_BACK) ile diyalog başarıyla atlandı ve sonlandı!")
		passed_count += 1
	else:
		printerr("  FAIL: Diyalog atlanamadı veya sonlanmadı! ended=%s, active=%s" % [test_state["dialogue_ended"], dbox.is_dialogue_active()])
		
	dbox.queue_free()
	await process_frame


func _test_dialogue_box_prompts_and_glyphs() -> void:
	total_count += 1
	print("\n[TEST 3/7] DialogueBox: Dinamik PlayStation / Gamepad Glifleri")
	
	var input_mgr = root.get_node_or_null("InputControllerManager")
	var dbox_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dbox = dbox_scene.instantiate()
	root.add_child(dbox)
	await process_frame
	
	var entries: Array = [
		{
			"speaker": "Ulak",
			"text": "Mektup geldi.",
			"choices": [
				{"text": "[1] Oku", "action": "read"},
				{"text": "[2] Yak", "action": "burn"}
			]
		}
	]
	
	# Gamepad şemasına ve PlayStation tipine zorla geçir
	if input_mgr:
		input_mgr.current_scheme = input_mgr.InputScheme.GAMEPAD
		input_mgr.current_gamepad_type = input_mgr.GamepadType.PLAYSTATION
		
	dbox.start_dialogue(entries)
	dbox._on_typing_finished()
	await process_frame
	
	var choice1_text = dbox.choice_btn_1.text if dbox.choice_btn_1 else ""
	var choice2_text = dbox.choice_btn_2.text if dbox.choice_btn_2 else ""
	var skip_btn = dbox.panel.get_node_or_null("SkipButton") as Button if dbox.panel else null
	var skip_text = skip_btn.text if skip_btn else ""
	var continue_text = dbox.continue_prompt.text if dbox.continue_prompt else ""
	
	print("  - Seçenek 1 Metni: %s" % choice1_text)
	print("  - Seçenek 2 Metni: %s" % choice2_text)
	print("  - Atla Butonu: %s" % skip_text)
	print("  - Devam İpucu: %s" % continue_text)
	
	var has_ps_glyphs = ("[▢]" in choice1_text) and ("[△]" in choice2_text) and ("SHARE" in skip_text)
	if has_ps_glyphs:
		print("  PASS: PlayStation glifleri ([▢], [△], SHARE) butonlara eksiksiz yansıtıldı!")
		passed_count += 1
	else:
		printerr("  FAIL: Glifler doğru yansıtılmadı!")
		
	dbox.queue_free()
	await process_frame


func _test_flashback_overlay_advance_and_skip() -> void:
	total_count += 1
	print("\n[TEST 4/7] FlashbackOverlay: Joypad ile İlerleme ve Atlama")
	
	var fback_scene = load("res://scenes/ui/flashback_overlay.tscn")
	if not fback_scene:
		printerr("  FAIL: flashback_overlay.tscn bulunamadı!")
		return
	var fback = fback_scene.instantiate()
	root.add_child(fback)
	await process_frame
	
	fback.play_vlad_memory_sequence()
	await process_frame
	
	# Cross (JOY_BUTTON_A) ile anıyı ilerlet
	var btn_cross = InputEventJoypadButton.new()
	btn_cross.button_index = JOY_BUTTON_A
	btn_cross.pressed = true
	fback._unhandled_input(btn_cross)
	await process_frame
	
	# Options / START (JOY_BUTTON_START) ile flashback'i atla
	var btn_options = InputEventJoypadButton.new()
	btn_options.button_index = JOY_BUTTON_START
	btn_options.pressed = true
	fback._unhandled_input(btn_options)
	await process_frame
	
	if not fback.is_playing():
		print("  PASS: FlashbackOverlay Joypad A ile ilerledi ve Joypad START ile başarıyla atlandı!")
		passed_count += 1
	else:
		printerr("  FAIL: FlashbackOverlay atlanamadı!")
		
	fback.queue_free()
	await process_frame


func _test_hud_potions_and_shortcuts() -> void:
	total_count += 1
	print("\n[TEST 5/7] FantasyHUD: Joypad D-Pad İksirleri ve Menü Kısayolları")
	
	var hud_scene = load("res://scenes/ui/fantasy_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	
	hud.max_health = 100
	hud.current_health = 40
	hud.health_potions = 2
	hud.max_mana = 100
	hud.current_mana = 30
	hud.mana_potions = 2
	
	# D-Pad Sol: Can İksiri İç
	var btn_dpad_left = InputEventJoypadButton.new()
	btn_dpad_left.button_index = JOY_BUTTON_DPAD_LEFT
	btn_dpad_left.pressed = true
	hud._unhandled_input(btn_dpad_left)
	await process_frame
	
	var hp_ok = (hud.current_health == 75) and (hud.health_potions == 1)
	
	# D-Pad Sağ: Mana İksiri İç
	var btn_dpad_right = InputEventJoypadButton.new()
	btn_dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	btn_dpad_right.pressed = true
	hud._unhandled_input(btn_dpad_right)
	await process_frame
	
	var mana_ok = (hud.current_mana == 50) and (hud.mana_potions == 1)
	
	# Joypad Y: Envanter Aç / Kapat
	var btn_y = InputEventJoypadButton.new()
	btn_y.button_index = JOY_BUTTON_Y
	btn_y.pressed = true
	hud._unhandled_input(btn_y)
	await process_frame
	
	var inv_opened = hud.inventory_dialog != null and hud.inventory_dialog.visible
	
	# Joypad B: Envanteri Kapat
	var btn_b = InputEventJoypadButton.new()
	btn_b.button_index = JOY_BUTTON_B
	btn_b.pressed = true
	hud._input(btn_b)
	await process_frame
	
	var inv_closed = hud.inventory_dialog != null and not hud.inventory_dialog.visible
	
	if hp_ok and mana_ok and inv_opened and inv_closed:
		print("  PASS: D-Pad Sol (Can İksiri), D-Pad Sağ (Mana İksiri), Y (Envanter Aç), B (Kapat) 100%% çalıştı!")
		passed_count += 1
	else:
		printerr("  FAIL: İksir veya Envanter kontrolleri başarısız! hp_ok=%s, mana_ok=%s, inv_opened=%s, inv_closed=%s" % [hp_ok, mana_ok, inv_opened, inv_closed])
		
	hud.queue_free()
	await process_frame


func _test_dialogs_tab_switching() -> void:
	total_count += 1
	print("\n[TEST 6/7] Menü & Dialog Sekme Değişimi: L1 / R1 Bumper Kontrolleri")
	
	var inv_scene = load("res://scenes/ui/inventory_dialog.tscn")
	var inv = inv_scene.instantiate()
	root.add_child(inv)
	await process_frame
	inv.open()
	await process_frame
	
	# R1 (JOY_BUTTON_RIGHT_SHOULDER) ile sekme değiştir: "items" -> "heart"
	var btn_r1 = InputEventJoypadButton.new()
	btn_r1.button_index = JOY_BUTTON_RIGHT_SHOULDER
	btn_r1.pressed = true
	inv._unhandled_input(btn_r1)
	await process_frame
	
	var inv_tab_ok = (inv._current_tab == "heart")
	
	# L1 (JOY_BUTTON_LEFT_SHOULDER) ile geri dön: "heart" -> "items"
	var btn_l1 = InputEventJoypadButton.new()
	btn_l1.button_index = JOY_BUTTON_LEFT_SHOULDER
	btn_l1.pressed = true
	inv._unhandled_input(btn_l1)
	await process_frame
	
	var inv_tab_back_ok = (inv._current_tab == "items")
	inv.close()
	inv.queue_free()
	await process_frame
	
	# QuestLogDialog Tab Test
	var quest_scene = load("res://scenes/ui/quest_log_dialog.tscn")
	var qlog = quest_scene.instantiate()
	root.add_child(qlog)
	await process_frame
	qlog.open()
	await process_frame
	
	qlog._unhandled_input(btn_r1)
	await process_frame
	var qlog_tab_ok = (qlog._current_tab == "completed")
	qlog.close()
	qlog.queue_free()
	await process_frame
	
	# CodexDialog Category Test
	var codex_scene = load("res://scenes/ui/codex_dialog.tscn")
	var codex = codex_scene.instantiate()
	root.add_child(codex)
	await process_frame
	codex.open()
	await process_frame
	var cat_initial = codex._current_category
	codex._unhandled_input(btn_r1)
	await process_frame
	var codex_tab_ok = (codex._current_category != cat_initial or codex._current_category == "monsters")
	codex.close()
	codex.queue_free()
	await process_frame
	
	if inv_tab_ok and inv_tab_back_ok and qlog_tab_ok and codex_tab_ok:
		print("  PASS: Envanter, Görev Günlüğü ve Kodeks pencerelerinde L1 / R1 ile sekme geçişi kusursuz çalışıyor!")
		passed_count += 1
	else:
		printerr("  FAIL: Sekme geçişi başarısız! inv=%s/%s, qlog=%s, codex=%s" % [inv_tab_ok, inv_tab_back_ok, qlog_tab_ok, codex_tab_ok])


func _test_player_weapon_draw_sheathe() -> void:
	total_count += 1
	print("\n[TEST 7/7] Player: Joypad L3 (Left Stick) ile Kılıç Çekme / Kınına Sokma")
	
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	
	player.has_sword = true
	player.is_armed = false
	
	# Joypad L3 (JOY_BUTTON_LEFT_STICK) bas
	var btn_l3 = InputEventJoypadButton.new()
	btn_l3.button_index = JOY_BUTTON_LEFT_STICK
	btn_l3.pressed = true
	player._unhandled_input(btn_l3)
	await process_frame
	
	var armed_first = player.is_armed # true olmalı
	
	# Tekrar bas
	player._unhandled_input(btn_l3)
	await process_frame
	var sheathed_second = not player.is_armed # true olmalı
	
	if armed_first and sheathed_second:
		print("  PASS: Joypad L3 tuşu kılıcı başarıyla çekti ve tekrar kınına soktu!")
		passed_count += 1
	else:
		printerr("  FAIL: Kılıç çekme/kın durumu hatalı! armed_first=%s, sheathed_second=%s" % [armed_first, sheathed_second])
		
	player.queue_free()
	await process_frame
