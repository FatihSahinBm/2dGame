extends Node

## tests/verify_sword_rebellion_runner.gd
## Story 2D-125: Yüksek Yozlaşmada Kılıç İsyanı Otomatik Doğrulama Testi

func _ready() -> void:
	print("\n========================================================")
	print("  TEST: Story 2D-125 Yüksek Yozlaşmada Kılıç İsyanı     ")
	print("========================================================")

	var all_passed: bool = true

	# 1. GameState Autoload Kontrolü
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		printerr("FAIL: /root/GameState autoload bulunamadı!")
		get_tree().quit(1)
		return
	game_state.reset_state()
	print("PASS: /root/GameState sıfırlandı ve hazırlandı.")

	# 2. Player ve SwordRebellionManager Örneği Kurulumu
	var player_scene = load("res://scenes/combat/test_player.tscn")
	if not player_scene:
		player_scene = load("res://scenes/player.tscn")
	if not player_scene:
		printerr("FAIL: Oyuncu sahnesi yüklenemedi!")
		get_tree().quit(1)
		return

	var player = player_scene.instantiate()
	add_child(player)
	player.has_sword = true
	player.is_armed = true

	var srm = player.get_node_or_null("SwordRebellionManager")
	if not srm:
		printerr("FAIL: Oyuncu üzerinde SwordRebellionManager bulunamadı!")
		all_passed = false
	else:
		print("PASS: Oyuncu üzerinde SwordRebellionManager başarıyla ilklendirildi.")

	# --- TEST SENARYOSU 1: Düşük Yozlaşma (< 50) Kontrolü ---
	print("\n--- Test 1: Düşük Yozlaşmada İstenmeyen İsyan Tetiklenmemesi ---")
	game_state.corruption_score = 0
	var low_rebel_count = 0
	for i in range(10):
		srm.reset_cooldown()
		if srm.check_and_trigger_attack_rebellion():
			low_rebel_count += 1

	game_state.corruption_score = 35 # Eşik altı (orta yozlaşma)
	for i in range(10):
		srm.reset_cooldown()
		if srm.check_and_trigger_attack_rebellion():
			low_rebel_count += 1

	if low_rebel_count > 0:
		printerr("FAIL: Düşük yozlaşmada istenmeyen kılıç isyanı tetiklendi! Tetikleme sayısı: ", low_rebel_count)
		all_passed = false
	else:
		print("PASS: Düşük yozlaşmada (0 ve 35 skorlarında) 0 isyan tetiklendi; saldırılar kesintisiz.")

	# --- TEST SENARYOSU 2: Yüksek Yozlaşma (>= 50) İsyan Tetikleme ve Saldırı Kesilmesi ---
	print("\n--- Test 2: Yüksek Yozlaşmada (>= 50) İsyan ve Saldırıyı Kesme ---")
	game_state.corruption_score = 60
	if srm.get_corruption_tier() != "high":
		printerr("FAIL: Yozlaşma seviyesi 'high' olarak algılanmadı! Bulunan: ", srm.get_corruption_tier())
		all_passed = false
	else:
		print("PASS: Yüksek yozlaşma eşiği (60 skor) 'high' olarak algılandı.")

	# Deterministik test modunu aç (her saldırıda isyan tetikle)
	srm.set_test_deterministic_mode(true, 1)
	srm.reset_cooldown()

	# Oyuncu saldırı başlatmaya çalışır
	var interrupted = srm.check_and_trigger_attack_rebellion()
	if not interrupted:
		printerr("FAIL: Yüksek yozlaşmada saldırı isyan tarafından kesilmedi!")
		all_passed = false
	elif not player.is_rebelling:
		printerr("FAIL: Oyuncu isyan durumuna (is_rebelling = true) geçmedi!")
		all_passed = false
	elif player.is_attacking:
		printerr("FAIL: Oyuncunun saldırı durumu (is_attacking) iptal edilmedi!")
		all_passed = false
	else:
		print("PASS: Yüksek yozlaşmada saldırı başarıyla kesildi ve isyan durumu uygulandı.")

	# --- TEST SENARYOSU 3: Sonsuz Kilitlenme Olmaması ve Durum Toparlanması (0.4s) ---
	print("\n--- Test 3: Süreli Sersemleme ve Sonsuz Kilitlenmenin Önlenmesi ---")
	# İsyan sürerken saldırı fonksiyonlarının çağrılması engellenmeli
	player.perform_light_attack()
	if player.is_attacking:
		printerr("FAIL: İsyan sürerken perform_light_attack() çalıştı!")
		all_passed = false
	else:
		print("PASS: İsyan anında ek saldırı çağrıları başarıyla engellendi.")

	# Sürenin tamamlanmasını bekle (0.45 sn)
	await get_tree().create_timer(0.45).timeout

	if player.is_rebelling or srm.is_rebelling():
		printerr("FAIL: İsyan süresi bitmesine rağmen kilitlenme sürdü (is_rebelling = true)!")
		all_passed = false
	else:
		print("PASS: İsyan süresi (0.40s) bittiğinde kilitlenme temizlendi; oyuncu serbest.")

	# --- TEST SENARYOSU 4: Aşırı Yozlaşma (>= 75) Eşiği ---
	print("\n--- Test 4: Aşırı Yozlaşma (>= 75) Eşiği ve Kural Farkı ---")
	game_state.corruption_score = 80
	if srm.get_corruption_tier() != "extreme":
		printerr("FAIL: Aşırı yozlaşma seviyesi 'extreme' olarak algılanmadı! Bulunan: ", srm.get_corruption_tier())
		all_passed = false
	else:
		print("PASS: Aşırı yozlaşma (80 skor) 'extreme' olarak algılandı.")

	# --- TEST SENARYOSU 5: Durum Çakışmalarının Önlenmesi (Hasar Alma & Ölüm) ---
	print("\n--- Test 5: Saldırı / Hasar Durumlarıyla Çakışmayı Önleyen Durum Yönetimi ---")
	srm.reset_cooldown()
	srm.trigger_rebellion(true)
	if not player.is_rebelling:
		printerr("FAIL: İsyan tetiklenemedi!")
		all_passed = false

	# İsyan anında düşmandan darbe alınırsa
	player.take_damage(15)
	if player.is_rebelling:
		printerr("FAIL: Hasar alındığında isyan durumu temizlenmedi!")
		all_passed = false
	elif not player.is_hurt:
		printerr("FAIL: Hasar alma durumu (is_hurt) devreye girmedi!")
		all_passed = false
	else:
		print("PASS: Hasar alma durumu isyanı ezdi; durum çakışması ve takılma önlendi.")

	# Ölüm durumu kontrolü
	player.is_dead = true
	srm.reset_cooldown()
	var dead_rebel = srm.check_and_trigger_attack_rebellion()
	if dead_rebel or player.is_rebelling:
		printerr("FAIL: Oyuncu ölüyken isyan tetiklendi!")
		all_passed = false
	else:
		print("PASS: Oyuncu ölüyken isyan tetiklenmesi güvenle engellendi.")
	player.is_dead = false
	player.is_hurt = false

	# --- TEST SENARYOSU 6: Geri Bildirim ve Ses/Görsel Donatıları ---
	print("\n--- Test 6: Ses, Görsel ve Metin Geri Bildirim Bütünlüğü ---")
	var audio_node = srm.get_node_or_null("@AudioStreamPlayer@1")
	if not audio_node:
		audio_node = srm.find_child("*Audio*", true, false)
	if not audio_node:
		# Çocuk düğümler arasında AudioStreamPlayer ara
		for ch in srm.get_children():
			if ch is AudioStreamPlayer:
				audio_node = ch
				break

	if not audio_node:
		printerr("FAIL: Madeni çığlık ses düğümü (AudioStreamPlayer) bulunamadı!")
		all_passed = false
	else:
		print("PASS: Madeni feryat ses çalıcısı (AudioStreamPlayer) mevcut ve yapılandırıldı.")

	# Rastgele kılıç isyan metni testi
	var StoryDataLoader = load("res://scripts/autoloads/story_data_loader.gd")
	var hint_text = StoryDataLoader.get_random_sword_rebellion_text()
	print("Kılıç İsyanı Örnek Geri Bildirim Metni: ", hint_text)
	if hint_text.is_empty():
		printerr("FAIL: İsyan metni boş döndü!")
		all_passed = false
	else:
		print("PASS: Kılıç isyan metni başarıyla üretildi.")

	# --- TEST SENARYOSU 7: Doğrudan Müttefik Kurbanında İsyan Tepkisi ---
	print("\n--- Test 7: Müttefik Sömürüsü / Katlinde Ruhun Doğrudan Tepkisi ---")
	var signal_box = [false]
	var test_cb = func():
		signal_box[0] = true
	game_state.sword_rebellion_triggered.connect(test_cb)
	var hp_gain = game_state.register_ally_sacrifice("janissary")
	if not signal_box[0] or hp_gain <= 0:
		printerr("FAIL: Müttefik kurban edildiğinde sword_rebellion_triggered sinyali üretilmedi!")
		all_passed = false
	else:
		print("PASS: Müttefik katlinde kılıç ruhu anında isyan sinyali üretti.")

	# --- TEST SENARYOSU 8: Düşmana Saldırırken Kılıcın Direnmemesi Doğrulaması ---
	print("\n--- Test 8: Düşman Hedeflendiğinde Kılıcın Direnmemesi ve Müttefik Koruması ---")
	game_state.corruption_score = 95 # Aşırı yozlaşma seviyesinde bile düşmana direnmemeli
	srm.reset_cooldown()

	# 8.1 Düşman menzildeyken saldırı kontrolü
	var dummy_enemy = CharacterBody2D.new()
	dummy_enemy.name = "DummyEnemy"
	dummy_enemy.add_to_group("enemies")
	dummy_enemy.add_to_group("damageable")
	dummy_enemy.position = player.global_position + Vector2(65.0, 0.0)
	add_child(dummy_enemy)

	if not player.has_enemy_in_attack_range():
		printerr("FAIL: Önündeki düşman algılanamadı!")
		all_passed = false
	else:
		print("PASS: Önündeki düşman başarıyla algılandı (has_enemy_in_attack_range = true).")

	var enemy_attack_rebel = player._check_and_trigger_sword_rebellion()
	if enemy_attack_rebel:
		printerr("FAIL: Düşmana saldırırken kılıç isyan etti! Kılıç düşmanlara karşı asla direnmemeli!")
		all_passed = false
	else:
		print("PASS: Düşmana saldırırken kılıç direnmedi; saldırı kesintisiz icra edildi.")

	dummy_enemy.free()

	# 8.2 Müttefik menzildeyken kılıcın müttefiki koruma isyanı
	var dummy_ally = CharacterBody2D.new()
	dummy_ally.name = "DummyAlly"
	dummy_ally.add_to_group("allies")
	dummy_ally.position = player.global_position + Vector2(50.0, 0.0)
	add_child(dummy_ally)

	srm.reset_cooldown()
	if not player.has_ally_in_attack_range():
		printerr("FAIL: Önündeki müttefik algılanamadı!")
		all_passed = false
	else:
		print("PASS: Önündeki müttefik algılandı (has_ally_in_attack_range = true).")

	var ally_attack_rebel = player._check_and_trigger_sword_rebellion()
	if not ally_attack_rebel:
		printerr("FAIL: Müttefike kılıç sallandığında kılıç isyan etmedi!")
		all_passed = false
	else:
		print("PASS: Müttefike kılıç sallandığında kılıç müttefiki korumak için başarıyla isyan etti.")

	dummy_ally.free()

	# Temizlik
	player.queue_free()
	game_state.reset_state()

	print("\n========================================================")
	if all_passed:
		print("  SONUÇ: 8/8 KILIÇ İSYANI TESTLERİ TAMAMEN BAŞARILI!   ")
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: BAZI KILIÇ İSYANI TESTLERİ BAŞARISIZ OLDU!   ")
		print("========================================================\n")
		get_tree().quit(1)
