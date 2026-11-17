@tool
extends SceneTree

## res://verify_main_menu.gd
## Ana Menü, Kayıt Sistemi ve Sahne Geçiş Akışı Otomatik Doğrulama Testi

func _init() -> void:
	print("--- ANA MENU & GECIS AKISI TESTI BASLADI ---")

	# 1. Sahne Yükleme
	var menu_res = load("res://scenes/ui/main_menu.tscn")
	if not menu_res:
		push_error("FAIL: res://scenes/ui/main_menu.tscn yüklenemedi!")
		quit(1)
		return
	print("OK: main_menu.tscn yüklendi.")

	var menu_inst = menu_res.instantiate()
	root.add_child(menu_inst)
	menu_inst._ready()
	print("OK: main_menu sahnesi ağaca eklendi.")

	# 2. Temel Düğümlerin Varlığı
	var btn_continue = menu_inst.find_child("BtnContinue", true, false) as Button
	var btn_new_game = menu_inst.find_child("BtnNewGame", true, false) as Button
	var btn_chapter_select = menu_inst.find_child("BtnChapterSelect", true, false) as Button
	var btn_settings = menu_inst.find_child("BtnSettings", true, false) as Button
	var btn_exit = menu_inst.find_child("BtnExit", true, false) as Button

	var confirm_dlg = menu_inst.find_child("ConfirmDialog", true, false)
	var chapter_dlg = menu_inst.find_child("ChapterSelectDialog", true, false)
	var settings_dlg = menu_inst.find_child("SettingsDialog", true, false)
	var music_player = menu_inst.find_child("MusicPlayer", true, false) as AudioStreamPlayer

	if not btn_continue or not btn_new_game or not btn_chapter_select or not btn_settings or not btn_exit:
		push_error("FAIL: Ana menü butonlarından biri veya birkaçı eksik!")
		quit(1)
		return
	print("OK: Tüm menü butonları (Devam Et, Yeni Oyun, Bölüm Seçimi, Ayarlar, Çıkış) mevcut.")

	if not confirm_dlg or not chapter_dlg or not settings_dlg:
		push_error("FAIL: Alt dialog pencereleri eksik!")
		quit(1)
		return
	print("OK: Alt dialog pencereleri (Onay, Bölüm Seçimi, Ayarlar) mevcut.")

	if not music_player:
		push_error("FAIL: MusicPlayer bulunamadı!")
		quit(1)
		return
	print("OK: MusicPlayer mevcut.")

	# 3. SaveManager Testleri & Devam Et Durumu
	var save_mgr = root.get_node_or_null("SaveManager")
	if not save_mgr:
		# Autoload henüz ağaçta değilse doğrudan yükle
		var save_mgr_res = load("res://scripts/autoloads/save_manager.gd")
		save_mgr = save_mgr_res.new()
		save_mgr.name = "SaveManager"
		root.add_child(save_mgr)

	print("SaveManager testleri yapılıyor...")
	# Temiz bir başlangıç için tüm yuvaları sil (Devam Et, kaydı olan herhangi bir yuvayı açabilir)
	for slot_to_clear in range(1, 4):
		save_mgr.delete_save(slot_to_clear)
	save_mgr.active_slot = 1
	if save_mgr.has_save(1):
		push_error("FAIL: delete_save sonrası has_save true döndü!")
		quit(1)
		return
	print("OK: Kayıt silme ve yokluk kontrolü başarılı.")

	menu_inst._update_continue_state()
	if not btn_continue.disabled:
		push_error("FAIL: Kayıt dosyası yokken Devam Et butonu devre dışı olmalıydı!")
		quit(1)
		return
	print("OK: Kayıt yokken Devam Et butonu devre dışı (disabled=true).")

	# Bölüm seçimi kuralı: 2. bölüm yalnızca 1. bölüm tamamlandıysa açılır
	var gs_rule = root.get_node_or_null("GameState")
	if not gs_rule:
		# --script modunda autoload'lar ağaçta olmayabilir; kural testi için doğrudan yükle
		gs_rule = load("res://scripts/autoloads/game_state.gd").new()
		gs_rule.name = "GameState"
		root.add_child(gs_rule)
	if gs_rule:
		gs_rule.reset_state()
		if not save_mgr.is_chapter_unlocked(1) or save_mgr.is_chapter_unlocked(2):
			push_error("FAIL: Kayıt yokken 1. bölüm açık, 2. bölüm kilitli olmalıydı!")
			quit(1)
			return
		gs_rule.complete_chapter("chapter_1")
		if not save_mgr.is_chapter_unlocked(2):
			push_error("FAIL: 1. bölüm tamamlanınca 2. bölüm açılmalıydı!")
			quit(1)
			return
		gs_rule.reset_state()
		print("OK: Bölüm seçimi kuralı doğrulandı (2. bölüm, 1. bölüm tamamlanınca açılır).")

	# Kayıt oluşturma testi
	var save_success = save_mgr.save_game(1)
	if not save_success or not save_mgr.has_save(1):
		push_error("FAIL: save_game kayıt oluşturamadı!")
		quit(1)
		return
	print("OK: Yeni oyun kaydı başarıyla oluşturuldu.")

	menu_inst._update_continue_state()
	if btn_continue.disabled:
		push_error("FAIL: Kayıt varken Devam Et butonu aktif olmalıydı!")
		quit(1)
		return
	print("OK: Kayıt varken Devam Et butonu aktif (disabled=false).")

	# Devam Et doğru yuvayı açmalı: son kullanılan yuva, o boşsa kaydı olan ilk yuva
	save_mgr.save_game(3)
	if menu_inst._resolve_continue_slot() != 3:
		push_error("FAIL: Son kullanılan yuva 3 iken Devam Et yuva %d seçti!" % menu_inst._resolve_continue_slot())
		quit(1)
		return
	save_mgr.delete_save(3)
	if menu_inst._resolve_continue_slot() != 1:
		push_error("FAIL: Aktif yuva boşken Devam Et kaydı olan yuvaya (1) düşmedi!")
		quit(1)
		return
	save_mgr.active_slot = 1
	print("OK: Devam Et son kullanılan yuvayı, o boşsa kaydı olan ilk yuvayı seçiyor.")

	# 4. Kayıt Yükleme & GameState Senkronizasyonu
	var game_state = root.get_node_or_null("GameState")
	if game_state:
		game_state.corruption_score = 45
		game_state.complete_chapter("chapter_1")
		save_mgr.save_game(1)
		game_state.reset_state()
		if game_state.corruption_score != 0:
			push_error("FAIL: reset_state corruption_score sıfırlamadı!")
			quit(1)
			return
		save_mgr.load_game(1)
		if game_state.corruption_score != 45 or not game_state.is_chapter_completed("chapter_1"):
			push_error("FAIL: load_game verileri doğru geri yükleyemedi!")
			quit(1)
			return
		print("OK: Kayıt yükleme ve GameState senkronizasyonu doğrulandı.")

	# 5. Yeni Oyun Onay Akışı Testi
	print("Yeni Oyun onay akışı test ediliyor...")
	btn_new_game.pressed.emit()
	if not confirm_dlg.visible:
		push_error("FAIL: Kayıt varken Yeni Oyun'a basıldığında onay penceresi açılmalıydı!")
		quit(1)
		return
	print("OK: Kayıt varken Yeni Oyun basılınca onay penceresi açıldı.")

	# İptal etme testi
	confirm_dlg._on_cancel_pressed()
	if confirm_dlg.visible:
		push_error("FAIL: İptal basıldığında onay penceresi kapanmalıydı!")
		quit(1)
		return
	print("OK: İptal akışı pencereyi kapattı.")

	# 6. Bölüm Seçimi Penceresi Testi
	print("Bölüm seçimi testi...")
	btn_chapter_select.pressed.emit()
	if not chapter_dlg.visible:
		push_error("FAIL: Bölüm Seçimi butonuna basıldığında pencere açılmalıydı!")
		quit(1)
		return
	chapter_dlg._on_back_pressed()
	if chapter_dlg.visible:
		push_error("FAIL: Geri basıldığında bölüm penceresi kapanmalıydı!")
		quit(1)
		return
	print("OK: Bölüm seçimi penceresi açılma ve kapanma doğrulandı.")

	# 7. Ayarlar Penceresi Testi
	print("Ayarlar penceresi testi...")
	btn_settings.pressed.emit()
	if not settings_dlg.visible:
		push_error("FAIL: Ayarlar butonuna basıldığında pencere açılmalıydı!")
		quit(1)
		return
	settings_dlg._on_master_changed(50.0)
	settings_dlg._on_back_pressed()
	if settings_dlg.visible:
		push_error("FAIL: Ayarlar penceresi kapanmadı!")
		quit(1)
		return
	print("OK: Ayarlar penceresi ve ses seviyesi etkileşimi doğrulandı.")

	# 8. Sahne Geçiş Sistemi (SceneTransition) Testi
	print("Sahne geçiş sistemi test ediliyor...")
	var transition_res = load("res://scenes/ui/scene_transition.tscn")
	if not transition_res:
		push_error("FAIL: scene_transition.tscn bulunamadı!")
		quit(1)
		return
	var transition_inst = transition_res.instantiate()
	root.add_child(transition_inst)
	transition_inst._ready()
	if not transition_inst.color_rect:
		push_error("FAIL: SceneTransition color_rect eksik!")
		quit(1)
		return
	print("OK: SceneTransition sahnesi başarıyla yüklendi ve hazır.")

	# Test sonrası temizlik
	save_mgr.delete_save(1)
	menu_inst.queue_free()
	transition_inst.queue_free()

	print("--- TÜM ANA MENÜ VE SAHNE GEÇİŞ AKIŞI TESTLERİ %100 BAŞARIYLA GEÇTİ! ---")
	quit(0)
