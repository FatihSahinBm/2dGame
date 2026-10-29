extends Node

## res://tests/verify_positional_audio_runner.gd
## Story 2D-112: 2D Konumsal Ses ve Ortam Sesleri Doğrulama Paketi

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
	print("  TEST: Story 2D-112 2D Konumsal & Ortam Sesleri Testi ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d KONUMSAL SES TESTİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ KONUMSAL SES TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager Autoload singleton mevcut.")
	if not audio_mgr:
		return

	_test_positional_emitter_creation()
	_test_duplicate_playback_prevention()
	_test_distance_attenuation_and_stereo()
	_test_distance_culling()
	_test_fade_in_and_fade_out()
	_test_zone_ambience_layers(audio_mgr)
	_test_procedural_positional_sounds(audio_mgr)
	_test_brazier_positional_integration()


# ---------------------------------------------------------------------------
# Test 1: PositionalAudioEmitter2D Bileşeni Kurulumu ve Doğrulama
# ---------------------------------------------------------------------------
func _test_positional_emitter_creation() -> void:
	print("\n--- Test 1: PositionalAudioEmitter2D Kurulumu ---")

	var EmitterScript = preload("res://scripts/audio/positional_audio_emitter_2d.gd")
	var emitter = Node2D.new()
	emitter.set_script(EmitterScript)
	emitter.sound_key = "torch"
	emitter.max_distance = 550.0
	emitter.volume_db = -3.0
	emitter.loop = true
	emitter.autoplay = false
	add_child(emitter)

	emitter._init_player()
	var player = emitter.get_player()
	_assert_true(player != null, "Dahili AudioStreamPlayer2D oluşturuldu.")
	_assert_true(player.max_distance == 550.0, "Maksimum duyulma mesafesi 550.0 olarak atandı.")
	_assert_true(player.bus == "SFX", "Varsayılan ses yolu SFX olarak atandı.")
	_assert_true(player.panning_strength == 1.0, "Stereo konumlandırma (panning) tam güçte (1.0).")

	emitter.queue_free()


# ---------------------------------------------------------------------------
# Test 2: Çift Çalımı ve Üst Üste Binmeyi Önleme (Anti-Overlap Guard)
# ---------------------------------------------------------------------------
func _test_duplicate_playback_prevention() -> void:
	print("\n--- Test 2: Çift Çalımı Önleme (Anti-Overlap) ---")

	var EmitterScript = preload("res://scripts/audio/positional_audio_emitter_2d.gd")
	var emitter = Node2D.new()
	emitter.set_script(EmitterScript)
	emitter.sound_key = "campfire"
	emitter.loop = true
	emitter.autoplay = false
	add_child(emitter)

	emitter.play_sound()
	_assert_true(emitter.is_playing(), "Döngüsel ses başarıyla çalmaya başladı.")

	# Tekrar play_sound() çağrıldığında sesi kesip baştan başlatmamalı
	var player = emitter.get_player()
	var prev_stream = player.stream
	emitter.play_sound()
	_assert_true(player.stream == prev_stream, "Çalan döngüsel ses mükerrer çağrıda kesilmedi veya sıfırlanmadı.")

	emitter.stop_sound()
	_assert_true(not emitter.is_playing(), "stop_sound() sesi durdurdu.")

	emitter.queue_free()


# ---------------------------------------------------------------------------
# Test 3: Mesafeye Bağlı Zayıflama ve Stereo Konumlandırma
# ---------------------------------------------------------------------------
func _test_distance_attenuation_and_stereo() -> void:
	print("\n--- Test 3: Mesafeye Bağlı Zayıflama ve Konumlandırma ---")

	var EmitterScript = preload("res://scripts/audio/positional_audio_emitter_2d.gd")
	var emitter = Node2D.new()
	emitter.set_script(EmitterScript)
	emitter.sound_key = "waterfall"
	emitter.max_distance = 800.0
	emitter.attenuation = 1.5
	emitter.autoplay = false
	add_child(emitter)

	emitter.global_position = Vector2(400.0, 150.0)
	emitter.play_sound()

	var player = emitter.get_player()
	_assert_true(player.attenuation == 1.5, "Mesafe zayıflama katsayısı (attenuation) 1.5 olarak uygulandı.")
	_assert_true(player.max_distance == 800.0, "Maksimum duyulma mesafesi 800.0.")
	_assert_true(player.global_position == Vector2(400.0, 150.0), "Ses kaynağı Vector2(400, 150) konumunda stereo yayım yapıyor.")

	emitter.queue_free()


# ---------------------------------------------------------------------------
# Test 4: Uzak Nesneler için Mesafe Kırpma (Distance Culling)
# ---------------------------------------------------------------------------
func _test_distance_culling() -> void:
	print("\n--- Test 4: Uzak Nesneler için Mesafe Kırpma (Distance Culling) ---")

	var EmitterScript = preload("res://scripts/audio/positional_audio_emitter_2d.gd")
	var emitter = Node2D.new()
	emitter.set_script(EmitterScript)
	emitter.sound_key = "torch"
	emitter.max_distance = 400.0
	emitter.cull_margin = 100.0
	emitter.enable_culling = true
	emitter.autoplay = false
	add_child(emitter)

	emitter.global_position = Vector2(0, 0)
	emitter.play_sound()
	_assert_true(emitter.is_playing(), "Yakın mesafede ses aktif olarak çalıyor.")

	# Emitter dinleyiciden çok uzağa taşındığında
	emitter.global_position = Vector2(3000.0, 3000.0)
	emitter._process(0.1)
	_assert_true(emitter.is_culled(), "Menzil dışına çıkınca mesafe kırpma (culling) tetiklendi.")
	_assert_true(not emitter.is_playing(), "Kırpılan ses işlemci tasarrufu için duraklatıldı/kırpıldı (is_playing = false).")

	# Geri yakına getirildiğinde
	emitter.global_position = Vector2(50.0, 50.0)
	emitter._process(0.1)
	_assert_true(not emitter.is_culled(), "Menzile girince kırpma kaldırıldı.")
	_assert_true(emitter.is_playing(), "Menzildeki ses otomatik olarak sürdürüldü (is_playing = true).")

	emitter.queue_free()


