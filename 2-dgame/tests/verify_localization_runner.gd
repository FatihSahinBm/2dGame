extends Node

## tests/verify_localization_runner.gd
## Story 2D-119: Yerelleştirme Altyapısı Kapsamlı Otomatik Testi

func _ready() -> void:
	print("\n========================================================")
	print("  TEST: Story 2D-119 Yerelleştirme Altyapısı Doğrulama  ")
	print("========================================================")

	var all_passed: bool = true

	# 1. LocalizationManager Autoload Kontrolü
	var loc_mgr = get_node_or_null("/root/LocalizationManager")
	if not loc_mgr:
		printerr("FAIL: /root/LocalizationManager autoload bulunamadı!")
		get_tree().quit(1)
		return
	print("PASS: /root/LocalizationManager başarıyla yüklendi.")

	# 2. Türkçe Anahtar Testi
	loc_mgr.set_locale("tr")
	var tr_continue = tr("BTN_CONTINUE")
	var tr_settings = tr("SETTINGS_TITLE")
	var tr_new_game = tr("BTN_NEW_GAME")
	var tr_pause = tr("PAUSE_TITLE")
	var tr_save_slots = tr("SAVE_SLOTS_TITLE")

	print("[TR] BTN_CONTINUE: ", tr_continue)
	print("[TR] SETTINGS_TITLE: ", tr_settings)
	print("[TR] BTN_NEW_GAME: ", tr_new_game)
	print("[TR] PAUSE_TITLE: ", tr_pause)
	print("[TR] SAVE_SLOTS_TITLE: ", tr_save_slots)

	if tr_continue != "▶ Devam Et" or tr_settings != "AYARLAR" or tr_new_game != "✦ Yeni Oyun" \
			or tr_pause != "OYUN DURAKLATILDI" or tr_save_slots != "KAYIT YUVALARI (3 YUVA)":
		printerr("FAIL: Türkçe yerelleştirme metinleri beklenenle uyuşmuyor!")
		all_passed = false
	else:
		print("PASS: Türkçe çeviri anahtarları doğrulandı.")

	# 3. İngilizce Anahtar Testi
	loc_mgr.set_locale("en")
	var en_continue = tr("BTN_CONTINUE")
	var en_settings = tr("SETTINGS_TITLE")
	var en_new_game = tr("BTN_NEW_GAME")
	var en_pause = tr("PAUSE_TITLE")
	var en_save_slots = tr("SAVE_SLOTS_TITLE")

	print("[EN] BTN_CONTINUE: ", en_continue)
	print("[EN] SETTINGS_TITLE: ", en_settings)
	print("[EN] BTN_NEW_GAME: ", en_new_game)
	print("[EN] PAUSE_TITLE: ", en_pause)
	print("[EN] SAVE_SLOTS_TITLE: ", en_save_slots)

	if en_continue != "▶ Continue" or en_settings != "SETTINGS" or en_new_game != "✦ New Game" \
			or en_pause != "GAME PAUSED" or en_save_slots != "SAVE SLOTS (3 SLOTS)":
		printerr("FAIL: İngilizce yerelleştirme metinleri beklenenle uyuşmuyor!")
		all_passed = false
	else:
		print("PASS: İngilizce çeviri anahtarları doğrulandı.")

	# 4. Güvenli Çeviri ve Eksik Anahtar Koruma Mekanizması Testi
	var missing_key = "NON_EXISTING_SECRET_KEY_999"
	var fallback_text = "Varsayılan Güvenli Metin"
	var safe_result = loc_mgr.translate_safe(missing_key, fallback_text)
	var missing_keys = loc_mgr.get_missing_keys()

	print("translate_safe fallback çıktısı: ", safe_result)
	print("Tespit edilen eksik anahtarlar: ", missing_keys)

	if safe_result != fallback_text:
		printerr("FAIL: translate_safe eksik anahtarda fallback metnini döndürmedi!")
		all_passed = false
	elif not missing_keys.has(missing_key):
		printerr("FAIL: Eksik anahtar _missing_keys listesine kaydedilmedi!")
		all_passed = false
	else:
		print("PASS: Güvenli çeviri ve eksik anahtar raporlama mekanizması doğrulandı.")

	# 5. Kalıcılık (user://game_settings.json) Testi
	loc_mgr.set_locale("en")
	loc_mgr.load_saved_locale()
	if loc_mgr.get_current_locale() != "en":
		printerr("FAIL: Dil tercihi kalıcı olarak yüklenemedi!")
		all_passed = false
	else:
		print("PASS: Dil tercihi kalıcılığı doğrulandı.")

	# 6. SettingsDialog Dinamik Yenilenme Testi
	var settings_scene = load("res://scenes/ui/settings_dialog.tscn")
	if settings_scene:
		var settings_inst = settings_scene.instantiate()
		add_child(settings_inst)
		settings_inst.open()

		loc_mgr.set_locale("tr")
		if settings_inst.title_label.text != "AYARLAR" or settings_inst.language_label.text != "Dil (Language):" or settings_inst.language_option.selected != 0:
			printerr("FAIL: SettingsDialog TR dinamik güncelleme hatası!")
			all_passed = false
		else:
			print("PASS: SettingsDialog TR dinamik güncelleme başarılı.")

		loc_mgr.set_locale("en")
		if settings_inst.title_label.text != "SETTINGS" or settings_inst.language_label.text != "Language:" or settings_inst.language_option.selected != 1:
			printerr("FAIL: SettingsDialog EN dinamik güncelleme hatası!")
			all_passed = false
		else:
			print("PASS: SettingsDialog EN dinamik güncelleme başarılı.")

		settings_inst.queue_free()

	# 7. MainMenu Dinamik Yenilenme Testi
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	if menu_scene:
		var menu_inst = menu_scene.instantiate()
		add_child(menu_inst)

		loc_mgr.set_locale("tr")
		if menu_inst.btn_new_game.text != "✦ Yeni Oyun" or menu_inst.btn_settings.text != "⚙ Ayarlar":
			printerr("FAIL: MainMenu TR dinamik güncelleme hatası! Bulunan: ", menu_inst.btn_new_game.text)
			all_passed = false
		else:
			print("PASS: MainMenu TR dinamik güncelleme başarılı.")

		loc_mgr.set_locale("en")
		if menu_inst.btn_new_game.text != "✦ New Game" or menu_inst.btn_settings.text != "⚙ Settings":
			printerr("FAIL: MainMenu EN dinamik güncelleme hatası! Bulunan: ", menu_inst.btn_new_game.text)
			all_passed = false
		else:
			print("PASS: MainMenu EN dinamik güncelleme başarılı.")

		menu_inst.queue_free()

	# 8. PauseMenu Dinamik Yenilenme Testi
	var pause_scene = load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		var pause_inst = pause_scene.instantiate()
		add_child(pause_inst)

		loc_mgr.set_locale("tr")
		if pause_inst.btn_resume.text != "▶ Devam Et" or pause_inst.btn_save.text != "💾 Oyunu Kaydet (3 Yuva)":
			printerr("FAIL: PauseMenu TR dinamik güncelleme hatası!")
			all_passed = false
		else:
			print("PASS: PauseMenu TR dinamik güncelleme başarılı.")

		loc_mgr.set_locale("en")
		if pause_inst.btn_resume.text != "▶ Resume" or pause_inst.btn_save.text != "💾 Save Game (3 Slots)":
			printerr("FAIL: PauseMenu EN dinamik güncelleme hatası!")
			all_passed = false
		else:
			print("PASS: PauseMenu EN dinamik güncelleme başarılı.")

		pause_inst.queue_free()

	# 9. ChapterSelectDialog Dinamik Yenilenme Testi
	var chapter_scene = load("res://scenes/ui/chapter_select_dialog.tscn")
	if chapter_scene:
		var ch_inst = chapter_scene.instantiate()
		add_child(ch_inst)
		ch_inst.open()

		loc_mgr.set_locale("tr")
		ch_inst._populate_chapters()
		if ch_inst.title_label.text != "BÖLÜM SEÇİMİ VE YOLCULUK" or ch_inst.back_button.text != "⮌ Geri":
			printerr("FAIL: ChapterSelectDialog TR dinamik güncelleme hatası!")
			all_passed = false
		else:
			print("PASS: ChapterSelectDialog TR dinamik güncelleme başarılı.")

		loc_mgr.set_locale("en")
		ch_inst._populate_chapters()
		if ch_inst.title_label.text != "CHAPTER SELECT & JOURNEY" or ch_inst.back_button.text != "⮌ Back":
			printerr("FAIL: ChapterSelectDialog EN dinamik güncelleme hatası!")
			all_passed = false
		else:
			print("PASS: ChapterSelectDialog EN dinamik güncelleme başarılı.")

		ch_inst.queue_free()

	# 10. StoryDataLoader İki Dilli Diyalog Testi
	var story_loader = get_node_or_null("/root/StoryDataLoader")
	if story_loader:
		loc_mgr.set_locale("tr")
		var tr_seq = story_loader.get_dialogue_sequence("intro_awakening")
		if tr_seq.is_empty() or not tr_seq[0]["speaker"].contains("Kılıç"):
			printerr("FAIL: StoryDataLoader TR diyalog yükleme hatası!")
			all_passed = false
		else:
			print("PASS: StoryDataLoader TR diyalog: ", tr_seq[0]["speaker"], " -> ", tr_seq[0]["text"].substr(0, 30))

		loc_mgr.set_locale("en")
		var en_seq = story_loader.get_dialogue_sequence("intro_awakening")
		if en_seq.is_empty() or not en_seq[0]["speaker"].contains("Blade"):
			printerr("FAIL: StoryDataLoader EN diyalog yükleme hatası! Bulunan: ", en_seq[0]["speaker"] if not en_seq.is_empty() else "Boş")
			all_passed = false
		else:
			print("PASS: StoryDataLoader EN diyalog: ", en_seq[0]["speaker"], " -> ", en_seq[0]["text"].substr(0, 30))

	# Testi sıfırla ve varsayılan dili ayarla
	loc_mgr.set_locale("tr")

	print("========================================================")
	if all_passed:
		print("  SONUÇ: 10/10 YERELLEŞTİRME TESTLERİ TAMAMEN BAŞARILI! ")
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: BAZI YERELLEŞTİRME TESTLERİ BAŞARISIZ OLDU! ")
		print("========================================================\n")
		get_tree().quit(1)

