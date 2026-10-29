extends Node2D

## res://tests/verify_codex_runner.gd
## Story 2D-122: Düşman Kodeksi ve Dünya Bilgisi Arşivi Otomatik Doğrulama Testi

const CodexDialogScene = preload("res://scenes/ui/codex_dialog.tscn")
const FantasyHUDScene = preload("res://scenes/ui/fantasy_hud.tscn")

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	get_tree().current_scene = self
	print("\n========================================================")
	print("  TEST: Story 2D-122 Düşman Kodeksi ve Bilgi Arşivi ")
	print("========================================================\n")

	_run_all_tests()

	print("\n========================================================")
	if _failed_tests == 0:
		print("  SONUÇ: %d/%d KODEKS VE BİLGİ ARŞİVİ TESTİ TAMAMEN BAŞARILI!" % [_passed_tests, _passed_tests])
	else:
		printerr("  HATA: %d test BAŞARISIZ OLDU! (Başarılı: %d)" % [_failed_tests, _passed_tests])
	print("========================================================\n")

	get_tree().quit(0 if _failed_tests == 0 else 1)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		_passed_tests += 1
		print("PASS: %s" % test_name)
	else:
		_failed_tests += 1
		printerr("FAIL: %s" % test_name)


func _run_all_tests() -> void:
	_test_1_scene_and_node_hierarchy()
	_test_2_codex_database_initialization()
	_test_3_spoiler_masking_for_locked_entries()
	_test_4_encounter_and_unlock_mechanics()
	_test_5_kill_counter_progression()
	_test_6_progress_calculations()
	_test_7_category_tab_switching()
	_test_8_entry_selection_and_tactics_display()
	_test_9_hud_integration_and_shortcuts()
	_test_10_save_manager_persistence()
	_test_11_fallback_safety_missing_textures()
	_test_12_procedural_audio_feedback()


func _test_1_scene_and_node_hierarchy() -> void:
	print("--- TEST 1: Sahne ve Düğüm Hiyerarşisi ---")
	var dialog = CodexDialogScene.instantiate()
	add_child(dialog)

	_assert_true(dialog != null, "CodexDialog örneği başarıyla oluşturuldu")
	_assert_true(dialog.get_node_or_null("Panel") != null, "Panel düğümü mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/TabsContainer/BtnEnemies") != null, "BtnEnemies sekme düğmesi mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/TabsContainer/BtnBosses") != null, "BtnBosses sekme düğmesi mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/TabsContainer/BtnCharacters") != null, "BtnCharacters sekme düğmesi mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/TabsContainer/BtnLore") != null, "BtnLore sekme düğmesi mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/Scroll/EntryList") != null, "EntryList konteyneri mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/ProgressBox/ProgressLabel") != null, "ProgressLabel mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/HeaderBox/TitleBox/TitleLabel") != null, "TitleLabel mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/TacticsBox/TacticsLabel") != null, "TacticsLabel mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/WeaknessBox/WeaknessLabel") != null, "WeaknessLabel mevcut")
	_assert_true(dialog.get_node_or_null("Panel/VBox/Footer/BtnClose") != null, "BtnClose kapat butonu mevcut")

	dialog.queue_free()


