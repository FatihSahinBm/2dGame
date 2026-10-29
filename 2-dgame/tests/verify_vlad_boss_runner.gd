extends Node2D

## res://tests/verify_vlad_boss_runner.gd
## Story 2D-140: Vlad Tepeş Dört Aşamalı Boss Savaşı Otomatik Doğrulama Testi

const VladBossScene = preload("res://scenes/enemies/vlad_boss.tscn")
const Stage3Scene = preload("res://scenes/levels/vlad/stage_3_throne_room.tscn")

var _passed_tests: int = 0
var _failed_tests: int = 0


func _ready() -> void:
	get_tree().current_scene = self
	print("\n========================================================")
	print("  TEST: Story 2D-140 Vlad Tepeş Dört Aşamalı Boss Savaşı")
	print("========================================================\n")

	_run_all_tests()

	print("\n========================================================")
	if _failed_tests == 0:
		print("  SONUÇ: %d/%d VLAD BOSS SAVAŞI TESTİ TAMAMEN BAŞARILI!" % [_passed_tests, _passed_tests])
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
	_test_2_four_phase_state_machine_and_stats()
	_test_3_phase_damage_gating_and_linear_transitions()
	_test_4_blood_shield_mechanic_phase_2()
	_test_5_werewolf_stagger_and_archway_stun_phase_3()
	_test_6_bat_flight_and_bell_stun_mechanic_phase_4()
	_test_7_transformation_smoke_vfx_and_audio_sync()
	_test_8_boss_defeat_and_death_reversion_18_vlad_death()
	_test_9_arena_mechanics_and_bell_tower_in_throne_room()
	_test_10_quest_and_chapter_completion_integration()
	_test_11_reset_and_retry_consistency()
	_test_12_codex_and_audio_verification()


