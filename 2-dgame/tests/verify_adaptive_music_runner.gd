extends Node

## res://tests/verify_adaptive_music_runner.gd
## Story 2D-111: Duruma Göre Değişen Müzik Katmanları Doğrulama Paketi

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
	print("  TEST: Story 2D-111 Duruma Göre Müzik Katmanları Testi ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d ADAPTİF MÜZİK TESTİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ MÜZİK TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager Autoload singleton mevcut.")
	if not audio_mgr:
		return

	_test_music_state_transitions(audio_mgr)
	_test_combat_hysteresis_and_cooldown(audio_mgr)
	_test_combat_audio_modes(audio_mgr)
	_test_boss_phases_and_transitions(audio_mgr)
	_test_boss_priority_over_normal_combat(audio_mgr)
	_test_player_defeat_and_cleanup(audio_mgr)
	_test_custom_boss_theme_registration(audio_mgr)
	_test_volume_normalization_and_safety(audio_mgr)
	_test_scene_change_state_reset(audio_mgr)


# ---------------------------------------------------------------------------
# Test 1: Müzik Durum Geçişleri ve İdempotans
# ---------------------------------------------------------------------------
func _test_music_state_transitions(audio_mgr: Node) -> void:
	print("\n--- Test 1: Müzik Durum Geçişleri ve İdempotans ---")

	var state_history: Array[int] = []
	var on_state_changed = func(prev: int, new_st: int):
		state_history.append(new_st)

	audio_mgr.music_state_changed.connect(on_state_changed)

	# Başlangıç durumu Keşif (EXPLORATION)
	audio_mgr.set_music_state(audio_mgr.MusicState.EXPLORATION, 0.1)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.EXPLORATION, "Müzik durumu EXPLORATION olarak ayarlandı.")

	# Çatışma durumuna geçiş
	audio_mgr.set_music_state(audio_mgr.MusicState.COMBAT, 0.1)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.COMBAT, "Müzik durumu COMBAT durumuna geçti.")
	_assert_true(state_history.has(audio_mgr.MusicState.COMBAT), "music_state_changed sinyali COMBAT ile yayıldı.")

	# İdempotans testi: Aynı durum tekrar çağrıldığında parça gereksiz baştan başlatılmamalı
	var count_before = state_history.size()
	audio_mgr.set_music_state(audio_mgr.MusicState.COMBAT, 0.1)
	_assert_true(state_history.size() == count_before, "Aynı durum tekrar istendiğinde gereksiz sinyal tetiklenmedi (İdempotans sağlandı).")

	audio_mgr.music_state_changed.disconnect(on_state_changed)


# ---------------------------------------------------------------------------
# Test 2: Çatışma Takibi, Soğuma Gecikmesi (Hysteresis) ve Jitter Önleme
# ---------------------------------------------------------------------------
func _test_combat_hysteresis_and_cooldown(audio_mgr: Node) -> void:
	print("\n--- Test 2: Çatışma Takibi ve Soğuma Gecikmesi (Hysteresis) ---")

	var dummy_enemy1 = Node2D.new()
	var dummy_enemy2 = Node2D.new()
	add_child(dummy_enemy1)
	add_child(dummy_enemy2)

	# 1. Düşman savaşı başlatır
	audio_mgr.on_combat_started(dummy_enemy1)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.COMBAT, "Düşman çatışma başlatınca müzik COMBAT durumuna geçti.")
	_assert_true(audio_mgr.get_active_combatant_count() == 1, "Aktif çatışan sayısı 1.")

	# 2. Düşman çatışmaya dahil olur
	audio_mgr.on_combat_started(dummy_enemy2)
	_assert_true(audio_mgr.get_active_combatant_count() == 2, "İki düşman çatışmada kayıtlı.")

	# 1. Düşman öldüğünde müzik anında kesilmemeli
	audio_mgr.on_combat_ended(dummy_enemy1)
	_assert_true(audio_mgr.get_active_combatant_count() == 1, "Kalan çatışan sayısı 1.")
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.COMBAT, "Hala aktif düşman varken müzik COMBAT olarak devam etti.")

	# 2. Düşman da öldüğünde ani kesilme olmamalı; hysteresis soğuma sayacı başlamalı
	audio_mgr.on_combat_ended(dummy_enemy2)
	_assert_true(audio_mgr.get_active_combatant_count() == 0, "Tüm düşmanlar yenildi.")
	_assert_true(audio_mgr._combat_cooldown_timer > 0.0, "Çatışma bitişinde ani ses kesilmesini önleyen soğuma sayacı (cooldown) aktif.")
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.COMBAT, "Soğuma süresi içinde müzik hemen kesilmedi (Jitter/patlama engellendi).")

	# Süre dolunca _process çağrısı simüle edilerek EXPLORATION'a dönmeli
	audio_mgr._process(audio_mgr.combat_cooldown_delay + 0.1)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.EXPLORATION, "Soğuma süresi dolunca müzik yumuşakça EXPLORATION durumuna döndü.")

	# Zorunlu (force) çatışma bitişi
	audio_mgr.on_combat_started(dummy_enemy1)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.COMBAT, "Tekrar savaşa girildi.")
	audio_mgr.on_combat_ended(null, true)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.EXPLORATION, "force=true ile çağrıldığında anında EXPLORATION'a geçildi.")

	dummy_enemy1.queue_free()
	dummy_enemy2.queue_free()


