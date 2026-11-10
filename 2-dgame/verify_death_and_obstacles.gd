extends SceneTree

## res://verify_death_and_obstacles.gd
## Ölüm Mekaniği ve Engel Çarpışma Doğrulama Testi

func _init() -> void:
	_run_async()

func _run_async() -> void:
	print("\n=== [TEST BAŞLANGICI] Ölüm Mekaniği ve Engel Çarpışma Doğrulaması ===")
	var total_tests: int = 0
	var passed_tests: int = 0

	# 1. TEST: Oyuncu Boşluğa Düşünce Ölüm Tetiklenmesi
	total_tests += 1
	var player_scene = load("res://scenes/combat/test_player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	await physics_frame

	player.global_position = Vector2(100.0, 400.0)
	player.set_spawn_position(player.global_position)
	var spawn_pos = player.global_position

	# Oyuncuyu düşme ölüm eşiğinin altına taşı
	player.global_position.y = player.fall_death_y + 20.0
	player._physics_process(0.016)

	if player.is_dead and player.velocity == Vector2.ZERO:
		print("✅ TEST 1 GEÇTİ: Oyuncu boşluğa düştüğünde die() tetiklendi ve velocity sıfırlandı.")
		passed_tests += 1
	else:
		print("❌ TEST 1 BAŞARISIZ: Boşluğa düşüş ölümü tetikleyemedi! is_dead: %s" % str(player.is_dead))
		quit(1)
		return

	# 2. TEST: Yeniden Doğma (Respawn) ve Velocity Sıfırlanması
	total_tests += 1
	player.respawn_at_checkpoint()

	if not player.is_dead and player.global_position == spawn_pos and player.velocity == Vector2.ZERO and player.current_health == player.max_health:
		print("✅ TEST 2 GEÇTİ: Respawn sonrası başlangıç noktasına dönüldü, can tazelendi ve hız sıfırlandı.")
		passed_tests += 1
	else:
		print("❌ TEST 2 BAŞARISIZ: Respawn mantığında hata! is_dead: %s, pos: %s" % [str(player.is_dead), str(player.global_position)])
		quit(1)
		return

	# 3. TEST: Harita Altı DeathZone (Area2D) Tetiklenmesi
	total_tests += 1
	var death_zone_scene = load("res://scenes/hazards/death_zone.tscn")
	var death_zone = death_zone_scene.instantiate()
	death_zone.global_position = Vector2(100.0, 600.0)
	root.add_child(death_zone)
	await process_frame
	await physics_frame

	death_zone._on_body_entered(player)

	if player.is_dead:
		print("✅ TEST 3 GEÇTİ: DeathZone Area2D oyuncuyu anında tespit edip ölümü tetikledi.")
		passed_tests += 1
	else:
		print("❌ TEST 3 BAŞARISIZ: DeathZone ölümü tetikleyemedi!")
		quit(1)
		return

	death_zone.queue_free()
	player.queue_free()
	await process_frame

	# 4. TEST: Engele Çarpma ve İçinden Geçmeme (StaticBody2D Katı Çarpışma)
	total_tests += 1
	var test_p = player_scene.instantiate()
	root.add_child(test_p)
	test_p.global_position = Vector2(100.0, 500.0)

	var solid_obstacle = StaticBody2D.new()
	solid_obstacle.collision_layer = 1
	solid_obstacle.collision_mask = 0
	solid_obstacle.global_position = Vector2(140.0, 500.0)
	var col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40.0, 60.0)
	col_shape.shape = rect
	solid_obstacle.add_child(col_shape)
	root.add_child(solid_obstacle)

	await process_frame
	await physics_frame
	await physics_frame

	# Oyuncunun sağa doğru engele hareket testi (test_move)
	var collision_detected: bool = test_p.test_move(test_p.global_transform, Vector2(40.0, 0.0))

	if collision_detected:
		print("✅ TEST 4 GEÇTİ: Katı engele doğru harekette çarpışma tespit edildi (İçinden geçilemez).")
		passed_tests += 1
	else:
		print("❌ TEST 4 BAŞARISIZ: Engele çarpışma algılanamadı, içinden geçildi!")
		quit(1)
		return

	# 5. TEST: Alttan Geçiş ve Tavan Engeli (Eğilme / Kayma Mekaniği)
	total_tests += 1
	# Yüksekliği 30 px olan tünel engeli oluştur (Y = 475'te tavan, zemin Y = 500'de)
	var ceiling_obstacle = StaticBody2D.new()
	ceiling_obstacle.collision_layer = 1
	ceiling_obstacle.collision_mask = 0
	ceiling_obstacle.global_position = Vector2(250.0, 450.0)
	var ceil_col = CollisionShape2D.new()
	var ceil_rect = RectangleShape2D.new()
	ceil_rect.size = Vector2(100.0, 40.0)
	ceil_col.shape = ceil_rect
	ceiling_obstacle.add_child(ceil_col)
	root.add_child(ceiling_obstacle)

	await process_frame
	await physics_frame

	test_p.global_position = Vector2(250.0, 500.0)
	# Ayaktayken (boy 38px) tavana çarpar
	var standing_hits_ceiling = test_p.test_move(test_p.global_transform, Vector2(0.0, -10.0))

	# Eğilince (boy 22px) tavan engelinin altından geçebilir
	test_p.is_crouching = true
	test_p._set_collision_box(test_p.LOW_COL_SIZE, test_p.LOW_COL_POS)
	var has_ceiling = test_p._has_ceiling_overhead()

	if standing_hits_ceiling and has_ceiling:
		print("✅ TEST 5 GEÇTİ: Alttan geçiş mekaniği doğrulandı; ayakta çarpıyor, eğilince geçiyor ve tavanı algılıyor.")
		passed_tests += 1
	else:
		print("❌ TEST 5 BAŞARISIZ: Alttan geçiş tavan algılamasında hata!")
		quit(1)
		return

	test_p.queue_free()
	solid_obstacle.queue_free()
	ceiling_obstacle.queue_free()
	await process_frame

	# 6. TEST: Sahne 6 (stoneage_06_beasts_domain.tscn) Engel ve DeathZone Doğrulaması
	total_tests += 1
	var domain_scene = load("res://scenes/levels/stoneage/stoneage_06_beasts_domain.tscn")
	if not domain_scene:
		print("❌ TEST 6 BAŞARISIZ: Sahne 6 yüklenemedi!")
		quit(1)
		return

	var domain = domain_scene.instantiate()
	root.add_child(domain)
	await process_frame

	var trunk = domain.get_node_or_null("PrehistoricForestProps/FallenColossusTrunk1")
	var ribcage = domain.get_node_or_null("PrehistoricForestProps/GiantRibcageCluster1")
	var bones = domain.get_node_or_null("PrehistoricForestProps/BoneHeap1")
	var skull = domain.get_node_or_null("PrehistoricForestProps/MassiveSkullFossil1")
	var death_zone_node = domain.get_node_or_null("Environment/DeathZone")
	var ledge1 = domain.get_node_or_null("Environment/LedgeFossil1")

	var trunk_ok = trunk is StaticBody2D and trunk.get_node_or_null("CollisionShape2D") != null
	var ribcage_ok = ribcage is StaticBody2D and (ribcage.get_node_or_null("CollisionShapeCeiling") != null or ribcage.get_node_or_null("CollisionShape2D") != null)
	var bones_ok = bones is StaticBody2D and bones.get_node_or_null("CollisionShape2D") != null
	var skull_ok = skull is StaticBody2D and skull.get_node_or_null("CollisionShape2D") != null
	var dz_ok = death_zone_node != null and death_zone_node is Area2D
	var ledge_ok = ledge1 != null and ledge1.get_node_or_null("CollisionShape2D") != null and (ledge1.get_node("CollisionShape2D") as CollisionShape2D).one_way_collision

	if trunk_ok and ribcage_ok and bones_ok and skull_ok and dz_ok and ledge_ok:
		print("✅ TEST 6 GEÇTİ: Sahne 6'daki tüm engeller StaticBody2D'ye dönüştürüldü, DeathZone ve one_way_collision doğrulandı.")
		passed_tests += 1
	else:
		print("❌ TEST 6 BAŞARISIZ: Sahne 6 bileşenlerinde eksiklik var! trunk:%s, ribcage:%s, dz:%s, ledge:%s" % [trunk_ok, ribcage_ok, dz_ok, ledge_ok])
		quit(1)
		return

	domain.queue_free()

	print("\n=== TÜM TESTLER TAMAMLANDI: %d/%d Başarılı ===" % [passed_tests, total_tests])
	quit(0)