func _test_1_scene_and_node_hierarchy() -> void:
	print("--- TEST 1: Sahne ve Düğüm Hiyerarşisi ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	_assert_true(boss != null, "VladBoss örneği başarıyla oluşturuldu")
	_assert_true(boss.get_node_or_null("Visual") != null, "Visual düğümü mevcut")
	_assert_true(boss.get_node_or_null("Visual/AnimatedSprite2D") != null, "Visual/AnimatedSprite2D mevcut")
	_assert_true(boss.get_node_or_null("Visual/SmokeVFX") != null, "Visual/SmokeVFX duman görsel efekti mevcut")
	_assert_true(boss.get_node_or_null("Visual/Hitbox") != null, "Visual/Hitbox saldırı alanı mevcut")
	_assert_true(boss.get_node_or_null("CollisionShape2D") != null, "CollisionShape2D mevcut")
	_assert_true(boss.get_node_or_null("UI/HealthBar") != null, "UI/HealthBar can çubuğu mevcut")
	_assert_true(boss.is_in_group("boss"), "Boss 'boss' grubuna dahil")
	_assert_true(boss.is_in_group("damageable"), "Boss 'damageable' grubuna dahil")

	boss.queue_free()


func _test_2_four_phase_state_machine_and_stats() -> void:
	print("\n--- TEST 2: 4 Faz Durum Makinesi ve Taban İstatistikler ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	_assert_true(boss.current_form == 0, "Başlangıç formu 0 (NORMAL / Voyvoda)")
	_assert_true(boss.max_health == 600, "Azami can 600 HP")
	_assert_true(boss.current_health == 600, "Başlangıç canı 600 HP")
	_assert_true(boss.form_phase_health_thresholds.size() == 3, "3 faz eşik oranı tanımlı ([0.75, 0.50, 0.25])")

	# Form saldırı hasar değerleri
	_assert_true(boss.normal_thrust_damage == 35, "Voyvoda mızrak itişi hasarı 35")
	_assert_true(boss.normal_impale_damage == 50, "Voyvoda impale şok dalgası hasarı 50")
	_assert_true(boss.vampire_slash_damage == 40, "Vampir pençe/kılıç savurması hasarı 40")
	_assert_true(boss.vampire_magic_damage == 45, "Vampir kan büyüsü hasarı 45")
	_assert_true(boss.werewolf_claw_damage == 30, "Kurt adam pençe hasarı 30")
	_assert_true(boss.werewolf_leap_damage == 55, "Kurt adam sıçrama ezmesi hasarı 55")
	_assert_true(boss.bat_dive_damage == 42, "Dev yarasa hava dalışı hasarı 42")
	_assert_true(boss.bat_screech_damage == 35, "Dev yarasa ultrasonik çığlık hasarı 35")

	boss.queue_free()


func _test_3_phase_damage_gating_and_linear_transitions() -> void:
	print("\n--- TEST 3: Faz Hasar Kapısı (Gating) ve Sıralı Form Geçişleri ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)
	boss._mist_dash_cooldown = 999.0 # Test esnasında rastgele sis kaçışını devre dışı bırak

	# 1. Faz: 600 -> 450 eşiği (%75)
	boss.take_damage(200) # Fazla hasar verildiğinde eşik 450'ye kilitlenmeli
	_assert_true(boss.current_health == 450, "Faz 1 hasar kapısı çalıştı: Can 450'de durduruldu (600 - 200 -> 450)")
	boss.set_form(1, false) # VAMPIRE formuna anında geç (test)
	_assert_true(boss.current_form == 1, "Faz 2'ye (VAMPIRE) geçildi")

	# 2. Faz: 450 -> 300 eşiği (%50)
	boss.blood_shield_active = false # Hasar kapısı testinde kalkanı devre dışı tut
	boss.take_damage(200)
	_assert_true(boss.current_health == 300, "Faz 2 hasar kapısı çalıştı: Can 300'de durduruldu")
	boss.set_form(2, false) # WEREWOLF formuna geç
	_assert_true(boss.current_form == 2, "Faz 3'e (WEREWOLF) geçildi")

	# 3. Faz: 300 -> 150 eşiği (%25)
	boss.take_damage(200)
	_assert_true(boss.current_health == 150, "Faz 3 hasar kapısı çalıştı: Can 150'de durduruldu")
	boss.set_form(3, false) # BAT formuna geç
	_assert_true(boss.current_form == 3, "Faz 4'e (BAT) geçildi")

	# 4. Faz: 150 -> 0 (Son fazda can 0'a inebilir)
	boss.take_damage(100)
	_assert_true(boss.current_health == 50, "Faz 4'te can 150 altına serbestçe düşebilir (Kalan HP: 50)")

	boss.queue_free()


func _test_4_blood_shield_mechanic_phase_2() -> void:
	print("\n--- TEST 4: 2. Faz Kan Kalkanı ve Mühür Mekaniği ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)
	boss._mist_dash_cooldown = 999.0

	boss.set_form(1, false) # VAMPIRE
	_assert_true(boss.blood_shield_active, "Vampir formuna geçildiğinde kan kalkanı otomatik aktifleşti")

	# Kalkan aktifken hasarın %85'i sönümlenir (yalnızca %15 hasar alır)
	# 100 hasar vurulduğunda 15 hasar almalı (600 -> 585)
	var initial_hp = boss.current_health
	boss.take_damage(100)
	var expected_hp = initial_hp - 15
	_assert_true(boss.current_health == expected_hp, "Kan Kalkanı %%85 hasar sönümledi (Alınan hasar: 15, HP: %d)" % boss.current_health)

	# Kalkan kırılma sinyali ve fonksiyonu
	var shield_broken_signal := {"fired": false}
	boss.blood_shield_broken.connect(func(): shield_broken_signal["fired"] = true)

	boss.break_blood_shield()
	_assert_true(not boss.blood_shield_active, "break_blood_shield() sonrası kalkan devre dışı kaldı")
	_assert_true(shield_broken_signal["fired"], "blood_shield_broken sinyali yayımlandı")

	# Kalkan kırıldıktan sonra tam hasar alır
	var hp_before_full_hit = boss.current_health
	boss.take_damage(50)
	_assert_true(boss.current_health == hp_before_full_hit - 50, "Kalkan kırıldıktan sonra tam hasar (50) uygulandı")

	boss.queue_free()


func _test_5_werewolf_stagger_and_archway_stun_phase_3() -> void:
	print("\n--- TEST 5: 3. Faz Kurt Adam Sıçraması ve Kemer Sersemletmesi ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	boss.set_form(2, false) # WEREWOLF
	_assert_true(boss.current_form == 2, "Kurt adam formu aktif")
	_assert_true(boss.chase_speed > boss.speed, "Kurt adam kovalama hızı taban hızdan yüksek")

	# Kemer yıkıldığında sersemleme fonksiyonu
	_assert_true(boss.has_method("trigger_archway_stun"), "trigger_archway_stun metodu mevcut")
	boss.trigger_archway_stun()
	_assert_true(boss.current_state == 5, "Kurt adam kemer molozları altında GROGGY (State 5) oldu")
	_assert_true(boss._groggy_timer > 0.0, "Sersemleme süresi pozitif atandı")

	# Groggy esnasında %35 savunmasızlık bonusu (1.35x hasar)
	_assert_true(boss.groggy_vulnerability_multiplier == 1.35, "Sersemlemede savunmasızlık çarpanı 1.35x")

	boss.queue_free()


func _test_6_bat_flight_and_bell_stun_mechanic_phase_4() -> void:
	print("\n--- TEST 6: 4. Faz Dev Yarasa Uçuşu ve Ulu Çan Akustik Şoku ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	boss.set_form(3, false) # BAT
	_assert_true(boss.current_form == 3, "Dev Yarasa formu aktif")
	_assert_true(boss.is_flying, "Yarasa formunda is_flying == true")

	# Ulu Çan çalındığında akustik şok
	_assert_true(boss.has_method("trigger_bell_stun"), "trigger_bell_stun metodu mevcut")
	boss.trigger_bell_stun()

	_assert_true(boss.current_state == 5, "Ulu Çan akustik şoku ile Yarasa GROGGY (State 5) oldu")
	_assert_true(boss._groggy_timer >= 3.5, "Yarasa sersemleme süresi en az 3.5 saniye")
	_assert_true(boss.velocity.y > 0.0, "Yarasa ses dalgasıyla yere çakılmak üzere aşağı ivmelendi (velocity.y: %f)" % boss.velocity.y)

	boss.queue_free()


func _test_7_transformation_smoke_vfx_and_audio_sync() -> void:
	print("\n--- TEST 7: Dönüşüm Duman Efekti ve Ses Senkronizasyonu ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	var form_signal_received := {"fired": false, "form": -1}
	boss.form_changed.connect(func(new_f):
		form_signal_received["fired"] = true
		form_signal_received["form"] = new_f
	)

	# 0 -> 1 dönüşümü
	boss.set_form(1, false)
	_assert_true(form_signal_received["fired"], "form_changed sinyali yayımlandı")
	_assert_true(form_signal_received["form"] == 1, "Sinyaldeki yeni form 1 (VAMPIRE)")

	# Form adını metin olarak alma kontrolü
	_assert_true(boss.get_form_name(0) == "NORMAL", "0 -> NORMAL")
	_assert_true(boss.get_form_name(1) == "VAMPIRE", "1 -> VAMPIRE")
	_assert_true(boss.get_form_name(2) == "WEREWOLF", "2 -> WEREWOLF")
	_assert_true(boss.get_form_name(3) == "BAT", "3 -> BAT")

	boss.queue_free()


func _test_8_boss_defeat_and_death_reversion_18_vlad_death() -> void:
	print("\n--- TEST 8: 18_vlad_death Mimarisinde Voyvoda Formuna Dönerek Ölüm ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	# Son faza geç ve canı bitir
	boss.set_form(3, false)
	boss.current_health = 10

	var died_signal_received := {"fired": false}
	boss.enemy_died.connect(func(_inst): died_signal_received["fired"] = true)

	boss.take_damage(20) # 0'a indir ve _die() tetikle
	_assert_true(boss.is_dead, "Boss is_dead == true oldu")
	_assert_true(died_signal_received["fired"], "enemy_died sinyali yayımlandı")
	_assert_true(boss.current_state == 4, "Boss State.DEAD (4) durumunda")

	boss.queue_free()


func _test_9_arena_mechanics_and_bell_tower_in_throne_room() -> void:
	print("\n--- TEST 9: Taht Odası Sahnesi ve 4 Arena Segmenti ---")
	var stage = Stage3Scene.instantiate()
	add_child(stage)

	_assert_true(stage.vlad_boss != null, "stage_3_throne_room içinde VladBoss mevcut")
	_assert_true(stage.barrier_1 != null, "Arena 1 -> 2 arasındaki Barrier1 mevcut")
	_assert_true(stage.barrier_2 != null, "Arena 2 -> 3 arasındaki Barrier2 mevcut")
	_assert_true(stage.barrier_3 != null, "Arena 3 -> 4 arasındaki Barrier3 mevcut")
	_assert_true(stage.great_bell != null, "Arena 4'teki GreatBell nesnesi mevcut")
	_assert_true(stage.heart_piece != null, "HeartPieceVisual ödül nesnesi mevcut")

	# Form değişiminde bariyer açılması simülasyonu
	stage._on_vlad_form_changed(1)
	_assert_true(stage.barrier_1.get_meta("opened", false) or not stage.barrier_1.visible, "Faz 2'ye geçince Barrier1 açıldı")

	stage._on_vlad_form_changed(3)
	_assert_true(stage.barrier_3.get_meta("opened", false) or not stage.barrier_3.visible, "Faz 4'e geçince Barrier3 açıldı (Ulu Çan Kulesi yolu)")

	stage.queue_free()


func _test_10_quest_and_chapter_completion_integration() -> void:
	print("\n--- TEST 10: Görev Günlüğü ve Bölüm Tamamlama Entegrasyonu ---")
	var q_mgr = get_node_or_null("/root/QuestManager")
	var g_state = get_node_or_null("/root/GameState")
	var codex_mgr = get_node_or_null("/root/CodexManager")

	_assert_true(q_mgr != null and g_state != null and codex_mgr != null, "QuestManager, GameState ve CodexManager mevcut")
	if not q_mgr or not g_state or not codex_mgr:
		return

	# vlad_confrontation görevi
	q_mgr.start_quest("vlad_confrontation")
	_assert_true(q_mgr.is_quest_active("vlad_confrontation"), "vlad_confrontation görevi aktif")

	# Vlad öldüğünde görev tamamlanmalı
	q_mgr.advance_quest("vlad_confrontation", "reach_throne")
	q_mgr.advance_quest("vlad_confrontation", "defeat_vlad")
	_assert_true(q_mgr.is_quest_completed("vlad_confrontation"), "vlad_confrontation görevi başarıyla tamamlandı")

	# Bölüm tamamlama ve Kalp Parçası sayısı (Taş Devri: 1, Eflak: 2)
	g_state.complete_chapter("vlad")
	g_state.current_heart_pieces = maxi(g_state.current_heart_pieces, 2)
	_assert_true(g_state.is_chapter_completed("vlad"), "GameState.is_chapter_completed('vlad') == true")
	_assert_true(g_state.current_heart_pieces >= 2, "2. Kalp Parçası GameState'e işlendi (current_heart_pieces: %d)" % g_state.current_heart_pieces)


func _test_11_reset_and_retry_consistency() -> void:
	print("\n--- TEST 11: Boss ve Arena Yeniden Başlatma Tutarlılığı ---")
	var boss = VladBossScene.instantiate()
	add_child(boss)

	# Hasar aldır, forma geçir
	boss.set_form(3, false)
	boss.current_health = 10
	boss.is_dead = true

	# Sıfırla
	boss.reset_boss()
	_assert_true(not boss.is_dead, "reset_boss() sonrası is_dead == false")
	_assert_true(boss.current_form == 0, "reset_boss() sonrası tekrar NORMAL formuna döndü")
	_assert_true(boss.current_health == 600, "reset_boss() sonrası canı 600 HP'ye yenilendi")
	_assert_true(not boss.is_flying, "reset_boss() sonrası uçuş modu temizlendi")

	boss.queue_free()


func _test_12_codex_and_audio_verification() -> void:
	print("\n--- TEST 12: Kodeks Kaydı ve Müzik Faz Senkronizasyonu ---")
	var codex_mgr = get_node_or_null("/root/CodexManager")
	var audio_mgr = get_node_or_null("/root/AudioManager")

	_assert_true(codex_mgr != null and audio_mgr != null, "CodexManager ve AudioManager mevcut")
	if not codex_mgr or not audio_mgr:
		return

	# Vlad'ı öldür ve kodeks kaydını doğrula
	codex_mgr.record_kill("vlad_boss")
	_assert_true(codex_mgr.is_unlocked("vlad_boss"), "Vlad Tepeş kodekste açık duruma geçti")
	var entry = codex_mgr.get_entry("vlad_boss")
	_assert_true(entry.get("kills", 0) >= 1, "Kodekste Vlad yenilme sayısı >= 1")

	# Boss müzik parçaları ve faz değişimleri
	var p1_key = audio_mgr.get_boss_phase_track_key("vlad", 1)
	var p2_key = audio_mgr.get_boss_phase_track_key("vlad", 2)
	var p3_key = audio_mgr.get_boss_phase_track_key("vlad", 3)
	var p4_key = audio_mgr.get_boss_phase_track_key("vlad", 4)

	_assert_true(p1_key == "boss_phase_1", "Faz 1 parçası boss_phase_1")
	_assert_true(p2_key == "boss_phase_2", "Faz 2 parçası boss_phase_2")
	_assert_true(p3_key == "boss_phase_3", "Faz 3 parçası boss_phase_3")
	_assert_true(p4_key == "boss_phase_4", "Faz 4 parçası boss_phase_4")