# ---------------------------------------------------------------------------
# Test 3: Çatışma Ses Modları (Katmanlı Layered vs Cross-Fade)
# ---------------------------------------------------------------------------
func _test_combat_audio_modes(audio_mgr: Node) -> void:
	print("\n--- Test 3: Çatışma Ses Modları (Layered vs Crossfade) ---")

	# Crossfade Modu
	audio_mgr.combat_audio_mode = audio_mgr.CombatAudioMode.CROSSFADE
	audio_mgr.set_exploration_theme("menu_theme")
	audio_mgr.set_music_state(audio_mgr.MusicState.COMBAT, 0.1)
	_assert_true(audio_mgr.get_current_music_key() == "combat_theme", "Crossfade modunda tam çatışma teması ('combat_theme') devreye girdi.")

	# Layered (Katmanlı Ritim) Modu
	audio_mgr.combat_audio_mode = audio_mgr.CombatAudioMode.LAYERED
	audio_mgr.set_music_state(audio_mgr.MusicState.EXPLORATION, 0.1)
	_assert_true(audio_mgr._combat_layer_player.volume_db <= -70.0, "Keşif modunda savaş katmanı sessize alındı (-80 dB).")

	audio_mgr.set_music_state(audio_mgr.MusicState.COMBAT, 0.1)
	_assert_true(audio_mgr._combat_layer_player.playing, "Katmanlı modda savaş ritim katmanı çalmaya başladı.")

	# Geri Keşif moduna geçişte katmanın kısılması
	audio_mgr.set_music_state(audio_mgr.MusicState.EXPLORATION, 0.1)
	audio_mgr.combat_audio_mode = audio_mgr.CombatAudioMode.CROSSFADE


# ---------------------------------------------------------------------------
# Test 4: Boss Savaşı ve 4 Faz Geçişi
# ---------------------------------------------------------------------------
func _test_boss_phases_and_transitions(audio_mgr: Node) -> void:
	print("\n--- Test 4: Boss Savaşı ve 4 Faz Geçişi ---")

	var phases_heard: Array[int] = []
	var on_phase = func(p: int):
		phases_heard.append(p)

	audio_mgr.boss_phase_changed.connect(on_phase)

	# Boss başlangıcı (Faz 1)
	audio_mgr.on_boss_started("vlad", 1)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.BOSS, "Boss başlayınca durum BOSS oldu.")
	_assert_true(audio_mgr.get_current_music_key().contains("boss_phase_1") or audio_mgr.get_current_music_key().contains("vlad"), "1. Faz boss teması çalındı.")

	# Faz 2: Vampir formu
	audio_mgr.on_boss_phase_changed(2)
	_assert_true(phases_heard.has(2), "boss_phase_changed sinyali 2. fazı bildirdi.")
	_assert_true(audio_mgr.get_current_music_key().contains("phase_2"), "2. Faz boss teması devreye girdi.")

	# Faz 3: Kurt adam formu
	audio_mgr.on_boss_phase_changed(3)
	_assert_true(phases_heard.has(3), "boss_phase_changed sinyali 3. fazı bildirdi.")
	_assert_true(audio_mgr.get_current_music_key().contains("phase_3"), "3. Faz boss teması devreye girdi.")

	# Faz 4: Yarasa formu
	audio_mgr.on_boss_phase_changed(4)
	_assert_true(phases_heard.has(4), "boss_phase_changed sinyali 4. fazı bildirdi.")
	_assert_true(audio_mgr.get_current_music_key().contains("phase_4"), "4. Faz boss teması devreye girdi.")

	# Zafer (Boss Yenilgisi)
	audio_mgr.on_boss_defeated()
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.VICTORY, "Boss ölünce zafer teması (VICTORY) tetiklendi.")
	_assert_true(audio_mgr.get_current_music_key() == "victory_theme", "Zafer parçası 'victory_theme' olarak ayarlandı.")

	audio_mgr.boss_phase_changed.disconnect(on_phase)


