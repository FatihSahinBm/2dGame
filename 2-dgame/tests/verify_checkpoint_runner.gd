extends Node

## res://tests/verify_checkpoint_runner.gd
## Story 2D-131: Kontrol Noktaları ve Kamp Ateşi Doğrulama Paketi

const CampfireCheckpoint = preload("res://scripts/objects/campfire_checkpoint.gd")

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
	print("  TEST: Story 2D-131 Kontrol Noktaları & Kamp Ateşi Testi ")
	print("========================================================")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d KONTROL NOKTASI TESTİ TAMAMEN BAŞARILI! " % [tests_passed, tests_passed + tests_failed])
		print("========================================================\n")
		get_tree().quit(0)
	else:
		printerr("  SONUÇ: %d BAŞARISIZ KONTROL NOKTASI TESTİ BULUNDU! " % tests_failed)
		print("========================================================\n")
		get_tree().quit(1)


func _run_all_tests() -> void:
	_test_campfire_instantiation()
	_test_proximity_and_prompt()
	_test_ignition_and_feedback()
	_test_save_manager_checkpoint()
	_test_health_and_potion_refill()
	_test_idempotent_interactions()
	_test_enemy_respawn_and_boss_preservation()
	_test_player_death_and_checkpoint_respawn()
	_test_save_load_persistence()


# ---------------------------------------------------------------------------
# Test 1: Kamp Ateşi Düğüm Kurulumu ve Başlangıç Durumu
# ---------------------------------------------------------------------------
func _test_campfire_instantiation() -> void:
	print("\n--- Test 1: Kamp Ateşi Düğüm Kurulumu ve Başlangıç Durumu ---")
	var cf_scene = load("res://scenes/objects/campfire_checkpoint.tscn")
	_assert_true(cf_scene != null, "CampfireCheckpoint sahnesi başarıyla yüklendi.")

	var campfire = cf_scene.instantiate() as CampfireCheckpoint
	add_child(campfire)
	campfire.checkpoint_id = "test_cp_initial"

	_assert_true(campfire.is_in_group("campfires"), "Kamp ateşi 'campfires' grubunda.")
	_assert_true(campfire.is_in_group("checkpoints"), "Kamp ateşi 'checkpoints' grubunda.")
	_assert_true(not campfire.is_lit, "Ateş başlangıçta sönük (is_lit == false).")
	_assert_true(campfire.fire_visual != null and not campfire.fire_visual.visible, "Alev görseli sönükken gizli.")
	_assert_true(campfire.particles != null and not campfire.particles.emitting, "Kıvılcım parçacıkları sönükken durdurulmuş.")
	_assert_true(campfire.prompt_label != null and not campfire.prompt_label.visible, "Etkileşim ipucu başlangıçta gizli.")

	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 2: Oyuncu Yaklaşımı ve Etkileşim İpucu (Proximity & Prompt)
# ---------------------------------------------------------------------------
func _test_proximity_and_prompt() -> void:
	print("\n--- Test 2: Oyuncu Yaklaşımı ve Etkileşim İpucu ---")
	var campfire = CampfireCheckpoint.new()
	campfire.name = "ProximityCampfire"
	campfire.checkpoint_id = "cp_proximity"
	add_child(campfire)

	var dummy_player = CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	add_child(dummy_player)

	# Oyuncu alana girdi
	campfire._on_body_entered(dummy_player)
	_assert_true(campfire.prompt_label.visible, "Oyuncu yaklaştığında ipucu etiketi görünür.")
	_assert_true(campfire.prompt_label.text.contains("Kamp Ateşini Yak") or campfire.prompt_label.text.contains("Light Campfire"), "İpucu 'Kamp Ateşini Yak' içeriyor.")

	# Oyuncu alandan çıktı
	campfire._on_body_exited(dummy_player)
	_assert_true(not campfire.prompt_label.visible, "Oyuncu uzaklaştığında ipucu gizlenir.")

	dummy_player.queue_free()
	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 3: Ateşleme, Görsel & Ses Geri Bildirimi
