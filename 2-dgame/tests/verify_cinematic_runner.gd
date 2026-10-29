extends Node

## tests/verify_cinematic_runner.gd
## Story 2D-145: Hafıza Yankıları ve Sinematik Geçişler doğrulama testi

var ok: bool = true

func _check(cond: bool, pass_msg: String, fail_msg: String) -> void:
	if cond:
		print("PASS: ", pass_msg)
	else:
		printerr("FAIL: ", fail_msg)
		ok = false


func _make_player() -> CharacterBody2D:
	var p = load("res://scenes/combat/test_player.tscn").instantiate()
	add_child(p)
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	p.add_child(cam)
	return p


func _ready() -> void:
	print("\n========================================================")
	print("  TEST: Story 2D-145 Hafıza Yankıları & Sinematik Geçişler ")
	print("========================================================")

	var cm = get_node_or_null("/root/CinematicManager")
	var gs = get_node_or_null("/root/GameState")
	if not cm or not gs:
		printerr("FAIL: CinematicManager / GameState autoload bulunamadı!")
		get_tree().quit(1)
		return
	cm.set_reduce_motion(false)
	cm.set_reduce_flashing(false)
	gs.reset_state()

	var player = _make_player()
	await get_tree().process_frame

	# --- 1. CinematicManager girdi kilidi ---
	print("\n--- Test 1: Girdi kilidi ve geri açma ---")
	cm.begin_cinematic("t1")
	_check(not player.can_move and gs.is_in_cinematic and cm.is_active(), "Sinematik başlayınca oyuncu girdileri kilitlendi.", "Girdi kilitlenmedi!")
	cm.begin_cinematic("t2")
	cm.end_cinematic("t1")
	_check(not player.can_move, "Çakışan ikinci kaynak varken kilit korunuyor (ref sayımı).", "Kilit erken açıldı!")
	cm.end_cinematic("t2")
	_check(player.can_move and not gs.is_in_cinematic and not cm.is_active(), "Tüm kaynaklar bitince kontroller geri açıldı.", "Kontroller geri açılmadı!")

	# --- 2. Flashback: kilit, filtre, letterbox, yankı ---
	print("\n--- Test 2: Flashback overlay (filtre, letterbox, yankı, kilit) ---")
	var fb = load("res://scenes/ui/flashback_overlay.tscn").instantiate()
	add_child(fb)
	fb.play_vlad_memory_sequence()
	await get_tree().create_timer(1.5).timeout
	_check(fb.is_playing() and fb.visible, "Flashback oynuyor.", "Flashback başlamadı!")
	_check(not player.can_move and gs.is_in_cinematic, "Flashback sırasında oynanış girdileri devre dışı.", "Flashback sırasında girdiler açık!")
	_check(fb.get_filter_amount() > 0.95, "Görsel filtre (desatürasyon/soğuk ton) uygulandı: " + str(fb.get_filter_amount()), "Görsel filtre uygulanmadı!")
	_check(fb.get_letterbox_amount() > 50.0, "Letterbox çubukları açıldı: " + str(fb.get_letterbox_amount()), "Letterbox açılmadı!")
	_check(fb._echo_label != null and is_instance_valid(fb._echo_label), "Diyalogda yankı efekti gösteriliyor.", "Yankı efekti yok!")

	# Atlama
	var finished_box = [0]
	fb.flashback_finished.connect(func(): finished_box[0] += 1)
	fb.skip_flashback()
	await get_tree().process_frame
	_check(finished_box[0] == 1, "Atlama flashback_finished sinyalini bir kez yayar.", "flashback_finished sayısı: " + str(finished_box[0]))
	_check(player.can_move and not gs.is_in_cinematic, "Atlamada kontroller geri açıldı.", "Atlamada kontroller kapalı kaldı!")
	_check(fb.get_filter_amount() == 0.0 and fb.get_letterbox_amount() == 0.0 and not fb.visible, "Atlamada filtre/letterbox/overlay sıfırlandı.", "Atlamada görsel durum sıfırlanmadı!")
	_check(gs.has_ability("blood_mist_dash"), "Atlansa bile yetenek ödülü verildi.", "Yetenek verilmedi!")
	fb.skip_flashback()
	_check(finished_box[0] == 1, "Çift atlama güvenli (tek bitiş).", "Çift bitiş yayıldı!")

	# --- 3. Normal tamamlanma ---
	print("\n--- Test 3: Normal tamamlanma ---")
	gs.reset_state()
	fb.play_vlad_memory_sequence()
	await get_tree().create_timer(0.3).timeout
	var guard := 0
	while fb.get_stage_name() == "MEMORY" and guard < 20:
		fb._is_typing = false
		fb._advance_memory()
		guard += 1
	_check(fb.get_stage_name() == "ABILITY" and gs.has_ability("blood_mist_dash"), "Hafıza satırları bitince yetenek kartı gösterildi.", "Yetenek aşamasına geçilemedi: " + fb.get_stage_name())
	_check(not player.can_move, "Yetenek kartı sırasında da girdiler kilitli.", "Kart sırasında girdiler açık!")
	await get_tree().create_timer(5.6).timeout
	_check(finished_box[0] == 2 and fb.get_stage_name() == "DONE", "Normal akış flashback_finished ile bitti.", "Normal akış bitmedi: " + fb.get_stage_name())
	_check(player.can_move and not gs.is_in_cinematic, "Normal bitişte kontroller geri açıldı.", "Normal bitişte kontroller kapalı!")
	_check(fb.get_filter_amount() == 0.0 and fb.get_letterbox_amount() == 0.0 and not fb.visible, "Normal bitişte filtre/letterbox/overlay sıfırlandı.", "Normal bitişte görsel durum sıfırlanmadı!")
	fb.queue_free()

	# --- 4. Diyalog kutusu: yankı, atlama, sıfırlama ---
	print("\n--- Test 4: Diyalog yankısı ve atlama ---")
	var db = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(db)
	await get_tree().process_frame
	var comp_box = [0]
	db.dialogue_completed.connect(func(): comp_box[0] += 1)
	db.start_dialogue([
		{"speaker": "A", "title": "", "text": "Yankılı satır", "portrait": "player", "echo": true},
		{"speaker": "B", "title": "", "text": "İkinci satır", "portrait": "player"}
	])
	await get_tree().process_frame
	_check(not player.can_move and gs.is_in_cinematic and db.is_dialogue_active(), "Diyalog sırasında girdiler kilitli.", "Diyalogda girdiler açık!")
	_check(db._echo_label != null and is_instance_valid(db._echo_label), "Echo işaretli diyalog satırında yankı efekti var.", "Diyalog yankısı yok!")
	db.skip_dialogue()
	await get_tree().process_frame
	_check(comp_box[0] == 1 and player.can_move and not gs.is_in_cinematic, "Diyalog atlanınca kontroller geri açıldı ve tamamlandı sinyali yayıldı.", "Diyalog atlama sonrası durum hatalı!")
	_check(db._echo_label == null, "Diyalog bitince yankı temizlendi.", "Yankı temizlenmedi!")

	# Normal tamamlanma
	db.start_dialogue([{"speaker": "A", "title": "", "text": "Tek", "portrait": "player"}])
	await get_tree().process_frame
	db._is_typing = false
	db._advance_dialogue()
	await get_tree().process_frame
	_check(comp_box[0] == 2 and player.can_move, "Diyalog normal bitince kontroller açık.", "Normal diyalog bitişinde kontrol kapalı!")

	# --- 5. Sahne yeniden başlatma / atlama ---
	print("\n--- Test 5: Sahne yeniden başlatma / atlama ---")
	var fb2 = load("res://scenes/ui/flashback_overlay.tscn").instantiate()
	add_child(fb2)
	fb2.play_vlad_memory_sequence()
	await get_tree().process_frame
	_check(not player.can_move, "Flashback ikinci kez başlatıldı, girdi kilitli.", "Kilit yok!")
	fb2.free()  # sahne yeniden başlatma simülasyonu (düğüm ağaçtan çıkar)
	await get_tree().process_frame
	_check(player.can_move and not gs.is_in_cinematic, "Flashback ortasında sahne kaldırılınca kilit çözüldü.", "Sahne kaldırınca kilit takıldı!")

	db.start_dialogue([{"speaker": "A", "title": "", "text": "x", "portrait": "player"}])
	await get_tree().process_frame
	db.free()
	await get_tree().process_frame
	_check(player.can_move and not gs.is_in_cinematic, "Diyalog ortasında sahne kaldırılınca kilit çözüldü.", "Diyalog sahne kaldırma sonrası kilit takıldı!")

	cm.begin_cinematic("scene_test")
	var other := Node.new()
	get_tree().root.add_child(other)
	await get_tree().process_frame
	get_tree().current_scene = other
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not cm.is_active() and player.can_move, "Aktif sahne değişince sinematik durumu otomatik sıfırlandı.", "Sahne değişiminde sinematik sıfırlanmadı!")
	other.queue_free()
	get_tree().current_scene = self

	cm.begin_cinematic("force")
	cm.force_reset("test")
	_check(not cm.is_active() and player.can_move and not gs.is_in_cinematic, "force_reset() kontrolleri güvenle açar.", "force_reset başarısız!")

	# --- 6. Erişilebilirlik ---
	print("\n--- Test 6: Erişilebilirlik seçenekleri ---")
	cm.set_reduce_motion(true)
	cm.set_reduce_flashing(true)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2.ONE
	var db2 = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(db2)
	await get_tree().process_frame
	db2.start_dialogue([{"speaker": "A", "title": "", "text": "x", "portrait": "player"}])
	await get_tree().create_timer(0.7).timeout
	_check(cam.zoom.is_equal_approx(Vector2.ONE), "Hareketi azalt açıkken kamera zoom uygulanmadı.", "Kamera zoom uygulandı: " + str(cam.zoom))
	db2.skip_dialogue()
	await get_tree().process_frame
	db2.queue_free()

	gs.reset_state()
	var fb3 = load("res://scenes/ui/flashback_overlay.tscn").instantiate()
	add_child(fb3)
	fb3.play_vlad_memory_sequence()
	await get_tree().process_frame
	var guard2 := 0
	while fb3.get_stage_name() == "MEMORY" and guard2 < 20:
		fb3._is_typing = false
		fb3._advance_memory()
		guard2 += 1
	fb3._cut_dimensional_rift()
	await get_tree().process_frame
	_check(not fb3.rift_slash.visible, "Yanıp sönmeyi azalt açıkken parlak yırtık flaşı gösterilmedi.", "Flaş yine de gösterildi!")
	await get_tree().create_timer(1.0).timeout
	_check(fb3.get_stage_name() == "DONE" and player.can_move, "Erişilebilir bitiş de kontrolleri geri açtı.", "Erişilebilir akış bitmedi: " + fb3.get_stage_name())
	fb3.queue_free()

	# Kalıcılık
	cm.reduce_motion = false
	cm.reduce_flashing = false
	cm.load_accessibility()
	_check(cm.reduce_motion and cm.reduce_flashing, "Erişilebilirlik ayarları kalıcı (user://game_settings.json).", "Erişilebilirlik ayarları kalıcı değil!")

	# Ayarlar diyaloğu
	var sd = load("res://scenes/ui/settings_dialog.tscn").instantiate()
	add_child(sd)
	sd.open()
	_check(sd.reduce_motion_check.button_pressed and sd.reduce_flash_check.button_pressed, "Ayarlar diyaloğu mevcut erişilebilirlik değerlerini gösteriyor.", "Ayarlar diyaloğu senkron değil!")
	sd.reduce_motion_check.button_pressed = false
	sd.reduce_flash_check.button_pressed = false
	_check(not cm.reduce_motion and not cm.reduce_flashing, "Ayarlar diyaloğu seçenekleri CinematicManager'a yazıyor.", "Ayarlar diyaloğu seçenekleri uygulamıyor!")
	sd.queue_free()

	# Temizlik
	cm.set_reduce_motion(false)
	cm.set_reduce_flashing(false)
	gs.reset_state()

	print("========================================================")
	if ok:
		print("  SONUÇ: SİNEMATİK / FLASHBACK TESTLERİ TAMAMEN BAŞARILI!  ")
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: BAZI SİNEMATİK TESTLERİ BAŞARISIZ OLDU!  ")
		print("========================================================\n")
		get_tree().quit(1)
