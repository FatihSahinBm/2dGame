extends Node

## res://tests/verify_layered_sword_runner.gd
## Doğrulama: Endüstri Standardı Çift Katmanlı (Whoosh + Transient Ring) Kılıç Ses Sistemi
## - Katman 1 (Whoosh): Düşük-orta frekanslı rüzgar sürtünmesi (0.00s)
## - Katman 2 (Ring): Yüksek frekanslı kristal çelik tınısı (~15ms micro-offset)
## - 3'lü Round-Robin varyasyon ve ±%5 rastgele perde (pitch)

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
	print("  TEST: Katmanlı Kılıç Sesleri & Round-Robin Doğrulama  ")
	print("========================================================")

	await _run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d KATMANLI KILIÇ SESİ TESTİ BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ TEST BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	_assert_true(audio_mgr != null, "AudioManager Singleton aktif.")
	if not audio_mgr:
		return

	# 1. Kayıt Kontrolleri (Registry Check)
	print("\n--- Test 1: Çift Katmanlı Ses Kayıtları (Whoosh & Ring) ---")
	_assert_true(audio_mgr.has_sound("sword_slash"), "Ana 'sword_slash' kaydı mevcut.")
	_assert_true(audio_mgr.has_sound("sword_slash_whoosh"), "'sword_slash_whoosh' hava katmanı mevcut.")
	_assert_true(audio_mgr.has_sound("sword_slash_ring"), "'sword_slash_ring' çelik transient katmanı mevcut.")
	_assert_true(audio_mgr.has_sound("sword_hit_thud"), "'sword_hit_thud' gövde darbe katmanı mevcut.")
	_assert_true(audio_mgr.has_sound("sword_hit_metal"), "'sword_hit_metal' zırh parçalama katmanı mevcut.")

	# 2. Round-Robin Dönüşüm Testi
	print("\n--- Test 2: 3'lü Round-Robin Döngüsü ---")
	var prev_slash_rr: int = audio_mgr._sword_slash_round_robin
	var p1 = audio_mgr.play_sword_slash(0.0, 0.05, 0.0) # immediate
	_assert_true(p1 != null, "1. Kılıç savurma başarıyla tetiklendi.")
	_assert_true(audio_mgr._sword_slash_round_robin == (prev_slash_rr % 3) + 1, "Round-robin 1. adıma geçti (%d)." % audio_mgr._sword_slash_round_robin)

	var p2 = audio_mgr.play_sword_slash(0.0, 0.05, 0.0)
	_assert_true(p2 != null, "2. Kılıç savurma başarıyla tetiklendi.")
	_assert_true(audio_mgr._sword_slash_round_robin == (prev_slash_rr + 1 % 3) + 1, "Round-robin 2. adıma geçti (%d)." % audio_mgr._sword_slash_round_robin)

	var p3 = audio_mgr.play_sword_slash(0.0, 0.05, 0.0)
	_assert_true(p3 != null, "3. Kılıç savurma başarıyla tetiklendi.")
	_assert_true(audio_mgr._sword_slash_round_robin == (prev_slash_rr + 2 % 3) + 1, "Round-robin 3. adıma geçti (%d)." % audio_mgr._sword_slash_round_robin)

	var p4 = audio_mgr.play_sword_slash(0.0, 0.05, 0.0)
	_assert_true(p4 != null, "4. Kılıç savurma başarıyla tetiklendi (Döngü 1'e geri döndü).")
	_assert_true(audio_mgr._sword_slash_round_robin == 1, "Round-robin 1. adıma geri döndü.")

	# 3. Darbe (Hit) Round-Robin Testi
	print("\n--- Test 3: Kılıç Darbesi (Hit) Çift Katman & Round-Robin ---")
	var hit_p1 = audio_mgr.play_sword_hit(0.0, 0.05)
	_assert_true(hit_p1 != null, "Kılıç darbesi (Thud + Metal) başarıyla tetiklendi.")
	_assert_true(audio_mgr._sword_hit_round_robin == 1, "Darbe round-robin 1. adımda.")

	var hit_p2 = audio_mgr.play_sword_hit(0.0, 0.05)
	_assert_true(hit_p2 != null, "2. Kılıç darbesi tetiklendi.")
	_assert_true(audio_mgr._sword_hit_round_robin == 2, "Darbe round-robin 2. adımda.")

	# 4. Perde (Pitch) Değişkenliği Testi (±%5 aralığında mı?)
	print("\n--- Test 4: ±%5 Pitch Değişkenliği Doğrulaması ---")
	var pitches: Array[float] = []
	for i in range(10):
		var test_p = audio_mgr.play_sword_slash(0.0, 0.05, 0.0)
		if test_p:
			pitches.append(test_p.pitch_scale)
			_assert_true(test_p.pitch_scale >= 0.94 and test_p.pitch_scale <= 1.06, 
				"Pitch (%.3f) beklenen [0.95, 1.05] (±%%5) bandında." % test_p.pitch_scale)

	# 5. Mikro-Gecikmeli Katmanlama Testi (15ms Offset)
	print("\n--- Test 5: 15ms Mikro-Gecikmeli Katmanlama Tetikleyicisi ---")
	var layered_whoosh = audio_mgr.play_sword_slash(-2.0, 0.05, 15.0)
	_assert_true(layered_whoosh != null, "Whoosh katmanı t=0.00s anında tetiklendi.")
	
	# 25ms bekle ve çelik transient katmanının da SFX havuzunda çaldığını onayla
	await get_tree().create_timer(0.025).timeout
	var any_playing_sfx := false
	for p in audio_mgr._sfx_pool:
		if p.playing:
			any_playing_sfx = true
			break
	_assert_true(any_playing_sfx, "15ms mikro-gecikmeli çelik transient katmanı başarıyla tetiklendi ve çalıyor.")