# ---------------------------------------------------------------------------
func _test_ignition_and_feedback() -> void:
	print("\n--- Test 3: Ateşleme, Görsel & Ses Geri Bildirimi ---")
	var campfire = CampfireCheckpoint.new()
	campfire.name = "IgniteCampfire"
	campfire.checkpoint_id = "cp_ignite"
	campfire.spawn_offset = Vector2(25.0, 0.0)
	add_child(campfire)

	var activated_signal_fired: Array = []
	campfire.checkpoint_activated.connect(func(cid, pos):
		activated_signal_fired.append({"cid": cid, "pos": pos})
	)

	var dummy_player = CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	add_child(dummy_player)

	campfire.ignite_and_rest(dummy_player)

	_assert_true(campfire.is_lit, "Kamp ateşi yakıldı (is_lit == true).")
	_assert_true(campfire.fire_visual.visible, "Alev görseli aktif ve görünür.")
	_assert_true(campfire.particles.emitting, "Kıvılcım parçacıkları saçılmaya başladı.")
	_assert_true(campfire.audio_emitter != null, "Konumsal ses yayıcısı (PositionalAudioEmitter2D) oluşturuldu.")
	_assert_true(campfire.audio_emitter.sound_key == "campfire", "Ses anahtarı 'campfire' olarak ayarlandı.")
	_assert_true(activated_signal_fired.size() == 1, "checkpoint_activated sinyali tam 1 kez yayınlandı.")
	_assert_true(activated_signal_fired[0]["cid"] == "cp_ignite", "Sinyaldeki checkpoint_id doğru.")
	_assert_true(activated_signal_fired[0]["pos"] == campfire.global_position + campfire.spawn_offset, "Sinyaldeki spawn konumu doğru hesaplandı.")

	dummy_player.queue_free()
	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 4: SaveManager Entegrasyonu (Kontrol Noktası Kaydı)
# ---------------------------------------------------------------------------
func _test_save_manager_checkpoint() -> void:
	print("\n--- Test 4: SaveManager Entegrasyonu (Kontrol Noktası Kaydı) ---")
	var save_mgr = get_node_or_null("/root/SaveManager")
	_assert_true(save_mgr != null, "SaveManager Autoload singleton mevcut.")
	if not save_mgr:
		return

	var campfire = CampfireCheckpoint.new()
	campfire.checkpoint_id = "cp_save_test_01"
	campfire.global_position = Vector2(500.0, 300.0)
	campfire.spawn_offset = Vector2(20.0, 0.0)
	add_child(campfire)

	campfire.ignite_and_rest()

	_assert_true(save_mgr.cached_checkpoint_id == "cp_save_test_01", "SaveManager.cached_checkpoint_id güncellendi.")
	_assert_true(save_mgr.cached_checkpoint_position == Vector2(520.0, 300.0), "SaveManager.cached_checkpoint_position spawn offset ile eşitlendi.")

	# Slot 1'e kayıt al ve doğrula
	var save_ok = save_mgr.save_game(1)
	_assert_true(save_ok, "SaveManager.save_game(1) başarılı.")

	var summary = save_mgr.get_slot_summary(1)
	_assert_true(summary.get("has_save", false), "Kayıt özeti geçerli.")
	_assert_true(summary.get("checkpoint_position") == Vector2(520.0, 300.0), "Kayıt özetindeki checkpoint_position doğru saklandı.")

	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 5: Can ve İksir Tazeleme (Rest Replenish)
# ---------------------------------------------------------------------------
func _test_health_and_potion_refill() -> void:
	print("\n--- Test 5: Can ve İksir Tazeleme ---")
	var campfire = CampfireCheckpoint.new()
	campfire.checkpoint_id = "cp_heal"
	add_child(campfire)

	# Test Player (Gerçek sahne ile tam değişken desteği)
	var PlayerScene = load("res://scenes/combat/test_player.tscn")
	var player = PlayerScene.instantiate()
	player.max_health = 100
	player.current_health = 15 # Ağır yaralı
	add_child(player)

	# Mock HUD (GDScript değişkenleri tanımlı)
	var hud_script = GDScript.new()
	hud_script.source_code = """
extends Control
var max_health: int = 100
var current_health: int = 15
var max_mana: int = 40
var current_mana: int = 5
var health_potions: int = 0
var mana_potions: int = 0
func update_all() -> void:
	pass
"""
	hud_script.reload()
	var hud = Control.new()
	hud.name = "FantasyHUD"
	hud.set_script(hud_script)
	add_child(hud)

	campfire.ignite_and_rest(player)

	_assert_true(player.current_health == 100, "Oyuncu canı dinlenmeyle tam seviyeye (100) ulaştı.")
	_assert_true(hud.current_health == 100, "HUD canı tam seviyeye (100) ulaştı.")
	_assert_true(hud.current_mana == 40, "HUD manası tam seviyeye (40) ulaştı.")
	_assert_true(hud.health_potions == 3, "Can iksirleri 3 adet tazelendi.")
	_assert_true(hud.mana_potions == 2, "Mana iksirleri 2 adet tazelendi.")

	player.queue_free()
	hud.queue_free()
	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 6: İdempotent Etkileşim (Art Arda Dinlenmeler)
