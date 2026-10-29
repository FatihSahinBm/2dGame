extends Node

## res://tests/verify_spawn_points_runner.gd
## Harita Sahnesi Spawn Noktaları ve Bölümler Arası Güvenli Doğuş Testi

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
	print("  TEST: Harita Spawn Noktaları ve Güvenli Doğuş Doğrulama ")
	print("========================================================\n")

	_run_all_tests()

	print("\n========================================================")
	if tests_failed == 0:
		print("  SONUÇ: %d/%d HARİTA SPAWN TESTİ TAMAMEN BAŞARILI!" % [tests_passed, tests_passed + tests_failed])
	else:
		printerr("  HATA: %d test BAŞARISIZ OLDU! (Başarılı: %d)" % [tests_failed, tests_passed])
	print("========================================================\n")

	await get_tree().process_frame
	get_tree().quit(0 if tests_failed == 0 else 1)


func _run_all_tests() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	_assert_true(save_mgr != null, "SaveManager mevcut.")
	if not save_mgr:
		return

	# Test 1: stage_1_camp sahnesi varsayılan spawn noktası
	print("--- TEST 1: Stage 1 Camp Spawn Noktası ---")
	save_mgr.clear_checkpoint()
	var camp_scene = load("res://scenes/levels/vlad/stage_1_camp.tscn").instantiate()
	add_child(camp_scene)
	var player = camp_scene.find_child("CombatPlayer", true, false)
	_assert_true(player != null, "Camp sahnesinde CombatPlayer mevcut.")
	_assert_true(player.global_position == Vector2(120, 560), "Camp sahnesinde başlangıç konumu güvenli (120, 560).")

	# Kamp ateşi checkpoint'ini yak
	var campfire = camp_scene.find_child("CampfireCheckpoint", true, false)
	_assert_true(campfire != null, "Camp sahnesinde CampfireCheckpoint mevcut.")
	if campfire:
		campfire.ignite_and_rest(player)
		_assert_true(save_mgr.cached_checkpoint_position == campfire.get_spawn_position(), "Campfire checkpoint SaveManager'a kaydedildi.")

	# Camp içinde ölüm ve respawn testi
	player.is_dead = true
	player.respawn()
	_assert_true(player.global_position == campfire.get_spawn_position(), "Camp içinde ölünce kamp ateşinde yeniden doğuldu.")
	camp_scene.queue_free()

	# Test 2: stage_2_castle_dungeon sahnesi geçişi (Dikenler Üzerinde Doğmama Testi!)
	print("\n--- TEST 2: Stage 2 Dungeon Geçişi & Diken Çukuru Koruması ---")
	# Önceki sahnede checkpoint (840, 560) iken yeni sahneye geçiyoruz:
	var dungeon_scene = load("res://scenes/levels/vlad/stage_2_castle_dungeon.tscn").instantiate()
	add_child(dungeon_scene)
	var dungeon_player = dungeon_scene.find_child("CombatPlayer", true, false)
	_assert_true(dungeon_player != null, "Dungeon sahnesinde CombatPlayer mevcut.")

	# Eski sahnenin checkpoint'i (840, 560) kesinlikle uygulanmamalı, güvenli giriş zemininde (120, 530) doğmalı!
	_assert_true(dungeon_player.global_position == Vector2(120, 530), "Dungeon başlangıcında güvenli giriş çıkıntısında (120, 530) doğuldu!")
	_assert_true(dungeon_player.global_position != Vector2(820, 560) and dungeon_player.global_position != Vector2(840, 560), "Oyuncu kesinlikle eski kamp ateşi koordinatında (dikenlerin üstünde) doğmadı!")

	# Diken çukuru alanının x sınırları içinde olmamalı (SpikePitHazard x: 160-1360 arası, player 120'de güvenli)
	_assert_true(dungeon_player.global_position.x < 160.0, "Oyuncu diken çukurunun (x: 160+) tamamen gerisinde güvenli zeminde.")

	# Dungeon içinde ölüm ve respawn testi
	dungeon_player.is_dead = true
	dungeon_player.respawn()
	_assert_true(dungeon_player.global_position == Vector2(120, 530), "Dungeon içinde ölünce güvenli giriş noktasında (120, 530) yeniden doğuldu, dikenlere düşülmedi!")
	dungeon_scene.queue_free()

	# Test 3: stage_1_forest_camp sahnesi spawn noktası
	print("\n--- TEST 3: Stage 1 Forest Camp Spawn Noktası ---")
	save_mgr.clear_checkpoint()
	var forest_scene = load("res://scenes/levels/vlad/stage_1_forest_camp.tscn").instantiate()
	add_child(forest_scene)
	var forest_player = forest_scene.find_child("CombatPlayer", true, false)
	_assert_true(forest_player != null, "Forest Camp sahnesinde CombatPlayer mevcut.")
	_assert_true(forest_player.global_position == Vector2(140, 500) or forest_player.global_position == Vector2(140, 520), "Forest Camp başlangıç konumu güvenli (140, 500 veya 140, 520).")
	forest_scene.queue_free()

	# Test 4: stage_1_bridge_assault sahnesi spawn noktası
	print("\n--- TEST 4: Stage 1 Bridge Assault Spawn Noktası ---")
	save_mgr.clear_checkpoint()
	var bridge_scene = load("res://scenes/levels/vlad/stage_1_bridge_assault.tscn").instantiate()
	add_child(bridge_scene)
	var bridge_player = bridge_scene.find_child("CombatPlayer", true, false)
	_assert_true(bridge_player != null, "Bridge sahnesinde CombatPlayer mevcut.")
	_assert_true(bridge_player.global_position == Vector2(120, 560), "Bridge sahnesi güvenli başlangıç noktasında (120, 560).")
	bridge_scene.queue_free()

	# Test 5: stage_1_fatih_tent sahnesi spawn noktası
	print("\n--- TEST 5: Stage 1 Fatih Tent Spawn Noktası ---")
	save_mgr.clear_checkpoint()
	var tent_scene = load("res://scenes/levels/vlad/stage_1_fatih_tent.tscn").instantiate()
	add_child(tent_scene)
	var tent_player = tent_scene.find_child("CombatPlayer", true, false)
	_assert_true(tent_player != null, "Fatih çadırında CombatPlayer mevcut.")
	_assert_true(tent_player.global_position == Vector2(360, 610), "Çadır içinde zemin üzerinde doğru konumda (360, 610).")
	tent_scene.queue_free()

	# Test 6: stage_3_throne_room sahnesi spawn noktası
	print("\n--- TEST 6: Stage 3 Throne Room Spawn Noktası ---")
	save_mgr.clear_checkpoint()
	var throne_scene = load("res://scenes/levels/vlad/stage_3_throne_room.tscn").instantiate()
	add_child(throne_scene)
	var throne_player = throne_scene.find_child("CombatPlayer", true, false)
	_assert_true(throne_player != null, "Taht odasında CombatPlayer mevcut.")
	_assert_true(throne_player.global_position == Vector2(180, 560), "Taht odası girişinde güvenli konumda (180, 560).")
	throne_scene.queue_free()

	# Test 7: prehistoric_valley sahnesi spawn noktası
	print("\n--- TEST 7: Prehistoric Valley Spawn Noktası ---")
	save_mgr.clear_checkpoint()
	var prehist_scene = load("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn").instantiate()
	add_child(prehist_scene)
	var prehist_player = prehist_scene.find_child("CombatPlayer", true, false)
	_assert_true(prehist_player != null, "Tarih öncesi vadide CombatPlayer mevcut.")
	_assert_true(prehist_player.global_position == Vector2(160, 440), "Zaman yarığının hemen önünde (160, 440).")
	prehist_scene.queue_free()
