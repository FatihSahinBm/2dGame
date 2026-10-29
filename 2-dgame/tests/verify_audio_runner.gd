extends Node

## res://tests/verify_audio_runner.gd
## Story 2D-110: Merkezi Ses Yöneticisi (AudioManager) Doğrulama Paketi

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
	print("  TEST: Story 2D-110 Merkezi Ses Yöneticisi Doğrulama   ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d SES YÖNETİCİSİ TESTİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ SES TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	_test_autoload_and_buses()
	_test_bus_volume_controls()
	_test_sfx_pool_and_recycling()
	_test_procedural_sounds()
	_test_missing_sound_key_safety()
	_test_music_crossfade_and_tracking()
	_test_ambience_and_dialogue()
	_test_positional_2d_audio()
	_test_settings_persistence()
	_test_settings_dialog_integration()


# ---------------------------------------------------------------------------
# Test 1: Autoload Başlatma ve Bus Kontrolü
# ---------------------------------------------------------------------------
func _test_autoload_and_buses() -> void:
	print("\n--- Test 1: Autoload Başlatma ve Bus Kontrolü ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager Autoload singleton olarak yüklendi.")

	var required_buses = ["Master", "Music", "SFX", "Dialogue", "Ambience"]
	for bus in required_buses:
		_assert_true(audio_mgr.has_bus(bus), "Ses yolu '%s' mevcut." % bus)
		var idx = AudioServer.get_bus_index(bus)
		_assert_true(idx != -1, "AudioServer '%s' yol indeksine sahip (%d)." % [bus, idx])
		if bus != "Master":
			var send_to = AudioServer.get_bus_send(idx)
			_assert_true(send_to == "Master", "'%s' ses yolu çıkışı Master'a yönlendirildi (Send: %s)." % [bus, send_to])


# ---------------------------------------------------------------------------
# Test 2: Bağımsız Bus Ses Seviyeleri ve Sessize Alma (Mute)
# ---------------------------------------------------------------------------
func _test_bus_volume_controls() -> void:
	print("\n--- Test 2: Bağımsız Bus Ses Seviyeleri ve Mute ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	# Linear seviye ayarı
	audio_mgr.set_bus_volume_linear("SFX", 0.75)
	var sfx_vol = audio_mgr.get_bus_volume_linear("SFX")
	_assert_true(absf(sfx_vol - 0.75) < 0.05, "SFX linear ses seviyesi 0.75 olarak ayarlandı (Okunan: %.2f)." % sfx_vol)

	# dB seviye ayarı
	audio_mgr.set_bus_volume_db("Music", -12.0)
	var music_db = audio_mgr.get_bus_volume_db("Music")
	_assert_true(absf(music_db - (-12.0)) < 0.1, "Music dB ses seviyesi -12 dB olarak ayarlandı (Okunan: %.2f dB)." % music_db)

	# Mute (Sessize alma)
	audio_mgr.set_bus_mute("Dialogue", true)
	_assert_true(audio_mgr.is_bus_muted("Dialogue"), "Dialogue yolu sessize alındı (muted = true).")
	audio_mgr.set_bus_mute("Dialogue", false)
	_assert_true(not audio_mgr.is_bus_muted("Dialogue"), "Dialogue yolu sesi açıldı (muted = false).")


# ---------------------------------------------------------------------------
# Test 3: SFX Havuzu ve Geri Dönüşüm (Pooling & Concurrency)
# ---------------------------------------------------------------------------
func _test_sfx_pool_and_recycling() -> void:
	print("\n--- Test 3: SFX Havuzu ve Eşzamanlılık (max_concurrent_sfx = 16) ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr.max_concurrent_sfx == 16, "Maksimum eşzamanlı SFX limiti 16.")

	# 16 sesi ardışık çal
	var spawned_players: Array[AudioStreamPlayer] = []
	for i in range(16):
		var p = audio_mgr.play_sfx("jump")
		_assert_true(p != null, "SFX player %d başarıyla alındı ve tetiklendi." % (i + 1))
		spawned_players.append(p)

	# 17. ses istendiğinde havuza geri dönüşüm (recycling) yaparak en eskiyi kullanmalı
	var recycled = audio_mgr.play_sfx("ui_click")
	_assert_true(recycled != null, "17. SFX talebinde havuz taşmadı, round-robin recycling ile oyuncu yeniden kullanıldı.")

	# Tüm SFX durdurma
	audio_mgr.stop_all_sfx()
	var any_playing := false
	for p in spawned_players:
		if p.playing:
			any_playing = true
			break
	_assert_true(not any_playing, "stop_all_sfx() tüm SFX oyuncularını başarıyla durdurdu.")


# ---------------------------------------------------------------------------
# Test 4: Prosedürel Ses Sentezleme Yedeği
# ---------------------------------------------------------------------------
func _test_procedural_sounds() -> void:
	print("\n--- Test 4: Prosedürel Ses Sentezleme Fallback ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	var builtins = ["ui_click", "jump", "dash", "sword_slash", "sword_hit", "player_hurt", "menu_theme", "prehistoric_theme", "vlad_theme"]
	for s in builtins:
		_assert_true(audio_mgr.has_sound(s), "Prosedürel ses kaydı mevcut: '%s'" % s)

	# Harici ses dosyası kaydetme ve çalma
	var custom_stream = AudioStreamGenerator.new()
	audio_mgr.register_sound("custom_slash", custom_stream)
	_assert_true(audio_mgr.has_sound("custom_slash"), "Özel ses anahtarı ('custom_slash') başarıyla kaydedildi.")

	var custom_player = audio_mgr.play_sfx("custom_slash")
	_assert_true(custom_player != null and custom_player.stream == custom_stream, "Özel ses akışı doğru şekilde SFX oyuncusuna atandı.")


# ---------------------------------------------------------------------------
# Test 5: Olmayan Ses Anahtarı Güvenliği (Crash Prevention)
# ---------------------------------------------------------------------------
func _test_missing_sound_key_safety() -> void:
	print("\n--- Test 5: Olmayan Ses Anahtarı Güvenliği ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	# Olmayan anahtarla SFX çalındığında oyun çökmemeli ve null dönmeli
	var p_sfx = audio_mgr.play_sfx("non_existent_key_12345")
	_assert_true(p_sfx == null, "Olmayan SFX anahtarı güvenle yakalandı ve null döndü (çökme yok).")

	var p_2d = audio_mgr.play_sound_2d("missing_2d_key_999", Vector2(50, 50))
	_assert_true(p_2d == null, "Olmayan 2D ses anahtarı güvenle yakalandı ve null döndü.")

	var p_dlg = audio_mgr.play_dialogue("missing_dialogue")
	_assert_true(p_dlg == null, "Olmayan diyalog sesi güvenle yakalandı.")


# ---------------------------------------------------------------------------
# Test 6: Müzik Yumuşak Çapraz Geçiş (Cross-Fade) ve İzleme
# ---------------------------------------------------------------------------
func _test_music_crossfade_and_tracking() -> void:
	print("\n--- Test 6: Müzik Cross-Fade ve Takip ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	var signal_state := { "received_key": "" }
	var on_music = func(key: String):
		signal_state["received_key"] = key

	audio_mgr.music_changed.connect(on_music)

	# İlk müzik
	audio_mgr.crossfade_music("menu_theme", 0.05, -6.0)
	_assert_true(audio_mgr.get_current_music_key() == "menu_theme", "Aktif müzik anahtarı 'menu_theme' olarak güncellendi.")
	_assert_true(signal_state["received_key"] == "menu_theme", "music_changed sinyali 'menu_theme' ile tetiklendi.")

	# İkinci müzik (cross-fade geçişi)
	audio_mgr.crossfade_music("prehistoric_theme", 0.05, -8.0)
	_assert_true(audio_mgr.get_current_music_key() == "prehistoric_theme", "Cross-fade sonrası aktif müzik 'prehistoric_theme' oldu.")
	_assert_true(signal_state["received_key"] == "prehistoric_theme", "music_changed sinyali yeni parça ile tetiklendi.")

	# Aynı parça tekrar istendiğinde yeniden başlatmamalı
	signal_state["received_key"] = ""
	audio_mgr.crossfade_music("prehistoric_theme", 0.05, -8.0)
	_assert_true(signal_state["received_key"] == "", "Aynı müzik çağrıldığında parça gereksiz yere baştan başlatılmadı.")

	# Müzik durdurma
	audio_mgr.stop_music(0.05)
	audio_mgr.music_changed.disconnect(on_music)


# ---------------------------------------------------------------------------
# Test 7: Ortam (Ambience) ve Diyalog (Dialogue)
# ---------------------------------------------------------------------------
func _test_ambience_and_dialogue() -> void:
	print("\n--- Test 7: Ortam ve Diyalog Çalıcıları ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	audio_mgr.play_ambience("menu_theme", 0.05, -10.0)
	_assert_true(audio_mgr._ambience_player != null and audio_mgr._ambience_player.playing, "Ambience player 'Ambience' bus üzerinde çalıyor.")
	_assert_true(audio_mgr._ambience_player.bus == "Ambience", "Ambience player doğru ses yoluna bağlı.")

	audio_mgr.stop_ambience(0.05)

	var dlg = audio_mgr.play_dialogue("ui_click", -3.0)
	_assert_true(dlg != null and dlg.playing, "Diyalog player 'Dialogue' bus üzerinde çalıyor.")
	_assert_true(dlg.bus == "Dialogue", "Diyalog player doğru ses yoluna bağlı.")


# ---------------------------------------------------------------------------
# Test 8: 2D Konumsal Ses (play_sound_2d)
# ---------------------------------------------------------------------------
func _test_positional_2d_audio() -> void:
	print("\n--- Test 8: 2D Konumsal Ses (play_sound_2d) ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	var target_pos := Vector2(250.0, 480.0)
	var p2d = audio_mgr.play_sound_2d("sword_hit", target_pos, null, 0.0, 1500.0)
	_assert_true(p2d != null, "2D konumsal ses oyuncusu başarıyla başlatıldı.")
	_assert_true(p2d is AudioStreamPlayer2D, "Dönen nesne AudioStreamPlayer2D tipinde.")
	_assert_true(p2d.global_position == target_pos, "2D ses oyuncusu hedeflenen koordinata konumlandırıldı (Vector2(250, 480)).")
	_assert_true(p2d.max_distance == 1500.0, "2D ses azami duyulma mesafesi (1500.0) atandı.")


# ---------------------------------------------------------------------------
# Test 9: Kalıcılık ve Ayar Dosyası (user://game_settings.json)
# ---------------------------------------------------------------------------
func _test_settings_persistence() -> void:
	print("\n--- Test 9: Kalıcılık ve Ayar Dosyası ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	audio_mgr.set_bus_volume_linear("Master", 0.82)
	audio_mgr.set_bus_volume_linear("Music", 0.65)
	audio_mgr.set_bus_volume_linear("SFX", 0.90)
	audio_mgr.save_audio_settings()

	_assert_true(FileAccess.file_exists("user://game_settings.json"), "user://game_settings.json ayar dosyası oluşturuldu.")

	var f = FileAccess.open("user://game_settings.json", FileAccess.READ)
	_assert_true(f != null, "Ayar dosyası okuma modunda açılabildi.")
	if f:
		var json = JSON.new()
		var parse_res = json.parse(f.get_as_text())
		_assert_true(parse_res == OK, "Ayar dosyası JSON formatı geçerli.")
		var data = json.data
		_assert_true(data.has("audio_settings"), "JSON içinde 'audio_settings' nesnesi mevcut.")
		var aud = data.get("audio_settings", {})
		_assert_true(absf(float(aud.get("master_volume", 0.0)) - 0.82) < 0.05, "Master ses seviyesi kalıcı olarak kaydedildi (%.2f)." % float(aud.get("master_volume", 0.0)))
		_assert_true(absf(float(aud.get("music_volume", 0.0)) - 0.65) < 0.05, "Music ses seviyesi kalıcı olarak kaydedildi (%.2f)." % float(aud.get("music_volume", 0.0)))
		_assert_true(absf(float(aud.get("sfx_volume", 0.0)) - 0.90) < 0.05, "SFX ses seviyesi kalıcı olarak kaydedildi (%.2f)." % float(aud.get("sfx_volume", 0.0)))
		f.close()


# ---------------------------------------------------------------------------
# Test 10: SettingsDialog Entegrasyonu
# ---------------------------------------------------------------------------
func _test_settings_dialog_integration() -> void:
	print("\n--- Test 10: SettingsDialog Entegrasyonu ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	var SettingsDialogScript = preload("res://scripts/ui/settings_dialog.gd")
	var dialog = PanelContainer.new()
	dialog.set_script(SettingsDialogScript)
	add_child(dialog)

	# Slider sinyal fonksiyonlarını doğrudan simüle et
	dialog._on_master_changed(45.0)
	_assert_true(absf(audio_mgr.get_bus_volume_linear("Master") - 0.45) < 0.05, "SettingsDialog Master kaydırıcısı AudioManager'a %45 ses iletti.")

	dialog._on_music_changed(60.0)
	_assert_true(absf(audio_mgr.get_bus_volume_linear("Music") - 0.60) < 0.05, "SettingsDialog Music kaydırıcısı AudioManager'a %60 ses iletti.")

	dialog._on_sfx_changed(72.0)
	_assert_true(absf(audio_mgr.get_bus_volume_linear("SFX") - 0.72) < 0.05, "SettingsDialog SFX kaydırıcısı AudioManager'a %72 ses iletti.")

	dialog.queue_free()