func _test_2_codex_database_initialization() -> void:
	print("\n--- TEST 2: Veritabanı ve Kategori İlklendirmesi ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	_assert_true(codex_mgr != null, "CodexManager autoload tekil örneği mevcut")
	if not codex_mgr:
		return

	codex_mgr.reset_codex()

	var enemies = codex_mgr.get_entries_by_category("enemies")
	var bosses = codex_mgr.get_entries_by_category("bosses")
	var characters = codex_mgr.get_entries_by_category("characters")
	var lore = codex_mgr.get_entries_by_category("lore")

	_assert_true(enemies.size() >= 7, "En az 7 normal düşman tanımlı (Bulunan: %d)" % enemies.size())
	_assert_true(bosses.size() >= 4, "En az 4 elebaşı tanımlı (Bulunan: %d)" % bosses.size())
	_assert_true(characters.size() >= 3, "En az 3 müttefik/karakter tanımlı (Bulunan: %d)" % characters.size())
	_assert_true(lore.size() >= 3, "En az 3 parşömen/dünya bilgisi tanımlı (Bulunan: %d)" % lore.size())

	# Belli başlı kayıtların varlığı
	_assert_true(codex_mgr.get_entry("basic_enemy").has("title"), "Eflak Muhafız Piyadesi kaydı mevcut")
	_assert_true(codex_mgr.get_entry("blood_knight").has("title"), "Kan Şövalyesi kaydı mevcut")
	_assert_true(codex_mgr.get_entry("vlad_boss").has("title"), "Vlad Tepeş elebaşı kaydı mevcut")
	_assert_true(codex_mgr.get_entry("fatih_mehmed").has("title"), "Fatih Sultan Mehmed kaydı mevcut")
	_assert_true(codex_mgr.get_entry("world_heart_myth").has("title"), "Dünya Kalbi Efsanesi kaydı mevcut")


func _test_3_spoiler_masking_for_locked_entries() -> void:
	print("\n--- TEST 3: Spoiler Koruması ve Kilitli Gösterim ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	if not codex_mgr:
		return

	codex_mgr.reset_codex()

	# Vlad Tepeş başlangıçta kilitli olmalı
	_assert_true(not codex_mgr.is_unlocked("vlad_boss"), "Vlad Tepeş başlangıçta kilitli")

	var masked_vlad = codex_mgr.get_display_entry("vlad_boss")
	_assert_true(bool(masked_vlad.get("is_locked", false)), "Maskeli kayıtta is_locked == true")
	_assert_true("???" in str(masked_vlad.get("title", "")), "Kilitli kaydın başlığı ??? ile gizlenmiş")
	_assert_true(not ("Vlad Tepeş" in str(masked_vlad.get("title", ""))), "Kilitli kaydın başlığında gerçek isim sızdırılmıyor")
	_assert_true("🔒" in str(masked_vlad.get("tactics", "")), "Taktikler kilitli simgesiyle gizlenmiş")
	_assert_true("🔒" in str(masked_vlad.get("weakness", "")), "Zayıflık kilitli simgesiyle gizlenmiş")

	# Açık olan kayıt gerçek bilgileri göstermeli
	_assert_true(codex_mgr.is_unlocked("basic_enemy"), "basic_enemy başlangıçta açık")
	var open_soldier = codex_mgr.get_display_entry("basic_enemy")
	_assert_true(not bool(open_soldier.get("is_locked", false)), "Açık kayıtta is_locked == false")
	_assert_true("Eflak Muhafız" in str(open_soldier.get("title", "")), "Açık kaydın başlığı okunabilir")
	_assert_true("Fırlatma Bıçağı" in str(open_soldier.get("weakness", "")), "Açık kaydın zayıflık bilgisi mevcut")


func _test_4_encounter_and_unlock_mechanics() -> void:
	print("\n--- TEST 4: Karşılaşma ve Kilit Açma Mekanizması ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	if not codex_mgr:
		return

	codex_mgr.reset_codex()

	_assert_true(not codex_mgr.is_unlocked("skeleton"), "İskelet başlangıçta kilitli")

	var unlock_signal_received := {"fired": false, "id": ""}
	var handler = func(e_id: String, _data: Dictionary):
		unlock_signal_received["fired"] = true
		unlock_signal_received["id"] = e_id

	codex_mgr.entry_unlocked.connect(handler)

	var res = codex_mgr.record_encounter("skeleton")
	_assert_true(res, "record_encounter('skeleton') true döndü")
	_assert_true(codex_mgr.is_unlocked("skeleton"), "İskelet artık açık (unlocked == true)")
	_assert_true(unlock_signal_received["fired"], "entry_unlocked sinyali tetiklendi")
	_assert_true(unlock_signal_received["id"] == "skeleton", "Sinyal doğru entry_id iletti")

	# Tekrar karşılaşıldığında kilit açılma sinyali tekrar tetiklenmemeli (idempotent)
	unlock_signal_received["fired"] = false
	codex_mgr.record_encounter("skeleton")
	_assert_true(not unlock_signal_received["fired"], "Mevcut kayıtta tekrar kilit sinyali tetiklenmedi")

	codex_mgr.entry_unlocked.disconnect(handler)


func _test_5_kill_counter_progression() -> void:
	print("\n--- TEST 5: Düşman Yenilme Sayacı (Kill Counter) ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	if not codex_mgr:
		return

	codex_mgr.reset_codex()

	var initial_kills = codex_mgr.get_entry("basic_enemy").get("kills", 0)
	_assert_true(initial_kills == 0, "basic_enemy başlangıçta 0 yenilmeye sahip")

	var kill_signal_received := {"fired": false, "count": 0}
	var handler = func(_id: String, count: int):
		kill_signal_received["fired"] = true
		kill_signal_received["count"] = count

	codex_mgr.kill_count_incremented.connect(handler)

	codex_mgr.record_kill("basic_enemy")
	_assert_true(kill_signal_received["fired"], "kill_count_incremented sinyali tetiklendi")
	_assert_true(kill_signal_received["count"] == 1, "Kill sayısı 1 oldu")

	codex_mgr.record_kill("basic_enemy")
	_assert_true(kill_signal_received["count"] == 2, "Kill sayısı 2'ye yükseldi")

	var entry = codex_mgr.get_entry("basic_enemy")
	_assert_true(int(entry.get("kills", 0)) == 2, "Veritabanındaki kills alanı 2 olarak güncellendi")

	codex_mgr.kill_count_incremented.disconnect(handler)


func _test_6_progress_calculations() -> void:
	print("\n--- TEST 6: Kodeks İlerleme Oranı Hesaplaması ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	if not codex_mgr:
		return

	codex_mgr.reset_codex()

	var prog_all = codex_mgr.get_progress("")
	_assert_true(prog_all.has("total") and prog_all["total"] > 0, "Genel ilerleme toplam kayıt sayısı > 0")
	_assert_true(prog_all.has("unlocked") and prog_all["unlocked"] >= 1, "Genel açılan kayıt sayısı >= 1")
	_assert_true(prog_all.has("percentage") and prog_all["percentage"] >= 0 and prog_all["percentage"] <= 100, "Yüzde 0-100 aralığında")

	var prog_enemies = codex_mgr.get_progress("enemies")
	_assert_true(prog_enemies["unlocked"] == 1, "Düşmanlar sekmesinde başlangıçta 1 kayıt açık (basic_enemy)")
	_assert_true(prog_enemies["total"] >= 7, "Düşmanlar toplamı >= 7")

	# İskelet ve Göz açıldığında ilerleme artmalı
	codex_mgr.unlock_entry("skeleton")
	codex_mgr.unlock_entry("flying_eye")

	var prog_updated = codex_mgr.get_progress("enemies")
	_assert_true(prog_updated["unlocked"] == 3, "2 yeni düşman açıldıktan sonra unlocked == 3 oldu")
	_assert_true(prog_updated["percentage"] > prog_enemies["percentage"], "İlerleme yüzdesi arttı")


func _test_7_category_tab_switching() -> void:
	print("\n--- TEST 7: Kategori Sekmeleri ve Liste Güncelleme ---")
	var dialog = CodexDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	_assert_true(dialog.visible, "dialog.open() sonrası pencere görünür")
	_assert_true(dialog._current_category == "enemies", "Varsayılan aktif sekme: enemies")

	# Sekme değişimi: bosses
	dialog._switch_category("bosses")
	_assert_true(dialog._current_category == "bosses", "Sekme 'bosses' olarak değişti")
	var entry_list: VBoxContainer = dialog.get_node_or_null("Panel/VBox/MainSplit/LeftPane/VBox/Scroll/EntryList")
	_assert_true(entry_list != null and entry_list.get_child_count() >= 4, "Elebaşılar listelendi (adet: %d)" % entry_list.get_child_count())

	# Sekme değişimi: characters
	dialog._switch_category("characters")
	_assert_true(dialog._current_category == "characters", "Sekme 'characters' olarak değişti")
	_assert_true(entry_list.get_child_count() >= 3, "Karakterler listelendi (adet: %d)" % entry_list.get_child_count())

	# Sekme değişimi: lore
	dialog._switch_category("lore")
	_assert_true(dialog._current_category == "lore", "Sekme 'lore' olarak değişti")
	_assert_true(entry_list.get_child_count() >= 3, "Dünya bilgisi kayıtları listelendi (adet: %d)" % entry_list.get_child_count())

	# Döngüsel geçiş (TAB simülasyonu)
	dialog._cycle_category()
	_assert_true(dialog._current_category == "enemies", "cycle_category ile tekrar ilk kategoriye döndü")

	dialog.close()
	_assert_true(not dialog.visible, "dialog.close() sonrası pencere kapandı")
	dialog.queue_free()


func _test_8_entry_selection_and_tactics_display() -> void:
	print("\n--- TEST 8: Kayıt Seçimi ve Taktik/Zayıflık Gösterimi ---")
	var dialog = CodexDialogScene.instantiate()
	add_child(dialog)
	dialog.open()

	var codex_mgr = get_node_or_null("/root/CodexManager")
	if codex_mgr:
		codex_mgr.unlock_entry("blood_knight")

	dialog._switch_category("bosses")
	dialog._selected_entry_id = "blood_knight"
	dialog._display_selected_entry()

	var title_lbl: Label = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/HeaderBox/TitleBox/TitleLabel")
	var tactics_lbl: Label = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/TacticsBox/TacticsLabel")
	var weakness_lbl: Label = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/WeaknessBox/WeaknessLabel")

	_assert_true(title_lbl != null and "Kan Şövalyesi" in title_lbl.text, "Başlıkta 'Kan Şövalyesi' gösterildi")
	_assert_true(tactics_lbl != null and "Kemankeş" in tactics_lbl.text, "Taktiklerde Kemankeş ok desteği bilgisi gösterildi")
	_assert_true(weakness_lbl != null and "Alevli Ok" in weakness_lbl.text, "Zayıflıkta Alevli Ok Bombardımanı gösterildi")

	dialog.close()
	dialog.queue_free()


func _test_9_hud_integration_and_shortcuts() -> void:
	print("\n--- TEST 9: FantasyHUD Entegrasyonu ve Kısayol Tuşları ---")
	var hud = FantasyHUDScene.instantiate()
	hud.name = "FantasyHUD"
	add_child(hud)

	_assert_true(hud.has_method("toggle_codex"), "FantasyHUD toggle_codex fonksiyonuna sahip")

	# Aç
	hud.toggle_codex()
	_assert_true(hud.codex_dialog != null, "toggle_codex çağrılınca codex_dialog oluşturuldu")
	_assert_true(hud.codex_dialog.visible, "Kodeks açıldı (visible == true)")

	# Tekrar çağrınca kapat
	hud.toggle_codex()
	_assert_true(not hud.codex_dialog.visible, "toggle_codex tekrar çağrılınca kapandı (visible == false)")

	# Aç ve ESC simülasyonu ile kapat
	hud.toggle_codex()
	_assert_true(hud.codex_dialog.visible, "Kodeks tekrar açıldı")

	var esc_event = InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	hud._input(esc_event)

	_assert_true(not hud.codex_dialog.visible, "ESC tuşu ile kodeks güvenle kapatıldı (pause menüsü tetiklenmeden önce)")

	hud.queue_free()


func _test_10_save_manager_persistence() -> void:
	print("\n--- TEST 10: SaveManager ile Kalıcılık (Export/Import) ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	var save_mgr = get_node_or_null("/root/SaveManager")

	_assert_true(codex_mgr != null and save_mgr != null, "CodexManager ve SaveManager mevcut")
	if not codex_mgr or not save_mgr:
		return

	codex_mgr.reset_codex()

	# Necromancer'ı aç ve kill sayısını 3 yap
	codex_mgr.unlock_entry("necromancer")
	codex_mgr.record_kill("necromancer")
	codex_mgr.record_kill("necromancer")
	codex_mgr.record_kill("necromancer")

	_assert_true(codex_mgr.is_unlocked("necromancer"), "Necromancer açıldı")
	_assert_true(codex_mgr.get_entry("necromancer").get("kills", 0) == 3, "Necromancer 3 kill'e sahip")

	# Export testi
	var exported = codex_mgr.export_save_data()
	_assert_true(exported.has("necromancer"), "Dışa aktarılan veride 'necromancer' mevcut")
	_assert_true(exported["necromancer"]["unlocked"] == true, "Dışa aktarılan 'necromancer' unlocked == true")
	_assert_true(exported["necromancer"]["kills"] == 3, "Dışa aktarılan 'necromancer' kills == 3")

	# Sıfırla ve içe aktar
	codex_mgr.reset_codex()
	_assert_true(not codex_mgr.is_unlocked("necromancer"), "Reset sonrası necromancer kilitlendi")

	codex_mgr.import_save_data(exported)
	_assert_true(codex_mgr.is_unlocked("necromancer"), "İçe aktarma sonrası necromancer kilidi başarıyla geri yüklendi")
	_assert_true(codex_mgr.get_entry("necromancer").get("kills", 0) == 3, "İçe aktarma sonrası kill sayısı (3) korundu")

	# Tam SaveManager.save_game / load_game entegrasyonu
	var save_res = save_mgr.save_game(1)
	_assert_true(save_res, "SaveManager.save_game(1) başarıyla kaydedildi")

	codex_mgr.reset_codex()
	_assert_true(not codex_mgr.is_unlocked("necromancer"), "Reset sonrası necromancer tekrar kilitlendi")

	var load_res = save_mgr.load_game(1)
	_assert_true(load_res, "SaveManager.load_game(1) başarıyla yüklendi")
	_assert_true(codex_mgr.is_unlocked("necromancer"), "SaveManager yüklemesi sonrasında kodeks kayıtları başarıyla geri yüklendi")


func _test_11_fallback_safety_missing_textures() -> void:
	print("\n--- TEST 11: Güvenli Çökme Koruması (Missing Textures & Malformed Data) ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	var dialog = CodexDialogScene.instantiate()
	add_child(dialog)

	# Var olmayan ikon yolu ve eksik alanlara sahip sahte bir canavar kaydet
	codex_mgr.register_entry({
		"id": "missing_texture_monster",
		"category": "enemies",
		"title": "Bilinmeyen Gölge",
		"icon_path": "res://scenes/ui/icons/non_existent_fake_icon_404.png",
		"unlocked": true,
		"description": "Kırık dokulu test yaratığı."
	})

	dialog.open()
	dialog._switch_category("enemies")
	dialog._selected_entry_id = "missing_texture_monster"
	dialog._display_selected_entry()

	var icon_tex: TextureRect = dialog.get_node_or_null("Panel/VBox/MainSplit/RightPane/ContentVBox/VisualAndStats/IconContainer/IconTexture")
	_assert_true(icon_tex != null, "IconTexture düğümü mevcut")
	_assert_true(icon_tex.texture == null, "Eksik doku durumunda çökmeden null olarak ele alındı")

	# Geçersiz ID ve boş sorgularda çökmemeli
	var invalid_data = codex_mgr.get_display_entry("completely_unknown_id")
	_assert_true(invalid_data.is_empty(), "Bilinmeyen ID boş sözlük döndürdü, çökmedi")

	dialog.close()
	dialog.queue_free()


func _test_12_procedural_audio_feedback() -> void:
	print("\n--- TEST 12: Prosedürel Ses Geri Bildirimleri ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager autoload mevcut")
	if not audio_mgr:
		return

	# Prosedürel ses fonksiyonlarının kayıtlı olduğunu doğrula
	_assert_true(audio_mgr.has_method("play_sfx"), "AudioManager.play_sfx mevcut")

	var open_res = audio_mgr.play_sfx("codex_open", -2.0)
	_assert_true(open_res != null, "codex_open prosedürel sesi başarıyla tetiklendi")

	var close_res = audio_mgr.play_sfx("codex_close", -2.0)
	_assert_true(close_res != null, "codex_close prosedürel sesi başarıyla tetiklendi")

	var unlock_res = audio_mgr.play_sfx("codex_unlock", -2.0)
	_assert_true(unlock_res != null, "codex_unlock prosedürel sesi başarıyla tetiklendi")