# ---------------------------------------------------------------------------
func _test_idempotent_interactions() -> void:
	print("\n--- Test 6: İdempotent Etkileşim (Tekrarlanan Dinlenmeler) ---")
	var campfire = CampfireCheckpoint.new()
	campfire.checkpoint_id = "cp_idempotent"
	add_child(campfire)

	var rested_events: Array = []
	campfire.player_rested.connect(func(cid):
		rested_events.append(cid)
	)

	# 1. Ateşleme
	campfire.ignite_and_rest()
	_assert_true(campfire.is_lit, "İlk etkileşimde kamp ateşi yakıldı.")

	# Cooldown'ı sıfırlayıp 2. ve 3. dinlenmeleri yap
	campfire._is_resting_cooldown = false
	campfire.ignite_and_rest()
	campfire._is_resting_cooldown = false
	campfire.ignite_and_rest()

	_assert_true(rested_events.size() == 2, "Sonraki dinlenmeler 'player_rested' sinyali üretti (2 kez).")

	# Ses yayıcısı çoğalmamalı
	var emitter_count: int = 0
	for ch in campfire.get_children():
		if ch.name.contains("PositionalAudio"):
			emitter_count += 1
	_assert_true(emitter_count == 1, "Art arda dinlenmeler çift/mükerrer ses yayıcı oluşturmadı (Tam 1 adet).")

	# İpucu 'Dinlen' olarak güncellendi
	campfire._player_in_range = Node2D.new()
	campfire._update_prompt_text()
	_assert_true(campfire.prompt_label.text.contains("Dinlen"), "Ateş yanıkken etkileşim ipucu 'Dinlen' metnini gösteriyor.")
	campfire._player_in_range.free()

	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 7: Devriye Düşmanlarının Yeniden Doğması ve Boss Durumunun Korunması
# ---------------------------------------------------------------------------
func _test_enemy_respawn_and_boss_preservation() -> void:
	print("\n--- Test 7: Düşman Yeniden Doğuşu & Boss İlerlemesi Korunması ---")
	var campfire = CampfireCheckpoint.new()
	campfire.checkpoint_id = "cp_respawn_enemies"
	add_child(campfire)

	# Sıradan devriye düşmanı oluştur
	var enemy_script = GDScript.new()
	enemy_script.source_code = """
extends CharacterBody2D
var max_health: int = 50
var current_health: int = 50
var is_dead: bool = false
var direction: int = 1
"""
	enemy_script.reload()

	var patrol_enemy = CharacterBody2D.new()
	patrol_enemy.name = "PatrolGoblin"
	patrol_enemy.set_script(enemy_script)
	patrol_enemy.add_to_group("respawnable_enemies")
	patrol_enemy.global_position = Vector2(800.0, 450.0)
	add_child(patrol_enemy)

	# Düşmanı kamp ateşine kaydet
	campfire.register_respawnable_enemy(patrol_enemy)

	# Düşmanı öldür ve yerini değiştir
	patrol_enemy.current_health = 0
	patrol_enemy.is_dead = true
	patrol_enemy.global_position = Vector2(950.0, 450.0)
	patrol_enemy.visible = false

	# Kalıcı bir boss'u öldürülmüş olarak işaretle
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.set_event_completed("boss_defeated_trex", true)

	# Kamp ateşinde dinlen -> Düşmanlar respawn edilmeli
	var count = campfire.respawn_enemies()
	_assert_true(count >= 1, "En az 1 devriye düşmanı yeniden başlatıldı.")
	_assert_true(patrol_enemy.current_health == 50, "Devriye düşmanının canı başlangıç değerine (50) döndü.")
	_assert_true(patrol_enemy.is_dead == false, "Devriye düşmanı canlandırıldı (is_dead == false).")
	_assert_true(patrol_enemy.global_position == Vector2(800.0, 450.0), "Devriye düşmanı ilk devriye başlangıç noktasına döndü.")
	_assert_true(patrol_enemy.visible, "Düşmanın görünürlüğü açıldı.")

	# Boss'un durumu korunmalı
	if gs:
		_assert_true(gs.is_event_completed("boss_defeated_trex"), "Kalıcı boss yenilgisi dinlenmeyle kaybolmadı, korundu.")

	patrol_enemy.queue_free()
	campfire.queue_free()


