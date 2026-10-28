extends Node

## res://verify_pause_menu.gd
## HUD Durdurma Butonu, Duraklatma Menüsü ve Devam Et Akışı Otomatik Doğrulama Testi

func _ready() -> void:
	print("--- HUD DURDURMA BUTONU VE DEVAM ET TESTİ BAŞLADI ---")

	# 1. FantasyHUD Sahnesi Yükleme
	var hud_res = load("res://scenes/ui/fantasy_hud.tscn")
	if not hud_res:
		push_error("FAIL: res://scenes/ui/fantasy_hud.tscn yüklenemedi!")
		get_tree().quit(1)
		return
	print("OK: fantasy_hud.tscn başarıyla yüklendi.")

	var hud_inst = hud_res.instantiate()
	add_child(hud_inst)
	print("OK: fantasy_hud sahne ağacına eklendi.")

	# 2. Process Mode Kontrolü
	if hud_inst.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("FAIL: FantasyHUD process_mode PROCESS_MODE_ALWAYS olmalı!")
		get_tree().quit(1)
		return
	print("OK: FantasyHUD process_mode = PROCESS_MODE_ALWAYS doğrulandı.")

	# 3. Durdurma Butonu (PauseButton) Kontrolü
	var pause_btn = hud_inst.find_child("PauseButton", true, false) as TextureButton
	if not pause_btn:
		push_error("FAIL: PauseButton bulunamadı!")
		get_tree().quit(1)
		return
	print("OK: Sağ üstteki Durdur Butonu (PauseButton) mevcut.")

	# 4. Duraklatma Menüsü (PauseMenu) Kontrolü
	var pause_menu = hud_inst.find_child("PauseMenu", true, false)
	if not pause_menu:
		push_error("FAIL: PauseMenu düğümü HUD içinde bulunamadı!")
		get_tree().quit(1)
		return
	print("OK: PauseMenu bileşeni mevcut.")

	if pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("FAIL: PauseMenu process_mode PROCESS_MODE_ALWAYS olmalı!")
		get_tree().quit(1)
		return
	print("OK: PauseMenu process_mode = PROCESS_MODE_ALWAYS doğrulandı.")

	# Başlangıçta oyun duraklatılmamış ve menü gizli olmalı
	if get_tree().paused:
		push_error("FAIL: Başlangıçta oyun duraklatılmış olmamalı!")
		get_tree().quit(1)
		return
	if pause_menu.visible:
		push_error("FAIL: Başlangıçta PauseMenu gizli (visible=false) olmalı!")
		get_tree().quit(1)
		return
	print("OK: Başlangıç durumu: Oyun akıyor ve duraklatma menüsü gizli.")

	# 5. Durdur Butonuna Basma Testi (Pause)
	print("Durdur butonuna basılıyor...")
	pause_btn.pressed.emit()

	if not get_tree().paused:
		push_error("FAIL: Durdur butonuna basıldığında get_tree().paused true olmalıydı!")
		get_tree().quit(1)
		return
	if not pause_menu.visible:
		push_error("FAIL: Durdur butonuna basıldığında PauseMenu görünür (visible=true) olmalıydı!")
		get_tree().quit(1)
		return
	print("OK: Durdur butonuna basılınca oyun durdu (paused=true) ve menü açıldı.")

	# 6. 'Devam Et' Butonunun Varlığı ve İşlevi
	var btn_resume = pause_menu.find_child("BtnResume", true, false) as Button
	var btn_restart = pause_menu.find_child("BtnRestart", true, false) as Button
	var btn_main_menu = pause_menu.find_child("BtnMainMenu", true, false) as Button

	if not btn_resume or not btn_restart or not btn_main_menu:
		push_error("FAIL: Duraklatma menüsü butonları (Devam Et, Yeniden Başlat, Ana Menü) eksik!")
		get_tree().quit(1)
		return
	print("OK: Menü butonları (Devam Et, Yeniden Başlat, Ana Menü) mevcut.")

	# 7. 'Devam Et' Butonuna Basma Testi (Resume)
	print("'Devam Et' butonuna basılıyor...")
	btn_resume.pressed.emit()

	if get_tree().paused:
		push_error("FAIL: Devam Et butonuna basıldığında get_tree().paused false olmalıydı!")
		get_tree().quit(1)
		return
	if pause_menu.visible:
		push_error("FAIL: Devam Et butonuna basıldığında PauseMenu kapanmalıydı!")
		get_tree().quit(1)
		return
	print("OK: 'Devam Et' basılınca oyun duraklatması kaldırıldı (paused=false) ve oyun kaldığı yerden devam etti.")

	# 8. Durdur Butonuna Tekrar Basarak Açıp Kapatma Testi (Toggle)
	print("Durdur butonu ile toggle testi...")
	pause_btn.pressed.emit()
	if not get_tree().paused or not pause_menu.visible:
		push_error("FAIL: Durdur butonu tekrar basılınca oyunu durduramadı!")
		get_tree().quit(1)
		return

	# Durdur butonuna açıkken tekrar basıldığında kapanmalı
	pause_btn.pressed.emit()
	if get_tree().paused or pause_menu.visible:
		push_error("FAIL: Açıkken durdur butonuna basılınca oyun devam etmeliydi!")
		get_tree().quit(1)
		return
	print("OK: Durdur butonu ile çift yönlü toggle kusursuz çalışıyor.")

	# 9. Standalone PauseMenu Testi
	var standalone_res = load("res://scenes/ui/pause_menu.tscn")
	var standalone_inst = standalone_res.instantiate()
	add_child(standalone_inst)
	standalone_inst.open()
	if not get_tree().paused or not standalone_inst.visible:
		push_error("FAIL: Standalone PauseMenu open() çalışmadı!")
		get_tree().quit(1)
		return
	standalone_inst.resume_game()
	if get_tree().paused or standalone_inst.visible:
		push_error("FAIL: Standalone PauseMenu resume_game() çalışmadı!")
		get_tree().quit(1)
		return
	print("OK: Standalone PauseMenu bağımsız bileşen olarak da doğrulandı.")

	# 10. ESC (Escape) Tuşu ile Durdurma ve Devam Etme Testi
	print("ESC tuşu girdi simülasyonu testi...")
	var esc_event = InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE

	hud_inst._input(esc_event)
	if not get_tree().paused or not pause_menu.visible:
		push_error("FAIL: ESC tuşuna basıldığında oyun duraklatılmalı ve menü açılmalıydı!")
		get_tree().quit(1)
		return
	print("OK: ESC tuşuna basılınca oyun durdu ve menü açıldı.")

	# ESC tuşuna tekrar basınca devam etmeli
	hud_inst._input(esc_event)
	if get_tree().paused or pause_menu.visible:
		push_error("FAIL: ESC tuşuna tekrar basıldığında oyun devam etmeli ve menü kapanmalıydı!")
		get_tree().quit(1)
		return
	print("OK: ESC tuşuna tekrar basılınca oyun devam etti.")

	# 11. Fiziksel ESC (Physical Keycode) Testi
	var phys_esc_event = InputEventKey.new()
	phys_esc_event.pressed = true
	phys_esc_event.physical_keycode = KEY_ESCAPE

	hud_inst._input(phys_esc_event)
	if not get_tree().paused or not pause_menu.visible:
		push_error("FAIL: Fiziksel ESC tuşuna basıldığında oyun duraklatılmalıydı!")
		get_tree().quit(1)
		return
	print("OK: Fiziksel ESC (physical_keycode) ile oyun durduruldu.")

	btn_resume.pressed.emit()
	if get_tree().paused or pause_menu.visible:
		push_error("FAIL: Devam Et butonu ile fiziksel ESC sonrası devam edilemedi!")
		get_tree().quit(1)
		return
	print("OK: 'Devam Et' butonu ile oyun başarıyla sürdürüldü.")

	# 12. Ayarlar Butonu ve SettingsDialog Kontrolü
	print("Ayarlar butonu ve SettingsDialog testi...")
	pause_btn.pressed.emit() # menüyü aç
	var btn_settings = pause_menu.find_child("BtnSettings", true, false) as Button
	var settings_dlg = pause_menu.find_child("SettingsDialog", true, false)
	if not btn_settings or not settings_dlg:
		push_error("FAIL: PauseMenu içinde BtnSettings veya SettingsDialog bulunamadı!")
		get_tree().quit(1)
		return
	print("OK: BtnSettings ve SettingsDialog mevcut.")
	btn_settings.pressed.emit()
	if not settings_dlg.visible:
		push_error("FAIL: BtnSettings basıldığında SettingsDialog açılmadı!")
		get_tree().quit(1)
		return
	print("OK: Ayarlar butonuna basılınca SettingsDialog başarıyla açıldı.")
	settings_dlg._on_back_pressed()
	if settings_dlg.visible:
		push_error("FAIL: Geri basılınca SettingsDialog kapanmadı!")
		get_tree().quit(1)
		return
	print("OK: SettingsDialog geri butonu ile başarıyla kapandı.")

	# 13. Kayıt Yuvaları Paneli (3 Yuva) ve Oto-Kayıt Kontrolü
	print("Kayıt Yuvaları paneli ve 3 yuva testi...")
	var btn_save = pause_menu.find_child("BtnSave", true, false) as Button
	var save_panel = pause_menu.find_child("SaveSlotsPanel", true, false)
	if not btn_save or not save_panel:
		push_error("FAIL: BtnSave veya SaveSlotsPanel bulunamadı!")
		get_tree().quit(1)
		return
	btn_save.pressed.emit()
	if not save_panel.visible:
		push_error("FAIL: BtnSave basılınca SaveSlotsPanel açılmadı!")
		get_tree().quit(1)
		return
	print("OK: 'Oyunu Kaydet' basılınca 3 yuvalı SaveSlotsPanel açıldı.")

	var btn_save_slot1 = pause_menu.find_child("BtnSaveSlot1", true, false) as Button
	var btn_save_slot2 = pause_menu.find_child("BtnSaveSlot2", true, false) as Button
	var btn_save_slot3 = pause_menu.find_child("BtnSaveSlot3", true, false) as Button
	var check_autosave = pause_menu.find_child("CheckAutoSave", true, false) as CheckBox
	var btn_back_save = pause_menu.find_child("BtnBackFromSave", true, false) as Button

	if not btn_save_slot1 or not btn_save_slot2 or not btn_save_slot3 or not check_autosave:
		push_error("FAIL: 3 Kayıt yuvası butonları veya CheckAutoSave bulunamadı!")
		get_tree().quit(1)
		return
	print("OK: 3 kayıt yuvası ve Otomatik Kayıt onay kutusu mevcut.")

	# Yuva 1'e kaydet
	btn_save_slot1.pressed.emit()
	var lbl_slot1_details = pause_menu.find_child("LblSlot1Details", true, false) as Label
	if not lbl_slot1_details or not lbl_slot1_details.text.contains("Tarih"):
		push_error("FAIL: Yuva 1 kaydedildikten sonra detay etiketi güncellenmedi!")
		get_tree().quit(1)
		return
	print("OK: Yuva 1'e kayıt yapıldı ve tarih/konum detayı güncellendi: " + lbl_slot1_details.text)

	# Oto-kayıt onay kutusu toggle testi
	check_autosave.toggled.emit(false)
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.is_autosave_enabled():
		push_error("FAIL: Checkbox oto-kayıt durumunu kapatamadı!")
		get_tree().quit(1)
		return
	check_autosave.toggled.emit(true)
	if sm and not sm.is_autosave_enabled():
		push_error("FAIL: Checkbox oto-kayıt durumunu açamadı!")
		get_tree().quit(1)
		return
	print("OK: Otomatik kayıt seçeneği başarıyla açılıp kapatıldı.")

	# Geri butonu ile ana pause butonlarına dönüş
	btn_back_save.pressed.emit()
	if save_panel.visible:
		push_error("FAIL: Geri basılınca SaveSlotsPanel kapanmadı!")
		get_tree().quit(1)
		return
	print("OK: Kayıt yuvalarından geri dönüldü.")
	btn_resume.pressed.emit()

	# Temizlik
	if sm:
		sm.delete_save(1)

	# Temizlik
	hud_inst.queue_free()
	standalone_inst.queue_free()

	print("--- TÜM HUD DURDURMA VE DEVAM ET TESTLERİ (ESC DAHİL) %100 BAŞARIYLA GEÇTİ! ---")
	get_tree().quit(0)
