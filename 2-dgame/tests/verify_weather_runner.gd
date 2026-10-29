extends Node

## res://tests/verify_weather_runner.gd
## Story 2D-149: Seviye Bazlı Hava Durumu Sistemi Doğrulama Paketi

var tests_passed: int = 0
var tests_failed: int = 0


func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		tests_passed += 1
		print("PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("FAIL: %s" % msg)


func _ready() -> void:
	print("\n========================================================")
	print("  TEST: Story 2D-149 Seviye Bazlı Hava Durumu Doğrulama   ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d HAVA DURUMU TESTLERİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ HAVA DURUMU TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	_test_initialization()
	_test_profiles_and_emitters()
	_test_intensity_scaling()
	_test_intensity_off_disables_all()
	_test_lightning_sound_timing()
	_test_reduce_flashing_accessibility()
	_test_cleanup_on_scene_change()
	_test_level_profile_mapping()
	_test_settings_dialog_sync()


# ---------------------------------------------------------------------------
# Test 1: Başlatma ve Singleton Kaydı
# ---------------------------------------------------------------------------
func _test_initialization() -> void:
	print("\n--- Test 1: Başlatma ve Singleton Kaydı ---")
	var wm = get_node_or_null("/root/WeatherManager")
	_assert_true(wm != null, "WeatherManager Autoload singleton olarak yüklendi.")


# ---------------------------------------------------------------------------
# Test 2: Profiller ve Partikül Yayıcıları
# ---------------------------------------------------------------------------
func _test_profiles_and_emitters() -> void:
	print("\n--- Test 2: Profiller ve Partikül Yayıcıları ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_intensity(3) # HIGH

	# RAIN profili
	wm.set_profile(1) # RAIN
	_assert_true(wm.is_weather_active(), "RAIN profili aktif olarak raporlandı.")
	_assert_true(wm.get_active_particle_count() > 0, "RAIN profilinde yağmur partikülleri üretildi (%d partikül)." % wm.get_active_particle_count())

	# WIND profili
	wm.set_profile(2) # WIND
	_assert_true(wm.is_weather_active(), "WIND profili aktif.")
	_assert_true(wm.get_active_particle_count() > 0, "WIND profilinde rüzgâr partikülleri üretildi (%d partikül)." % wm.get_active_particle_count())

	# FOG profili
	wm.set_profile(3) # FOG
	_assert_true(wm.is_weather_active(), "FOG profili aktif.")
	_assert_true(wm.get_active_particle_count() > 0, "FOG profilinde sis partikülleri üretildi (%d partikül)." % wm.get_active_particle_count())

	# ASH profili (Ordugâh baskını)
	wm.set_profile(5) # ASH
	_assert_true(wm.is_weather_active(), "ASH profili aktif.")
	_assert_true(wm.get_active_particle_count() > 0, "ASH profilinde kül/kıvılcım partikülleri üretildi (%d partikül)." % wm.get_active_particle_count())

	# CLEAR profili
	wm.set_profile(0) # CLEAR
	_assert_true(not wm.is_weather_active(), "CLEAR profilinde hava durumu kapalı.")
	_assert_true(wm.get_active_particle_count() == 0, "CLEAR profilinde partikül sayısı 0.")


# ---------------------------------------------------------------------------
# Test 3: Yoğunluk Ölçekleme (HIGH > MEDIUM > LOW)
# ---------------------------------------------------------------------------
func _test_intensity_scaling() -> void:
	print("\n--- Test 3: Yoğunluk Ölçekleme (HIGH > MEDIUM > LOW) ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_profile(1) # RAIN

	wm.set_intensity(3) # HIGH
	var high_count = wm.get_active_particle_count()

	wm.set_intensity(2) # MEDIUM
	var med_count = wm.get_active_particle_count()

	wm.set_intensity(1) # LOW
	var low_count = wm.get_active_particle_count()

	print("Partikül Yoğunlukları: HIGH=%d, MEDIUM=%d, LOW=%d" % [high_count, med_count, low_count])
	_assert_true(high_count > med_count, "HIGH yoğunluk MEDIUM'dan daha fazla partikül üretiyor.")
	_assert_true(med_count > low_count, "MEDIUM yoğunluk LOW'dan daha fazla partikül üretiyor.")
	_assert_true(low_count > 0, "LOW yoğunlukta temel efekt korunuyor.")


# ---------------------------------------------------------------------------
# Test 4: Yoğunluk %0 / OFF İken Tamamen Devre Dışı Kalma
# ---------------------------------------------------------------------------
func _test_intensity_off_disables_all() -> void:
	print("\n--- Test 4: Yoğunluk OFF İken Tamamen Devre Dışı Kalma ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_profile(4) # LIGHTNING
	wm.set_intensity(0) # OFF

	_assert_true(not wm.is_weather_active(), "Yoğunluk OFF iken is_weather_active false döndü.")
	_assert_true(wm.get_active_particle_count() == 0, "Yoğunluk OFF iken partikül sayısı 0.")

	# Şimşek tetiklenmeyi dene
	wm.trigger_lightning(1.0, 0.2)
	_assert_true(wm._flash_rect == null or is_zero_approx(wm._flash_rect.color.a), "Yoğunluk OFF iken şimşek flaşı tetiklenmedi.")


# ---------------------------------------------------------------------------
# Test 5: Şimşek ve Gök Gürültüsü Zamanlaması (Işık - Ses Gecikmesi)
# ---------------------------------------------------------------------------
func _test_lightning_sound_timing() -> void:
	print("\n--- Test 5: Şimşek ve Gök Gürültüsü Zamanlaması ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_intensity(3) # HIGH
	wm.set_profile(4, true) # LIGHTNING (force_reload = true)

	var results := {
		"flash_struck": false,
		"thunder_heard": false
	}

	var on_flash := func(_intensity): results["flash_struck"] = true
	var on_thunder := func(): results["thunder_heard"] = true

	wm.lightning_struck.connect(on_flash)
	wm.thunder_played.connect(on_thunder)

	# 0.15s ses gecikmesiyle şimşek çaktır
	wm.trigger_lightning(1.0, 0.15)
	_assert_true(results["flash_struck"], "Şimşek tetiklendiğinde önce görsel flaş yayıldı.")
	_assert_true(not results["thunder_heard"], "Işık hızından dolayı başlangıçta henüz ses duyulmadı (mesafe gecikmesi).")

	# Gecikme süresi kadar ilerlet
	wm._sound_delay_timer.timeout.emit()
	_assert_true(results["thunder_heard"], "Ses gecikmesi tamamlandığında gök gürültüsü duyuldu.")

	wm.lightning_struck.disconnect(on_flash)
	wm.thunder_played.disconnect(on_thunder)


# ---------------------------------------------------------------------------
# Test 6: Erişilebilirlik (reduce_flashing) ile Flaş Kapatma
# ---------------------------------------------------------------------------
func _test_reduce_flashing_accessibility() -> void:
	print("\n--- Test 6: Erişilebilirlik (reduce_flashing) ile Flaş Kapatma ---")
	var cin = get_node_or_null("/root/CinematicManager")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_intensity(3)
	wm.set_profile(4)

	var prev_flash = cin.reduce_flashing if cin else false
	if cin:
		cin.set_reduce_flashing(true)

	wm.trigger_lightning(1.0, 0.2)
	if wm._flash_rect:
		_assert_true(wm._flash_rect.color.r < 0.5, "reduce_flashing aktifken sert beyaz flaş yerine loş/yumuşak ton uygulandı.")

	if cin:
		cin.set_reduce_flashing(prev_flash)


# ---------------------------------------------------------------------------
# Test 7: Sahne Değişiminde Kaynakların Temizlenmesi
# ---------------------------------------------------------------------------
func _test_cleanup_on_scene_change() -> void:
	print("\n--- Test 7: Sahne Değişiminde Kaynakların Temizlenmesi ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_intensity(3)
	wm.set_profile(1) # RAIN
	_assert_true(wm._weather_canvas != null, "Hava durumu canvas katmanı oluşturuldu.")

	# clean_weather çağrısı
	wm.clean_weather()
	_assert_true(wm._weather_canvas == null, "clean_weather sonrası canvas katmanı tamamen temizlendi.")
	_assert_true(wm.get_active_particle_count() == 0, "Temizlik sonrası partiküller sıfırlandı.")


# ---------------------------------------------------------------------------
# Test 8: Seviye Türüne Göre Otomatik Profil Eşleme
# ---------------------------------------------------------------------------
func _test_level_profile_mapping() -> void:
	print("\n--- Test 8: Seviye Türüne Göre Otomatik Profil Eşleme ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_intensity(3)

	# Simüle edilmiş seviye düğümleri
	var valley_dummy = Node.new()
	valley_dummy.scene_file_path = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"
	wm._on_scene_changed(valley_dummy)
	_assert_true(wm.get_current_profile() == 4, "Tarih öncesi vadi sahnesi LIGHTNING profili ile eşlendi.")
	valley_dummy.queue_free()

	var camp_dummy = Node.new()
	camp_dummy.scene_file_path = "res://scenes/levels/vlad/stage_1_forest_camp.tscn"
	wm._on_scene_changed(camp_dummy)
	_assert_true(wm.get_current_profile() == 5, "Ordugâh sahnesi ASH profili ile eşlendi.")
	camp_dummy.queue_free()

	var menu_dummy = Node.new()
	menu_dummy.scene_file_path = "res://scenes/ui/main_menu.tscn"
	wm._on_scene_changed(menu_dummy)
	_assert_true(wm.get_current_profile() == 0, "Ana menü sahnesinde hava durumu CLEAR olarak kapatıldı (taşma engellendi).")
	menu_dummy.queue_free()


# ---------------------------------------------------------------------------
# Test 9: Ayarlar Menüsü (SettingsDialog) Entegrasyonu
# ---------------------------------------------------------------------------
func _test_settings_dialog_sync() -> void:
	print("\n--- Test 9: Ayarlar Menüsü Entegrasyonu ---")
	var wm = get_node_or_null("/root/WeatherManager")
	wm.set_intensity(2) # MEDIUM

	var settings_scene: PackedScene = load("res://scenes/ui/settings_dialog.tscn")
	var dialog = settings_scene.instantiate()
	add_child(dialog)

	dialog.open()

	var weather_opt: OptionButton = dialog.find_child("WeatherOption", true, false) as OptionButton
	_assert_true(weather_opt != null, "SettingsDialog içinde WeatherOption mevcut.")
	_assert_true(weather_opt.selected == 2, "WeatherOption mevcut WeatherManager değerini (2: MEDIUM) yansıtıyor.")

	# Seçim değiştirilince WeatherManager'a yansıma
	weather_opt.item_selected.emit(1) # LOW
	_assert_true(wm.get_intensity() == 1, "WeatherOption seçimi değiştirilince WeatherManager güncellendi (1: LOW).")

	# Kalıcılık kontrolü
	wm.save_settings()
	_assert_true(FileAccess.file_exists("user://game_settings.json"), "Hava durumu ayarı user://game_settings.json dosyasına kaydedildi.")

	# Varsayılana geri al
	wm.set_intensity(3)
	wm.clean_weather()
	dialog.queue_free()