# ---------------------------------------------------------------------------
# Test 5: Yumuşak Fade-In ve Fade-Out
# ---------------------------------------------------------------------------
func _test_fade_in_and_fade_out() -> void:
	print("\n--- Test 5: Yumuşak Fade-In ve Fade-Out ---")

	var EmitterScript = preload("res://scripts/audio/positional_audio_emitter_2d.gd")
	var emitter = Node2D.new()
	emitter.set_script(EmitterScript)
	emitter.sound_key = "torch"
	emitter.volume_db = -4.0
	emitter.autoplay = false
	add_child(emitter)

	emitter.play_sound(0.1)
	_assert_true(emitter.is_playing(), "Fade-in ile ses başlatıldı.")
	_assert_true(emitter._player.volume_db <= -4.0, "Başlangıç ses seviyesi güvenli aralıkta.")

	emitter.stop_sound(0.05)
	emitter.queue_free()


# ---------------------------------------------------------------------------
# Test 6: Taş Devri, Eflak ve Ordugâh Bölgesel Ortam Katmanları
# ---------------------------------------------------------------------------
func _test_zone_ambience_layers(audio_mgr: Node) -> void:
	print("\n--- Test 6: Bölgesel Ortam Sesleri (Zone Ambience) ---")

	# Taş Devri / Tarih Öncesi Vadi Ambiyansı
	audio_mgr.play_zone_ambience("prehistoric", 0.1, -6.0)
	_assert_true(audio_mgr.get_current_ambience_key() == "prehistoric_ambience", "Taş Devri için 'prehistoric_ambience' başlatıldı.")
	_assert_true(audio_mgr._ambience_player != null and audio_mgr._ambience_player.playing, "Ambience player aktif olarak çalıyor.")

	# Eflak / Gotik Vlad Kalesi Ambiyansı (Yumuşak Cross-Fade ile)
	audio_mgr.play_zone_ambience("wallachia", 0.1, -5.0)
	_assert_true(audio_mgr.get_current_ambience_key() == "vlad_ambience", "Eflak bölgesine geçişte 'vlad_ambience' cross-fade ile devreye girdi.")

	# Ordugâh Ambiyansı
	audio_mgr.play_zone_ambience("camp", 0.1, -6.0)
	_assert_true(audio_mgr.get_current_ambience_key() == "camp_ambience", "Ordugâh sahnesine geçişte 'camp_ambience' devreye girdi.")

	# Ambiyansı durdurma
	audio_mgr.stop_ambience(0.05)


# ---------------------------------------------------------------------------
# Test 7: Prosedürel Konumsal Ses Kayıtları
# ---------------------------------------------------------------------------
func _test_procedural_positional_sounds(audio_mgr: Node) -> void:
	print("\n--- Test 7: Prosedürel Konumsal Sesler ---")

	var required_sounds = [
		"torch", "campfire", "waterfall", "enemy_step", "dungeon_drip",
		"prehistoric_ambience", "vlad_ambience", "camp_ambience"
	]

	for s in required_sounds:
		_assert_true(audio_mgr.has_sound(s), "Prosedürel ses kaydı mevcut: '%s'" % s)

	# 2D çalma doğrulamaları
	var p_torch = audio_mgr.play_sound_2d("torch", Vector2(100, 100))
	_assert_true(p_torch != null and p_torch.playing, "Meşale konumsal sesi 2D havuzundan başarıyla çaldı.")

	var p_step = audio_mgr.play_sound_2d("enemy_step", Vector2(200, 50))
	_assert_true(p_step != null and p_step.playing, "Düşman adım sesi 2D havuzundan başarıyla çaldı.")

	var p_water = audio_mgr.play_sound_2d("waterfall", Vector2(300, 300))
	_assert_true(p_water != null and p_water.playing, "Şelale konumsal sesi 2D havuzundan başarıyla çaldı.")


# ---------------------------------------------------------------------------
# Test 8: BloodAltarBrazier Konumsal Ses Entegrasyonu
# ---------------------------------------------------------------------------
func _test_brazier_positional_integration() -> void:
	print("\n--- Test 8: BloodAltarBrazier Konumsal Ses Entegrasyonu ---")

	var BrazierScript = preload("res://scripts/objects/blood_altar_brazier.gd")
	var brazier = Area2D.new()
	brazier.set_script(BrazierScript)
	add_child(brazier)

	_assert_true(brazier._audio_emitter == null, "Mangal sönükken ses yayımı yok.")

	brazier.ignite_brazier()
	_assert_true(brazier._audio_emitter != null, "Mangal yakılınca PositionalAudioEmitter2D otomatik oluşturuldu.")
	_assert_true(brazier._audio_emitter.sound_key == "torch", "Mangal meşale ('torch') ses anahtarını kullanıyor.")
	_assert_true(brazier._audio_emitter.is_playing(), "Mangal yakılınca konumsal ateş sesi çalmaya başladı.")

	brazier.queue_free()