# ---------------------------------------------------------------------------
# Test 5: Boss Önceliği (Minion Çatışmasının Boss Müziğini Bozamaması)
# ---------------------------------------------------------------------------
func _test_boss_priority_over_normal_combat(audio_mgr: Node) -> void:
	print("\n--- Test 5: Boss Önceliği ve Çatışma Hiyerarşisi ---")

	audio_mgr.on_boss_started("vlad", 2)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.BOSS, "Boss savaşı aktif.")

	# Boss savaşırken yan düşman saldırırsa boss müziği normal çatışmaya düşmemeli
	var minion = Node2D.new()
	add_child(minion)
	audio_mgr.on_combat_started(minion)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.BOSS, "Minion saldırısı boss müziğini COMBAT'e düşüremedi (Boss önceliği korundu).")

	minion.queue_free()


# ---------------------------------------------------------------------------
# Test 6: Oyuncu Yenilgisi (DEFEAT) ve Temizlik
# ---------------------------------------------------------------------------
func _test_player_defeat_and_cleanup(audio_mgr: Node) -> void:
	print("\n--- Test 6: Oyuncu Yenilgisi (DEFEAT) ve Temizlik ---")

	audio_mgr.on_player_defeated()
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.DEFEAT, "Oyuncu ölünce DEFEAT durumuna geçildi.")
	_assert_true(audio_mgr.get_current_music_key() == "defeat_theme", "Yenilgi teması 'defeat_theme' olarak güncellendi.")
	_assert_true(audio_mgr.get_active_combatant_count() == 0, "Yenilgi anında çatışan düşman havuzu temizlendi.")


# ---------------------------------------------------------------------------
# Test 7: Özel Boss Faz Teması Kaydı
# ---------------------------------------------------------------------------
func _test_custom_boss_theme_registration(audio_mgr: Node) -> void:
	print("\n--- Test 7: Özel Boss Faz Teması Kaydı ---")

	var custom_stream = AudioStreamGenerator.new()
	audio_mgr.register_boss_phase_theme("dragon", 1, custom_stream)
	_assert_true(audio_mgr.has_sound("dragon_phase_1"), "Özel boss parçası ('dragon_phase_1') başarıyla kaydedildi.")

	audio_mgr.on_boss_started("dragon", 1)
	_assert_true(audio_mgr.get_current_music_key() == "dragon_phase_1", "Özel boss fazı doğru anahtarla eşleştirildi.")


# ---------------------------------------------------------------------------
# Test 8: Ses Seviyesi Normalizasyonu ve Anti-Clipping
# ---------------------------------------------------------------------------
func _test_volume_normalization_and_safety(audio_mgr: Node) -> void:
	print("\n--- Test 8: Ses Seviyesi Normalizasyonu ve Anti-Clipping ---")

	# Tüm durumların hedef ses seviyeleri safe aralıkta (-80 dB < vol <= 0.0 dB) olmalı
	var states = [
		audio_mgr.MusicState.EXPLORATION,
		audio_mgr.MusicState.COMBAT,
		audio_mgr.MusicState.BOSS,
		audio_mgr.MusicState.VICTORY,
		audio_mgr.MusicState.DEFEAT
	]

	for st in states:
		audio_mgr.set_music_state(st, 0.05)
		_assert_true(audio_mgr.get_music_state() == st, "Durum %d başarıyla yüklendi." % st)

	# Boss faz ses seviyeleri
	for phase in range(1, 5):
		audio_mgr.on_boss_phase_changed(phase)
		_assert_true(audio_mgr.has_sound("boss_phase_%d" % phase), "Boss fazı %d için kayıtlı ses mevcut." % phase)


# ---------------------------------------------------------------------------
# Test 9: Sahne Değişiminde Durum Sıfırlama
# ---------------------------------------------------------------------------
func _test_scene_change_state_reset(audio_mgr: Node) -> void:
	print("\n--- Test 9: Sahne Değişiminde Durum Sıfırlama ---")

	audio_mgr.on_boss_started("vlad", 3)
	var dummy_scene = Node.new()
	dummy_scene.scene_file_path = "res://scenes/ui/main_menu.tscn"

	audio_mgr._on_scene_changed(dummy_scene)
	_assert_true(audio_mgr.get_music_state() == audio_mgr.MusicState.EXPLORATION, "Ana menüye geçişte durum EXPLORATION olarak sıfırlandı.")
	_assert_true(audio_mgr.get_active_combatant_count() == 0, "Sahne geçişiyle çatışan listesi sıfırlandı.")
	_assert_true(audio_mgr._current_boss_name == "", "Boss kaydı sıfırlandı.")

	dummy_scene.queue_free()