# ---------------------------------------------------------------------------
# Test 8: Oyuncu Ölümü ve Kontrol Noktasından Yeniden Doğuş
# ---------------------------------------------------------------------------
func _test_player_death_and_checkpoint_respawn() -> void:
	print("\n--- Test 8: Oyuncu Ölümü ve Kontrol Noktasında Doğuş ---")
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	# Önceden bir kontrol noktası belirle
	save_mgr.cached_checkpoint_id = "cp_death_test"
	save_mgr.cached_checkpoint_position = Vector2(400.0, 250.0)

	var PlayerScene = load("res://scenes/combat/test_player.tscn")
	_assert_true(PlayerScene != null, "test_player.tscn yüklendi.")
	var player = PlayerScene.instantiate()
	add_child(player)

	# Oyuncuyu uzağa taşı ve öldür
	player.global_position = Vector2(1200.0, 250.0)
	player.die()
	_assert_true(player.is_dead, "Oyuncu yenildi/öldü (is_dead == true).")

	# Kontrol noktasında yeniden doğur
	player.respawn()

	_assert_true(player.is_dead == false, "Yeniden doğuş sonrası is_dead == false.")
	_assert_true(player.current_health == player.max_health, "Yeniden doğuş sonrası oyuncu canı tam.")
	_assert_true(player.global_position == Vector2(400.0, 250.0), "Oyuncu kayıtlı kontrol noktası konumunda (400, 250) doğdu.")

	player.queue_free()


# ---------------------------------------------------------------------------
# Test 9: Kayıt Yükleme Sonrası Kontrol Noktası ve Kalıcı İlerleme
# ---------------------------------------------------------------------------
func _test_save_load_persistence() -> void:
	print("\n--- Test 9: Kayıt Yükleme & Kalıcı Görev/Boss İlerlemesi ---")
	var save_mgr = get_node_or_null("/root/SaveManager")
	var gs = get_node_or_null("/root/GameState")
	if not save_mgr or not gs:
		return

	save_mgr.cached_checkpoint_id = "cp_castle_courtyard"
	save_mgr.cached_checkpoint_position = Vector2(640.0, 360.0)
	gs.is_commander_rescued = true
	gs.set_event_completed("drawbridge_lowered", true)
	gs.set_event_completed("blood_altar_cleared", true)

	var save_res = save_mgr.save_game(1)
	_assert_true(save_res, "Oyun Yuva 1'e kaydedildi.")

	# Bellek durumunu temizle
	save_mgr.cached_checkpoint_id = ""
	save_mgr.cached_checkpoint_position = Vector2.ZERO
	gs.is_commander_rescued = false
	gs.persistent_events.clear()

	# Yuva 1'den yükle
	var load_res = save_mgr.load_game(1)
	_assert_true(load_res, "Yuva 1'den oyun yüklendi.")

	_assert_true(save_mgr.cached_checkpoint_id == "cp_castle_courtyard", "Yüklenen kontrol noktası kimliği korundu.")
	_assert_true(save_mgr.cached_checkpoint_position == Vector2(640.0, 360.0), "Yüklenen kontrol noktası koordinatı korundu.")
	_assert_true(gs.is_commander_rescued == true, "Görev ilerlemesi (komutan kurtarıldı) korundu.")
	_assert_true(gs.is_event_completed("drawbridge_lowered"), "Kalıcı köprü indirme olayı korundu.")
	_assert_true(gs.is_event_completed("blood_altar_cleared"), "Kalıcı sunak temizleme olayı korundu.")
